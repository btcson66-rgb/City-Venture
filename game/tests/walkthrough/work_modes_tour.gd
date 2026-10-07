extends RefCounted
var bot
func _init(b) -> void: bot = b
func run() -> void:
	if "--before-work-modes" in OS.get_cmdline_user_args():
		UIRoot._suppress_decisions = true
		MiniGames.auto = -1.0
		GameState.new_game({"name": "New player", "seed": 150})
		GameState.data["tutorial"] = {"v":3,"off":true,"seen":{}}
		SceneRouter._enter("interior", "bloom_coffee", "entry", "up")
		Clock.world_active = false
		var game := BaristaGame.new()
		game.mark_tutorial_seen()
		UIRoot.open_modal(game)
		await bot.wait(0.2)
		await bot.click_named("StartGame")
		await bot.shot("barista_before_wait")
		for i in 6: game._process(10000.0)
		await bot.wait(0.2)
		await bot.shot("barista_after_wait")
		bot.expect(game.phase == "play" and game.round_i == 0, "waiting preserves the shift")
		game.close()
		return
	await load("res://tests/walkthrough/practice_tour.gd").new(bot).run()
	var settings := SettingsModal.new()
	settings.page = 4
	UIRoot.open_modal(settings)
	await bot.wait(0.2)
	await bot.shot("default_work_mode_settings")
	var selected := settings.find_child("Setting_work_mode", true, false) as OptionButton
	selected.select(1)
	selected.item_selected.emit(1)
	await bot.wait(0.2)
	Preferences.load_settings()
	bot.expect(Preferences.values["work_mode"] == 1, "chosen default survives settings reload")
	await bot.shot("challenge_default_saved")
	settings.close()
	await bot.wait(0.2)
	var challenge := BaristaGame.new()
	challenge.mark_tutorial_seen()
	UIRoot.open_modal(challenge)
	await bot.wait(0.2)
	await bot.shot("challenge_start_card")
	await bot.click_named("StartGame")
	await bot.shot("challenge_optional_clock")
	await bot.click_named("ConfirmOrder")
	for pair in [["Size", challenge.want["size"]], ["Drink", challenge.want["drink"]], ["Milk", challenge.want["milk"]], ["Shots", challenge.want["shots"]]]:
		await bot.click_named("%s_%s" % pair)
	await bot.click_named("Serve")
	await bot.click_named("Deliver_%d" % int(challenge.want["destination"]))
	await bot.click_named("CleanTable")
	bot.expect(challenge.points == 1.0 and challenge.tips == 2.0 and challenge.challenge_tips == 0.5, "challenge earns normal quality/tips plus optional bonus")
	await bot.shot("challenge_tip_feedback")
	challenge._process(100000.0)
	bot.expect(challenge.round_i == 1 and challenge.queue.size() == 3, "expired challenge bonus keeps the remaining guests")
	await bot.shot("challenge_bonus_expired_guests_still_wait")
	challenge.close()
	Preferences.set_value("work_mode", 0)
