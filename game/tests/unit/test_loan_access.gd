extends RefCounted
var runner

func _eligible() -> String:
	Company.register("Lending Test", "ecommerce", "22 Founders Lane")
	Company.open_business_account(10000)
	var cid := GameState.company_id()
	GameState.data["entities"][cid]["founded"] = Clock.now() - 14 * Clock.DAY
	Ledger.post(cid, "Lending fixture stock", [{"acct": "inventory", "dr": 6000}, {"acct": "cash", "cr": 6000}])
	return cid

func _check(id: String, expected: bool) -> void:
	var rows := Bank.eligibility()
	runner.eq(rows.size(), 6, "every condition returned even after a failure")
	for row in rows:
		if row["id"] == id:
			runner.eq(row["ok"], expected, id)
			runner.check(str(row["hint_action"]) != "", "next step exists")
	runner.check(Ledger.check_balanced(), "eligibility is read-only and balanced")

func test_company_requirement() -> void:
	_check("company", false)
	runner.eq(Bank.offer()["error"], "We lend to registered companies.", "original refusal priority")

func test_account_requirement() -> void:
	Company.register("Lending Test", "ecommerce", "22 Founders Lane")
	_check("account", false)
	runner.eq(Bank.offer()["error"], "Open a business account with us first.", "original account refusal")

func test_credit_and_ban_requirement() -> void:
	_eligible()
	Bank.B()["credit"] = 559
	_check("credit", false)
	Bank.B()["credit"] = 560
	Bank.B()["no_loans_until"] = Clock.now() + Clock.DAY
	_check("credit", false)
	for row in Bank.eligibility():
		if row["id"] == "credit":
			runner.eq(row["gap"], 0, "ban does not invent a score shortfall")
	Bank.B()["no_loans_until"] = Clock.now()
	_check("credit", true)

func test_arrears_requirement() -> void:
	var cid := _eligible()
	Bank.B()["loans"]["old"] = {"entity": cid, "status": "late"}
	_check("arrears", false)
	Bank.B()["loans"]["old"]["status"] = "called"
	_check("arrears", false)
	runner.eq(Bank.offer()["error"], "Not while a loan is in arrears.", "original arrears refusal")

func test_age_requirement_and_contract_alternative() -> void:
	var cid := _eligible()
	GameState.data["entities"][cid]["founded"] = Clock.now()
	_check("age", false)
	GameState.data["contracts"]["active"] = {"seller": cid, "status": "active", "total": 10000, "upfront_paid": 1000}
	_check("age", true)
	runner.eq(Bank.offer()["max"], 8000, "original floor of stock 3000 plus contract 5400")

func test_capacity_requirement_and_formula_unchanged() -> void:
	var cid := _eligible()
	runner.eq(Bank.offer()["max"], 3000, "half of inventory, original offer")
	Ledger.post(cid, "Remove fixture stock", [{"acct": "cash", "dr": 6000}, {"acct": "inventory", "cr": 6000}])
	_check("capacity", false)
	runner.eq(Bank.offer()["error"], "Your books don't support a loan yet. Show me more gross profit.", "original capacity refusal")

func test_all_conditions_pass_and_reading_preserves_ledger() -> void:
	_eligible()
	var ledger: Dictionary = GameState.data["ledger"].duplicate(true)
	for row in Bank.eligibility():
		runner.check(row["ok"], str(row["id"]))
	runner.check(Bank.offer()["ok"], "eligible offer")
	runner.eq(GameState.data["ledger"], ledger, "reading never posts money")


func test_original_weighted_offer_rounding_and_cap() -> void:
	var cid := _eligible()
	runner.check(Bank.take_loan(2000, 12)["ok"], "existing debt recorded by real disbursement")
	Ledger.post(cid, "Recent sales", [{"acct": "cash", "dr": 2400}, {"acct": "revenue", "cr": 2400}])
	Ledger.post(cid, "Sales cost", [{"acct": "cogs", "dr": 1200}, {"acct": "cash", "cr": 1200}])
	Ledger.post(cid, "Invoice sale", [{"acct": "accounts_receivable", "dr": 1000}, {"acct": "revenue", "cr": 1000}])
	GameState.data["contracts"]["active"] = {"seller": cid, "status": "active", "total": 10000, "upfront_paid": 1000}
	Clock.advance(1)   # statements use an exclusive end timestamp
	var o := Bank.offer()
	runner.eq(o["max"], 13000, "original: 6600 GP + 700 AR + 5400 contracts + 3000 stock - 2000 debt, floored")
	runner.eq(o["reasons"].size(), 5, "all original formula components retained")
	Ledger.post(cid, "Large sale", [{"acct": "cash", "dr": 500000}, {"acct": "revenue", "cr": 500000}])
	Clock.advance(1)
	runner.eq(Bank.offer()["max"], 250000, "original lending cap")
	runner.check(Ledger.check_balanced(), "weighted offer never changes balanced books")


func test_actual_older_save_without_appointment_loads_and_keeps_books() -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)
	var f := FileAccess.open(SaveSystem._path(6), FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/contracts_before_closure_pre36.json"))
	f.close()
	runner.check(SaveSystem.load_data(6), "loads real earlier-build save")
	var ledger: Dictionary = GameState.data["ledger"].duplicate(true)
	var contracts: Dictionary = GameState.data["contracts"].duplicate(true)
	runner.eq(Bank.appointment_hint(), "", "missing optional appointment means no reminder")
	runner.eq(Bank.credit(), 680, "original default score")
	runner.eq(Bank.eligibility().size(), 6, "older company can read all new conditions")
	runner.eq(GameState.data["ledger"], ledger, "reading old save never posts journals")
	runner.eq(GameState.data["contracts"], contracts, "old contracts unchanged")
	runner.check(Ledger.check_balanced(), "older save balanced")

func test_appointment_weekend_and_saved_schedule() -> void:
	GameState.data["clock"]["minutes"] = Clock.at_day_time(0, 16 * 60)
	var due := Bank.book_appointment()
	runner.check(due > Clock.now() and Bank.marcus_on_duty(due), "next actual working slot")
	runner.check(Clock.weekday(due) >= 1 and Clock.weekday(due) <= 5, "weekdays only")
	Bank.book_appointment()
	runner.eq(Sim.pending("bank.appointment").size(), 1, "rebooking replaces reminder")
	runner.check(SaveSystem.save(6) and SaveSystem.load_data(6), "reminder survives real save/load")
	runner.eq(Bank.B()["appointment"], due, "saved due time")
	runner.eq(Sim.pending("bank.appointment").size(), 1, "saved scheduled notification")
	runner.check(Ledger.check_balanced(), "appointment costs no money")

func _screen(officer := false) -> LoanModal:
	var m := LoanModal.new(officer)
	m.body = UIK.vbox()
	m.footer = UIK.hbox()
	m.add_child(m.body)
	m.add_child(m.footer)
	m.build()
	return m

func _bank_scene() -> WorldScene:
	var ws := WorldScene.new()
	ws.kind = "interior"
	ws.scene_id = "nexus_bank"
	SceneRouter.current = ws
	return ws

func test_counter_meeting_unlocks_borrow_button() -> void:
	_eligible()
	GameState.data["npcs"]["marcus"] = {"met": false, "relationship": 3, "convo_done": ["marcus_loan"]}
	GameState.data["clock"]["minutes"] = Clock.at_day_time(1, 13 * 60)
	var ws := _bank_scene()
	var m := _screen()
	runner.check(m.find_child("MeetMarcus", true, false) != null, "counter has direct officer access")
	m._entry()
	runner.eq(GameState.data["npcs"]["marcus"]["relationship"], 3, "meeting keeps existing NPC history")
	runner.eq(GameState.data["npcs"]["marcus"]["convo_done"], ["marcus_loan"], "conversation receipts preserved")
	runner.check(m.find_child("TakeLoan", true, false) != null, "meeting exposes borrow button")
	m.free()
	SceneRouter.current = null
	ws.free()
	runner.check(Ledger.check_balanced(), "meeting does not move money")

func test_off_duty_booking_and_outside_bank_navigation() -> void:
	GameState.data["clock"]["minutes"] = Clock.at_day_time(0, 16 * 60)
	var m := _screen()
	runner.check(m.find_child("BookLoanAppointment", true, false) != null, "booking visible off duty")
	runner.check(m.find_child("RouteNexusBank", true, false) != null, "brochure outside bank supplies navigation")
	Bank.book_appointment()
	runner.check(Bank.appointment_hint().contains("Nexus Bank"), "persisted task says exactly where to go")
	m.free()
	runner.check(Ledger.check_balanced(), "booking has no cost")

func test_ineligible_screen_has_all_conditions_and_no_borrow() -> void:
	var m := _screen(true)
	var labels := m.find_children("*", "Label", true, false).map(func(l): return l.text)
	for row in Bank.eligibility():
		runner.check(labels.any(func(t): return str(t).contains(row["label"])), "visible requirement: " + row["id"])
	runner.check(m.find_child("TakeLoan", true, false) == null, "cannot borrow while ineligible")
	m.free()
	runner.check(Ledger.check_balanced(), "reading checklist preserves books")


func test_checklist_boolean_rows_and_numeric_units() -> void:
	var m := _screen()
	for id in ["company", "account", "arrears"]:
		var row := m.find_child("Eligibility_" + id, true, false)
		runner.eq(row.get_child_count(), 2, "boolean row contains only status and next step: " + id)
	var capacity := m.find_child("Eligibility_capacity", true, false)
	runner.eq(capacity.get_child(1).text, "Current $0 · required $2,000 · gap $2,000", "capacity always uses money units")
	var age := m.find_child("Eligibility_age", true, false)
	runner.eq(age.get_child(1).text, "Current 0 days · required 14 days · 14 more days", "age states remaining days")
	var credit := m.find_child("Eligibility_credit", true, false)
	runner.eq(credit.get_child(1).text, "Current 680 points · required 560 points · gap 0 points", "credit remains numeric with units")
	m.free()
	runner.check(Ledger.check_balanced(), "display does not change money")


func test_first_missing_prerequisite_is_primary_and_booking_secondary() -> void:
	var m := _screen(true)
	var first: Button = m.footer.get_child(0)
	runner.eq(first.name, "PrerequisiteCompany", "company comes before account")
	runner.check(first.has_theme_stylebox_override("normal"), "first prerequisite is primary")
	var booking: Button = m.find_child("BookLoanAppointment", true, false)
	runner.check(not booking.has_theme_stylebox_override("normal"), "booking is secondary")
	m.free()
	Company.register("Lending Test", "ecommerce", "22 Founders Lane")
	m = _screen()
	first = m.footer.get_child(0)
	runner.eq(first.name, "PrerequisiteAccount", "account becomes first action after registration")
	runner.check(first.has_theme_stylebox_override("normal"), "account action is primary")
	booking = m.find_child("BookLoanAppointment", true, false)
	runner.check(not booking.has_theme_stylebox_override("normal"), "booking stays secondary")
	m.free()
	runner.check(Ledger.check_balanced(), "prioritising actions has no money effect")

func test_signing_takes_only_afternoon_and_first_payment_stays_thirty_days() -> void:
	_eligible()
	GameState.data["clock"]["minutes"] = Clock.at_day_time(1, 13 * 60)
	var before := Clock.now()
	var ws := _bank_scene()
	var m := _screen(true)
	m._sign()
	runner.eq(Clock.now() - before, 4 * 60, "only afternoon elapsed")
	var loan: Dictionary = Bank.loans()[0]
	runner.eq(int(loan["next"]) - int(loan["opened"]), 30 * Clock.DAY, "first payment still thirty days after funds arrive")
	runner.eq(int(loan["paid_n"]), 0, "no immediate repayment")
	m.free()
	SceneRouter.current = null
	ws.free()
	runner.check(Ledger.check_balanced(), "disbursement is balanced")
