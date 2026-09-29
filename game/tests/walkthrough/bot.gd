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
	# bots play the minigames at a fixed quality and skip first-open help cards (both covered by their own checks)
	Help.auto = false
	MiniGames.auto = 0.85
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
		"trailer":
			await Trailer.new(self).run()
		"screens":
			await _screens()
		"minigames":
			MiniGames.auto = -1.0
			await _minigames()
		"tutorial":
			await _tutorial_tour()
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
## Screens the walkthrough doesn't reach, from a saved end-of-June company (the trailer fixture):
## a big-contract decision, staff in the office, the loan desk, SaaS after launch, insolvency and the
## closing statement, the pause menu with audio settings.
func _screens() -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)
	var f := FileAccess.open(SaveSystem._path(9), FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string("res://tests/walkthrough/fixtures/trailer_state.json"))
	f.close()
	SaveSystem.load_data(9)
	while Clock.hour() != 10:
		Clock.advance(60)
	UIRoot._suppress_decisions = true
	EventEngine.S()["queue"].clear()
	SceneRouter._enter("interior", "small_office", "door", "up")
	UIRoot.set_hud_visible(true)
	await wait(0.8)
	# the Crestline decision (long detail text must wrap)
	var inst := EventEngine.trigger("crestline_big_offer", {})
	UIRoot.open_modal(DecisionModal.new(inst))
	await wait(0.6)
	await shot("screen_decision_big_contract")
	UIRoot.close_all()
	# staff at work in the office
	Staff.register_employer()
	for role in ["packer", "developer", "marketer"]:
		Staff.post_job(role)
		Clock.advance(19 * 60)
		Staff.hire(Staff.S()["applicants"][0]["id"])
	while not (Clock.weekday() >= 1 and Clock.weekday() <= 5 and Clock.hour() == 11):
		Clock.advance(60)
	SceneRouter._enter("interior", "small_office", "door", "up")
	await wait(1.6)
	await shot("screen_staff_in_office")
	UIRoot.open_modal(CompanyOS.new("office"))
	await wait(0.3)
	await click_named("Tab_people", 2.0)
	await wait(0.4)
	await shot("screen_people_team")
	UIRoot.close_all()
	# SaaS after launch
	Saas.start("salon_booking")
	Saas.add_dev(Saas.dev_needed(), false)
	Saas.launch()
	Clock.advance(21 * Clock.DAY)
	UIRoot.open_modal(CompanyOS.new("office"))
	await wait(0.3)
	await click_named("Tab_saas", 2.0)
	await wait(0.4)
	await shot("screen_saas_live")
	UIRoot.close_all()
	UIRoot.open_modal(LoanModal.new(true))
	await wait(0.4)
	await shot("screen_loan_desk")
	UIRoot.close_all()
	UIRoot.open_modal(PauseMenu.new())
	await wait(0.4)
	await shot("screen_pause_audio")
	UIRoot.close_all()
	# insolvency and the closing statement
	Insolvency.begin(GameState.company_id(), I18n.t("three payrolls in a row went unpaid"))
	await wait(0.8)
	await shot("screen_insolvency")
	var m = UIRoot.top_modal()
	if m is InsolvencyModal:
		await click_named("CloseCompany", 2.0)
		await wait(0.5)
		await shot("screen_closing_statement")
	expect(GameState.company_id() == "", "company closed from the insolvency screen")
	expect(Ledger.check_balanced(), "ledger balanced after closing")


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
	for d in ["riverside", "startup_hub", "civic_center", "financial", "shopping_street"]:
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
	SceneRouter._enter("district", "shopping_street", "metro", "down")
	await wait(1.0)
	await shot("shopping_street_night")
	# Saturday market on Shopping Street, then Threadline's rails
	while not (Clock.weekday() == 6 and Clock.hour() == 11):
		Clock.advance(60)
	SceneRouter._enter("district", "shopping_street", "metro", "down")
	await wait(1.0)
	var stalls: Array = scene().timed_props.filter(func(tp): return tp["node"].visible)
	expect(stalls.size() == 6, "six market stalls out on Saturday morning (%d)" % stalls.size())
	await shot("shopping_street_market")
	SceneRouter._enter("interior", "threadline_apparel", "door", "up")
	await wait(1.2)
	expect(scene().spawns["door"].distance_to(player().position) < 4.0, "player stays at the door after entering (%s)" % player().position)
	expect(Actions.npc_present("nina"), "Nina at the Threadline counter")
	GameState.set_flag("met_nina")
	Actions.run("clothing_shop", {"npc": "nina", "building": "threadline_apparel"})
	await wait(0.4)
	await click_named("Item_executive", 2.0)
	await wait(0.3)
	await click_named("Buy", 2.0)
	await wait(0.3)
	expect(Wardrobe.owns("executive"), "bought the Executive outfit")
	await shot("threadline_shop")
	await click_named("Wear", 2.0)
	UIRoot.close_all()
	await wait(0.6)
	expect(Wardrobe.wearing() == "executive", "wearing Executive")
	await shot("threadline_wearing_executive")


# ------------------------------------------------------------------ minigames (hands-on work)
func _mg_open(g: MiniGame, name: String) -> MiniGame:
	var res := {}
	MiniGames.play(g, func(r): res.merge(r))
	await wait(0.4)
	await shot("mg_%s_intro" % name)
	await click_named("StartGame", 2.0)
	await wait(0.4)
	return g


func _mg_finish(g: MiniGame, name: String, q := 0.8) -> void:
	await shot("mg_%s_play" % name)
	if is_instance_valid(g) and g.phase == "play":
		g.round_i = g.rounds - 1
		g.points = q * (g.rounds - 1)
		g.award(q)
		g.next_round()
	await wait(0.4)
	await shot("mg_%s_results" % name)
	await click_named("FinishGame", 2.0)
	await wait(0.3)
	expect(UIRoot.top_modal() == null or not (UIRoot.top_modal() is MiniGame), "%s closed after its results" % name)


func _minigames() -> void:
	GameState.new_game({"name": "Mini Games", "seed": 5})
	SceneRouter._enter("interior", "bloom_coffee", "door", "up")
	UIRoot.set_hud_visible(true)
	await wait(1.0)
	# barista: build one drink by hand
	var b: BaristaGame = await _mg_open(BaristaGame.new(), "barista")
	for f in [["Size", b.want["size"]], ["Drink", b.want["drink"]], ["Milk", b.want["milk"]], ["Shots", b.want["shots"]]]:
		await click_named("%s_%s" % [f[0], f[1]], 1.0)
	await shot("mg_barista_built")
	await click_named("Serve", 1.0)
	await wait(0.3)
	expect(b.points >= 0.99, "a correctly built drink scores full points (%.2f)" % b.points)
	await _mg_finish(b, "barista")
	var ps: ParcelSortGame = await _mg_open(ParcelSortGame.new(), "parcels")
	await click_named("Bin_" + str(ps.parcel["bin"]), 1.0)
	expect(ps.points > 0.6, "sorting a parcel into the right bin scores")
	await _mg_finish(ps, "parcels")
	var ch: CoworkHostGame = await _mg_open(CoworkHostGame.new(), "cowork")
	await click_named("Desk_" + str(ch.visitors[0]["answer"]), 1.0)
	expect(ch.points > 0.7, "handling a visitor right scores")
	await _mg_finish(ch, "cowork")
	var cf: ClerkFormsGame = await _mg_open(ClerkFormsGame.new(), "clerk")
	if str(cf.form["bad"]) == "":
		await click_named("Approve", 1.0)
	else:
		await click_named("Field_" + str(cf.form["bad"]), 1.0)
		await shot("mg_clerk_marked")
		await click_named("Reject", 1.0)
	expect(cf.points >= 0.99, "the right call on a form scores full points")
	await _mg_finish(cf, "clerk")
	var tc: TellerCashGame = await _mg_open(TellerCashGame.new(), "teller")
	var left := tc.amount
	for d in TellerCashGame.NOTES:
		while left >= d:
			await click_named("Note_%d" % d, 1.0)
			left -= d
	await shot("mg_teller_counted")
	await click_named("HandOver", 1.0)
	expect(tc.points >= 0.99, "an exact, tidy withdrawal scores full points")
	await _mg_finish(tc, "teller")
	var ph: PhotoShootGame = await _mg_open(PhotoShootGame.new("desk_lamp"), "photo")
	await click_named("Backdrop_wood", 1.0)
	await click_named("ZoomIn", 1.0)
	await wait(0.3)
	await shot("mg_photo_setup")
	await _mg_finish(ph, "photo")
	var orders := []
	for i in 3:
		orders.append({"id": "O10%d" % i, "product": ["wireless_earbuds", "desk_lamp", "water_bottle"][i], "qty": 1, "customer": "Rin Tanaka"})
	var pk: PackGame = await _mg_open(PackGame.new(orders), "pack")
	await click_named("Box_" + pk.need_box(), 1.0)
	for i in 5:
		await click_named("Pad", 1.0)
	for i in 3:
		await click_named("Seam_%d" % i, 1.0)
	for i in pk.labels.size():
		if pk.labels[i]["ok"]:
			await click_named("Label_%d" % i, 1.0)
	await shot("mg_pack_ready")
	await click_named("Seal", 1.0)
	expect(pk.points > 0.9, "a well packed order scores high (%.2f)" % pk.points)
	await _mg_finish(pk, "pack")
	var ty: TypingGame = await _mg_open(TypingGame.new("saas", "salon_booking", 2.0, "Coding session — Glow Book"), "typing")
	var line := str(ty.lines[0])
	for c in line.substr(ty.col):
		var ev := InputEventKey.new()
		ev.pressed = true
		ev.unicode = c.unicode_at(0)
		ev.keycode = KEY_SPACE if c == " " else KEY_A
		Input.parse_input_event(ev)
		await frames(1)
		if ty.round_i > 0:
			break
	await wait(0.2)
	expect(ty.round_i >= 1, "typing a whole line moves on to the next")
	await _mg_finish(ty, "typing")


# ------------------------------------------------------------------ the guided first venture, as the player sees it
func _tut_step() -> String:
	return str(UIRoot.tutorial.current().get("id", "done"))


func _tutorial_tour() -> void:
	GameState.new_game({"name": "Guide Tour", "seed": 4})
	UIRoot.set_hud_visible(true)
	await SceneRouter.begin_world()
	await wait(2.0)
	UIRoot.tutorial._seen("move")
	await wait(1.6)
	expect(_tut_step() == "phone", "step 2 is the phone (%s)" % _tut_step())
	await shot("tut_phone_button")
	UIRoot.toggle_phone()
	await wait(0.6)
	await shot("tut_phone_open")
	UIRoot.phone.close()
	GameState.set_flag("maya_intro_done")
	UIRoot.dialogue_queue.clear()
	await wait(1.6)
	await shot("tut_exit")
	SceneRouter._enter("district", "riverside", "door_riverside_apartment", "down")
	await wait(2.2)
	await shot("tut_riverside_arrow")
	GameState.set_flag("bought_coffee_bloom_coffee")
	await wait(1.6)
	await shot("tut_walk_east")
	SceneRouter._enter("district", "startup_hub", "door_nexus_cowork", "down")
	await wait(1.4)
	GameState.set_flag("met_priya")
	SceneRouter._enter("interior", "nexus_cowork", "door", "up")
	await wait(2.0)
	expect(_tut_step() == "cowork", "at the co-work: buy a day pass (%s)" % _tut_step())
	await shot("tut_cowork_arrow")
	UIRoot.open_modal(CoworkDeskModal.new())
	await wait(0.8)
	await shot("tut_cowork_daypass")
	await click_named("DayPass", 2.0)
	await wait(0.4)
	UIRoot.close_all()
	await wait(1.6)
	UIRoot.open_modal(BusinessBoard.new())
	await wait(0.8)
	await shot("tut_board")
	await click_named("Biz_ecommerce", 2.0)
	await wait(0.4)
	await shot("tut_board_ecommerce")
	await click_named("StartEcommerce", 2.0)
	UIRoot.close_all()
	await wait(1.6)
	UIRoot.open_modal(CompanyOS.new("cowork"))
	await wait(1.6)
	await shot("tut_os_overview")
	await click_named("Tab_operations", 2.0)
	await wait(0.6)
	await shot("tut_os_buy")
	await click_named("Buy_tradelink_wholesale_phone_stand", 2.0)
	UIRoot.close_all()
	await wait(1.8)
	expect(_tut_step() == "job", "after buying stock: get a job while it travels (%s)" % _tut_step())
	UIRoot.open_modal(BusinessBoard.new())
	await wait(0.6)
	await click_named("Page_jobs", 2.0)
	await wait(0.6)
	await shot("tut_jobs")
	UIRoot.close_all()
	Careers.hire("barista")
	await wait(1.6)
	SceneRouter._enter("district", "riverside", "door_bloom_coffee", "down")
	await wait(2.0)
	await shot("tut_to_shift")
	log_line("  tutorial at step %s" % _tut_step())
