extends RefCounted
var bot


func _init(b) -> void:
	bot = b


func run() -> void:
	UIRoot._suppress_decisions = true
	Help.auto = false
	GameState.new_game({"name": "Alex Chen", "seed": 109})
	GameState.set_flag("maya_intro_done")
	Clock.clear_pauses()
	Clock.world_active = false
	bot.step("Closed destination at the first tutorial instruction")
	GameState.data["clock"]["minutes"] = Clock.DAY + 22 * 60
	GameState.data["tutorial"] = {"v": 3, "step": Tutorial._index("coffee"), "seen": {}, "off": false}
	SceneRouter._enter("district", "riverside", "door_bloom_coffee", "up")
	UIRoot.set_hud_visible(true)
	await bot.wait(1.0)
	bot.expect(UIRoot.tutorial.body.text.contains("07:00"), "first prompt states next opening")
	await bot.shot("tutorial_closed_hours")
	await bot.click_named("TutorialWaitOpening")
	await bot.wait(1.0)
	bot.expect(SceneRouter.building_open("bloom_coffee")["open"], "wait goes through normal clock simulation to opening")
	bot.expect(UIRoot.tutorial.body.text.contains("20:00"), "open prompt states closing time")
	await bot.shot("tutorial_open_hours")
	bot.step("City Guide gives live hours and explicit waiting")
	GameState.data["tutorial"]["off"] = true
	GameState.data["clock"]["minutes"] = 5 * Clock.DAY + 18 * 60
	UIRoot.open_modal(CityGuideModal.new())
	await bot.wait(1.0)
	var card := UIRoot.top_modal().find_child("GuideBuilding_city_hall", true, false)
	var sc := card.get_parent().get_parent() as ScrollContainer
	if sc != null: sc.ensure_control_visible(card)
	await bot.wait(0.5)
	bot.expect(UIRoot.top_modal().find_child("GuideWait_city_hall", true, false) != null, "closed City Hall has a wait option")
	await bot.shot("city_guide_weekend_hours")
	UIRoot.close_all()
	bot.step("Every coffee ticket names the espresso count")
	MiniGames.auto = -1.0
	var g := BaristaGame.new()
	UIRoot.open_modal(g)
	await bot.wait(0.5)
	await bot.click_named("StartGame")
	await bot.wait(0.5)
	g.want = {"size": "M", "drink": "latte", "milk": "oat", "shots": "1", "who": "Mia"}
	g._layout()
	bot.expect(g.order_text().contains(BaristaGame._name(BaristaGame.SHOTS, "1")), "single shot named")
	await bot.shot("barista_single_shot")
	g.want["drink"] = "flat_white"
	g.want["shots"] = "2"
	g._layout()
	await bot.shot("barista_flat_white_double_shot")
	UIRoot.close_all()
	bot.step("Payment terms explanation beside suppliers and contracts")
	Company.register("Riverlight Goods", "ecommerce", "22 Founders Lane")
	var os := CompanyOS.new("home_laptop")
	os.tab = "operations"
	UIRoot.open_modal(os)
	await bot.wait(1.0)
	await bot.shot("supplier_terms_badge")
	var badge := InfoTip.make("net_terms")
	os.body.add_child(badge)
	await bot.wait(0.2)
	badge._pin()
	await bot.wait(1.0)
	await bot.shot("payment_terms_explanation")
	UIRoot.close_all()
	bot.expect(Ledger.check_balanced(), "normal wait and company registration preserve ledger")
