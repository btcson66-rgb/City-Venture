extends RefCounted
var runner

func test_roundtrip_import_uses_free_slot_and_keeps_running_game() -> void:
	SaveSystem.DIR = "user://transfer_roundtrip_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)
	GameState.data["player"]["name"] = "Roundtrip Founder"
	runner.check(SaveSystem.save(1), "export source saved")
	var before := FileAccess.get_file_as_string(SaveSystem._path(1))
	var source := before
	GameState.data["player"]["name"] = "Current Founder"
	var result := SaveSystem.import_text(source)
	runner.check(result["ok"], "import succeeded")
	runner.check(result["slot"] != 1, "import uses empty slot")
	runner.eq(FileAccess.get_file_as_string(SaveSystem._path(1)), before, "existing source identical")
	runner.eq(GameState.data["player"]["name"], "Current Founder", "import does not mutate live game until load")
	runner.check(SaveSystem.load_data(result["slot"]), "imported game loads")
	runner.eq(GameState.data["player"]["name"], "Roundtrip Founder", "original player recovered")
	SaveSystem.DIR = "user://test_saves"

func test_full_slots_require_explicit_replacement_and_keep_archive() -> void:
	SaveSystem.DIR = "user://transfer_full_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)
	for slot in SaveSystem.GAME_SLOTS:
		runner.check(SaveSystem.save(slot), "fill slot")
	var text := FileAccess.get_file_as_string(SaveSystem._path(1))
	var result := SaveSystem.import_text(text)
	runner.check(not result["ok"] and result.get("full", false), "full list needs player selection")
	runner.eq(FileAccess.get_file_as_string(SaveSystem._path(1)), text, "full list does not overwrite")
	runner.check(not SaveSystem.import_text(text, 1)["ok"], "selection without confirmation cannot overwrite")
	runner.check(SaveSystem.import_text(text, 1, true)["ok"], "explicit replacement succeeds")
	runner.check(DirAccess.get_files_at(SaveSystem.DIR + "/replaced").size() == 1, "replaced source archived")
	SaveSystem.DIR = "user://test_saves"

func test_backup_failure_prevents_replacing_a_slot() -> void:
	SaveSystem.DIR = "user://transfer_backup_fail_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)
	runner.check(SaveSystem.save(1), "source saved")
	var source := FileAccess.get_file_as_string(SaveSystem._path(1))
	var blocker := FileAccess.open(SaveSystem.DIR + "/replaced", FileAccess.WRITE)
	blocker.store_string("a file blocks the archive directory")
	blocker.close()
	runner.check(not SaveSystem.import_text(source, 1, true)["ok"], "backup failure aborts import")
	runner.eq(FileAccess.get_file_as_string(SaveSystem._path(1)), source, "primary identical after failure")
	SaveSystem.DIR = "user://test_saves"

func test_rotation_recovers_corrupt_primary_without_losing_it() -> void:
	SaveSystem.DIR = "user://transfer_rotation_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)
	for value in ["First", "Second", "Third", "Fourth", "Fifth"]:
		GameState.data["player"]["name"] = value
		runner.check(SaveSystem.save(1), "atomic replacement succeeds")
	for pair in [[1, "Fourth"], [2, "Third"], [3, "Second"]]:
		var payload = JSON.parse_string(FileAccess.get_file_as_string(SaveSystem._path(1).trim_suffix(".json") + ".bak%d" % pair[0]))
		runner.eq(payload["data"]["player"]["name"], pair[1], "three most recent backups")
	runner.check(SaveSystem._atomic_write(SaveSystem._path(1), "corrupt"), "damage fixture primary")
	runner.check(SaveSystem.summary(1).is_empty(), "corrupt primary identified")
	runner.eq(SaveSystem.recovery_index(1), 1, "latest usable backup")
	runner.check(SaveSystem.restore_backup(1), "restore backup succeeds")
	runner.check(SaveSystem.load_data(1), "recovered slot loads")
	runner.eq(GameState.data["player"]["name"], "Fourth", "latest backup restored")
	var archive := DirAccess.open(SaveSystem.DIR + "/replaced")
	var preserved := false
	for name in archive.get_files():
		if FileAccess.get_file_as_string(SaveSystem.DIR + "/replaced/" + name) == "corrupt": preserved = true
	runner.check(preserved, "corrupted original retained for investigation")
	SaveSystem.DIR = "user://test_saves"

func test_invalid_imports_preserve_every_existing_byte_and_game() -> void:
	SaveSystem.DIR = "user://transfer_invalid_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)
	runner.check(SaveSystem.save(1), "save before rejection")
	var original := FileAccess.get_file_as_string(SaveSystem._path(1))
	var future = JSON.parse_string(original)
	future["data"]["meta"]["version"] = "9.0.0"
	var bad_shape = JSON.parse_string(original)
	bad_shape["data"]["ledger"]["journal"] = "invalid"
	var bad_entity = JSON.parse_string(original)
	bad_entity["data"]["entities"]["player"] = "invalid"
	var bad_order = JSON.parse_string(original)
	bad_order["data"]["ecommerce"]["orders"]["#bad"] = {}
	var bad_location = JSON.parse_string(original)
	bad_location["data"]["player"]["location"] = {}
	for text in ["{", "{}", JSON.stringify(future), JSON.stringify(bad_shape), JSON.stringify(bad_entity), JSON.stringify(bad_order), JSON.stringify(bad_location)]:
		var result := SaveSystem.import_text(text, 1, true)
		runner.check(not result["ok"], "invalid import rejected")
		runner.eq(FileAccess.get_file_as_string(SaveSystem._path(1)), original, "existing bytes never deleted")
	runner.check(not SaveSystem._atomic_write(SaveSystem.DIR + "/missing/fail.json", original), "failed temporary write returns failure")
	runner.eq(FileAccess.get_file_as_string(SaveSystem._path(1)), original, "write failure does not touch existing save")
	SaveSystem.DIR = "user://test_saves"
