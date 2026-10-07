extends RefCounted
var bot
func _init(b) -> void:bot=b
func run() -> void:
	UIRoot._suppress_decisions = true
	Help.auto = false
	GameState.new_game({"name":"Alex Chen","seed":154})
	GameState.data["tutorial"] = {"off":true,"v":99,"seen":{}}
	Clock.clear_pauses()
	Clock.world_active = false
	SceneRouter._enter("interior",Living.home_building(),Living.home_bed(),"down")
	UIRoot.set_hud_visible(true)
	var settings := SettingsModal.new()
	settings.page = 5
	UIRoot.open_modal(settings)
	await bot.wait(0.4)
	await bot.shot("assistant_settings_new_game")
	bot.expect(settings.find_child("AssistantAll",true,false).button_pressed,"all chores default on")
	bot.expect(settings.help_key=="assistant","assistant settings have their own help card")
	UIRoot.close_all()
	GameState.data["tutorial"] = {"step":Tutorial._index("pack"),"seen":{},"off":false,"v":Tutorial.VERSION}
	await bot.wait(0.4)
	await bot.shot("assistant_packing_guide")
	bot.expect(UIRoot.tutorial.body.text.begins_with(I18n.t("Your assistant packs and ships. Turn it off at the packing table to play.")),"packing guide explains optional manual play")
	GameState.data["tutorial"]["off"] = true
	var os := CompanyOS.new("home_laptop")
	os.tab = "operations"
	UIRoot.open_modal(os)
	await bot.wait(0.4)
	await bot.shot("assistant_operations")
	UIRoot.close_all()
	UIRoot.open_modal(PackShipModal.new(Living.home()))
	await bot.wait(0.4)
	await bot.shot("assistant_packing")
	UIRoot.close_all()
	Company.register("Quiet Trading","ecommerce","Suite 2B")
	Company.open_business_account(10000)
	GameState.data["story"]["chapter"] = "ch7_supply_shock"
	UIRoot.open_modal(TaxFilingModal.new(GameState.company_id()))
	await bot.wait(0.4)
	await bot.shot("assistant_tax_default")
	bot.expect(Ledger.check_balanced(),"render fixture books balanced")
	UIRoot.close_all()
	AssistantPolicy.affordable(GameState.company_id(),Ledger.cash(GameState.company_id()))
	UIRoot.phone.open()
	await bot.wait(0.4)
	await bot.click_named("App_messages")
	await bot.wait(0.3)
	bot.expect(UIRoot.phone.app=="messages" and UIRoot.top_modal()==null,"cash warning shown in notification center")
	await bot.shot("assistant_cash_recovery")
	bot.expect(PhoneMessages.contact_name("assistant")==I18n.t("Assistant"),"assistant sender is localized")
	UIRoot.phone.close()
