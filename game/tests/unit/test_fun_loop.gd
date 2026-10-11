extends RefCounted
var runner

func test_old_wait_objective_keeps_id_but_uses_active_products() -> void:
	var objective := StoryEngine.objective_def("goal_month")
	runner.check(not objective["complete_when"].any(func(c): return str(c).contains("month_closes")), "no month wait gate")
	StoryEngine.St()["active"] = ["goal_month"]
	StoryEngine.St()["chapters_done"] = ["ch3_open_for_business"]
	StoryEngine.St()["chapter"] = "ch3_open_for_business"
	for product in ["water_bottle", "wireless_earbuds"]:
		var order := Ecommerce.buy("tradelink_wholesale", product, int(DataDB.product(product).get("moq", 60)))
		if not order.get("ok", false): order = Ecommerce.buy("tradelink_wholesale", product, 60)
		runner.check(order["ok"], "actual stock purchased")
		Ecommerce.handle("eco.po_arrive", {"po":order["po_id"]})
		runner.check(Ecommerce.create_listing(product, 30, "self")["ok"], "actual product listed")
	StoryEngine.check()
	runner.check("goal_month" in StoryEngine.St()["done"], "old active objective completes with actual listings")
	runner.eq(StoryEngine.St()["chapter"], "ch4_growing_pains", "next chapter starts without month close")
	runner.eq(GameState.stat("month_closes"), 0, "no fabricated month close")
	runner.check(Ledger.check_balanced(), "story progress does not unbalance books")

func test_already_completed_wait_receipt_is_preserved() -> void:
	StoryEngine.St()["chapter"] = "ch3_open_for_business"
	StoryEngine.St()["done"].append("goal_month")
	StoryEngine.check()
	runner.eq(StoryEngine.St()["chapter"], "ch4_growing_pains", "completed legacy receipt continues")
	StoryEngine.check()
	runner.eq(StoryEngine.St()["done"].count("goal_month"), 1, "receipt remains unique")

func test_skip_runs_real_purchase_scheduler_and_stops_at_decision() -> void:
	StoryEngine.St()["active"] = ["ch2_stock"]
	StoryEngine.St()["chapter"] = "ch2_first_customer"
	var order := Ecommerce.buy("tradelink_wholesale", "water_bottle", 60)
	runner.check(order["ok"], "real purchase made")
	var cash := Ledger.cash("player")
	runner.check(FunLoop.next_event() > Clock.now(), "real pending arrival visible")
	FunLoop.skip_next()
	runner.check(Ledger.cash("player") <= cash, "skip gives no money")
	runner.check(Ledger.check_balanced(), "scheduled transactions balanced")

func test_skip_noop_for_action_goal_and_stale_schedule() -> void:
	StoryEngine.St()["active"] = ["goal_month"]
	var now := Clock.now()
	Sim.schedule(now + 60, "eco.deliver", {"order":"missing"})
	runner.eq(FunLoop.next_event(), -1, "listing action never skips unrelated shipment")
	runner.check(not FunLoop.skip_next(), "no action bypass")
	runner.eq(Clock.now(), now, "no time moved")

func test_two_entry_shifts_pay_only_real_hours() -> void:
	Careers.hire("barista")
	Clock.advance_to(Clock.at_day_time(1, 9 * 60))
	var cash := Ledger.cash("player")
	var first := Careers.work_shift("barista", 1.0)
	var second := Careers.work_shift("barista", 1.0)
	runner.check(first["ok"] and second["ok"], "two paid sessions fit opening hours")
	runner.eq(Clock.minute_of_day(), 17 * 60, "eight actual working hours pass")
	runner.eq(Ledger.cash("player") - cash, float(first["pay"]) + float(second["pay"]), "pay equals actual sessions")
	runner.check(second["promoted"], "good performance earns early promotion")
	runner.check(Ledger.check_balanced(), "wages balanced")

func test_staff_waits_expose_actual_applicant_and_weekly_payroll() -> void:
	Company.register("Short goals", "ecommerce", "Suite 2B")
	Company.open_business_account(10000)
	Staff.register_employer()
	Staff.post_job("support")
	StoryEngine.St()["active"] = ["ch4_hire"]
	runner.check(FunLoop.next_event() > Clock.now(), "actual applicant reply can be skipped to")
	Clock.advance_to(FunLoop.next_event())
	runner.eq(FunLoop.next_event(), -1, "ready applicants require a hiring choice")
	Staff.hire(str(Staff.S()["applicants"][0]["id"]))
	StoryEngine.St()["active"] = ["ch4_payroll"]
	var payroll := FunLoop.next_event()
	runner.eq(Clock.weekday(payroll), int(Staff.cfg()["payroll_weekday"]), "real payroll weekday")
	runner.eq(Clock.minute_of_day(payroll), int(Staff.cfg()["payroll_hour"]) * 60, "real payroll hour")
	runner.check(Ledger.check_balanced(), "staff transactions balance")

func test_existing_medical_bill_does_not_trap_waiting_player() -> void:
	StoryEngine.St()["active"] = ["ch2_stock"]
	var order := Ecommerce.buy("tradelink_wholesale", "water_bottle", 60)
	runner.check(order["ok"], "actual inventory order")
	TrafficSafety.S()["accidents"].append({"debt":10.0,"counterparty_fault":false,"treated":true,"settled":false})
	runner.check(TrafficSafety.needs_attention(), "existing care item needs attention")
	var before := Clock.now()
	runner.check(FunLoop.skip_next(), "existing payable does not disable all waiting")
	runner.check(Clock.now() > before, "actual time advances")
	runner.check(Ledger.check_balanced(), "no free settlement or inventory")

func test_genuine_pre_change_waiting_save_continues_without_new_money() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/saves/pr182-pre-fun-ch3.json")
	runner.check(SaveSystem.validate_text(text)["ok"], "genuine pre-change envelope validates")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SaveSystem.DIR))
	runner.check(SaveSystem._atomic_write(SaveSystem._path(19), text), "fixture copied to isolated test slot")
	runner.check(SaveSystem.load_data(19), "real played old save loads")
	var cash := Ledger.cash("player")
	var company_cash := Ledger.cash(GameState.company_id())
	StoryEngine.check()
	runner.check("goal_month" in StoryEngine.St()["done"], "actual existing products complete old wait objective")
	runner.eq(StoryEngine.St()["chapter"], "ch4_growing_pains", "real old save can continue")
	runner.eq(Ledger.cash("player"), cash, "continuation adds no personal money")
	runner.eq(Ledger.cash(GameState.company_id()), company_cash, "continuation adds no company money")
	runner.check(Ledger.check_balanced(), "historical transactions remain balanced")

func test_completed_late_shift_survives_render_delay_and_releases_pause() -> void:
	UIRoot.close_all()
	Help.auto = false
	Careers.hire("barista")
	Clock.advance_to(Clock.at_day_time(1, 17 * 60 + 59))
	var cash := Ledger.cash("player")
	var expected := Careers.pay_for("barista", 1.0, 2)
	Clock.world_active = true
	# Start the actual settlement, then simulate a delayed render frame while the fade awaits.
	UIRoot._finish_shift("barista", {"score":1.0})
	Clock._process(10.0)
	runner.eq(Clock.minute_of_day(), 17 * 60 + 59, "fade cannot cross the admitted shift cutoff")
	await runner.get_tree().create_timer(1.0).timeout
	runner.eq(Careers.shifts("barista"), 1, "completed real shift counts")
	runner.eq(Ledger.cash("player") - cash, expected, "exact two-hour wages, no latency compensation money")
	runner.check(not "work_payout" in Clock.pause_reasons(), "settlement releases its pause")
	runner.check(Ledger.check_balanced(), "late completed work is balanced")
	Clock.world_active = false
	UIRoot.close_all()

func test_stale_workplace_card_does_not_start_unpaid_work() -> void:
	UIRoot.close_all()
	Help.auto = false
	Careers.hire("barista")
	Clock.advance_to(Clock.at_day_time(1, 19 * 60))
	var cash := Ledger.cash("player")
	UIRoot.work_shift_flow("barista")
	await runner.get_tree().process_frame
	runner.check(UIRoot.top_modal() is JobModal, "stale card refreshes instead of playing unpaid work")
	runner.eq(Careers.shifts("barista"), 0, "no fabricated completion")
	runner.eq(Ledger.cash("player"), cash, "no unplayed wages")
	UIRoot.close_all()
