extends RefCounted
var bot
func _init(b) -> void:bot=b
func run() -> void:
	UIRoot._suppress_decisions = true
	Help.auto = false
	GameState.new_game({"name":"Alex Chen","seed":151})
	Clock.clear_pauses()
	Clock.world_active = false
	GameState.data["tutorial"] = {"v":3,"off":true,"seen":{}}
	SceneRouter._enter("interior", Living.home_building(), Living.home_bed(), "down")
	UIRoot.set_hud_visible(true)
	for chapter in [1,7,24]:
		GameState.data["story"]["chapter"] = str(StoryEngine.chapters()[chapter-1]["id"])
		UIRoot.open_modal(CompanyOS.new("home_laptop"))
		await bot.wait(0.5)
		await bot.shot("os_ch%d" % chapter)
		UIRoot.close_all()
		UIRoot.phone.open()
		await bot.wait(0.3)
		await bot.shot("phone_ch%d" % chapter)
		UIRoot.phone.close()
