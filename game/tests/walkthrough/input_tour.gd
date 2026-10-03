extends "res://tests/walkthrough/settings_tour.gd"
## Short input acceptance: actual joypad navigation and target bounds, plus native mobile framing.


func _settle() -> void:
	for frame in 4:
		await get_tree().process_frame


func _pad(button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	await _settle()
	event = InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = false
	Input.parse_input_event(event)
	await _settle()


func _scan_targets(node: Node) -> void:
	if node is Button:
		var good: bool = node.size.x >= 43.9 and node.size.y >= 43.9
		checks.append({"target": str(node.get_path()), "ok": good, "size": str(node.size)})
		if not good:
			failures.append("Small button: " + str(node.get_path()))
	for child in node.get_children():
		_scan_targets(child)


func _navigate(modal: Modal, label: String) -> void:
	modal.help_key = ""
	UIRoot.open_modal(modal)
	InputAccess.controller_mode = true
	await _settle()
	_scan_targets(modal)
	var controls: Array[Control] = InputAccess.focus_surface(modal)
	await _settle()
	var visited := {}
	for index in controls.size():
		var focus := get_viewport().gui_get_focus_owner()
		if focus != null and modal.is_ancestor_of(focus):
			visited[focus.get_instance_id()] = true
		await _pad(JOY_BUTTON_DPAD_DOWN)
	var reachable := visited.size() == controls.size() and not controls.is_empty()
	checks.append({"modal": label, "ok": reachable, "focusable": controls.size(), "visited": visited.size()})
	if not reachable:
		failures.append(label + ": D-pad did not reach every control")
	if modal is SettingsModal:
		await _shot("controller_focus")
	if modal.closable:
		await _pad(JOY_BUTTON_B)
		var closed := not is_instance_valid(modal) or modal.is_queued_for_deletion()
		checks.append({"modal": label + " B returns", "ok": closed})
		if not closed:
			failures.append(label + ": B did not close")
	elif modal is RunCardModal:
		await _pad(JOY_BUTTON_B)
		var waits := is_instance_valid(modal) and not modal.is_queued_for_deletion()
		await _pad(JOY_BUTTON_A)
		var acknowledged := not is_instance_valid(modal) or modal.is_queued_for_deletion()
		checks.append({"modal": label + " A acknowledges", "ok": waits and acknowledged})
		if not waits or not acknowledged:
			failures.append(label + ": controller acknowledgement failed")
	elif modal is InsolvencyModal:
		await _pad(JOY_BUTTON_B)
		var waits := is_instance_valid(modal) and not modal.is_queued_for_deletion()
		await _pad(JOY_BUTTON_A)
		var rescued := not Insolvency.active() and (not is_instance_valid(modal) or modal.is_queued_for_deletion())
		checks.append({"modal": label + " B waits, A rescues", "ok": waits and rescued})
		if not waits or not rescued:
			failures.append(label + ": controller rescue failed")
	else:
		await _pad(JOY_BUTTON_B)
		var waits := is_instance_valid(modal) and not modal.is_queued_for_deletion()
		checks.append({"modal": label + " decision cannot dismiss", "ok": waits})
		if not waits:
			failures.append(label + ": cancel discarded a decision")
		var history_before: int = EventEngine.S()["history"].size()
		await _pad(JOY_BUTTON_A)
		var chosen: bool = EventEngine.S()["history"].size() == history_before + 1
		if is_instance_valid(modal):
			await _pad(JOY_BUTTON_A)
		checks.append({"modal": label + " A chooses and acknowledges", "ok": chosen})
		if not chosen:
			failures.append(label + ": A did not choose")
			if is_instance_valid(modal):
				modal.close()
	await _settle()


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.substr(6)
	if out.is_empty() or out.begins_with("user://"):
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	SaveSystem.autosave_enabled = false
	SaveSystem.DIR = out.path_join("saves")
	Preferences.path = out.path_join("settings.cfg")
	Preferences.values = Preferences.DEFAULTS.duplicate()
	Preferences.apply()
	GameState.new_game({"name": "Input QA", "seed": 88})
	UIRoot.tutorial.st()["off"] = true
	SceneRouter._enter("interior", "riverside_apartment", "bed_side", "down")
	UIRoot.close_all()
	await _settle()
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	InputAccess.touch_mode = true
	await _settle()
	UIK.clear(UIRoot.card_layer)
	var player := SceneRouter.world_scene().player
	player.global_position = Vector2(172, 92)
	player.face("up")
	await _settle()
	await _shot("mobile_landscape")
	var world := SceneRouter.world_scene()
	var target := world.player.global_position + Vector2(24, 0)
	var planned := world.player.walk_to(target)
	for frame in 120:
		await get_tree().physics_frame
	checks.append({"touch_path": "apartment tap", "ok": planned and world.player.click_route.is_empty()})
	if not planned or not world.player.click_route.is_empty():
		failures.append("Touch route did not complete")
	Clock.world_active = false
	UIRoot.set_hud_visible(false)
	InputAccess.touch_mode = false
	var directory := DirAccess.open("res://scripts/ui/modals")
	for file in directory.get_files():
		if file.ends_with(".gd") and file not in ["metro_lines.gd", "world_routes.gd"]:
			var modal: Modal
			if file == "insolvency_modal.gd":
				Company.register("Input QA Company", "ecommerce", "riverside_studio")
				Insolvency.begin(GameState.company_id(), "QA input test")
				modal = InsolvencyModal.new()
			elif file == "decision_modal.gd":
				modal = DecisionModal.new(EventEngine.trigger("low_cash_warning", {"entity_name": "QA", "cash": Fmt.money(100), "upcoming": Fmt.money(200)}))
			else:
				modal = _make(file)
			await _navigate(modal, file)
	var games := DirAccess.open("res://scripts/ui/minigames")
	for file in games.get_files():
		if file.ends_with(".gd") and file not in ["mini_game.gd", "mini_games.gd"]:
			await _navigate(_make_game(file), file)
	SceneRouter._set_scene(CharacterCreator.new())
	InputAccess.controller_mode = true
	await _settle()
	_scan_targets(SceneRouter.current)
	var creator := SceneRouter.current as CharacterCreator
	var scroll := creator.find_child("CharacterScroll", true, false) as ScrollContainer
	var creator_fits := scroll != null and scroll.size == creator.get_viewport_rect().size
	checks.append({"creator_scroll": "fills viewport", "ok": creator_fits})
	if not creator_fits:
		failures.append("Character creation scroll does not fill viewport")
	await _shot("touch_creator")
	var report := FileAccess.open(out.path_join("input_result.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	report.close()
	print("Input tour: %d checks, %d failures" % [checks.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
