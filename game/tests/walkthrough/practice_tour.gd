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
	Preferences.values["work_mode"] = 0
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
	if "--slow-work" in OS.get_cmdline_user_args():
		await bot.wait(65.0) # A real wait longer than the former 60-second patience.
		work._process(10000.0)
		bot.expect(work.round_i == 0 and work.points == 0.0 and work.queue.size() == 3, "long relaxed waiting preserves all guests and score")
		await bot.shot("barista_after_long_wait")
	for i in 6:
		if "--slow-work" in OS.get_cmdline_user_args(): await bot.wait(2.0)
		await bot.click_named("ConfirmOrder")
		for pair in [["Size", work.want["size"]], ["Drink", work.want["drink"]], ["Milk", work.want["milk"]], ["Shots", work.want["shots"]]]:
			await bot.click_named("%s_%s" % pair)
		if i == 0 and "--slow-work" in OS.get_cmdline_user_args():
			await bot.click_named("Shots_" + ("1" if work.want["shots"] == "2" else "2"))
			await bot.click_named("Serve")
			bot.expect(work.want["station"] == "make", "wrong cup remains available to redo")
			await bot.shot("barista_gentle_retry")
			await bot.click_named("Shots_" + str(work.want["shots"]))
		await bot.click_named("Serve")
		await bot.click_named("Deliver_%d" % int(work.want["destination"]))
		await bot.click_named("CleanTable")
	await bot.shot("barista_formal_results")
	bot.expect(work.points == 6.0, "all six formal orders complete")
	var expected_pay := Careers.pay_for("barista", 1.0, Careers.shift_hours_now("barista")) + work.tips
	var shift_minutes := Careers.shift_hours_now("barista") * 60
	var before_payout := Clock.now()
	await bot.click_named("FinishGame")
	await bot.wait(0.8)
	bot.expect(Careers.shifts("barista") == 1 and Ledger.cash("player") > cash, "formal shift pays and counts")
	bot.expect(is_equal_approx(Ledger.cash("player") - cash, expected_pay), "full normal wage and normal tips paid: " + Fmt.money(expected_pay))
	# The ordinary world clock resumes after the result modal closes (fade and payout toast).
	var elapsed := Clock.now() - before_payout
	bot.expect(elapsed >= shift_minutes and elapsed <= shift_minutes + 3, "scheduled shift %d minutes; game time advanced %d" % [shift_minutes, elapsed])
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
