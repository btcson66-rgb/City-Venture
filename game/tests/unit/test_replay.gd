extends RefCounted

var runner


func test_framework_assets_are_included_in_settlement_wealth() -> void:
	_start("part_time_start")
	var before := Replay.net_worth()
	Ledger.post("player", "QA inherited industry assets", [{"acct": "fixed_assets", "dr": 200}, {"acct": "property_assets", "dr": 300}, {"acct": "construction_in_progress", "dr": 400}, {"acct": "equity", "cr": 900}], {"type": "opening"})
	runner.eq(Replay.net_worth(), before + 900, "framework asset books count once")
	runner.check(Ledger.check_balanced(), "inherited asset journal balances")


func test_property_income_uses_jobs_and_real_estate_segment() -> void:
	_start("family_property")
	Clock.advance(90 * Clock.DAY)
	var rents: Array = Jobs.S()["items"].values().filter(func(job): return job.has("property"))
	runner.check(not rents.is_empty(), "occupied months have rental contracts")
	for job in rents:
		runner.check(job["status"] == "paid" and job["segment"] == "real_estate" and job["client"] in RealEstate.cfg()["tenant_names"], "named tenant, real invoice/payment, registered segment")
	var count := rents.size()
	GameState.data = JSON.parse_string(JSON.stringify(GameState.data))
	Replay.on_hour(Clock.now(), 9)
	runner.eq(Jobs.S()["items"].size(), count, "restored period cannot collect twice")
	var segments := Segments.compute("player", 0, Clock.now() + 1)
	runner.eq(segments["rows"]["real_estate"]["revenue"], -Ledger.balance("player", "revenue"), "rental receipts reach the industry report")
	runner.check(Ledger.check_balanced(), "rental invoices and receipts balance")


func _start(id: String, seed_value := 89, extra := {}) -> void:
	var options := {"difficulty": "standard", "scenario": id, "story": false}
	options.merge(extra, true)
	Clock.clear_pauses()
	Clock.world_active = false
	GameState.new_game({"name": "Replay QA", "seed": seed_value, "run": options})


func test_every_scenario_initializes_and_books_balance() -> void:
	for id in DataDB.scenarios:
		_start(id)
		runner.check(Ledger.check_balanced(), id + " opening ledger balances")
		runner.check(int(Replay.S()["deadline"]) > Clock.now(), id + " has a future deadline")
		runner.check(not Replay.story_enabled() and GameState.data["story"]["chapter"] == "", "sandbox has no main chapter")
		match id:
			"inherited_cafe":
				runner.check(Cafe.ready_to_open() and Staff.count("barista") == 1 and Bank.debt(GameState.company_id()) > 0, "café, employee and debt")
			"fresh_restart":
				runner.eq(Bank.credit(), 520, "restart credit")
				runner.eq(Bank.B()["no_loans_until"], Clock.now() + 90 * Clock.DAY, "ban expires")
			"venture_fund":
				runner.eq(GameState.data["ledger"]["journal"][0]["lines"][0]["dr"], 500000, "venture opening funds")
				runner.check(Clock.date_at(int(Replay.S()["deadline"]))["month"] == 12, "18-month calendar deadline")
			"harbor_cargo": runner.check(Logistics.has_van() and Logistics.active_jobs().size() == 2, "van and two contracts")
			"family_property": runner.check(Ledger.balance("player", "property") == 200000 and Bank.debt("player") == 150000, "property asset and mortgage")
			"part_time_start": runner.check(Ledger.cash("player") == 500 and GameState.company_id() == "", "500 without a company")


func _thirty_days(seed_value: int) -> String:
	_start("family_property", seed_value)
	Careers.hire("bank_teller")
	for day in 30:
		Clock.advance(Clock.next_time_of_day(9 * 60) - Clock.now())
		Careers.work_shift("bank_teller", 0.8)
		Clock.advance(Clock.next_time_of_day(23 * 60) - Clock.now())
	return JSON.stringify(GameState.data["ledger"]["journal"]).sha256_text()


func test_same_seed_replays_thirty_day_ledger_and_preview_does_not_consume_rng() -> void:
	var first := _thirty_days(12089)
	var second := _thirty_days(12089)
	runner.eq(first, second, "same seed, actions and rules replay 30-day journal")
	runner.check(first != _thirty_days(12090), "different seed changes rent/repair outcome")
	var state := GameState.rng.state
	var demand := Replay.demand("water_bottle")
	for preview in 20:
		runner.eq(Replay.demand("water_bottle"), demand, "preview stable")
	runner.eq(GameState.rng.state, state, "preview never advances event RNG")
	runner.check(Ledger.check_balanced(), "30-day books balance")


func test_difficulty_bounds_and_old_save_rules() -> void:
	GameState.new_game({"seed": 89})
	runner.check(not Replay.active() and Replay.story_enabled(), "old/default games retain story")
	runner.eq(Replay.demand("coffee"), 1, "old demand unaffected")
	var old_apr := Bank.apr()
	_start("", 89, {"difficulty": "hard"})
	runner.eq(Ledger.cash("player"), 15000, "hard starting cash")
	runner.check(Bank.apr() > old_apr, "rate surcharge applied")
	var custom := Replay.rules("custom", {"initial_cash": -1, "event_frequency": INF, "debt_tolerance": 900})
	runner.eq(custom["initial_cash"], 500, "cash clamped")
	runner.eq(custom["event_frequency"], 1, "nonfinite default")
	runner.eq(custom["debt_tolerance"], 2, "tolerance bounded")


func test_win_deadline_company_closure_and_board_withdrawal() -> void:
	_start("part_time_start")
	GameState.inc_stat("shifts_worked", 30)
	Ledger.post("player", "QA wages", [{"acct": "cash", "dr": 2000}, {"acct": "wages", "cr": 2000}])
	runner.eq(Replay.evaluate(), "won", "all criteria met")
	var result: Dictionary = Replay.S()["result"].duplicate(true)
	Clock.advance(24 * 60)
	runner.eq(Replay.S()["result"], result, "settlement snapshot immutable")
	_start("venture_fund")
	GameState.data["clock"]["minutes"] = int(Replay.S()["deadline"])
	var cash_before := Ledger.cash(GameState.company_id())
	runner.eq(Replay.evaluate(), "lost", "deadline fails without revenue")
	runner.check(Ledger.cash(GameState.company_id()) < cash_before, "board withdraws available capital")
	var count: int = GameState.data["ledger"]["journal"].size()
	Replay.evaluate()
	runner.eq(GameState.data["ledger"]["journal"].size(), count, "withdrawal never repeats")
	_start("inherited_cafe")
	var cid := GameState.company_id()
	GameState.data["entities"][cid]["closed"] = Clock.now()
	GameState.data["company"] = ""
	runner.eq(Replay.evaluate(), "lost", "closing the scenario company is terminal")
	runner.check(Ledger.check_balanced(), "result books balance")


func test_weekly_seed_history_dedup_and_save_round_trip() -> void:
	var week := Replay.weekly(1790908800)
	runner.eq(week, Replay.weekly(1790908800 + 3600), "same UTC week")
	runner.check(week != Replay.weekly(1790908800 + 7 * 86400), "next week changes")
	var original_path := Replay.rank_path
	Replay.rank_path = SaveSystem.DIR+"/replay_history.json"
	if FileAccess.file_exists(Replay.rank_path):
		DirAccess.remove_absolute(Replay.rank_path)
	_start("part_time_start", 89, {"week": "QA"})
	GameState.inc_stat("shifts_worked", 30)
	Ledger.post("player", "QA wages", [{"acct": "cash", "dr": 2000}, {"acct": "wages", "cr": 2000}])
	Replay.evaluate()
	runner.check(Replay.S()["recorded"], "local result saved")
	Replay.S()["recorded"] = false
	Replay.record_result()
	runner.eq(Replay.history().size(), 1, "same attempt cannot duplicate after older save")
	var run: Dictionary = Replay.S().duplicate(true)
	GameState.pack_rng()
	var packed := JSON.stringify(GameState.data)
	GameState.data = JSON.parse_string(packed)
	GameState.unpack_rng()
	runner.eq(Replay.S(), JSON.parse_string(JSON.stringify(run)), "run survives JSON save with numeric JSON conversion")
	runner.eq(Replay.evaluate(), "won", "loaded result remains terminal")
	runner.eq(Replay.pending_card(), "result", "unread result is restored after load")
	Replay.S()["result_seen"] = true
	runner.eq(Replay.pending_card(), "", "read result is not forced again")
	Replay.rank_path = original_path


func test_corrupt_local_history_is_preserved_and_reported() -> void:
	var original_path := Replay.rank_path
	Replay.rank_path = SaveSystem.DIR+"/replay_corrupt.json"
	var file := FileAccess.open(Replay.rank_path, FileAccess.WRITE)
	file.store_string("[7,{\"result\":{\"score\":\"bad\"}}]")
	file.close()
	_start("part_time_start", 89, {"week": "QA"})
	GameState.inc_stat("shifts_worked", 30)
	Ledger.post("player", "QA wages", [{"acct": "cash", "dr": 2000}, {"acct": "wages", "cr": 2000}])
	Replay.evaluate()
	runner.check(not Replay.S()["recorded"] and not Replay.history_error.is_empty(), "corrupt history is an explicit storage failure")
	runner.eq(FileAccess.get_file_as_string(Replay.rank_path), "[7,{\"result\":{\"score\":\"bad\"}}]", "existing bytes preserved")
	Replay.rank_path = original_path
