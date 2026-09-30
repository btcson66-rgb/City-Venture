extends RefCounted
## Old Town and the café: the district is on the map and walkable from Shopping Street; a café needs the lease, the
## fit-out and the food licence before it opens; somebody has to be behind the counter; the till, supplies, pastry
## waste and the rating behave; baristas work café hours and show up at the café, not the office.

var runner


func _company(cash := 20000.0) -> String:
	Company.register("Corner Test Co", "ecommerce", "22 Founders Lane")
	Company.open_business_account(cash)
	GameState.set_flag("business_account_opened")
	return GameState.company_id()


## A leased, fitted, licensed café with supplies in and the clock at `h` o'clock on the next Monday.
func _open_cafe(h := 7) -> String:
	var cid := _company()
	runner.check(Living.lease("corner_cafe")["ok"], "leased the corner unit")
	runner.check(Cafe.fit_out()["ok"], "fitted out")
	runner.check(Cafe.apply_permit()["ok"], "applied for the licence")
	runner.check(Cafe.order_supplies("large")["ok"], "ordered supplies")
	Clock.advance(3 * Clock.DAY)
	_to(1, h)
	return cid


## On to the next `weekday` (0 = Sunday) at h:00.
func _to(weekday: int, h: int) -> void:
	Clock.advance(60 - Clock.minute_of_day() % 60)
	while not (Clock.weekday() == weekday and Clock.hour() == h):
		Clock.advance(60)


func test_old_town_is_open_and_linked() -> void:
	runner.check(DataDB.districts.has("old_town"), "district data loads")
	runner.eq(str(DataDB.district_def_in_city("old_town").get("status", "")), "active", "open on the city map")
	var linked := false
	for ex in DataDB.districts["shopping_street"]["exits"]:
		linked = linked or ex["to"] == "old_town"
	runner.check(linked, "walkable from Shopping Street")
	var on_line := false
	for l in DataDB.city["metro"]["lines"]:
		on_line = on_line or "old_town" in l["stations"]
	runner.check(on_line, "has a metro station")
	for bid in ["okafor_lettings", "corner_cafe_unit", "old_town_studio"]:
		var b := DataDB.building(bid)
		runner.eq(str(b.get("district", "")), "old_town", bid + " is in Old Town")
		runner.check(DataDB.buildings_meta.has(District.facade(b["exterior"])), bid + " has a facade to draw")
	runner.eq(str(DataDB.businesses["cafe"]["status"]), "active", "the café business is open")


func test_cafe_needs_lease_fitout_and_licence() -> void:
	runner.check(not Cafe.leased(), "not leased at the start")
	runner.check(not Living.lease("corner_cafe")["ok"], "leases go to registered companies")
	var cid := _company()
	var cash0 := Ledger.cash(cid)
	runner.check(Cafe.apply_permit()["error"] == "lease the café unit first", "the licence needs the premises")
	runner.check(Living.lease("corner_cafe")["ok"], "leased")
	runner.check(absf(cash0 - Ledger.cash(cid) - 1900.0 * 3) < 0.01, "first month + two months' deposit")
	runner.eq(Cafe.open_block(), "fit out the unit", "fit-out next")
	runner.check(Cafe.fit_out()["ok"], "fit-out ordered")
	runner.check(Cafe.fitting() and not Cafe.fitted(), "fitters at work overnight")
	runner.check(Cafe.apply_permit()["ok"], "licence applied for")
	runner.check(Cafe.permit_pending(), "being processed")
	Clock.advance(Clock.DAY + 10)
	runner.check(Cafe.fitted(), "fitted a day later")
	runner.check(not Cafe.permitted(), "licence not through yet")
	Clock.advance(Clock.DAY + 10)
	runner.check(Cafe.permitted() and Cafe.ready_to_open(), "licensed two days later: ready to open")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_nobody_behind_the_counter_means_shut() -> void:
	_open_cafe()
	Clock.advance(10 * 60 + 5)   # Monday 7:00 → after closing
	var d: Dictionary = Cafe.S()["days"].back()
	runner.eq(int(d["served"]), 0, "no staff, owner not in: nobody served")
	runner.check(int(d["shut_hours"]) > 0, "the café stayed shut")
	runner.eq(int(d["waste"]), 20, "the standing pastry order was binned")


func test_owner_shift_serves_customers_and_banks_the_till() -> void:
	var cid := _open_cafe(8)
	var rev0 := -Ledger.balance(cid, "revenue")
	MiniGames.auto = -1.0
	var r := Cafe.owner_shift(0.9)
	runner.check(r["ok"], "worked the counter (%s)" % str(r.get("error", "")))
	runner.check(int(r["served"]) > 5, "served customers in two busy morning hours (%d)" % int(r["served"]))
	runner.eq(int(Cafe.S()["supplies"]), 400 - int(Cafe.S()["today"]["served"]), "each cup uses supplies")
	_to(1, 18)
	runner.check(-Ledger.balance(cid, "revenue") > rev0, "the till was banked at closing")
	runner.check(GameState.flag("cafe_first_sale"), "first sale recorded")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_baristas_open_every_day_and_price_moves_demand() -> void:
	var cid := _open_cafe(6)
	Staff.register_employer()
	runner.eq(Staff.hire_block("barista"), "", "baristas can be hired once there's a café")
	runner.check(Staff.post_job("barista")["ok"], "job posted")
	Clock.advance(int(Staff.cfg()["applicant_delay_hours"]) * 60 + 5)
	var apps: Array = Staff.S()["applicants"]
	runner.check(Staff.hire(apps[0]["id"])["ok"], "barista hired")
	var p: Dictionary = Staff.people()[0]
	runner.eq(Staff.workplace("barista"), "corner_cafe", "works at the café")
	# café hours, Saturday included, not the office's Mon–Fri 9–17
	var t := Clock.now()
	while Clock.weekday(t) != 6:
		t += Clock.DAY
	var sat_noon := t - t % Clock.DAY + 12 * 60
	runner.check(Staff.is_working(p, sat_noon) or sat_noon < int(p.get("start", 0)), "works Saturdays")
	runner.check(not Staff.is_working(p, sat_noon + Clock.DAY), "not Sundays")
	runner.check(not Staff.is_working(p, sat_noon - 5 * 60 - 30), "not before 7:00")
	var base := Cafe.expected_day_demand()
	Cafe.set_price("coffee", 6.0)
	runner.check(Cafe.expected_day_demand() < base * 0.7, "a $6 coffee sends people elsewhere")
	Cafe.set_price("coffee", 4.2)
	# a week with a barista: open every day, money in the till
	Cafe.order_supplies("large")
	for i in 7:
		Clock.advance(Clock.DAY)
	runner.check(Cafe.last_days(6, "served") > 60, "a week of customers (%d)" % int(Cafe.last_days(6, "served")))
	runner.check(-Ledger.balance(cid, "revenue") > 300.0, "revenue booked")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_running_out_and_queues_pull_the_rating_down() -> void:
	_open_cafe(6)
	Cafe.S()["supplies"] = 5
	Cafe.S()["owner_from"] = Clock.now()
	Cafe.S()["owner_until"] = Clock.now() + 11 * 60
	var r0 := float(Cafe.S()["rating"])
	_to(1, 18)
	var d: Dictionary = Cafe.S()["days"].back()
	runner.check(int(d["stock_lost"]) > 0, "customers turned away when the coffee ran out")
	runner.check(float(Cafe.S()["rating"]) < r0, "rating fell (%.2f → %.2f)" % [r0, float(Cafe.S()["rating"])])


func test_rent_goes_on_the_shop_line() -> void:
	var cid := _company()
	Living.lease("corner_cafe")
	runner.check(Ledger.balance(cid, "exp:rent_shop") > 0.0, "shop rent, not office rent")
	runner.eq(Ledger.balance(cid, "exp:rent_office"), 0.0, "no office rent")


func test_your_cafe_has_seats_for_its_customers() -> void:
	var room := Interior.new()
	room.def = DataDB.building("corner_cafe_unit")["interior"]
	var seats := room.seats()
	runner.check(seats.size() >= 8, "the café's stools are seats (%d)" % seats.size())
	runner.check(seats.filter(func(s): return not s["staff"]).size() >= 8, "customers may take all of them")
	room.free()
