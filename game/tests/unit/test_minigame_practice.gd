extends RefCounted
var runner
const Fixtures = preload("res://tests/helpers/minigame_practice_fixture.gd")

func frames(n := 3) -> void:
	for i in n: await UIRoot.get_tree().process_frame

func test_every_minigame_requires_tutorial_data() -> void:
	var data: Dictionary = DataDB._read("res://data/help/minigame_tutorials.json")
	var dir := DirAccess.open("res://scripts/ui/minigames")
	var count := 0
	for file in dir.get_files():
		if not file.ends_with(".gd"): continue
		var text := FileAccess.get_file_as_string("res://scripts/ui/minigames/" + file)
		if not text.contains("extends MiniGame"): continue
		count += 1
		var id := file.get_basename()
		runner.check(data.has(id), id + " has a lesson; future games must add one")
		if not data.has(id): continue
		runner.check(not data[id]["steps"].is_empty(), id + " has actionable steps")
		for step in data[id]["steps"]:
			runner.check(step.has("target") and step.has("text") and step.has("condition"), id + " step is complete")
	runner.check(count >= 15, "all current classes enumerated; future games require matching data")

func test_first_second_skip_and_header_replay_preserve_active_work() -> void:
	MiniGames.auto = -1.0
	GameState.data.erase("minigame_tutorials_seen") # old saves lazily gain this key
	var game := BaristaGame.new()
	var before := Ledger.cash("player")
	UIRoot.open_modal(game)
	await frames(5)
	var practice: MiniGame = UIRoot.top_modal()
	runner.check(practice != game and practice.practice_only, "first open automatically offers safe practice")
	practice.skip_practice()
	await frames()
	runner.check(game.tutorial_seen(), "skip persisted")
	game.start()
	await frames()
	var ticket := game.want.duplicate(true)
	game.find_child("PracticeHelp", true, false).pressed.emit()
	await frames()
	practice = UIRoot.top_modal()
	runner.check(practice.practice_only and practice != game, "header ? opens separate practice")
	var frozen_age := float(game.want["age"])
	await frames(10)
	runner.eq(game.want["age"], frozen_age, "active work timer freezes throughout replay")
	practice.skip_practice()
	await frames()
	var resumed_ticket := game.want.duplicate(true)
	resumed_ticket.erase("age")
	ticket.erase("age")
	runner.eq(resumed_ticket, ticket, "active ticket survives replay")
	runner.eq(Ledger.cash("player"), before, "skip/replay never pays")
	game.close()
	await frames()
	var second := BaristaGame.new()
	UIRoot.open_modal(second)
	await frames(5)
	runner.check(UIRoot.top_modal() == second and second.phase == "intro", "second open goes directly to compact card")
	second.close()
	await frames()

func test_all_lessons_complete_without_callbacks_money_or_ratings() -> void:
	MiniGames.auto = -1.0
	var games := Fixtures.games()
	for original in games:
		var before := GameState.data.duplicate(true)
		var copy: MiniGame = original.practice_copy()
		var called := []
		copy.on_done = func(result): called.append(result)
		UIRoot.open_modal(copy)
		await frames()
		copy.start()
		await frames(5)
		copy._process(10000.0)
		var actions := 0
		for attempts in 110:
			await frames()
			if copy.phase == "practice_ready": break
			if not is_instance_valid(copy.practice_target): continue
			actions += 1
			if not Fixtures.special_input(copy) and copy.practice_target is BaseButton:
				copy.practice_target.pressed.emit()
		runner.eq(copy.phase, "practice_ready", original.tutorial_id() + " lesson completes")
		runner.check(actions > 0, "lesson requires an actual input")
		runner.eq(copy.points, 0.0, "practice never scores")
		copy.close()
		await frames()
		runner.check(called.is_empty(), "practice cannot reach income/rating callback")
		for key in ["ledger", "careers", "automotive", "media", "ecommerce", "popup"]:
			runner.eq(GameState.data.get(key), before.get(key), original.tutorial_id() + " preserves " + key)
		runner.check(Ledger.check_balanced(), "practice ledger balanced")
		original.free()

func test_seen_persists_and_legacy_save_lazily_adds_it() -> void:
	GameState.data.erase("minigame_tutorials_seen")
	var game := BaristaGame.new()
	runner.check(not game.tutorial_seen(), "old save lacking tutorial key remains playable")
	game.mark_tutorial_seen()
	runner.check(SaveSystem.save(1), "save completed lesson")
	GameState.data.erase("minigame_tutorials_seen")
	runner.check(SaveSystem.load_data(1), "load lesson state")
	runner.check(game.tutorial_seen(), "completed/skip state survives load")
	runner.check(Ledger.check_balanced(), "load keeps books balanced")
	game.free()
