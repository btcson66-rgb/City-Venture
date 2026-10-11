extends RefCounted
## Matching upper/lower street sections and real ambient movement in an isolated save.
var bot
func _init(b) -> void: bot = b
func run() -> void:
	Preferences.path = bot.out_dir.path_join("settings.cfg")
	Preferences.values = Preferences.DEFAULTS.duplicate(true)
	Preferences.apply()
	UIRoot.close_all()
	UIRoot._suppress_decisions = true
	SaveSystem.DIR = bot.out_dir.path_join("saves_" + str(OS.get_process_id()))
	if not bot.expect(GameState.new_game({"name":"District review", "seed":179}), "fresh isolated QA game created"): return
	GameState.data["tutorial"] = {"v":3, "off":true, "seen":{}}
	var motion: Array = []
	for id in DataDB.districts:
		SceneRouter._enter("district", id, "metro", "down")
		await bot.wait(0.25)
		Clock.world_active = false
		var world := SceneRouter.world_scene() as District
		world.player.collision_layer = 0
		world.player.input_enabled = false
		world.player.camera.position_smoothing_enabled = false
		UIRoot.set_hud_visible(false)
		for card in bot.get_tree().get_nodes_in_group("location_card"): card.queue_free()
		for y in [350, 590]:
			for x in range(240, world.size_px.x, 480):
				world.player.position = Vector2(x, y)
				await bot.wait(0.15)
				await bot.shot(id + ("_frontage_" if y == 350 else "_park_") + str(x))
		var actors: Array = world.cars + world.peds
		var positions: Array = []
		for actor in actors: positions.append(actor.position)
		await bot.wait(1.0)
		var moved := 0
		var cells := {}
		for i in actors.size():
			if actors[i].position.distance_to(positions[i]) > 2.0:
				moved += 1
				cells[int(positions[i].x) / 480] = true
		bot.expect(moved > 0, id + " has rendered moving street life")
		motion.append({"district":id, "cars":world.cars.size(), "pedestrians":world.peds.size(), "moved_in_one_second":moved, "moving_sections":cells.keys()})
	UIRoot.set_hud_visible(true)
	bot.expect(Ledger.check_balanced(), "scenery capture leaves ledger balanced")
	var file := FileAccess.open(bot.out_dir.path_join("motion.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(motion, "\t"))
