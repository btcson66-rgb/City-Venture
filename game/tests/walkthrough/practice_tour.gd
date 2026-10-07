extends RefCounted
var bot
const Fixtures = preload("res://tests/helpers/minigame_practice_fixture.gd")
func _init(b) -> void: bot = b

func lesson(g: MiniGame, tag: String, every_step := false) -> void:
	await bot.click_named("StartGame")
	var first_target := true
	for attempts in 110:
		await bot.wait(0.08)
		if g.phase == "practice_ready": break
		if not is_instance_valid(g.practice_target): continue
		if every_step or first_target: await bot.shot(tag + "_step_%d" % g.practice_step)
		first_target = false
		if not Fixtures.special_input(g):
			await bot.click_named(str(g.practice_target.name), 1.0)
	bot.expect(g.phase == "practice_ready", tag + " tutorial completes")
	await bot.shot(tag + "_ready")
	await bot.click_named("StartFormalWork")
	await bot.wait(0.1)

func run() -> void:
	UIRoot.close_all()
	UIRoot._suppress_decisions = true
	Help.auto = false
	MiniGames.auto = -1.0
	InputAccess.touch_mode = "--practice-large" in OS.get_cmdline_user_args()
	Preferences.values["font_size"] = 3 if InputAccess.touch_mode else 1
	Preferences.apply()
	GameState.new_game({"name": "New player", "seed": 149})
	GameState.data["tutorial"] = {"v": 3, "off": true, "seen": {}}
	Clock.world_active = false
	Clock.advance_to(Clock.at_day_time(0, 9 * 60))
	SceneRouter._enter("interior", "bloom_coffee", "entry", "up")
	UIRoot.set_hud_visible(true)
	UIRoot.open_modal(JobModal.new("barista"))
	await bot.wait(0.2)
	await bot.shot("new_game_first_job")
	await bot.click_named("ApplyJob")
	var cash := Ledger.cash("player")
	await bot.click_named("WorkShift")
	await bot.wait(0.2)
	var practice: MiniGame = UIRoot.top_modal()
	bot.expect(practice.practice_only, "first actual work shift automatically enters practice")
	await bot.shot("barista_first_practice_card")
	await lesson(practice, "barista", true)
	bot.expect(Ledger.cash("player") == cash and Careers.shifts("barista") == 0, "practice changes no pay or promotion")
	var work: BaristaGame = UIRoot.top_modal()
	bot.expect(work.phase == "play" and not work.practice_only, "ready button naturally starts formal shift")
	await bot.shot("barista_formal_start")
	for i in 6:
		await bot.click_named("ConfirmOrder")
		for pair in [["Size", work.want["size"]], ["Drink", work.want["drink"]], ["Milk", work.want["milk"]], ["Shots", work.want["shots"]]]:
			await bot.click_named("%s_%s" % pair)
		await bot.click_named("Serve")
		await bot.click_named("Deliver_%d" % int(work.want["destination"]))
		await bot.click_named("CleanTable")
	await bot.shot("barista_formal_results")
	bot.expect(work.points == 6.0, "all six formal orders complete")
	await bot.click_named("FinishGame")
	await bot.wait(0.8)
	bot.expect(Careers.shifts("barista") == 1 and Ledger.cash("player") > cash, "formal shift pays and counts")
	await bot.shot("barista_real_payout")
	UIRoot.close_all()
	var experienced := BaristaGame.new()
	UIRoot.open_modal(experienced)
	await bot.wait(0.2)
	bot.expect(UIRoot.top_modal() == experienced, "experienced player sees compact card without automatic practice")
	await bot.shot("experienced_compact_card")
	await bot.click_named("PracticeHelp")
	await bot.wait(0.2)
	bot.expect((UIRoot.top_modal() as MiniGame).practice_only, "experienced player can replay with ?")
	await bot.shot("experienced_replay")
	await bot.click_named("SkipPractice")
	await bot.wait(0.2)
	bot.expect(UIRoot.top_modal() == experienced, "skip returns to original work")
	experienced.close()
	await bot.wait(0.2)
	var games := Fixtures.games()
	for original in games:
		var copy: MiniGame = original.practice_copy()
		var tag: String = original.tutorial_key().replace(":", "_")
		var ledger_before: Variant = GameState.data["ledger"].duplicate(true)
		UIRoot.open_modal(copy)
		await bot.wait(0.2)
		await bot.shot(tag + "_card")
		await lesson(copy, tag)
		bot.expect(GameState.data["ledger"] == ledger_before, tag + " practice preserves ledger")
		original.free()
	bot.expect(Ledger.check_balanced(), "tour ledger balanced")
