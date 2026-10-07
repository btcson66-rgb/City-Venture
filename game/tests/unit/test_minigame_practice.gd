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
	Media.S() # created lazily by hourly sims; make the snapshot independent of timing
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

# ---- review fixes: one-time practice offer, old saves, no free tips, generic input lock

func _cancel_event() -> InputEventAction:
	var e := InputEventAction.new()
	e.action = "cancel"
	e.pressed = true
	return e

func test_closing_practice_by_any_route_never_forces_it_again() -> void:
	MiniGames.auto = -1.0
	Preferences.values["tutorial_hints"] = true
	for route in ["close", "cancel"]:
		GameState.data.erase("minigame_tutorials_seen")
		var game := BaristaGame.new()
		UIRoot.open_modal(game)
		await frames(5)
		var practice: MiniGame = UIRoot.top_modal()
		runner.check(practice != game and practice.practice_only, route + ": practice offered once")
		if route == "close": practice.close()
		else: practice.abort()
		await frames()
		runner.check(game.tutorial_seen(), route + ": closing marks the tutorial seen")
		game.start()
		await frames(3)
		runner.eq(game.phase, "play", route + ": start() no longer reopens practice")
		game.close()
		await frames()

func test_tutorial_hints_off_never_auto_enters_practice_but_button_remains() -> void:
	MiniGames.auto = -1.0
	GameState.data.erase("minigame_tutorials_seen")
	var previous = Preferences.values["tutorial_hints"]
	Preferences.values["tutorial_hints"] = false
	var game := BaristaGame.new()
	UIRoot.open_modal(game)
	await frames(5)
	runner.check(UIRoot.top_modal() == game, "hints off: no auto practice on open")
	game.start()
	await frames(3)
	runner.eq(game.phase, "play", "hints off: start goes straight to work")
	runner.check(game.find_child("PracticeHelp", true, false) != null, "? still offers practice")
	game.close()
	await frames()
	Preferences.values["tutorial_hints"] = previous

func test_old_save_with_work_history_counts_as_seen() -> void:
	var saved_careers: Dictionary = Careers.C().duplicate(true)
	var saved_seen = GameState.data.get("minigame_tutorials_seen")
	GameState.data.erase("minigame_tutorials_seen")
	Careers.C()["shifts"] = {"barista": 3, "city_clerk": 0}
	MiniGame.backfill_tutorials_seen()
	var barista := BaristaGame.new()
	var clerk := ClerkFormsGame.new()
	var typing := TypingGame.new("freelance", "", 2, "x")
	runner.check(barista.tutorial_seen(), "worked barista shifts: tutorial seen")
	runner.check(not clerk.tutorial_seen(), "never worked clerk: still new")
	runner.check(not typing.tutorial_seen(), "no freelance yet")
	Careers.C()["shifts"] = {}
	Careers.C()["freelance"]["done"] = 2
	MiniGame.backfill_tutorials_seen()
	runner.check(typing.tutorial_seen(), "freelance history counts for typing")
	GameState.data["careers"] = saved_careers
	if saved_seen == null: GameState.data.erase("minigame_tutorials_seen")
	else: GameState.data["minigame_tutorials_seen"] = saved_seen
	for g in [barista, clerk, typing]: g.free()

func test_untimed_games_hide_challenge_and_never_pay_tips() -> void:
	MiniGames.auto = -1.0
	var previous = Preferences.values["tutorial_hints"]
	Preferences.values["tutorial_hints"] = false
	var clerk := ClerkFormsGame.new()
	runner.check(not clerk.has_clock(), "forms game has no clock")
	clerk.work_mode = 1
	runner.check(clerk.relaxed() and not clerk.challenge_time_ok(), "challenge selection is ignored without a clock")
	UIRoot.open_modal(clerk)
	await frames(3)
	runner.check(clerk.find_child("WorkMode", true, false) == null, "selector hidden for untimed game")
	clerk.phase = "play"
	clerk.award(1.0)
	runner.eq(clerk.challenge_tips, 0.0, "no free challenge tip")
	clerk.close()
	await frames()
	var parcels := ParcelSortGame.new()
	parcels.work_mode = 1
	runner.check(parcels.has_clock() and not parcels.relaxed(), "timed tip job keeps Challenge")
	UIRoot.open_modal(parcels)
	await frames(3)
	runner.check(parcels.find_child("WorkMode", true, false) != null, "selector shown for timed game")
	parcels.close()
	await frames()
	Preferences.values["tutorial_hints"] = previous

func test_practice_swallows_other_game_shortcuts() -> void:
	var game := ParcelSortGame.new()
	game.practice_only = true
	game.phase = "play"
	var pick := InputEventKey.new()
	pick.keycode = KEY_1
	pick.physical_keycode = KEY_1
	pick.pressed = true
	runner.check(InputMap.has_action("pick_1") and pick.is_action_pressed("pick_1"), "test key maps to pick_1")
	runner.check(game.practice_blocks_key(pick), "pick_N shortcuts are blocked in practice")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	enter.pressed = true
	runner.check(game.practice_blocks_key(enter), "Enter cannot activate a non-highlighted control")
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	runner.check(not game.practice_blocks_key(esc), "Esc still leaves practice")
	game.practice_only = false
	runner.check(not game.practice_blocks_key(pick), "real work keeps its shortcuts")
	game.free()

func test_hud_health_count_is_never_zero_when_shown() -> void:
	var s := TrafficSafety.S()
	var saved := s.duplicate(true)
	s["accidents"] = []
	s["injury"] = "none"
	runner.eq(HUD.safety_count(), 0, "nothing actionable: count 0 (button hidden)")
	s["injury"] = "minor"
	runner.eq(HUD.safety_count(), 1, "injury with no bill shows at least 1")
	s["injury"] = "none"
	s["accidents"] = [{"debt": 50.0, "counterparty_fault": false, "treated": true, "settled": false}]
	runner.eq(HUD.safety_count(), 1, "open bill counts")
	GameState.data["traffic_safety"] = saved
