extends "res://tests/walkthrough/settings_tour.gd"
## Short market tour with three normal-policy seeds; no fixture income/orders.


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
	Help.auto = false
	UIRoot._suppress_decisions = true
	Replay.rank_path = out.path_join("history.json")
	var samples: Array = []
	for seed_value in [90, 91, 92]:
		ReplayPolicy.start("inherited_cafe", seed_value)
		Macro.initialize()
		var opening := Replay.net_worth()
		for day in 120:
			ReplayPolicy.work(day)
			# Normal business policy chooses retaining at its disclosed payroll cost.
			for offer in Rivals.pending():
				Rivals.answer(str(offer["employee"]), true)
			if day % 10 == 0:
				await get_tree().process_frame
		var sample := {"seed": seed_value, "net_worth_gain": Replay.net_worth() - opening, "cash": Replay.metrics()["cash"], "revenue": Replay.metrics()["revenue"], "balanced": Ledger.check_balanced(), "rate": Macro.rate(), "cycle": Macro.S()["index"]}
		samples.append(sample)
		print("Market normal policy: " + JSON.stringify(sample))
		if not sample["balanced"] or float(sample["cash"]) <= 0:
			failures.append("Unbalanced or dead normal strategy for seed " + str(seed_value))
	var average := 0.0
	for sample in samples:
		average += float(sample["net_worth_gain"]) / samples.size()
	if average <= 0:
		failures.append("Normal policy does not profit on average")
	ReplayPolicy.start("inherited_cafe", 90)
	Macro.initialize()
	Clock.advance(8 * Clock.DAY)
	var os := CompanyOS.new("home_laptop")
	os.tab = "market"
	UIRoot.open_modal(os)
	await _settle()
	await _shot("market_page")
	os.close()
	await _settle()
	CityNews.publish_day()
	UIRoot.phone.open()
	UIRoot.phone._go("news")
	await _settle()
	await _shot("city_news")
	UIRoot.phone.close()
	var employee := str(Staff.people()[0]["id"])
	for offer in Rivals.pending():
		Rivals.answer(str(offer["employee"]), true)
	Rivals.make_offer(employee, "cafe_1")
	UIRoot.open_modal(PoachModal.new(employee))
	await _settle()
	await _shot("poach_offer")
	var file := FileAccess.open(out.path_join("market_result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples": samples, "average_gain": average, "failures": failures, "limits": ["Three seeds illustrate variability, not a universal balance proof.", "RFQ/brief systems are unmerged in the PR target; competitor API awaits integration."]}, "\t"))
	file.close()
	print("Market tour: %d samples, %d failures" % [samples.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
