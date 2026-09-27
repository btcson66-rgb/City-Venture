extends Node
## Save / load (Handoff §78, kickoff §19). Saves the whole GameState.data plus the exact scene
## and player position, never "just the scene".

var DIR := "user://saves"
const AUTOSAVE_SLOT := 0

signal saved(slot: int)
signal loaded(slot: int)


func _path(slot: int) -> String:
	return "%s/slot_%d.json" % [DIR, slot]


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_path(slot))


func latest_slot() -> int:
	var best := -1
	var best_t := -1.0
	for s in range(0, 4):
		if has_save(s):
			var sm := summary(s)
			if float(sm.get("saved_unix", 0)) > best_t:
				best_t = float(sm.get("saved_unix", 0))
				best = s
	return best


func summary(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var d = JSON.parse_string(FileAccess.get_file_as_string(_path(slot)))
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	return d.get("summary", {})


func save(slot := 1) -> bool:
	if not GameState.has_game():
		return false
	SceneRouter.capture_location()
	GameState.pack_rng()
	DirAccess.make_dir_recursive_absolute(DIR)
	var d := GameState.data
	var summary_d := {
		"name": d["player"]["name"], "company": GameState.business_display_name(),
		"date": Clock.fmt_datetime(), "day": Clock.day_index(), "cash": Ledger.cash("player"),
		"business_cash": Ledger.cash(GameState.business_entity()),
		"location": d["player"]["location"].get("id", ""), "saved_unix": Time.get_unix_time_from_system(),
		"chapter": d["story"].get("chapter", ""),
	}
	var payload := {"format": GameState.SAVE_FORMAT, "summary": summary_d, "data": d}
	var f := FileAccess.open(_path(slot), FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: cannot write " + _path(slot))
		return false
	f.store_string(JSON.stringify(payload))
	f.close()
	saved.emit(slot)
	return true


## Load into GameState only (no scene change). Used by tests and by load_and_enter().
func load_data(slot: int) -> bool:
	if not has_save(slot):
		return false
	var d = JSON.parse_string(FileAccess.get_file_as_string(_path(slot)))
	if typeof(d) != TYPE_DICTIONARY or int(d.get("format", 0)) != GameState.SAVE_FORMAT:
		push_error("SaveSystem: incompatible save")
		return false
	GameState.data = _migrate(d["data"])
	GameState.unpack_rng()
	Clock.clear_pauses()
	loaded.emit(slot)
	EventBus.state_loaded.emit()
	return true


func load_and_enter(slot: int) -> bool:
	if not load_data(slot):
		return false
	SceneRouter.restore_location()
	return true


func autosave() -> void:
	save(AUTOSAVE_SLOT)


func _migrate(d: Dictionary) -> Dictionary:
	# JSON has no ints: normalise the hot counters back to int so arithmetic stays exact.
	d["clock"]["minutes"] = int(d["clock"]["minutes"])
	d["ledger"]["seq"] = int(d["ledger"]["seq"])
	for k in d["ecommerce"]["counters"]:
		d["ecommerce"]["counters"][k] = int(d["ecommerce"]["counters"][k])
	for it in d["schedule"]:
		it["t"] = int(it["t"])
	return d
