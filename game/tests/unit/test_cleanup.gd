extends RefCounted
var runner
const Fixtures = preload("res://tests/helpers/minigame_practice_fixture.gd")

class HistoryProbe extends MiniGame:
	var id := ""
	func tutorial_id() -> String: return id

func frames(n := 4) -> void:
	for i in n: await UIRoot.get_tree().process_frame

func test_six_histories_backfill_without_overwriting_explicit_entries() -> void:
	GameState.data["minigame_tutorials_seen"] = {"pack_game":false}
	GameState.data["automotive"] = {"lots":{"old":{"leader":"player"}}}
	GameState.data["ecommerce"]["orders"] = {"old":{"status":"shipped"}}
	GameState.data["ecommerce"]["listings"] = {"old":{"photo":"self"}}
	GameState.data["logistics"] = {"history":[{"id":"old"}]}
	GameState.data["fundraising"] = {"deals":{"old":{"deck_at":1}}}
	GameState.data["popup"] = {"history":[{"id":"old"}]}
	MiniGame.backfill_tutorials_seen()
	for id in MiniGame.LEGACY_OPTIONAL:
		runner.eq(GameState.data["minigame_tutorials_seen"].get(id), id != "pack_game", "history/explicit choice: " + id)
	runner.check(Ledger.check_balanced(), "backfill does not touch ledger")

func test_real_historical_fixtures_never_force_six_uncertain_lessons() -> void:
	MiniGames.auto = -1.0
	for name in DirAccess.get_files_at("res://tests/fixtures/saves"):
		if not name.ends_with(".cvsave"): continue
		var decoded := SaveSystem.validate_text(FileAccess.get_file_as_string("res://tests/fixtures/saves/" + name))
		runner.check(decoded["ok"], name + " validates")
		if not decoded["ok"]: continue
		GameState.data = decoded["payload"]["data"]
		MiniGame.backfill_tutorials_seen()
		for id in MiniGame.LEGACY_OPTIONAL:
			var game := HistoryProbe.new()
			game.id = id
			runner.check(not game.auto_practice_due(), name + ": optional " + id)
			game.free()
		runner.check(Ledger.check_balanced(), name + " keeps ledger balanced")

func test_new_players_still_get_first_practice_and_migration_persists() -> void:
	MiniGames.auto = -1.0
	var game := PackGame.new([])
	Preferences.values["tutorial_hints"] = true
	runner.check(game.auto_practice_due(), "new player retains first-use practice")
	GameState.data.erase("minigame_practice_version")
	GameState.data = SaveSystem._migrate(GameState.data)
	runner.check(not game.auto_practice_due(), "unknown legacy experience is optional")
	var optional: Array = GameState.data["minigame_practice_optional"].duplicate()
	GameState.data = SaveSystem._migrate(GameState.data)
	runner.eq(GameState.data["minigame_practice_optional"], optional, "migration idempotent")
	game.free()

func test_highlighted_number_key_runs_normal_callback_and_advances_once() -> void:
	MiniGames.auto = -1.0
	for game in [ParcelSortGame.new(), RouteGame.new()]:
		game.practice_only = true
		UIRoot.open_modal(game)
		await frames()
		game.start()
		await frames()
		var target := str(game.practice_target.name)
		var current: int = game.practice_step
		for i in 9:
			var key := InputEventKey.new()
			key.pressed = true
			key.keycode = KEY_1 + i
			key.physical_keycode = key.keycode
			if game.practice_key_target(key) != target:
				runner.check(game.practice_blocks_key(key), "other numeric key blocked")
				continue
			runner.check(not game.practice_blocks_key(key), "highlighted shortcut allowed")
			runner.check(game.practice_shortcut(key), "highlighted shortcut executes")
			runner.check(not game.practice_shortcut(key), "same-frame repeat cannot execute twice")
			await frames()
			if game is ParcelSortGame: runner.eq(game.practice_step, current + 1, "sorting advances once")
			else: runner.eq(game.order.size(), 1, "route records exactly one stop")
			break
		game.close()
		await frames()

func test_weekly_forecast_matches_actual_bill_boundary_and_manual_due_dates() -> void:
	Clock.advance_to(5 * Clock.DAY + 23 * 60)
	var cost := Living.daily_living() * 7.0
	var forecast := Forecast.weekly("player", 2)
	runner.eq(Living.next_living_bill_at(), 6 * Clock.DAY, "next issue at day-index seven midnight")
	runner.eq(forecast["rows"][0]["items"].get("Living costs", 0), -cost, "one weekly bill in first week")
	var cash := Ledger.cash("player")
	Clock.advance(60)
	runner.eq(cash - Ledger.cash("player"), cost, "actual auto-paid bill matches forecast")
	AssistantPolicy.set_task("bills", false)
	Clock.advance(7 * Clock.DAY)
	var unpaid := AssistantPolicy.unpaid("player")
	runner.check(not unpaid.is_empty(), "manual bill issued")
	var bill: Dictionary = AssistantPolicy.S()["bills"][unpaid.back()]
	forecast = Forecast.weekly("player", 3)
	var found := false
	for row in forecast["rows"]:
		if int(bill["due"]) >= int(row["start"]) and int(bill["due"]) < int(row["start"]) + 7 * Clock.DAY:
			found = true
			runner.check(float(row["items"].get("Bills due", 0)) <= -float(bill["amount"]), "unpaid bill appears on saved due date")
	runner.check(found and Ledger.check_balanced(), "forecast retains real bill and balanced books")

func test_retired_phone_arrival_hook_cannot_launch_reply_dialogue() -> void:
	var methods: Array = load("res://scripts/sim/phone_messages.gd").get_script_method_list()
	runner.check(not methods.any(func(m): return m["name"] == "check_arrival"), "retired arrival hook removed")
	TrafficSafety.shift_soft_deadlines(Clock.DAY)
	runner.check(PhoneMessages.S()["agenda"].is_empty(), "hospital recovery does not create appointments")
