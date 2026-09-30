class_name NoSoftlocksTour
extends RefCounted
## Focused screenshots of recovered tutorial/story states; gameplay walkthrough remains separate.

var bot


func _init(b) -> void:
	bot = b


func _reset() -> void:
	UIRoot._suppress_decisions = true
	GameState.new_game({"name": "Alex Chen", "seed": 24})
	GameState.set_flag("maya_intro_done")
	Clock.clear_pauses()
	Clock.world_active = false
	GameState.data["tutorial"] = {"v": 3, "step": Tutorial._index("shift"), "seen": {}, "off": false}
	SceneRouter._enter("interior", "riverside_apartment", "door", "up")
	UIRoot.set_hud_visible(true)


func run() -> void:
	SaveSystem.DIR = "user://softlock_tour_saves"
	bot.step("Tutorial recovery after quitting before first shift")
	_reset()
	Careers.hire("barista")
	Careers.quit()
	await bot.wait(1.0)
	bot.expect(UIRoot.tutorial.current().get("id", "") == "shift", "shift still needed, instructions lead to hiring")
	await bot.shot("quit_job_recovery")
	bot.step("Listing paused before first order")
	_reset()
	GameState.data["tutorial"]["step"] = Tutorial._index("order")
	Ecommerce.E()["listings"]["old"] = {"id": "old", "product": "phone_stand", "active": false}
	await bot.wait(1.0)
	bot.expect(Tutorial.step_text(UIRoot.tutorial.current()).contains("no longer active"), "relisting instructions")
	await bot.shot("paused_listing_recovery")
	bot.step("Earlier chapter forecast receipt retained")
	_reset()
	GameState.data["tutorial"]["off"] = true
	StoryEngine.St()["done"] = ["ch4_employer", "ch4_post", "ch4_hire", "ch4_payroll"]
	GameState.set_flag("cash_forecast_viewed")
	StoryEngine.start_chapter("ch4_growing_pains")
	await bot.wait(4.0)
	bot.expect("ch4_forecast" in StoryEngine.St()["done"], "forecast already done: immediately chapter 5")
	await bot.shot("early_forecast_next_chapter")
	bot.step("Two negative cash closes: honest progression")
	_reset()
	GameState.data["tutorial"]["off"] = true
	Ledger.expense("player", "other", 40000.0, "loss")
	Clock.advance(1)
	StoryEngine.St()["chapter"] = "ch6_cash_is_oxygen"
	StoryEngine.St()["active"] = ["ch6_close"]
	StoryEngine.St()["done"] = ["ch6_forecast", "ch6_bridge", "ch6_collect"]
	MonthClose.run(2031, 6)
	MonthClose.run(2031, 7)
	StoryEngine.check()
	await bot.wait(4.0)
	bot.expect("ch6_close" in StoryEngine.St()["done"] and not GameState.flag("ch6_month_in_black"), "carry on without claiming positive cash")
	UIRoot.phone.open()
	UIRoot.phone._open_app("messages")
	await bot.wait(1.0)
	await bot.click_named("Thread_maya")
	await bot.wait(1.0)
	await bot.shot("negative_cash_honest_message")
	bot.step("Long translated decision keeps its confirmation reachable")
	UIRoot.phone.close()
	_reset()
	GameState.data["tutorial"]["off"] = true
	var ctx := {"count": "1", "frozen": "$856", "until": "6/21", "ratio": "90%", "supplier": "Lumina Direct",
		"lost": "$85.60", "reroute_cost": "$890", "reroute_cost_v": 890.0, "reroute_fee": "$34", "wire_days": 3,
		"loan": "$890", "loan_v": 890.0, "apr": "8%"}
	var m := DecisionModal.new({"id": "rail_frozen", "iid": "layout_tour", "ctx": ctx})
	UIRoot.open_modal(m)
	await bot.wait(0.5)
	bot.expect(m.panel.get_global_rect().end.y <= 360.0, "long decision fits the viewport")
	await bot.shot("long_decision_scroll")
	m.outcome = I18n.t(DataDB.events["rail_frozen"]["choices"][1]["outcome"])
	m.rebuild()
	await bot.wait(0.5)
	var ok: Button = m.find_child("DecisionOK", true, false)
	bot.expect(ok != null and ok.get_global_rect().end.y <= 360.0, "outcome confirmation is on-screen")
	await bot.shot("decision_outcome_reachable")
	await bot.click_named("DecisionOK")
	await bot.wait(0.3)
	bot.expect(UIRoot.top_modal() == null, "confirmation closes the decision through input")
	bot.step("Declined contract advances without claiming stock or delivery")
	_reset()
	GameState.data["tutorial"]["off"] = true
	GameState.set_flag("forecast_checked_ch6")
	GameState.set_flag("costs_cut")
	Contracts.C()["old"] = {"tag": "big_contract", "status": "rejected"}
	StoryEngine.start_chapter("ch5_big_contract")
	await bot.wait(4.0)
	bot.expect("ch5_big_contract" in StoryEngine.St()["chapters_done"], "declined contract advances")
	var explanation := I18n.t("The Crestline deal will not go ahead. Carry on with your next venture.")
	bot.expect(GameState.data["messages"].filter(func(msg): return str(msg["text"]) == explanation).size() == 1, "translated unavailable-deal explanation appears once")
	UIRoot.phone.open()
	UIRoot.phone._open_app("messages")
	await bot.wait(0.5)
	await bot.click_named("Thread_maya")
	await bot.wait(0.5)
	await bot.shot("declined_contract_honest_message")
