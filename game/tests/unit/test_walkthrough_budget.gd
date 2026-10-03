extends RefCounted
var runner

func _offer() -> String:
	Company.register("Budget QA", "ecommerce", "22 Founders Lane")
	Company.open_business_account(20000)
	Rivals.initialize()
	var company := GameState.company_id()
	Staff.S()["people"]["E1"] = {"id":"E1", "role":"support", "salary_week":600.0}
	Rivals.S()["offers"]["E1"] = {"company":company, "status":"pending", "salary":650.0, "expires":Clock.now()+Clock.DAY}
	return company

func _trade(company: String) -> void:
	var id := Jobs.offer({"client":"Budget customer", "scope":"Completed consultancy", "segment":"consulting", "entity":company, "price":5000.0, "terms":0})
	Jobs.accept(id)
	Jobs.progress(id, 1)
	Jobs.deliver(id)
	Jobs.invoice(id)

func test_retention_needs_actual_profit_and_month_of_payroll_cash() -> void:
	var company := _offer()
	runner.check(not Walkthrough.retention_affordable("E1"), "capital alone is not trading profit")
	_trade(company)
	runner.check(Walkthrough.retention_affordable("E1"), "profitable business can retain within role wage range")
	Company.transfer(company, "player", 22500)
	runner.check(not Walkthrough.retention_affordable("E1"), "profitable operation still needs four weeks of cash wages")
	Company.transfer("player", company, 2500)
	runner.check(Walkthrough.retention_affordable("E1"), "cash reserve restored with actual owner capital")
	Ledger.expense(company, "maintenance", 6000, "Actual operating cost")
	runner.check(not Walkthrough.retention_affordable("E1"), "loss-making operation releases rather than increasing payroll")
	runner.check(Ledger.check_balanced(), "budget decisions create no income or expense")

func test_retention_rejects_wage_spiral_expired_other_or_closed_company() -> void:
	var company := _offer()
	_trade(company)
	var offer: Dictionary = Rivals.S()["offers"]["E1"]
	offer["salary"] = 1000.0
	runner.check(not Walkthrough.retention_affordable("E1"), "compounding wage bid beyond role budget rejected")
	offer["salary"] = 650.0
	offer["expires"] = Clock.now()
	runner.check(not Walkthrough.retention_affordable("E1"), "expired offer rejected")
	offer["expires"] = Clock.now()+Clock.DAY
	offer["company"] = "another_company"
	runner.check(not Walkthrough.retention_affordable("E1"), "original company ownership required")
	offer["company"] = company
	GameState.data["entities"][company]["closed"] = Clock.now()
	runner.check(not Walkthrough.retention_affordable("E1"), "closed company cannot retain")
	runner.check(not Walkthrough.retention_affordable("unknown"), "missing employee rejected")


class MissedCloseInput:
	extends RefCounted
	var runner
	var popup_handler: Callable
	var clicks := 0
	var cancels := 0
	func _init(r): runner = r
	func click(_control):
		clicks += 1
		await runner.get_tree().process_frame
		return false  # pointer click lost during relayout
	func key_action(_action):
		cancels += 1
		var ev := InputEventAction.new()
		ev.action = "pause"
		ev.pressed = true
		Input.parse_input_event(ev)
		await runner.get_tree().process_frame
		ev = InputEventAction.new()
		ev.action = "pause"
		ev.pressed = false
		Input.parse_input_event(ev)
	func wait(_seconds):
		await runner.get_tree().create_timer(0.02).timeout
	func log_line(_line): pass
	func fail(msg): runner.check(false, msg)

func test_missed_packing_close_uses_real_cancel_before_movement() -> void:
	Help.auto = false
	var panel := PackShipModal.new("riverside_studio")
	UIRoot.open_modal(panel)
	await runner.get_tree().process_frame
	var input := MissedCloseInput.new(runner)
	await Walkthrough.new(input).close_modal()
	await runner.get_tree().process_frame
	runner.eq(input.clicks, 1, "first pointer attempt was consumed")
	runner.eq(input.cancels, 1, "real cancel action dismisses the remaining panel")
	runner.check(not (UIRoot.top_modal() is PackShipModal), "movement is no longer blocked")
	UIRoot.close_all()
	Help.auto = true
