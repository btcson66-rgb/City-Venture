extends RefCounted
## Onboarding: tutorial state in saves and the guide arrow's routing between districts.

var runner


func test_guide_routes_by_street_or_metro() -> void:
	runner.eq(Tutorial._next_hop("riverside", "startup_hub"), "startup_hub", "Riverside → Startup Hub on foot (east edge)")
	runner.eq(Tutorial._next_hop("startup_hub", "riverside"), "riverside", "and back")
	runner.eq(Tutorial._next_hop("civic_center", "financial"), "financial", "Civic Center → Financial on foot")
	runner.eq(Tutorial._next_hop("riverside", "civic_center"), "civic_center", "new canonical northern foot route")


func test_every_main_objective_target_is_resolvable() -> void:
	for ch in DataDB.story["chapters"]:
		for o in ch.get("objectives", []):
			var tg: Dictionary = o.get("target", {})
			if tg.has("building"):
				runner.check(DataDB.buildings.has(tg["building"]), "%s targets a real building" % o["id"])
			if tg.has("action"):
				var found := false
				for b in DataDB.buildings.values():
					for it in b.get("interior", {}).get("interactables", []):
						if it.get("action", "") == tg["action"] and (not tg.has("building") or b["id"] == tg["building"]):
							found = true
				runner.check(found, "%s: some interior offers action %s" % [o["id"], tg["action"]])
			if tg.has("district"):
				runner.check(DataDB.districts.has(tg["district"]), "%s targets a real district" % o["id"])


func test_tutorial_state_for_new_and_old_saves() -> void:
	var tut := Tutorial.new()
	runner.check(not GameState.data.has("tutorial"), "fresh game has no tutorial state yet")
	runner.check(tut.is_active(), "a new game gets the tutorial")
	runner.eq(int(GameState.data["tutorial"]["step"]), 0, "starts at step 0")
	GameState.data.erase("tutorial")
	GameState.data["story"]["chapter"] = "ch3_open_for_business"
	runner.check(not tut.is_active(), "a save from before the tutorial, past Chapter 1, is not interrupted")
	tut.restart()
	runner.check(tut.is_active(), "Replay tutorial turns it back on")
	tut.free()

func test_assisted_business_guide_does_not_require_an_optional_side_job() -> void:
	GameState.set_flag("test_assistant_run")
	AssistantPolicy.set_all(true)
	var tut := Tutorial.new()
	GameState.data["tutorial"] = {"step":Tutorial._index("pack"),"seen":{},"off":false,"v":Tutorial.VERSION}
	runner.eq(tut.current()["target"],{},"assistant packing does not send player back to a chore")
	runner.eq(tut.current()["ui"],[],"assistant packing does not highlight a mandatory manual action")
	UIRoot.tutorial._show_step(Tutorial._index("pack"))
	runner.eq(UIRoot.tutorial.body.text,I18n.t(str(tut.current()["text"])),"visible guide uses the assistant-aware instruction")
	AssistantPolicy.set_task("packing",false)
	runner.check(not tut.current()["target"].is_empty(),"manual packing guide remains available")
	AssistantPolicy.set_task("packing",true)
	GameState.set_flag("business_chosen")
	var job_step: Dictionary = Tutorial.STEPS[Tutorial._index("job")]
	runner.check(not tut.step_done(job_step),"no first sale cannot skip the actual business loop")
	GameState.inc_stat("orders_delivered")
	runner.check(tut.step_done(job_step),"actual business delivery makes side job optional")
	AssistantPolicy.set_task("packing",false)
	runner.check(not tut.step_done(job_step),"manual-route side-job guide remains intact")
	tut.free()
