extends RefCounted
var runner


func _at(day: int, minute: int) -> void:
	GameState.data["clock"]["minutes"] = day * Clock.DAY + minute


func test_first_closed_tutorial_prompt_names_opening_time() -> void:
	_at(1, 22 * 60)
	var step: Dictionary = Tutorial.STEPS[Tutorial._index("coffee")]
	var text := DestinationHours.target_text(step)
	runner.check(text.contains("tomorrow") and text.contains("07:00"), "first instruction includes actual next opening")


func test_open_until_and_exclusive_close() -> void:
	_at(1, 16 * 60)
	runner.check(DestinationHours.status("city_hall")["text"].contains("17:00"), "closing time from data")
	_at(1, 17 * 60)
	runner.check(not DestinationHours.status("city_hall")["open"], "closed at exact end")
	runner.eq(DestinationHours.status("city_hall")["next"], 2 * Clock.DAY + 9 * 60, "next weekday opening")


func test_weekend_wait_is_monday_and_read_only() -> void:
	_at(5, 18 * 60) # Friday, June 6.
	var before := Clock.now()
	var state := DestinationHours.status("city_hall")
	runner.eq(state["next"], 8 * Clock.DAY + 9 * 60, "Monday, never Saturday")
	runner.eq(Clock.now(), before, "queries do not advance time")
	runner.check(not str(state["text"]).contains("tomorrow"), "does not claim tomorrow on a Friday")


func test_npc_schedule_intersects_building_hours() -> void:
	_at(1, 10 * 60)
	var state := DestinationHours.status("nexus_bank", "marcus")
	runner.check(not state["open"], "bank open does not mean Marcus is here")
	runner.eq(state["next"], Clock.DAY + 13 * 60, "Marcus arrives at 13:00")
	_at(1, 14 * 60)
	runner.check(DestinationHours.status("nexus_bank", "marcus")["text"].contains("16:00"), "Marcus leaves before building closes")


func test_hours_are_data_driven_and_unknown_is_not_open() -> void:
	_at(1, 6 * 60)
	var b := DataDB.building("bloom_coffee")
	var original: Dictionary = b["hours"].duplicate(true)
	b["hours"]["open"] = "08:15"
	runner.eq(DestinationHours.status("bloom_coffee")["next"], Clock.DAY + 8 * 60 + 15, "changed schedule, no hard-coded hours")
	b["hours"] = original
	runner.eq(DestinationHours.status("missing_building")["next"], -1, "unknown destination cannot fast-forward")


func test_private_home_and_old_save_need_no_new_state() -> void:
	_at(1, 23 * 60)
	var old := GameState.data.duplicate(true)
	runner.check(DestinationHours.status("riverside_apartment")["open"], "home remains accessible at night")
	GameState.data = SaveSystem._migrate(JSON.parse_string(JSON.stringify(old)))
	runner.check(DestinationHours.status("riverside_apartment")["open"], "old save needs no new keys")


func test_wait_rechecks_and_simulates_time() -> void:
	_at(1, 6 * 60 + 59)
	DestinationHours.wait_until_open("bloom_coffee")
	runner.eq(Clock.now(), Clock.DAY + 7 * 60, "advances to actual opening")
	DestinationHours.wait_until_open("bloom_coffee")
	runner.eq(Clock.now(), Clock.DAY + 7 * 60, "already open is a no-op")
	runner.check(Ledger.check_balanced(), "normal simulation preserves books")
