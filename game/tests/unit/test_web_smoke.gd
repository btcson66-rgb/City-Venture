extends RefCounted
var runner

func test_release_browser_probe_parses() -> void:
	# This opt-in script is loaded only in Web releases; editor import alone does not compile it.
	var script: GDScript = load("res://scripts/qa/web_smoke_probe.gd")
	runner.check(script.can_instantiate(), "release-only browser probe compiles")
	if script.can_instantiate():
		var probe: Node = script.new()
		probe.free()

func test_interior_decoration_does_not_swallow_touch_navigation() -> void:
	GameState.new_game({"name": "Touch regression", "seed": 167})
	var room := Interior.new()
	room.build("riverside_apartment")
	_check_decoration(room)
	room.free()

func _check_decoration(node: Node) -> void:
	if node is ColorRect:
		runner.eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE, "world decoration passes touch to navigation")
	for child in node.get_children():
		_check_decoration(child)
func test_touch_enters_home_using_normal_physics_and_door_trigger() -> void:
	UIRoot.close_all()
	Help.auto = false
	UIRoot.tutorial.st()["off"] = true
	Clock.clear_pauses()
	SceneRouter._enter("district", "riverside", "door_riverside_apartment", "down")
	for i in 3: await runner.get_tree().process_frame
	var world := SceneRouter.world_scene()
	var before := Ledger.cash("player")
	InputAccess._walk_touch(world.player, world.spawns["door_riverside_apartment"] - Vector2(0, 20))
	runner.check(not world.player.click_route.is_empty(), "touch creates a physical walking route")
	await runner.get_tree().create_timer(2.0).timeout
	runner.eq(SceneRouter.world_scene().scene_id, "riverside_apartment", "touch reaches the doorway trigger")
	runner.eq(Ledger.cash("player"), before, "navigation does not change cash")
	SceneRouter._set_scene(Node.new())
	Clock.world_active = false
	UIRoot.set_hud_visible(false)
func test_locked_web_audio_does_not_start_an_empty_layer_tween() -> void:
	var old_headless := Sound._headless
	var old_unlocked := Sound._audio_unlocked
	var old_context := Sound._context_kind
	var old_intensity := Sound._intensity
	Sound._headless = false
	Sound._audio_unlocked = false
	Sound._context_kind = ""
	Sound._intensity = -1
	Sound._process(2.0)
	runner.check(not is_instance_valid(Sound._layer_tween), "no empty tween while browser audio awaits a gesture")
	Sound._headless = old_headless
	Sound._audio_unlocked = old_unlocked
	Sound._context_kind = old_context
	Sound._intensity = old_intensity