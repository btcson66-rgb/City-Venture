class_name SaveTransferTour
extends RefCounted
var bot
var export_seen := false
func _init(b) -> void: bot = b

func run() -> void:
	if OS.has_feature("web"):
		await _web()
		return
	bot.get_tree().root.gui_embed_subwindows = true
	var walk := Walkthrough.new(bot)
	await walk._new_game()
	await bot.until(func(): return UIRoot.card_layer.find_child("ChapterCard", false, false) == null, 8.0)
	UIRoot._suppress_decisions = true
	GameState.data["tutorial"]["off"] = true
	GameState.data["player"]["name"] = "Save Traveler"
	var original_cash := Ledger.cash("player")
	UIRoot.open_modal(PauseMenu.new())
	await bot.wait(0.4)
	await bot.shot("save_pause_transfer")
	await bot.click_named("ExportSave", 2.0)
	await bot.wait(0.4)
	var dialog := bot.get_tree().root.get_node_or_null("ExportSaveDialog") as FileDialog
	bot.expect(dialog != null, "real desktop export picker opened")
	if dialog == null: return
	dialog.current_dir = bot.out_dir
	dialog.current_file = SaveSystem.export_filename()
	dialog.size = Vector2i(600, 310)
	dialog.position = Vector2i(20, 32)
	await bot.wait(0.4)
	await bot.shot("save_export_picker")
	# Entering a filename and pressing the actual file-dialog confirmation exports through the real handler.
	await _confirm_dialog(dialog)
	await bot.wait(0.4)
	var exported: String = bot.out_dir + "/" + SaveSystem.export_filename()
	bot.expect(FileAccess.file_exists(exported), "exported .cvsave exists")
	if not FileAccess.file_exists(exported): return
	UIRoot.close_all()
	GameState.new_game({"name": "Another Game", "seed": 22})
	SceneRouter._enter("interior", "riverside_apartment", "door", "down")
	await bot.wait(0.4)
	SaveSystem.save(SaveSystem.current_slot())
	UIRoot.open_modal(SaveListModal.new("load"))
	await bot.wait(0.4)
	await bot.shot("save_list_transfer")
	await bot.click_named("ImportSave", 2.0)
	await bot.wait(0.4)
	dialog = bot.get_tree().root.get_node_or_null("ImportSaveDialog") as FileDialog
	bot.expect(dialog != null, "real desktop import picker opened")
	if dialog == null: return
	dialog.current_dir = bot.out_dir
	dialog.current_file = exported.get_file()
	dialog.size = Vector2i(600, 310)
	dialog.position = Vector2i(20, 32)
	await bot.wait(0.4)
	await bot.shot("save_import_picker")
	await _confirm_dialog(dialog)
	await bot.wait(1.0)
	bot.expect(GameState.data["player"]["name"] == "Save Traveler", "original game continued after import")
	bot.expect(is_equal_approx(Ledger.cash("player"), original_cash), "imported cash preserved")
	bot.expect(Ledger.check_balanced(), "imported books balanced")
	await bot.shot("save_import_continued")
	var slot := SaveSystem.current_slot()
	SaveSystem.save(slot)
	SaveSystem.save(slot)
	SaveSystem._atomic_write(SaveSystem._path(slot), "corrupt")
	UIRoot.open_modal(SaveListModal.new("load"))
	await bot.wait(0.4)
	await bot.shot("save_recover_backup")
	await bot.click_named("RestoreBackup_%d" % slot, 2.0)
	await bot.wait(1.0)
	bot.expect(GameState.data["player"]["name"] == "Save Traveler", "previous backup continued")
	SaveSystem._receive_import("{}")
	await bot.wait(0.4)
	await bot.shot("save_invalid_file_message")
	UIRoot.close_all()
	UIRoot.open_modal(PauseMenu.new())
	await bot.wait(0.3)
	for tip in bot.get_tree().root.find_children("*", "InfoTip", true, false):
		if tip.tip_id == "save_export":
			await bot.click_control(tip)
			await bot.wait(0.4)
			await bot.shot("save_export_help")
			break
	UIRoot.close_all()
	for s in SaveSystem.GAME_SLOTS: SaveSystem.save(s)
	SaveSystem._receive_import(FileAccess.get_file_as_string(exported))
	await bot.wait(0.4)
	bot.expect(UIRoot.top_modal() is SaveListModal and not SaveSystem.pending_import.is_empty(), "full slots require explicit UI selection")
	await bot.shot("save_import_full_slots")
	await bot.click_named("Replace_1", 2.0)
	await bot.wait(0.4)
	await bot.shot("save_import_confirm_replace")
	await bot.click_named("ConfirmReplace", 2.0)
	await bot.wait(0.8)
	bot.expect(SaveSystem.current_slot() == 1 and GameState.data["player"]["name"] == "Save Traveler", "confirmed import replaces chosen slot only")
	SaveSystem._receive_import(FileAccess.get_file_as_string(exported))
	await bot.wait(0.2)
	UIRoot.top_modal().close()
	bot.expect(SaveSystem.pending_import.is_empty(), "closing import selector clears pending import")

func _confirm_dialog(dialog: FileDialog) -> void:
	dialog.get_line_edit().grab_focus()
	for pressed in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		Input.parse_input_event(event)
		await bot.frames(2)

func _web() -> void:
	if OS.get_cmdline_user_args().has("--verify-persisted"):
		var slot := SaveSystem.latest_slot()
		bot.expect(slot >= 0 and SaveSystem.load_and_enter(slot), "IndexedDB save survives browser refresh")
		await bot.wait(0.8)
		var expected_player := "Alex Chen" if OS.get_cmdline_user_args().has("--import-legacy") else "Save Traveler"
		bot.expect(GameState.data["player"]["name"] == expected_player, "persisted player recovered")
		if OS.get_cmdline_user_args().has("--check-updates"):
			bot.expect(not PatchNotes.needs_notice(GameState.data), "read update notice persists after browser refresh")
		_web_phase("finished")
		return
	var walk := Walkthrough.new(bot)
	await walk._new_game()
	await bot.until(func(): return UIRoot.card_layer.find_child("ChapterCard", false, false) == null, 8.0)
	UIRoot._suppress_decisions = true
	GameState.data["tutorial"]["off"] = true
	GameState.data["player"]["name"] = "Save Traveler"
	var old_import := OS.get_cmdline_user_args().has("--import-legacy")
	if not old_import:
		UIRoot.open_modal(PauseMenu.new())
		await bot.wait(0.4)
		SaveSystem.exported.connect(func(_name): export_seen = true, CONNECT_ONE_SHOT)
		_web_phase("export", "ExportSave")
		bot.expect(await bot.until(func(): return export_seen, 90.0), "browser downloads actual current save")
		UIRoot.close_all()
		GameState.new_game({"name": "Another Browser Game", "seed": 22})
		SceneRouter._enter("interior", "riverside_apartment", "door", "down")
		await bot.wait(0.8)
		SaveSystem.save(SaveSystem.current_slot())
	UIRoot.open_modal(SaveListModal.new("load"))
	await bot.wait(0.5)
	_web_phase("import", "ImportSave")
	var expected := "Riverlight Goods" if old_import else "Save Traveler"
	bot.expect(await bot.until(func(): return GameState.data["player"]["name"] == ("Alex River" if old_import else expected) or (old_import and GameState.data["meta"]["version"] == "0.1.8-test8.1"), 90.0), "browser FileReader imports selected file")
	await bot.wait(0.8)
	StoryEngine.check()
	bot.expect(Ledger.check_balanced(), "browser imported ledger balanced")
	if old_import:
		bot.expect(GameState.data["meta"]["version"] == "0.1.8-test8.1", "real historical 0.1.8 save imported in Chromium")
		if OS.get_cmdline_user_args().has("--check-updates"):
			bot.expect(await bot.until(func(): return bot.get_tree().root.find_child("PatchNotesModal", true, false) != null, 5.0), "browser older save shows what's new")
			await bot.wait(0.5)
			_web_phase("updates", "ContinueUpdatedGame")
			bot.expect(await bot.until(func(): return not PatchNotes.needs_notice(GameState.data), 90.0), "browser player acknowledges update notice")
	else:
		bot.expect(GameState.data["player"]["name"] == "Save Traveler", "download imported after new game")
	SaveSystem.save(SaveSystem.current_slot())
	_web_phase("finished")

func _web_phase(phase: String, button_name := "") -> void:
	var data := {"phase": phase, "failures": bot.failures.duplicate(), "player": GameState.data["player"]["name"] if GameState.has_game() else "", "version": GameState.data.get("meta", {}).get("version", "")}
	if button_name != "":
		var button = bot.button_named(button_name)
		bot.expect(button != null, "browser transfer button exists: " + button_name)
		var rect: Rect2 = button.get_global_rect()
		var transform: Transform2D = bot.get_viewport().get_final_transform()
		var point := transform * rect.get_center()
		data["button"] = {"x": point.x, "y": point.y}
	JavaScriptBridge.eval("window.cityVentureQA = " + JSON.stringify(data), true)
