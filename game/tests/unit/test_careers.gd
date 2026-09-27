extends RefCounted
## Careers: part-time jobs (shifts, wages, promotions, perks) and freelance consulting gigs.

var runner


func _to_next(hh: int) -> void:
	Clock.advance_to(Clock.at_day_time(1, hh * 60))


func test_jobs_data_valid() -> void:
	runner.check(DataDB.jobs.size() >= 5, "at least five part-time jobs")
	for id in DataDB.jobs:
		var j: Dictionary = DataDB.jobs[id]
		runner.check(j["ranks"].size() >= 3, "%s has a promotion ladder" % id)
		runner.check(str(j.get("perk", {}).get("desc", "")) != "", "%s has a perk" % id)


func test_hire_work_shift_and_get_paid() -> void:
	runner.check(Careers.hire("barista")["ok"], "hired")
	runner.eq(Careers.current_job(), "barista", "current job")
	var cash0 := Ledger.cash("player")
	var t0 := Clock.now()
	var r := Careers.work_shift("barista")   # Sunday 14:00, Bloom open till 20:00
	runner.check(r["ok"], "shift ok: %s" % str(r))
	runner.eq(Clock.now() - t0, 240, "a shift takes four hours")
	runner.eq(Ledger.cash("player") - cash0, 68.0, "4 h × $17 paid")
	runner.eq(-Ledger.balance("player", "wages"), 68.0, "booked as wages")
	runner.check(Ledger.check_balanced(), "ledger balanced")
	runner.eq(Careers.shift_block("barista"), "already worked today", "one shift a day")


func test_shift_needs_opening_hours() -> void:
	Careers.hire("barista")
	Clock.advance_to(Clock.at_day_time(0, 17 * 60))
	runner.eq(Careers.shift_block("barista"), "too late for a full shift", "17:00 + 4 h is past closing")
	Careers.hire("city_clerk")
	runner.eq(Careers.shift_block("city_clerk"), "closed now", "City Hall is shut on Sunday evening")


func test_promotion_raises_wage() -> void:
	Careers.hire("parcel_sorter")
	for i in 5:
		_to_next(9)
		runner.check(Careers.work_shift("parcel_sorter")["ok"], "shift %d" % i)
	runner.eq(str(Careers.rank("parcel_sorter")["title"]), "Route Planner", "promoted after 5 shifts")
	runner.eq(Careers.wage("parcel_sorter"), 19.0, "new hourly rate")


func test_perks_are_real() -> void:
	var base := Company.registration_fee()
	Careers.hire("city_clerk")
	runner.eq(Company.registration_fee(), base * 0.5, "clerk: half-price registration")
	runner.check(not Living.has_desk_access(), "no desk before")
	Careers.hire("cowork_host")
	runner.check(Living.has_desk_access(), "host: desk access")
	runner.eq(Company.registration_fee(), base, "discount ends with the job")
	Careers.hire("parcel_sorter")
	runner.eq(Careers.perk_value("ship_discount"), 0.15, "sorter: 15% shipping discount")
	Careers.quit()
	runner.eq(Careers.current_job(), "", "quit")


func test_freelance_gig_invoice_and_payment() -> void:
	Careers.start_freelance()
	var offers: Array = Careers.F()["offers"]
	runner.check(offers.size() >= 2, "offers on day one")
	var o: Dictionary = offers[0]
	var r := Careers.accept(o["id"])
	runner.check(r["ok"], "accepted")
	var rep0 := Careers.rep()
	var guard := 0
	var res := {}
	while guard < 20:
		guard += 1
		res = Careers.work_on(o["id"])
		if res.get("delivered", false):
			break
	runner.check(res.get("delivered", false), "delivered after enough sessions")
	runner.check(not res["late"], "on time")
	var fee := float(res["fee"])
	runner.eq(Ledger.balance("player", "accounts_receivable"), fee, "invoice sits in receivables")
	runner.check(Careers.rep() > rep0, "on-time delivery raises reputation")
	Clock.advance((int(o["terms"]) + 1) * Clock.DAY)
	var paid := 0.0
	for e in Ledger.entries("player", 100000):
		if str(e["source"].get("type", "")) == "gig_payment":
			paid += Ledger.entry_cash(e)
	runner.eq(paid, fee, "client pays the invoice into cash on terms")
	runner.eq(Ledger.balance("player", "accounts_receivable"), 0.0, "receivable cleared")
	runner.eq(str(Careers.F()["gigs"][o["id"]]["status"]), "paid", "gig paid")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_freelance_missed_deadline_cancels() -> void:
	Careers.start_freelance()
	var o: Dictionary = Careers.F()["offers"][0]
	Careers.accept(o["id"])
	var rep0 := Careers.rep()
	Clock.advance((int(o["days"]) + 5) * Clock.DAY)
	runner.eq(str(Careers.F()["gigs"][o["id"]]["status"]), "cancelled", "abandoned gig is cancelled")
	runner.check(Careers.rep() < rep0, "and costs reputation")
	runner.eq(Ledger.balance("player", "revenue"), 0.0, "no revenue for cancelled work")
