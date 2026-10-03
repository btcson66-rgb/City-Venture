extends RefCounted
var bot

func _init(b) -> void:
	bot = b

func route() -> Array:
	var pending: Dictionary = DataDB.city["adjacency"].duplicate(true)
	var stack: Array = ["riverside"]
	var result: Array = []
	while not stack.is_empty():
		var a := str(stack[-1])
		if pending[a].is_empty(): result.push_front(stack.pop_back())
		else:
			var b := str(pending[a].keys()[0])
			pending[a].erase(b)
			stack.append(b)
	return result

func run() -> void:
	UIRoot.close_all()
	UIRoot._suppress_decisions = true
	Help.auto = false
	bot.popup_handler = Callable()
	GameState.new_game({"name": "Alex Chen", "seed": 111})
	GameState.data["tutorial"] = {"v": 3, "off": true, "seen": {}}
	Clock.clear_pauses()
	Clock.world_active = false
	SceneRouter._enter("district", "riverside", "from_startup_hub", "left")
	UIRoot.set_hud_visible(true)
	await bot.wait(0.5)
	UIRoot.open_modal(CityMapModal.new(false))
	await bot.wait(0.5)
	await bot.click_named("ToggleWalkingRoutes")
	await bot.wait(0.5)
	bot.expect(UIRoot.top_modal().walking, "actual button opens walking diagram")
	await bot.shot("city_walking_connections")
	UIRoot.close_all()
	var itinerary := route()
	bot.expect(itinerary.size() == 41, "Euler circuit includes every directed walking link")
	var screenshots := {}
	for i in range(1, itinerary.size()):
		var a := str(itinerary[i - 1])
		var b := str(itinerary[i])
		bot.step("Walking " + a + " > " + b)
		var world := SceneRouter.world_scene() as District
		if world == null or world.scene_id != a: bot.fail("Wrong source district: " + a); return
		var exits: Array = world.def["exits"].filter(func(e): return e["to"] == b)
		if exits.size() != 1: bot.fail("Missing unique exit to " + b); return
		var ex: Dictionary = exits[0]
		var r: Array = ex["rect"]
		var target := Vector2(float(r[0]) + float(r[2]) / 2, float(r[1]) + float(r[3]) / 2)
		var side := str(ex["direction"])
		var inward: Vector2 = {"N": Vector2.DOWN, "E": Vector2.LEFT, "S": Vector2.UP, "W": Vector2.RIGHT}[side]
		await bot.walk_to(target + inward * 80, 5.0, 60.0)
		if not screenshots.has(side):
			await bot.shot("exit_sign_" + side + "_" + a)
			screenshots[side] = true
		await bot.walk_to(target, 3.0, 60.0)
		var arrived: bool = await bot.until(func(): return SceneRouter.world_scene().scene_id == b and not SceneRouter.transitioning, 8.0)
		bot.expect(arrived, "actual walking transition to " + b)
		if not arrived:
			bot.log_line("Actual destination: " + SceneRouter.world_scene().scene_id)
			await bot.shot("failed_exit_" + a + "_" + b)
			return
		await bot.wait(0.5)
		bot.expect(SceneRouter.world_scene().scene_id == b, "arrival does not retrigger a return")
		if "--signs-only" in OS.get_cmdline_user_args() and screenshots.size() == 4: return
	bot.expect(Ledger.check_balanced(), "all walking time preserves ledger")
