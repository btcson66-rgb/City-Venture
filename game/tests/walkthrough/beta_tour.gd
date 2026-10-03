class_name BetaTour
extends RefCounted
## Fresh-player and later-story snapshots use real scenes, schedules and UI, without inventing NPCs.

var bot


func _init(b) -> void:
	bot = b


func run() -> void:
	var walk := Walkthrough.new(bot)
	await walk._new_game()
	UIRoot._suppress_decisions = true
	UIRoot.tutorial.st()["off"] = true
	GameState.data["clock"]["minutes"] = Clock.at_day_time(1, 14 * 60)
	# Let the real chapter transition finish before capturing any destinations.
	await bot.wait(0.5)
	await bot.until(func(): return UIRoot.card_layer.find_child("ChapterCard", false, false) == null, 8.0)
	bot.expect(UIRoot.card_layer.find_child("ChapterCard", false, false) == null, "chapter card cleared before destination screenshots")
	for g in BuildingInfo.guide_groups():
		bot.step("Beta district: " + str(g["id"]))
		SceneRouter._enter("district", g["id"], "", "down")
		await bot.wait(0.3)
		await bot.shot("beta_district_" + g["id"])
		for node in SceneRouter.world_scene().get_children():
			if node is DoorTrigger:
				bot.expect(BuildingInfo.building_enterable(node.building_id), "door belongs to active building: " + node.building_id)
		for bid in g["buildings"]:
			SceneRouter._enter("interior", bid, "door", "up")
			await bot.wait(0.35)
			var usable = bot.find_interactable(func(n): return n.enabled and n.action != "look" and Actions.lock_reason(n.action, n.params) == "")
			bot.expect(usable != null, "working interaction or present NPC: " + bid)
			await bot.shot("beta_interior_" + bid)
	# Later-story NPC-only rooms become destinations from their actual conditions and schedules.
	UIRoot.open_modal(PermitsModal.new())
	await bot.wait(0.4)
	bot.expect(bot.button_named("CompanyRegistrationNext") != null, "first action is company registration before applications")
	await bot.shot("beta_registration_next")
	await bot.click_named("CompanyRegistrationNext")
	bot.expect(UIRoot.tutorial._destination == "city_hall", "primary registration step starts a usable route")
	UIRoot.tutorial._destination = ""
	GameState.set_flag("big_contract_offered")
	Company.register("Riverlight Goods", "ecommerce", "22 Founders Lane")
	Company.open_business_account(20000.0)
	Living.lease("corner_cafe")
	GameState.data["clock"]["minutes"] = Clock.at_day_time(6, 14 * 60)
	for g in BuildingInfo.guide_groups():
		for bid in g["buildings"]:
			if BuildingInfo.activities(bid).is_empty() or bid == "corner_cafe_unit":
				SceneRouter._enter("interior", bid, "door", "up")
				await bot.wait(0.35)
				bot.expect(bot.find_interactable(func(n): return n.enabled and n.action != "look" and Actions.lock_reason(n.action, n.params) == "") != null, "later destination has working interaction or real NPC: " + bid)
				await bot.shot("beta_story_" + bid)
	UIRoot.open_modal(CityGuideModal.new())
	await bot.wait(0.4)
	await bot.shot("beta_later_city_guide")
	UIRoot.top_modal().close()
	GameState.data["clock"]["minutes"] = Clock.at_day_time(1, 14 * 60)
	SceneRouter._enter("district", "riverside", "", "down")
	await bot.wait(0.3)
	for modal in [BusinessBoard.new(), CityMapModal.new(false), MetroModal.new("riverside"), PermitsModal.new(), CityGuideModal.new(), CompanyOS.new("home_laptop")]:
		bot.step("Beta screen: " + modal.get_script().get_global_name())
		UIRoot.open_modal(modal)
		await bot.wait(0.4)
		if modal is BusinessBoard:
			for b in DataDB.businesses.values():
				bot.expect((bot.button_named("Biz_" + b["id"]) != null) == (b.get("status", "planned") == "active"), "board follows business status: " + str(b["id"]))
		await bot.shot("beta_screen_" + modal.get_script().get_global_name())
		modal.close()
		await bot.wait(0.2)
	UIRoot.phone.open()
	await bot.wait(0.3)
	bot.expect(bot.button_named("App_world") == null, "world map is absent from phone")
	await bot.shot("beta_phone")
	UIRoot.phone.close()
	var old = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/contracts_before_closure_pre36.json"))
	old["data"]["player"]["location"] = {"kind": "interior", "id": "old_town_studio", "x": 40, "y": 60, "facing": "up"}
	var old_file := FileAccess.open(SaveSystem._path(4), FileAccess.WRITE)
	old_file.store_string(JSON.stringify(old))
	old_file.close()
	bot.expect(SaveSystem.load_and_enter(4), "real old-save fixture loads from hidden room")
	await walk.wait_world()
	bot.expect(SceneRouter.world_scene().kind == "district" and SceneRouter.world_scene().scene_id == "old_town", "old save returns to original street")
	await bot.shot("beta_old_save_return")
	bot.expect(Ledger.check_balanced(), "beta fixture preserves balanced ledger")
	var report := FileAccess.open(bot.out_dir + "/beta_tour_result.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"failures": bot.failures, "screenshots": bot.shot_n}, "  "))
