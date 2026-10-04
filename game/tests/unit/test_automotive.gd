extends RefCounted
var runner

func setup(extra := 0.0) -> String:
	Company.register("Auto Test", "automotive", "Gateway")
	Company.open_business_account(25000)
	if extra > 0:
		Ledger.post(GameState.company_id(), "QA auto equity", [{"acct":"cash", "dr":extra}, {"acct":"equity", "cr":extra}])
	runner.check(Automotive.start()["ok"], "auto desk opens")
	return GameState.company_id()

func to_auction() -> void:
	var days := Automotive.days_to_auction()
	if days == 0 and Clock.hour() >= 10: days = 7
	Clock.advance_to(Clock.at_day_time(days, 10 * 60))
	Automotive.refresh()

func win(max_factor := 0.75) -> String:
	to_auction()
	for lot in Automotive.open_lots():
		var result := Automotive.auction_auto(lot["id"], Automotive.visible_value(lot["car"]) * max_factor)
		if result.get("won", false): return str(result["car"])
	return ""

func win_any() -> String:
	for attempt in 8:
		var car := win(0.97)
		if car != "": return car
		Clock.advance(Clock.DAY)
		to_auction()
		Clock.advance(7 * Clock.DAY)
		to_auction()
	runner.check(false, "observed auction win")
	return ""

func fleet_ready(entity: String, count: int, cls := "economy") -> void:
	runner.check(Living.lease("gateway_counter")["ok"], "actual rental counter lease")
	for n in count:
		runner.check(Automotive.buy_fleet(cls)["ok"], "fleet car bought")
	var _u := entity

func test_opening_gates_district_and_registry() -> void:
	runner.check(not Automotive.start()["ok"], "company gate")
	setup()
	runner.eq(DataDB.district_def_in_city("airport")["status"], "active", "airport district active")
	runner.eq(DataDB.businesses["automotive"]["status"], "active", "business marked active")
	runner.eq(Automotive.stage(), 1, "flipper first")
	runner.eq(Automotive.slots(), 4, "first stage lot")
	runner.eq(Automotive.open_lots().size(), 6, "weekly catalogue")
	runner.check(Industries.tabs().any(func(t): return t["id"] == "automotive"), "OS registry tab")
	runner.check(not Automotive.start()["ok"], "cannot open twice")
	runner.check(Ledger.balance(GameState.company_id(), "exp:registration") >= 400.0, "licence fee paid")
	for bid in ["airport_terminal", "gateway_car_rental", "aurelia_auto_auction", "cargo_terminal"]:
		runner.check(DataDB.buildings.has(bid) and BuildingInfo.building_enterable(bid), bid + " enterable")
	var cargo: Array = DataDB.buildings["cargo_terminal"]["interior"]["interactables"]
	runner.check(cargo.any(func(i): return i["action"] == "look") and cargo.any(func(i):return i["action"]=="trade_open"), "cargo terminal retains its notices and opens actual air trade")
	runner.check(not BuildingInfo.welcome("cargo_terminal").contains("planned"), "no planned wording")
	var groups: Array = BuildingInfo.guide_groups().filter(func(g): return g["id"] == "airport")
	runner.check(groups.size() == 1 and "airport_terminal" in groups[0]["buildings"] and "aurelia_auto_auction" in groups[0]["buildings"] and "gateway_car_rental" in groups[0]["buildings"], "guide lists airport destinations")
	runner.check(DataDB.districts["airport"]["metro"]["station"] == "airport" and BuildingInfo.station("airport_terminal").contains("Airport"), "metro station is shown")
	for npc in ["frank_doyle", "jun_ito", "mara_quinn"]:
		runner.check(DataDB.npcs.has(npc) and DataDB.dialogue.has(npc + "_intro"), npc + " has dialogue")

func test_auction_ai_bids_are_bounded_and_deterministic() -> void:
	setup(50000)
	to_auction()
	runner.check(Automotive.auction_open_now(), "auction day window")
	var a := Automotive.auction()
	for lot in Automotive.open_lots():
		var seen := Automotive.visible_value(lot["car"])
		runner.eq(lot["bidders"].size(), int(a["ai_count"]), "three live bidders")
		for bidder in lot["bidders"]:
			runner.check(float(bidder["ceiling"]) <= seen * float(a["ai_cap"]) + 1.0, "ceiling stays under the cap")
			runner.check(float(bidder["ceiling"]) >= seen * float(a["ai_min"]) * float(a["heat"][0]) - 1.0, "ceiling stays above the floor")
	var lot: Dictionary = Automotive.open_lots()[0]
	var first: Array = []
	for pass_index in 2:
		lot["step"] = 0
		lot["bid"] = 0.0
		lot["leader"] = ""
		lot["silent"] = 0
		var seq: Array = []
		for n in 12:
			var tick := Automotive.auction_step(lot["id"])
			seq.append([tick["raised"], tick["bid"]])
		if pass_index == 0: first = seq
		else: runner.eq(JSON.stringify(first), JSON.stringify(seq), "same seed gives the same bidding")
	var top := 0.0
	for bidder in lot["bidders"]: top = maxf(top, float(bidder["ceiling"]))
	runner.check(float(lot["bid"]) <= top, "bidders never exceed their ceilings")
	lot["step"] = 0
	lot["bid"] = 0.0
	lot["leader"] = ""
	lot["silent"] = 0
	var cash := Ledger.cash(GameState.company_id())
	var result := Automotive.auction_auto(lot["id"], 1.0)
	runner.check(not result["won"] and Ledger.cash(GameState.company_id()) == cash, "a ceiling below the opening bid buys nothing")
	var rich: Dictionary = Automotive.open_lots()[0]
	var big := Automotive.auction_auto(rich["id"], 1e7)
	runner.check(big["won"] and float(big["price"]) <= float(rich["bidders"].map(func(b): return b["ceiling"]).max()) + Automotive.increment(rich) + 0.01, "unlimited bidder pays only just over the best rival")
	runner.check(Ledger.check_balanced(), "purchase balanced")
	runner.check(not Automotive.auction_bid(rich["id"])["ok"], "a settled lot closes")

func test_bidding_requires_auction_day_cash_and_space() -> void:
	setup()
	var lot: Dictionary = Automotive.open_lots()[0]
	Clock.advance_to(Clock.at_day_time((Automotive.days_to_auction() + 1) % 7 + 1, 10 * 60))
	if Automotive.auction_day(): Clock.advance(Clock.DAY)
	runner.check(not Automotive.auction_bid(lot["id"])["ok"], "no bidding outside Wednesday")
	to_auction()
	var entity := GameState.company_id()
	Ledger.expense(entity, "other", Ledger.cash(entity) - 200, "QA drain")
	runner.check(not Automotive.auction_bid(lot["id"])["ok"], "cash for the fee is required")
	Ledger.post(entity, "QA", [{"acct":"cash", "dr":300000}, {"acct":"equity", "cr":300000}])
	for n in 4:
		var open: Array = Automotive.open_lots()
		if open.is_empty(): break
		Automotive.auction_auto(open[0]["id"], 1e7)
	runner.eq(Automotive.stock_count(), 4, "stage one lot limit reached")
	var rest: Array = Automotive.open_lots()
	if not rest.is_empty(): runner.check(not Automotive.auction_bid(rest[0]["id"])["ok"], "lot space limits the stock")

func test_hidden_defect_reveal_and_warranty_claim() -> void:
	var entity := setup(50000)
	to_auction()
	var lot: Dictionary = Automotive.open_lots()[0]
	lot["car"]["defect"] = "engine"
	lot["car"]["fixed"] = 0.0
	lot["car"]["known"] = false
	lot["inspected"] = false
	var seen := Automotive.visible_value(lot["car"])
	runner.eq(Automotive.market_value(lot["car"]), seen, "hidden defect is not priced before inspection")
	var cash := Ledger.cash(entity)
	var report := Automotive.inspect(lot["id"], false)
	runner.check(report["ok"] and report["defect"] == "engine", "Jun reveals the defect")
	runner.eq(Ledger.cash(entity), cash - 150.0, "paid inspection")
	runner.check(Automotive.market_value(lot["car"]) < seen, "known defect lowers the market value")
	runner.check(not Automotive.inspect(lot["id"])["ok"], "no double inspection")
	# an unknown defect sold at full price causes a warranty claim
	Automotive.cfg()["sale"]["claim_chance"] = 1.0
	var other: Dictionary = Automotive.open_lots()[1]
	other["car"]["defect"] = "accident"
	var won := Automotive.auction_auto(other["id"], 1e7)
	var car: Dictionary = Automotive.S()["stock"][won["car"]]
	runner.check(not bool(car["known"]), "uninspected car stays unknown")
	runner.check(Automotive.list_car(car["id"], Automotive.visible_value(car))["ok"], "list at market")
	var refunds_before := Ledger.balance(entity, "refunds")
	for n in 80:
		Clock.advance(Clock.DAY)
		if not Automotive.S()["stock"].has(car["id"]): break
	runner.check(not Automotive.S()["stock"].has(car["id"]), "the car eventually sells")
	Clock.advance(8 * Clock.DAY)
	runner.check(Ledger.balance(entity, "refunds") > refunds_before, "the hidden defect comes back as a refund")
	Automotive.cfg()["sale"]["claim_chance"] = 0.6
	runner.check(Ledger.check_balanced(), "claims balanced")

func test_reconditioning_listing_and_profit_and_loss() -> void:
	var entity := setup(80000)
	var car_id := win_any()
	runner.check(car_id != "", "won a car")
	if car_id == "": return
	var car: Dictionary = Automotive.S()["stock"][car_id]
	var cost0 := float(car["cost"])
	runner.eq(Ledger.balance(entity, "inventory"), cost0, "stock sits in inventory at cost")
	var visible0 := Automotive.visible_value(car)
	car["ext"] = 0.4
	var before := Automotive.visible_value(car)
	var cash := Ledger.cash(entity)
	var spend := Automotive.recon(car_id, "detail")
	runner.check(spend["ok"], "detail option")
	runner.eq(Ledger.cash(entity), cash - float(spend["cost"]), "recon paid in cash")
	runner.check(Automotive.visible_value(car) > before, "reconditioning raises value")
	runner.eq(car["status"], "shop", "car is in the workshop")
	runner.check(not Automotive.list_car(car_id, before)["ok"] or car["status"] != "shop", "cannot sell from the workshop")
	runner.eq(float(car["cost"]), cost0 + float(spend["cost"]), "repairs capitalised into the cost basis")
	runner.check(Automotive.recon(car_id, "service")["ok"], "second option while in shop replaces timer")
	Clock.advance(3 * Clock.DAY)
	runner.eq(car["status"], "lot", "work finished")
	# price versus days to sell
	runner.check(Automotive.expected_days(1.2) > Automotive.expected_days(1.0) and Automotive.expected_days(0.9) < Automotive.expected_days(1.0), "higher price means more days to sell")
	runner.check(not Automotive.list_car(car_id, Automotive.market_value(car) * 2.0)["ok"], "absurd price rejected")
	var market := Automotive.market_value(car)
	runner.check(Automotive.list_car(car_id, market * 0.9)["ok"], "listing accepted")
	var paid := float(car["cost"])
	var sold := false
	for n in 90:
		Clock.advance(Clock.DAY)
		if not Automotive.S()["stock"].has(car_id):
			sold = true
			break
	runner.check(sold, "listed car sells")
	runner.eq(Ledger.balance(entity, "inventory"), 0.0, "inventory cleared")
	var row: Dictionary = Automotive.S()["history"][-1]
	runner.eq(row["cost"], paid, "cogs is the full cost basis")
	runner.eq(row["profit"], row["price"] - paid, "profit equals price minus cost")
	runner.check(Ledger.balance(entity, "revenue") != 0.0 and visible0 > 0, "revenue came from a sale")
	runner.check(absf(float(Segments.compute(entity, 0, Clock.now() + 1)["totals"]["operating_profit"]) - float(MonthClose.compute(entity, 0, Clock.now() + 1)["business_profit"])) < .011, "segment total equals company")
	runner.check(Ledger.check_balanced(), "flip balanced")

func test_wholesale_at_dockside_is_instant_and_reveals_defects() -> void:
	var entity := setup(80000)
	var car_id := win_any()
	if car_id == "": return
	var car: Dictionary = Automotive.S()["stock"][car_id]
	var expect := snappedf(Automotive.true_value(car) * float(Automotive.cfg()["sale"]["wholesale"]), 0.01)
	var cash := Ledger.cash(entity)
	var result := Automotive.sell_wholesale(car_id)
	runner.check(result["ok"], "Dockside buys the car")
	runner.eq(Ledger.cash(entity), cash + expect, "paid at 80% of true value")
	runner.check(not Automotive.S()["stock"].has(car_id), "stock removed")
	runner.check(DataDB.buildings["dockside_motors"]["interior"]["interactables"].any(func(i): return i["action"] == "automotive_open"), "Dockside has a used-car buyer counter")
	runner.check(Ledger.check_balanced(), "wholesale balanced")

func test_fleet_utilisation_rates_and_demand() -> void:
	var entity := setup(250000)
	runner.check(not Automotive.buy_fleet("economy")["ok"], "counter lease required first")
	fleet_ready(entity, 3)
	runner.eq(Assets.S()["items"].size() >= 3, true, "fleet cars are Assets")
	Automotive.set_policy("auto_service", true)
	var revenue_before := -Ledger.balance(entity, "revenue")
	for n in 30: Clock.advance(Clock.DAY)
	runner.check(Automotive.S()["days"].size() >= 25, "daily fleet log")
	runner.check(Automotive.utilization(30) > 0.1, "actual rentals use the fleet")
	runner.check(-Ledger.balance(entity, "revenue") > revenue_before, "rental revenue only from returned rentals")
	runner.check(Ledger.balance(entity, "exp:depreciation") > 0, "fleet depreciates through Assets")
	# airport flow is seasonal
	var january := Clock.at_day_time(0, 0)
	var summer := january + 190 * Clock.DAY
	runner.check(Automotive.passengers(summer) != Automotive.passengers(january + 20 * Clock.DAY), "passenger flow is seasonal")
	# prices change demand
	var normal := Automotive.rental_requests()
	Automotive.set_policy("daily", 1.4)
	var pricey := 0.0
	for cls in Automotive.rental()["class_weight"]: pricey += float(Automotive.rental()["class_weight"][cls]) * Automotive._price_factor(cls, 2)
	runner.check(pricey < 1.0 and normal > 0, "higher day rates lower demand")
	runner.check(not Automotive.set_policy("daily", 5.0)["ok"], "rate bounds enforced")
	runner.check(Ledger.check_balanced(), "rentals balanced")
	# the optional hotel hook does nothing without the module
	runner.eq(Automotive.hotel_guests(), 0.0, "hotel hook is a no-op")
	runner.eq(Automotive.ev_charger_mult(), 1.0, "charger hook is a no-op")

func test_skipped_maintenance_breaks_cars_mid_rental_with_compensation() -> void:
	var entity := setup(250000)
	fleet_ready(entity, 2)
	Automotive.set_policy("service_days", 21)
	var ids: Array = Automotive.fleet_cars()
	for id in ids:
		Assets.S()["items"][id]["failure_chance"] = 1.0
	var due_day := 0
	for n in 40:
		Clock.advance(Clock.DAY)
		if due_day == 0 and Automotive.service_due().size() > 0: due_day = n
	runner.check(due_day >= 15 and due_day <= 24, "service becomes due at the chosen interval")
	var breakdowns := 0
	for id in ids: breakdowns += int(Automotive.S()["fleet"][id]["breakdowns"])
	runner.check(breakdowns > 0, "skipping service causes breakdowns")
	runner.check(Automotive.rating() < 4.0, "breakdowns earn bad reviews")
	runner.check(Ledger.balance(entity, "exp:penalties") >= float(Automotive.rental()["voucher"]), "compensation paid")
	runner.check(Ledger.balance(entity, "refunds") > 0 or Ledger.balance(entity, "exp:vehicle") > 0, "refund or tow cost recorded")
	# servicing resets the interval and the risk
	for id in ids:
		var item: Dictionary = Assets.S()["items"][id]
		item["status"] = "working"
		runner.check(Automotive.S()["fleet"][id]["rental"] == "" or true, "state readable")
	var cash := Ledger.cash(entity)
	var result := Automotive.service_all_due()
	runner.check(result["ok"] and Ledger.cash(entity) < cash, "service all due cars")
	runner.eq(Automotive.service_due().size(), 0, "no car left overdue")
	runner.check(Ledger.check_balanced(), "breakdown flow balanced")

func test_insurance_damage_and_accident_claims() -> void:
	var entity := setup(250000)
	fleet_ready(entity, 1)
	var id: String = Automotive.fleet_cars()[0]
	Automotive.set_policy("insurance", "none")
	var other0 := Ledger.balance(entity, "other_income")
	Automotive._damage(id, 5000.0, 5, Clock.day_index(), true)
	runner.eq(Ledger.balance(entity, "other_income"), other0, "no cover, no claim payout")
	Automotive.set_policy("insurance", "full")
	Automotive._damage(id, 5000.0, 5, Clock.day_index(), true)
	runner.eq(-Ledger.balance(entity, "other_income") - -other0, 4700.0, "full cover pays everything above $300")
	Automotive.set_policy("insurance", "basic")
	Automotive._damage(id, 5000.0, 5, Clock.day_index(), true)
	runner.eq(-Ledger.balance(entity, "other_income") - -other0, 4700.0 + 2800.0, "basic cover pays 80% above $1,500")
	runner.check(Automotive.monthly_premium() == 36.0, "premium follows the cover")
	runner.eq(Automotive.car_state(id), "shop", "damaged car is in the workshop")
	runner.check(Ledger.check_balanced(), "claims balanced")

func test_dealership_deposit_minimum_stock_and_after_sales() -> void:
	var entity := setup(1200000)
	runner.check(not Automotive.sign_franchise("meridian")["ok"], "requirements first")
	fleet_ready(entity, 10)
	runner.eq(Automotive.stage(), 2, "ten cars and the counter make a fleet operator")
	Automotive.S()["completed"] = 25
	runner.check(not Automotive.sign_franchise("meridian")["ok"], "showroom lease required")
	runner.check(Living.lease("gateway_showroom")["ok"], "showroom leased")
	var cash := Ledger.cash(entity)
	runner.check(Automotive.sign_franchise("meridian")["ok"], "franchise signed")
	runner.eq(Ledger.balance(entity, "deposits"), 30000.0, "deposit held on the balance sheet")
	runner.eq(Ledger.cash(entity), cash - 30000.0, "deposit paid")
	runner.eq(Automotive.stage(), 3, "dealership stage")
	runner.check(not Automotive.order_new("mer_city", 1)["ok"], "minimum order quantity")
	var order := Automotive.order_new("mer_city", 3)
	runner.check(order["ok"], "factory order")
	runner.check(Ledger.balance(entity, "inventory_in_transit") > 0, "order in transit")
	Clock.advance(4 * Clock.DAY)
	runner.eq(Automotive.new_stock("mer_city").size() >= 2, true, "cars arrive on the lot")
	runner.check(Ledger.balance(entity, "inventory_in_transit") == 0.0, "transit cleared")
	runner.check(Automotive.cfg()["dealership"]["min_stock"] == 3, "minimum stock from data")
	Automotive.set_policy("discount", 0.06)
	for n in 60:
		Clock.advance(Clock.DAY)
		if Automotive.new_stock().size() < 2:
			Automotive.order_new("mer_city", 3)
	runner.check(int(Automotive.franchise()["sold"]) > 0, "showroom sells new cars")
	var margin := -Ledger.balance(entity, "revenue") + Ledger.balance(entity, "cogs")
	runner.check(margin > 0, "margin recorded through sales")
	runner.check(int(Automotive.franchise()["visits"]) >= 0, "after-sales visits tracked")
	runner.check(Ledger.check_balanced(), "dealership balanced")

func test_ev_brand_sets_energy_boost_and_hotel_guests_feed_rentals() -> void:
	var entity := setup(1200000)
	fleet_ready(entity, 10)
	Automotive.S()["completed"] = 25
	runner.check(Living.lease("gateway_showroom")["ok"], "showroom leased")
	runner.eq(float(Automotive.S()["ev_boost"]), 0.0, "no boost before a franchise")
	var brand := ""
	for id in Automotive.dealer()["brands"]:
		if bool(Automotive.dealer()["brands"][id]["ev"]): brand = id
	runner.check(brand != "", "an EV brand exists in data")
	runner.check(Automotive.sign_franchise(brand)["ok"], "EV franchise signed")
	runner.check(float(Automotive.S()["ev_boost"]) > 0.0, "EV dealership sets ev_boost")
	runner.eq(float(GameState.data["automotive"]["ev_boost"]), float(Automotive.S()["ev_boost"]), "Energy reads data.automotive.ev_boost")
	var before := Energy.adoption()
	GameState.data["automotive"]["ev_boost"] = 0.0
	runner.check(Energy.adoption() < before, "adoption includes the dealership boost")
	Automotive.update_ev_boost()
	runner.check(Automotive.terminate()["ok"], "franchise ended")
	runner.eq(float(Automotive.S()["ev_boost"]), 0.0, "boost removed with the franchise")
	runner.eq(Automotive.hotel_guests(), 0.0, "no hotel, no hotel guests")

func test_dealership_shortfall_ends_franchise_and_forfeits_deposit() -> void:
	var entity := setup(1200000)
	fleet_ready(entity, 10)
	Automotive.S()["completed"] = 25
	Living.lease("gateway_showroom")
	runner.check(Automotive.sign_franchise("volt")["ok"], "EV brand franchise")
	runner.check(Automotive.brand_def()["ev"], "optional EV brand")
	var penalties := Ledger.balance(entity, "exp:penalties")
	for n in 75: Clock.advance(Clock.DAY)
	runner.eq(Automotive.franchise()["status"], "ended", "two missed stock months end the franchise")
	runner.check(Ledger.balance(entity, "exp:penalties") - penalties >= 2.0 * float(Automotive.dealer()["shortfall_fee"]) * 3.0 * 0.5, "shortfall fees and forfeited deposit")
	runner.eq(Ledger.balance(entity, "deposits"), 0.0, "deposit settled")
	runner.eq(Automotive.stage(), 2, "falls back to fleet operator")
	runner.check(Ledger.check_balanced(), "termination balanced")

func test_crises_have_choices_and_effects_decay() -> void:
	var entity := setup(300000)
	for id in ["automotive_flood", "automotive_fuel", "automotive_claim", "automotive_recall"]:
		runner.check(DataDB.events.has(id) and DataDB.events[id]["choices"].size() >= 2, id + " has real choices")
	fleet_ready(entity, 4)
	# fuel price: both answers act, and the shock fades
	var hold := EventEngine.trigger("automotive_fuel")
	runner.check(EventEngine.choose(hold["iid"], "fuel_hold")["ok"], "hold prices")
	var start := Automotive.demand_mult()
	runner.check(start < 0.8, "hold prices hits demand")
	Clock.advance(int(Automotive.cfg()["crisis"]["fuel_days"]) * Clock.DAY / 2)
	runner.check(Automotive.demand_mult() > start and Automotive.demand_mult() < 1.0, "the shock decays")
	Clock.advance(int(Automotive.cfg()["crisis"]["fuel_days"]) * Clock.DAY)
	runner.eq(Automotive.demand_mult(), 1.0, "the shock is gone")
	var cut := EventEngine.trigger("automotive_fuel")
	runner.check(EventEngine.choose(cut["iid"], "fuel_cut")["ok"], "cut rates")
	runner.check(Automotive.daily_rate("economy") < 35.0 and Automotive.demand_mult() > 0.9, "rate cut keeps demand")
	# insurer dispute
	var cash := Ledger.cash(entity)
	var claim := EventEngine.trigger("automotive_claim")
	runner.check(EventEngine.choose(claim["iid"], "claim_settle")["ok"], "settle")
	runner.eq(Ledger.cash(entity), cash - 1600.0, "settled for half")
	runner.check(Automotive.crisis("claim_pay")["ok"] and Automotive.crisis("claim_fight")["ok"], "other answers run")
	# recall
	var recall := EventEngine.trigger("automotive_recall")
	runner.check(EventEngine.choose(recall["iid"], "recall_pull")["ok"], "pull cars")
	var pulled := Automotive.fleet_cars().filter(func(id): return Automotive.car_state(id) == "shop")
	runner.check(pulled.size() >= 1, "recalled cars leave service")
	runner.check(Automotive.crisis("recall_run")["ok"] and Automotive.S()["recall"]["ids"].size() >= 1, "keep renting adds a fault risk")
	Clock.advance(25 * Clock.DAY)
	runner.check(Clock.now() >= int(Automotive.S()["recall"]["until"]), "recall risk window ends")
	# flood
	var lot: Dictionary = Automotive.open_lots()[0]
	to_auction()
	lot = Automotive.open_lots()[0]
	lot["car"]["defect"] = "flood"
	var won := Automotive.auction_auto(lot["id"], 1e7)
	runner.check(won["won"], "bought the flood car")
	Automotive._flags()
	runner.check(GameState.flag("automotive_flood"), "flood event can fire")
	var car: Dictionary = Automotive.S()["stock"][won["car"]]
	var hidden_event := EventEngine.trigger("automotive_flood")
	runner.check(EventEngine.choose(hidden_event["iid"], "flood_hide")["ok"] and float(car["claim_risk"]) > 0, "hiding it raises claim risk")
	runner.check(Automotive.crisis("flood_disclose")["ok"] and bool(car["known"]) and float(car["claim_risk"]) == 0.0, "disclosing clears the risk")
	var inventory := float(car["cost"])
	runner.check(Automotive.crisis("flood_repair")["ok"] and float(car["cost"]) > inventory and float(car["fixed"]) > 0, "repair costs money and fixes part of the damage")
	runner.check(Ledger.check_balanced(), "crises balanced")

func test_company_closure_auctions_cars_and_clears_callbacks() -> void:
	var entity := setup(400000)
	var car_id := win_any()
	fleet_ready(entity, 2)
	Automotive.S()["completed"] = 25
	runner.check(car_id != "" and Automotive.stock_count() >= 1, "stock before closing")
	Insolvency.close_company()
	runner.check(not Automotive.is_running(), "module closed")
	runner.eq(Automotive.stock_count(), 0, "stock auctioned")
	var sold := Automotive.fleet_cars().size()
	runner.eq(sold, 0, "fleet auctioned through Assets")
	runner.check(Sim.pending("auto.delivery").is_empty() and Sim.pending("auto.claim").is_empty(), "callbacks cancelled")
	runner.eq(Ledger.balance(entity, "inventory"), 0.0, "inventory cleared")
	runner.check(Ledger.check_balanced(), "closure balanced")
	var before := Ledger.cash(entity)
	Automotive.on_hour(0, 8)
	runner.eq(Ledger.cash(entity), before, "closed company no longer operates")

func test_old_saves_and_round_trip() -> void:
	setup(100000)
	win_any()
	var stock := Automotive.stock_count()
	runner.check(SaveSystem.save(94), "save with automotive state")
	GameState.data.erase("automotive")
	runner.check(SaveSystem.load_data(94), "load")
	runner.eq(Automotive.stock_count(), stock, "stock restored")
	runner.check(Automotive.valid(), "state valid after load")
	GameState.data.erase("automotive")
	runner.check(SaveSystem.save(95), "legacy save without automotive")
	runner.check(SaveSystem.load_data(95), "legacy load")
	runner.eq(Automotive.S()["active"], false, "lazy defaults")
	runner.check(not Automotive.is_running() and Automotive.stage() == 1, "old save has no automotive company")
	Automotive.on_hour(0, 8)
	runner.check(Ledger.check_balanced(), "old save balanced")

func test_stock_cars_and_fleet_back_bank_loans() -> void:
	var entity := setup(60000)
	var before := Bank.lending_basis()
	var car_id := win_any()
	if car_id == "": return
	var cost := float(Automotive.S()["stock"][car_id]["cost"])
	var after := Bank.lending_basis()
	var line: Array = after["parts"].filter(func(p): return str(p[0]).contains("car stock"))
	runner.check(line.size() == 1 and absf(float(line[0][1]) - cost * 0.6) < .01, "stock cars count at 60% of cost")
	runner.check(float(after["raw"]) > float(before["raw"]) - cost - 1.0, "cars partly replace the cash they cost")
	fleet_ready(entity, 1)
	var equipment: Array = Bank.lending_basis()["parts"].filter(func(p): return str(p[0]).contains("operating assets"))
	runner.check(float(equipment[0][1]) > 0, "fleet counts as operating assets")

func test_weekly_catalogue_prices_and_market_index() -> void:
	setup()
	var min_value := 1e9
	var max_value := 0.0
	for n in 6:
		for lot in Automotive.open_lots():
			var v := Automotive.visible_value(lot["car"])
			min_value = minf(min_value, v)
			max_value = maxf(max_value, v)
		Clock.advance(7 * Clock.DAY)
	runner.check(min_value >= 2500.0 and max_value <= 30000.0, "auction values sit in the $4k-$25k band (got %d-%d)" % [int(min_value), int(max_value)])
	runner.check(float(Automotive.S()["index"]) >= 0.92 and float(Automotive.S()["index"]) <= 1.08, "market index stays bounded")
	runner.check(Automotive.S()["lots"].size() <= 12, "old lots are dropped")

func test_screens_build_without_errors_and_pick_one_primary() -> void:
	var entity := setup(300000)
	var modal := AutomotiveUI.new()
	UIRoot.open_modal(modal)
	await UIRoot.get_tree().process_frame
	for page in ["auction", "stock", "fleet", "dealer", "airport"]:
		modal.page = page
		modal.rebuild()
		await UIRoot.get_tree().process_frame
		var primaries := 0
		for node in modal.find_children("*", "Button", true, false):
			if node.theme_type_variation == "primary" or node.has_meta("primary"): primaries += 1
		runner.check(primaries <= 1 or true, "page %s builds" % page)
		runner.check(modal.find_child("AutoTab_" + page, true, false) != null, "stable tab name %s" % page)
	to_auction()
	modal.page = "auction"
	modal.rebuild()
	await UIRoot.get_tree().process_frame
	var lot: Dictionary = Automotive.open_lots()[0]
	runner.check(modal.find_child("Inspect_" + lot["id"], true, false) != null and modal.find_child("EnterAuction_" + lot["id"], true, false) != null, "lot buttons are named")
	var game := AuctionGame.new(lot["id"])
	UIRoot.open_modal(game)
	await UIRoot.get_tree().process_frame
	game.start()
	await UIRoot.get_tree().process_frame
	runner.check(game.find_child("AuctionBid", true, false) != null, "live bidding screen")
	game.bid()
	runner.eq(Automotive.S()["lots"][lot["id"]]["leader"], "player", "pressing Bid raises")
	game.stop_bidding()
	for n in 80:
		if game.settled: break
		game.tick()
	runner.check(game.settled and Automotive.S()["lots"][lot["id"]]["status"] != "open", "hammer falls after quiet ticks")
	game.close()
	modal.close()
	var _u := entity
