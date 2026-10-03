class_name SynergyMetrics
extends RefCounted
## Reads one number out of the game for data-driven group goals and milestones (#71).
## Source strings:  stat:<name>  ·  data:<path.in.save>  ·  count:<path>|<key>=<value>  ·  fn:<name>
## A data path resolves numbers as themselves, lists and dictionaries as their size, booleans as 0/1, missing as 0.


static func value(src: String) -> float:
	var kind := src.get_slice(":", 0)
	var arg := src.substr(kind.length() + 1)
	match kind:
		"stat": return GameState.stat(arg)
		"data": return _data(arg)
		"count": return _count(arg)
		"fn": return _fn(arg)
	return 0.0


static func _walk(path: String) -> Variant:
	var node: Variant = GameState.data
	for part in path.split("."):
		if typeof(node) != TYPE_DICTIONARY or not node.has(part):
			return null
		node = node[part]
	return node


static func _data(path: String) -> float:
	var v: Variant = _walk(path)
	match typeof(v):
		TYPE_INT, TYPE_FLOAT: return float(v)
		TYPE_BOOL: return 1.0 if v else 0.0
		TYPE_ARRAY, TYPE_DICTIONARY: return float(v.size())
	return 0.0


static func _count(arg: String) -> float:
	var v: Variant = _walk(arg.get_slice("|", 0))
	var filt := arg.get_slice("|", 1) if arg.contains("|") else ""
	var items: Array = []
	if typeof(v) == TYPE_DICTIONARY:
		items = v.values()
	elif typeof(v) == TYPE_ARRAY:
		items = v
	var n := 0
	for item in items:
		if filt == "" or (typeof(item) == TYPE_DICTIONARY and str(item.get(filt.get_slice("=", 0), "")) == filt.get_slice("=", 1)):
			n += 1
	return float(n)


static func _fn(name: String) -> float:
	var d: Dictionary = GameState.data
	match name:
		"saas_launched":
			return 1.0 if d.has("saas") and float(d["saas"].get("launched", -1)) >= 0 else 0.0
		"media_stage":
			return float(Media.stage()) if d.has("media") and Media.is_running() else 0.0
		"automotive_stage":
			return float(Automotive.stage()) if d.has("automotive") and Automotive.is_running() else 0.0
		"energy_stage":
			return float(Energy.stage()) if d.has("energy") and Energy.is_running() else 0.0
		"energy_stations_open":
			return float(Energy.open_stations().size()) if d.has("energy") and Energy.is_running() else 0.0
		"hotel_occupancy_30":
			if not d.has("hotel"):
				return 0.0
			var history: Array = d["hotel"].get("history", [])
			if history.size() < 30:
				return 0.0
			var occupied := 0.0
			var rooms := 0.0
			for row in history.slice(history.size() - 30):
				occupied += float(row["occupied"])
				rooms += float(row["rooms"])
			return occupied / rooms if rooms > 0 else 0.0
		"mfg_yield_today":
			# -1 means no production today, so a quiet day neither extends nor breaks a streak.
			if not d.has("manufacturing"):
				return -1.0
			var day_start := (Clock.day_index() - 1) * Clock.DAY
			var qty := 0.0
			var bad := 0.0
			for row in d["manufacturing"].get("quality", []):
				if int(row["t"]) >= day_start:
					qty += float(row["qty"])
					bad += float(row["qty"]) * float(row["defect"])
			return 1.0 - bad / qty if qty > 0 else -1.0
	return 0.0
