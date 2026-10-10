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
