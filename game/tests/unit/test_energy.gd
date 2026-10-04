extends RefCounted
var runner

func setup(extra := 0.0) -> String:
	Company.register("Solar Test", "energy", "Helio")
	Company.open_business_account(25000)
	if extra > 0: Ledger.post(GameState.company_id(), "QA energy equity", [{"acct":"cash", "dr":extra}, {"acct":"equity", "cr":extra}])
	runner.check(Living.lease("helio_warehouse")["ok"], "actual warehouse lease")
	runner.check(Energy.start()["ok"], "energy business opens")
	return GameState.company_id()
func roof(w := 5, h := 3, orientation := "S", load := 400) -> Dictionary:
	var shade: Array = []
	for y in h:
		var row: Array = []
		row.resize(w)
		row.fill(0.0)
		shade.append(row)
	return {"w":w, "h":h, "shade":shade, "orientation":orientation, "load_kg":load}
## A deterministic, strongly profitable roof so acceptance is near-certain.
func make_lead(kind := "home", id := "ROOF-T") -> Dictionary:
	var lead := {"id":id, "kind":kind, "client":"Test Client", "district":"residential", "roof":roof(), "kwh_year":9000.0, "status":"open", "layout":[], "battery":0.0,
		"margin":0.18, "subsidy":false, "expires":Clock.now() + 14 * Clock.DAY}
	Energy.S()["leads"][id] = lead
	return lead
func won_install(subsidy := false) -> String:
	Energy.S()["reputation"] = 1.0
	for attempt in 30:
		var lead := make_lead("home", "ROOF-W%d" % attempt)
		Energy.auto_layout(lead["id"])
		Energy.set_options(lead["id"], 0.0, 0.18, subsidy)
		var result := Energy.quote(lead["id"])
		if result.get("accepted", false): return result["job"]
	runner.check(false, "an installable quote is accepted")
	return ""
func finish(id: String) -> void:
	for day in 40:
		if Energy.S()["installs"][id]["status"] == "delivered": return
		Clock.advance(Clock.DAY)

func test_opening_gates_and_actual_industrial_world() -> void:
	runner.check(not Energy.start()["ok"], "company gate")
	Company.register("Solar Test", "energy", "Helio")
	Company.open_business_account(25000)
	runner.check(not Energy.start()["ok"], "warehouse gate")
	Living.lease("helio_warehouse")
	runner.check(Energy.start()["ok"], "lease unlocks")
	for building in ["helio_supply", "helio_warehouse"]: runner.check(building in DataDB.districts["industrial"]["buildings"] and BuildingInfo.building_enterable(building), building + " is an actual location")
	for npc in ["sunny_adeyemi", "rafael_costa", "ms_okoro"]: runner.check(DataDB.npcs.has(npc), npc + " exists")
	runner.check(DataDB.economy["staff"]["roles"].has("electrician") and int(DataDB.economy["staff"]["roles"]["electrician"]["salary_week"][0]) == 1050, "electrician role at $1,050 a week")
	runner.check(Industries.tabs().any(func(t): return t["id"] == "energy"), "OS registry tab")
	runner.eq(Energy.stage(), 1, "installer first")
	runner.check(DataDB.buildings["city_hall"]["interior"]["interactables"].any(func(i): return i["action"] == "energy_subsidy"), "City Hall subsidy desk")
	runner.eq(DataDB.businesses["energy"]["status"], "active", "business status active")

func test_shading_orientation_load_and_yield_math() -> void:
	setup()
	var lead := make_lead()
	var south := Energy.evaluate(lead, [[0, 0]])
	runner.check(absf(float(south["annual_kwh"]) - 0.4 * 1350) < 0.2, "one clear south panel = 540 kWh")
	lead["roof"]["shade"][0][1] = 0.5
	var shaded := Energy.evaluate(lead, [[1, 0]])
	runner.check(absf(float(shaded["annual_kwh"]) - 270) < 0.2, "50% shade halves a cell")
	lead["roof"]["orientation"] = "N"
	var north := Energy.evaluate(lead, [[0, 0]])
	runner.check(float(north["annual_kwh"]) < float(south["annual_kwh"]) * 0.6, "north roofs yield much less")
	lead["roof"]["orientation"] = "S"
	runner.check(not Energy.evaluate(lead, [[0, 0], [0, 0]])["ok"], "duplicate cell rejected")
	runner.check(not Energy.evaluate(lead, [[9, 9]])["ok"], "off-roof cell rejected")
	lead["roof"]["load_kg"] = 66
	runner.eq(Energy.max_panels(lead["roof"]), 3, "load limit allows 3 panels")
	runner.check(not Energy.layout_check(lead["roof"], [[0, 0], [1, 0], [2, 0], [3, 0]])["ok"], "fourth panel breaks the load limit")
	lead["roof"]["load_kg"] = 400
	var five := Energy.evaluate(lead, [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0], [0, 1], [1, 1], [2, 1], [3, 1], [4, 1], [0, 2], [1, 2], [2, 2]], 0.0, 0.18)
	runner.check(float(five["kw"]) == 5.2 and float(five["price"]) > 9000 and float(five["price"]) < 15000, "5 kW system quotes inside $9k-$14k")
	runner.check(absf(float(five["gross_margin"]) - 0.18) < 0.001, "gross margin matches chosen margin")
	var bat := Energy.evaluate(lead, [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]], 5.0)
	var nobat := Energy.evaluate(lead, [[0, 0], [1, 0], [2, 0], [3, 0], [4, 0]], 0.0)
	runner.check(float(bat["saving_year"]) > float(nobat["saving_year"]), "battery shifts load into peak hours and saves more")
	Energy.S()["reputation"] = 0.5
	runner.check(Energy.accept_chance(5.0, "home") > Energy.accept_chance(14.0, "home"), "shorter payback wins more quotes")
	runner.check(Energy.auto_layout(lead["id"])["ok"] and lead["layout"].size() > 0, "best panels helper")

func test_quote_install_crew_capacity_invoice_and_segments() -> void:
	var entity := setup(30000)
	Staff.S()["people"].clear()
	var id := won_install()
	var inst: Dictionary = Energy.S()["installs"][id]
	runner.eq(Jobs.get_job(id)["status"], "active", "quote accepted through Jobs")
	runner.check(float(Jobs.get_job(id)["deposit_paid"]) > 0 and Ledger.balance(entity, "deferred_revenue") < 0, "client deposit is a liability")
	runner.eq(-Ledger.balance(entity, "revenue"), 0.0, "no revenue before delivery")
	var cash := Ledger.cash(entity)
	runner.check(Energy.start_install(id)["ok"], "materials ordered")
	runner.check(Ledger.cash(entity) < cash and Ledger.balance(entity, "inventory") > 0, "materials sit in stock until delivery")
	runner.eq(inst["status"], "installing", "install running")
	runner.eq(Energy.crew_capacity(), 1.0, "owner alone is one crew")
	var alone_days := Energy.duration_days(float(inst["work"]))
	Staff.S()["people"]["E90"] = {"id":"E90", "name":"Rafael Test", "role":"electrician", "skill":4, "salary_week":1050.0, "morale":70}
	Staff.S()["people"]["E91"] = {"id":"E91", "name":"Ana Test", "role":"electrician", "skill":2, "salary_week":1050.0, "morale":70}
	runner.check(Energy.duration_days(float(inst["work"])) < alone_days, "more electricians shorten the install")
	Staff.S()["people"].clear()
	finish(id)
	runner.eq(inst["status"], "delivered", "crew work delivers the install")
	runner.check(Jobs.get_job(id)["status"] in ["invoiced", "paid"], "delivered scope is invoiced")
	var revenue := -Ledger.balance(entity, "revenue")
	runner.check(revenue > 9000, "revenue is the actual invoice")
	runner.check(absf(Ledger.balance(entity, "cogs") - float(inst["materials_paid"])) < 0.02 and absf(Ledger.balance(entity, "inventory")) < 0.02, "materials move from stock to cost of goods")
	runner.check(float(Bank.lending_basis()["contracts"]) >= 0, "bank basis reads Jobs")
	Clock.advance(30 * Clock.DAY)
	runner.eq(Jobs.get_job(id)["status"], "paid", "collected after the terms")
	runner.check(Ledger.check_balanced(), "install cycle balanced")
	var company := MonthClose.compute(entity, 0, Clock.now() + 1)
	runner.check(absf(float(Segments.compute(entity, 0, Clock.now() + 1)["totals"]["operating_profit"]) - float(company["business_profit"])) < 0.011, "segments sum to the company total")
	runner.check(Segments.compute(entity, 0, Clock.now() + 1)["rows"].has("energy"), "energy segment row")

func test_weather_stops_work_and_late_delivery_penalty() -> void:
	var entity := setup(30000)
	Staff.S()["people"].clear()
	var id := won_install()
	var inst: Dictionary = Energy.S()["installs"][id]
	Energy.start_install(id)
	Energy.S()["weather"] = {"day":Clock.day_index(), "kind":"storm"}
	Clock.advance_to(Clock.at_day_time(0, 17 * 60 + 5))
	runner.eq(float(inst["done"]), 0.0, "storms stop installation work")
	Energy.S()["weather"] = {"day":Clock.day_index(), "kind":"clear"}
	Jobs.get_job(id)["due"] = Clock.now() + 1
	finish(id)
	runner.check(-Ledger.balance(entity, "revenue") > 0, "late job still invoices")
	runner.check(Ledger.balance(entity, "exp:penalties") > 0, "late delivery pays the contract penalty")
	runner.check(Ledger.check_balanced(), "penalty entry balanced")

func test_subsidy_flow_quota_rejection_and_policy() -> void:
	var entity := setup(30000)
	var sub: Dictionary = Energy.cfg()["subsidy"]
	var id := won_install(true)
	var inst: Dictionary = Energy.S()["installs"][id]
	runner.eq(inst["subsidy"], "pending", "application filed with the quote")
	runner.check(Ledger.balance(entity, "exp:registration") >= float(sub["fee"]), "application fee is real cost")
	runner.check(not Energy.start_install(id)["ok"], "materials wait for the decision")
	runner.check(not Energy.apply_subsidy("install", id)["ok"], "no duplicate filing")
	runner.check(float(inst["grant"]) > 0 and float(inst["price"]) < float(inst["gross"]), "client price reflects the pending grant")
	var original: float = sub["reject_base"]
	sub["reject_base"] = 0.0
	Clock.advance((int(sub["decision_days"]) + 1) * Clock.DAY)
	runner.eq(inst["subsidy"], "approved", "decision after the application time")
	runner.check(absf(float(Energy.subsidy()["used"]) - float(inst["grant"])) < 0.02, "quota consumed")
	runner.check(Energy.start_install(id)["ok"], "install may start once approved")
	finish(id)
	Clock.advance((int(sub["pay_days"]) + 1) * Clock.DAY)
	runner.check(Ledger.balance(entity, "revenue") < -float(inst["gross"]) + float(inst["grant"]) - 1 or -Ledger.balance(entity, "revenue") > float(inst["price"]), "City Hall grant paid as traceable revenue")
	runner.eq(Energy.applications().filter(func(a): return a["status"] == "paid").size(), 1, "grant paid once")
	Energy.subsidy()["used"] = Energy.quota_total("install")
	runner.check(not Energy.apply_subsidy("install", id)["ok"], "exhausted quota blocks filing")
	runner.eq(Energy.subsidy_block("install"), "This year's subsidy quota is used up.", "quota reason is explained")
	Energy.subsidy()["used"] = 0.0
	var full := Energy.grant_amount("install", 10000)
	Energy.set_mod("subsidy", 0.5, 90)
	runner.check(absf(Energy.grant_amount("install", 10000) - full * 0.5) < 0.02, "policy cut halves grants")
	Clock.advance(91 * Clock.DAY)
	runner.check(absf(Energy.grant_amount("install", 10000) - full) < 0.02, "cut decays back")
	sub["reject_base"] = original
	Clock.advance_to(Clock.at_day_time(0, 7 * 60))
	var month := int(Clock.date()["month"])
	runner.check(Energy.subsidy_block("install") != "" or month <= int(sub["season_last_month"]), "season closes late in the year")
	runner.check(Ledger.check_balanced(), "subsidy journals balanced")

func test_subsidy_rejection_returns_full_price_or_cancels_with_refund() -> void:
	var entity := setup(30000)
	var sub: Dictionary = Energy.cfg()["subsidy"]
	var original: float = sub["reject_base"]
	sub["reject_base"] = 1.0
	sub["reject_max"] = 1.0
	Energy.S()["reputation"] = 1.0
	var id := won_install(true)
	var inst: Dictionary = Energy.S()["installs"][id]
	Clock.advance((int(sub["decision_days"]) + 1) * Clock.DAY)
	sub["reject_base"] = original
	sub["reject_max"] = 0.9
	runner.eq(inst["subsidy"], "rejected", "decision can reject")
	runner.check(inst["status"] == "cancelled" or absf(float(inst["price"]) - float(inst["gross"])) < 0.01, "rejection restores full price or the client walks")
	if inst["status"] == "cancelled": runner.check(Ledger.balance(entity, "deferred_revenue") > -0.02, "deposit refunded when the client cancels")
	runner.check(Ledger.check_balanced(), "rejection balanced")

func test_warranty_claim_accounting_and_dispute() -> void:
	var entity := setup(30000)
	Staff.S()["people"].clear()
	var id := won_install()
	Energy.start_install(id)
	finish(id)
	var inst: Dictionary = Energy.S()["installs"][id]
	runner.check(int(inst["warranty_until"]) > Clock.now(), "warranty period starts at delivery")
	var claim_id := Energy.make_claim(id)
	runner.check(claim_id != "", "claim opened inside warranty")
	runner.eq(Energy.make_claim(id), "", "one open claim per system")
	var claim: Dictionary = Energy.S()["claims"][claim_id]
	var cash := Ledger.cash(entity)
	var cost := float(claim["cost"])
	runner.check(absf(cost - float(inst["gross"]) * float(Energy.cfg()["warranty"]["cost_share"])) < 0.02, "claim cost is a share of the price")
	runner.check(Energy.resolve_claim(claim_id, true)["ok"], "repair under warranty")
	runner.check(absf(cash - Ledger.cash(entity) - cost) < 0.02 and absf(Ledger.balance(entity, "exp:maintenance") - cost) < 0.02, "repair posts exactly one maintenance expense")
	runner.check(not Energy.resolve_claim(claim_id, true)["ok"], "claim settles once")
	var reputation := float(Energy.S()["reputation"])
	var second := Energy.make_claim(id)
	Energy.resolve_claim(second, false)
	runner.check(float(Energy.S()["reputation"]) < reputation, "disputing a claim damages reputation")
	var third := Energy.make_claim(id)
	Energy.S()["claims"][third]["due"] = Clock.now() - 1
	Energy._warranty_day()
	runner.eq(Energy.S()["claims"][third]["status"], "repaired", "ignored claims are repaired at a markup")
	inst["warranty_until"] = Clock.now() - 1
	runner.eq(Energy.make_claim(id), "", "no claim after the warranty")
	runner.check(Ledger.check_balanced(), "warranty journals balanced")

func test_storage_certification_stage_and_battery_gate() -> void:
	setup(30000)
	var lead := make_lead()
	Energy.auto_layout(lead["id"])
	runner.check(not Energy.set_options(lead["id"], 5.0, 0.24, false)["ok"], "no battery sales before certification")
	runner.check(not Energy.certify_storage()["ok"], "course needs two installs")
	Energy.S()["completed"] = 2
	runner.check(Energy.certify_storage()["ok"], "course taken")
	runner.eq(Energy.stage(), 2, "storage stage")
	runner.check(Energy.set_options(lead["id"], 5.0, 0.24, false)["ok"], "battery may be quoted")
	runner.check(not Energy.set_options(lead["id"], 5.0, 0.9, false)["ok"], "absurd margin rejected")

func test_charger_demand_follows_adoption_price_and_capacity() -> void:
	setup(100000)
	var site := {"type":"fast", "district":"shopping_street", "price":0.45, "deal":{"share":0.0}}
	var y1 := Energy.demand_kwh(site)
	Clock.advance(365 * Clock.DAY)
	var y2 := Energy.demand_kwh(site)
	runner.check(Energy.adoption() > float(Energy.cfg()["ev"]["adoption_start"]) + 0.02, "adoption rises yearly")
	runner.check(y2 > y1 * 1.3, "demand tracks city EV adoption")
	var cheap := site.duplicate(true)
	cheap["price"] = 0.35
	var dear := site.duplicate(true)
	dear["price"] = 0.6
	runner.check(Energy.demand_kwh(cheap) > Energy.demand_kwh(site) and Energy.demand_kwh(dear) < Energy.demand_kwh(site), "higher price lowers utilisation")
	runner.check(Energy.demand_kwh(site, "storm") < Energy.demand_kwh(site, "clear"), "storms keep drivers home")
	var l2 := {"type":"l2", "district":"shopping_street", "price":0.35, "deal":{"share":0.0}}
	Energy.S()["ev_boost"] = 5.0
	runner.check(Energy.demand_kwh(l2) <= 4 * 11 * 24 * float(Energy.cfg()["charging"]["util_cap"]) + 0.01, "port power caps demand")
	Energy.S()["ev_boost"] = 0.0
	var before := Energy.adoption()
	Energy.add_ev_boost(0.02)
	runner.check(absf(Energy.adoption() - before - 0.02) < 0.0001, "dealership hook raises adoption")
	Energy.add_ev_boost(1.0)
	runner.check(Energy.adoption() - before <= float(Energy.cfg()["ev"]["boost_cap"]) + 0.0001, "boost is capped")
	Energy.S()["ev_boost"] = 0.0
	var plain := Energy.adoption()
	GameState.data.erase("automotive")
	runner.eq(Energy.adoption(), plain, "absent automotive state is a no-op")
	GameState.data["automotive"] = {"ev_boost": 0.01}
	runner.check(absf(Energy.adoption() - plain - 0.01) < 0.0001, "optional automotive hook is read when present")
	GameState.data.erase("automotive")
	runner.check(Energy.margin_per_kwh(site) > 0, "default price leaves margin per kWh")

func test_charging_network_build_deals_ops_street_and_failure() -> void:
	var entity := setup(120000)
	runner.check(not Energy.site_deal("shop_garage", "fee")["ok"], "stage gates the network")
	Energy.S()["storage_cert"] = true
	Energy.S()["completed"] = 2
	runner.eq(Energy.stage(), 2, "stage two")
	runner.eq(Energy.free_spots("shopping_street"), 2, "limited spots per district")
	runner.check(not Energy.build_station("shop_garage", "fast")["ok"], "build needs landlord terms")
	var signed := false
	for attempt in 12:
		Clock.advance(Clock.DAY)
		if Energy.site_deal("shop_garage", "fee").get("signed", false):
			signed = true
			break
	runner.check(signed, "landlord eventually agrees")
	var cash := Ledger.cash(entity)
	runner.check(Energy.build_station("shop_garage", "fast")["ok"], "fast hub ordered")
	runner.check(absf(cash - Ledger.cash(entity) - 45000) < 0.02, "fast hub costs $45,000")
	runner.check(Energy.spot_taken("shop_garage") and Energy.free_spots("shopping_street") == 1, "spot consumed")
	runner.check(Assets.S()["items"][Energy.site_of("shop_garage")["asset"]]["segment"] == "energy", "station is a depreciating Asset")
	runner.eq(Energy.street_props("shopping_street").size(), 2, "construction cones show in the street scene")
	Clock.advance(11 * Clock.DAY)
	var site := Energy.site_of("shop_garage")
	runner.eq(site["status"], "open", "station opens after the build time")
	var props := Energy.street_props("shopping_street")
	runner.check(props.size() == 2 and props[0]["sprite"] == "ev_charger", "player charger appears in its district's street scene")
	runner.eq(Energy.street_props("riverside").size(), 0, "other districts unaffected")
	var before_rev := -Ledger.balance(entity, "revenue")
	Clock.advance(10 * Clock.DAY)
	runner.check(float(site["kwh"]) > 0 and -Ledger.balance(entity, "revenue") > before_rev, "revenue is metered kWh x price")
	runner.check(absf(float(site["revenue"]) - float(site["kwh"]) * 0.45) < float(site["kwh"]) * 0.002 + 1, "revenue equals kWh times price")
	runner.check(Ledger.balance(entity, "cogs") > 0, "electricity is a real cost")
	runner.check(Energy.set_price("shop_garage", 0.5)["ok"] and not Energy.set_price("shop_garage", 0.9)["ok"], "price range enforced")
	var item: Dictionary = Assets.S()["items"][site["asset"]]
	item["status"] = "broken"
	var revenue := float(site["revenue"])
	Clock.advance(2 * Clock.DAY)
	runner.eq(float(site["revenue"]), revenue, "a failed station earns nothing")
	runner.check(int(site["down_days"]) > 0, "downtime recorded")
	runner.check(Energy.maintain_station("shop_garage")["ok"], "maintenance restores service")
	Clock.advance(Clock.DAY)
	runner.check(float(site["revenue"]) > revenue, "service resumes")
	Clock.advance(35 * Clock.DAY)
	runner.check(float(Assets.S()["items"][site["asset"]]["book"]) < 45000, "station depreciates")
	runner.check(Ledger.check_balanced(), "network journals balanced")

func test_owned_property_and_helio_lot_need_no_landlord() -> void:
	setup(120000)
	Energy.S()["storage_cert"] = true
	Energy.S()["completed"] = 2
	var owned: Dictionary = Energy.spot_def("ind_helio")
	runner.check(Energy.owned_deal(owned), "leased warehouse lot counts as your own property")
	runner.check(Energy.site_deal("ind_helio", "")["ok"], "own lot needs no negotiation")
	runner.eq(Energy.S()["deals"]["ind_helio"]["fee"], 0.0, "no landlord fee")
	runner.check(not Energy.owned_deal(Energy.spot_def("res_maple")), "residential spot requires an owned unit")
	RealEstate.S()["properties"]["maple_2"] = {"name":"Maple unit"}
	runner.check(Energy.owned_deal(Energy.spot_def("res_maple")), "player-owned property hosts chargers")
	GameState.data.erase("real_estate")

func test_loan_and_grant_financing_for_stations() -> void:
	var entity := setup(60000)
	Energy.S()["storage_cert"] = true
	Energy.S()["completed"] = 2
	Energy.S()["deals"]["hub_lot"] = {"kind":"fee", "fee":380.0, "share":0.0}
	var result := Energy.build_station("hub_lot", "l2", true, false)
	runner.check(result["ok"], "grant request files with the build")
	runner.check(Energy.applications().any(func(a): return a["program"] == "charger"), "charger application recorded")
	var sub: Dictionary = Energy.cfg()["subsidy"]
	var original: float = sub["reject_base"]
	sub["reject_base"] = 0.0
	var cash := Ledger.cash(entity)
	Clock.advance(6 * Clock.DAY)
	sub["reject_base"] = original
	var app: Dictionary = Energy.applications().filter(func(a): return a["program"] == "charger")[0]
	runner.check(app["status"] in ["paid", "approved"], "charger grant decided")
	if app["status"] == "paid":
		var item: Dictionary = Assets.S()["items"][Energy.site_of("hub_lot")["asset"]]
		runner.check(float(item["price"]) < 9000, "grant reduces the capitalised cost")
		runner.check(Ledger.cash(entity) > cash - 100, "grant arrives in cash")
	runner.check(Ledger.check_balanced(), "grant journals balanced")

func test_crises_have_two_real_choices_and_effects_decay() -> void:
	var entity := setup(120000)
	Energy.S()["storage_cert"] = true
	Energy.S()["completed"] = 2
	Energy.S()["deals"]["hub_lot"] = {"kind":"fee", "fee":380.0, "share":0.0}
	Energy.build_station("hub_lot", "l2")
	Clock.advance(6 * Clock.DAY)
	var checked := 0
	for id in ["energy_shortage", "energy_typhoon", "energy_subsidy_cut", "energy_vandal", "energy_tariff", "energy_rule"]:
		runner.check(DataDB.events[id]["choices"].size() >= 2, id + " has real choices")
		checked += 1
	runner.eq(checked, 6, "six crisis events")
	var event := EventEngine.trigger("energy_shortage")
	runner.check(EventEngine.choose(event["iid"], "premium")["ok"], "premium supplier route")
	var premium := Energy.mod("materials")
	Energy.S()["mods"].clear()
	event = EventEngine.trigger("energy_shortage")
	runner.check(EventEngine.choose(event["iid"], "wait")["ok"], "wait route")
	runner.check(Energy.mod("materials") > premium, "the cheap choice carries the worse price shock")
	var peak := Energy.mod("materials")
	Clock.advance(20 * Clock.DAY)
	runner.check(Energy.mod("materials") < peak and Energy.mod("materials") > 1.0, "shock eases gradually")
	Clock.advance(40 * Clock.DAY)
	runner.eq(Energy.mod("materials"), 1.0, "shock fully decays")
	var price := float(Energy.site_of("hub_lot")["price"])
	event = EventEngine.trigger("energy_tariff")
	runner.check(EventEngine.choose(event["iid"], "pass")["ok"], "pass-through choice")
	runner.check(float(Energy.site_of("hub_lot")["price"]) > price and Energy.grid_cost() > 0, "price rises while grid cost shocks")
	Energy.S()["mods"].clear()
	event = EventEngine.trigger("energy_vandal")
	runner.check(EventEngine.choose(event["iid"], "secure")["ok"] and Energy.mod("security") < 1.0, "security choice cuts outage risk for a while")
	event = EventEngine.trigger("energy_subsidy_cut")
	runner.check(EventEngine.choose(event["iid"], "accept")["ok"] and Energy.mod("subsidy") < 1.0, "policy cut event")
	var accessible := Energy.open_stations().filter(func(s): return s["accessible"]).size()
	event = EventEngine.trigger("energy_rule")
	runner.check(EventEngine.choose(event["iid"], "retrofit")["ok"], "retrofit choice")
	runner.check(Energy.open_stations().filter(func(s): return s["accessible"]).size() > accessible, "bays made accessible")
	var id := won_install()
	Energy.start_install(id)
	finish(id)
	var claims := Energy.claims_open().size()
	event = EventEngine.trigger("energy_typhoon")
	runner.check(EventEngine.choose(event["iid"], "triage")["ok"], "triage choice")
	runner.check(Energy.claims_open().size() == claims, "typhoon repairs are settled immediately")
	runner.check(Ledger.check_balanced(), "crisis journals balanced")

func test_save_old_save_and_company_closure() -> void:
	var entity := setup(120000)
	Energy.S()["storage_cert"] = true
	Energy.S()["completed"] = 2
	Energy.S()["deals"]["hub_lot"] = {"kind":"fee", "fee":380.0, "share":0.0}
	Energy.build_station("hub_lot", "l2", true)
	var id := won_install(true)
	runner.check(SaveSystem.save(95), "energy save")
	GameState.data.erase("energy")
	runner.check(SaveSystem.load_data(95), "energy load")
	runner.check(Energy.S()["installs"].has(id) and Energy.S()["sites"].has("hub_lot"), "installs and stations persist")
	runner.check(not Sim.pending("energy.decision").is_empty() or not Sim.pending("energy.open").is_empty(), "scheduled callbacks persist")
	Insolvency.close_company()
	runner.check(not Energy.is_running(), "closure stops the business")
	runner.check(Sim.pending("energy.decision").is_empty() and Sim.pending("energy.open").is_empty() and Sim.pending("energy.grant").is_empty(), "closure cancels energy callbacks")
	runner.eq(Energy.S()["installs"][id]["status"], "cancelled", "open installs cancelled")
	runner.eq(Energy.S()["sites"]["hub_lot"]["status"], "closed", "stations closed")
	runner.eq(Assets.S()["items"][Energy.S()["sites"]["hub_lot"]["asset"]]["status"], "sold", "station auctioned")
	runner.check(Ledger.check_balanced(), "closure balanced")
	GameState.data.erase("energy")
	runner.check(SaveSystem.save(96), "legacy save without energy state")
	runner.check(SaveSystem.load_data(96), "legacy load")
	runner.eq(Energy.stage(), 1, "old save lazy defaults")
	runner.check(not Energy.is_running(), "old save has no business")
	var other := Energy.S()
	runner.check(other["leads"].is_empty() and other["sites"].is_empty(), "lazy state is empty")

func test_own_property_rooftop_array_earns_feed_in_through_assets() -> void:
	var entity := setup(60000)
	RealEstate.S()["properties"]["maple_1"] = {"name":"Maple unit"}
	Energy.S()["week"] = -1
	Energy.refresh()
	runner.check(Energy.S()["leads"].has("OWN-maple_1"), "owned property becomes a roof lead")
	Energy.auto_layout("OWN-maple_1")
	var result := Energy.quote("OWN-maple_1")
	runner.check(result["ok"], "own roof accepted")
	Energy.start_install("OWN-maple_1")
	finish("OWN-maple_1")
	runner.check(Energy.S()["arrays"].has("OWN-maple_1") and Assets.S()["items"][Energy.S()["installs"]["OWN-maple_1"]["asset"]]["segment"] == "energy", "array is a depreciating Asset")
	var revenue := -Ledger.balance(entity, "revenue")
	Clock.advance(10 * Clock.DAY)
	runner.check(-Ledger.balance(entity, "revenue") > revenue, "grid export is metered revenue")
	runner.check(Ledger.check_balanced(), "own array balanced")
	GameState.data.erase("real_estate")

func test_roof_survey_ui_buttons_and_primary_rule() -> void:
	setup(30000)
	var lead := make_lead()
	var ui := EnergyUI.new()
	ui.page = "survey"
	ui.selected = lead["id"]
	UIRoot.open_modal(ui)
	await UIRoot.get_tree().process_frame
	runner.check(ui.find_child("Cell_0_0", true, false) != null and ui.find_child("Cell_4_2", true, false) != null, "every roof cell has a stable name")
	ui.find_child("Cell_0_0", true, false).emit_signal("pressed")
	ui.find_child("Cell_1_0", true, false).emit_signal("pressed")
	await UIRoot.get_tree().process_frame
	runner.eq(lead["layout"].size(), 2, "clicking cells places panels")
	runner.check(ui.find_child("SendQuote", true, false) != null, "quote button exists once panels are placed")
	runner.check(ui.has_primary, "survey offers exactly one primary next step")
	ui.close()
	for tab in ["leads", "installs", "subsidy", "charging"]:
		var page := EnergyUI.new()
		page.page = tab
		UIRoot.open_modal(page)
		await UIRoot.get_tree().process_frame
		runner.check(page.find_child("EnergyTab_" + tab, true, false) != null, tab + " page builds")
		page.close()

func test_new_facades_use_existing_art_and_district_scene_draws_player_chargers() -> void:
	for bid in ["helio_supply", "helio_warehouse"]:
		var b: Dictionary = DataDB.buildings[bid]
		runner.check(DataDB.buildings_meta.has(District.facade(b["exterior"])), bid + " has a facade to draw")
	var before := District.new()
	UIRoot.get_tree().root.add_child(before)
	before.build("shopping_street")
	var base := before.entities.get_child_count()
	before.queue_free()
	setup(120000)
	Energy.S()["storage_cert"] = true
	Energy.S()["completed"] = 2
	Energy.S()["deals"]["shop_garage"] = {"kind":"fee", "fee":520.0, "share":0.0}
	runner.check(Energy.build_station("shop_garage", "fast")["ok"], "station ordered")
	Clock.advance(11 * Clock.DAY)
	var after := District.new()
	UIRoot.get_tree().root.add_child(after)
	after.build("shopping_street")
	runner.check(after.entities.get_child_count() >= base + 2, "player chargers are drawn in the street scene")
	after.queue_free()

func test_company_os_tab_and_charging_map_ui_build_without_errors() -> void:
	setup(150000)
	var os := CompanyOS.new("home_laptop")
	os.tab = "energy"
	UIRoot.open_modal(os)
	await UIRoot.get_tree().process_frame
	runner.check(os.find_child("OpenEnergyConsole", true, false) != null, "Company OS energy tab offers the console")
	os.close()
	Energy.S()["storage_cert"] = true
	Energy.S()["completed"] = 2
	var map := EnergyUI.new()
	map.page = "charging"
	map.district = "shopping_street"
	UIRoot.open_modal(map)
	await UIRoot.get_tree().process_frame
	runner.check(map.find_child("District_shopping_street", true, false) != null and map.find_child("District_industrial", true, false) != null, "map lists every district with spots")
	runner.check(map.find_child("DealFee_shop_garage", true, false) != null and map.find_child("DealShare_shop_garage", true, false) != null, "landlord terms are offered")
	Energy.S()["deals"]["shop_garage"] = {"kind":"fee", "fee":520.0, "share":0.0}
	map.rebuild()
	await UIRoot.get_tree().process_frame
	runner.check(map.find_child("Build_shop_garage_fast", true, false) != null and map.find_child("BuildLoan_shop_garage_l2", true, false) != null, "build choices after terms")
	map.find_child("Build_shop_garage_fast", true, false).emit_signal("pressed")
	await UIRoot.get_tree().process_frame
	Clock.advance(11 * Clock.DAY)
	map.rebuild()
	await UIRoot.get_tree().process_frame
	runner.check(map.find_child("PriceUp_shop_garage", true, false) != null, "price control for an open station")
	map.find_child("PriceUp_shop_garage", true, false).emit_signal("pressed")
	runner.check(absf(float(Energy.site_of("shop_garage")["price"]) - 0.5) < 0.001, "price button changes the station price")
	map.close()
	var subs := EnergyUI.new()
	subs.page = "subsidy"
	UIRoot.open_modal(subs)
	await UIRoot.get_tree().process_frame
	runner.check(subs.has_primary, "subsidy desk always offers one next step")
	subs.close()
	var board := VBoxContainer.new()
	Industries.board_detail("energy", board, null)
	runner.check(board.find_child("OpenEnergyConsole", true, false) != null, "Business Board detail from the registry")
	board.free()

func test_station_loan_financing_is_all_or_nothing() -> void:
	var entity := setup(10000)
	Energy.S()["storage_cert"] = true
	Energy.S()["completed"] = 2
	Energy.S()["deals"]["hub_lot"] = {"kind":"fee", "fee":380.0, "share":0.0}
	var cash := Ledger.cash(entity)
	var result := Energy.build_station("hub_lot", "fast", false, true)
	if result["ok"]:
		runner.check(Bank.debt(entity) > 0 and Energy.spot_taken("hub_lot"), "financed station records the loan and the asset")
	else:
		runner.eq(Ledger.cash(entity), cash, "refused financing moves no money")
		runner.check(Bank.debt(entity) == 0 and not Energy.spot_taken("hub_lot"), "no loan or station without the build")
	runner.check(Ledger.check_balanced(), "financing journals balanced")

func test_cancelled_install_releases_the_subsidy_quota() -> void:
	setup(30000)
	var sub: Dictionary = Energy.cfg()["subsidy"]
	var original: float = sub["reject_base"]
	sub["reject_base"] = 0.0
	var id := won_install(true)
	Clock.advance((int(sub["decision_days"]) + 1) * Clock.DAY)
	sub["reject_base"] = original
	runner.check(float(Energy.subsidy()["used"]) > 0, "quota reserved on approval")
	Energy.cancel_install(id, "test")
	runner.eq(float(Energy.subsidy()["used"]), 0.0, "quota returns when the install is cancelled")
	runner.check(Ledger.check_balanced(), "cancellation refund balanced")
