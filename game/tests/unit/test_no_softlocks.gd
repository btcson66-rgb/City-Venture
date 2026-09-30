extends RefCounted
## Every main objective is seeded before its chapter starts; none needs a later input tick.

var runner


func test_every_interior_door_spawn_has_player_clearance() -> void:
	for bid in DataDB.buildings:
		if not DataDB.buildings[bid].has("interior"):
			continue
		var room := Interior.new()
		room.build(bid)
		var door: Vector2 = room.spawns["door"]
		var player_space := Rect2(door - Vector2(6, 4), Vector2(12, 7))
		for solid in room.solids:
			runner.check(not player_space.intersects(solid), bid + " door spawn has collision clearance")
		room.free()


func test_long_decision_cannot_push_confirmation_out_of_viewport() -> void:
	var m := DecisionModal.new({"id": "rail_frozen", "iid": "layout_test", "ctx": {}})
	m.help_key = ""
	runner.add_child(m)
	runner.check(m.panel.get_combined_minimum_size().y <= 352.0, "long choices fit the 360px viewport")
	m.outcome = "A long outcome. ".repeat(200)
	m.rebuild()
	runner.check(m.panel.get_combined_minimum_size().y <= 352.0, "long outcome cannot push footer off-screen")
	runner.check(m.find_child("DecisionOK", true, false) is Button, "confirmation has a stable name")
	m.free()


func test_direct_return_resolution_before_chapter() -> void:
	GameState.inc_stat("returns_resolved")
	for o in StoryEngine.chapter_def("ch2_first_customer")["objectives"]:
		if o["id"] != "ch2_issue":
			StoryEngine.St()["done"].append(o["id"])
	StoryEngine.start_chapter("ch2_first_customer")
	runner.check("ch2_issue" in StoryEngine.St()["done"], "a return resolved outside the story event still counts")


func test_tutorial_drains_consecutive_completed_steps() -> void:
	var tut := Tutorial.new()
	GameState.data["tutorial"] = {"v": 3, "step": 0, "seen": {"move": true, "os": true}, "off": false}
	for f in ["maya_intro_done", "bought_coffee_bloom_coffee", "business_chosen"]:
		GameState.set_flag(f)
	GameState.mark_visited("riverside")
	GameState.mark_visited("startup_hub")
	GameState.inc_stat("purchase_orders")
	Ecommerce.E()["listings"]["old"] = {"active": false}
	tut.skip_completed()
	runner.eq(int(tut.st()["step"]), Tutorial._index("order"), "all ten completed steps drain before showing the next card")
	tut.free()


func test_stale_first_order_receipt_can_retry_without_duplicate_schedule() -> void:
	GameState.data["tutorial"] = {"v": 3, "step": Tutorial._index("order"), "seen": {"first_order": true}, "off": false}
	Ecommerce.E()["listings"]["retry"] = {"id": "retry", "product": "phone_stand", "active": true}
	UIRoot.tutorial._first_order()
	runner.eq(Sim.pending("eco.order_place").size(), 1, "a stale seen receipt doesn't block a new attempt")
	UIRoot.tutorial._first_order()
	runner.eq(Sim.pending("eco.order_place").size(), 1, "only one pending attempt")


func test_all_arrow_data_targets_exist() -> void:
	for c in StoryEngine.chapters():
		for o in c["objectives"]:
			var t: Dictionary = o.get("target", {})
			if t.has("building"):
				var b := DataDB.building(t["building"])
				runner.check(not b.is_empty(), o["id"] + " building exists")
				if t.has("action"):
					runner.check(b.get("interior", {}).get("interactables", []).any(func(i): return i["action"] == t["action"]), o["id"] + " action exists in target room")
			if t.has("district"):
				runner.check(DataDB.districts.has(t["district"]), o["id"] + " district exists")


func test_arrow_ignores_locked_terminal() -> void:
	var ws := WorldScene.new()
	var spot := Interactable.new()
	spot.action = "open_company_os"
	spot.params = {"requires": "desk_access"}
	ws.add_child(spot)
	runner.add_child(ws)
	spot.add_to_group("interactable")
	runner.check(UIRoot.tutorial._interactable(ws, "open_company_os").is_empty(), "expired pass: no arrow to locked desk")
	GameState.data["living"]["day_pass"] = Clock.day_index()
	runner.check(not UIRoot.tutorial._interactable(ws, "open_company_os").is_empty(), "valid pass: desk target restored")
	ws.free()


func test_tutorial_every_step_already_done() -> void:
	var tut := Tutorial.new()
	for s in Tutorial.STEPS:
		runner._fresh_game()
		GameState.data["tutorial"] = {"v": 3, "step": Tutorial._index(s["id"]), "seen": {}, "off": false}
		match s["id"]:
			"move", "os":
				GameState.data["tutorial"]["seen"][s["id"]] = true
			"phone": GameState.set_flag("maya_intro_done")
			"exit": GameState.mark_visited("riverside")
			"coffee": GameState.set_flag("bought_coffee_bloom_coffee")
			"east": GameState.mark_visited("startup_hub")
			"cowork": GameState.data["living"]["day_pass"] = Clock.day_index()
			"board": GameState.set_flag("business_chosen")
			"buy": GameState.inc_stat("purchase_orders")
			"shoot": Ecommerce.E()["listings"]["old"] = {"active": false}
			"order": GameState.inc_stat("orders_placed")
			"pack": GameState.inc_stat("orders_packed")
			"ship", "dropoff": GameState.inc_stat("orders_shipped")
			"paid": GameState.inc_stat("orders_delivered")
			"job": Careers.hire("barista")
			"shift": GameState.inc_stat("shifts_worked")
			"sleep": GameState.inc_stat("nights_slept")
		runner.check(tut.step_done(s), s["id"] + " seeded before entry")
		tut.skip_completed()
		runner.check(int(tut.st()["step"]) > Tutorial._index(s["id"]), s["id"] + " skipped on entry")
	tut.free()


func test_tutorial_expired_pass_and_quit_job() -> void:
	var tut := Tutorial.new()
	GameState.data["tutorial"] = {"v": 3, "step": Tutorial._index("cowork"), "seen": {}, "off": false}
	GameState.data["living"]["day_pass"] = -1
	GameState.inc_stat("purchase_orders")
	tut.skip_completed()
	runner.check(int(tut.st()["step"]) > Tutorial._index("cowork"), "business already underway: use home laptop")
	Careers.hire("barista")
	Careers.quit()
	runner.check(tut.step_done(Tutorial.STEPS[Tutorial._index("job")]), "prior job survives quitting")
	var step: Dictionary = Tutorial.STEPS[Tutorial._index("shift")]
	runner.check(Tutorial.step_text(step).contains("Take a job again"), "no job: concrete recovery instructions")
	tut.free()


func test_news_receipts_do_not_cross_eras() -> void:
	World.set_year(3)
	InfoModal.news().free()
	StoryEngine.start_chapter("ch7_supply_shock")
	runner.check("ch7_news" in StoryEngine.St()["done"], "same era read before chapter")
	StoryEngine.start_chapter("ch8_green_shift")
	runner.check("ch8_news" in StoryEngine.St()["active"], "new era still needs reading")
	runner.check(SaveSystem.save(6), "save unread era")
	runner._fresh_game()
	runner.check(SaveSystem.load_data(6), "reload unread era")
	StoryEngine.check()
	runner.check("ch8_news" in StoryEngine.St()["active"], "load does not turn legacy receipt into current news")


func test_completed_chapter_resumes_once() -> void:
	for o in StoryEngine.chapter_def("ch1_arrival")["objectives"]:
		StoryEngine.St()["done"].append(o["id"])
	StoryEngine.start_chapter("ch1_arrival")
	runner.check("ch1_arrival" in StoryEngine.St()["chapters_done"], "completed objectives close the chapter")
	runner.eq(StoryEngine.St()["chapter"], "ch2_first_customer", "next chapter starts")
	var n: int = GameState.data["schedule"].size()
	StoryEngine.check()
	runner.eq(GameState.data["schedule"].size(), n, "no repeated completion actions")


func test_old_save_news_and_contract_receipts() -> void:
	GameState.data["world"]["year"] = 5
	GameState.set_flag("news_read")
	GameState.data["contracts"]["old"] = {"tag": "big_contract", "status": "paid"}
	runner.check(SaveSystem.save(6), "old shape saved")
	runner._fresh_game()
	runner.check(SaveSystem.load_data(6), "old shape loaded")
	runner.check(GameState.flag("news_read_y5") and not GameState.flag("news_read_y6"), "migrate only saved era")
	for f in ["offered", "decided", "delivered", "paid"]:
		runner.check(GameState.flag("big_contract_" + f), "reconcile " + f)
	runner.check(Ledger.check_balanced(), "migration leaves ledger balanced")


func test_expired_withdrawn_rejected_contracts_progress() -> void:
	for status in ["expired", "withdrawn", "rejected"]:
		runner._fresh_game()
		Contracts.C()["old"] = {"tag": "big_contract", "status": status}
		var notices: Array = []
		var capture := func(text, _kind, _icon): notices.append(str(text))
		EventBus.notify.connect(capture)
		StoryEngine.start_chapter("ch5_big_contract")
		EventBus.notify.disconnect(capture)
		runner.check("ch5_big_contract" in StoryEngine.St()["chapters_done"], status + " cannot block")
		runner.check(not notices.any(func(n): return n.contains("Get 800") or n.contains("Deliver Crestline")), status + " never claims stocking/delivery")
		runner.check(GameState.data["messages"].any(func(m): return str(m["text"]).contains("will not go ahead")), status + " honest alternative")
		runner.eq(GameState.data["messages"].filter(func(m): return str(m["text"]).contains("will not go ahead")).size(), 1, status + " explanation is not repeated per step")
		runner.check(Ledger.check_balanced(), status + " balanced")


func test_company_closed_contract_cannot_block() -> void:
	GameState.data["entities"]["old_co"] = {"closed": Clock.now()}
	Contracts.C()["old"] = {"tag": "big_contract", "status": "active", "seller": "old_co", "product": "desk_lamp", "qty": 800}
	StoryEngine.start_chapter("ch5_big_contract")
	runner.check("ch5_deliver" in StoryEngine.St()["done"], "closed seller: delivery skipped")
	GameState.set_flag("forecast_checked_ch6")
	StoryEngine.check()
	runner.check("ch6_collect" in StoryEngine.St()["done"], "closed seller: collection skipped")
	runner.check(GameState.data["messages"].any(func(m): return str(m["text"]).contains("will not go ahead")), "honest message")
	runner.eq(GameState.data["messages"].filter(func(m): return str(m["text"]).contains("will not go ahead")).size(), 1, "closed deal explanation once across chapters")
	runner.check(Ledger.check_balanced(), "story fallback does not move money")


func test_negative_cash_two_month_ends_progress() -> void:
	Ledger.expense("player", "other", 40000.0, "loss")
	StoryEngine.St()["active"] = ["ch6_close"]
	StoryEngine.St()["chapter"] = "ch6_cash_is_oxygen"
	for id in ["ch6_forecast", "ch6_bridge", "ch6_collect"]:
		StoryEngine.St()["done"].append(id)
	for i in 2:
		Clock.advance(1)
		MonthClose.run(2031, 6)
		StoryEngine.check()
		if i == 0:
			runner.check("ch6_close" in StoryEngine.St()["active"], "first negative close stays")
	runner.check("ch6_close" in StoryEngine.St()["done"], "second negative close progresses")
	runner.check(not GameState.flag("ch6_month_in_black"), "never claim recovery")
	runner.check(Ledger.check_balanced(), "balanced")

const FLAGS := {
 "ch1_phone": "maya_intro_done",
 "ch1_coffee": "bought_coffee_bloom_coffee",
 "ch1_board": "business_chosen",
 "ch2_issue": "first_issue_resolved",
 "ch3_bank": "business_account_opened",
 "ch3_workspace": "workspace_chosen",
 "ch3_os": "company_os_opened_as_company",
 "ch4_employer": "employer_registered",
 "ch4_forecast": "cash_forecast_viewed",
 "ch5_meet": "big_contract_offered",
 "ch5_decide": "big_contract_decided",
 "ch5_deliver": "big_contract_delivered",
 "ch6_forecast": "forecast_checked_ch6",
 "ch6_bridge": "loan_taken",
 "ch6_collect": "big_contract_paid",
 "ch6_close": "ch6_month_in_black",
 "ch7_news": "news_read_y3",
 "ch7_ken": "ch7_supply_plan",
 "ch7_price": "repriced",
 "ch7_close": "ch7_month_profit",
 "ch8_news": "news_read_y4",
 "ch8_pack": "packaging_green",
 "ch8_grant": "green_grant",
 "ch9_news": "news_read_y5",
 "ch9_lina": "met_lina",
 "ch10_news": "news_read_y6",
 "ch10_lina": "ch10_decided",
 "ch11_news": "news_read_y7",
 "ch11_freeze": "rail_recovered",
 "ch12_news": "news_read_y8",
 "ch12_licence": "import_licence",
 "ch12_offer": "offer_decided"
}

const STATS := {
 "ch2_supplier": [
  "purchase_orders",
  1.0
 ],
 "ch2_stock": [
  "stock_received",
  1.0
 ],
 "ch2_order": [
  "orders_placed",
  1.0
 ],
 "ch2_ship": [
  "orders_shipped",
  1.0
 ],
 "ch2_first_dollar": [
  "orders_delivered",
  1.0
 ],
 "ch4_post": [
  "jobs_posted",
  1.0
 ],
 "ch4_hire": [
  "hires",
  1.0
 ],
 "ch4_payroll": [
  "payrolls_run",
  1.0
 ],
 "ch9_import": [
  "import_orders",
  1.0
 ],
 "ch9_settle": [
  "import_cleared",
  1.0
 ],
 "ch9_arrive": [
  "import_received",
  1.0
 ],
 "ch10_import": [
  "import_orders_y6",
  1.0
 ],
 "ch10_arrive": [
  "import_received_y6",
  1.0
 ],
 "ch11_order": [
  "import_orders_y7",
  1.0
 ],
 "ch11_restock": [
  "import_received_y7",
  1.0
 ],
 "ch12_kyc": [
  "kyc_cleared",
  1.0
 ]
}

const VISITS := {
 "ch1_outside": "riverside",
 "ch1_cowork": "nexus_cowork"
}

func _early(id: String) -> void:
	var o := StoryEngine.objective_def(id)
	var chapter := str(o["_chapter"])
	# Earlier objectives were already completed in this save; the chapter must resume at the first unfinished one.
	for prev in StoryEngine.chapter_def(chapter)["objectives"]:
		if prev["id"] == id:
			break
		StoryEngine.St()["done"].append(prev["id"])
	if FLAGS.has(id):
		GameState.set_flag(FLAGS[id])
	elif STATS.has(id):
		GameState.inc_stat(STATS[id][0], STATS[id][1])
	elif VISITS.has(id):
		GameState.mark_visited(VISITS[id])
	else:
		match id:
			"ch2_listing":
				Ecommerce.E()["listings"]["old"] = {"active": false}
			"ch3_register":
				Company.register("Earlier Co", "ecommerce", "22 Founders Lane")
			"ch5_stock":
				Contracts.C()["earlier"] = {"tag": "big_contract", "status": "delivered"}
			"ch7_stock":
				Ecommerce._add_stock("riverside_studio", "phone_stand", 100, 3.0, 0.0)
			"ch8_product":
				Ecommerce.E()["listings"]["earlier"] = {"product": "solar_lamp", "active": true}
	StoryEngine.start_chapter(chapter)
	runner.check(id in StoryEngine.St()["done"], id + " completed during start_chapter")
	StoryEngine.check()
	runner.eq(StoryEngine.St()["done"].count(id), 1, id + " completes once")
	runner.check(Ledger.check_balanced(), id + " balanced")

func test_early_ch1_phone() -> void:
	_early("ch1_phone")


func test_early_ch1_outside() -> void:
	_early("ch1_outside")


func test_early_ch1_coffee() -> void:
	_early("ch1_coffee")


func test_early_ch1_cowork() -> void:
	_early("ch1_cowork")


func test_early_ch1_board() -> void:
	_early("ch1_board")


func test_early_ch2_supplier() -> void:
	_early("ch2_supplier")


func test_early_ch2_stock() -> void:
	_early("ch2_stock")


func test_early_ch2_listing() -> void:
	_early("ch2_listing")


func test_early_ch2_order() -> void:
	_early("ch2_order")


func test_early_ch2_ship() -> void:
	_early("ch2_ship")


func test_early_ch2_first_dollar() -> void:
	_early("ch2_first_dollar")


func test_early_ch2_issue() -> void:
	_early("ch2_issue")


func test_early_ch3_register() -> void:
	_early("ch3_register")


func test_early_ch3_bank() -> void:
	_early("ch3_bank")


func test_early_ch3_workspace() -> void:
	_early("ch3_workspace")


func test_early_ch3_os() -> void:
	_early("ch3_os")


func test_early_ch4_employer() -> void:
	_early("ch4_employer")


func test_early_ch4_post() -> void:
	_early("ch4_post")


func test_early_ch4_hire() -> void:
	_early("ch4_hire")


func test_early_ch4_payroll() -> void:
	_early("ch4_payroll")


func test_early_ch4_forecast() -> void:
	_early("ch4_forecast")


func test_early_ch5_meet() -> void:
	_early("ch5_meet")


func test_early_ch5_decide() -> void:
	_early("ch5_decide")


func test_early_ch5_stock() -> void:
	_early("ch5_stock")


func test_early_ch5_deliver() -> void:
	_early("ch5_deliver")


func test_early_ch6_forecast() -> void:
	_early("ch6_forecast")


func test_early_ch6_bridge() -> void:
	_early("ch6_bridge")


func test_early_ch6_collect() -> void:
	_early("ch6_collect")


func test_early_ch6_close() -> void:
	_early("ch6_close")


func test_early_ch7_news() -> void:
	_early("ch7_news")


func test_early_ch7_ken() -> void:
	_early("ch7_ken")


func test_early_ch7_stock() -> void:
	_early("ch7_stock")


func test_early_ch7_price() -> void:
	_early("ch7_price")


func test_early_ch7_close() -> void:
	_early("ch7_close")


func test_early_ch8_news() -> void:
	_early("ch8_news")


func test_early_ch8_pack() -> void:
	_early("ch8_pack")


func test_early_ch8_product() -> void:
	_early("ch8_product")


func test_early_ch8_grant() -> void:
	_early("ch8_grant")


func test_early_ch9_news() -> void:
	_early("ch9_news")


func test_early_ch9_import() -> void:
	_early("ch9_import")


func test_early_ch9_lina() -> void:
	_early("ch9_lina")


func test_early_ch9_settle() -> void:
	_early("ch9_settle")


func test_early_ch9_arrive() -> void:
	_early("ch9_arrive")


func test_early_ch10_news() -> void:
	_early("ch10_news")


func test_early_ch10_lina() -> void:
	_early("ch10_lina")


func test_early_ch10_import() -> void:
	_early("ch10_import")


func test_early_ch10_arrive() -> void:
	_early("ch10_arrive")


func test_early_ch11_news() -> void:
	_early("ch11_news")


func test_early_ch11_order() -> void:
	_early("ch11_order")


func test_early_ch11_freeze() -> void:
	_early("ch11_freeze")


func test_early_ch11_restock() -> void:
	_early("ch11_restock")


func test_early_ch12_news() -> void:
	_early("ch12_news")


func test_early_ch12_licence() -> void:
	_early("ch12_licence")


func test_early_ch12_kyc() -> void:
	_early("ch12_kyc")


func test_early_ch12_offer() -> void:
	_early("ch12_offer")
