extends RefCounted
## Harbor and the logistics business: the district is on the map and linked by metro; Pier 7 is a leased warehouse and a
## second stock location; Sam sells one used van from the company account (insured monthly); the van ships your own
## parcels for fuel and takes posted delivery runs, planned on a map (score = best route ÷ yours); drivers work a run
## every workday; and the books stay balanced through all of it.

var runner


func _company(cash := 27000.0) -> String:
	Company.register("Haul Test Co", "ecommerce", "22 Founders Lane")
	Company.open_business_account(cash)
	GameState.set_flag("business_account_opened")
	return GameState.company_id()


## On to the next `weekday` (0 = Sunday) at h:00.
func _to(weekday: int, h: int) -> void:
	Clock.advance(60 - Clock.minute_of_day() % 60)
	while not (Clock.weekday() == weekday and Clock.hour() == h):
		Clock.advance(60)


## On to the next Mon–Fri at h:00 (and not before `after`).
func _to_workday(h: int, after := 0) -> void:
	Clock.advance(60 - Clock.minute_of_day() % 60)
	while not (Clock.weekday() >= 1 and Clock.weekday() <= 5 and Clock.hour() == h and Clock.now() >= after):
		Clock.advance(60)


func _van() -> String:
	var cid := _company()
	runner.check(Logistics.buy_van()["ok"], "bought the van")
	return cid


## A job of the given stops, straight on the board (bypassing the morning post so tests don't depend on the RNG).
func _job(stops: Array, pay := 150.0, hours_left := 8) -> Dictionary:
	var best := Logistics.best_order(stops)
	var st := Logistics.stats_for_px(stops.size(), float(best["px"]), float(best["px"]))
	var id := "R%d" % int(Logistics.S()["seq"])
	Logistics.S()["seq"] = int(Logistics.S()["seq"]) + 1
	var j := {"id": id, "client": "Kuro Ramen", "stops": stops, "kind": "same_day", "posted": Clock.now(), "by": Clock.now() + hours_left * 60,
		"pay": pay, "km_best": st["km"], "est_min": int(st["minutes"]), "status": "open"}
	Logistics.S()["jobs"][id] = j
	return j


const STOPS := ["lantern_books", "threadline", "city_hall", "nexus_bank", "bloom_coffee"]


func test_harbor_is_open_and_linked() -> void:
	runner.check(DataDB.districts.has("harbor"), "district data loads")
	runner.eq(str(DataDB.district_def_in_city("harbor").get("status", "")), "active", "open on the city map")
	var stations := []
	for l in DataDB.city["metro"]["lines"]:
		if "harbor" in l["stations"]:
			stations.append(l["id"])
	runner.check("M3" in stations, "on the Harbor Line, M3 (%s)" % str(stations))
	runner.check(DataDB.city["metro"]["travel_min"].has("harbor>riverside"), "a metro time to Riverside")
	runner.eq(str(DataDB.districts["harbor"]["metro"]["station"]), "harbor", "its own metro station")
	runner.check(DataDB.districts["harbor"]["spawns"].has("metro"), "a place to step off the metro")
	for bid in ["pier7_warehouse", "dockside_motors", "harbor_point_fitness", "customs_house"]:
		var b := DataDB.building(bid)
		runner.eq(str(b.get("district", "")), "harbor", bid + " is in the Harbor")
		runner.check(DataDB.buildings_meta.has(District.facade(b["exterior"])), bid + " has a facade to draw")
		runner.check(DataDB.districts["harbor"]["buildings"].has(bid), bid + " is listed in the district")
	for g in DataDB.districts["harbor"]["ground"]:
		var t := str(g["type"])
		runner.check(DataDB.tiles["tiles"].has(t) or DataDB.tiles["tiles"].has(str(g.get("fallback", ""))), "ground tile %s has art or a fallback" % t)
	for f in DataDB.districts["harbor"]["fillers"]:
		runner.check(DataDB.buildings_meta.has(District.facade(f)), "filler %s has a facade to draw" % f["sprite"])
	runner.eq(str(DataDB.businesses["logistics"]["status"]), "active", "the logistics business is open")
	runner.eq(str(DataDB.businesses["logistics"]["module"]), "logistics", "with its module")
	runner.check(DataDB.validate().is_empty(), "data validates: " + str(DataDB.validate()))


func test_the_gym_and_customs_house_have_actual_hours() -> void:
	runner.check(not SceneRouter.building_open("harbor_point_fitness")["open"], "Harbor Point Fitness stays scenery until enabled")
	var g := DataDB.building("harbor_point_fitness")
	runner.check(g["interior"]["interactables"].any(func(i): return i["action"] == "look"), "with something to look at inside")
	var st := SceneRouter.building_open("customs_house")
	runner.check(not st["open"], "the Customs House is closed outside office hours")
	runner.check(str(st["reason"]).contains("09:00–16:00"), "shows actual office hours: " + str(st["reason"]))
	GameState.data["clock"]["minutes"] = Clock.at_day_time(1, 10 * 60)
	runner.check(SceneRouter.building_open("customs_house")["open"], "Customs House opens on a weekday morning")
	runner.check(DataDB.building("customs_house").has("interior"), "it still has a room, so screens and tools can load it")


func test_sam_and_the_dealer_are_wired() -> void:
	var sam := DataDB.npc("sam")
	runner.eq(str(sam["name"]), "Sam Okoro", "Sam Okoro")
	runner.eq(str(sam["schedule"][0]["location"]), "interior:dockside_motors", "he minds Dockside Motors")
	runner.check(DataDB.building("dockside_motors")["interior"]["npc_spots"].has(str(sam["schedule"][0]["spot"])), "at a spot that exists")
	for d in sam["dialogue"]:
		runner.check(DataDB.dialogue.has(str(d["conversation"])), "dialogue %s exists" % d["conversation"])
	runner.check(sam["dialogue"].any(func(d): return str(d.get("action", "")) == "buy_van"), "talking to him opens the van")
	runner.check(DataDB.npcs.has("harbor_point"), "Rosa still reaches you by phone")


func test_warehouse_lease_and_stock_location() -> void:
	var p: Dictionary = DataDB.properties["pier7_warehouse"]
	runner.eq(str(p["kind"]), "warehouse", "a warehouse")
	runner.eq(int(p["capacity"]["inventory_units"]), 5000, "5,000 units")
	runner.check(not ("pier7_warehouse" in Ecommerce.stock_locations()), "not a stock location before the lease")
	runner.check(not Living.lease("pier7_warehouse")["ok"], "leases go to registered companies")
	var cid := _company()
	var cash0 := Ledger.cash(cid)
	runner.check(Living.lease("pier7_warehouse")["ok"], "leased")
	runner.check(absf(cash0 - Ledger.cash(cid) - 1400.0 * 2) < 0.01, "first month + a month's deposit")
	runner.check(Ledger.balance(cid, "exp:rent_warehouse") > 0.0, "rent goes on the warehouse line")
	runner.eq(Ledger.balance(cid, "exp:rent_office"), 0.0, "not office rent")
	runner.check("pier7_warehouse" in Ecommerce.stock_locations(), "a stock location now")
	runner.eq(Ecommerce.location_capacity("pier7_warehouse"), 5000, "with its own space")
	# stock can be delivered there, and orders for it are packed at the warehouse's own bench
	var r := Ecommerce.buy("tradelink_wholesale", "phone_stand", 400, "pier7_warehouse")
	runner.check(r.get("ok", false), "stock ordered to Pier 7: " + str(r.get("error", "")))
	for i in 24 * 8:
		if Ecommerce.stock("pier7_warehouse", "phone_stand") >= 400:
			break
		Clock.advance(60)
	runner.eq(Ecommerce.stock("pier7_warehouse", "phone_stand"), 400, "it arrived at the warehouse")
	runner.eq(Ecommerce.total_units_at("riverside_studio"), 0, "and not at home")
	var l := Ecommerce.create_listing("phone_stand", 14.0, "self")
	runner.check(l.get("ok", false), "listed from warehouse stock")
	Ecommerce._h_order_place({"listing": l["listing_id"]})
	var waiting := Ecommerce.orders_with(["placed"], "pier7_warehouse")
	runner.eq(waiting.size(), 1, "the order waits at Pier 7")
	runner.eq(Ecommerce.pack_orders("pier7_warehouse"), 1, "packed there")
	# the packing table and the lettings desk are in the room
	var acts: Array = DataDB.building("pier7_warehouse")["interior"]["interactables"]
	var pack: Dictionary = acts.filter(func(a): return a["action"] == "pack_orders")[0]
	runner.eq(str(pack["params"]["location"]), "pier7_warehouse", "the bench packs for Pier 7")
	runner.eq(str(pack["params"]["requires"]), "lease:pier7_warehouse", "and needs the lease")
	var lease_act: Dictionary = acts.filter(func(a): return a["action"] == "lease_property")[0]
	runner.eq(str(lease_act["params"]["property"]), "pier7_warehouse", "the lettings desk leases Pier 7")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_buying_the_van() -> void:
	runner.check(not Logistics.has_van(), "no van at the start")
	runner.eq(Logistics.buy_block(), "register a company first", "needs a company")
	Company.register("Haul Test Co", "ecommerce", "22 Founders Lane")
	runner.eq(Logistics.buy_block(), "open a business bank account first", "and a business account")
	Company.open_business_account(20000.0)
	GameState.set_flag("business_account_opened")
	var cid := GameState.company_id()
	var cash0 := Ledger.cash(cid)
	var r := Logistics.buy_van()
	runner.check(r["ok"], "bought it: " + str(r.get("error", "")))
	runner.check(Logistics.has_van() and GameState.flag("van_owned"), "the van is yours")
	runner.check(absf(cash0 - Ledger.cash(cid) - (9800.0 + 165.0)) < 0.01, "$9,800 plus the first month's insurance from the company account")
	runner.eq(Ledger.balance(cid, "exp:vehicle"), 9800.0, "the price is a vehicle expense")
	runner.eq(Ledger.balance(cid, "exp:insurance"), 165.0, "insurance has its own line")
	runner.eq(Logistics.buy_block(), "you already own the van", "one van")
	# insurance comes round again every month
	Clock.advance(35 * Clock.DAY)
	runner.check(Ledger.balance(cid, "exp:insurance") >= 330.0, "insured again next month (%.0f)" % Ledger.balance(cid, "exp:insurance"))
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_a_broke_company_cannot_buy_the_van() -> void:
	Company.register("Haul Test Co", "ecommerce", "22 Founders Lane")
	Company.open_business_account(5000.0)
	GameState.set_flag("business_account_opened")
	runner.check(Logistics.buy_block().contains("$9,965"), "says what it needs: " + Logistics.buy_block())
	runner.check(not Logistics.buy_van()["ok"], "no van")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_own_van_shipping_costs_fuel_and_arrives_today() -> void:
	var cid := _van()
	runner.check(Living.lease("pier7_warehouse")["ok"], "leased Pier 7")
	Ecommerce.buy("tradelink_wholesale", "phone_stand", 200, "pier7_warehouse")
	for i in 24 * 8:
		if Ecommerce.stock("pier7_warehouse", "phone_stand") >= 200:
			break
		Clock.advance(60)
	var l := Ecommerce.create_listing("phone_stand", 14.0, "self")
	for i in 6:
		Ecommerce._h_order_place({"listing": l["listing_id"]})
	runner.eq(Ecommerce.pack_orders("pier7_warehouse"), 6, "six orders packed")
	var packed := Ecommerce.orders_with(["packed"], "pier7_warehouse")
	var q := Logistics.ship_quote("pier7_warehouse")
	runner.eq(int(q["count"]), 6, "the quote covers them")
	var per_km := 0.14 * 2.1
	runner.check(absf(float(q["fuel"]) - 6 * 4.5 * per_km) < 0.02, "fuel is per parcel: 6 × 4.5 km × $%.3f (%.2f)" % [per_km, float(q["fuel"])])
	runner.eq(int(q["minutes"]), 25 + 6 * 12, "and it takes your time")
	# cheaper than the courier for the same parcels
	var courier := float(DataDB.shipping()["pickup"]["courier_fee_per_batch"])
	for o in packed:
		courier += Ecommerce.ship_cost(o, "economy")
	runner.check(float(q["fuel"]) < courier, "cheaper than the economy courier (%.2f < %.2f)" % [float(q["fuel"]), courier])
	var fuel0 := Ledger.balance(cid, "exp:fuel")
	var ship0 := Ledger.balance(cid, "exp:shipping")
	var t0 := Clock.now()
	var r := Logistics.ship_own_van("pier7_warehouse")
	runner.check(r["ok"], "shipped: " + str(r.get("error", "")))
	runner.check(absf(Ledger.balance(cid, "exp:fuel") - fuel0 - float(q["fuel"])) < 0.011, "fuel booked to exp:fuel")
	runner.eq(Ledger.balance(cid, "exp:shipping"), ship0, "no courier fee")
	for o in packed:
		runner.eq(str(o["status"]), "shipped", "on its way")
		runner.eq(str(o["ship"]["method"]), "own_van", "by your own van")
		runner.eq(int(o["ship"]["eta"]), t0 + int(q["minutes"]), "same day: it arrives when you do")
	Clock.advance(int(r["minutes"]) + 1)
	for o in packed:
		runner.eq(str(o["status"]), "delivered", "delivered today")
	runner.check(Ledger.balance(cid, "revenue") < 0.0, "the sales are revenue now")
	runner.check(Ledger.check_balanced(), "ledger balanced")
	runner.eq(Logistics.ship_block("pier7_warehouse"), "nothing packed here", "nothing left to ship")


func test_the_courier_options_are_untouched_and_the_van_needs_owning() -> void:
	runner.eq(Logistics.ship_block("riverside_studio"), "you need a van (Dockside Motors, Harbor)", "no van, no option")
	runner.check(not Logistics.ship_own_van("riverside_studio")["ok"], "can't ship without one")
	runner.eq(DataDB.ship_method("economy")["transit_days"], 3.0, "economy is still 3 days")
	runner.eq(DataDB.ship_method("express")["transit_days"], 1.0, "express is still 1 day")


func test_fuel_gets_dearer_in_a_shipping_shock() -> void:
	var base := Logistics.fuel_cost_per_km()
	runner.check(absf(base - 0.14 * 2.1) < 0.0001, "$%.3f a km in a normal year" % base)
	GameState.data["world"]["year"] = 3   # Supply Shock: shipping index 1.8
	runner.check(absf(Logistics.fuel_cost_per_km() - base * 1.4) < 0.0001, "40%% dearer in the Supply Shock (%.3f)" % Logistics.fuel_cost_per_km())


func test_route_geometry_and_score_math() -> void:
	# the river runs between the depot's bank and Riverside: crossing costs a detour through a bridge
	runner.check(not Logistics.across(Logistics.depot()), "the depot is on the west bank")
	runner.check(Logistics.across(Logistics.place_pos("bloom_coffee")), "Riverside is across the river")
	runner.check(not Logistics.across(Logistics.place_pos("city_hall")), "Civic Center is on the depot's side")
	var across := Logistics.leg(Logistics.depot(), Logistics.place_pos("bloom_coffee"))
	runner.eq(across.size(), 3, "a crossing goes via a bridge")
	runner.check(Logistics.leg_px(Logistics.depot(), Logistics.place_pos("bloom_coffee")) > Logistics.depot().distance_to(Logistics.place_pos("bloom_coffee")), "longer than the straight line")
	runner.eq(Logistics.leg(Logistics.depot(), Logistics.place_pos("city_hall")).size(), 2, "same bank: straight")
	# brute force: nothing beats the best order, and its score is exactly 1
	var best := Logistics.best_order(STOPS)
	var perms := RouteGame._perms(STOPS.size())
	runner.eq(perms.size(), 120, "5 stops have 120 orders")
	var worst := 0.0
	for perm in perms:
		var px := Logistics.route_px(STOPS, perm)
		runner.check(px >= float(best["px"]) - 0.001, "no order beats the best")
		worst = maxf(worst, px)
	var top := Logistics.route_stats(STOPS, best["order"])
	runner.check(absf(float(top["score"]) - 1.0) < 0.0001, "the best route scores 100%")
	var bad: Array = []
	for perm in perms:
		if absf(Logistics.route_px(STOPS, perm) - worst) < 0.001:
			bad = perm
			break
	var low := Logistics.route_stats(STOPS, bad)
	runner.check(absf(float(low["score"]) - float(best["px"]) / worst) < 0.0001, "score = best ÷ yours (%.3f)" % float(low["score"]))
	runner.check(float(low["score"]) < 0.8, "a bad plan scores well under 100%% (%.2f)" % float(low["score"]))
	runner.check(float(low["km"]) > float(top["km"]) and int(low["minutes"]) > int(top["minutes"]) and float(low["fuel_l"]) > float(top["fuel_l"]), "longer means more km, time and fuel")
	runner.check(absf(float(top["km"]) - Logistics.to_km(float(best["px"]))) < 0.06, "kilometres follow the map scale")
	runner.check(absf(float(top["fuel_l"]) - float(top["km"]) * 0.14) < 0.06, "14 L per 100 km")
	runner.check(Logistics.route_stats(STOPS, [0, 1, 2, 3]).is_empty(), "a route must visit every stop")
	runner.check(Logistics.route_stats(STOPS, [0, 1, 2, 3, 3]).is_empty(), "and only once")
	runner.check(Logistics.valid_order(STOPS, [4, 3, 2, 1, 0]), "any order of them is a route")


func test_the_route_minigame_plays_and_autoplays() -> void:
	var g := RouteGame.new({"id": "R9", "client": "Kuro Ramen", "stops": STOPS, "by": 0})
	var got := {}
	g.on_done = func(r): got.merge(r)
	g.autoplay(1.0)
	runner.check(not got.has("aborted"), "finished, not aborted")
	runner.check(float(got.get("score", 0.0)) > 0.999, "autoplay at 100%% plays the shortest route (%.3f)" % float(got.get("score", 0.0)))
	runner.check(Logistics.valid_order(STOPS, got.get("order", [])), "with a real order")
	runner.check(int(got.get("minutes", 0)) > 30 and float(got.get("km", 0.0)) > 5.0, "time and kilometres come with it")
	var g2 := RouteGame.new({"id": "R9", "client": "Kuro Ramen", "stops": STOPS, "by": 0})
	var got2 := {}
	g2.on_done = func(r): got2.merge(r)
	g2.autoplay(0.7)
	runner.check(absf(float(got2.get("score", 0.0)) - 0.7) < 0.12, "autoplay at 70%% lands near it (%.3f)" % float(got2.get("score", 0.0)))
	runner.check(float(got2["km"]) > float(got["km"]), "a lower score is a longer drive")
	# clicking through it by hand: the route grows stop by stop and undo takes one back
	var g3 := RouteGame.new({"id": "R9", "client": "Kuro Ramen", "stops": STOPS, "by": 0})
	g3.phase = "play"
	g3.stage = Control.new()
	g3.footer = HBoxContainer.new()
	g3.build_round()
	g3._pick(2)
	g3._pick(0)
	runner.eq(g3.order, [2, 0], "stops in the order clicked")
	g3._pick(2)
	runner.eq(g3.order, [2, 0], "a stop already planned isn't added twice")
	g3._undo()
	runner.eq(g3.order, [2], "undo takes the last one back")
	runner.check(g3.drive_btn.disabled, "can't drive a half-planned route")
	for i in [0, 1, 3, 4]:
		g3._pick(i)
	runner.check(not g3.drive_btn.disabled, "drive once every stop is planned")
	g3.stage.free()
	g3.footer.free()
	g3.free()
	g2.free()
	g.free()


func test_jobs_are_posted_accepted_driven_and_paid() -> void:
	var cid := _van()
	runner.eq(Logistics.open_jobs().size(), 0, "nothing on the board yet")
	_to(2, 6)   # Tuesday 6:00
	Clock.advance(70)   # 7:00: the morning post
	var open := Logistics.open_jobs()
	runner.check(open.size() >= 2 and open.size() <= 4, "two to four runs posted (%d)" % open.size())
	for j in open:
		runner.check((j["stops"] as Array).size() >= 4 and (j["stops"] as Array).size() <= 6, "4 to 6 stops")
		runner.check(float(j["pay"]) >= 90.0 and float(j["pay"]) <= 260.0, "a sensible fee ($%.0f)" % float(j["pay"]))
		runner.check(int(j["by"]) > Clock.now(), "with a deadline ahead")
		runner.check(Logistics.place(str((j["stops"] as Array)[0])).size() > 0, "at real places")
	# accept one
	var j0: Dictionary = open[0]
	var id := str(j0["id"])
	runner.check(Logistics.accept(id)["ok"], "accepted")
	runner.eq(str(Logistics.job(id)["status"]), "active", "on your list")
	runner.check(not Logistics.accept(id)["ok"], "not twice")
	runner.check(not Logistics.drive("R404", [0])["ok"], "can't drive a run that isn't yours")
	runner.check(not Logistics.drive(id, [0, 1])["ok"], "or half a route")
	# drive it, best route
	var rev0 := -Ledger.balance(cid, "revenue")
	var fuel0 := Ledger.balance(cid, "exp:fuel")
	var veh0 := Ledger.balance(cid, "exp:vehicle")
	var cash0 := Ledger.cash(cid)
	var t0 := Clock.now()
	var best := Logistics.best_order(j0["stops"])
	var r := Logistics.drive(id, best["order"])
	runner.check(r["ok"], "driven: " + str(r.get("error", "")))
	runner.eq(Clock.now() - t0, int(r["minutes"]), "the drive took its time")
	runner.check(int(r["minutes"]) >= 90 and int(r["minutes"]) <= 300, "a couple of hours, not minutes (%d)" % int(r["minutes"]))
	var on_time := Clock.now() <= int(j0["by"])
	runner.eq(bool(r["late"]), not on_time, "late only if the deadline passed")
	var want := float(j0["pay"]) * 1.1 * (1.0 if on_time else 0.6)
	runner.check(absf(float(r["pay"]) - want) < 0.02, "the best route pays 110%% of the fee, less 40%% if late (%.2f vs %.2f)" % [float(r["pay"]), want])
	runner.check(absf(-Ledger.balance(cid, "revenue") - rev0 - float(r["pay"])) < 0.011, "the pay is banked as revenue")
	runner.check(absf(Ledger.balance(cid, "exp:fuel") - fuel0 - float(r["fuel"])) < 0.011 and float(r["fuel"]) > 1.0, "fuel charged ($%.2f)" % float(r["fuel"]))
	runner.check(Ledger.balance(cid, "exp:vehicle") - veh0 > 0.0, "and a little upkeep")
	runner.check(Ledger.cash(cid) - cash0 > 0.0, "a run leaves you better off in cash")
	runner.check(Logistics.job(id).is_empty(), "the run left the list")
	runner.eq(Logistics.history(3)[0]["id"], id, "and is in the history")
	runner.eq(int(GameState.stat("van_runs")), 1, "counted")
	runner.check(GameState.flag("first_delivery_run"), "first run recorded")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_a_worse_route_pays_less_and_costs_more() -> void:
	var cid := _van()
	var a := _job(STOPS, 150.0, 12)
	var b := _job(STOPS, 150.0, 12)
	runner.check(Logistics.accept(a["id"])["ok"] and Logistics.accept(b["id"])["ok"], "two identical runs accepted")
	var best := Logistics.best_order(STOPS)
	var worst: Array = []
	var worst_px := 0.0
	for perm in RouteGame._perms(STOPS.size()):
		var px := Logistics.route_px(STOPS, perm)
		if px > worst_px:
			worst_px = px
			worst = perm
	var good := Logistics.drive(a["id"], best["order"])
	var poor := Logistics.drive(b["id"], worst)
	runner.check(float(poor["pay"]) < float(good["pay"]) and float(poor["fuel"]) > float(good["fuel"]) and int(poor["minutes"]) > int(good["minutes"]),
		"the long way round: less pay, more fuel, more time")
	runner.check(Ledger.check_balanced(), "ledger balanced")
	var _u := cid


func test_late_runs_pay_less_and_forgotten_ones_are_cancelled() -> void:
	var cid := _van()
	var best := Logistics.best_order(STOPS)
	# late: the deadline passed while you were busy, still inside the grace time
	var late := _job(STOPS, 150.0, 8)
	Logistics.accept(late["id"])
	late["by"] = Clock.now() - 30
	var r := Logistics.drive(late["id"], best["order"])
	runner.check(r["late"], "late")
	runner.check(absf(float(r["pay"]) - 150.0 * 1.1 * 0.6) < 0.02, "pays 40%% less (%.2f)" % float(r["pay"]))
	runner.eq(str(Logistics.history(1)[0]["status"]), "late", "recorded as late")
	# failed: accepted, then left until well after the deadline
	var lost := _job(STOPS, 150.0, 8)
	Logistics.accept(lost["id"])
	lost["by"] = Clock.now() - 7 * 60
	var rev0 := -Ledger.balance(cid, "revenue")
	Logistics._housekeeping(Clock.now())
	runner.check(Logistics.job(lost["id"]).is_empty(), "the client cancelled it")
	var rec: Dictionary = Logistics.history(1)[0]
	runner.eq(str(rec["status"]), "failed", "a failed run")
	runner.eq(float(rec["pay"]), 0.0, "pays nothing")
	runner.eq(-Ledger.balance(cid, "revenue"), rev0, "no revenue")
	runner.eq(int(GameState.stat("van_runs_failed")), 1, "counted")
	runner.check(GameState.data["messages"].any(func(m): return m["from"] == "client"), "with a message from the client")
	# an open run nobody took lapses at its deadline
	var stale := _job(STOPS, 150.0, 1)
	stale["by"] = Clock.now() - 1
	Logistics._housekeeping(Clock.now())
	runner.check(Logistics.job(stale["id"]).is_empty(), "an untaken run lapses")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_you_can_only_carry_so_many_runs() -> void:
	_van()
	for i in 4:
		_job(STOPS)
	var ids: Array = Logistics.open_jobs().map(func(j): return j["id"])
	for i in 3:
		runner.check(Logistics.accept(ids[i])["ok"], "run %d accepted" % (i + 1))
	runner.check(not Logistics.accept(ids[3])["ok"], "a fourth is too many")


func test_drivers_need_the_van_and_work_a_run_every_workday() -> void:
	Company.register("Haul Test Co", "ecommerce", "22 Founders Lane")
	Company.open_business_account(27000.0)
	GameState.set_flag("business_account_opened")
	var cid := GameState.company_id()
	Staff.register_employer()
	runner.eq(Staff.hire_block("driver"), "needs a van (buy one from Sam at Dockside Motors)", "no van, no driver")
	runner.check(Logistics.buy_van()["ok"], "bought the van")
	runner.eq(Staff.hire_block("driver"), "", "now a driver can be hired")
	runner.eq(Staff.workplace("driver"), "pier7_warehouse", "he works out of Pier 7")
	runner.check(Staff.post_job("driver")["ok"], "job posted")
	Clock.advance(int(Staff.cfg()["applicant_delay_hours"]) * 60 + 5)
	runner.check(Staff.hire(Staff.S()["applicants"][0]["id"])["ok"], "driver hired")
	var p: Dictionary = Staff.people()[0]
	runner.eq(str(p["role"]), "driver", "a driver")
	runner.eq(str(p["outfit"]), "logistics_site", "in work clothes")
	var t := Clock.now()
	while Clock.weekday(t) != 3:
		t += Clock.DAY
	var wed := t - t % Clock.DAY
	runner.check(Staff.is_working(p, wed + 10 * 60) or wed + 10 * 60 < int(p["start"]), "works weekdays")
	runner.check(not Staff.is_working(p, wed + 3 * Clock.DAY + 10 * 60), "not Saturdays")
	runner.check(not Staff.is_working(p, wed + 8 * 60), "not before 9:00")
	# a working day: runs are posted at 7:00, the driver takes one at 9:00 and it pays out by the afternoon
	_to_workday(6, int(p["start"]) - 3 * 60)
	Clock.advance(65)   # 7:05, posted
	for i in 6:
		if Logistics.open_jobs().any(func(j): return j["kind"] != "rush"):
			break
		Logistics.post_jobs()
	var rev0 := -Ledger.balance(cid, "revenue")
	var runs0 := int(GameState.stat("van_runs"))
	Clock.advance(2 * 60)   # 9:05
	var driving := Logistics._jobs_with("driving")
	runner.eq(driving.size(), 1, "the driver has taken one run")
	var jd: Dictionary = driving[0]
	runner.eq(str(jd["driver"]), str(p["id"]), "his")
	var st: Dictionary = jd["driver_stats"]
	runner.check(float(st["score"]) < 0.93 and float(st["score"]) > 0.6, "plans the route worse than a good player (%.2f)" % float(st["score"]))
	Clock.advance(int(st["minutes"]) + 5)
	runner.eq(int(GameState.stat("van_runs")), runs0 + 1, "one run done")
	var rec: Dictionary = Logistics.history(1)[0]
	runner.eq(str(rec["who"]), str(p["name"]).get_slice(" ", 0), "driven by him")
	runner.check(-Ledger.balance(cid, "revenue") - rev0 > 90.0, "the fee is banked as revenue")
	runner.check(absf(float(rec["pay"]) - float(jd["pay"]) * (0.9 + 0.2 * float(st["score"])) * (0.6 if bool(rec["late"]) else 1.0)) < 0.02, "pay follows his score")
	# one run per workday: nothing more today
	Clock.advance(3 * 60)
	runner.eq(int(GameState.stat("van_runs")), runs0 + 1, "still just one run that day")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_no_van_no_business() -> void:
	runner.eq(Logistics.post_jobs(), 0, "nothing is posted without a van")
	_to(2, 6)
	Clock.advance(3 * 60)
	runner.eq(Logistics.open_jobs().size(), 0, "no runs on the board")
	runner.check(not GameState.data.has("logistics") or Logistics.open_jobs().is_empty(), "and nothing was created")


func test_a_closed_company_sells_the_van() -> void:
	var cid := _van()
	var cash0 := Ledger.cash(cid)
	var got := Logistics.on_company_closed(cid)
	runner.check(absf(got - 9800.0 * 0.55) < 0.01, "sold at auction for 55%% (%.0f)" % got)
	runner.check(not Logistics.has_van() and not GameState.flag("van_owned"), "no van any more")
	runner.check(absf(Ledger.cash(cid) - cash0 - got) < 0.01, "the money came in")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_help_cards_and_badges_exist() -> void:
	for k in ["os_logistics", "route_game"]:
		runner.check(Help.has(k), "help card " + k)
	for k in ["stock_location", "own_van_shipping", "fuel_cost", "vehicle_insurance", "delivery_run", "route_planning", "driver_staff", "van_capacity"]:
		runner.check(DataDB.glossary.has(k), "badge card " + k)


func test_a_full_stockroom_names_the_warehouse_with_room() -> void:
	_company()
	runner.check(Living.lease("pier7_warehouse")["ok"], "leased")
	var home := "riverside_studio"
	var cap := Ecommerce.location_capacity(home)
	runner.eq(Ecommerce.space_block(home, 200), "", "room at home to begin with")
	runner.check(Ecommerce.buy("tradelink_wholesale", "phone_stand", cap - 100, home).get("ok", false), "home nearly filled")
	var why := Ecommerce.space_block(home, 200)
	runner.check(why != "", "stock on the way counts: 200 more won't fit")
	runner.check(why.contains(Ecommerce.location_name("pier7_warehouse")), "the message names the warehouse with room: " + why)
	var r := Ecommerce.buy("tradelink_wholesale", "phone_stand", 200, home)
	runner.check(not r.get("ok", true) and str(r.get("error", "")) == why, "the order says the same")
	runner.check(Ecommerce.buy("tradelink_wholesale", "phone_stand", 200, "pier7_warehouse").get("ok", false), "and goes to Pier 7")
	runner.check(Ledger.check_balanced(), "ledger balanced")
