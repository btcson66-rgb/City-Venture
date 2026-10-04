extends RefCounted

var runner


func _store() -> Node:
	var store: Node = load("res://autoload/preferences.gd").new()
	store.path = "user://test_preferences.cfg"
	DirAccess.remove_absolute(store.path)
	return store


func test_settings_round_trip_preserves_unknown_sections_and_game() -> void:
	var store := _store()
	var before := JSON.stringify(GameState.data)
	var cfg := ConfigFile.new()
	cfg.set_value("general", "locale", "zh_TW")
	cfg.set_value("future", "keep", 42)
	cfg.save(store.path)
	store.values["master"] = 0.35
	store.values["font_size"] = 3
	store.values["tutorial_hints"] = false
	runner.eq(store.save_settings(), OK, "saved")
	store.load_settings()
	runner.eq(store.values["master"], 0.35, "volume roundtrip")
	runner.eq(store.values["font_size"], 3, "font roundtrip")
	runner.eq(store.values["tutorial_hints"], false, "boolean roundtrip")
	cfg.load(store.path)
	runner.eq(cfg.get_value("general", "locale"), "zh_TW", "locale retained")
	runner.eq(cfg.get_value("future", "keep"), 42, "unknown section retained")
	runner.eq(JSON.stringify(GameState.data), before, "old game schema untouched")
	store.free()


func test_subtitles_wait_for_choices_manual_mode_and_settings() -> void:
	UIRoot.close_all()
	await runner.get_tree().process_frame
	var dialogue := DialogueBox.new()
	runner.get_tree().root.add_child(dialogue)
	dialogue.active = true
	dialogue.lines = [{"text": "First line"}, {"text": "Second line"}]
	dialogue.text_label.visible_characters = -1
	var original: float = Preferences.values["subtitle_seconds"]
	Preferences.values["subtitle_seconds"] = 0.0
	dialogue._process(10.0)
	runner.eq(dialogue.idx, 0, "zero delay is manual, not instant skip")
	Preferences.values["subtitle_seconds"] = 2.0
	dialogue._waiting_choice = true
	dialogue._process(10.0)
	runner.eq(dialogue.idx, 0, "choices never auto-select")
	dialogue._waiting_choice = false
	var settings := Control.new()
	UIRoot.modal_layer.add_child(settings)
	dialogue._process(10.0)
	runner.eq(dialogue.idx, 0, "reading settings holds subtitles")
	UIRoot.modal_layer.remove_child(settings)
	settings.free()
	dialogue._process(1.0)
	runner.eq(dialogue.idx, 0, "paused duration is not counted")
	dialogue._process(1.0)
	runner.eq(dialogue.idx, 1, "completed plain line advances after the delay")
	Preferences.values["subtitle_seconds"] = original
	dialogue.free()


func test_remap_conflict_reset_and_persistence() -> void:
	var store := _store()
	runner.eq(store.rebind("phone", KEY_K), OK, "remap persisted")
	store.load_settings()
	runner.eq(store.bindings["phone"], [KEY_K], "remap survived load")
	runner.eq(store.rebind("map", KEY_K), ERR_INVALID_PARAMETER, "conflict rejected")
	runner.eq(store.bindings["map"], [KEY_M], "conflict leaves original key")
	runner.eq(store.reset_bindings(), OK, "defaults saved")
	store.load_settings()
	runner.eq(store.bindings, store.BINDINGS, "defaults survived restart")
	runner.eq(store.key_caption("building_activities"), "I", "new activity shortcut uses a registered binding")
	runner.eq(InputMap.action_get_events("phone").size(), 2, "no duplicate bindings")
	store.apply_input()
	runner.eq(InputMap.action_get_events("phone").size(), 2, "repeat application idempotent")
	Preferences.apply_input()
	store.free()


func test_malformed_values_and_legacy_audio() -> void:
	var store := _store()
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", 0.4)
	cfg.set_value("preferences", "ui_scale", 999.0)
	cfg.set_value("preferences", "font_size", -1)
	cfg.set_value("preferences", "autosave_seconds", "never")
	cfg.set_value("preferences", "reduce_motion", "false")
	cfg.set_value("bindings", "phone", [KEY_M])
	cfg.save(store.path)
	store.load_settings()
	runner.eq(store.values["music"], 0.4, "old audio cfg supported")
	runner.eq(store.values["ui_scale"], 1.5, "scale clamp")
	runner.eq(store.values["font_size"], 0, "font clamp")
	runner.eq(store.values["autosave_seconds"], 15.0, "bad type falls back")
	runner.eq(store.values["reduce_motion"], false, "bad bool falls back")
	runner.eq(store.bindings, store.BINDINGS, "conflicting cfg safely defaults")
	runner.eq(store.validated("master", NAN), 1.0, "nonfinite volume defaults")
	store.free()


func test_large_fonts_are_not_applied_twice_to_new_widgets() -> void:
	var store := _store()
	store.values["font_size"] = 3
	var button := UIK.button("Done", func(): pass)
	store._style(button)
	runner.eq(button.get_theme_font_size("font_size"), 12, "8px button becomes 12px")
	store._style(button)
	runner.eq(button.get_theme_font_size("font_size"), 12, "repeated styling does not multiply")
	var label := UIK.label("Font fixture", 9)
	store._style(label)
	runner.eq(label.get_theme_font_size("font_size"), 14, "explicit font size scales once")
	store.values["font_size"] = 1
	store._style(label)
	runner.eq(label.get_theme_font_size("font_size"), 9, "returns to original size")
	button.free()
	label.free()
	store.free()
