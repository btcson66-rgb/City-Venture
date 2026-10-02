extends "res://tests/walkthrough/settings_tour.gd"
## Related replay tour: pages/cards plus honest 120-day normal-policy samples and idle controls.


func _run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			out = argument.substr(6)
	if out.is_empty() or out.begins_with("user://"):
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(out)
	SaveSystem.DIR = out.path_join("saves")
	SaveSystem.autosave_enabled = false
	Replay.rank_path = out.path_join("challenge_history.json")
	Help.auto = false
	UIRoot._suppress_decisions = true
	var setup := NewRunModal.new()
	UIRoot.open_modal(setup)
	await _settle()
	var primary := setup.find_child("CreateRunCharacter", true, false) as Button
	var visible_action := setup.get_viewport_rect().encloses(primary.get_global_rect())
	checks.append({"sticky_primary_visible": visible_action})
	if not visible_action:
		failures.append("Setup primary action outside viewport")
	await _shot("new_game_setup")
	setup.page = "scenarios"
	setup.rebuild()
	await _settle()
	await _shot("scenario_selection")
	setup.close()
	await _settle()
	ReplayPolicy.start("inherited_cafe", 89)
	var card := RunCardModal.new(true)
	UIRoot.open_modal(card)
	await _settle()
	await _shot("scenario_opening")
	card.close()
	await _settle()
	var samples: Array = []
	var ids: Array = DataDB.scenarios.keys()
	ids.sort()
	for id in ids:
		for seed_value in [89, 90, 91]:
			ReplayPolicy.start(id, seed_value)
			for day in 120:
				ReplayPolicy.work(day)
				if day % 10 == 0:
					await get_tree().process_frame
			var balanced := Ledger.check_balanced()
			var sample := {"scenario": id, "seed": seed_value, "policy": "normal", "days": 120, "status": Replay.S()["status"], "metrics": Replay.metrics(), "result": Replay.S()["result"].duplicate(true), "balanced": balanced}
			samples.append(sample)
			print("Scenario %s seed %d: %s, cash %s, revenue %s, balanced %s" % [id, seed_value, sample["status"], str(sample["metrics"]["cash"]), str(sample["metrics"]["revenue"]), str(balanced)])
			if not balanced:
				failures.append(id + " unbalanced ledger")
		ReplayPolicy.start(id, 89)
		for day in 120:
			ReplayPolicy.work(day, true)
			if day % 10 == 0:
				await get_tree().process_frame
		samples.append({"scenario": id, "seed": 89, "policy": "idle", "days": 120, "status": Replay.S()["status"], "metrics": Replay.metrics(), "balanced": Ledger.check_balanced()})
	var won: Array = samples.filter(func(s): return s["policy"] == "normal" and s["status"] == "won")
	for id in ids:
		var can_win := won.any(func(s): return s["scenario"] == id)
		checks.append({"scenario": id, "normal_policy_can_win": can_win})
		if not can_win:
			failures.append(id + " has no winning 120-day sample")
	ReplayPolicy.start("part_time_start", 89)
	for day in 120:
		ReplayPolicy.work(day)
	if Replay.S()["result"].is_empty():
		failures.append("No result for settlement evidence")
	var result_card := RunCardModal.new(false)
	UIRoot.open_modal(result_card)
	await _settle()
	await _shot("scenario_result")
	result_card.close()
	var report := FileAccess.open(out.path_join("replay_result.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "samples": samples, "failures": failures,
		"limits": ["Normal APIs and time costs; no forced orders or fixture money.", "Three seeds per scenario are examples, not a proof of every strategy or seed.", "Venture funding's deadline is 18 calendar months, beyond this 120-day sample."]}, "	"))
	report.close()
	print("Replay tour: %d normal wins / %d samples, %d failures" % [won.size(), samples.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
