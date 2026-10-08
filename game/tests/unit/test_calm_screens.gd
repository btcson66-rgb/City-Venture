extends RefCounted
var runner
func frames() -> void:
	for i in 4:await UIRoot.get_tree().process_frame

func test_every_registered_industry_has_short_first_use_data() -> void:
	var guides := FeatureIntroModal.industry_definitions()
	for industry in Industries.all():
		var id: String = industry["id"]
		runner.check(guides.has(id),"missing first-use guide: "+id)
		var steps: Array = guides.get(id,{}).get("steps",[])
		runner.check(steps.size()>=1 and steps.size()<=3,"one to three steps: "+id)
		for step in steps:runner.check(not str(step.get("text","")).is_empty(),"visible hint: "+id)

func test_first_use_skip_replay_never_pauses_or_moves_cash() -> void:
	var helper = load("res://tests/unit/test_hotel.gd").new()
	helper.runner = runner
	var entity: String = helper.setup()
	var cash := Ledger.cash(entity)
	var now := Clock.now()
	var paused := Clock.is_paused()
	var modal := HotelUI.new()
	UIRoot.open_modal(modal)
	await frames()
	var intro := modal.find_child("FeatureIntro",true,false) as FeatureIntroModal
	runner.check(intro != null,"first opening supplies guide")
	if intro != null:
		runner.check(intro._target != null,"outline targets real visible button")
		intro.finish()
	await frames()
	runner.check("industry_hotel" in FeatureGate.state()["guided"],"skip saved once")
	FeatureIntroModal.show_in(modal,"industry_hotel")
	await frames()
	runner.check(modal.find_child("FeatureIntro",true,false)!=null,"replay is available")
	runner.eq(Clock.now(),now,"guide consumes no game time")
	runner.eq(Clock.is_paused(),paused or modal.pauses_time,"guide adds no clock pause")
	runner.eq(Ledger.cash(entity),cash,"guide moves no cash")
	UIRoot.close_all()
	await frames()

func test_disclosure_keeps_real_controls_and_one_primary() -> void:
	var helper = load("res://tests/unit/test_hotel.gd").new()
	helper.runner = runner
	helper.setup()
	var modal := HotelUI.new()
	UIRoot.open_modal(modal)
	await frames()
	FeatureIntroModal.dismiss_all(UIRoot.get_tree())
	var details := modal.find_child("CalmDetails",true,false) as Control
	runner.check(details != null and not details.visible,"details start closed")
	var primary := modal.body.find_children("*","Button",true,false).filter(func(b):return b.is_visible_in_tree() and b.get_meta("primary_action",false))
	runner.eq(primary.size(),1,"one visible main action")
	runner.eq(CalmScreen.figures("hotel",modal).size(),3,"three key figures")
	var advanced := modal.find_child("CalmAdvanced",true,false) as Button
	advanced.pressed.emit()
	runner.check(details.visible,"manual detail controls can be revealed")
	UIRoot.close_all()
	await frames()

func test_manual_old_assistant_choices_stay_manual_for_new_tasks() -> void:
	var state := AssistantPolicy.S()
	for id in state["tasks"]:state["tasks"][id]=false
	for id in ["hotel_daily","fleet_care","charging_care","media_delivery","month_close"]:state["tasks"].erase(id)
	for id in ["hotel_daily","fleet_care","charging_care","media_delivery","month_close"]:
		runner.check(not AssistantPolicy.S()["tasks"][id],"new chore respects manual save: "+id)

func test_hotel_assistant_uses_reference_rates_and_real_cleaners() -> void:
	var helper = load("res://tests/unit/test_hotel.gd").new()
	helper.runner = runner
	var entity: String = helper.setup()
	GameState.set_flag("test_assistant_run")
	AssistantPolicy.set_all(false)
	AssistantPolicy.set_task("hotel_daily",true)
	Hotel.set_price("standard",180)
	var cash := Ledger.cash(entity)
	AssistantPolicy.on_hour(Clock.now(),int(AssistantPolicy.cfg()["daily_hour"]))
	runner.eq(Hotel.rack_price("standard"),100,"reasonable reference price, not optimum")
	runner.eq(Ledger.cash(entity),cash,"setting housekeeping buys no fictitious labor")
	runner.check(Hotel.S()["temp"],"existing paid temporary cleaner option enabled")
	AssistantPolicy.set_task("hotel_daily",false)
	Hotel.set_price("standard",135)
	AssistantPolicy.on_hour(Clock.now(),int(AssistantPolicy.cfg()["daily_hour"]))
	runner.eq(Hotel.rack_price("standard"),135,"manual price stays selected when off")
	runner.check(Ledger.check_balanced(),"hotel delegation balanced")

func test_legacy_media_only_invoices_completed_agreed_work() -> void:
	var helper = load("res://tests/unit/test_media.gd").new()
	helper.runner = runner
	var entity: String = helper.setup()
	var id := Jobs.offer({"entity":entity,"client":"northstar","scope":"Actual legacy media delivery","segment":"media","price":100,"work":2,"terms":0,"due":Clock.now()+Clock.DAY})
	runner.check(Jobs.accept(id)["ok"],"real agreed job accepted")
	GameState.set_flag("test_assistant_run")
	AssistantPolicy.set_all(false)
	AssistantPolicy.set_task("media_delivery",true)
	AssistantPolicy.on_hour(Clock.now(),12)
	runner.eq(Jobs.get_job(id)["status"],"active","unfinished work never delivered")
	runner.eq(-Ledger.balance(entity,"revenue"),0,"no income from unfinished work")
	Jobs.progress(id,2)
	AssistantPolicy.on_hour(Clock.now(),12)
	runner.check(Jobs.get_job(id)["status"] in ["paid","invoiced"],"completed real work invoiced")
	runner.eq(-Ledger.balance(entity,"revenue"),100-Tax.vat(100),"R4: agreed scope creates actual invoice")
	AssistantPolicy.on_hour(Clock.now(),12)
	runner.eq(-Ledger.balance(entity,"revenue"),100-Tax.vat(100),"no duplicate revenue")
	runner.check(Ledger.check_balanced(),"media real transaction balanced")

func test_monthly_delegation_preserves_real_currency_report_receipt() -> void:
	Company.register("Report Test","ecommerce","Report Test")
	Company.open_business_account(1000)
	var entity := GameState.company_id()
	GameState.set_flag("test_assistant_run")
	AssistantPolicy.set_all(true)
	GameState.set_flag("monthly_report_seen")
	OverseasPartners.S()["chapters"]["ch15_currency_swing"]={"entity":entity,"started":Clock.now()-1}
	var report := {"t1":Clock.now(),"entities":{entity:{}}}
	var pending := UIRoot._pending_reports.size()
	EventBus.month_closed.emit(report)
	runner.eq(UIRoot._pending_reports.size(),pending,"later actual reports do not force a popup")
	runner.check(GameState.flag("fx_month_viewed"),"real delegated report cannot soft-lock currency chapter")
	runner.check(Ledger.check_balanced(),"report receipt creates no income")

func test_manual_monthly_reports_still_open() -> void:
	GameState.set_flag("test_assistant_run")
	GameState.set_flag("monthly_report_seen")
	AssistantPolicy.set_task("month_close",false)
	var report := {"t1":Clock.now(),"entities":{}}
	var pending := UIRoot._pending_reports.size()
	EventBus.month_closed.emit(report)
	runner.eq(UIRoot._pending_reports.size(),pending+1,"manual choice keeps the real report popup")
	UIRoot._pending_reports.pop_back()

func test_registry_tab_aliases_reach_their_actual_industry_guides() -> void:
	runner.eq(FeatureIntroModal.industry_for_tab("sales"),"ecommerce","sales reaches ecommerce guide")
	runner.eq(FeatureIntroModal.industry_for_tab("freelance"),"consulting","freelance reaches consulting guide")
	for industry in Industries.all():
		var tab: String = industry["sim_class"].os_tab().get("id", "")
		runner.check(tab != "" and FeatureIntroModal.industry_for_tab(tab)==industry["id"],"real registered entry reaches guide: "+str(industry["id"]))

func test_money_actions_keep_full_terms_beside_manual_buttons() -> void:
	var button := UIK.button("Sign and receive the funds")
	button.name="SignTerms"
	runner.check(CalmScreen._requires_review(button),"signing requires viewing actual terms")
	button.name="Recruit_housekeeper"
	runner.check(CalmScreen._requires_review(button),"paid hiring keeps salary and role context")
	button.name="BoardNextOps"
	runner.check(not CalmScreen._requires_review(button),"safe navigation remains one direct click")
	button.free()

func test_new_chores_inherit_related_manual_choices_in_partial_old_saves() -> void:
	var tasks: Dictionary = AssistantPolicy.S()["tasks"]
	tasks["maintenance"]=false
	tasks["packing"]=false
	for id in ["fleet_care","charging_care","media_delivery"]:tasks.erase(id)
	runner.check(not AssistantPolicy.S()["tasks"]["fleet_care"],"manual fleet maintenance stays manual")
	runner.check(not AssistantPolicy.S()["tasks"]["charging_care"],"manual charging maintenance stays manual")
	runner.check(not AssistantPolicy.S()["tasks"]["media_delivery"],"manual deliveries stay manual")
	runner.check(AssistantPolicy.S()["tasks"]["tax"],"unrelated enabled task preserved")

class SigningProbe extends Modal:
	var quote := {"purchase":100,"margin":20,"stress_margin":5}
	func _init() -> void:calm_profile="trade_quote"
	func build() -> void:
		body.add_child(UIK.wrap("Actual insurance, payment and delivery terms"))
		var sign := UIK.button("Sign buyer contract",Callable(),"primary")
		sign.name="TradeSign"
		footer.add_child(sign)
func test_footer_commit_buttons_cannot_bypass_review() -> void:
	var modal:=SigningProbe.new()
	UIRoot.open_modal(modal)
	await frames()
	var sign:=modal.find_child("TradeSign",true,false) as Button
	var details:=modal.find_child("CalmDetails",true,false) as Control
	runner.check(not sign.is_visible_in_tree() and details.is_ancestor_of(sign),"footer signing stays beside actual terms inside review")
	(modal.find_child("CalmAdvanced",true,false) as Button).pressed.emit()
	runner.check(sign.is_visible_in_tree(),"original manual signing control survives review")
	UIRoot.close_all()
	await frames()
