class_name StoryEngine
extends RefCounted
## Chapters → objectives, all from data/story/chapters.json (see STORY_IMPLEMENTATION.md).

static var _checking := false


static func St() -> Dictionary:
	return GameState.data["story"]


static func chapters() -> Array:
	return DataDB.story.get("chapters", [])


## Side stories share objective conditions/actions, but never replace the main chapter.
static func side_stories() -> Dictionary:
	return DataDB.story.get("side_stories", {})


## Lazy state keeps saves written before side stories compatible.
static func side_progress() -> Dictionary:
	if not St().has("side_stories"):
		St()["side_stories"] = {}
	return St()["side_stories"]


static func side_available(id: String) -> bool:
	var d: Dictionary = side_stories().get(id, {})
	if d.is_empty() or d.get("objectives", []).is_empty() or side_progress().has(id):
		return false
	var business := str(d.get("business", ""))
	if business != "" and DataDB.businesses.get(business, {}).get("status", "") != "active":
		return false
	var company := GameState.company_id()
	var entity: Dictionary = GameState.data["entities"].get(company, {})
	if company == "" or entity.is_empty() or entity.has("closed"):
		return false
	return Cond.all(d.get("trigger", []))


static func available_side_stories() -> Array:
	var out: Array = []
	for id in side_stories():
		if side_available(str(id)):
			out.append(side_stories()[id])
	out.sort_custom(func(a, b): return str(a["id"]) < str(b["id"]))
	return out


static func start_side_story(id: String) -> bool:
	if not side_available(id):
		return false
	side_progress()[id] = {"company": GameState.company_id(), "status": "active", "skipped": false}
	_advance_side_story(id)
	check()
	return true


## Completion receipts precede actions, so repeated checks/reloads cannot award twice.
## An unavailable step continues the sequence but forfeits the completion reward.
static func _advance_side_story(id: String) -> void:
	var p: Dictionary = side_progress().get(id, {})
	if p.get("status", "") != "active":
		return
	var d: Dictionary = side_stories().get(id, {})
	if d.is_empty():
		return
	for o in d.get("objectives", []):
		if not o["id"] in St()["done"]:
			start_objective(str(o["id"]))
			return
	p["status"] = "unavailable" if p.get("skipped", false) else "completed"
	if p["status"] == "completed":
		run_actions(d.get("on_complete", []))
	else:
		run_actions(d.get("on_unavailable", []))


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
	for o in obs:
		if not o["id"] in St()["done"]:
			start_objective(o["id"])
			break
	_finish_chapter(id)
	check()
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
	check()   # already done before this step: do not wait for another interaction/hour


static func complete_objective(id: String, unavailable := false) -> void:
	if not id in St()["active"]:
		return
	St()["active"].erase(id)
	St()["done"].append(id)
	var d := objective_def(id)
	var side := str(d.get("_side_story", ""))
	if unavailable:
		# Several consecutive unavailable steps can share one explanation; say it once.
		var explanation := I18n.t(str(d["skip_text"]))
		if not GameState.data["messages"].any(func(m): return str(m.get("text", "")) == explanation):
			GameState.add_message("maya", d["skip_text"])
	elif d.get("main", false):
		EventBus.notify.emit("✓ " + fill(d.get("text", id)), "good", "check")
	if side != "" and unavailable:
		side_progress()[side]["skipped"] = true
		run_actions(d.get("on_skip", []))
	else:
		run_actions(d.get("on_complete", []))
	if side != "":
		_advance_side_story(side)
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
		_finish_chapter(ch)
	EventBus.objective_changed.emit()


## The objective being checked right now (read by the bots' watchdog when the game stops responding).
static var last_phase := ""


## A continued chapter may already have every objective done. Finish it once without replaying actions.
static func _finish_chapter(id: String) -> void:
	if id in St()["chapters_done"]:
		return
	var c := chapter_def(id)
	for o in c.get("objectives", []):
		if not o["id"] in St()["done"]:
			return
	St()["chapters_done"].append(id)
	GameState.timeline(I18n.t("Completed %s.") % I18n.t(str(c.get("title", id))), "chapter")
	EventBus.chapter_completed.emit(id)
	run_actions(c.get("on_complete", []))
	if c.get("next", "") != "":
		start_chapter(c["next"])


static func check() -> void:
	if _checking or not GameState.has_game():
		return
	_checking = true   # on_complete can start another chapter; the outer loop drains it
	_check_all()
	_checking = false   # cleared out here, so a script error inside can never leave the story stuck


static func _check_all() -> void:
	Customs.reconcile()
	OverseasPartners.reconcile()
	Contracts.reconcile_tags()
	# A closing company cannot leave a side objective waiting for a business action forever.
	for id in side_progress().keys():
		var p: Dictionary = side_progress()[id]
		if p.get("status", "") != "active":
			continue
		var company: Dictionary = GameState.data["entities"].get(p.get("company", ""), {})
		if company.is_empty() or company.has("closed"):
			p["status"] = "unavailable"
			for o in side_stories().get(id, {}).get("objectives", []):
				St()["active"].erase(o["id"])
			run_actions(side_stories().get(id, {}).get("on_unavailable", []))
		else:
			_advance_side_story(str(id))
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
	if "ch12_regulation_scale" in St()["chapters_done"] and not "ch13_first_order_abroad" in St()["chapters_done"] and St().get("chapter", "") == "ch12_regulation_scale":
		start_chapter("ch13_first_order_abroad")
	if "ch14_customs" in St()["chapters_done"] and not "ch15_currency_swing" in St()["chapters_done"] and St().get("chapter", "") == "ch14_customs":
		start_chapter("ch15_currency_swing")
	LegacyBusiness.reconcile()
	if "ch16_partner_overseas" in St()["chapters_done"] and not "ch17_consolidation" in St()["chapters_done"] and St().get("chapter", "") == "ch16_partner_overseas":
		start_chapter("ch17_consolidation")
	var guard := 0
	var limit: int = DataDB.story.get("side", []).size() + 1
	for c in chapters():
		limit += c.get("objectives", []).size()
	while changed and guard < limit:
		guard += 1
		changed = false
		for id in St()["active"].duplicate():
			last_phase = str(id)
			var d := objective_def(id)
			var conds: Array = d.get("complete_when", [])
			if conds.is_empty():
				continue
			if Cond.all(conds):
				complete_objective(id)
				changed = true
			elif not d.get("skip_when", []).is_empty() and Cond.all(d["skip_when"]):
				complete_objective(id, true)
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
			"legacy_begin":
				LegacyBusiness.begin(str(a["chapter"]))
			"consolidation_comparison":
				UIRoot.open_modal(LegacyBusiness.comparison())
			"fx_comparison_card":
				OverseasPartnerUI.fx_card()
			"partner_comparison_card":
				OverseasPartnerUI.partner_card()
			"overseas_begin":
				OverseasPartners.begin(str(a["chapter"]))
			"customs_begin":
				Customs.begin(str(a["chapter"]))
			"export_income_card":
				UIRoot.open_modal(ExportIncomeModal.new())
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
