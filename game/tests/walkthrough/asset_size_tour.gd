extends RefCounted
## Identical fixed states for ten before/after compression samples. QA saves only.
var bot

func _init(b) -> void:
	bot = b

func run() -> void:
	Preferences.path = bot.out_dir.path_join("settings.cfg")
	Preferences.values = Preferences.DEFAULTS.duplicate(true)
	Preferences.apply()
	GameState.new_game({"name": "Asset Comparison", "seed": 166})
	GameState.data["tutorial"] = {"off": true, "step": 99, "seen": {}, "v": 99}
	UIRoot._suppress_decisions = true
	Clock.world_active = false
	UIRoot.set_hud_visible(true)
	for district in ["riverside", "harbor", "old_town"]:
		var building := str(DataDB.districts[district]["buildings"][0])
		SceneRouter._enter("district", district, "door_" + building, "down")
		await bot.wait(1.0)
		await bot.shot("size_" + district)
	for building in ["bloom_coffee", "nexus_cowork", "pier7_warehouse"]:
		SceneRouter._enter("interior", building, "door", "up")
		await bot.wait(1.0)
		await bot.shot("size_" + building)
	UIRoot.open_modal(CityMapModal.new(false))
	await bot.wait(0.5)
	await bot.shot("size_city_map")
	UIRoot.close_all()
	UIRoot.open_modal(WorldMapModal.new())
	await bot.wait(0.5)
	await bot.shot("size_world_map")
	UIRoot.close_all()
	Company.register("Comparison Co", "ecommerce", "22 Founders Lane")
	UIRoot.open_modal(CompanyOS.new("cowork"))
	await bot.wait(0.5)
	await bot.shot("size_company_os")
	UIRoot.close_all()
	SceneRouter._enter("interior", "bloom_coffee", "door", "up")
	MiniGames.auto = -1.0
	MiniGames.play(BaristaGame.new(), func(_result): pass)
	await bot.wait(0.5)
	await bot.click_named("StartGame")
	await bot.wait(0.3)
	await bot.shot("size_barista")
	UIRoot.close_all()
	bot.expect(Ledger.check_balanced(), "compression samples preserve balanced books")
