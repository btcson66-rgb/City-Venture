extends RefCounted
var runner
const Fixtures = preload("res://tests/helpers/minigame_practice_fixture.gd")
func frames(n := 3) -> void:
	for i in n: await UIRoot.get_tree().process_frame

func test_all_games_tolerate_unlimited_relaxed_waiting() -> void:
	Media.S() # created lazily by hourly sims; make the snapshot independent of timing
	for game in Fixtures.games():
		game.work_mode = 0
		game.mark_tutorial_seen()
		UIRoot.open_modal(game)
		await frames()
		game.start()
		await frames()
		var before := GameState.data.duplicate(true)
		var round_before: int = game.round_i
		var points_before: float = game.points
		var queue_before: Variant = game.get("queue").duplicate(true) if game is BaristaGame else null
		var focus_before: float = game.needle() if game is PhotoShootGame else 0.0
		game._process(100000000.0)
		await frames()
		runner.eq(game.round_i, round_before, game.tutorial_id() + " never expires")
		runner.eq(game.points, points_before, "waiting never loses points")
		runner.check(not game._timer_bar.visible, "no default countdown")
		if game is BaristaGame: runner.eq(game.queue, queue_before, "all guests wait")
		if game is PhotoShootGame: runner.eq(game.needle(), focus_before, "focus stays centred")
		for key in ["ledger", "careers", "automotive", "media", "popup"]:
			runner.eq(GameState.data.get(key), before.get(key), "waiting cannot alter " + key)
		game.close()
		await frames()
	runner.check(Ledger.check_balanced(), "all waits balanced")

func test_same_base_wage_and_review_challenge_adds_only_tips() -> void:
	var results := []
	for mode in [0, 1]:
		var game := BaristaGame.new()
		game.work_mode = mode
		game.mark_tutorial_seen()
		UIRoot.open_modal(game)
		await frames()
		game.start()
		for i in game.rounds:
			game._confirm()
			for key in ["size", "drink", "milk", "shots"]: game.got[key] = game.want[key]
			game._serve()
			game._deliver(int(game.want["destination"]))
			game._clean()
		results.append({"score":game.score(), "tips":game.tips, "bonus":game.challenge_tips, "review":game.extra_result()["manager_rating"]})
		game.close()
		await frames()
	runner.eq(results[0]["score"], results[1]["score"], "same performance score")
	runner.eq(results[0]["review"], results[1]["review"], "same manager review/promotion quality")
	runner.eq(Careers.pay_for("barista", results[0]["score"]), Careers.pay_for("barista", results[1]["score"]), "same normal wages")
	runner.eq(results[0]["tips"], results[1]["tips"], "normal tips also equal")
	runner.eq(results[0]["tips"], float(FunLoop.cfg()["barista_early_rounds"]) * float(MiniGame.mode_cfg()["normal_barista_tip"]), "normal tips follow actual guests in the shorter entry shift")
	runner.eq(results[0]["bonus"], 0.0, "relaxed is normal pay")
	runner.check(results[1]["bonus"] > 0.0, "challenge earns extra tips only")

func test_wrong_drink_and_destination_are_recoverable_same_order() -> void:
	var game := BaristaGame.new()
	game.work_mode = 0
	game.mark_tutorial_seen()
	UIRoot.open_modal(game)
	await frames()
	game.start()
	game._confirm()
	var id: int = game.want["id"]
	for key in ["size", "drink", "milk", "shots"]: game.got[key] = game.want[key]
	game.got["shots"] = "1" if game.want["shots"] == "2" else "2"
	game._serve()
	runner.eq(game.want["station"], "make", "retry this same cup")
	runner.eq(game.want["id"], id, "no order is discarded")
	game.got["shots"] = game.want["shots"]
	game._serve()
	game._deliver((int(game.want["destination"]) + 1) % 3)
	runner.eq(game.want["station"], "deliver", "wrong delivery retries in place")
	game._deliver(int(game.want["destination"]))
	game._clean()
	runner.eq(game.points, 1.0, "recovered order earns normal quality")
	runner.eq(game.tips, 2.0 - float(MiniGame.mode_cfg()["retry_tip_reduction"]), "only one small tip reduction")
	game.close()
	await frames()

func test_expired_challenge_preserves_quality_wages_and_guests() -> void:
	var game := BaristaGame.new()
	game.work_mode = 1
	game.mark_tutorial_seen()
	UIRoot.open_modal(game)
	await frames()
	game.start()
	game._process(100000.0)
	game._confirm()
	for key in ["size", "drink", "milk", "shots"]: game.got[key] = game.want[key]
	game._serve()
	game._deliver(int(game.want["destination"]))
	game._clean()
	runner.eq(game.points, 1.0, "late service retains quality")
	runner.eq(game.challenge_tips, 0.0, "only optional bonus expires")
	runner.eq(game.tips, 2.0, "late service keeps normal tips")
	game.close()
	await frames()

func test_default_mode_settings_persist_and_old_preferences_relax() -> void:
	var old_path := Preferences.path
	var old_values := Preferences.values.duplicate(true)
	Preferences.path = SaveSystem.DIR.path_join("work_mode.cfg")
	DirAccess.make_dir_recursive_absolute(Preferences.path.get_base_dir())
	Preferences.load_settings()
	runner.eq(Preferences.values["work_mode"], 0, "old/missing preference defaults to relaxed")
	runner.eq(Preferences.set_value("work_mode", 1), OK, "save default")
	Preferences.values["work_mode"] = 0
	Preferences.load_settings()
	runner.eq(Preferences.values["work_mode"], 1, "mode survives settings reload")
	var game := BaristaGame.new()
	runner.eq(game.work_mode, 1, "new job copies the selected default")
	game.work_mode = 0
	runner.eq(Preferences.values["work_mode"], 1, "a session choice does not override device default")
	game.free()
	Preferences.path = old_path
	Preferences.values = old_values
