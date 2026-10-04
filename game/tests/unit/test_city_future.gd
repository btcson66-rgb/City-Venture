extends RefCounted
var runner
func _start(number: int) -> void:
	GameState.set_flag("legacy_cards_viewed")
	UIRoot._suppress_decisions=true
	StoryEngine.St()["active"].clear()
	StoryEngine.start_chapter(CityFuture.definition(number)["id"])
func _services(number: int) -> void:
	_start(number)
	runner.check(CityFuture.read_brief()["ok"],"civic briefing")
	runner.check(CityFuture.procure("partner")["ok"],"paid civic partnership")
	GameState.data["clock"]["minutes"]+=8*Clock.DAY
	CityFuture.reconcile()
	runner.check(GameState.flag("city%d_plan"%number),"actual delivered or failed service result unblocks plan")
func _exercise(number: int, choice: String) -> void:
	_services(number)
	var c:=CityFuture.chapter(number)
	runner.check(CityFuture.choose(choice)["ok"],"actual civic choice")
	GameState.data["clock"]["minutes"]=int(c["review_at"])
	runner.check(CityFuture.review()["ok"],"actual result review")
	runner.check(CityFuture.definition(number)["id"] in StoryEngine.St()["chapters_done"],"already performed receipts complete chapter")
	var journals: int=GameState.data["ledger"]["journal"].size()
	CityFuture.reconcile();StoryEngine.check()
	runner.eq(GameState.data["ledger"]["journal"].size(),journals,"already done replay creates no cash")
	GameState.new_game({"name":"Closed citizen","seed":12345})
	_start(number)
	GameState.data["clock"]["minutes"]=int(CityFuture.chapter(number)["deadline"])+1
	CityFuture.reconcile();StoryEngine.check()
	runner.check(CityFuture.definition(number)["id"] in StoryEngine.St()["chapters_done"],"expired impossible chapter never soft-locks")
	runner.check(Ledger.check_balanced(),"civic books balanced")
func test_chapter19_already_done_and_impossible() -> void:_exercise(19,"balanced")
func test_chapter20_already_done_and_impossible() -> void:_exercise(20,"transparent")
func test_chapter21_already_done_and_impossible() -> void:_exercise(21,"delay")
func test_chapter22_already_done_and_impossible() -> void:_exercise(22,"culture")
func test_chapter23_already_done_and_impossible() -> void:_exercise(23,"neutral")
func test_chapter24_already_done_and_impossible() -> void:_exercise(24,"economy")
func test_paid_services_are_purchase_jobs_and_never_owner_revenue() -> void:
	_services(19)
	var c:=CityFuture.chapter(19)
	runner.eq(c["contracts"].size(),3,"three actual industry supplier contracts")
	for receipt in c["contracts"]:
		var job:=Jobs.get_job(receipt["job"])
		runner.eq(job["direction"],"purchase","purchased services cannot make revenue")
		runner.eq(job["paid_cost"],job["price"],"actual cost paid")
	runner.eq(Ledger.balance("player","revenue"),0,"no personal civic windfall")
	runner.eq(Ledger.balance(CityFuture.sponsor(),"revenue"),0,"appropriation is not revenue")
func test_old_save_has_no_city_effect_and_effects_expire() -> void:
	runner.eq(CityFuture.demand_factor("hotel"),1,"old save unchanged")
	_services(24)
	runner.check(CityFuture.choose("economy")["ok"],"actual event plan")
	runner.check(CityFuture.demand_factor("energy")<1,"simultaneous crisis is an actual downside")
	GameState.data["clock"]["minutes"]+=15*Clock.DAY
	runner.eq(CityFuture.demand_factor("energy"),1,"crisis and peak fully expire")

func test_pending_purchase_save_load_and_closed_owner_can_use_partner() -> void:
	load("res://tests/unit/test_global.gd").new()._setup()
	_start(19)
	CityFuture.read_brief()
	runner.check(CityFuture.procure("fund")["ok"],"owned company pays actual service budget")
	var state: Dictionary=CityFuture.S().duplicate(true)
	runner.check(SaveSystem.save(99),"pending civic purchase saved")
	runner.check(SaveSystem.load_data(99),"pending civic purchase loaded")
	runner.eq(CityFuture.chapter(19)["contracts"][0]["job"],state["chapters"]["19"]["contracts"][0]["job"],"same actual paid purchase survives")
	Insolvency.close_company()
	GameState.data["clock"]["minutes"]+=8*Clock.DAY
	CityFuture.reconcile()
	runner.check(GameState.flag("city19_plan"),"closed payer receipts are resolved as closed rather than waiting forever")
	runner.check(CityFuture.choose("balanced")["ok"],"citizen may still submit honest failed plan")
	runner.check(Ledger.check_balanced(),"closure does not revive civic money")
func test_insufficient_cash_double_purchase_and_invalid_choices_preserve_money() -> void:
	_start(19)
	Ledger.expense("player","other",28000,"QA exhausted personal funds")
	var before:=Ledger.cash("player")
	runner.check(not CityFuture.procure("fund",true)["ok"],"unaffordable premium plan is blocked")
	runner.eq(Ledger.cash("player"),before,"blocked plan spends nothing")
	runner.check(CityFuture.procure("partner")["ok"],"paid public partnership is a real zero-private-cash alternative")
	var public_cash:=Ledger.cash(CityFuture.sponsor())
	runner.check(not CityFuture.procure("partner")["ok"],"no duplicate paid order")
	runner.eq(Ledger.cash(CityFuture.sponsor()),public_cash,"no duplicate city spending")
	runner.check(not CityFuture.choose("made_up")["ok"],"unknown policy rejected")
func test_secret_favor_is_disqualified_without_a_bribe_transaction() -> void:
	_services(20)
	var cash:=Ledger.cash(CityFuture.sponsor())
	runner.check(CityFuture.choose("favor")["ok"],"prohibited approach has a recorded bad result")
	runner.check(GameState.flag("city_disqualified"),"bid disqualified")
	runner.check(not CityFuture.chapter(20)["result"]["won"],"no illicit tender win")
	runner.eq(Ledger.cash(CityFuture.sponsor()),cash,"no bribe is paid")
func test_unowned_team_has_multiple_available_civic_choices_and_event_risks() -> void:
	for num in range(19,25):
		GameState.new_game({"name":"Citizen","seed":99001})
		_services(num)
		var count:=0
		for choice in CityFuture.definition(num)["choices"]:
			if CityFuture.choice_block(choice)=="":count+=1
		runner.check(count>=2,"at least two real civic choices without owning an industry")
func test_civic_modal_builds_and_never_recommends_a_political_choice() -> void:
	_services(23)
	var modal:=CityFutureModal.new()
	modal.body=UIK.vbox();modal.add_child(modal.body);modal.build()
	for choice in ["green","enterprise","neutral"]:
		runner.check(modal.find_child("CityChoice_"+choice,true,false)!=null,"all election choices visible")
	for button in modal.find_children("CityChoice_*","Button",true,false):
		runner.check(not button.get_meta("civic_primary",false),"political choices are neutral")
	modal.free()

func _team() -> String:
	Company.register("Civic Team","ecommerce","22 Founders Lane")
	Company.open_business_account(15000)
	Staff.register_employer();Staff.post_job("support")
	Staff.handle("stf.applicants",{"role":"support"})
	var person: Dictionary=Staff.S()["applicants"][0]
	runner.check(Staff.hire(person["id"])["ok"],"actual advertised applicant hired")
	return str(person["id"])
func test_talent_salary_and_volunteer_have_real_time_payroll_and_brand_tradeoffs() -> void:
	var person:=_team()
	_services(22)
	var weekly:=Staff.weekly_payroll()
	runner.check(CityFuture.choose("salary")["ok"],"salary policy accepted")
	runner.check(Staff.weekly_payroll()>weekly,"future payroll actually increases")
	runner.check(person in CityFuture.chapter(22)["result"]["people"],"affected actual employee recorded")
	GameState.new_game({"name":"Independent citizen","seed":12345})
	_services(22)
	var clock:=Clock.now();var cash:=Ledger.cash("player")
	runner.check(CityFuture.choose("volunteer")["ok"],"second teamless choice available")
	runner.eq(Clock.now()-clock,int(CityFuture.cfg()["volunteer_minutes"]),"mentoring spends real player time")
	runner.eq(Ledger.cash("player"),cash,"volunteering makes no fake income")
	runner.eq(CityFuture.S()["brand"],CityFuture.cfg()["volunteer_brand_gain"],"volunteer has lower brand gain than culture")
func test_options_vest_only_for_surviving_staff_without_cash_or_share_creation() -> void:
	_team();_services(22)
	GameState.data["cap_table"]={"founder":.7,"investors":.3}
	var carrying:=Ledger.balance("player","investments")
	var cash:=Ledger.cash("player")
	runner.check(CityFuture.choose("options")["ok"],"board approved genuine option commitment")
	var offer: Dictionary=CityFuture.S()["options"][0]
	CityFuture.reconcile()
	runner.eq(offer["status"],"pending","no immediate option vesting")
	# Resolve the actual poaching roll early and check it cannot repeat at vesting.
	CityFuture.chapter(22)["poaching_resolved"]=true
	GameState.data["clock"]["minutes"]=int(offer["vest_at"])
	CityFuture.reconcile()
	runner.eq(offer["status"],"vested","remaining employee receives earned shares")
	var shares: Dictionary=GameState.data["cap_table"]
	runner.check(absf(float(shares["founder"])+float(shares["investors"])+float(shares["employees"])-1)<.000001,"shares conserved")
	runner.eq(shares["investors"],.3,"outside investors are not diluted by founder grant")
	runner.check(Ledger.balance("player","investments")<carrying,"founder carrying value transferred")
	runner.eq(Ledger.cash("player"),cash,"options create no cash")
	var journal: int=GameState.data["ledger"]["journal"].size();CityFuture.reconcile()
	runner.eq(GameState.data["ledger"]["journal"].size(),journal,"vesting cannot post twice")
	runner.check(Ledger.check_balanced(),"option grant books balanced")
func test_departed_team_forfeits_unvested_options_and_cannot_resurrect_closed_owner() -> void:
	var person:=_team();_services(22)
	runner.check(CityFuture.choose("options")["ok"],"real commitment made")
	Staff._quit(Staff.S()["people"][person])
	var offer: Dictionary=CityFuture.S()["options"][0]
	GameState.data["clock"]["minutes"]=int(offer["vest_at"])
	CityFuture.reconcile()
	runner.eq(offer["status"],"forfeited","resigned employee cannot vest")
	runner.eq(GameState.data["cap_table"].get("employees",0),0,"no invented employee holding")
	Insolvency.close_company();CityFuture.reconcile()
	runner.check(Ledger.check_balanced(),"closed option issuer books remain balanced")
func test_material_returns_reduce_a_cost_actually_paid_and_never_repeat() -> void:
	_services(20)
	var receipt: Dictionary=CityFuture.chapter(20)["contracts"][0]
	# Search a real successful supplier seed; no delivery status or costs are fabricated.
	if receipt["status"]!="delivered":
		GameState.new_game({"name":"Material return","seed":4});_services(20)
		receipt=CityFuture.chapter(20)["contracts"][0]
	runner.eq(receipt["status"],"delivered","actual material supplier delivery")
	var cash:=Ledger.cash(receipt["payer"]);var units: int=receipt["delivered_units"]
	runner.check(CityFuture.choose("low_bid")["ok"],"reduced specification selected")
	runner.check(Ledger.cash(receipt["payer"])>cash,"supplier credits actual unused materials")
	runner.check(int(receipt["delivered_units"])<units,"returned material removed from project")
	runner.eq(Ledger.balance(receipt["payer"],"revenue"),0,"cost credit is not revenue")
	cash=Ledger.cash(receipt["payer"]);runner.check(not CityFuture.choose("low_bid")["ok"],"duplicate decision blocked")
	runner.eq(Ledger.cash(receipt["payer"]),cash,"no second return credit")
func test_election_changes_real_subsidy_quotes_and_keeps_rent_independent() -> void:
	var baseline:=Energy.grant_amount("install",1000)
	_services(23);var rent:=World.rent_mult();CityFuture.choose("green")
	runner.eq(GameState.data["npcs"]["mayor_green"]["civic_support"],1,"actual candidate relationship records participation")
	var factor:=CityFuture.policy_factor("subsidy")
	runner.check(absf(Energy.grant_amount("install",1000)-baseline*factor)<.01,"actual quoted energy subsidy follows elected policy")
	runner.eq(World.rent_mult(),rent,"zoning does not silently change lease rent")
	runner.check(CityFuture.policy_factor("tax")!=1 and CityFuture.policy_factor("zoning")!=1,"different tax and construction policies active")
func test_every_industry_has_temporary_peak_and_crises_fade_gradually() -> void:
	_services(24);CityFuture.S()["expo_awarded"]=true;CityFuture.choose("resilient")
	var start:=Clock.now();var disrupted:=CityFuture.demand_factor("energy")
	for industry in ["ecommerce","cafe","saas","hotel","automotive","manufacturing","media","real_estate","logistics","freelance","energy","trade"]:
		runner.check(CityFuture.demand_factor(industry)>1,"actual peak and resilient disruption apply to "+industry)
	GameState.data["clock"]["minutes"]=start+4*Clock.DAY
	runner.check(CityFuture.demand_factor("energy")>disrupted,"crisis fades instead of sticking")
	GameState.data["clock"]["minutes"]=start+15*Clock.DAY
	runner.eq(CityFuture.demand_factor("energy"),1,"peak and crisis end")
func test_transition_changes_actual_automotive_demand_and_paid_energy_asset() -> void:
	var baseline:=Automotive.demand_mult()
	_services(21)
	var cash:=Ledger.cash(CityFuture.sponsor())
	runner.check(CityFuture.choose("charging")["ok"],"actual charging asset purchased")
	runner.check(Ledger.cash(CityFuture.sponsor())<cash,"charging network cost actually paid")
	runner.check(CityFuture.chapter(21).has("network_asset"),"real maintainable asset recorded")
	runner.check(Automotive.demand_mult()<baseline,"fuel vehicle demand changes")
	runner.check(CityFuture.demand_factor("energy")>1,"charging boosts energy demand")
	runner.check(Ledger.check_balanced(),"charging asset books balanced")

func test_zoning_changes_actual_construction_due_and_property_tax_ledger() -> void:
	var re=load("res://tests/unit/test_real_estate.gd").new();re.runner=runner
	var entity: String=re.setup(2500000)
	RealEstate.buy("maple_1",.2,25);Compliance.apply_permit("building");Clock.advance(7*Clock.DAY)
	CityFuture.S()["elected"]="enterprise"
	var start:=Clock.now();var scale: Dictionary=RealEstate.cfg()["development"]["small"]
	runner.check(RealEstate.develop("small","City policy tower")["ok"],"actual funded permitted construction")
	var project: Dictionary=RealEstate.S()["project"]
	runner.eq(int(project["due"])-start,ceili(float(scale["days"])*CityFuture.policy_factor("zoning"))*Clock.DAY,"elected zoning changes actual due date")
	runner.eq(project["budget"],scale["cost"],"faster zoning does not invent cost savings")
	var cash:=Ledger.cash(entity)
	var home: Dictionary=RealEstate.S()["properties"]["maple_1"]
	var cost:=snappedf(RealEstateMarket.value(home)*float(RealEstate.cfg()["monthly_tax_rate"])*CityFuture.policy_factor("tax")+float(RealEstate.cfg()["monthly_management"]),.01)
	GameState.data["clock"]["minutes"]=29*Clock.DAY+9*60
	RealEstate.on_hour(Clock.now(),9)
	cost=snappedf(RealEstateMarket.value(home)*float(RealEstate.cfg()["monthly_tax_rate"])*CityFuture.policy_factor("tax")+float(RealEstate.cfg()["monthly_management"]),.01)
	runner.check(absf(cash-Ledger.cash(entity)-cost)<.011,"actual monthly property tax payment uses election rate")
	runner.check(Ledger.check_balanced(),"policy cost postings balance")
func test_viewing_options_does_not_cast_board_vote_or_spend_money() -> void:
	_team();_services(22)
	var vote: Dictionary=CapitalMarket.S().get("last_vote",{}).duplicate(true)
	var money:=Ledger.cash(GameState.company_id())
	runner.eq(CityFuture.choice_block("options"),"","preview eligible")
	runner.eq(CapitalMarket.S().get("last_vote",{}),vote,"reading screen does not cast a board vote")
	runner.eq(Ledger.cash(GameState.company_id()),money,"reading choice does not spend")

func test_failed_suppliers_cannot_make_negative_quality_or_material_refund() -> void:
	_start(20);CityFuture.read_brief();CityFuture.procure("partner")
	var probe:=RandomNumberGenerator.new();var failure_seed: int=-1
	for seed_value in 10000:
		probe.seed=seed_value
		if probe.randf()<float(CityFuture.cfg()["contract_failure_basic"]) and probe.randf()<float(CityFuture.cfg()["contract_failure_basic"]) and probe.randf()<float(CityFuture.cfg()["contract_failure_basic"]):
			failure_seed=seed_value;break
	runner.check(failure_seed>=0,"deterministic actual all-supplier-failure seed exists")
	GameState.rng.seed=failure_seed
	GameState.data["clock"]["minutes"]+=8*Clock.DAY;CityFuture.reconcile()
	runner.check(CityFuture.chapter(20)["contracts"].all(func(r):return r["status"]=="failed"),"actual paid suppliers all fail")
	var cash:=Ledger.cash(CityFuture.sponsor())
	runner.check(CityFuture.choose("low_bid")["ok"],"honest failed low-cost plan can continue")
	runner.eq(CityFuture.chapter(20)["result"]["quality"],0,"quality never falls below zero percent")
	runner.eq(Ledger.cash(CityFuture.sponsor()),cash,"failed undelivered materials cannot be refunded as unused stock")

func test_late_submission_cannot_buy_assurance_or_change_failed_outcome() -> void:
	_services(19)
	GameState.data["clock"]["minutes"]=int(CityFuture.chapter(19)["deadline"])+1
	var cash:=Ledger.cash(CityFuture.sponsor())
	var journals: int=GameState.data["ledger"]["journal"].size()
	runner.check(not CityFuture.choose("premium")["ok"],"late bid blocked before paying assurance")
	runner.eq(CityFuture.chapter(19)["status"],"expired","deadline retains honest failed outcome")
	runner.eq(CityFuture.chapter(19)["decision"],"","no late decision recorded")
	runner.eq(Ledger.cash(CityFuture.sponsor()),cash,"late bid spends no public money")
	runner.eq(GameState.data["ledger"]["journal"].size(),journals,"late bid posts no journal")
	StoryEngine.check()
	runner.check("ch19_expo_bid" in StoryEngine.St()["chapters_done"],"expired proposal still advances chapter")

func test_return_to_world_closes_the_underlying_company_os() -> void:
	_start(19);CityFuture.read_brief();CityFuture.procure("partner")
	UIRoot.open_modal(CompanyOS.new("home_laptop"))
	await runner.get_tree().process_frame
	UIRoot.open_modal(CityFutureModal.new())
	await runner.get_tree().process_frame
	while UIRoot.top_modal() is InfoModal:
		UIRoot.top_modal().close()
		await runner.get_tree().process_frame
	runner.check(UIRoot.top_modal() is CityFutureModal,"civic screen visible after first-use help")
	if not UIRoot.top_modal() is CityFutureModal:return
	var civic: CityFutureModal=UIRoot.top_modal()
	var button:=civic.find_child("city_wait",true,false) as Button
	runner.check(button!=null,"real wait-for-delivery action exists")
	button.pressed.emit()
	await runner.get_tree().process_frame
	runner.eq(UIRoot.top_modal(),null,"return-to-world does not leave OS blocking the player")
