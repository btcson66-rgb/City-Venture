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
signal exported(filename: String)

var autosave_enabled := true
var next_slot := -1        # the slot the title screen picked for the next new game (when every slot is taken)
var _since := 0.0
var _last_sig := ""
var _js_cbs: Array = []   # JavaScriptBridge callbacks must stay referenced
var last_error := ""
var pending_import := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web"):
		_hook_web_lifecycle()


func _process(delta: float) -> void:
	_since += delta
	if _since >= AUTOSAVE_EVERY:
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
		if not backup(s):
			last_error = "A backup could not be created. Your existing save is unchanged."
			return -1
	return s


## Copy a slot into saves/replaced/ before any replacement, preserving the primary on failure.
func backup(slot: int) -> bool:
	var dir := DIR + "/replaced"
	if FileAccess.file_exists(dir) or DirAccess.make_dir_recursive_absolute(dir) != OK: return false
	return DirAccess.copy_absolute(_path(slot), "%s/slot_%d_%d_%d.json" % [dir, slot, int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]) == OK


## Every saved game, newest first: [{slot, summary}].
func save_list() -> Array:
	var out: Array = []
	for s in [AUTOSAVE_SLOT] + GAME_SLOTS:
		if has_save(s):
			var sm := summary(s)
			out.append({"slot": s, "summary": sm, "corrupt": sm.is_empty(), "backup": recovery_index(s)})
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
	var result := validate_text(FileAccess.get_file_as_string(_path(slot)))
	if not result["ok"]:
		return {}
	return result["payload"].get("summary", {})


func save(slot := 1) -> bool:
	if slot < 0:
		return false
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
	if not _atomic_write(path, JSON.stringify(payload), slot >= 0):
		last_error = "The save could not be written. Your existing save is unchanged."
		return false
	if slot >= 0:
		saved.emit(slot)
	return true


## Load into GameState only (no scene change). Used by tests and by load_and_enter().
func load_data(slot: int) -> bool:
	if not has_save(slot):
		return false
	var result := validate_text(FileAccess.get_file_as_string(_path(slot)))
	if not result["ok"]:
		last_error = result["error"]
		return false
	GameState.data = result["payload"]["data"]
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
	PatchNotes.after_load()
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


## Validate without changing the running game; migrations run only on the decoded copy.
func validate_text(text: String) -> Dictionary:
	var result := SaveCodec.decode(text)
	if result["ok"]:
		result["payload"]["data"] = _migrate(result["payload"]["data"])
	return result


## A completed temporary file replaces its destination atomically. No delete-then-write window.
func _atomic_write(path: String, text: String, rotate := false) -> bool:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return false
	file.store_string(text)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK: return false
	if rotate and FileAccess.file_exists(path):
		for index in [3, 2]:
			var previous := path.trim_suffix(".json") + ".bak%d" % (index - 1)
			if FileAccess.file_exists(previous) and not _atomic_write(path.trim_suffix(".json") + ".bak%d" % index, FileAccess.get_file_as_string(previous)):
				return false
		if not _atomic_write(path.trim_suffix(".json") + ".bak1", FileAccess.get_file_as_string(path)):
			return false
	return DirAccess.rename_absolute(temp, path) == OK


func recovery_index(slot: int) -> int:
	for index in [1, 2, 3]:
		var path := _path(slot).trim_suffix(".json") + ".bak%d" % index
		if FileAccess.file_exists(path) and validate_text(FileAccess.get_file_as_string(path))["ok"]:
			return index
	return -1


func restore_backup(slot: int) -> bool:
	var index := recovery_index(slot)
	if index < 0: return false
	if has_save(slot) and not backup(slot): return false
	var path := _path(slot).trim_suffix(".json") + ".bak%d" % index
	return _atomic_write(_path(slot), FileAccess.get_file_as_string(path))


func import_text(text: String, slot := -1, replace := false) -> Dictionary:
	var result := validate_text(text)
	if not result["ok"]: return result
	if slot < 0: slot = free_slot()
	if slot < 0: return {"ok": false, "full": true, "payload": result["payload"], "error": "Choose a save slot to replace. Its existing save will be backed up."}
	if not slot in GAME_SLOTS: return {"ok": false, "error": "This is not a City Venture save."}
	if has_save(slot) and (not replace or not backup(slot)):
		return {"ok": false, "error": "A backup could not be created. Your existing save is unchanged."}
	result["payload"]["data"]["meta"]["slot"] = slot
	DirAccess.make_dir_recursive_absolute(DIR)
	if not _atomic_write(_path(slot), JSON.stringify(result["payload"]), true):
		return {"ok": false, "error": "The save could not be written. Your existing save is unchanged."}
	return {"ok": true, "slot": slot}


func export_filename() -> String:
	var who := str(GameState.data["player"]["name"])
	var safe := ""
	for character in who:
		safe += "_" if character.unicode_at(0) in [60, 62, 58, 34, 47, 92, 124, 63, 42] or character.unicode_at(0) < 32 else character
	safe = safe.strip_edges().left(60).trim_suffix(".")
	if safe.is_empty(): safe = "Player"
	var date := Clock.date()
	return "CityVenture_%s_%04d-%02d-%02d.cvsave" % [safe, date["year"], date["month"], date["day"]]


func show_export() -> void:
	if not GameState.has_game(): return
	if OS.has_feature("web"):
		var path := "user://export.cvsave"
		if save_to(path):
			JavaScriptBridge.download_buffer(FileAccess.get_file_as_bytes(path), export_filename(), "application/json")
			exported.emit(export_filename())
		else: _transfer_error(last_error)
		return
	var dialog := FileDialog.new()
	dialog.name = "ExportSaveDialog"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.filters = PackedStringArray(["*.cvsave ; " + I18n.t("City Venture save")])
	dialog.current_file = export_filename()
	get_tree().root.add_child(dialog)
	dialog.file_selected.connect(func(path):
		if not save_to(path): _transfer_error(last_error)
		else:
			UIRoot.toast("Save exported. Keep this file outside your browser.", "good", "save")
			exported.emit(path.get_file())
		dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered(Vector2i(800, 520))
	_localize_picker(dialog)


func show_import() -> void:
	if OS.has_feature("web"):
		_web_import()
		return
	var dialog := FileDialog.new()
	dialog.name = "ImportSaveDialog"
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.cvsave,*.json ; " + I18n.t("City Venture save")])
	get_tree().root.add_child(dialog)
	dialog.file_selected.connect(func(path): _receive_import(FileAccess.get_file_as_string(path)); dialog.queue_free())
	dialog.canceled.connect(func(): dialog.queue_free())
	dialog.popup_centered(Vector2i(800, 520))
	_localize_picker(dialog)


func _localize_picker(dialog: FileDialog) -> void:
	# Engine file pickers have their own strings and do not use the game's gettext catalogue.
	var picker_theme := UIK.theme().duplicate() as Theme
	picker_theme.set_font("title_font", "Window", UIK.body_font())
	picker_theme.set_font_size("title_font_size", "Window", 10)
	dialog.theme = picker_theme
	dialog.title = I18n.t("Export save" if dialog.file_mode == FileDialog.FILE_MODE_SAVE_FILE else "Import save")
	var words := {"Directories & Files:": I18n.t("Directories & Files:"), "Favorites:": I18n.t("Favorites:"), "Recent:": I18n.t("Recent:"), "File:": I18n.t("File:"), "Path:": I18n.t("Path:"), "Save": I18n.t("Save"), "Open": I18n.t("Open"), "Cancel": I18n.t("Cancel"), "All Files (*)": I18n.t("All Files (*)")}
	for control in dialog.find_children("*", "Control", true, false):
		if control is Label or control is Button:
			if words.has(control.text):
				control.text = words[control.text]
				control.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


func _web_import() -> void:
	var document = JavaScriptBridge.get_interface("document")
	var input = document.createElement("input")
	input.type = "file"
	input.accept = ".cvsave,.json"
	input.style.display = "none"
	document.body.appendChild(input)
	var reader = JavaScriptBridge.create_object("FileReader")
	var callbacks: Array = []
	var finish := JavaScriptBridge.create_callback(func(_args):
		_receive_import(str(reader.result))
		input.remove()
		_release_callbacks.call_deferred(callbacks))
	var failure := JavaScriptBridge.create_callback(func(_args): _transfer_error("The file could not be read. Your existing save is unchanged."); input.remove(); _release_callbacks.call_deferred(callbacks))
	var selected := JavaScriptBridge.create_callback(func(_args):
		if int(input.files.length) > 0: reader.readAsText(input.files.item(0))
		else: input.remove(); _release_callbacks.call_deferred(callbacks))
	var cancel := JavaScriptBridge.create_callback(func(_args): input.remove(); _release_callbacks.call_deferred(callbacks))
	callbacks.append_array([finish, failure, selected, cancel])
	_js_cbs.append_array(callbacks)
	reader.onload = finish
	reader.onerror = failure
	input.onchange = selected
	input.oncancel = cancel
	input.click()


func _release_callbacks(callbacks: Array) -> void:
	for callback in callbacks: _js_cbs.erase(callback)
	callbacks.clear()


func _receive_import(text: String) -> void:
	var result := import_text(text)
	if result.get("full", false):
		pending_import = result["payload"]
		UIRoot.close_all()
		UIRoot.open_modal(SaveListModal.new("import"))
	elif result["ok"]:
		UIRoot.close_all()
		load_and_enter(result["slot"])
		UIRoot.toast("Save imported. Continue where you left off.", "good", "save")
	else: _transfer_error(result["error"])


func _transfer_error(message: String) -> void:
	UIRoot.open_modal(InfoModal.make("Save transfer", "save", [I18n.t(message)]))
