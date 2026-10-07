extends RefCounted
var bot
func _init(b) -> void: bot = b

func _screen(modal: Modal, label: String) -> void:
	UIRoot.close_all()
	modal.help_key = ""
	UIRoot.open_modal(modal)
	await bot.wait(0.3)
	bot.expect(modal.get_viewport_rect().grow(1).encloses(modal.panel.get_global_rect()), label + " fits viewport")
	await bot.shot(label)
	modal.close()
	await bot.wait(0.1)

func run() -> void:
	UIRoot._suppress_decisions = true
	Help.auto = false
	GameState.new_game({"name": "Calm tour", "seed": 152})
	GameState.data["tutorial"] = {"v": 3, "off": true, "seen": {}}
	SceneRouter._enter("district", "civic_center", "metro", "up")
	UIRoot.set_hud_visible(true)
	Clock.push_pause("calm_tour")
	TrafficSafety.hit(75, "civic_center", Vector2(560, 424))
	UIRoot.close_all()
	for locale in ["en", "zh_TW"]:
		TranslationServer.set_locale(locale)
		for mobile in [false, true]:
			InputAccess.touch_mode = mobile
			Preferences.values["font_size"] = 3 if mobile else 1
			Preferences.apply()
			var tag: String = locale + ("_mobile_large" if mobile else "_desktop")
			await bot.wait(0.3)
			await bot.shot(tag + "_hud")
			await _screen(CompanyOS.new("home_laptop"), tag + "_os")
			var instance := EventEngine.trigger("escrow_offer", {})
			if not instance.is_empty(): await _screen(DecisionModal.new(instance), tag + "_decision")
			await _screen(TrafficModal.new("accident"), tag + "_traffic")
	Clock.pop_pause("calm_tour")
	bot.expect(Ledger.check_balanced(), "reading screens preserves ledger balance")
