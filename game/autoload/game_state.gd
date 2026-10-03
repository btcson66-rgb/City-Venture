extends Node
## Single source of truth. Everything that must survive a save lives in `data`.
## `data` is plain JSON-serialisable Dictionaries/Arrays (see GAME_DATA_SCHEMA.md §2).

const SAVE_FORMAT := 1

var data: Dictionary = {}
var rng := RandomNumberGenerator.new()


func has_game() -> bool:
	return not data.is_empty()


func default_appearance() -> Dictionary:
	return {
		"presentation": "masculine", "face": "round", "hair": "messy", "hair_color": "dark_brown",
		"skin": "s2", "eye_shape": "round", "eye_color": "brown", "brows": "straight", "mouth": "smile",
		"accessory": "none",
	}


## Build a fresh world. `setup` = {name, appearance{}, outfit, seed?}
## Returns false (and leaves no game in memory) when no save slot could be claimed; SaveSystem.last_error says why.
func new_game(setup: Dictionary) -> bool:
	var living := DataDB.living()
	var seed_v: int = int(setup.get("seed", Time.get_ticks_usec() % 2147483647))
	# Explicit reproducible seeds are restricted to QA bot runs.
	if Array(OS.get_cmdline_user_args()).any(func(a): return a.begins_with("--bot=")):
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--seed="):
				seed_v = int(arg.substr(7))
	rng.seed = seed_v
	var slot := SaveSystem.claim_slot()
	if slot < 0:
		data = {}
		return false
	data = template(setup, seed_v)
	data["meta"]["slot"] = slot
	Ledger.post("player", "Opening balance — savings", [
		{"acct": "cash", "dr": float(living.get("start_cash", 30000))},
		{"acct": "equity", "cr": float(living.get("start_cash", 30000))}], {"type": "opening"})
	timeline(I18n.t("Moved to Aurelia City with $%s in savings.") % Fmt.money0(float(living.get("start_cash", 30000))))
	return true


## The shape of a brand-new game. new_game() starts from it, and loading an older save fills in anything a newer
## version added (SaveSystem._migrate), so a save from any earlier build keeps working.
func template(setup := {}, seed_v := 1) -> Dictionary:
	var living := DataDB.living()
	var sd: Dictionary = living.get("start_date", {"year": 2031, "month": 6, "day": 1})
	return {
		"meta": {"format": SAVE_FORMAT, "version": ProjectSettings.get_setting("application/config/version", "dev"),
			"created_unix": Time.get_unix_time_from_system(), "playtime_s": 0.0, "slot": -1},
		"player": {
			"name": setup.get("name", "Alex"),
			"appearance": setup.get("appearance", default_appearance()),
			"outfit": setup.get("outfit", "startup_casual"),
			"home": "riverside_studio",
			"location": {"kind": "interior", "id": "riverside_apartment", "x": -1.0, "y": -1.0, "facing": "down"},
			"carrying_parcels": [],
		},
		"clock": {"minutes": int(living.get("start_minute_of_day", 840)), "start": sd},
		"entities": {
			"player": {"id": "player", "name": setup.get("name", "Alex"), "kind": "person", "bank_account": true,
				"seller_account": "personal"},
		},
		"company": "",
		"ledger": {"seq": 0, "journal": [], "balances": {}},
		"ecommerce": {"listings": {}, "orders": {}, "purchase_orders": {}, "inventory": {}, "supplier_mods": [],
			"counters": {"order": 1000, "po": 100, "listing": 1}, "demand_mods": [], "ad_price_mult": 1.0,
			"ad_price_until": 0, "month_gmv": {}, "cap_notified": {}},
		"contracts": {},
		"schedule": [],
		"events": {"queue": [], "history": [], "cooldowns": {}, "fired": {}},
		"story": {"chapter": "", "active": [], "done": [], "chapters_done": []},
		"flags": {},
		"stats": {},
		"npcs": {},
		"messages": [],
		"timeline": [],
		"reports": {"month_closes": []},
		"world": {"year": 1, "modifiers": []},
		"living": {"reduced": false, "rent_history": [], "leases": {}},
		"visited": {},
		"rng": {"seed": seed_v, "state": ""},
	}


func pack_rng() -> void:
	if has_game():
		data["rng"]["state"] = str(rng.state)


func unpack_rng() -> void:
	rng.seed = int(data["rng"].get("seed", 1))
	var st: String = str(data["rng"].get("state", ""))
	if st != "":
		rng.state = int(st)


# ------------------------------------------------------------------ rng helpers
func randf() -> float:
	return rng.randf()


func randi_range(a: int, b: int) -> int:
	return rng.randi_range(a, b)


func pick(arr: Array) -> Variant:
	if arr.is_empty():
		return null
	return arr[rng.randi_range(0, arr.size() - 1)]


func poisson(lam: float) -> int:
	if lam <= 0.0:
		return 0
	var l := exp(-lam)
	var k := 0
	var p := 1.0
	while true:
		k += 1
		p *= rng.randf()
		if p <= l or k > 50:
			break
	return k - 1


# ------------------------------------------------------------------ flags & stats
func flag(name: String) -> bool:
	return bool(data.get("flags", {}).get(name, false))


func set_flag(name: String, value := true) -> void:
	if flag(name) == value:
		return
	data["flags"][name] = value
	EventBus.flag_set.emit(name)


func inc_stat(name: String, by := 1.0) -> void:
	data["stats"][name] = float(data["stats"].get(name, 0.0)) + by


## Stats used by the condition DSL (stored counters + derived values).
func stat(name: String) -> float:
	match name:
		"listings_active":
			var n := 0
			for l in data["ecommerce"]["listings"].values():
				if l.get("active", false):
					n += 1
			return n
		"cash":
			return Ledger.cash(business_entity())
		"personal_cash":
			return Ledger.cash("player")
		"gross_profit_total":
			return Ledger.lifetime_gross_profit(business_entity()) + (Ledger.lifetime_gross_profit("player") if company_id() != "" else 0.0)
		"inventory_units":
			return float(Ecommerce.total_units())
		"day":
			return float(Clock.day_index())
		"month_gmv":
			return Ecommerce.month_gmv()
	return float(data.get("stats", {}).get(name, 0.0))


# ------------------------------------------------------------------ entities
func company_id() -> String:
	return str(data.get("company", ""))


## The entity whose books the business currently runs on.
func business_entity() -> String:
	var c := company_id()
	return c if c != "" and flag("business_account_opened") else "player"


func entity_name(id: String) -> String:
	if data.get("entities", {}).has(id):
		return data["entities"][id].get("name", id)
	if DataDB.companies.has(id):
		return DataDB.companies[id].get("name", id)
	return id


func business_display_name() -> String:
	var c := company_id()
	if c != "":
		return entity_name(c)
	return I18n.t("%s (personal seller)") % data["player"]["name"]


# ------------------------------------------------------------------ messages / timeline
func add_message(from_id: String, text: String) -> void:
	text = I18n.t(text)   # a plain English line becomes the player's language; already-translated text passes through
	data["messages"].append({"t": Clock.now(), "from": from_id, "text": text, "read": false})
	EventBus.message_received.emit(from_id, text)


func unread_messages() -> int:
	var n := 0
	for m in data.get("messages", []):
		if not m.get("read", false):
			n += 1
	return n


func timeline(text: String, kind := "life", metadata := {}) -> void:
	var row := {"t": Clock.now(), "text": text, "kind": kind}
	for key in ["art", "category", "entity", "npc"]:
		if metadata.has(key): row[key] = metadata[key]
	data["timeline"].append(row)


func mark_visited(key: String) -> void:
	if not data["visited"].has(key):
		data["visited"][key] = Clock.now()
	EventBus.location_entered.emit("visit", key)


func visited(key: String) -> bool:
	return data.get("visited", {}).has(key)
