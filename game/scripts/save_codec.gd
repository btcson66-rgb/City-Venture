class_name SaveCodec
extends RefCounted
## Untrusted imports are checked before migration, storage, or changing the live game.

static func decode(text: String) -> Dictionary:
	var invalid := {"ok": false, "error": "This is not a City Venture save."}
	if text.length() > 20 * 1024 * 1024: return invalid
	var parser := JSON.new()
	if parser.parse(text) != OK: return invalid
	var payload = parser.data
	if not payload is Dictionary or not payload.get("format") is float and not payload.get("format") is int: return invalid
	if float(payload["format"]) > GameState.SAVE_FORMAT:
		return {"ok": false, "error": "This save comes from a newer version of City Venture."}
	if float(payload["format"]) != GameState.SAVE_FORMAT or not payload.get("data") is Dictionary or not payload.get("summary") is Dictionary: return invalid
	var data: Dictionary = payload["data"]
	var tpl := GameState.template()
	for key in ["meta", "player", "clock", "entities", "ledger", "ecommerce", "contracts", "schedule", "events", "story", "flags", "rng"]:
		if not data.has(key): return invalid
	if not _shape(data, tpl): return invalid
	for pair in [["player", ["name", "location"]], ["clock", ["minutes", "start"]], ["ledger", ["seq", "journal", "balances"]], ["rng", ["seed", "state"]], ["meta", ["version", "format"]], ["story", ["chapter", "active", "done", "chapters_done"]]]:
		for key in pair[1]:
			if not data[pair[0]].has(key): return invalid
	if _newer(str(data["meta"]["version"]), str(ProjectSettings.get_setting("application/config/version"))):
		return {"ok": false, "error": "This save comes from a newer version of City Venture."}
	if float(data["meta"]["format"]) != GameState.SAVE_FORMAT or float(data["clock"]["minutes"]) < 0 or not data["entities"].has("player"): return invalid
	if not _record(data["player"]["location"], {"kind": "", "id": "", "x": 0, "y": 0, "facing": ""}): return invalid
	for entity in data["entities"].values():
		if not _record(entity, {"id": "", "name": "", "kind": "", "bank_account": false}): return invalid
	for pair in [["listings", {"id": "", "product": "", "price": 0, "active": false}], ["orders", {"id": "", "product": "", "entity": "", "qty": 0, "status": "", "unit_price": 0}], ["purchase_orders", {"id": "", "product": "", "entity": "", "qty": 0, "status": "", "total": 0, "eta": 0}]]:
		for record in data["ecommerce"].get(pair[0], {}).values():
			if not _record(record, pair[1]): return invalid
	for inventory in data["ecommerce"].get("inventory", {}).values():
		if not inventory is Dictionary: return invalid
		for item in inventory.values():
			if not _record(item, {"qty": 0, "avg_cost": 0, "defect_rate": 0}): return invalid
	for contract in data["contracts"].values():
		if not contract is Dictionary: return invalid
	for message in data.get("messages", []):
		if not _record(message, {"t": 0, "from": "", "text": "", "read": false}): return invalid
	for stat in data.get("stats", {}).values():
		if not _numeric(stat): return invalid
	for flag in data["flags"].values():
		if not flag is bool: return invalid
	for entry in data["schedule"]:
		if not _record(entry, {"t": 0, "kind": "", "p": {}}): return invalid
	var totals := {}
	for entry in data["ledger"]["journal"]:
		if not _record(entry, {"n": 0, "t": 0, "entity": "", "memo": "", "lines": []}): return invalid
		if not data["entities"].has(entry["entity"]): return invalid
		var difference := 0.0
		if not totals.has(entry["entity"]): totals[entry["entity"]] = {}
		for line in entry["lines"]:
			if not _record(line, {"acct": ""}): return invalid
			for side in ["dr", "cr"]:
				if not _numeric(line.get(side, 0)): return invalid
			var delta := float(line.get("dr", 0)) - float(line.get("cr", 0))
			difference += delta
			totals[entry["entity"]][line["acct"]] = float(totals[entry["entity"]].get(line["acct"], 0)) + delta
		if absf(difference) > 0.011: return invalid
	for entity in data["ledger"]["balances"]:
		if not data["ledger"]["balances"][entity] is Dictionary: return invalid
		for account in data["ledger"]["balances"][entity]:
			var amount = data["ledger"]["balances"][entity][account]
			if not _numeric(amount) or absf(float(amount) - float(totals.get(entity, {}).get(account, 0))) > 0.02: return invalid
	for entity in totals:
		for account in totals[entity]:
			if absf(float(totals[entity][account]) - float(data["ledger"]["balances"].get(entity, {}).get(account, 0))) > 0.02: return invalid
	return {"ok": true, "payload": payload}


static func _numeric(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _shape(value: Variant, expected: Variant) -> bool:
	if typeof(expected) in [TYPE_INT, TYPE_FLOAT]: return _numeric(value)
	if typeof(value) != typeof(expected): return false
	if value is Dictionary:
		for key in expected:
			if value.has(key) and not _shape(value[key], expected[key]): return false
	return true


static func _record(value: Variant, expected: Dictionary) -> bool:
	if not value is Dictionary: return false
	for key in expected:
		if not value.has(key) or not _shape(value[key], expected[key]): return false
	return true


static func _newer(incoming: String, current: String) -> bool:
	var a := incoming.split("-")[0].split(".")
	var b := current.split("-")[0].split(".")
	for index in 3:
		var av := int(a[index]) if index < a.size() else 0
		var bv := int(b[index]) if index < b.size() else 0
		if av != bv: return av > bv
	var pattern := RegEx.new()
	pattern.compile("[0-9]+")
	var incoming_build := pattern.search(incoming.get_slice("-", 1))
	var current_build := pattern.search(current.get_slice("-", 1))
	if incoming_build != null:
		return int(incoming_build.get_string()) > (int(current_build.get_string()) if current_build != null else 0)
	return false
