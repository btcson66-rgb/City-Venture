extends Node
## Scene flow: Main Menu → Character Creator → Arrival → World (districts ⇄ interiors).
## Keeps the player's exact location in GameState so saves restore position, not just the scene.

var current: Node = null
var transitioning := false
var holder: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	holder = Node.new()
	holder.name = "SceneHolder"
	get_tree().root.call_deferred("add_child", holder)


func _setup_input() -> void:
	var map := {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT], "move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"run": [KEY_SHIFT], "interact": [KEY_E, KEY_SPACE, KEY_ENTER], "phone": [KEY_TAB, KEY_P], "map": [KEY_M],
		"pause": [KEY_ESCAPE], "fast_forward": [KEY_T], "company_os_hint": [KEY_C], "bug_report": [KEY_F12],
	}
	for a in map:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in map[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)


func _set_scene(n: Node) -> void:
	if current != null and is_instance_valid(current):
		# take it out of the physics world now: queue_free alone leaves the old walls in place until the end of the
		# frame, and a physics step in between shoves the new player out of them (spawned inside a room, pushed
		# 120 px down past its bottom wall)
		if current.get_parent() == holder:
			holder.remove_child(current)
		current.queue_free()
	current = n
	holder.add_child(n)


func _fade(cb: Callable, minutes := 0) -> void:
	transitioning = true
	await UIRoot.fade_out(0.25)
	if minutes > 0:
		Clock.advance(minutes)
	cb.call()
	await get_tree().process_frame
	await UIRoot.fade_in(0.3)
	transitioning = false
	SaveSystem.autosave_if_changed()


# ------------------------------------------------------------------ front-end
func go_menu() -> void:
	Sound.music("menu")
	Clock.world_active = false
	UIRoot.set_hud_visible(false)
	UIRoot.close_all()
	_set_scene(MainMenu.new())


func go_creator() -> void:
	Clock.world_active = false
	UIRoot.set_hud_visible(false)
	_fade(func(): _set_scene(CharacterCreator.new()))


func go_arrival(setup: Dictionary) -> void:
	GameState.new_game(setup)
	Clock.world_active = false
	UIRoot.set_hud_visible(false)
	_fade(func(): _set_scene(ArrivalScene.new()))


## Called by the arrival sequence when it ends.
func begin_world() -> void:
	await _fade(func():
		_enter("interior", "riverside_apartment", "bed_side", ""))
	StoryEngine.start_chapter("ch1_arrival")
	GameState.add_message("maya", "So you actually quit?")
	GameState.add_message("maya", "Call me. Or text. Or whatever.")
	SaveSystem.autosave()


# ------------------------------------------------------------------ world
func _enter(kind: String, id: String, spawn: String, facing: String, pos := Vector2(-1, -1)) -> void:
	var scene: WorldScene
	if kind == "district":
		var d := District.new()
		d.name = "District_" + id
		d.build(id)
		scene = d
	else:
		var it := Interior.new()
		it.name = "Interior_" + id
		it.build(id)
		scene = it
	var p: Vector2 = pos
	if p.x < 0:
		if spawn == "bed_side":
			p = Vector2(60, 124)
		else:
			p = scene.spawns.get(spawn, scene.spawns.get("door", Vector2(scene.size_px) / 2.0))
	var f := facing
	if f == "":
		f = "down" if kind == "district" else "up"
	_set_scene(scene)
	Sound.music_for_scene(kind, id)
	scene.spawn_player(p, f)
	if kind == "district":
		var cam := scene.player.camera
		cam.limit_left = 0
		cam.limit_top = 0
		cam.limit_right = scene.size_px.x
		cam.limit_bottom = scene.size_px.y
		cam.reset_smoothing()
	else:
		_frame_interior(scene)
	GameState.data["player"]["location"] = {"kind": kind, "id": id, "x": p.x, "y": p.y, "facing": f}
	Clock.world_active = true
	UIRoot.set_hud_visible(true)
	UIRoot.on_scene_changed(scene)
	var first_visit := not GameState.visited(id)
	GameState.mark_visited(id)
	EventBus.location_entered.emit(kind, id)
	if first_visit:
		UIRoot.show_location_card(kind, id)


func _frame_interior(scene: WorldScene) -> void:
	var cam := scene.player.camera
	var vp := Vector2(640, 360)
	if scene.size_px.x <= vp.x and scene.size_px.y <= vp.y - 40:
		# small room: fixed camera, room centred like a diorama
		cam.position_smoothing_enabled = false
		cam.top_level = true
		cam.global_position = Vector2(scene.size_px) / 2.0 + Vector2(0, -12)
	else:
		cam.limit_left = -40
		cam.limit_top = -60
		cam.limit_right = scene.size_px.x + 40
		cam.limit_bottom = scene.size_px.y + 40
	cam.reset_smoothing()


func world_scene() -> WorldScene:
	return current as WorldScene


func building_open(bid: String) -> Dictionary:
	var b := DataDB.building(bid)
	var h: Dictionary = b.get("hours", {})
	if h.has("always_if_lease") and Living.has_lease(h["always_if_lease"]):
		return {"open": true}
	if b.get("type", "") == "home":
		return {"open": true}
	var days: String = h.get("days", "all")
	var wd: String = Clock.WEEKDAYS[Clock.weekday()].to_lower()
	var m := Clock.minute_of_day()
	var o := Clock.parse_hm(h.get("open", "00:00"))
	var c := Clock.parse_hm(h.get("close", "24:00"))
	var day_ok := days == "all" or wd in days.split(",")
	if day_ok and m >= o and m < c:
		return {"open": true}
	var dtxt := "daily" if days == "all" else ("Mon–Fri" if days == "mon,tue,wed,thu,fri" else days.replace(",", "/"))
	return {"open": false, "reason": I18n.t("%s is closed. Open %s–%s, %s.") % [b.get("name", bid), h.get("open", ""), h.get("close", ""), dtxt]}


func enter_building(bid: String) -> void:
	if transitioning:
		return
	var st := building_open(bid)
	if not st["open"]:
		EventBus.notify.emit(st["reason"], "warn", "lock")
		var ws := world_scene()
		if ws and ws.player:
			ws.player.position.y += 10
		return
	_fade(func(): _enter("interior", bid, "door", "up"))


func exit_building(bid: String) -> void:
	if transitioning:
		return
	var district: String = DataDB.building(bid)["district"]
	_fade(func(): _enter("district", district, "door_" + bid, "down"), 1)


func walk_to_district(to: String, spawn: String, minutes: int) -> void:
	if transitioning:
		return
	EventBus.notify.emit(I18n.t("Walking to %s… (%d min)") % [I18n.t(DataDB.districts[to]["name"]), minutes], "info", "walk")
	_fade(func(): _enter("district", to, spawn, ""), minutes)


func metro_travel(to_district: String, minutes: int, fare: float) -> void:
	Ledger.expense("player", "transport", fare, I18n.t("Metro fare to %s") % I18n.t(DataDB.districts[to_district]["name"]), {"type": "metro"})
	GameState.inc_stat("metro_rides")
	_fade(func(): _enter("district", to_district, "metro", "down"), minutes)


func teleport_home_and_sleep() -> void:
	_fade(func(): _enter("interior", "riverside_apartment", "bed_side", "down"))


## Save support ----------------------------------------------------------------
func capture_location() -> void:
	var ws := world_scene()
	if ws != null and ws.player != null and GameState.has_game():
		GameState.data["player"]["location"] = {"kind": ws.kind, "id": ws.scene_id, "x": ws.player.position.x,
			"y": ws.player.position.y, "facing": ws.player.facing}


func restore_location() -> void:
	var loc: Dictionary = GameState.data["player"]["location"]
	UIRoot.close_all()
	_fade(func(): _enter(str(loc.get("kind", "interior")), str(loc.get("id", "riverside_apartment")), "door", str(loc.get("facing", "down")),
		Vector2(float(loc.get("x", -1)), float(loc.get("y", -1)))))


func reenter_current() -> void:
	capture_location()
	var loc: Dictionary = GameState.data["player"]["location"]
	_enter(str(loc["kind"]), str(loc["id"]), "", str(loc["facing"]), Vector2(float(loc["x"]), float(loc["y"])))
