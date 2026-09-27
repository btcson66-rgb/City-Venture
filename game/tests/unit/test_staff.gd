extends RefCounted
## Staff: employer registration, job ads, applicants, payroll (paid and missed), packing, support, marketing.

var runner


func _company(cash := 20000.0) -> String:
	var r := Company.register("Test Goods", "ecommerce", "22 Founders Lane")
	runner.check(r.get("ok", false), "company registered: %s" % str(r))
	var r2 := Company.open_business_account(cash)
	runner.check(r2.get("ok", false), "business account: %s" % str(r2))
	return GameState.company_id()


func _applicants(role: String) -> Array:
	runner.check(Staff.post_job(role)["ok"], "job posted")
	Clock.advance(int(Staff.cfg()["applicant_delay_hours"]) * 60 + 5)
	return Staff.S()["applicants"]


func _to_friday_evening() -> void:
	while not (Clock.weekday() == 5 and Clock.hour() == 18):
		Clock.advance(60)


func test_hiring_needs_company_account_and_employer_registration() -> void:
	runner.eq(Staff.hire_block(), "register a company first", "no company")
	_company()
	runner.eq(Staff.hire_block(), "register as an employer at City Hall", "needs employer registration")
	var cid := GameState.company_id()
	var cash0 := Ledger.cash(cid)
	runner.check(Staff.register_employer()["ok"], "registered as employer")
	runner.eq(cash0 - Ledger.cash(cid), 150.0, "fee from the company account")
	runner.eq(Staff.hire_block(), "", "can hire now")
	runner.eq(Staff.hire_block("packer"), "needs an office (lease Suite 2B)", "packers need the office")


func test_post_job_applicants_and_hire() -> void:
	_company()
	Staff.register_employer()
	var apps := _applicants("support")
	runner.eq(apps.size(), 3, "three applicants arrive within a day")
	for a in apps:
		runner.check(int(a["skill"]) >= 1 and int(a["skill"]) <= 5, "skill in range")
		runner.check(float(a["salary_week"]) >= 540.0 and float(a["salary_week"]) <= 700.0, "salary within the role band")
	var r := Staff.hire(apps[0]["id"])
	runner.check(r["ok"], "hired")
	runner.eq(Staff.count(), 1, "team of one")
	runner.check(Staff.S()["applicants"].is_empty(), "other applicants released")


func test_payroll_paid_on_friday() -> void:
	var cid := _company(20000.0)
	Staff.register_employer()
	var a: Dictionary = _applicants("marketer")[0]
	Staff.hire(a["id"])
	var cash0 := Ledger.cash(cid)
	_to_friday_evening()
	runner.check(GameState.stat("payrolls_run") >= 1.0, "payroll ran on Friday 17:00")
	var paid := 0.0
	for e in Ledger.entries(cid, 1000):
		if str(e["source"].get("type", "")) == "payroll":
			paid -= Ledger.entry_cash(e)
	runner.eq(paid, float(a["salary_week"]) * GameState.stat("payrolls_run"), "paid the weekly salary")
	runner.check(Ledger.cash(cid) < cash0, "cash went down")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_missed_payroll_becomes_wages_owed_and_hurts_morale() -> void:
	var cid := _company(2000.0)
	Staff.register_employer()
	var a: Dictionary = _applicants("marketer")[0]
	Staff.hire(a["id"])
	# drain the company account
	Ledger.expense(cid, "other", Ledger.cash(cid) - 10.0, "test drain")
	var m0 := int(Staff.people()[0]["morale"])
	_to_friday_evening()
	runner.check(GameState.stat("payrolls_missed") >= 1.0, "payroll bounced")
	runner.check(Staff.wages_owed() >= float(a["salary_week"]) - 0.01, "wages owed recorded as a liability")
	if Staff.count() > 0:
		runner.check(int(Staff.people()[0]["morale"]) < m0, "morale fell")
	runner.check(Ledger.check_balanced(), "ledger balanced")
	# topping up pays the arrears at the next payroll
	Ledger.post(cid, "test capital", [{"acct": "cash", "dr": 5000.0}, {"acct": "equity", "cr": 5000.0}], {"type": "capital"})
	Clock.advance(60)
	_to_friday_evening()
	if Staff.count() > 0:
		runner.eq(Staff.wages_owed(), 0.0, "arrears paid with the next payroll")


func test_marketer_raises_demand() -> void:
	_company()
	Staff.register_employer()
	var before := Ecommerce.demand_mult("wireless_earbuds")
	Staff.hire(_applicants("marketer")[0]["id"])
	Clock.advance(2 * Clock.DAY)   # starts the next morning at 9:00
	runner.check(Ecommerce.demand_mult("wireless_earbuds") > before, "demand multiplier up with a marketer")


func test_packer_packs_at_the_office() -> void:
	var cid := _company(25000.0)
	Staff.register_employer()
	runner.check(Living.lease("suite_2b").get("ok", false), "leased Suite 2B")
	var apps := _applicants("packer")
	runner.check(Staff.hire(apps[0]["id"])["ok"], "packer hired")
	# stock at the office and a few orders placed there
	Ecommerce.buy("tradelink_wholesale", "water_bottle", 60, "suite_2b")
	Clock.advance(6 * Clock.DAY)
	runner.check(Ecommerce.stock("suite_2b", "water_bottle") >= 60, "stock at the office")
	var l := Ecommerce.create_listing("water_bottle", 17.99, "self")
	runner.check(l.get("ok", false), "listed")
	var guard := 0
	while Ecommerce.orders_with(["placed"], "suite_2b").size() < 3 and guard < 72:
		guard += 1
		Clock.advance(60)
	# next weekday morning the packer works through them
	while not (Clock.weekday() >= 1 and Clock.weekday() <= 5 and Clock.hour() == 12):
		Clock.advance(60)
	runner.check(GameState.stat("orders_packed_by_staff") >= 1.0, "packer packed orders (%d)" % int(GameState.stat("orders_packed_by_staff")))
	var _u := cid
