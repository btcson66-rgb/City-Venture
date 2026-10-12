extends RefCounted
## Reproducible district frontage, every exit and arrival evidence; QA saves belong to the bot.
var bot
func _init(b) -> void: bot = b
func run() -> void:
	Preferences.path = bot.out_dir.path_join("settings.cfg")
	Preferences.values = Preferences.DEFAULTS.duplicate(true)
	if "--large-text" in OS.get_cmdline_user_args(): Preferences.values["font_size"] = 3
	Preferences.apply()
	UIRoot.close_all()
	UIRoot._suppress_decisions = true
	SaveSystem.DIR = bot.out_dir.path_join("saves_" + str(OS.get_process_id()))
	if not bot.expect(GameState.new_game({"name":"Visual review", "seed":178}), "fresh isolated QA game created"): return
	GameState.data["tutorial"] = {"v":3, "off":true, "seen":{}}
	Clock.world_active = false
	var arrival := ArrivalScene.new()
	SceneRouter._set_scene(arrival)
	await bot.wait(4.0)
	await bot.shot("arrival_train")
	for id in DataDB.districts:
		SceneRouter._enter("district", id, "metro", "down")
		await bot.wait(0.3)
		Clock.world_active = false
		var world := SceneRouter.world_scene() as District
		# A framing fixture must not walk through exits or doors while positioning its camera.
		world.player.collision_layer = 0
		world.player.input_enabled = false
		world.player.camera.position_smoothing_enabled = false
		UIRoot.set_hud_visible(false)
		for card in bot.get_tree().get_nodes_in_group("location_card"): card.queue_free()
		for x in range(240, world.size_px.x, 480):
			world.player.position = Vector2(x, 350)
			await bot.wait(0.15)
			await bot.shot(id + "_frontage_" + str(x))
		UIRoot.set_hud_visible(true)
		for ex in world.def.get("exits", []):
			var r: Array = ex["rect"]
			var inward: Vector2 = {"N":Vector2.DOWN,"E":Vector2.LEFT,"S":Vector2.UP,"W":Vector2.RIGHT}[str(ex["direction"])]
			var point := Vector2(float(r[0])+float(r[2])/2, float(r[1])+float(r[3])/2)
			if str(ex["direction"]) in ["E","W"] and int(r[1]) == 324: point.y = 348
			var distance := 40 if str(ex["direction"]) == "N" and int(r[1]) == 304 else 32 if str(ex["direction"]) == "S" and int(r[1]) == 544 else 90
			world.player.position = point + inward * distance
			await bot.wait(0.2)
			await bot.shot(id + "_exit_" + str(ex["to"]))
	for bid in ["helio_supply", "helio_warehouse"]:
		SceneRouter._enter("interior", bid, "door", "up")
		await bot.wait(0.3)
		UIRoot.close_all()
		await bot.shot(bid + "_new_game")
	FeatureGate.grant("os_energy")
	for bid in ["helio_supply", "helio_warehouse"]:
		SceneRouter._enter("interior", bid, "door", "up")
		await bot.wait(0.3)
		UIRoot.close_all()
		await bot.shot(bid + "_unlocked")
		Actions.run("energy_open", {"building":bid})
		await bot.wait(0.3)
		await bot.shot(bid + "_startup_prerequisites")
		UIRoot.close_all()
	bot.expect(Company.register("Riverlight", "energy", "Helio")["ok"], "registered real QA company")
	bot._allowed["RIVERLIGHT"] = true
	bot.expect(Company.open_business_account(25000)["ok"], "funded from actual starting savings")
	bot.expect(Living.lease("helio_warehouse")["ok"], "paid real warehouse lease")
	bot.expect(Energy.start()["ok"], "actually started energy business")
	for bid in ["helio_supply", "helio_warehouse"]:
		SceneRouter._enter("interior", bid, "door", "up")
		await bot.wait(0.3)
		UIRoot.close_all()
		Actions.run("energy_open", {"building":bid})
		await bot.wait(0.3)
		await bot.shot(bid + "_operating")
		UIRoot.close_all()
	bot.expect(Ledger.check_balanced(), "visual inspection leaves ledger balanced")
