extends Node
func _ready() -> void: call_deferred("run")
func run() -> void:
	var fixture := ""
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--fixture="): fixture = arg.substr(10)
		if arg.begins_with("--out="): out = arg.substr(6)
	SaveSystem.DIR = out.path_join("legacy-qa-saves")
	SaveSystem.autosave_enabled = false
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)
	var text := FileAccess.get_file_as_string(fixture)
	var original: Dictionary = JSON.parse_string(text)["data"]
	# Save migration canonicalizes the sequence counter from JSON float to integer.
	original["ledger"]["seq"] = int(original["ledger"]["seq"])
	var slot := FileAccess.open(SaveSystem._path(9), FileAccess.WRITE)
	slot.store_string(text)
	slot.close()
	var loaded := SaveSystem.load_data(9)
	var failures: Array = []
	if not loaded: failures.append("played save failed to load")
	if GameState.data["ledger"] != original["ledger"]: failures.append("historical ledger changed during load")
	TrafficSafety.S()
	if TrafficSafety.speed_multiplier() != 1.0: failures.append("old save acquired an injury")
	var previous_gigs: Dictionary = original.get("careers", {}).get("freelance", {}).get("gigs", {})

	Clock.world_active = false
	Clock.clear_pauses()
	var balanced := Ledger.check_balanced()
	if not balanced: failures.append("played save unbalanced")
	var report := FileAccess.open(out.path_join("legacy-played-save-result.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"fixture":fixture,"loaded":loaded,"old_gigs":previous_gigs.size(),"ledger_unchanged":GameState.data["ledger"] == original["ledger"],"balanced":balanced,"failures":failures}, "\t"))
	print("PLAYED LEGACY SAVE: loaded=%s, %d old gigs, %d failures" % [str(loaded),previous_gigs.size(),failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
