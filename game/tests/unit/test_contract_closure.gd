extends RefCounted
## A collector's AR sale is collected once; closure/load must end contracts without new money entries.
var runner


func _company() -> String:
	Company.register("Closure Test", "ecommerce", "22 Founders Lane")
	Company.open_business_account(10000)
	return GameState.company_id()


func _offer(tag := "big_contract") -> String:
	return Contracts.create_offer({"buyer": "harbor_point_fitness", "product": "water_bottle", "qty": 10,
		"unit_price": 21.0, "tag": tag, "payment_terms_days": 30})


func _stock() -> void:
	var po := Ecommerce.buy("tradelink_wholesale", "water_bottle", 60)
	runner.check(po["ok"], "stock purchase")
	Ecommerce.handle("eco.po_arrive", {"po": po["po_id"]})


func _pending(cid: String) -> Array:
	return GameState.data["schedule"].filter(func(e): return str(e["kind"]).begins_with("con.") and e["p"].get("id", "") == cid)


func _load_fixture(file: String) -> void:
	var contents := FileAccess.get_file_as_string("res://tests/fixtures/" + file)
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)
	var f := FileAccess.open(SaveSystem._path(6), FileAccess.WRITE)
	f.store_string(contents)
	f.close()
	runner.check(SaveSystem.load_data(6), "loads actual pre-change fixture: " + file)


func test_delivered_invoice_closed_then_due_cannot_pay_twice() -> void:
	var ent := _company()
	_stock()
	var cid := _offer()
	Contracts.accept(cid)
	runner.check(Contracts.deliver(cid)["ok"], "delivered before closure")
	var due := int(Contracts.C()[cid]["pay_due"])
	var ar := Ledger.balance(ent, "accounts_receivable")
	var result := Insolvency.close_company()
	runner.check(result["ok"], "company closed")
	runner.eq(result["report"]["receivables"], snappedf(ar * 0.8, 0.01), "exactly one 80% AR recovery")
	runner.eq(Contracts.C()[cid]["status"], "sold_to_collector", "terminal invoice state")
	runner.check(not GameState.flag("big_contract_paid"), "collector sale is not buyer payment")
	runner.check(_pending(cid).is_empty(), "collection and old reminders cancelled")
	var cash := Ledger.cash(ent)
	Clock.advance(due - Clock.now() + 60)
	Contracts.handle("con.pay", {"id": cid})
	runner.eq(Ledger.cash(ent), cash, "no cash re-enters closed company")
	runner.eq(Ledger.balance(ent, "accounts_receivable"), 0, "AR cannot turn negative")
	runner.check(not Contracts.early_payment(cid)["ok"], "early payment blocked")
	runner.check(Ledger.check_balanced(), "balanced closure and due date")


func test_active_contract_terminated_and_new_company_stock_protected() -> void:
	_company()
	var cid := _offer()
	Contracts.accept(cid)
	Insolvency.close_company()
	runner.eq(Contracts.C()[cid]["status"], "terminated", "undelivered contract terminated")
	runner.check(not GameState.flag("big_contract_delivered"), "no delivery receipt invented")
	runner.check(GameState.flag("big_contract_accepted") and not GameState.flag("big_contract_declined"), "existing decision retained")
	runner.check(_pending(cid).is_empty(), "active reminders removed")
	_company()
	_stock()
	var qty := Ecommerce.total_units_at_any("water_bottle")
	var seq := int(GameState.data["ledger"]["seq"])
	runner.check(not Contracts.can_deliver(cid), "new company's stock is not available to old seller")
	runner.check(not Contracts.deliver(cid)["ok"], "direct delivery call also blocked")
	runner.eq(Ecommerce.total_units_at_any("water_bottle"), qty, "no stock consumed")
	runner.eq(GameState.data["ledger"]["seq"], seq, "no money moved on blocked action")
	runner.eq(Contracts.delivery_block(cid), "This is a contract of a closed company.", "plain closed-company reason")
	var os := CompanyOS.new("laptop")
	os.content = UIK.vbox()
	os.sel_contract = cid
	os._tab_contracts()
	var button := os.content.find_child("DeliverContract", true, false) as Button
	runner.check(button != null and button.disabled, "stable disabled button remains visible")
	var texts := os.content.find_children("*", "Label", true, false).map(func(label): return label.text)
	runner.check("This is a contract of a closed company." in texts, "UI shows ownership reason")
	os.content.free()
	os.free()
	runner.check(Ledger.check_balanced(), "balanced restart")


func test_offered_closure_settles_chapter_five() -> void:
	_company()
	var cid := _offer()
	GameState.set_flag("big_contract_offered")
	StoryEngine.start_chapter("ch5_big_contract")
	var seq := int(GameState.data["ledger"]["seq"])
	Contracts.close_for_entity(GameState.company_id())
	runner.eq(GameState.data["ledger"]["seq"], seq, "ending contract creates no journal")
	runner.eq(Contracts.C()[cid]["status"], "withdrawn", "unanswered offer withdrawn")
	runner.check(GameState.flag("big_contract_decided") and GameState.flag("big_contract_declined"), "story decision receipt")
	StoryEngine.check()
	runner.check("ch5_decide" in StoryEngine.St()["done"], "chapter five decision completes")
	runner.check("ch5_stock" in StoryEngine.St()["done"] and "ch5_deliver" in StoryEngine.St()["done"], "declined contract's impossible stock/delivery skipped")
	runner.check(Ledger.check_balanced(), "withdrawn offer balanced")


func test_closed_old_save_reconciles_without_liquidating_again() -> void:
	var original: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/contracts_closed_pre36.json"))
	original["data"]["ledger"]["seq"] = int(original["data"]["ledger"]["seq"])   # existing save migration normalises this counter
	_load_fixture("contracts_closed_pre36.json")
	runner.eq(GameState.data["ledger"], original["data"]["ledger"], "loading repair leaves original ledger exactly unchanged")
	var ent := "co_closure_fixture"
	runner.eq(Contracts.C()["C-001"]["status"], "withdrawn", "old offered repaired")
	runner.eq(Contracts.C()["C-002"]["status"], "terminated", "old active repaired")
	runner.eq(Contracts.C()["C-003"]["status"], "sold_to_collector", "old delivered repaired")
	runner.check(GameState.flag("big_contract_decided"), "old story decision repaired")
	var cash := Ledger.cash(ent)
	var seq := int(GameState.data["ledger"]["seq"])
	var history_size: int = Contracts.C()["C-003"]["history"].size()
	Contracts.reconcile_closed()
	runner.eq(GameState.data["ledger"]["seq"], seq, "idempotent reconcile never posts journals")
	runner.eq(Contracts.C()["C-003"]["history"].size(), history_size, "history line not duplicated")
	for cid in Contracts.C():
		runner.check(_pending(cid).is_empty(), "all old contract schedules removed")
	GameState.data["clock"]["minutes"] = int(Contracts.C()["C-003"]["pay_due"])
	Contracts.handle("con.pay", {"id": "C-003"})
	runner.eq(Ledger.cash(ent), cash, "old closed save cannot collect again")
	runner.eq(Ledger.balance(ent, "accounts_receivable"), 0, "old AR stays zero")
	runner.check(Ledger.check_balanced(), "old closed save balanced")


func test_preclosure_fixture_loads_then_closes_safely() -> void:
	_load_fixture("contracts_before_closure_pre36.json")
	runner.eq(Contracts.C()["C-003"]["status"], "delivered", "live invoice not prematurely ended")
	runner.check(Insolvency.close_company()["ok"], "loaded live company closes")
	var cash := Ledger.cash("co_closure_fixture")
	var due := int(Contracts.C()["C-003"]["pay_due"])
	Clock.advance(due - Clock.now() + 60)
	runner.eq(Ledger.cash("co_closure_fixture"), cash, "preclosure fixture never double collects")
	runner.eq(Ledger.balance("co_closure_fixture", "accounts_receivable"), 0, "preclosure AR stays zero")
	runner.check(Ledger.check_balanced(), "preclosure fixture balanced")


func test_guards_protect_against_missing_cleanup_and_wrong_seller() -> void:
	var ent := _company()
	_stock()
	var cid := _offer()
	Contracts.accept(cid)
	Contracts.deliver(cid)
	GameState.data["entities"][ent]["closed"] = Clock.now()
	var seq := int(GameState.data["ledger"]["seq"])
	Contracts.handle("con.pay", {"id": cid})
	runner.check(not Contracts.early_payment(cid)["ok"], "raw stale invoice cannot be paid early")
	runner.eq(GameState.data["ledger"]["seq"], seq, "raw closed invoice posts no collection")
	GameState.data["entities"][ent].erase("closed")
	Contracts.C()[cid]["status"] = "active"
	Contracts.C()[cid]["seller"] = "other_company"
	runner.check(not Contracts.can_deliver(cid) and not Contracts.deliver(cid)["ok"], "foreign open seller blocked")
	runner.check(Ledger.check_balanced(), "guarded actions balanced")


func test_terminal_contracts_unchanged_and_missing_decision_repaired() -> void:
	var ent := _company()
	for status in ["paid", "rejected", "withdrawn", "expired"]:
		var cid := _offer(status)
		Contracts.C()[cid]["status"] = status
	var active := _offer("legacy_active")
	Contracts.accept(active)
	GameState.set_flag("legacy_active_decided", false)
	var seq := int(GameState.data["ledger"]["seq"])
	Contracts.close_for_entity(ent)
	for c in Contracts.C().values():
		if c["id"] != active:
			runner.eq(c["status"], c["tag"], "existing terminal status retained")
	runner.check(GameState.flag("legacy_active_decided") and GameState.flag("legacy_active_declined"), "legacy active gets missing decision only")
	runner.check(not GameState.flag("legacy_active_delivered"), "no false delivery")
	runner.eq(GameState.data["ledger"]["seq"], seq, "closure has no extra penalty")
	runner.check(Ledger.check_balanced(), "unchanged terminal contracts balanced")
