extends RefCounted
## Chapters 7–9 at the logic level: the Supply Shock (Year 3), the Green Shift (Year 4) and the Clearing Crisis
## (Year 5) each change the economy through data, and each chapter is finished with the systems it introduces.

var runner


func _check() -> void:
	StoryEngine.check()


func _active(id: String) -> bool:
	return id in StoryEngine.St()["active"]


func _done(id: String) -> bool:
	return id in StoryEngine.St()["done"]


func _setup() -> void:
	Company.register("Era Test Co", "ecommerce", "22 Founders Lane")
	Company.open_business_account(20000.0)
	GameState.set_flag("business_account_opened")
	Ecommerce.buy("tradelink_wholesale", "phone_stand", 80)
	Clock.advance(3 * Clock.DAY)
	Ecommerce.create_listing("phone_stand", 12.0, "studio")


func test_supply_shock_changes_costs_and_chapter_7_plays_through() -> void:
	_setup()
	var cost_before := Ecommerce.unit_cost("tradelink_wholesale", "phone_stand")
	var ship_before := Ecommerce.ship_cost({"product": "phone_stand"}, "economy")
	StoryEngine.start_chapter("ch7_supply_shock")
	runner.eq(World.year(), 3, "Year 3")
	runner.check(Ecommerce.unit_cost("tradelink_wholesale", "phone_stand") > cost_before, "local prices rise")
	runner.check(absf(Ecommerce.unit_cost("lumina_direct", "phone_stand") / 2.10 - 1.25) < 0.01, "imports rise more")
	runner.check(Ecommerce.ship_cost({"product": "phone_stand"}, "economy") > ship_before * 1.5, "couriers charge more")
	var r := Ecommerce.buy("tradelink_wholesale", "phone_stand", 80)
	runner.check(r["ok"] and int(r.get("eta", 0)) - Clock.now() >= 2 * Clock.DAY, "and lead times stretch (%s)" % str(r.get("error", "")))
	InfoModal.news().free()
	_check()
	runner.check(_active("ch7_ken"), "news read → talk to Ken")
	# the local co-op: no surcharge, one-day delivery, only once unlocked
	runner.check(not World.supplier_available("aurelia_makers"), "the co-op isn't open yet")
	var inst := EventEngine.trigger("supply_shock_plan", EventEngine.bind(DataDB.events["supply_shock_plan"]))
	EventEngine.choose(inst["iid"], "local")
	_check()
	runner.check(World.supplier_available("aurelia_makers"), "the co-op is a supplier now")
	runner.eq(World.cost_mult("aurelia_makers"), 1.0, "made in the city: no shock surcharge")
	runner.check(Ecommerce.buy("aurelia_makers", "phone_stand", 40)["ok"], "and can be ordered from")
	_check()
	runner.check(_done("ch7_stock") and _active("ch7_price"), "plan chosen, 100+ units covered → reprice")
	var l := Ecommerce.listing_for("phone_stand")
	Ecommerce.set_price(l["id"], float(l["price"]) + 2.0)
	_check()
	runner.check(_active("ch7_close"), "repriced → close a month in profit")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_chapter_events_bind_their_product_and_supplier() -> void:
	_setup()
	StoryEngine.start_chapter("ch7_supply_shock")
	# a chapter fires its events with no context (`{"do": "event"}`): the event still binds the product and supplier
	var inst := EventEngine.trigger("supply_shock_plan")
	runner.eq(str(inst["ctx"].get("product_id", "")), "phone_stand", "the best seller is bound")
	runner.eq(str(inst["ctx"].get("supplier_id", "")), "tradelink_wholesale", "the most-used supplier is bound")
	runner.check(int(inst["ctx"].get("moq", 0)) > 0 and str(inst["ctx"].get("unit_cost", "")) != "", "MOQ and unit cost are filled in")
	runner.check(not EventEngine.fill("{product} costs {unit_cost}, MOQ {moq}", inst["ctx"]).contains("{"), "no placeholder is left on screen")
	runner.check(EventEngine.choose(inst["iid"], "stock_up")["ok"], "stocking up buys the bound product")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_green_shift_levy_and_grant() -> void:
	_setup()
	World.set_year(4)
	runner.check(World.supplier_available("verdant_supply"), "Verdant Supply opens in Year 4")
	runner.eq(Ecommerce.packaging_extra(), 0.4, "plastic padding pays the levy")
	runner.check(Company.green_grant_block() != "", "no grant without recycled packaging and a green product")
	Ecommerce.set_packaging("recycled")
	runner.eq(Ecommerce.packaging_extra(), 0.25, "recycled paper costs a little, no levy")
	var rb := Ecommerce.buy("verdant_supply", "solar_lamp", 30)
	runner.check(rb["ok"], "solar lamps bought (%s)" % str(rb.get("error", "")))
	Clock.advance(3 * Clock.DAY)
	Ecommerce.create_listing("solar_lamp", 42.0, "studio")
	runner.check(Cond.eval("listed:solar_lamp"), "a green product on sale")
	runner.check(Ecommerce.demand_mult("solar_lamp") > Ecommerce.demand_mult("phone_stand"), "green products sell better this year")
	var cash := Ledger.cash(GameState.company_id())
	var g := Company.claim_green_grant()
	runner.check(g["ok"], "grant approved")
	runner.check(absf(Ledger.cash(GameState.company_id()) - cash - 3000.0) < 0.01, "$3,000 lands in the company account")
	runner.check(not Company.claim_green_grant()["ok"], "only once")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_clearing_crisis_holds_imports_until_paid() -> void:
	_setup()
	World.set_year(5)
	runner.check(Ecommerce.needs_settlement("lumina_direct"), "imports need their payment to clear")
	runner.check(not Ecommerce.needs_settlement("tradelink_wholesale"), "local suppliers don't")
	runner.check(Ecommerce.settlement_block("stablecoin_settlement") != "", "digital dollars need an exchange account")
	var r := Ecommerce.buy("lumina_direct", "phone_stand", 400)
	runner.check(r["ok"], "import ordered by wire (%s)" % str(r.get("error", "")))
	if not r["ok"]:
		return
	var po: Dictionary = Ecommerce.E()["purchase_orders"][r["po_id"]]
	runner.eq(str(po["status"]), "awaiting_payment", "the supplier waits for the money")
	runner.check(int(po["settlement"]["clears"]) - Clock.now() >= 5 * Clock.DAY, "a wire takes days to land")
	runner.eq(Ecommerce.incoming_units_of("phone_stand"), 400, "still counted as on the way")
	var sw := Ecommerce.switch_settlement(r["po_id"], "letter_of_credit")
	runner.check(sw["ok"], "switched to a letter of credit")
	Clock.advance(2 * Clock.DAY + 60)
	runner.eq(str(po["status"]), "in_transit", "paid → shipped")
	runner.eq(int(GameState.stat("import_cleared")), 1, "one import cleared")
	while str(po["status"]) != "delivered" and Clock.day_index() < 60:
		Clock.advance(12 * 60)
	runner.eq(int(GameState.stat("import_received")), 1, "and delivered")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_chapter_7_never_soft_locks_on_losses() -> void:
	_setup()
	StoryEngine.start_chapter("ch7_supply_shock")
	StoryEngine.St()["active"] = ["ch7_close"]   # straight to the month-end objective
	for o in ["ch7_news", "ch7_ken", "ch7_stock", "ch7_price"]:
		StoryEngine.St()["done"].append(o)
	var cid := GameState.company_id()
	for i in 2:
		Ledger.expense(cid, "other", 3000.0, "a bad month")
		Clock.advance(1)   # the close covers entries before now
		var d := Clock.date()
		MonthClose.run(int(d["year"]), int(d["month"]))
		if i == 0:
			runner.check(not GameState.flag("ch7_month_profit"), "one losing month: try again next month")
	runner.check(GameState.flag("ch7_month_profit"), "two losing months: the chapter moves on anyway")
	_check()
	runner.check("ch7_supply_shock" in StoryEngine.St()["chapters_done"], "chapter 7 complete, no soft-lock")
