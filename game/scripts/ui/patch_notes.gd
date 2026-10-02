class_name PatchNotes
extends RefCounted
## Player-facing release notes, shown once after loading a game from an older version.

static func compare(a: String, b: String) -> int:
	return SaveCodec.compare_versions(a, b)


static func since(saved: String, current: String, notes: Dictionary) -> Array:
	var versions: Array = []
	for version in notes:
		if compare(str(version), saved) > 0 and compare(str(version), current) <= 0:
			versions.append(version)
	versions.sort_custom(func(a, b): return compare(str(a), str(b)) < 0)
	return versions


static func needs_notice(data: Dictionary) -> bool:
	return data.get("meta", {}).get("version", "") != str(ProjectSettings.get_setting("application/config/version"))


static func after_load() -> void:
	var loaded: Dictionary = GameState.data
	while SceneRouter.transitioning:
		await SceneRouter.get_tree().process_frame
	if not is_same(GameState.data, loaded) or not needs_notice(loaded): return
	var current := str(ProjectSettings.get_setting("application/config/version"))
	var previous := str(loaded["meta"].get("version", ""))
	var lines: Array = []
	for version in since(previous, current, DataDB.patch_notes):
		var note: Dictionary = DataDB.patch_notes[version]
		lines.append(I18n.t("# Version %s · %s") % [version, str(note.get("date", ""))])
		for line in note.get("lines", []): lines.append("• " + I18n.t(str(line)))
	if lines.is_empty(): lines.append(I18n.t("Your saved game is ready to continue in this version."))
	var modal := InfoModal.make("What's new", "info", lines, Vector2(420, 280))
	modal.name = "PatchNotesModal"
	modal.ok_text = "Continue game"
	modal.ok_name = "ContinueUpdatedGame"
	modal.help_key = "patch_notes"
	modal.closed.connect(func():
		if is_same(GameState.data, loaded):
			loaded["meta"]["version"] = current
			if not SaveSystem.save(SaveSystem.current_slot()):
				loaded["meta"]["version"] = previous
				UIRoot.toast(SaveSystem.last_error, "warn", "save"))
	UIRoot.open_modal(modal)
