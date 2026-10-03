class_name Milestones
extends RefCounted
## Industry milestones (#71): five per industry in data/milestones.json, shown on the Timeline and in the Achievements page.
## A milestone is a metric threshold (see SynergyMetrics), optionally held for N consecutive days (streak_days).
## State: GameState.data["synergy"]["milestones"] = {done:{id:t}, streak:{id:days}, day:{id:last day counted}}.


static func S() -> Dictionary:
	var root: Dictionary = InternalSupply.S()
	if not root.has("milestones"):
		root["milestones"] = {"done": {}, "streak": {}, "day": {}}
	return root["milestones"]


## Definitions in registry order (the order industries appear in Company OS), then file order.
static func list(industry := "") -> Array:
	var out: Array = []
	for entry in Industries.all():
		if industry != "" and entry["id"] != industry:
			continue
		for m in DataDB.milestones.values():
			if m["industry"] == entry["id"]:
				out.append(m)
	return out


static func unlocked(id: String) -> bool:
	return S()["done"].has(id)


static func count(industry := "") -> Array:
	var done := 0
	var all := list(industry)
	for m in all:
		if unlocked(m["id"]):
			done += 1
	return [done, all.size()]


## {have, target, text} for the progress line of one milestone.
static func progress(m: Dictionary) -> Dictionary:
	if m.has("streak_days"):
		var have := float(S()["streak"].get(m["id"], 0))
		return {"have": have, "target": float(m["streak_days"]), "streak": true}
	var v := SynergyMetrics.value(str(m["metric"]))
	return {"have": minf(v, float(m["value"])), "target": float(m["value"]), "streak": false}


static func met(m: Dictionary) -> bool:
	if m.has("streak_days"):
		return float(S()["streak"].get(m["id"], 0)) >= float(m["streak_days"])
	return SynergyMetrics.value(str(m["metric"])) >= float(m["value"])


static func unlock(id: String, quiet := false) -> bool:
	var m: Dictionary = DataDB.milestones.get(id, {})
	if m.is_empty() or unlocked(id):
		return false
	S()["done"][id] = Clock.now()
	GameState.set_flag("milestone_" + id)
	GameState.inc_stat("milestones")
	GameState.timeline(I18n.t("Milestone: %s") % I18n.t(str(m["name"])), "milestone")
	if not quiet:
		EventBus.notify.emit(I18n.t("Milestone: %s") % I18n.t(str(m["name"])), "good", "star")
	return true


## Unlocks everything now met. Returns the ids newly unlocked. More than three at once (an older save) share one toast.
static func check_all() -> Array:
	var fresh: Array = []
	for m in DataDB.milestones.values():
		if not unlocked(m["id"]) and met(m):
			fresh.append(m["id"])
	for id in fresh:
		unlock(id, fresh.size() > 3)
	if fresh.size() > 3:
		EventBus.notify.emit(I18n.t("%d milestones reached. See Achievements on your phone.") % fresh.size(), "good", "star")
	return fresh


## Once per day: extend or break streaks. A negative reading means "no data today" and leaves the streak alone.
static func update_streaks() -> void:
	for m in DataDB.milestones.values():
		if not m.has("streak_days") or unlocked(m["id"]) or int(S()["day"].get(m["id"], -1)) == Clock.day_index():
			continue
		var v := SynergyMetrics.value(str(m["metric"]))
		if v < 0:
			continue
		S()["day"][m["id"]] = Clock.day_index()
		S()["streak"][m["id"]] = int(S()["streak"].get(m["id"], 0)) + 1 if v >= float(m["value"]) else 0


static func on_hour(_t: int, h: int) -> void:
	if not GameState.has_game():
		return
	if h == int(InternalSupply.cfg().get("settle_hour", 22)):
		update_streaks()
	check_all()
