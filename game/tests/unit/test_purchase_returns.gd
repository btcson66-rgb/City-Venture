extends RefCounted
## Purchase-side returns: money, reservations, payment rails, deadlines and pre-change saves.
var runner


func _buy(terms := false, supplier := "tradelink_wholesale", product := "wireless_earbuds", qty := 50, settlement := "") -> String:
	var result := Ecommerce.buy(supplier, product, qty, "riverside_studio", terms, -1, 1.0, settlement)
	runner.check(result["ok"], "purchase succeeds: " + str(result))
	return result.get("po_id", "")


func _po(id: String) -> Dictionary:
	return Ecommerce.E()["purchase_orders"][id]


func _arrive(id: String) -> void:
	Ecommerce.handle("eco.po_arrive", {"po": id})


func test_prepaid_cancel_and_stale_delivery() -> void:
	var id := _buy()
	var cash := Ledger.cash("player")
	runner.check(Ecommerce.cancel_purchase(id)["ok"], "cancel within window")
	runner.eq(Ledger.cash("player"), cash + 855, "refund less five percent")
	runner.eq(Ledger.balance("player", "exp:restocking"), 45, "cancellation fee")
	runner.eq(Ledger.balance("player", "inventory_in_transit"), 0, "in-transit asset gone")
	_arrive(id)
	runner.eq(Ecommerce.stock("riverside_studio", "wireless_earbuds"), 0, "stale arrival cannot deliver")
	runner.check(not Ecommerce.cancel_purchase(id)["ok"], "cannot cancel twice")
	runner.check(Ledger.check_balanced(), "balanced cancellation")


func test_net_cancel_reduces_invoice_and_only_fee_is_paid() -> void:
	Company.register("Return Test", "retail_online", "Riverside Tower 7C")
	GameState.set_flag("business_account_opened")
	var ent := GameState.company_id()
	var id := _buy(true)
	var cash := Ledger.cash(ent)
	runner.check(Ecommerce.cancel_purchase(id)["ok"], "net cancellation")
	runner.eq(Ledger.cash(ent), cash, "no cash refund or charge today")
	runner.eq(Ledger.balance(ent, "accounts_payable"), -45, "only fee stays payable")
	Ecommerce.handle("eco.ap_due", {"po": id})
	runner.eq(Ledger.cash(ent), cash - 45, "due handler pays fee only")
	runner.eq(Ledger.balance(ent, "accounts_payable"), 0, "invoice closed")
	Ecommerce.handle("eco.ap_due", {"po": id})
	runner.eq(Ledger.cash(ent), cash - 45, "due handler idempotent")
	runner.check(Ledger.check_balanced(), "balanced net cancellation")


func test_cancel_deadline_is_exclusive() -> void:
	var id := _buy()
	GameState.data["clock"]["minutes"] = int(_po(id)["placed"]) + 24 * 60
	var cash := Ledger.cash("player")
	runner.check(not Ecommerce.cancel_purchase(id)["ok"], "at deadline cancellation blocked")
	runner.check(Ecommerce.cancel_block(id).contains("window ended"), "blocked reason")
	runner.eq(Ledger.cash("player"), cash, "blocked operation has no money movement")
	runner.check(Ledger.check_balanced(), "blocked cancellation balanced")


func test_partial_return_reserves_stock_and_delayed_refund() -> void:
	var id := _buy()
	_arrive(id)
	Ecommerce.E()["orders"]["reserve"] = {"status": "placed", "location": "riverside_studio", "product": "wireless_earbuds", "qty": 40}
	runner.eq(Ecommerce.return_max(id), 10, "unshipped customer orders reserved")
	runner.check(not Ecommerce.return_purchase(id, 11)["ok"], "cannot take reserved stock")
	var cash := Ledger.cash("player")
	var result := Ecommerce.return_purchase(id, 10)
	runner.check(result["ok"], "partial return")
	runner.eq(Ecommerce.stock("riverside_studio", "wireless_earbuds"), 40, "stock gone at dispatch")
	runner.eq(Ledger.cash("player"), cash - 6 * World.shipping_index(), "freight paid today")
	runner.eq(Ledger.balance("player", "accounts_receivable"), 153, "refund is receivable")
	runner.eq(Ledger.balance("player", "exp:restocking"), 27, "restocking expense")
	Ecommerce.handle("eco.return_refund", {"po": id, "return": 0})
	runner.eq(Ledger.balance("player", "accounts_receivable"), 153, "cannot collect early")
	GameState.data["clock"]["minutes"] = int(result["due"])
	Ecommerce.handle("eco.return_refund", {"po": id, "return": 0})
	Ecommerce.handle("eco.return_refund", {"po": id, "return": 0})
	runner.eq(Ledger.balance("player", "accounts_receivable"), 0, "refund settled once")
	runner.eq(Ledger.cash("player"), cash - 6 * World.shipping_index() + 153, "cash at receipt")
	runner.check(Ledger.check_balanced(), "balanced partial return")


func test_return_deadline_moved_stock_and_cumulative_cap() -> void:
	var id := _buy()
	_arrive(id)
	GameState.data["contracts"]["reserved"] = {"status": "active", "location": "riverside_studio", "product": "wireless_earbuds", "qty": 45}
	runner.eq(Ecommerce.return_max(id), 5, "contract reservation counts")
	GameState.data["contracts"].clear()
	runner.check(Ecommerce.return_purchase(id, 50)["ok"], "whole PO returned")
	Ecommerce._add_stock("riverside_studio", "wireless_earbuds", 50, 18.0, 0.0)
	runner.eq(Ecommerce.return_max(id), 0, "replacement stock cannot reuse fully returned PO")
	var other := _buy()
	_arrive(other)
	GameState.data["clock"]["minutes"] = int(_po(other)["arrived"]) + 14 * Clock.DAY
	runner.check(not Ecommerce.return_purchase(other, 1)["ok"], "return deadline exclusive")
	runner.check(Ledger.check_balanced(), "cumulative and expired returns balanced")


func test_delivered_import_has_no_supplier_return() -> void:
	GameState.data["world"]["year"] = 5
	var id := _buy(false, "lumina_direct", "wireless_earbuds", 200, "international_wire")
	_po(id)["settlement"]["clears"] = Clock.now()
	Ecommerce.handle("eco.po_cleared", {"po": id})
	_arrive(id)
	var cash := Ledger.cash("player")
	var stock := Ecommerce.stock("riverside_studio", "wireless_earbuds")
	runner.check(Ecommerce.return_block(id).contains("does not accept"), "delivered import gives supplier restriction reason")
	runner.check(not Ecommerce.return_purchase(id, 1)["ok"], "delivered import cannot be returned")
	runner.eq(Ledger.cash("player"), cash, "blocked import return cannot charge freight")
	runner.eq(Ecommerce.stock("riverside_studio", "wireless_earbuds"), stock, "blocked import return preserves stock")
	runner.check(Ledger.check_balanced(), "blocked import return balanced")


func test_average_cost_difference_and_zero_fee_coop() -> void:
	GameState.set_flag("supplier_aurelia_makers")
	var id := _buy(false, "aurelia_makers", "phone_stand", 40)
	_arrive(id)
	var cheaper := _buy(false, "tradelink_wholesale", "phone_stand", 80)
	_arrive(cheaper)
	var avg := Ecommerce.avg_cost("riverside_studio", "phone_stand")
	var value := snappedf(10 * avg, 0.01)
	runner.check(Ecommerce.return_purchase(id, 10)["ok"], "co-op partial return")
	runner.eq(Ecommerce.return_quote(id, 10)["fee"], 0, "co-op has no restocking fee")
	runner.eq(Ledger.balance("player", "inventory"), 164 + 272 - value, "remove average-cost stock")
	runner.eq(Ledger.balance("player", "other_income"), -(41 - value), "supplier price over average cost is other income")
	runner.check(Ledger.check_balanced(), "balanced mixed-cost return")


func test_pending_crossborder_principal_refunded_fees_kept() -> void:
	GameState.data["world"]["year"] = 5
	var id := _buy(false, "lumina_direct", "wireless_earbuds", 200, "international_wire")
	var po := _po(id)
	runner.eq(po["status"], "awaiting_payment", "payment pending")
	var fee := float(po["settlement"]["fee"])
	var cash := Ledger.cash("player")
	runner.check(Ecommerce.cancel_purchase(id)["ok"], "pending order cancelled")
	runner.eq(Ledger.cash("player"), cash + float(po["total"]), "full principal returned")
	runner.eq(Ledger.balance("player", "bank_fees"), 0, "only exp category records bank fee")
	runner.eq(Ledger.balance("player", "exp:bank_fees"), fee, "settlement fee is retained")
	Ecommerce.handle("eco.po_cleared", {"po": id})
	_arrive(id)
	runner.eq(po["status"], "cancelled", "old reminders cannot revive order")
	runner.eq(Ecommerce.return_policy("lumina_direct")["return_window_days"], 0, "imports have no default return window")
	runner.check(Ledger.check_balanced(), "balanced crossborder cancellation")


func test_escrow_cancellation_removes_held_asset() -> void:
	GameState.data["world"]["year"] = 6
	GameState.set_flag("escrow_open")
	var id := _buy(false, "lumina_direct", "wireless_earbuds", 200, "escrow")
	runner.check(Ecommerce.cancel_purchase(id)["ok"], "pending escrow cancelled")
	runner.eq(Ledger.balance("player", "escrow_held"), 0, "escrow asset cleared")
	runner.check(Ledger.check_balanced(), "balanced escrow cancellation")


func test_cleared_crossborder_uses_normal_cancellation_fee() -> void:
	GameState.data["world"]["year"] = 5
	var id := _buy(false, "lumina_direct", "wireless_earbuds", 200, "international_wire")
	var po := _po(id)
	# A landed payment uses the normal fee even if it cleared faster than its scheduled reminder.
	po["settlement"]["clears"] = Clock.now()
	Ecommerce.handle("eco.po_cleared", {"po": id})
	runner.eq(po["status"], "in_transit", "payment landed")
	var expected_fee := snappedf(float(po["total"]) * 0.05, 0.01)
	runner.eq(Ecommerce.cancel_purchase(id)["fee"], expected_fee, "landed import cancellation fee")
	runner.check(Ledger.check_balanced(), "balanced landed import")


func test_return_schedule_survives_save_load_and_registration() -> void:
	var id := _buy()
	_arrive(id)
	var result := Ecommerce.return_purchase(id, 5)
	runner.check(result["ok"], "return before registration")
	Company.register("Return Later", "retail_online", "Riverside Tower 7C")
	runner.check(Company.open_business_account(500)["ok"], "business account transfers stock assets")
	var ent := GameState.company_id()
	runner.eq(_po(id)["entity"], ent, "remaining delivered stock belongs to company")
	runner.eq(_po(id)["returns"][0]["entity"], "player", "existing receivable stays on proprietor books")
	runner.check(SaveSystem.save(5) and SaveSystem.load_data(5), "pending return save/load")
	GameState.data["clock"]["minutes"] = int(result["due"]) - 1
	Clock.advance(1)
	runner.eq(_po(id)["returns"][0]["status"], "refunded", "saved scheduler collects at deadline")
	runner.eq(Ledger.balance("player", "accounts_receivable"), 0, "original owner's receivable cleared")
	runner.check(Ecommerce.return_purchase(id, 1)["ok"], "remaining stock can be returned by company")
	runner.check(Ledger.check_balanced(), "balanced after registration and scheduler")


func test_save_made_before_purchase_returns_loads() -> void:
	var original := FileAccess.get_file_as_string("res://tests/fixtures/purchase_returns_pre21.json")
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)
	var f := FileAccess.open(SaveSystem._path(6), FileAccess.WRITE)
	f.store_string(original)
	f.close()
	runner.check(SaveSystem.load_data(6), "load fixture made on e6accdb before returns existed")
	var po: Dictionary = Ecommerce.E()["purchase_orders"].values()[0]
	runner.check(not po.has("returns"), "old PO has no new fields")
	runner.check(Ecommerce.cancel_purchase(str(po["id"]))["ok"], "old PO can cancel with lazy defaults")
	runner.check(Ledger.check_balanced(), "old save balanced")


func test_liquidated_return_receivable_cannot_collect_twice() -> void:
	Company.register("Return Closure", "ecommerce", "22 Founders Lane")
	Company.open_business_account(1000)
	var ent := GameState.company_id()
	var id := _buy()
	_arrive(id)
	var result := Ecommerce.return_purchase(id, 5)
	runner.check(result["ok"], "company return pending")
	runner.check(Insolvency.close_company()["ok"], "company sells AR in liquidation")
	var cash := Ledger.cash(ent)
	GameState.data["clock"]["minutes"] = int(result["due"])
	Ecommerce.handle("eco.return_refund", {"po": id, "return": 0})
	runner.eq(Ledger.cash(ent), cash, "supplier cannot repay sold AR")
	runner.eq(Ledger.balance(ent, "accounts_receivable"), 0, "no negative return receivable")
	runner.eq(_po(id)["returns"][0]["status"], "sold_to_collector", "honest terminal return status")
	runner.check(Ledger.check_balanced(), "liquidated supplier refund balanced")


func test_cancelled_net_fee_not_paid_again_after_liquidation() -> void:
	Company.register("Cancel Closure", "ecommerce", "22 Founders Lane")
	Company.open_business_account(1000)
	var ent := GameState.company_id()
	var id := _buy(true)
	runner.check(Ecommerce.cancel_purchase(id)["ok"], "cancel net invoice")
	Insolvency.close_company()
	var cash := Ledger.cash(ent)
	Ecommerce.handle("eco.ap_due", {"po": id})
	runner.eq(Ledger.cash(ent), cash, "settled cancellation fee cannot be paid twice")
	runner.eq(Ledger.balance(ent, "accounts_payable"), 0, "closed AP stays zero")
	runner.check(Ledger.check_balanced(), "liquidated cancellation balanced")


func test_coop_zero_fee_cancellation_removes_net_due() -> void:
	Company.register("Zero Fee", "ecommerce", "22 Founders Lane")
	Company.open_business_account(1000)
	GameState.set_flag("supplier_aurelia_makers")
	var ent := GameState.company_id()
	var id := _buy(true, "aurelia_makers", "phone_stand", 40)
	var cash := Ledger.cash(ent)
	runner.eq(Ecommerce.cancel_purchase(id)["fee"], 0, "co-op cancellation fee override")
	runner.eq(Ledger.balance(ent, "accounts_payable"), 0, "zero-fee invoice entirely removed")
	runner.check(Sim.pending("eco.ap_due").is_empty(), "zero-fee payment reminder cancelled")
	Ecommerce.handle("eco.ap_due", {"po": id})
	runner.eq(Ledger.cash(ent), cash, "stale due reminder cannot charge anything")
	runner.check(Ledger.check_balanced(), "zero-fee cancellation balanced")


func test_invalid_return_and_insufficient_freight_have_no_side_effects() -> void:
	var id := _buy()
	_arrive(id)
	for qty in [0, -1, 51]:
		runner.check(not Ecommerce.return_purchase(id, qty)["ok"], "invalid return quantity blocked")
	Ledger.expense("player", "other", Ledger.cash("player"), "Freight affordability fixture")
	var seq := int(GameState.data["ledger"]["seq"])
	runner.check(not Ecommerce.return_purchase(id, 1)["ok"], "return shipping must be affordable")
	runner.eq(GameState.data["ledger"]["seq"], seq, "failed return creates no receivable or freight expense")
	runner.eq(Ecommerce.stock("riverside_studio", "wireless_earbuds"), 50, "failed return cannot remove stock")
	runner.check(not _po(id).has("returns"), "failed return creates no scheduled refund")
	runner.check(Ledger.check_balanced(), "failed return balanced")
