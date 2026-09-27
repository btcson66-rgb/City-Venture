extends RefCounted
## Economy core: ledger, purchasing, inventory, listings, demand, fulfilment, payouts, returns, month close.

var runner


func _advance_until(pred: Callable, max_hours := 24 * 10) -> bool:
	for i in max_hours:
		if pred.call():
			return true
		Clock.advance(60)
	return pred.call()


func _stock_and_list(product := "wireless_earbuds", qty := 50, price := 39.0) -> String:
	var r := Ecommerce.buy("tradelink_wholesale", product, qty)
	runner.check(r.get("ok", false), "buy ok: %s" % str(r))
	_advance_until(func(): return Ecommerce.stock("riverside_studio", product) >= qty)
	var l := Ecommerce.create_listing(product, price, "self")
	runner.check(l.get("ok", false), "listing ok")
	return l.get("listing_id", "")


func test_data_is_valid() -> void:
	var errs := DataDB.validate()
	runner.check(errs.is_empty(), "DataDB.validate: " + str(errs))


func test_opening_balance_and_double_entry() -> void:
	runner.eq(Ledger.cash("player"), 30000.0, "start cash")
	runner.check(Ledger.check_balanced(), "ledger balanced at start")
	Ledger.expense("player", "coffee", 4.5, "Flat white")
	runner.eq(Ledger.cash("player"), 29995.5, "cash after coffee")
	runner.check(Ledger.check_balanced(), "still balanced")


func test_moq_and_cash_checks() -> void:
	var r := Ecommerce.buy("tradelink_wholesale", "wireless_earbuds", 10)
	runner.check(not r["ok"], "below MOQ must fail")
	r = Ecommerce.buy("tradelink_wholesale", "wireless_earbuds", 50)
	runner.check(r["ok"], "MOQ purchase ok")
	runner.eq(Ledger.cash("player"), 30000.0 - 900.0, "cash reduced by 50 × $18")
	runner.eq(Ledger.balance("player", "inventory_in_transit"), 900.0, "in transit asset")
	r = Ecommerce.buy("lumina_direct", "wireless_earbuds", 2000)
	runner.check(not r["ok"], "cannot exceed apartment capacity / cash")


func test_po_arrives_into_inventory() -> void:
	Ecommerce.buy("tradelink_wholesale", "wireless_earbuds", 50)
	runner.eq(Ecommerce.stock("riverside_studio", "wireless_earbuds"), 0, "nothing before lead time")
	var ok := _advance_until(func(): return Ecommerce.stock("riverside_studio", "wireless_earbuds") == 50)
	runner.check(ok, "stock arrives within lead time")
	runner.eq(Ledger.balance("player", "inventory"), 900.0, "inventory valued at cost")
	runner.eq(Ledger.balance("player", "inventory_in_transit"), 0.0, "in transit cleared")
	runner.eq(GameState.stat("stock_received"), 1.0, "stat stock_received")


func test_listing_requires_stock_and_price_moves_demand() -> void:
	var r := Ecommerce.create_listing("wireless_earbuds", 39.0, "self")
	runner.check(not r["ok"], "cannot list without product in hand")
	var lid := _stock_and_list()
	var l: Dictionary = GameState.data["ecommerce"]["listings"][lid]
	var base := Ecommerce.lambda_day(l)
	runner.check(base > 0.5, "some demand at a fair price (%.2f/day)" % base)
	Ecommerce.set_price(lid, 60.0)
	runner.check(Ecommerce.lambda_day(l) < base * 0.7, "higher price → lower demand")
	Ecommerce.set_price(lid, 39.0)
	Ecommerce.set_ad_budget(lid, 15.0)
	runner.check(Ecommerce.lambda_day(l) > base * 1.4, "ads increase demand")


func test_order_to_delivery_profit_is_not_cash() -> void:
	_stock_and_list()
	var got := _advance_until(func(): return GameState.stat("orders_placed") >= 3, 24 * 6)
	runner.check(got, "orders arrive from the demand model")
	var cash_before := Ledger.cash("player")
	var packed := Ecommerce.pack_orders("riverside_studio")
	runner.check(packed >= 1, "packed orders")
	var r := Ecommerce.courier_pickup("riverside_studio", "economy")
	runner.check(r["ok"], "courier booked")
	_advance_until(func(): return GameState.stat("orders_delivered") >= 1, 24 * 5)
	runner.check(GameState.stat("orders_delivered") >= 1, "delivered")
	var rev := -Ledger.balance("player", "revenue")
	runner.check(rev > 30.0, "revenue recognised on delivery (%.2f)" % rev)
	runner.check(Ledger.balance("player", "marketplace_balance") > 0.0, "money sits in marketplace balance")
	runner.check(Ledger.cash("player") < cash_before, "cash did NOT go up on delivery (Profit ≠ Cash)")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_weekly_payout_moves_balance_to_cash() -> void:
	_stock_and_list()
	_advance_until(func(): return GameState.stat("orders_placed") >= 2, 24 * 6)
	Ecommerce.pack_orders("riverside_studio")
	Ecommerce.courier_pickup("riverside_studio", "express")
	_advance_until(func(): return GameState.stat("orders_delivered") >= 1, 24 * 4)
	var mb := Ledger.balance("player", "marketplace_balance")
	runner.check(mb > 0, "balance to pay out")
	var cash0 := Ledger.cash("player")
	_advance_until(func(): return GameState.stat("payouts") >= 1, 24 * 10)
	runner.check(GameState.stat("payouts") >= 1, "payout happened on a Monday")
	runner.check(Ledger.cash("player") > cash0 - 200.0, "cash received")
	runner.eq(Clock.weekday(Ledger.entries("player", 500).filter(func(e): return e["memo"] == "ShopLane weekly payout")[0]["t"]), 1, "payout weekday is Monday")


func test_dropoff_at_postpoint() -> void:
	_stock_and_list()
	_advance_until(func(): return GameState.stat("orders_placed") >= 1, 24 * 6)
	Ecommerce.pack_orders("riverside_studio")
	var n := Ecommerce.carry_parcels("riverside_studio")
	runner.check(n >= 1, "carrying parcels")
	var r := Ecommerce.dropoff_carried("economy")
	runner.check(r["ok"] and int(r["count"]) == n, "dropped off")
	runner.eq(Ecommerce.carried_count(), 0, "hands empty")
	runner.check(GameState.stat("orders_shipped") >= 1, "shipped")


func test_return_refund_and_replacement() -> void:
	_stock_and_list()
	_advance_until(func(): return GameState.stat("orders_placed") >= 2, 24 * 6)
	Ecommerce.pack_orders("riverside_studio")
	Ecommerce.courier_pickup("riverside_studio", "express")
	GameState.set_flag("force_next_return")
	_advance_until(func(): return not EventEngine.pending().is_empty(), 24 * 8)
	var inst := EventEngine.next_pending()
	runner.eq(inst.get("id", ""), "customer_return_first", "first return uses the first-issue event")
	var oid: String = inst["ctx"]["order"]
	var refunds0 := Ledger.balance("player", "refunds")
	var r := EventEngine.choose(inst["iid"], "refund")
	runner.check(r["ok"], "refund applied")
	runner.check(Ledger.balance("player", "refunds") > refunds0, "refund booked as contra-revenue")
	runner.eq(GameState.data["ecommerce"]["orders"][oid]["status"], "refunded", "order refunded")
	runner.check(GameState.flag("first_issue_resolved"), "story flag set")
	runner.check(Ledger.check_balanced(), "balanced after refund")


func test_replacement_needs_stock_of_that_product() -> void:
	# regression: "Send a replacement" used to check for *any* stock, so it stayed enabled when the
	# returned product was sold out, failed, and left the (non-closable) decision stuck open
	_stock_and_list()
	_advance_until(func(): return GameState.stat("orders_placed") >= 2, 24 * 6)
	Ecommerce.pack_orders("riverside_studio")
	Ecommerce.courier_pickup("riverside_studio", "express")
	GameState.set_flag("force_next_return")
	_advance_until(func(): return not EventEngine.pending().is_empty(), 24 * 8)
	var inst := EventEngine.next_pending()
	var rep := {}
	for c in DataDB.events[inst["id"]]["choices"]:
		if c["id"] == "replace":
			rep = c
	runner.check(EventEngine.choice_available(rep, inst["ctx"]), "replacement offered while that product is in stock")
	# sell out that product; other stock remains
	var pid: String = inst["ctx"]["product_id"]
	GameState.data["ecommerce"]["inventory"]["riverside_studio"][pid]["qty"] = 0
	GameState.data["ecommerce"]["inventory"]["riverside_studio"]["water_bottle"] = {"qty": 10, "avg_cost": 5.0}
	runner.check(Ecommerce.total_units() > 0, "other stock still on hand")
	runner.check(not EventEngine.choice_available(rep, inst["ctx"]), "replacement disabled when that product is sold out")
	var r := EventEngine.choose(inst["iid"], "refund")
	runner.check(r["ok"], "refund still resolves the decision")
	runner.check(EventEngine.pending().is_empty(), "decision closed")


func test_month_close_report() -> void:
	_stock_and_list()
	# run the business to the end of June with a simple policy: pack + courier every evening
	while Clock.date()["month"] == 6:
		Clock.advance(60)
		if Clock.hour() == 18:
			Ecommerce.pack_orders("riverside_studio")
			Ecommerce.courier_pickup("riverside_studio", "economy")
		for q in EventEngine.pending().duplicate():
			EventEngine.choose(q["iid"], DataDB.events[q["id"]]["choices"][0]["id"])
	var reps: Array = GameState.data["reports"]["month_closes"]
	runner.eq(reps.size(), 1, "one month close")
	var rep: Dictionary = reps[0]["entities"]["player"]
	for k in ["revenue", "cogs", "opex_total", "rent", "advertising", "shipping", "refunds", "profit", "cash_close"]:
		runner.check(rep.has(k), "report has " + k)
	runner.check(rep["revenue"] > 0, "revenue in month")
	runner.eq(rep["rent_home"], 1250.0, "rent charged once in June")
	runner.check(absf(rep["profit"] - rep["cash_change"]) > 1.0, "profit differs from cash change (AR / inventory)")
	runner.check(Ledger.check_balanced(), "ledger balanced at month end")


func test_rent_due_day_14() -> void:
	var cash0 := Ledger.cash("player")
	while Clock.day_index() < 14 or Clock.hour() < 10:
		Clock.advance(60)
	runner.eq(GameState.data["living"]["rent_history"].size(), 1, "rent paid on the 14th")
	runner.check(Ledger.cash("player") < cash0 - 1250.0, "rent + living deducted")


func test_seller_cap_pauses_until_registration() -> void:
	_stock_and_list("phone_stand", 80, 12.0)
	GameState.data["ecommerce"]["month_gmv"][Clock.month_key()] = 2499.0
	Ecommerce._h_order_place({"listing": Ecommerce.listing_for("phone_stand")["id"]})
	runner.check(Ecommerce.is_capped(), "capped")
	runner.check(not Ecommerce.listing_for("phone_stand")["active"], "listing paused by cap")
	var r := Company.register("Test Goods", "retail_online", "Riverside Tower 7C")
	runner.check(r["ok"], "registered")
	runner.check(Ecommerce.listing_for("phone_stand")["active"], "cap lifted after registration")
