extends RefCounted
## Real settings input and fixed-position native/Web comparisons. No real user's cfg writes.
var bot

func _init(b) -> void:
	bot = b

func run() -> void:
	var original_path := Preferences.path
	var original_values := Preferences.values.duplicate(true)
	Preferences.path = bot.out_dir.path_join("detail_settings.cfg")
	GameState.new_game({"name":"Detail Tour", "seed":26})
	GameState.data["tutorial"] = {"off":true,"step":99,"seen":{},"v":99}
	Company.register("Detail Haul", "ecommerce", "Pier 7")
	Company.open_business_account(18000.0)
	bot.expect(Logistics.buy_van().get("ok", false), "real van purchase for appearance comparison")
	var samples := {}
	for district in ["old_town", "harbor", "shopping_street", "riverside"]:
		SceneRouter._enter("district", district, "door_" + str(DataDB.districts[district]["buildings"][0]), "down")
		await bot.wait(4.0)
		var pos := SceneRouter.world_scene().player.position
		for enabled in [false, true]:
			var modal := SettingsModal.new()
			modal.page = 1
			UIRoot.open_modal(modal)
			await bot.wait(0.3)
			if bool(Preferences.values["high_detail_art"]) != enabled:
				await bot.click_named("Setting_high_detail_art", 3.0)
				await bot.wait(0.8)
			await bot.click_named("SettingsDone", 3.0)
			bot.expect(Art.detail_enabled == enabled, "detail setting applied")
			bot.expect(SceneRouter.world_scene().player.position.distance_to(pos) < 1.0, "toggle preserves player position")
			Clock.world_active = false
			await bot.wait(0.4)
			await bot.shot("detail_%s_%s" % [district, "on" if enabled else "off"])
			# The optional Web benchmark draws the same actual Harbor scene for sixty seconds each.
			if district == "harbor" and "--detail-fps" in OS.get_cmdline_user_args():
				await bot.wait(3.0)
				var start := Time.get_ticks_msec()
				var frames := Engine.get_process_frames()
				await bot.wait(60.0)
				var seconds := (Time.get_ticks_msec() - start) / 1000.0
				samples["on" if enabled else "off"] = (Engine.get_process_frames() - frames) / seconds
				bot.log_line("Harbor average FPS (%s): %.2f over %.2f seconds" % [enabled, samples["on" if enabled else "off"], seconds])
	if not samples.is_empty():
		var ratio := float(samples["on"]) / maxf(0.001, float(samples["off"]))
		samples["ratio"] = ratio
		samples["platform"] = "web" if OS.has_feature("web") else "native"
		var file := FileAccess.open(bot.out_dir.path_join("detail_fps.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(samples, "  "))
		bot.log_line("DETAIL_FPS " + JSON.stringify(samples))
		bot.expect(ratio >= 0.9, "high detail Harbor FPS within ten percent")
	Preferences.path = original_path
	Preferences.values = original_values
	Preferences.apply()
	bot.expect(Ledger.check_balanced(), "detail tour leaves balanced books")
