class_name FunLoop
extends RefCounted
## Short goals and bounded event skipping read existing receipts; no synthetic income.

static func cfg() -> Dictionary:
	return DataDB.economy.get("fun_loop", {})

static func progress() -> Dictionary:
	var objective := StoryEngine.main_objective()
	if objective.is_empty(): return {}
	if str(objective.get("id", "")) == "goal_month":
		return {"value":minf(2, GameState.stat("listings_active")), "max":2, "text":I18n.t("Products listed: %d / 2") % mini(2, int(GameState.stat("listings_active")))}
	var chapter := StoryEngine.chapter_def(str(StoryEngine.St().get("chapter", "")))
	var objectives: Array = chapter.get("objectives", [])
	var done := 0
	for item in objectives:
		if item["id"] in StoryEngine.St()["done"]: done += 1
	return {"value":done, "max":maxi(1, objectives.size()), "text":I18n.t("Small steps: %d / %d") % [done, objectives.size()]}

## Only current waiting steps expose time travel. Query again at activation.
static func next_event() -> int:
	if not GameState.has_game(): return -1
	var objective := StoryEngine.main_objective()
	var id := str(objective.get("id", ""))
	var kinds: Array = {"ch2_stock":["eco.po_arrive"], "ch2_order":["eco.order_place"], "ch2_ship":["eco.pickup"], "ch2_first_dollar":["eco.deliver"], "ch2_issue":["eco.return_request"]}.get(id, [])
	var next := -1
	for event in GameState.data["schedule"]:
		if str(event["kind"]) in kinds and int(event["t"]) > Clock.now():
			var context := str(event.get("p", {}).get("company_context", GameState.company_id()))
			if context != GameState.company_id(): continue
			if next < 0 or int(event["t"]) < next: next = int(event["t"])
	if id == "ch2_order" and next < 0 and GameState.stat("listings_active") > 0:
		next = Clock.now() - Clock.minute_of_day() % 60 + 60
	var target := DestinationHours.target(objective)
	if target.has("building"):
		var opening := DestinationHours.status(str(target["building"]), str(target.get("npc", "")))
		if not opening["open"] and int(opening["next"]) > Clock.now():
			if next < 0 or int(opening["next"]) < next: next = int(opening["next"])
	return next

## Advance in small batches. Stop for a real decision, injury, or insolvency; all scheduler ticks still run.
static func skip_next() -> bool:
	var next := next_event()
	if next <= Clock.now() or not EventEngine.pending().is_empty() or TrafficSafety.needs_attention(): return false
	var stop := mini(next, Clock.now() + int(cfg().get("skip_limit_days", 7)) * Clock.DAY)
	while Clock.now() < stop:
		Clock.advance(mini(30, stop - Clock.now()))
		StoryEngine.check()
		if not EventEngine.pending().is_empty() or TrafficSafety.needs_attention() or Insolvency.state().get("stage", "") == "open": break
	return true
