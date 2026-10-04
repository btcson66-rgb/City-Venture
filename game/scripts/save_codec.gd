class_name SaveCodec
extends RefCounted
## Untrusted imports are checked before migration, storage, or changing the live game.
## The text cap covers the 3-day 5,000-order stress save once orders carry baskets and packing records (#113).

## Decoded JSON text cap. A saturated company (50 staff, 5,000 orders a day) holds about a week of open and settled
## orders; older ones are archived into monthly totals, so a long game stays well below this.
const MAX_TEXT := 128 * 1024 * 1024


## Large collections (a saturated company's orders, journal and schedule) are written as one packed Variant blob
## instead of JSON text: parsing millions of small JSON values was most of the load time. Small saves stay plain,
## readable JSON, and every older save loads unchanged. `unpack` runs before validation, so imports are checked
## exactly like plain JSON; the decoder never instantiates objects.
const PACK_MIN := 2000
const PACK_MAX_BYTES := 512 * 1024 * 1024


static func _packed(value: Variant) -> Dictionary:
	var bytes := var_to_bytes(value).compress(FileAccess.COMPRESSION_GZIP)
	return {"packed": 1, "n": value.size(), "z": Marshalls.raw_to_base64(bytes)}


static func _unpacked(blob: Variant) -> Variant:
	if not blob is Dictionary or not blob.has("packed"):
		return blob
	if not blob.get("z") is String: return null
	var raw := Marshalls.base64_to_raw(blob["z"])
	if raw.is_empty(): return null
	var bytes := raw.decompress_dynamic(PACK_MAX_BYTES, FileAccess.COMPRESSION_GZIP)
	if bytes.is_empty(): return null
	return bytes_to_var(bytes)


## Copy of `data` with its big collections packed (live state is never modified).
static func pack(data: Dictionary) -> Dictionary:
	var lean := data.duplicate(false)
	if data.get("schedule") is Array and data["schedule"].size() >= PACK_MIN:
		lean["schedule"] = _packed(data["schedule"])
	if data.get("ledger") is Dictionary and data["ledger"].get("journal") is Array and data["ledger"]["journal"].size() >= PACK_MIN:
		lean["ledger"] = data["ledger"].duplicate(false)
		lean["ledger"]["journal"] = _packed(data["ledger"]["journal"])
	if data.get("ecommerce") is Dictionary and data["ecommerce"].get("orders") is Dictionary and data["ecommerce"]["orders"].size() >= PACK_MIN:
		lean["ecommerce"] = data["ecommerce"].duplicate(false)
		lean["ecommerce"]["orders"] = _packed(data["ecommerce"]["orders"])
	if data.get("company_contexts") is Dictionary:
		var contexts := {}
		for id in data["company_contexts"]:
			var view = data["company_contexts"][id]
			var states = view.get("states") if view is Dictionary else null
			if states is Dictionary and states.get("ecommerce") is Dictionary and states["ecommerce"].get("orders") is Dictionary and states["ecommerce"]["orders"].size() >= PACK_MIN:
				var copy: Dictionary = view.duplicate(false)
				copy["states"] = states.duplicate(false)
				copy["states"]["ecommerce"] = states["ecommerce"].duplicate(false)
				copy["states"]["ecommerce"]["orders"] = _packed(states["ecommerce"]["orders"])
				contexts[id] = copy
			else:
				contexts[id] = view
		lean["company_contexts"] = contexts
	return lean


## In place, on freshly parsed data. Returns false when a blob is damaged.
static func unpack(data: Dictionary) -> bool:
	if data.get("schedule") is Dictionary:
		var schedule = _unpacked(data["schedule"])
		if not schedule is Array: return false
		data["schedule"] = schedule
	if data.get("ledger") is Dictionary and data["ledger"].get("journal") is Dictionary:
		var journal = _unpacked(data["ledger"]["journal"])
		if not journal is Array: return false
		data["ledger"]["journal"] = journal
	if data.get("ecommerce") is Dictionary and data["ecommerce"].get("orders") is Dictionary and data["ecommerce"]["orders"].has("packed"):
		var orders = _unpacked(data["ecommerce"]["orders"])
		if not orders is Dictionary: return false
		data["ecommerce"]["orders"] = orders
	if data.get("company_contexts") is Dictionary:
		for view in data["company_contexts"].values():
			if not view is Dictionary or not view.get("states") is Dictionary: continue
			var eco = view["states"].get("ecommerce")
			if eco is Dictionary and eco.get("orders") is Dictionary and eco["orders"].has("packed"):
				var orders = _unpacked(eco["orders"])
				if not orders is Dictionary: return false
				eco["orders"] = orders
	return true


static func _truthy(v) -> bool:
	if v is bool: return v
	if v == null: return false
	if v is int or v is float: return float(v) != 0.0
	if v is String: return not str(v).to_lower() in ["", "false", "0", "no", "off", "null"]
	return true


static func decode(text: String) -> Dictionary:
	var invalid := {"ok": false, "error": "This is not a City Venture save."}
	if text.length() > MAX_TEXT: return invalid
	var parser := JSON.new()
	if parser.parse(text) != OK: return invalid
	var payload = parser.data
	if not payload is Dictionary or not payload.get("format") is float and not payload.get("format") is int: return invalid
	if float(payload["format"]) > GameState.SAVE_FORMAT:
		return {"ok": false, "error": "This save comes from a newer version of City Venture."}
	if float(payload["format"]) != GameState.SAVE_FORMAT or not payload.get("data") is Dictionary or not payload.get("summary") is Dictionary: return invalid
	var data: Dictionary = payload["data"]
	if not unpack(data): return invalid
	var tpl := GameState.template()
	if data.get("company") is String: tpl["company"]=""
	for key in ["meta", "player", "clock", "entities", "ledger", "ecommerce", "contracts", "schedule", "events", "story", "flags", "rng"]:
		if not data.has(key): return invalid
	if not _shape(data, tpl): return invalid
	if data.get("company") is Array:
		var known := {}
		for id in data["company"]:
			if not id is String or known.has(id) or not data["entities"].has(id) or data["entities"][id].get("kind","")!="company":return invalid
			known[id]=true
		var active:=str(data.get("active_company",""))
		if active!="" and not known.has(active):return invalid
		for id in data.get("company_contexts",{}):
			if id!="" and not known.has(id):return invalid
			var view=data["company_contexts"][id]
			if not _record(view,{"states":{},"flags":{},"bank":{}}):return invalid
			for key in view["states"]:
				if tpl.has(key) and not _shape(view["states"][key],tpl[key]):return invalid
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
	if not data["flags"] is Dictionary: return invalid
	for key in data["flags"].keys():       # an older or hand-edited save may hold 1/0/"yes": read it as the truth value, don't reject the save
		data["flags"][key] = _truthy(data["flags"][key])
	for entry in data["schedule"]:
		if not _record(entry, {"t": 0, "kind": "", "p": {}}): return invalid
	var personal = data.get("living",{}).get("personal_assets",null)
	if personal!=null:
		if not _record(personal,{"homes":{},"car":{},"style":{},"visits":[],"parking":{},"month":0}):return invalid
		for id in personal["homes"]:
			if not DataDB.properties.get(id,{}).get("owner_purchase",false):return invalid
			var h=personal["homes"][id]
			if not _record(h,{"status":"","tier":0,"book":0,"base_price":0,"balance":0,"months":0,"paid_n":0,"next":0,"arrears":0,"tenant":{},"rent":0,"invoices":[]}):return invalid
			if h["status"] not in ["empty","occupied","listed","tenanted","sold"] or float(h["balance"])<0 or float(h["months"])<=0 or float(h["arrears"])<0:return invalid
			if h.has("leave") and not _numeric(h["leave"]):return invalid
			if h["status"]=="tenanted" and not _record(h["tenant"],{"name":""}):return invalid
			for row in h["invoices"]:
				if not _record(row,{"t":0,"amount":0,"paid":false}):return invalid
		var car=personal["car"]
		if not car.is_empty():
			if not _record(car,{"id":"","name":"","price":0,"electric":false,"luxury":false,"location":"","energy":0,"service":0}):return invalid
			if not DataDB.districts.has(car["location"]) or float(car["energy"])<0 or float(car["price"])<=0:return invalid
		for style in personal["style"].values():
			if not style is String or not DataDB.economy["personal_assets"]["furniture"].has(style):return invalid
		for visit in personal["visits"]:
			if not _record(visit,{"npc":"","day":0,"home":""}):return invalid
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
	return compare_versions(incoming, current) > 0


static func compare_versions(a: String, b: String) -> int:
	var pattern := RegEx.new()
	pattern.compile("[0-9]+")
	var av := pattern.search_all(a.get_slice("-", 0))
	var bv := pattern.search_all(b.get_slice("-", 0))
	for i in maxi(3, maxi(av.size(), bv.size())):
		var x := int(av[i].get_string()) if i < av.size() else 0
		var y := int(bv[i].get_string()) if i < bv.size() else 0
		if x != y: return 1 if x > y else -1
	var asuffix := a.get_slice("-", 1)
	var bsuffix := b.get_slice("-", 1)
	if asuffix.is_empty() != bsuffix.is_empty(): return 1 if asuffix.is_empty() else -1
	av = pattern.search_all(asuffix)
	bv = pattern.search_all(bsuffix)
	for i in maxi(av.size(), bv.size()):
		var x := int(av[i].get_string()) if i < av.size() else 0
		var y := int(bv[i].get_string()) if i < bv.size() else 0
		if x != y: return 1 if x > y else -1
	return 0
