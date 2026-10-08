extends RefCounted
## Matching fixtures use real setup APIs and declared equity; they are screen evidence, not the main story.
var bot
var metrics := {}
class Checks extends RefCounted:
	var bot
	func check(ok: bool, text: String) -> void: bot.expect(ok, text)
	func eq(a, b, text: String) -> void: bot.expect(a == b, text)
	func get_tree() -> SceneTree: return bot.get_tree()
func _init(b) -> void: bot = b

func fresh() -> void:
	UIRoot.close_all()
	GameState.new_game({"name":"新手","seed":164})
	GameState.data["tutorial"] = {"v":3,"off":true,"seen":{}}
	GameState.set_flag("debug_feature_gates_all")
	Clock.world_active = false
	AssistantPolicy.testing = true

func fixture(id: String, method := "setup"):
	fresh()
	var helper = load("res://tests/unit/test_" + id + ".gd").new()
	var checks := Checks.new()
	checks.bot = bot
	helper.runner = checks
	helper.call(method)
	if GameState.company_id() != "": GameState.data["entities"][GameState.company_id()]["name"] = "城市小舖"
	return helper

func capture(tag: String) -> void:
	await bot.wait(0.4)
	if "--calm-guides" in OS.get_cmdline_user_args():
		var intro := UIRoot.top_modal().find_child("FeatureIntro",true,false) as FeatureIntroModal
		if intro != null:
			bot.expect(intro._target != null and intro._target.is_visible_in_tree(),tag+" guide outlines a real control")
			await bot.shot("Guide_"+tag)
	FeatureIntroModal.dismiss_all(bot.get_tree())
	await bot.wait(0.1)
	await bot.shot(tag)
	var modal := UIRoot.top_modal()
	var root: Control = modal.get("content") if modal is CompanyOS else modal.body
	var text := ""
	var actions := 0
	for control in root.find_children("*", "Control", true, false):
		if not control.is_visible_in_tree():continue
		if control is Label or control is Button:
			text += control.atr(control.text) + "\n"
		if control is Button and not control.disabled:actions += 1
	metrics[tag] = {"characters":text.replace("\n", "").length(),"numbers":RegEx.create_from_string("[0-9]+(?:[.,][0-9]+)*").search_all(text).size(),"visible_actions":actions,"steps_to_primary":1,"manual_review_required":root.find_child("CalmAdvanced",true,false).get_meta("calm_primary",false) if root.find_child("CalmAdvanced",true,false)!=null else false,"text":text}
	var primaries := root.find_children("*","Button",true,false).filter(func(button):return button.is_visible_in_tree() and button.get_meta("primary_action",false))
	bot.expect(primaries.size()==1,tag+" one visible primary entrance")
	bot.expect(int(metrics[tag]["numbers"])<=3,tag+" at most three default-screen figures")
	bot.expect(Ledger.check_balanced(), tag + " ledger balanced")

func pages(modal: Modal, tags: Array) -> void:
	UIRoot.open_modal(modal)
	for page in tags:
		if modal.get("page") != page:
			modal.set("page", page)
			modal.rebuild()
		await capture(modal.get_script().get_global_name() + "_" + str(page))
	modal.close()

func run() -> void:
	UIRoot._suppress_decisions = true
	Help.auto = false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="):I18n.set_locale(arg.substr(7), false)
	if "--calm-large" in OS.get_cmdline_user_args():
		InputAccess.touch_mode = true
		Preferences.values["font_size"] = 3
		Preferences.apply()
	fixture("manufacturing", "setup_factory")
	SceneRouter._enter("interior", "riverside_apartment", "entry", "up")
	var rfq: Dictionary = Manufacturing.S()["rfqs"].values()[0]
	var quote := Manufacturing.quote(str(rfq["id"]), float(rfq["min_price"]))
	var factory := ManufacturingUI.new()
	factory.selected_job = str(quote.get("id", ""))
	await pages(factory, ["orders","planner","quality"])
	fixture("real_estate")
	await pages(RealEstateUI.new(), ["matches","properties"])
	var media = fixture("media")
	media.won()
	await pages(MediaUI.new(), ["briefs","mixer","reports"])
	fixture("hotel")
	await pages(HotelUI.new(), ["board","ops","groups"])
	fixture("automotive")
	await pages(AutomotiveUI.new(), ["auction","fleet"])
	fixture("energy")
	var energy := EnergyUI.new()
	if not Energy.S()["leads"].is_empty(): energy.selected = str(Energy.S()["leads"].keys()[0])
	await pages(energy, ["leads","survey","charging"])
	fixture("trade_execution")
	UIRoot.open_modal(TradeDeskUI.new())
	await capture("TradeDesk")
	UIRoot.close_all()
	UIRoot.open_modal(TradeQuoteModal.new("northridge"))
	await capture("TradeQuote")
	UIRoot.close_all()
	fixture("manufacturing", "setup_factory")
	var os := CompanyOS.new("home_laptop")
	UIRoot.open_modal(os)
	for tab in ["contracts","people","finance","segments","group","market","governance"]:
		os._set_tab(tab)
		await capture("OS_" + str(tab))
	os.close()
	UIRoot.open_modal(TaxFilingModal.new(GameState.company_id()))
	await capture("Tax")
	UIRoot.close_all()
	UIRoot.open_modal(LeaseModal.new("suite_2b"))
	await capture("Lease")
	UIRoot.close_all()
	UIRoot.open_modal(LeaseEndModal.new("unit12_factory"))
	await capture("LeaseEnd")
	UIRoot.close_all()
	var funding := FundraisingModal.new()
	UIRoot.open_modal(funding)
	await capture("Fundraising_investors")
	Fundraising.intro_offer("elena")
	funding.selected = "elena"
	funding.rebuild()
	await capture("Fundraising_terms")
	funding.tab = "cap"
	funding.rebuild()
	await capture("Fundraising_cap")
	UIRoot.close_all()
	var file := FileAccess.open(bot.out_dir + "/comparison.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics, "  "))

	if "--calm-guides" in OS.get_cmdline_user_args():
		for industry in Industries.all():
			match industry["id"]:
				"consulting":fresh();Careers.start_freelance()
				"cafe":fixture("cafe_depth")
				"logistics":fixture("logistics_depth")
				"real_estate":fixture("real_estate")
				"hotel":fixture("hotel")
				"automotive":fixture("automotive")
				_:fresh()
			GameState.set_flag("debug_feature_gates_all",false)
			var entry := CompanyOS.new("home_laptop")
			UIRoot.open_modal(entry)
			var tab: String = industry["sim_class"].os_tab()["id"]
			FeatureGate.grant("os_"+tab)
			entry._set_tab(tab)
			await bot.wait(.2)
			var hint := entry.find_child("FeatureIntro",true,false) as FeatureIntroModal
			bot.expect(hint != null and hint.feature == "industry_"+str(industry["id"]),"specific first-use guide wins over generic hint: "+tab)
			if hint != null:bot.expect(hint._target != null and hint._target.is_visible_in_tree(),"real first-use target: "+tab)
			await bot.shot("EntryGuide_"+str(industry["id"]))
			FeatureIntroModal.dismiss_all(bot.get_tree())
			UIRoot.close_all()
