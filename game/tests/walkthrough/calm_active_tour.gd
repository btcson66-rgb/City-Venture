extends RefCounted
var bot
var metrics := {}
class Checks extends RefCounted:
	var bot
	func check(ok: bool,text: String) -> void:bot.expect(ok,text)
	func eq(a,b,text: String) -> void:bot.expect(a==b,text)
	func get_tree() -> SceneTree:return bot.get_tree()
func _init(b) -> void:bot=b
func fixture(id: String):
	UIRoot.close_all()
	GameState.new_game({"name":"新手","seed":164})
	GameState.data["tutorial"]={"v":3,"off":true,"seen":{}}
	GameState.set_flag("debug_feature_gates_all")
	Clock.world_active=false
	AssistantPolicy.testing=true
	var helper=load("res://tests/unit/test_"+id+".gd").new()
	var checks:=Checks.new();checks.bot=bot;helper.runner=checks
	helper.setup()
	GameState.data["entities"][GameState.company_id()]["name"]="城市小舖"
	return helper
func capture(modal: Modal, tag: String) -> void:
	UIRoot.open_modal(modal)
	await bot.wait(.5)
	FeatureIntroModal.dismiss_all(bot.get_tree())
	await bot.wait(.2)
	await bot.shot(tag)
	var text := ""
	for node in modal.body.find_children("*","Control",true,false):
		if node.is_visible_in_tree() and (node is Label or node is Button):text+=node.atr(node.text)+"\n"
	metrics[tag]={"characters":text.replace("\n","").length(),"numbers":RegEx.create_from_string("[0-9]+(?:[.,][0-9]+)*").search_all(text).size(),"text":text,"steps_to_primary":1}
	bot.expect(Ledger.check_balanced(),tag+" real setup books balanced")
	UIRoot.close_all()
func run() -> void:
	UIRoot._suppress_decisions=true
	Help.auto=false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--lang="):I18n.set_locale(arg.substr(7),false)
	if "--calm-large" in OS.get_cmdline_user_args():
		InputAccess.touch_mode=true;Preferences.values["font_size"]=3;Preferences.apply()
	var media=fixture("media")
	SceneRouter._enter("interior","riverside_apartment","entry","up")
	var chosen: String=media.won()
	var mixer:=MediaUI.new();mixer.selected=chosen;mixer.page="mixer"
	await capture(mixer,"ActiveMediaMixer")
	var auto=fixture("automotive")
	Ledger.post(GameState.company_id(),"QA declared fleet equity",[{"acct":"cash","dr":100000},{"acct":"equity","cr":100000}])
	auto.fleet_ready(GameState.company_id(),1)
	var fleet:=AutomotiveUI.new();fleet.page="fleet"
	await capture(fleet,"ActiveFleet")
	GameState.set_flag("test_assistant_run")
	AssistantPolicy.set_all(false)
	AssistantPolicy.set_task("maintenance",true)
	var car: String = Automotive.S()["fleet"].keys()[0]
	var car_asset := Automotive.fleet_item(car)
	car_asset["status"]="broken";car_asset["maintenance_due"]=true
	var fleet_cash := Ledger.cash(GameState.company_id())
	AssistantPolicy._maintain()
	bot.expect(car_asset["status"]=="broken" and Ledger.cash(GameState.company_id())==fleet_cash,"fleet switch off preserves manual repair")
	AssistantPolicy.set_task("fleet_care",true)
	Automotive.S()["fleet"][car]["rental"]="QA occupied-car fixture"
	AssistantPolicy._maintain()
	bot.expect(Ledger.cash(GameState.company_id())==fleet_cash,"assistant waits for a rented car to return")
	Automotive.S()["fleet"][car]["rental"]=""
	var service_cost := Automotive.service_cost(car)
	AssistantPolicy._maintain()
	bot.expect(absf(Ledger.cash(GameState.company_id())-(fleet_cash-service_cost))<.01,"fleet assistant pays actual service cost")
	bot.expect(Automotive.S()["fleet"][car]["out"]==Clock.day_index()+1,"real service downtime retained")
	fixture("energy")
	Ledger.post(GameState.company_id(),"QA declared charger equity",[{"acct":"cash","dr":120000},{"acct":"equity","cr":120000}])
	# Stage eligibility only is a declared fixture; lease, site deal, asset, build time and costs remain real.
	Energy.S()["storage_cert"]=true;Energy.S()["completed"]=2
	var signed:=false
	for attempt in 12:
		Clock.advance(Clock.DAY)
		if Energy.site_deal("shop_garage","fee").get("signed",false):signed=true;break
	bot.expect(signed,"actual charger site deal signed")
	bot.expect(Energy.build_station("shop_garage","fast")["ok"],"real charger asset bought")
	Clock.advance(11*Clock.DAY)
	bot.expect(Energy.site_of("shop_garage")["status"]=="open","actual build time completed")
	var charging:=EnergyUI.new();charging.page="charging"
	await capture(charging,"ActiveCharging")
	GameState.set_flag("test_assistant_run")
	AssistantPolicy.set_all(false)
	AssistantPolicy.set_task("maintenance",true)
	var station := Energy.site_of("shop_garage")
	var asset: Dictionary = Assets.S()["items"][station["asset"]]
	asset["status"]="broken";asset["maintenance_due"]=true
	var charger_cash := Ledger.cash(Energy.entity())
	var charger_revenue := Ledger.balance(Energy.entity(),"revenue")
	AssistantPolicy._maintain()
	bot.expect(asset["status"]=="broken" and Ledger.cash(Energy.entity())==charger_cash,"charger switch off preserves manual repair")
	AssistantPolicy.set_task("charging_care",true)
	AssistantPolicy._maintain()
	bot.expect(asset["status"]=="working","charging assistant repairs the real asset")
	bot.expect(absf(Ledger.cash(Energy.entity())-(charger_cash-float(asset["maintenance_cost"])))<.01,"actual station maintenance fee paid")
	bot.expect(Ledger.balance(Energy.entity(),"revenue")==charger_revenue,"maintenance creates no sale or free income")
	bot.expect(Ledger.check_balanced(),"delegated station and fleet books balanced")
	var file:=FileAccess.open(bot.out_dir+"/comparison.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"  "))
