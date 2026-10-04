class_name BuildingInfo
extends RefCounted
## Shared, live building information for doors, welcome cards and the phone guide.

const ACTION_ICONS := {
	"legacy_mentor": "people",
	"customs_guide":"info", "trade_open":"world",
	"energy_open": "company", "energy_subsidy": "civic",
	"buy_item": "shop", "clothing_shop": "shop", "cafe_counter": "coffee",
	"work_shift": "tasks", "open_company_os": "laptop", "cowork_desk": "laptop",
	"sleep": "sleep", "read_news": "info", "bank_counter": "bank", "atm": "bank",
	"loans_info": "bank", "register_company": "civic", "permits_info": "civic", "take_number": "civic",
	"pack_orders": "parcel", "dropoff_parcels": "parcel", "change_outfit": "shirt",
	"lease_property": "home", "whiteboard": "objective", "look": "info", "talk": "people",
	"talk_staff": "people", "business_board": "company", "metro": "metro",
	"media_open": "company", "hotel_open": "sleep", "real_estate_open": "home", "manufacturing_open": "inventory", "automotive_open": "metro"
}


static func icon_for(action: String, params: Dictionary = {}) -> String:
	if action == "buy_item" and str(params.get("item", "")) == "coffee":
		return "coffee"
	return str(ACTION_ICONS.get(action, ""))


static func district_open(id: String) -> bool:
	var d: Dictionary = DataDB.districts.get(id, {})
	return str(d.get("status", DataDB.district_def_in_city(id).get("status", "planned"))) == "active"


static func building_enterable(id: String) -> bool:
	var b := DataDB.building(id)
	return not b.is_empty() and b.get("enterable", true) and str(b.get("status", "active")) == "active" and district_open(str(b.get("district", "")))


static func world_travel_available() -> bool:
	return DataDB.regions.values().filter(func(r): return r.get("status", "planned") == "active").size() > 1 or GlobalMarket.company().get("bank", false)


static var _avail_cache: Dictionary = {}
static var _avail_stamp := ""


## The door trigger asks every frame and the guide asks per building, so the answer is kept until the game minute or
## anything it reads (leases, desk pass, flags, the game itself) changes.
static func building_available(id: String) -> bool:
	if not GameState.has_game():
		return _compute_available(id)
	var stamp := "%d|%d|%d|%d|%d|%d" % [Clock.now(), int(GameState.data["meta"].get("created_unix", 0)), GameState.data["flags"].size(),
		Living.D()["leases"].size(), int(Living.D().get("day_pass", -1)), int(GameState.data["ledger"]["seq"])]
	if stamp != _avail_stamp:
		_avail_stamp = stamp
		_avail_cache.clear()
	if not _avail_cache.has(id):
		_avail_cache[id] = _compute_available(id)
	return _avail_cache[id]


## Forget remembered answers (data edited at run time, e.g. by tests).
static func invalidate_availability() -> void:
	_avail_stamp = ""
	_avail_cache.clear()


## A look-only room becomes a public destination only while a real scheduled NPC is there.
static func _compute_available(id: String) -> bool:
	if not building_enterable(id):
		return false
	for it in DataDB.building(id).get("interior", {}).get("interactables", []):
		if not it.get("enabled", true) or str(it["action"]) == "look":
			continue
		# Access checks only. Sim action blockers call building_open(), so evaluating them here would recurse.
		var requires := str(it.get("params", {}).get("requires", ""))
		if requires.begins_with("lease:") and not Living.has_lease(requires.substr(6)):
			continue
		if requires == "desk_access" and not Living.has_desk_access():
			continue
		if str(it["action"]) == "cafe_counter" and not Cafe.leased():
			continue
		return true
	var weekday: String = Clock.WEEKDAYS[Clock.weekday()].to_lower()
	var minute := Clock.minute_of_day()
	for npc in DataDB.npcs.values():
		for s in npc.get("schedule", []):
			var days := str(s.get("days", "all"))
			if str(s.get("location", "")) == "interior:" + id and (days == "all" or weekday in days.split(",")) and Cond.all([str(s.get("if", ""))]) and minute >= Clock.parse_hm(str(s["from"])) and minute < Clock.parse_hm(str(s["to"])):
				return true
	return false


## Old saves inside scenery return to the same facade's street spawn, preserving all financial state.
static func safe_location(loc: Dictionary) -> Dictionary:
	var result := loc.duplicate()
	if str(loc.get("kind", "")) == "interior" and not building_available(str(loc.get("id", ""))):
		var bid := str(loc.get("id", ""))
		var district := str(DataDB.building(bid).get("district", "riverside"))
		result = {"kind": "district", "id": district, "spawn": "door_" + bid, "x": -1, "y": -1, "facing": "down"}
	if result.get("kind", "") == "district" and not district_open(str(result.get("id", ""))):
		result = {"kind": "district", "id": "riverside", "spawn": "", "x": -1, "y": -1, "facing": "down"}
	return result


static func category(id: String) -> String:
	var b := DataDB.building(id)
	return I18n.t(str(b.get("category", "Building")))


static func hours(id: String) -> String:
	var h: Dictionary = DataDB.building(id).get("hours", {})
	var days := str(h.get("days", "all"))
	var day_text := I18n.t("Daily") if days == "all" else I18n.t("Mon–Fri") if days == "mon,tue,wed,thu,fri" else I18n.t("Mon–Sat") if days == "mon,tue,wed,thu,fri,sat" else "/".join(Array(days.split(",")).map(func(d): return I18n.t(str(d).capitalize())))
	return I18n.t("Hours: %s–%s · %s") % [str(h.get("open", "00:00")), str(h.get("close", "24:00")), day_text]


static func status(id: String) -> String:
	if SceneRouter.building_open(id)["open"]:
		return I18n.t("Open now")
	var b := DataDB.building(id)
	if b.has("closed_reason"):
		return I18n.t("Not open yet")
	return I18n.t("Closed · opens %s") % str(b.get("hours", {}).get("open", "00:00"))


static func door_text(id: String) -> String:
	var definition := DataDB.building(id)
	if id == "lot7":
		definition = RealEstate.lot_definition(definition)
	return "%s — %s · %s" % [I18n.t(str(definition.get("name", id))), category(id), status(id)]


## Uses the instantiated scene (including current NPCs), or building data in headless callers.
static func activities(id: String, scene: WorldScene = null) -> Array[String]:
	var out: Array[String] = []
	if scene != null:
		for node in scene.get_tree().get_nodes_in_group("interactable"):
			if scene.is_ancestor_of(node) and node.enabled and node.action != "look":
				out.append(_activity(str(node.label), str(node.action), node.params))
	else:
		for it in DataDB.building(id).get("interior", {}).get("interactables", []):
			var params: Dictionary = it.get("params", {}).duplicate()
			if params.has("unless_lease") and Living.has_lease(str(params["unless_lease"])):
				continue
			params["building"] = id
			if it.get("enabled", true) and str(it["action"]) != "look":
				out.append(_activity(str(it["label"]), str(it["action"]), params))
	return out


static func _activity(label: String, action: String, params: Dictionary) -> String:
	var reason := Actions.lock_reason(action, params)
	return action_label(label, action, params) + (" (" + I18n.t(reason) + ")" if reason != "" else "")


## A data-authored shop label quotes the current price using the same units as the rest of the UI.
static func action_label(label: String, action: String, params: Dictionary) -> String:
	var text := I18n.t(label)
	if action == "buy_item" and params.has("price"):
		var money := RegEx.create_from_string("\\$[0-9,]+(?:\\.[0-9]+)?")
		var found := money.search(text)
		if found != null: text = text.substr(0, found.get_start()) + (Fmt.money(float(params["price"])) if absf(float(params["price"]) - roundf(float(params["price"]))) > 0.001 else Fmt.money0(float(params["price"]))) + text.substr(found.get_end())
	return text


static func welcome(id: String, scene: WorldScene = null) -> String:
	var choices := activities(id, scene)
	return I18n.t("You can: %s") % " · ".join(choices) if not choices.is_empty() else I18n.t("This is a sightseeing-only location right now.")


## A new district or building appears without editing UI code. Inactive districts have no destinations.
static func guide_groups() -> Array:
	var ids: Array = DataDB.districts.keys()
	for d in DataDB.city.get("districts", []):
		if not str(d["id"]) in ids:
			ids.append(str(d["id"]))
	ids.sort()
	var groups := []
	for id in ids:
		var d: Dictionary = DataDB.districts.get(id, DataDB.district_def_in_city(id))
		var buildings := []
		if district_open(id):
			for bid in DataDB.buildings:
				var b: Dictionary = DataDB.buildings[bid]
				if str(b.get("district", "")) == id and building_available(bid):
					buildings.append(bid)
			buildings.sort()
		if district_open(id):
			groups.append({"id": id, "name": str(d.get("name", id)), "open": true, "buildings": buildings})
	return groups


static func guide_tags(id: String) -> String:
	var tags: Array[String] = []
	for it in DataDB.building(id).get("interior", {}).get("interactables", []):
		var tag := ""
		match str(it["action"]):
			"buy_item", "cafe_counter": tag = I18n.t("Eat")
			"clothing_shop": tag = I18n.t("Shop")
			"work_shift", "open_company_os", "cowork_desk", "business_board", "pack_orders": tag = I18n.t("Work")
			"bank_counter", "atm", "loans_info", "register_company", "permits_info", "take_number", "dropoff_parcels": tag = I18n.t("Services")
			"lease_property": tag = I18n.t("Property")
			"sleep": tag = I18n.t("Housing")
		if tag != "" and not tag in tags:
			tags.append(tag)
	return " · ".join(tags) if not tags.is_empty() else category(id) if not activities(id).is_empty() else I18n.t("Services") if building_available(id) else I18n.t("Sightseeing")


static func station(id: String) -> String:
	var district := str(DataDB.building(id).get("district", ""))
	var d: Dictionary = DataDB.districts.get(district, {})
	var metro: Dictionary = d.get("metro", {})
	if metro.is_empty():
		return I18n.t("Walk from a neighbouring district.")
	var station_id := str(metro.get("station", district))
	return I18n.t("Metro: %s Station") % I18n.t(str(DataDB.districts.get(station_id, d).get("name", station_id)))


## Added lazily so pre-guide saves keep their existing visited flags and need no destructive migration.
static func record_entry(id: String) -> int:
	if not GameState.data.has("building_visits"):
		GameState.data["building_visits"] = {}
	var visits: Dictionary = GameState.data["building_visits"]
	visits[id] = int(visits.get(id, 0)) + 1
	return int(visits[id])
