class_name StoryEngine
extends RefCounted
## Chapters → objectives, all from data/story/chapters.json (see STORY_IMPLEMENTATION.md).


static func St() -> Dictionary:
	return GameState.data["story"]


static func chapters() -> Array:
	return DataDB.story.get("chapters", [])


static func chapter_def(id: String) -> Dictionary:
	for c in chapters():
		if c["id"] == id:
			return c
	return {}


static func objective_def(id: String) -> Dictionary:
	for c in chapters():
		for o in c.get("objectives", []):
			if o["id"] == id:
				var d: Dictionary = o.duplicate()
				d["_chapter"] = c["id"]
				return d
	for o in DataDB.story.get("side", []):
		if o["id"] == id:
			var d2: Dictionary = o.duplicate()
			d2["_chapter"] = ""
			return d2
	return {}


static func start_chapter(id: String) -> void:
	var c := chapter_def(id)
	if c.is_empty():
		return
	St()["chapter"] = id
	GameState.timeline(I18n.t(c.get("title", id)), "chapter")
	# ch3_open_for_business → backdrops/chapter_3 (the illustration shows once the art exists)
	UIRoot.show_chapter_card(c.get("title", id), c.get("subtitle", ""), "backdrops/chapter_" + id.get_slice("_", 0).trim_prefix("ch"))
	var obs: Array = c.get("objectives", [])
	if not obs.is_empty():
		start_objective(obs[0]["id"])
	EventBus.objective_changed.emit()


static func start_objective(id: String) -> void:
	if id in St()["active"] or id in St()["done"]:
		return
	var d := objective_def(id)
	if d.is_empty():
		push_warning("Story: unknown objective " + id)
		return
	St()["active"].append(id)
	run_actions(d.get("on_start", []))
	EventBus.objective_changed.emit()


static func complete_objective(id: String) -> void:
	if not id in St()["active"]:
		return
	St()["active"].erase(id)
	St()["done"].append(id)
	var d := objective_def(id)
	if d.get("main", false):
		EventBus.notify.emit("✓ " + fill(d.get("text", id)), "good", "check")
	run_actions(d.get("on_complete", []))
	var ch: String = d.get("_chapter", "")
	if ch != "":
		var c := chapter_def(ch)
		var obs: Array = c.get("objectives", [])
		var idx := -1
		for i in obs.size():
			if obs[i]["id"] == id:
				idx = i
		if idx >= 0 and idx + 1 < obs.size() and not d.get("no_auto_next", false):
			start_objective(obs[idx + 1]["id"])
		var all_done := true
		for o in obs:
			if not o["id"] in St()["done"]:
				all_done = false
		if all_done and not ch in St()["chapters_done"]:
			St()["chapters_done"].append(ch)
			GameState.timeline(I18n.t("Completed %s.") % c.get("title", ch), "chapter")
			EventBus.chapter_completed.emit(ch)
			run_actions(c.get("on_complete", []))
			if c.get("next", "") != "":
				start_chapter(c["next"])
	EventBus.objective_changed.emit()


static func check() -> void:
	# saves that finished the June sandbox before chapters 4–6 existed carry on into Chapter 4
	if St().get("chapter", "") == "ch3_open_for_business" and "goal_month" in St()["done"] and not chapter_def("ch4_growing_pains").is_empty():
		start_chapter("ch4_growing_pains")
	# saves that finished Chapter 6 before Chapter 7 existed were parked on the growth goal: carry on into Chapter 7
	if St().get("chapter", "") == "ch6_cash_is_oxygen" and "ch6_cash_is_oxygen" in St()["chapters_done"] and not chapter_def("ch7_supply_shock").is_empty():
		St()["active"].erase("goal_growth")
		start_chapter("ch7_supply_shock")
	# saves that finished Chapter 9 before Chapters 10–12 existed were parked on the growth goal: carry on into Chapter 10
	if St().get("chapter", "") == "ch9_clearing_crisis" and "ch9_clearing_crisis" in St()["chapters_done"] and not chapter_def("ch10_digital_rails").is_empty() \
			and not "ch10_digital_rails" in St()["chapters_done"]:
		St()["active"].erase("goal_growth")
		start_chapter("ch10_digital_rails")
	var changed := true
	var guard := 0
	while changed and guard < 20:
		guard += 1
		changed = false
		for id in St()["active"].duplicate():
			var d := objective_def(id)
			var conds: Array = d.get("complete_when", [])
			if conds.is_empty():
				continue
			if Cond.all(conds):
				complete_objective(id)
				changed = true


static func fill(text: String) -> String:
	return EventEngine.fill(text, {})


## The objective shown on the HUD.
static func main_objective() -> Dictionary:
	for id in St()["active"]:
		var d := objective_def(id)
		if d.get("main", false):
			d["text"] = fill(d.get("text", ""))
			return d
	return {}


static func active_objectives() -> Array:
	var out: Array = []
	for id in St()["active"]:
		var d := objective_def(id)
		d["text"] = fill(d.get("text", ""))
		out.append(d)
	return out


static func run_actions(actions: Array) -> void:
	for a in actions:
		if a.has("if") and not Cond.eval(str(a["if"])):
			continue
		match a.get("do", ""):
			"dialogue":
				UIRoot.queue_dialogue(a["id"])
			"message":
				if int(a.get("delay_min", 0)) > 0:
					Sim.schedule(Clock.now() + int(a["delay_min"]), "story.message", {"from": a["from"], "text": a["text"]})
				else:
					GameState.add_message(a["from"], fill(a["text"]))
			"set_flag":
				if int(a.get("delay_min", 0)) > 0:
					Sim.schedule(Clock.now() + int(a["delay_min"]), "story.flag", {"flag": a["flag"], "value": a.get("value", true)})
				else:
					GameState.set_flag(a["flag"], a.get("value", true))
			"world_year":
				World.set_year(int(a["year"]))
			"flag_reset":
				GameState.set_flag(a["flag"], false)
			"start":
				start_objective(a["objective"])
			"complete":
				complete_objective(a["objective"])
			"timeline":
				GameState.timeline(fill(a["text"]), a.get("kind", "story"))
			"toast":
				EventBus.notify.emit(fill(a["text"]), a.get("kind", "info"), a.get("icon", "info"))
			"event":
				# one-off story events never queue twice (a fallback timer and a conversation can both fire them)
				var guard := "event_done:" + str(a["id"])
				if int(a.get("delay_min", 0)) > 0:
					Sim.schedule(Clock.now() + int(a["delay_min"]), "evt.trigger", {"id": a["id"], "ctx": a.get("ctx", {}), "story_once": true})
				elif not GameState.flag(guard) and not EventEngine._queued(a["id"]):
					GameState.set_flag(guard)
					EventEngine.trigger(a["id"], a.get("ctx", {}))
			"chapter":
				start_chapter(a["id"])
			"card":
				# a title band across the screen (the story's ending cards)
				UIRoot.show_chapter_card(fill(a.get("title", "")), fill(a.get("subtitle", "")), str(a.get("art", "")))
			"rail_exploit":
				# Chapter 11: the bridge is hit `delay_min` from now (or at once); no-op if it already was
				if int(a.get("delay_min", 0)) > 0:
					Sim.schedule(Clock.now() + int(a["delay_min"]), "rail.exploit", {})
				else:
					Rails.exploit()
			"lift_cap":
				Ecommerce.lift_cap()
			"force_return":
				# the first customer issue (STORY_IMPLEMENTATION §2): a return on the latest delivered order
				var latest := ""
				var lt := -1
				for o in GameState.data["ecommerce"]["orders"].values():
					if o["status"] == "delivered" and int(o.get("delivered", 0)) > lt:
						lt = int(o["delivered"])
						latest = o["id"]
				if latest != "":
					Sim.schedule(Clock.now() + int(a.get("delay_min", 60)), "eco.return_request", {"order": latest})
			_:
				push_warning("Story: unknown action %s" % str(a))


static func handle(kind: String, p: Dictionary) -> void:
	match kind:
		"story.message":
			GameState.add_message(p["from"], fill(p["text"]))
		"story.flag":
			GameState.set_flag(p["flag"], p.get("value", true))
			check()
		"story.check":
			check()
