extends Node
## Scripted player. Drives the REAL game with synthetic input: movement actions (Input.action_press),
## interact presses (InputEventAction) and mouse clicks on UI (InputEventMouseButton at the button's
## on-screen position). Used for the automated walkthrough test, screenshots and the recorded video.
##   godot --path game -- --bot=walkthrough [--out=<dir>] [--quit]
##   godot --path game -- --bot=shots --out=<dir>

var mode := "walkthrough"
var out_dir := ""
var shot_n := 0
var log_lines: Array = []
var failures: Array = []
var step_name := ""
var quit_at_end := true
var t0 := 0
var popup_handler: Callable
var video_mode := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		if a == "--no-quit":
			quit_at_end = false
		if a == "--video":
			video_mode = true
	if out_dir == "":
		out_dir = ProjectSettings.globalize_path("user://bot")
	DirAccess.make_dir_recursive_absolute(out_dir + "/screenshots")
	t0 = Time.get_ticks_msec()
	call_deferred("_run")


func _run() -> void:
	await wait(1.0)
	match mode:
		"shots":
			await _shots()
		"walkthrough":
			await Walkthrough.new(self).run()
	_finish()


func _finish() -> void:
	log_line("BOT FINISHED — %d failure(s) · %.1fs real" % [failures.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	var f := FileAccess.open(out_dir + "/walkthrough_log.txt", FileAccess.WRITE)
	if f:
		f.store_string("\n".join(log_lines))
		f.close()
	var res := FileAccess.open(out_dir + "/walkthrough_result.json", FileAccess.WRITE)
	if res:
		res.store_string(JSON.stringify({"failures": failures, "steps": log_lines.size(), "screenshots": shot_n}, "  "))
		res.close()
	if quit_at_end:
		get_tree().quit(0 if failures.is_empty() else 1)


# ------------------------------------------------------------------ logging
func log_line(s: String) -> void:
	var stamp := ""
	if GameState.has_game():
		stamp = "[%s] " % Clock.fmt_datetime()
	var line := "%6.1fs %s%s" % [(Time.get_ticks_msec() - t0) / 1000.0, stamp, s]
	print(line)
	log_lines.append(line)


func step(name: String) -> void:
	step_name = name
	log_line("STEP " + name)


func fail(msg: String) -> void:
	failures.append("%s: %s" % [step_name, msg])
	log_line("FAIL " + msg)


func expect(cond: bool, msg: String) -> bool:
	if cond:
		log_line("  ok  " + msg)
	else:
		fail(msg)
	return cond


# ------------------------------------------------------------------ timing
func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func frames(n := 1) -> void:
	for i in n:
		await get_tree().process_frame


func until(pred: Callable, timeout_s := 10.0) -> bool:
	var t := 0.0
	while t < timeout_s:
		if pred.call():
			return true
		await get_tree().process_frame
		t += get_process_delta_time()
	return pred.call()


# ------------------------------------------------------------------ screenshots
func shot(name: String) -> void:
	if DisplayServer.get_name() == "headless":
		log_line("  (shot %s skipped: headless)" % name)
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		return
	shot_n += 1
	var p := "%s/screenshots/%02d_%s.png" % [out_dir, shot_n, name]
	img.save_png(p)
	log_line("  shot " + p.get_file())


# ------------------------------------------------------------------ input
func key_action(action: String, hold := 0.08) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	Input.action_press(action)
	await wait(hold)
	var ev2 := InputEventAction.new()
	ev2.action = action
	ev2.pressed = false
	Input.parse_input_event(ev2)
	Input.action_release(action)
	await frames(2)


func release_moves() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "run"]:
		Input.action_release(a)


func find_button(pred: Callable, root: Node = null) -> Button:
	if root == null:
		root = get_tree().root
	for n in root.find_children("*", "Button", true, false):
		var b := n as Button
		if b.is_visible_in_tree() and not b.disabled and pred.call(b):
			return b
	return null


func button_named(name: String) -> Button:
	return find_button(func(b): return b.name == name)


func button_text(txt: String) -> Button:
	return find_button(func(b): return b.text.contains(txt))


## Real mouse click at the button's on-screen centre.
func click(b: Button) -> bool:
	if b == null:
		return false
	var sc: Node = b.get_parent()
	while sc != null and not sc is ScrollContainer:
		sc = sc.get_parent()
	if sc != null:
		(sc as ScrollContainer).ensure_control_visible(b)
		await frames(3)
	var center := b.get_global_rect().get_center()
	var screen := get_viewport().get_final_transform() * center
	var mv := InputEventMouseMotion.new()
	mv.position = screen
	mv.global_position = screen
	Input.parse_input_event(mv)
	await frames(2)
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = screen
	down.global_position = screen
	Input.parse_input_event(down)
	await frames(1)
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	up.position = screen
	up.global_position = screen
	Input.parse_input_event(up)
	await frames(3)
	return true


func click_named(name: String, timeout_s := 5.0) -> bool:
	var ok := await until(func(): return button_named(name) != null, timeout_s)
	if not ok:
		fail("button '%s' not found" % name)
		_diagnose(name)
		return false
	var b := button_named(name)
	log_line("  click [%s] %s" % [name, b.text.replace("\n", " ").left(50)])
	await click(b)
	return true


## Context for a failed lookup: what is on screen and whether the button exists at all.
func _diagnose(name: String) -> void:
	var m = UIRoot.top_modal()
	log_line("      diag: modal=%s dialogue=%s phone=%s" % [m.get_class() + ":" + str(m.get_script().get_global_name()) if m != null else "none",
		str(UIRoot.dialogue.active), str(UIRoot.phone.is_open)])
	var prefix := name.split("_")[0]
	for n in get_tree().root.find_children(prefix + "*", "Button", true, false):
		var b := n as Button
		log_line("      diag: %s visible=%s disabled=%s" % [b.name, str(b.is_visible_in_tree()), str(b.disabled)])


func click_text(txt: String, timeout_s := 5.0) -> bool:
	var ok := await until(func(): return button_text(txt) != null, timeout_s)
	if not ok:
		fail("button containing '%s' not found" % txt)
		return false
	var b := button_text(txt)
	log_line("  click \"%s\"" % b.text.replace("\n", " ").left(50))
	await click(b)
	return true


func type_into(edit: LineEdit, text: String) -> void:
	edit.grab_focus()
	edit.select_all()
	for ch in text:
		var ev := InputEventKey.new()
		ev.pressed = true
		ev.unicode = ch.unicode_at(0)
		Input.parse_input_event(ev)
		await frames(1)
		var ev2 := InputEventKey.new()
		ev2.pressed = false
		ev2.unicode = ch.unicode_at(0)
		Input.parse_input_event(ev2)
	await frames(2)
	if edit.text != text:
		edit.text = text  # fallback for headless keyboard edge cases
		log_line("  (typed via fallback)")
	edit.release_focus()


# ------------------------------------------------------------------ world navigation
func scene() -> WorldScene:
	return SceneRouter.world_scene()


func player() -> Player:
	var s := scene()
	return s.player if s != null else null


## Walk along a nav path using real movement actions.
func walk_to(target: Vector2, tol := 4.0, timeout_s := 40.0, run := true) -> bool:
	var s := scene()
	if s == null or s.player == null:
		fail("walk_to: no world scene")
		return false
	var path := s.find_path(s.player.position, target)
	if path.size() == 0:
		path = PackedVector2Array([target])
	path.append(target)
	var i := 0
	var t := 0.0
	var stuck := 0.0
	var last := s.player.position
	while i < path.size() and t < timeout_s:
		if UIRoot.is_blocking():
			release_moves()
			if popup_handler.is_valid():
				await popup_handler.call()
			await frames(2)
			continue
		if SceneRouter.world_scene() != s or not is_instance_valid(s.player):
			release_moves()
			return true  # scene changed (door / exit) — caller checks
		var p: Vector2 = s.player.position
		var wp: Vector2 = path[i]
		var d := wp - p
		var tol_i := tol if i == path.size() - 1 else 5.0
		if d.length() <= tol_i:
			i += 1
			continue
		release_moves()
		if run:
			Input.action_press("run")
		if d.x > 1.5:
			Input.action_press("move_right")
		elif d.x < -1.5:
			Input.action_press("move_left")
		if d.y > 1.5:
			Input.action_press("move_down")
		elif d.y < -1.5:
			Input.action_press("move_up")
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		if p.distance_to(last) < 0.2:
			stuck += dt
			if stuck > 1.2:
				# nudge around obstacles, then re-plan
				release_moves()
				Input.action_press(["move_left", "move_right", "move_down"][randi() % 3])
				await wait(0.25)
				release_moves()
				path = s.find_path(s.player.position, target)
				path.append(target)
				i = 0
				stuck = 0.0
		else:
			stuck = 0.0
		last = p
	release_moves()
	await frames(2)
	if SceneRouter.world_scene() != s:
		return true
	var ok := s.player.position.distance_to(target) <= tol + 6
	if not ok:
		fail("could not reach %s (at %s)" % [str(target), str(s.player.position)])
	return ok


func find_interactable(pred: Callable) -> Interactable:
	var s := scene()
	if s == null:
		return null
	for n in get_tree().get_nodes_in_group("interactable"):
		if is_instance_valid(n) and s.is_ancestor_of(n) and pred.call(n):
			return n
	return null


## Walk up to an interactable and press E. Returns true if the prompt matched and we interacted.
func use(pred: Callable, what: String) -> bool:
	if UIRoot.is_blocking() and popup_handler.is_valid():
		await popup_handler.call()
	var it := find_interactable(pred)
	if it == null:
		fail("interactable not found: " + what)
		return false
	var target := it.global_position + Vector2(0, 8)
	await walk_to(target, 3.0)
	await frames(3)
	var p := player()
	if p != null:
		# face the thing
		var d := it.global_position - p.global_position
		var act := "move_up" if d.y < -2 else ("move_down" if d.y > 2 else ("move_left" if d.x < 0 else "move_right"))
		Input.action_press(act)
		await frames(2)
		Input.action_release(act)
		await frames(4)
	var ok := await until(func(): return player() != null and player().focus == it, 1.5)
	if not ok:
		# try standing a little closer
		await walk_to(it.global_position + Vector2(0, 2), 2.0, 5.0, false)
		await frames(4)
	log_line("  use \"%s\"" % it.label)
	await key_action("interact")
	return true


func use_action(action: String, what := "") -> bool:
	return await use(func(n): return n.action == action, what if what != "" else action)


func talk_through_dialogue(max_lines := 30, choose_first := true) -> void:
	var n := 0
	while UIRoot.dialogue.active and n < max_lines:
		n += 1
		await wait(0.9)
		if UIRoot.dialogue._waiting_choice:
			var b := find_button(func(bb): return bb.name == "Choice", UIRoot.dialogue)
			if b != null:
				log_line("  choose \"%s\"" % b.text)
				await click(b)
				continue
		await key_action("interact")


# ------------------------------------------------------------------ simple screenshot tour
func _shots() -> void:
	await shot("main_menu")
	var rep: String = await BugReport.capture(get_tree())
	expect(FileAccess.file_exists(rep + "/info.txt"), "F12 bug report written (%s)" % rep)
	SceneRouter._set_scene(CharacterCreator.new())
	await wait(0.8)
	await shot("creator")
	GameState.new_game({"name": "Shot Tour", "seed": 3})
	SceneRouter._set_scene(ArrivalScene.new())
	await wait(6.2)
	await shot("arrival")
	for d in ["riverside", "startup_hub", "civic_center", "financial"]:
		for b in DataDB.districts[d]["buildings"]:
			SceneRouter._enter("district", d, "door_" + b, "down")
			await wait(1.0)
			await shot("district_%s_%s" % [d, b])
		SceneRouter._enter("district", d, "metro", "down")
		await wait(0.6)
		await shot("district_" + d + "_south")
	UIRoot.open_modal(CityMapModal.new(false))
	await wait(0.4)
	await shot("city_map")
	UIRoot.close_all()
	UIRoot.open_modal(WorldMapModal.new())
	await wait(0.4)
	await shot("world_map")
	UIRoot.close_all()
	for b in DataDB.buildings:
		SceneRouter._enter("interior", b, "door", "up")
		await wait(0.8)
		await shot("interior_" + b)
	Clock.advance(5 * 60)
	SceneRouter._enter("district", "riverside", "door_bloom_coffee", "down")
	await wait(1.0)
	await shot("riverside_dusk")
	Clock.advance(4 * 60)
	await wait(0.5)
	await shot("riverside_night")
	SceneRouter._enter("district", "startup_hub", "door_nexus_cowork", "down")
	await wait(1.0)
	await shot("startup_hub_night")
