extends Node
## Short real-render settings evidence and a live scan of every concrete management modal.

var out := ""
var checks: Array = []
var failures: Array = []


func _ready() -> void:
	_run.call_deferred()


func _settle() -> void:
	for frame in 8:
		await get_tree().process_frame


func _shot(name: String) -> void:
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_jpg(out.path_join(name + ".jpg"), 0.85)


func _check_modal(modal: Modal, label: String) -> void:
	modal.help_key = ""
	UIRoot.open_modal(modal)
	await _settle()
	var viewport := modal.get_viewport_rect()
	var bounds := modal.panel.get_global_rect()
	var good := viewport.grow(1).encloses(bounds) and modal.accessibility_scroll != null
	checks.append({"modal": label, "scale": Preferences.values["ui_scale"], "font": Preferences.values["font_size"],
		"ok": good, "viewport": str(viewport), "panel": str(bounds)})
	if not good:
		failures.append(label + ": panel outside viewport")
	modal.close()
	await _settle()


func _make(file: String) -> Modal:
	var script: GDScript = load("res://scripts/ui/modals/" + file)
	match file:
		"company_os.gd": return script.new("home_laptop")
		"city_map_modal.gd": return script.new(false)
		"decision_modal.gd": return script.new({"id": DataDB.events.keys()[0], "iid": "tour", "ctx": {}})
		"job_modal.gd": return script.new("barista")
		"lease_modal.gd": return script.new("riverside_studio")
		"metro_modal.gd": return script.new("riverside")
		"pack_ship_modal.gd": return script.new("riverside_studio")
		"purchase_return_modal.gd": return script.new("missing_order")
		"loan_signing_modal.gd": return script.new(func(): pass)
		"month_close_modal.gd": return script.new({"period": "2031-06", "entities": {"player": MonthClose.current("player")}})
		"settlement_modal.gd": return SettlementModal.for_purchase("tradelink_wholesale", "phone_stand", 1, "riverside_studio")
	return script.new()


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.substr(6)
	if out.is_empty() or out.begins_with("user://"):
		push_error("Settings tour requires an explicit QA output directory outside user://.")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	SaveSystem.autosave_enabled = false
	SaveSystem.DIR = out.path_join("saves")
	Preferences.path = out.path_join("settings.cfg")
	Preferences.values = Preferences.DEFAULTS.duplicate()
	Preferences.bindings = Preferences.BINDINGS.duplicate(true)
	Preferences.apply_input()
	Preferences.apply()
	GameState.new_game({"name": "Settings QA", "seed": 87})
	Clock.world_active = false
	UIRoot.set_hud_visible(false)
	SceneRouter.go_menu()
	await _settle()
	var settings := SettingsModal.new()
	settings.help_key = ""
	UIRoot.open_modal(settings)
	await _settle()
	for page in SettingsModal.PAGES.size():
		var button := settings.find_child("SettingsPage_%d" % page, true, false) as Button
		button.pressed.emit()
		await _settle()
		await _shot("settings_%d" % page)
	settings.close()
	await _settle()
	Preferences.values["font_size"] = 3
	Preferences.apply()
	await _settle()
	var company := CompanyOS.new("home_laptop")
	company.help_key = ""
	UIRoot.open_modal(company)
	await _settle()
	await _shot("company_os_extra_large")
	company.close()
	await _settle()
	Ledger.expense("player", "advertising", 55.25, "QA report expense")
	for mode in [1, 2, 3]:
		Preferences.values["color_mode"] = mode
		Preferences.apply()
		var report := MonthCloseModal.new({"period": "2031-06", "entities": {"player": MonthClose.current("player")}})
		report.help_key = ""
		UIRoot.open_modal(report)
		await _settle()
		await _shot("report_color_%d" % mode)
		report.close()
		await _settle()
	var directory := DirAccess.open("res://scripts/ui/modals")
	for scale_value in [0.8, 1.0, 1.5]:
		Preferences.values["ui_scale"] = scale_value
		Preferences.apply()
		await _settle()
		for file in directory.get_files():
			if file.ends_with(".gd") and file not in ["metro_lines.gd", "world_routes.gd"]:
				await _check_modal(_make(file), file)
	var games := DirAccess.open("res://scripts/ui/minigames")
	for scale_value in [0.8, 1.0, 1.5]:
		Preferences.values["ui_scale"] = scale_value
		Preferences.apply()
		await _settle()
		for game_file in games.get_files():
			if game_file.ends_with(".gd") and game_file not in ["mini_game.gd", "mini_games.gd"]:
				var game: Modal = load("res://scripts/ui/minigames/" + game_file).new()
				await _check_modal(game, game_file + " (intro)")
	var menu_scroll := SceneRouter.current.get_node("MenuScroll") as ScrollContainer
	var menu_ok := menu_scroll.size.x > 100.0 and menu_scroll.size.y > 100.0
	checks.append({"modal": "Main menu XL at 150%", "ok": menu_ok, "size": str(menu_scroll.size)})
	if not menu_ok:
		failures.append("Main menu scroll area has no usable size")
	await _shot("main_menu_extra_large_150")
	var file := FileAccess.open(out.path_join("settings_result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	file.close()
	print("Settings tour: %d modal checks, %d failures" % [checks.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
