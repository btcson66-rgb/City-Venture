extends Node
## Save / load (Handoff §78, kickoff §19). Saves the whole GameState.data plus the exact scene
## and player position, never "just the scene".

var DIR := "user://saves"
## Every game lives in its own slot and autosaves there, so starting a new game never touches another one.
## Slot 0 is where games from before 0.1.6 autosaved; they keep saving there when continued.
const AUTOSAVE_SLOT := 0
const GAME_SLOTS := [1, 2, 3, 4, 5, 6]
## Continuous autosave: every scene change, every AUTOSAVE_EVERY real seconds of play when something
## moved, when the window loses focus or closes, and (web) when the tab is hidden or reloaded — a
## refresh never costs more than a few seconds of play.
const AUTOSAVE_EVERY := 15.0

signal saved(slot: int)
signal loaded(slot: int)

var autosave_enabled := true
var next_slot := -1        # the slot the title screen picked for the next new game (when every slot is taken)
var _since := 0.0
var _last_sig := ""
var _js_cbs: Array = []   # JavaScriptBridge callbacks must stay referenced


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_hook_web_lifecycle()


func _process(delta: float) -> void:
	_since += delta
	if _since >= float(Preferences.values["autosave_seconds"]):
		_since = 0.0
		autosave_if_changed()


func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_GO_BACK_REQUEST]:
		autosave_if_changed()


func _hook_web_lifecycle() -> void:
	var cb := JavaScriptBridge.create_callback(func(_args): autosave_if_changed())
	_js_cbs.append(cb)
	var doc = JavaScriptBridge.get_interface("document")
	var win = JavaScriptBridge.get_interface("window")
	if doc != null:
		doc.addEventListener("visibilitychange", cb)
	if win != null:
		win.addEventListener("pagehide", cb)
		win.addEventListener("beforeunload", cb)


## True while there is a live game world whose state is safe to snapshot.
func can_autosave() -> bool:
	return autosave_enabled and GameState.has_game() and Clock.world_active and not SceneRouter.transitioning \
		and SceneRouter.world_scene() != null


func autosave_if_changed() -> void:
	if not can_autosave():
		return
	var ws := SceneRouter.world_scene()
	var pos: Vector2 = ws.player.position if ws.player != null else Vector2.ZERO
	var sig := "%d|%s|%d|%d|%d" % [Clock.now(), ws.scene_id, int(pos.x), int(pos.y), int(GameState.data["ledger"]["seq"])]
	if sig == _last_sig:
		return
	autosave()


func _path(slot: int) -> String:
	return "%s/slot_%d.json" % [DIR, slot]


func has_save(slot: int) -> bool:
	return FileAccess.file_exists(_path(slot))


## The slot the game in memory saves to.
func current_slot() -> int:
	if not GameState.has_game():
		return -1
	return int(GameState.data.get("meta", {}).get("slot", AUTOSAVE_SLOT))


func free_slot() -> int:
	for s in GAME_SLOTS:
		if not has_save(s):
			return s
	return -1


## Called when a new game is created: the slot it will live in. The title screen asks before a save is replaced
## (next_slot); a replaced save is moved to saves/replaced/, never deleted.
func claim_slot() -> int:
	var s := next_slot if next_slot >= 0 else free_slot()
	next_slot = -1
	if s < 0:
		var oldest := INF
		for g in GAME_SLOTS:
			var t := float(summary(g).get("saved_unix", 0))
			if t < oldest:
				oldest = t
				s = g
	if has_save(s):
		backup(s)
	return s


## Move a slot's file into saves/replaced/ (kept, just out of the list).
func backup(slot: int) -> void:
	var dir := DIR + "/replaced"
	DirAccess.make_dir_recursive_absolute(dir)
	DirAccess.rename_absolute(_path(slot), "%s/slot_%d_%d.json" % [dir, slot, int(Time.get_unix_time_from_system())])


## Every saved game, newest first: [{slot, summary}].
func save_list() -> Array:
	var out: Array = []
	for s in [AUTOSAVE_SLOT] + GAME_SLOTS:
		if has_save(s):
			var sm := summary(s)
			if not sm.is_empty():
				out.append({"slot": s, "summary": sm})
	out.sort_custom(func(a, b): return float(a["summary"].get("saved_unix", 0)) > float(b["summary"].get("saved_unix", 0)))
	return out


func latest_slot() -> int:
	var best := -1
	var best_t := -1.0
	for s in [AUTOSAVE_SLOT] + GAME_SLOTS:
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
	return save_to(_path(slot), slot)


## Write the current game to any path (slots, or a copy attached to a bug report).
func save_to(path: String, slot := -1) -> bool:
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
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_error("SaveSystem: cannot write " + path)
		return false
	f.store_string(JSON.stringify(payload))
	f.close()
	if slot >= 0:
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
	GameState.data["meta"]["slot"] = slot     # carry on saving where this game was loaded from
	Contracts.reconcile_closed()             # old liquidations sold AR but left live contracts and collection schedules
	Contracts.reconcile_tags()               # older builds could leave a story step waiting on a settled offer
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
	if not GameState.has_game():
		return
	_since = 0.0
	if save(current_slot()):
		var ws := SceneRouter.world_scene()
		var pos: Vector2 = ws.player.position if ws != null and ws.player != null else Vector2.ZERO
		_last_sig = "%d|%s|%d|%d|%d" % [Clock.now(), ws.scene_id if ws != null else "", int(pos.x), int(pos.y), int(GameState.data["ledger"]["seq"])]


func _migrate(d: Dictionary) -> Dictionary:
	# a save from an older build: add whatever sections and fields this build has that it doesn't
	_fill_missing(d, GameState.template())
	# Before era-specific receipts, the generic news flag referred to the save's current era.
	if d["flags"].get("news_read", false):
		d["flags"]["news_read_y%d" % int(d["world"].get("year", 1))] = true
	# JSON has no ints: normalise the hot counters back to int so arithmetic stays exact.
	d["clock"]["minutes"] = int(d["clock"]["minutes"])
	d["ledger"]["seq"] = int(d["ledger"]["seq"])
	for k in d["ecommerce"]["counters"]:
		d["ecommerce"]["counters"][k] = int(d["ecommerce"]["counters"][k])
	for it in d["schedule"]:
		it["t"] = int(it["t"])
	return d


## Add keys from `tpl` that `d` lacks, recursively into dictionaries. Existing values are never touched.
static func _fill_missing(d: Dictionary, tpl: Dictionary) -> void:
	for k in tpl:
		if not d.has(k):
			d[k] = tpl[k]
		elif typeof(d[k]) == TYPE_DICTIONARY and typeof(tpl[k]) == TYPE_DICTIONARY:
			_fill_missing(d[k], tpl[k])
