extends "res://tests/walkthrough/settings_tour.gd"
## Short market tour with three policies and seeds; no fixture income/orders.


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
	for policy in ["normal", "high_spending", "idle"]:
		for seed_value in [90, 91, 92]:
			ReplayPolicy.start("inherited_cafe", seed_value)
			Macro.initialize()
			var opening := Replay.net_worth()
			if policy == "high_spending":
				Cafe.set_ads(200.0)
				Cafe.set_pastry_order(80)
			for day in 120:
				ReplayPolicy.work(day, policy == "idle")
				# Active policies retain staff at their disclosed payroll cost.
				if policy != "idle":
					for offer in Rivals.pending():
						Rivals.answer(str(offer["employee"]), true)
				if day % 10 == 0:
					await get_tree().process_frame
			var sample := {"policy": policy, "seed": seed_value, "days": 120, "net_worth_gain": Replay.net_worth() - opening, "cash": Replay.metrics()["cash"], "revenue": Replay.metrics()["revenue"], "balanced": Ledger.check_balanced(), "rate": Macro.rate(), "cycle": Macro.S()["index"]}
			samples.append(sample)
			print("Market policy: " + JSON.stringify(sample))
			if not sample["balanced"] or (policy == "normal" and float(sample["cash"]) <= 0):
				failures.append("Unbalanced ledger or dead normal strategy for seed " + str(seed_value))
	var average := 0.0
	for sample in samples.filter(func(s): return s["policy"] == "normal"):
		average += float(sample["net_worth_gain"]) / 3.0
	if average <= 0:
		failures.append("Normal policy does not profit on average")
	if not samples.any(func(s): return float(s["net_worth_gain"]) < 0):
		failures.append("No downside observed across the three policies")
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
	var modal := UIRoot.top_modal()
	var retain := modal.find_child("RetainEmployee", true, false) as Button
	var point := get_viewport().get_final_transform() * retain.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await get_tree().process_frame
	for pressed in [true, false]:
		var mouse := InputEventMouseButton.new()
		mouse.position = point
		mouse.global_position = point
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = pressed
		Input.parse_input_event(mouse)
		await get_tree().process_frame
	await _settle()
	if UIRoot.top_modal() is PoachModal:
		failures.append("Walkthrough cannot answer competing job offer")
	var file := FileAccess.open(out.path_join("market_result.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"samples": samples, "average_gain": average, "failures": failures, "limits": ["Three seeds illustrate variability, not a universal balance proof."]}, "\t"))
	file.close()
	print("Market tour: %d samples, %d failures" % [samples.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
