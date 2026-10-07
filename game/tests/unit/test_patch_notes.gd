extends RefCounted
var runner

func test_beta_release_notes_are_complete_in_both_languages() -> void:
	var note: Dictionary = DataDB.patch_notes.get("0.2.0-beta", {})
	var lines: Array = note.get("lines", [])
	runner.check(lines.size() >= 6 and lines.size() <= 10, "release has 6–10 player-facing updates")
	I18n.init()
	var previous := I18n.locale()
	I18n.set_locale("zh_TW", false)
	for line in lines: runner.check(I18n.t(str(line)) != str(line), "release line translated")
	I18n.set_locale(previous, false)

func test_version_filter_excludes_seen_and_future_releases() -> void:
	var notes := {"0.1.9-test9": {}, "0.1.6-test6": {}, "0.1.8-test8.1": {}, "0.1.5-test5": {}, "0.2.0-beta": {}, "0.1.7-test7": {}}
	runner.eq(PatchNotes.since("0.1.6-test6", "0.1.9-test9", notes), ["0.1.7-test7", "0.1.8-test8.1", "0.1.9-test9"], "only newer installed releases in chronological order")
	runner.eq(PatchNotes.since("0.1.9-test9", "0.1.9-test9", notes), [], "same version has no notes")
	runner.check(PatchNotes.compare("0.1.8-test8.1", "0.1.8-test8") > 0, "patch build sorts after original")
	runner.check(PatchNotes.compare("0.1.10-test10", "0.1.9-test9") > 0, "numeric ordering rather than lexical")
	runner.check(PatchNotes.compare("0.2.0", "0.2.0-beta") > 0, "stable release follows beta")

func test_new_game_needs_no_update_notice_and_historical_metadata_survives_load() -> void:
	runner.check(not PatchNotes.needs_notice(GameState.data), "new game starts on current version")
	var path := "res://tests/fixtures/saves/0.1.7-test7.cvsave"
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)   # run alone, no earlier test has created the save folder
	SaveSystem._atomic_write(SaveSystem._path(6), FileAccess.get_file_as_string(path))
	runner.check(SaveSystem.load_data(6), "historical save loads")
	runner.eq(GameState.data["meta"]["version"], "0.1.7-test7", "load_data retains source version until notice is read")
	runner.check(PatchNotes.needs_notice(GameState.data), "historical game receives notice after entering")
	for version in DataDB.patch_notes:
		runner.check(DataDB.patch_notes[version].has("date") and not DataDB.patch_notes[version].get("lines", []).is_empty(), "dated release has player-facing notes")

func test_read_notice_persists_and_cannot_modify_a_different_game() -> void:
	var help_auto := Help.auto
	Help.auto = false
	UIRoot.close_all()
	GameState.data["meta"]["version"] = "0.1.7-test7"
	PatchNotes.after_load()
	var card := UIRoot.top_modal()
	runner.check(card != null and card.name == "PatchNotesModal", "old game gets notice")
	card.close()
	runner.check(not PatchNotes.needs_notice(GameState.data), "acknowledgement records installed version")
	runner.check(SaveSystem.load_data(SaveSystem.current_slot()), "acknowledgement saved")
	runner.check(not PatchNotes.needs_notice(GameState.data), "acknowledgement survives load")
	UIRoot.close_all()
	GameState.data["meta"]["version"] = "0.1.7-test7"
	PatchNotes.after_load()
	card = UIRoot.top_modal()
	GameState.new_game({"name": "Other game", "seed": 23})
	card.close()
	runner.eq(GameState.data["player"]["name"], "Other game", "closing stale card never changes another game")
	runner.check(not PatchNotes.needs_notice(GameState.data), "other game keeps its version")
	Help.auto = help_auto
