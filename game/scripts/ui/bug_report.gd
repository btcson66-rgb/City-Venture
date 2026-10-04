class_name BugReport
extends RefCounted
## F12 (or Pause → Report a problem): saves a screenshot, a copy of the current game, the log and a short
## info sheet into user://reports/<time>/ and opens that folder, so a tester can send it back as one folder.


static func capture(tree: SceneTree) -> String:
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "").replace(" ", "_").replace("-", "")
	var dir := "user://reports/" + stamp
	DirAccess.make_dir_recursive_absolute(dir)
	await RenderingServer.frame_post_draw
	var img := tree.root.get_texture().get_image()
	if img != null:
		img.save_png(dir + "/screenshot.png")
	if GameState.has_game():
		SaveSystem.save_to(dir + "/save.json")
	var f := FileAccess.open(dir + "/info.txt", FileAccess.WRITE)
	if f != null:
		f.store_string("\n".join(_info()) + "\n\n# What happened? (write here)\n\n")
		f.close()
	var log_path := "user://logs/godot.log"
	if FileAccess.file_exists(log_path):
		DirAccess.copy_absolute(log_path, dir + "/godot.log")
	if OS.has_feature("web"):
		# browsers can't open a folder: hand the files to the tester as downloads
		if FileAccess.file_exists(dir + "/screenshot.png"):
			JavaScriptBridge.download_buffer(FileAccess.get_file_as_bytes(dir + "/screenshot.png"), "cityventure_%s.png" % stamp, "image/png")
		JavaScriptBridge.download_buffer(("\n".join(_info())).to_utf8_buffer(), "cityventure_%s.txt" % stamp, "text/plain")
		if GameState.has_game():
			JavaScriptBridge.download_buffer(FileAccess.get_file_as_bytes(dir + "/save.json"), "cityventure_%s_save.json" % stamp, "application/json")
	elif not OS.has_feature("headless") and DisplayServer.get_name() != "headless":
		OS.shell_open(ProjectSettings.globalize_path(dir))
	return ProjectSettings.globalize_path(dir)


static func _info() -> PackedStringArray:
	var out := PackedStringArray()
	out.append("CITY VENTURE bug report")
	out.append("version: %s" % ProjectSettings.get_setting("application/config/version", ""))
	out.append("time (real): %s" % Time.get_datetime_string_from_system(false, true))
	out.append("os: %s %s · %s" % [OS.get_name(), OS.get_version(), OS.get_locale()])
	out.append("video: %s · %s" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version()])
	out.append("window: %s" % str(DisplayServer.window_get_size()))
	out.append("language: %s" % I18n.locale())
	if GameState.has_game():
		var loc: Dictionary = GameState.data["player"].get("location", {})
		out.append("game time: %s (day %d)" % [Clock.fmt_datetime(), Clock.day_index()])
		out.append("location: %s %s" % [str(loc.get("kind", "")), str(loc.get("id", ""))])
		out.append("cash: personal %s · business %s" % [Fmt.money0(Ledger.cash("player")), Fmt.money0(Ledger.cash(GameState.business_entity()))])
		out.append("company: %s" % GameState.business_display_name())
		out.append("chapters done: %s · active objectives: %s" % [str(GameState.data["story"]["chapters_done"]), str(GameState.data["story"]["active"])])
		out.append("orders delivered: %d · pending decisions: %d" % [int(GameState.stat("orders_delivered")), EventEngine.pending().size()])
	else:
		out.append("game: not started (menu)")
	return out
