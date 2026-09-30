extends Node
## Loads every JSON definition under res://data/ and validates references.
## Content is data-driven (Handoff §73): scene scripts only reference ids.

const FOLDERS := ["businesses", "products", "suppliers", "companies", "npcs", "buildings", "districts",
	"regions", "regulations", "events", "dialogue", "properties", "jobs"]

var businesses := {}
var products := {}
var suppliers := {}
var companies := {}
var npcs := {}
var buildings := {}
var districts := {}
var regions := {}
var regulations := {}
var events := {}
var dialogue := {}
var properties := {}
var jobs := {}
var economy := {}      # marketplace, shipping, living, settlement_methods
var city := {}
var story := {}
var world := {}
var character := {}
var buildings_meta := {}
var sprite_meta := {}     # board-converted sprites that overhang their design footprint
var tiles := {}
var glossary := {}        # data/help/glossary.json: {id: {title, what, why}} behind the "!" badges (InfoTip)
var loaded := false


func _ready() -> void:
	load_all()


func load_all() -> void:
	for f in FOLDERS:
		var target: Dictionary = get(f)
		target.clear()
		for path in _json_files("res://data/" + f):
			var d = _read(path)
			if typeof(d) == TYPE_DICTIONARY and d.has("id"):
				target[d["id"]] = d
			elif typeof(d) == TYPE_DICTIONARY and d.has("items"):
				for it in d["items"]:
					target[it["id"]] = it
	for path in _json_files("res://data/economy"):
		economy[path.get_file().get_basename()] = _read(path)
	city = _read("res://data/city/aurelia.json")
	var gl = _read("res://data/help/glossary.json")
	glossary = gl if typeof(gl) == TYPE_DICTIONARY else {}
	story = _read("res://data/story/chapters.json")
	world = _read("res://data/world/years.json")
	character = _read("res://data/character/options.json")
	buildings_meta = _read("res://assets/buildings/buildings_meta.json")
	tiles = _read("res://assets/tiles/atlas.json")
	if FileAccess.file_exists("res://assets/sprite_meta.json"):
		sprite_meta = _read("res://assets/sprite_meta.json")
	loaded = true


func _json_files(dir_path: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	for f in d.get_files():
		# exported builds may list remapped names; only plain .json are content
		if f.ends_with(".json"):
			out.append(dir_path + "/" + f)
	out.sort()
	return out


func _read(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("DataDB: missing " + path)
		return {}
	var txt := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(txt)
	if parsed == null:
		push_error("DataDB: invalid JSON " + path)
		return {}
	return parsed


# ------------------------------------------------------------------ helpers
func product(id: String) -> Dictionary:
	return products.get(id, {})


## A product's picture: its own art once it exists, else the stand-in named by `icon_fallback`.
func product_icon(id: String) -> String:
	var p := product(id)
	var ic := str(p.get("icon", "props/product_parcel"))
	if not Art.has_tex(ic) and p.has("icon_fallback"):
		return str(p["icon_fallback"])
	return ic


func supplier(id: String) -> Dictionary:
	return suppliers.get(id, {})


func building(id: String) -> Dictionary:
	return buildings.get(id, {})


func npc(id: String) -> Dictionary:
	return npcs.get(id, {})


func living() -> Dictionary:
	return economy.get("living", {})


func marketplace() -> Dictionary:
	return economy.get("marketplace", {})


func shipping() -> Dictionary:
	return economy.get("shipping", {})


func ship_method(id: String) -> Dictionary:
	for m in shipping().get("methods", []):
		if m["id"] == id:
			return m
	return {}


func year_def(y: int) -> Dictionary:
	for yd in world.get("years", []):
		if int(yd["year"]) == y:
			return yd
	return {}


func character_option(group: String, id: String) -> Dictionary:
	for o in character.get(group, []):
		if o["id"] == id:
			return o
	return {}


func district_def_in_city(id: String) -> Dictionary:
	for d in city.get("districts", []):
		if d["id"] == id:
			return d
	return {}


# ------------------------------------------------------------------ validation
## Returns a list of human-readable problems. Empty = valid.
func validate() -> Array:
	var errs: Array = []
	for sid in suppliers:
		for o in suppliers[sid].get("offers", []):
			if not products.has(o.get("product", "")):
				errs.append("supplier %s offers unknown product %s" % [sid, o.get("product")])
			if float(o.get("moq", 0)) <= 0:
				errs.append("supplier %s offer %s has no MOQ" % [sid, o.get("product")])
	for bid in buildings:
		var b: Dictionary = buildings[bid]
		if not districts.has(b.get("district", "")):
			errs.append("building %s in unknown district %s" % [bid, b.get("district")])
		var spr: String = b.get("exterior", {}).get("sprite", "")
		if spr != "" and not buildings_meta.has(spr):
			spr = str(b["exterior"].get("fallback", spr))   # a facade still being drawn stands in with its fallback
		if spr != "" and not buildings_meta.has(spr):
			errs.append("building %s uses unknown facade %s" % [bid, spr])
	for did in districts:
		for bid in districts[did].get("buildings", []):
			if not buildings.has(bid):
				errs.append("district %s lists unknown building %s" % [did, bid])
		for ex in districts[did].get("exits", []):
			var to: String = ex.get("to", "")
			if not districts.has(to):
				errs.append("district %s exit to unknown %s" % [did, to])
	for nid in npcs:
		for s in npcs[nid].get("schedule", []):
			var loc: String = s.get("location", "")
			var parts := loc.split(":")
			if parts.size() == 2:
				if parts[0] == "interior" and not buildings.has(parts[1]):
					errs.append("npc %s scheduled in unknown building %s" % [nid, parts[1]])
				if parts[0] == "district" and not districts.has(parts[1]):
					errs.append("npc %s scheduled in unknown district %s" % [nid, parts[1]])
	# Product rule R1/R2: character options can never carry gameplay fields
	for group in character:
		if typeof(character[group]) != TYPE_ARRAY:
			continue
		for o in character[group]:
			if typeof(o) != TYPE_DICTIONARY:
				continue
			for k in o.keys():
				if k in ["bonus", "stat", "stats", "modifier", "buff", "multiplier"]:
					errs.append("character option %s/%s has forbidden gameplay key %s" % [group, o.get("id"), k])
	# kickoff §17: an event must change money, inventory or options
	var impactful := ["cash", "purchase", "refund_order", "replace_order", "partial_refund", "refuse_return",
		"inventory_delta", "supplier_price_mod", "create_contract_offer", "listing_mod", "ad_price_mod", "demand_mod",
		"liquidate_inventory", "reduce_spending", "price_all_mod", "rush_order", "equity_investment"]
	for eid in events:
		var ok := false
		for c in events[eid].get("choices", []):
			for e in c.get("effects", []):
				if e.get("op", "") in impactful:
					ok = true
		if not ok:
			errs.append("event %s has no money/inventory/option effect" % eid)
	for jid in jobs:
		var j: Dictionary = jobs[jid]
		if not buildings.has(j.get("building", "")):
			errs.append("job %s at unknown building %s" % [jid, j.get("building")])
		if not npcs.has(j.get("boss", "")):
			errs.append("job %s has unknown boss %s" % [jid, j.get("boss")])
		var found := false
		for it in buildings.get(j.get("building", ""), {}).get("interior", {}).get("interactables", []):
			if it.get("action", "") == "work_shift" and it.get("params", {}).get("job", "") == jid:
				found = true
		if not found:
			errs.append("job %s has no work_shift spot in its building" % jid)
	for ch in story.get("chapters", []):
		for ob in ch.get("objectives", []):
			for a in ob.get("on_complete", []) + ob.get("on_start", []):
				if a.get("do", "") == "dialogue" and not dialogue.has(a.get("id", "")):
					errs.append("objective %s references missing dialogue %s" % [ob.get("id"), a.get("id")])
	return errs
