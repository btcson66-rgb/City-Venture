class_name DestinationHours
extends RefCounted
## Opening windows shared by tutorial, objectives, navigation and City Guide. Queries never advance simulation.


static func _day_ok(days: String, t: int) -> bool:
	return days == "all" or Clock.WEEKDAYS[Clock.weekday(t)].to_lower() in days.split(",")


static func _window(h: Dictionary, t: int, from_key := "open", to_key := "close") -> bool:
	var m := Clock.minute_of_day(t)
	var start := Clock.parse_hm(str(h.get(from_key, "00:00")))
	var end := Clock.parse_hm(str(h.get(to_key, "24:00")))
	if start <= end:
		return _day_ok(str(h.get("days", "all")), t) and m >= start and m < end
	return (_day_ok(str(h.get("days", "all")), t) and m >= start) or (t >= Clock.DAY and _day_ok(str(h.get("days", "all")), t - Clock.DAY) and m < end)


static func _open(b: Dictionary, t: int, npc: String) -> bool:
	var h: Dictionary = b.get("hours", {})
	var private_access: bool = b.get("type", "") == "home" or (h.has("always_if_lease") and Living.has_lease(str(h["always_if_lease"])))
	if not private_access and not _window(h, t):
		return false
	if npc == "":
		return true
	for slot in DataDB.npcs.get(npc, {}).get("schedule", []):
		if str(slot.get("location", "")) == "interior:" + str(b["id"]) and Cond.all([str(slot.get("if", ""))]) and _window(slot, t, "from", "to"):
			return true
	return false


static func status(bid: String, npc := "") -> Dictionary:
	var b := DataDB.building(bid)
	if b.is_empty() or not BuildingInfo.building_enterable(bid) or b.has("closed_reason"):
		return {"open": false, "next": -1, "close": -1, "text": I18n.t("No opening time available.")}
	var now := Clock.now()
	# Boundaries suffice: a window can only open/close at a building or NPC schedule boundary.
	var boundaries: Array[int] = [now]
	var h: Dictionary = b.get("hours", {})
	for day in range(9):
		var midnight := now - Clock.minute_of_day(now) + day * Clock.DAY
		for key in ["open", "close"]:
			boundaries.append(midnight + Clock.parse_hm(str(h.get(key, "00:00" if key == "open" else "24:00"))))
		for slot in DataDB.npcs.get(npc, {}).get("schedule", []):
			for key in ["from", "to"]:
				boundaries.append(midnight + Clock.parse_hm(str(slot[key])))
	boundaries.sort()
	var is_open := _open(b, now, npc)
	var next := -1
	var closes := -1
	for t in boundaries:
		if t < now: continue
		if not is_open and _open(b, t, npc):
			next = t
			break
		if is_open and not _open(b, t, npc):
			closes = t
			break
	var text := I18n.t("Open all day")
	if is_open and closes >= 0:
		text = I18n.t("Open until %s") % _hm(closes)
	elif not is_open:
		if next < 0:
			text = I18n.t("No opening time available.")
		elif next / Clock.DAY == now / Clock.DAY:
			text = I18n.t("Closed now; opens today at %s") % _hm(next)
		elif next / Clock.DAY == now / Clock.DAY + 1:
			text = I18n.t("Closed now; opens tomorrow at %s") % _hm(next)
		else:
			text = I18n.t("Closed now; opens %s at %s") % [Clock.fmt_date(next), _hm(next)]
	return {"open": is_open, "next": next, "close": closes, "text": text}


static func _hm(t: int) -> String:
	return "%02d:%02d" % [Clock.minute_of_day(t) / 60, Clock.minute_of_day(t) % 60]


static func target(s: Dictionary) -> Dictionary:
	var t: Dictionary = s.get("target", {})
	if t.get("job", false):
		var jid := Careers.current_job()
		return {"building": str(Careers.job_def(jid)["building"])} if jid != "" else {"building": "bloom_coffee"}
	return t


static func target_text(s: Dictionary) -> String:
	var t := target(s)
	return str(status(str(t["building"]), str(t.get("npc", "")))["text"]) if t.has("building") else ""


## Re-query on click so stale buttons cannot skip to yesterday or bypass an updated schedule.
static func wait_until_open(bid: String, npc := "") -> void:
	var st := status(bid, npc)
	if not st["open"] and int(st["next"]) > Clock.now():
		Clock.advance_to(int(st["next"]))
