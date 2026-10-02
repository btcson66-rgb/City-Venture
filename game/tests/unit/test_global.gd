extends RefCounted
## Actual ecommerce lifecycle, foreign books, refunds, closure and reproducible FX paths.

var runner


func _setup() -> String:
	Company.register("Global Goods", "retail_online", "22 Founders Lane")
	Company.open_business_account(15000)
	GameState.data["world"]["year"] = 9
	GlobalMarket.open_bank()
	GlobalMarket.open_store("northridge")
	var ent := GameState.company_id()
	Ecommerce._add_stock("riverside_studio", "wireless_earbuds", 20, 18.0, 0.0)
	Ledger.post(ent, "Test stock fixture", [{"acct": "inventory", "dr": 360}, {"acct": "cash", "cr": 360}])
	Ecommerce.create_listing("wireless_earbuds", 60.0, "self", 0.9)
	var listing := Ecommerce.listing_for("wireless_earbuds")
	GlobalMarket.set_price("northridge", str(listing["id"]), 60.0)
	return ent


func _order() -> Dictionary:
	var listing := Ecommerce.listing_for("wireless_earbuds")
	Ecommerce._h_order_place({"listing": listing["id"], "region": "northridge"})
	var id := "#%d" % int(Ecommerce.E()["counters"]["order"])
	return Ecommerce.E()["orders"][id]


func _deliver(o: Dictionary) -> void:
	Ecommerce.pack_orders("riverside_studio")
	Ecommerce.courier_pickup("riverside_studio", "economy")
	Ecommerce._h_pickup({"ids": [o["id"]]})
	GameState.data["clock"]["minutes"] = int(o["ship"]["eta"])
	Ecommerce._h_deliver({"order": o["id"]})


func test_fx_seeded_walk_bounds_mean_reversion_and_history() -> void:
	var start := FX.rate("NRD")
	var day := Clock.day_index()
	FX.on_day(day + 200)
	var path: Array = FX.S()["history"]["NRD"].duplicate(true)
	for point in path:
		runner.check(float(point["rate"]) >= start * 0.5 and float(point["rate"]) <= start * 2.0, "bounded quote")
	runner.check(absf(FX.rate("NRD") - start) < start * 0.15, "normal path stays near its mean")
	GameState.data.erase("fx")
	FX.on_day(day + 200)
	runner.eq(FX.S()["history"]["NRD"], path, "fixed seed reproduces path without changing gameplay RNG")
	runner.eq(FX.history("NRD", 0).size(), 0, "zero-day history empty")
	runner.eq(FX.rate("unknown"), 0, "unknown currency safe")


func test_fx_spread_and_expiring_shock() -> void:
	runner.eq(FX.to_home(100, "NRD"), 100 * FX.rate("NRD") * 0.985, "conversion deducts 1.5 percent spread")
	runner.eq(FX.to_home(100, "AUD"), 100, "home currency needs no spread")
	runner.eq(FX.to_home(-1, "NRD"), 0, "negative amount rejected")
	runner.check(FX.add_shock("NRD", 4.0, 3), "temporary volatility accepted")
	FX.on_day(Clock.day_index() + 4)
	runner.check(FX.S()["shocks"].is_empty(), "crisis effect expires")


func test_account_and_store_requirements_are_idempotent() -> void:
	runner.check(not GlobalMarket.open_bank()["ok"], "unregistered cannot open account")
	var ent := _setup()
	var cash := Ledger.cash(ent)
	runner.check(GlobalMarket.open_bank()["ok"], "existing account is usable")
	GlobalMarket.open_store("northridge")
	runner.eq(Ledger.cash(ent), cash, "already completed actions never charge twice")
	GameState.data["world"]["year"] = 8
	runner.check(not GlobalMarket.open_store("auroria")["ok"], "chapter 13 unlock enforced")
	GameState.set_flag("global_markets_open")
	runner.check(GlobalMarket.open_store("auroria")["ok"], "future chapter can unlock markets")


func test_overseas_lifecycle_keeps_foreign_units_until_conversion() -> void:
	var ent := _setup()
	var o := _order()
	runner.eq(o["currency"], "NRD", "local currency locked at order")
	_deliver(o)
	runner.eq(o["ship"]["method"], "international_economy", "actual international courier method")
	runner.check(int(o["ship"]["eta"]) - int(o["ship"]["shipped"]) >= 7 * Clock.DAY, "cannot fast-track abroad through tutorial")
	runner.eq(GlobalMarket.balance(ent, "NRD")["receivable"], 54.0, "foreign sale less fee awaits payout")
	runner.eq(Ledger.balance(ent, "fx_gain_loss"), 0, "delivery does not realize exchange gain")
	GlobalMarket.payout(ent)
	runner.eq(GlobalMarket.balance(ent, "NRD")["wallet"], 0, "new receipt respects payout hold")
	GameState.data["clock"]["minutes"] += 3 * Clock.DAY
	GlobalMarket.payout(ent)
	runner.eq(GlobalMarket.balance(ent, "NRD")["wallet"], 54.0, "weekly payout preserves foreign units")
	var book := Ledger.balance(ent, "fx_wallet:NRD")
	FX.S()["rates"]["NRD"] = 1.5
	var result := GlobalMarket.convert_currency(ent, "NRD")
	runner.eq(result["cash"], 54.0 * 1.5 * 0.985, "cash uses current rate less spread")
	runner.eq(result["gain_loss"], result["cash"] - book, "realized gain uses historical book value")
	runner.eq(-Ledger.balance(ent, "fx_gain_loss"), result["gain_loss"], "gain appears in ledger")
	runner.check(not GlobalMarket.convert_currency(ent, "NRD")["ok"], "no double conversion")
	runner.check(Ledger.check_balanced(), "complete cycle balances")


func test_automatic_conversion_and_exchange_loss() -> void:
	var ent := _setup()
	var o := _order()
	_deliver(o)
	company_auto(true)
	GameState.data["clock"]["minutes"] += 3 * Clock.DAY
	FX.S()["rates"]["NRD"] = 0.8
	GlobalMarket.payout(ent)
	runner.eq(GlobalMarket.balance(ent, "NRD")["wallet"], 0, "automatic conversion consumes payout")
	runner.check(Ledger.balance(ent, "fx_gain_loss") > 0, "lower quote realizes an expense")
	runner.check(Ledger.check_balanced(), "loss balances")


func company_auto(on: bool) -> void:
	GlobalMarket.company()["auto_fx"] = on


func test_refund_before_payout_reverses_receipt_and_stock() -> void:
	var ent := _setup()
	var o := _order()
	_deliver(o)
	o["status"] = "return_requested"
	runner.check(Ecommerce.resolve_return(str(o["id"]), "refund")["ok"], "foreign refund uses actual returns flow")
	runner.eq(GlobalMarket.balance(ent, "NRD")["receivable"], 0, "refund removes foreign amount")
	runner.eq(Ecommerce.stock("riverside_studio", "wireless_earbuds"), 20, "resellable stock restored")
	GameState.data["clock"]["minutes"] += 3 * Clock.DAY
	GlobalMarket.payout(ent)
	runner.eq(GlobalMarket.balance(ent, "NRD")["wallet"], 0, "refunded sale never pays twice")
	runner.check(Ledger.check_balanced(), "refund balances")


func test_paid_refund_cannot_spend_another_orders_unpaid_receipt() -> void:
	var ent := _setup()
	var first := _order()
	_deliver(first)
	GameState.data["clock"]["minutes"] += 3 * Clock.DAY
	GlobalMarket.payout(ent)
	GlobalMarket.convert_currency(ent, "NRD")
	var second := _order()
	_deliver(second)
	var outstanding := float(GlobalMarket.balance(ent, "NRD")["receivable"])
	first["status"] = "return_requested"
	Ecommerce.resolve_return(str(first["id"]), "refund")
	runner.eq(GlobalMarket.balance(ent, "NRD")["receivable"], outstanding, "paid refund repurchases FX instead of taking second receipt")
	GameState.data["clock"]["minutes"] += 3 * Clock.DAY
	GlobalMarket.payout(ent)
	runner.eq(GlobalMarket.balance(ent, "NRD")["wallet"], 54.0, "second order pays its correct units")
	runner.check(Ledger.check_balanced(), "cross-order refund balances")


func test_price_boundaries_and_rational_profit_with_risk() -> void:
	var ent := _setup()
	var l := Ecommerce.listing_for("wireless_earbuds")
	runner.check(not GlobalMarket.set_price("northridge", str(l["id"]), -1)["ok"], "negative price rejected")
	runner.check(not GlobalMarket.set_price("northridge", str(l["id"]), INF)["ok"], "infinite price rejected")
	runner.check(not GlobalMarket.set_price("northridge", str(l["id"]), 100000)["ok"], "unreasonable price rejected")
	runner.check(GlobalMarket.demand("northridge", l) > 0, "reasonable priced strategy attracts orders")
	var o := _order()
	var margin := FX.to_home(54.0, "NRD") - 18.0 - 0.6 - Ecommerce.ship_cost(o, "economy")
	runner.check(margin > 0, "reasonable sale covers unit, packing and international freight")
	FX.S()["rates"]["NRD"] = 0.55
	runner.check(FX.to_home(54.0, "NRD") - 18.0 - 0.6 - Ecommerce.ship_cost(o, "economy") < 0, "currency risk can eliminate profit")
	runner.check(Ledger.check_balanced(), "pricing does not invent money")
	var _u := ent


func test_company_closure_cancels_shipments_and_foreign_receipts() -> void:
	var ent := _setup()
	var delivered := _order()
	_deliver(delivered)
	var waiting := _order()
	Ecommerce.pack_orders("riverside_studio")
	Insolvency.state()["entity"] = ent
	runner.check(Insolvency.close_company()["ok"], "actual company closure")
	Ecommerce._h_deliver({"order": waiting["id"]})
	GlobalMarket.payout(ent)
	runner.eq(waiting["status"], "cancelled", "closed company's packed parcel cancelled")
	runner.eq(Ledger.balance(ent, "fx_wallet:NRD"), 0, "foreign wallet liquidated once")
	runner.eq(Ledger.balance(ent, "fx_receivable:NRD"), 0, "foreign receipts cannot arrive twice")
	runner.check(not GlobalMarket.convert_currency(ent, "NRD")["ok"], "closed company cannot convert again")
	runner.check(Ledger.check_balanced(), "closure balances")
	var _u := delivered


func test_old_save_and_fx_rng_roundtrip() -> void:
	_setup()
	FX.on_day(Clock.day_index() + 5)
	var data: Dictionary = JSON.parse_string(JSON.stringify(GameState.data))
	FX.on_day(Clock.day_index() + 10)
	var expected := FX.rate("NRD")
	GameState.data = SaveSystem._migrate(data)
	FX.on_day(Clock.day_index() + 10)
	runner.eq(FX.rate("NRD"), expected, "FX random stream survives JSON save/load")
	GameState.data.erase("fx")
	GameState.data.erase("global_market")
	GameState.data = SaveSystem._migrate(GameState.data)
	runner.check(FX.rate("NRD") > 0, "old save gets currency quotes")
	runner.check(not GlobalMarket.company()["bank"], "old save never silently buys account")
	runner.check(Ledger.check_balanced(), "old saved books unchanged")
