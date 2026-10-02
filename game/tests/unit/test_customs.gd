extends RefCounted
## Real order and Ledger paths, early receipts, closure and finite alternative routes for both chapters.

var runner


func _fixture():
	var f = load("res://tests/unit/test_global.gd").new()
	f._setup()
	return f


func _declare(policy := "ddp", code := "electronics") -> void:
	var l := Ecommerce.listing_for("wireless_earbuds")
	Customs.set_declaration("northridge", str(l["id"]), policy, code)


func test_ddp_duty_is_paid_once_from_real_shipping() -> void:
	var f = _fixture()
	_declare()
	var o: Dictionary = f._order()
	f._deliver(o)
	runner.eq(o["customs"]["duty_paid"], 2.64, "66 home-dollar value at four percent")
	runner.eq(Ledger.balance(str(o["entity"]), "exp:compliance"), 2.64, "DDP duty is an expense")
	Customs.prepare(o)
	runner.eq(o["customs"]["duty_paid"], 2.64, "repeated clearance never charges again")
	runner.check(Ledger.check_balanced(), "duty balances")


func test_ddu_buyer_duty_has_higher_refusal_risk() -> void:
	var f = _fixture()
	_declare("ddu")
	var o: Dictionary = f._order()
	f._deliver(o)
	runner.eq(o["customs"]["duty_paid"], 0, "DDU seller pays no arrival duty")
	var high := Customs.refusal_chance(o)
	o["customs"]["policy"] = "ddp"
	runner.check(high > Customs.refusal_chance(o) and Customs.refusal_chance(o) > 0, "both choices have actual risk")
	runner.check(Ledger.check_balanced(), "DDU balances")


func test_wrong_code_has_real_documents_and_pay_choices() -> void:
	var f = _fixture()
	_declare("ddu", "textiles")
	var o: Dictionary = f._order()
	Ecommerce.pack_orders("riverside_studio")
	Ecommerce.courier_pickup("riverside_studio", "economy")
	Ecommerce._h_pickup({"ids": [o["id"]]})
	runner.eq(o["status"], "customs_hold", "wrong code blocks shipment")
	var event: Dictionary = EventEngine.S()["queue"].filter(func(q): return q["id"] == "customs_hold")[0]
	runner.check(EventEngine.choose(str(event["iid"]), "documents")["ok"], "real decision accepts documents")
	runner.eq(o["customs"]["duty_paid"], 2.64, "supplement duty paid")
	runner.eq(o["customs"]["penalty"], 12.5, "documents reduce fine")
	runner.eq(int(o["ship"]["eta"]) - int(o["ship"]["shipped"]), 16 * Clock.DAY, "documents add two days to fourteen-day route")
	runner.check(not Customs.resolve(str(o["id"]), "pay")["ok"], "closed hold cannot charge again")
	runner.check(Ledger.check_balanced(), "correction balances")


func test_impossible_hold_times_out_and_reclaims_goods() -> void:
	var f = _fixture()
	_declare("ddu", "textiles")
	var o: Dictionary = f._order()
	Ecommerce.pack_orders("riverside_studio")
	Ecommerce.courier_pickup("riverside_studio", "economy")
	Ecommerce._h_pickup({"ids": [o["id"]]})
	GameState.data["clock"]["minutes"] += 7 * Clock.DAY
	Customs.reconcile()
	runner.eq(o["status"], "cancelled", "finite hold deadline")
	runner.eq(Ecommerce.stock("riverside_studio", "wireless_earbuds"), 20, "unsold goods restored once")
	runner.check(EventEngine.S()["queue"].filter(func(q): return q["id"] == "customs_hold").is_empty(), "stale decision removed")
	Customs.reconcile()
	runner.eq(Ecommerce.stock("riverside_studio", "wireless_earbuds"), 20, "no duplicate stock")
	runner.check(Ledger.check_balanced(), "withdrawal balances")


func test_immediate_payment_and_broke_withdrawal_are_distinct_routes() -> void:
	var f = _fixture()
	_declare("ddu", "textiles")
	var paid: Dictionary = f._order()
	Ecommerce.pack_orders("riverside_studio")
	Ecommerce.courier_pickup("riverside_studio", "economy")
	Ecommerce._h_pickup({"ids": [paid["id"]]})
	runner.check(Customs.resolve(str(paid["id"]), "pay")["ok"], "immediate payment releases hold")
	runner.eq(paid["customs"]["penalty"], 25, "full correction fine")
	runner.eq(int(paid["ship"]["eta"]) - int(paid["ship"]["shipped"]), 14 * Clock.DAY, "no document delay")
	var broke: Dictionary = f._order()
	Ecommerce.pack_orders("riverside_studio")
	Ecommerce.courier_pickup("riverside_studio", "economy")
	Ecommerce._h_pickup({"ids": [broke["id"]]})
	Ledger.expense(GameState.company_id(), "other", Ledger.cash(GameState.company_id()), "Test cash exhaustion")
	runner.check(not Customs.resolve(str(broke["id"]), "documents")["ok"], "broke company cannot pay discounted duty")
	runner.check(Customs.resolve(str(broke["id"]), "withdraw")["ok"], "cash-free withdrawal remains possible")
	runner.check(not Customs.resolve(str(broke["id"]), "withdraw")["ok"], "already withdrawn cannot restore stock twice")
	runner.check(Ledger.check_balanced(), "both genuine routes balance")


func test_chapter_13_already_done_receipts_drain_into_14() -> void:
	var f = _fixture()
	var o: Dictionary = f._order()
	f._deliver(o)
	GameState.data["clock"]["minutes"] += 3 * Clock.DAY
	GlobalMarket.payout(GameState.company_id())
	GlobalMarket.convert_currency(GameState.company_id(), "NRD")
	GameState.set_flag("news_read_y9")
	StoryEngine.start_chapter("ch13_first_order_abroad")
	runner.check("ch13_first_order_abroad" in StoryEngine.St()["chapters_done"], "five early receipts drain chapter")
	runner.eq(StoryEngine.St()["chapter"], "ch14_customs", "next chapter starts once")
	runner.check(Ledger.check_balanced(), "income card never creates money")


func test_chapter_14_already_done_policy_code_and_sales() -> void:
	var f = _fixture()
	_declare()
	for i in 10:
		var o: Dictionary = f._order()
		f._deliver(o)
		o["customs_refused"] = false   # this scenario is ten successful actual deliveries
	GameState.data["clock"]["minutes"] += 3 * Clock.DAY
	GameState.set_flag("met_ines")
	StoryEngine.start_chapter("ch14_customs")
	runner.check("ch14_customs" in StoryEngine.St()["chapters_done"], "early conversation/declarations/deliveries drain chapter")
	runner.check(Ledger.check_balanced(), "ten duties and sales balance")


func test_both_chapters_impossible_after_bound_company_closes() -> void:
	_fixture()
	StoryEngine.start_chapter("ch13_first_order_abroad")
	var ent := GameState.company_id()
	Insolvency.state()["entity"] = ent
	Insolvency.close_company()
	StoryEngine.check()
	runner.check("ch13_first_order_abroad" in StoryEngine.St()["chapters_done"] and "ch14_customs" in StoryEngine.St()["chapters_done"], "closed company cannot soft-lock either chapter")
	runner.check(not GameState.flag("first_export_converted") and not GameState.flag("customs_trial_passed"), "skip never forges successful transactions")
	runner.check(Ledger.check_balanced(), "closure balances")


func test_unsuccessful_trial_can_reduce_target_or_pause_honestly() -> void:
	var f = _fixture()
	_declare()
	GameState.set_flag("met_ines")
	StoryEngine.start_chapter("ch14_customs")
	GameState.data["clock"]["minutes"] += 14 * Clock.DAY
	Customs.reconcile()
	runner.eq(Customs.trial_results(GameState.company_id())["target"], 5, "two-week reduced target")
	runner.check(Customs.pause_expansion(), "zero sales still permit honest review")
	runner.check("ch14_customs" in StoryEngine.St()["chapters_done"], "review is an explicit alternative")
	runner.check(not GameState.flag("customs_trial_passed"), "review is not success")
	GameState.data.erase("customs")
	GameState.data = SaveSystem._migrate(GameState.data)
	runner.check(Customs.S().has("companies"), "older saves initialize declaration state")
	var _u = f


func test_trial_waits_for_return_window_and_counts_actual_refusals() -> void:
	var f = _fixture()
	_declare()
	var o: Dictionary = f._order()
	f._deliver(o)
	runner.eq(Customs.trial_results(GameState.company_id())["count"], 0, "new delivery cannot pass before scheduled returns have surfaced")
	GameState.data["clock"]["minutes"] += 3 * Clock.DAY
	o["customs_refused"] = true
	var result := Customs.trial_results(GameState.company_id())
	runner.eq(result["count"], 1, "observed delivery counts")
	runner.eq(result["return_rate"], 1.0, "refusal is not a successful sale")
