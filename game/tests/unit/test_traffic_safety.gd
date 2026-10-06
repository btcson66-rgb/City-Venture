extends RefCounted
var runner
func red() -> void: GameState.data["clock"]["minutes"] = 18*30+9
func hit(speed := 70.0) -> Dictionary:
	red()
	return TrafficSafety.hit(speed,"civic_center",Vector2(560,424))
func test_speed_boundaries_and_invalid() -> void:
	for pair in [[0.0,"glancing"],[17.99,"glancing"],[18.0,"minor"],[54.99,"minor"],[55.0,"major"],[85.0,"major"],[-1.0,"none"],[INF,"none"]]: runner.eq(TrafficSafety.grade(pair[0]),pair[1],"speed classification")
func test_green_crosswalk_never_hits_and_red_player_fault() -> void:
	GameState.data["clock"]["minutes"] = 18*30
	runner.check(TrafficSafety.protected_crossing("civic_center",Vector2(560,424)),"green protection")
	runner.check(not TrafficSafety.hit(85,"civic_center",Vector2(560,424))["ok"],"no green injury")
	runner.check(hit()["ok"],"red actual collision")
	runner.check(not TrafficSafety.latest()["counterparty_fault"],"red pedestrian fault")
func test_light_change_mid_crossing_keeps_clearance_only_briefly() -> void:
	GameState.data["clock"]["minutes"] = 18*40+7
	runner.check(TrafficSafety.protected_crossing("civic_center",Vector2(560,424)),"entered on green")
	GameState.data["clock"]["minutes"] = 18*40+9
	runner.check(TrafficSafety.protected_crossing("civic_center",Vector2(560,430)),"red mid-crossing keeps clearance")
	runner.check(not TrafficSafety.hit(70,"civic_center",Vector2(560,430))["ok"],"no injury during clearance")
	GameState.data["clock"]["minutes"] = 18*40+14
	runner.check(not TrafficSafety.protected_crossing("civic_center",Vector2(560,430)),"loitering on red loses clearance")
	runner.check(not TrafficSafety.protected_crossing("civic_center",Vector2(9000,9000)),"off crosswalk")
	GameState.data["clock"]["minutes"] = 18*41+9
	runner.check(not TrafficSafety.protected_crossing("civic_center",Vector2(560,424)),"stepping on during red is unprotected")
func test_only_the_carriageway_can_be_struck() -> void:
	runner.check(TrafficSafety.on_road("startup_hub",Vector2(100,470)),"road lane")
	runner.check(TrafficSafety.on_road("old_town",Vector2(100,470)),"cobbled road variant")
	runner.check(not TrafficSafety.on_road("startup_hub",Vector2(100,486)),"kerb beside the lane is safe")
func test_minor_medicine_actual_fee_and_recovery() -> void:
	hit(30)
	Clock.advance(3)
	runner.eq(TrafficSafety.speed_multiplier(),0.6,"injury slows")
	var before := Ledger.cash("player")
	var result := TrafficSafety.treat()
	runner.check(result["ok"],"medicine bought")
	runner.eq(before-Ledger.cash("player"),35.0,"actual medicine fee")
	runner.eq(TrafficSafety.speed_multiplier(),1.0,"medicine restores walking")
	runner.check(not TrafficSafety.treat()["ok"],"cannot repeat treatment")
func test_health_claim_only_preexisting_policy_and_real_medical_cost() -> void:
	runner.check(TrafficSafety.buy_policy()["ok"],"bought policy")
	runner.check(not TrafficSafety.buy_policy()["ok"],"no duplicate premium")
	hit()
	var before := Clock.now()
	var r := TrafficSafety.treat()
	runner.eq(r["claim"],1530.0,"85 percent of incurred bill")
	runner.check(Clock.now()-before >= Clock.DAY and Clock.now()-before <= 3*Clock.DAY,"one to three actual days")
	runner.eq(Ledger.balance("player","exp:medical"),270.0,"claim offsets the medical expense (net out-of-pocket)")
	runner.eq(Ledger.balance("player","other_income"),0.0,"reimbursement is never income")
	runner.check(Ledger.check_balanced(),"balanced")
func test_buying_policy_after_collision_does_not_cover_old_bill() -> void:
	hit()
	TrafficSafety.buy_policy()
	runner.eq(TrafficSafety.treat()["claim"],0.0,"no retroactive insurance")
func test_hospital_runs_existing_invoice_scheduler_and_living_costs() -> void:
	Careers.start_freelance()
	Careers.accept(Careers.F()["offers"][0]["id"])
	var g: Dictionary = Careers.active_gigs()[0]
	# An already completed legacy service invoice remains payable while its owner is hospitalized.
	g.erase("workflow")
	g["done"] = g["hours"]
	g["terms"] = 1
	Careers._deliver(g)
	hit()
	TrafficSafety.treat()
	runner.eq(g["status"],"paid","existing business payment ran during admission")
	runner.check(Ledger.balance("player","exp:living") > 0,"daily costs ran")
	runner.eq(Ledger.balance("player","accounts_receivable"),0.0,"invoice collected exactly once")
func test_save_roundtrip_and_old_save_lazy_default() -> void:
	runner.check(not GameState.data.has("traffic_safety"),"old state no field")
	var journal: Dictionary = GameState.data["ledger"].duplicate(true)
	TrafficSafety.S()
	runner.eq(GameState.data["ledger"],journal,"migration no money")
	hit(30)
	var state: Dictionary = JSON.parse_string(JSON.stringify(GameState.data))
	GameState.data = state
	runner.eq(TrafficSafety.latest()["severity"],"minor","injury restored")
	runner.check(TrafficSafety.treat()["ok"],"resumed medicine")
func test_injury_expires_and_contact_cooldown() -> void:
	runner.check(hit(30)["ok"],"first hit")
	runner.check(not TrafficSafety.hit(30,"civic_center",Vector2(600,424))["ok"],"no repeat contact")
	Clock.advance(3*Clock.DAY)
	runner.eq(TrafficSafety.speed_multiplier(),1.0,"natural recovery")
func test_no_cash_emergency_payable_and_old_debt_remains_reachable() -> void:
	hit()
	var cash := Ledger.cash("player")
	Ledger.expense("player","other",cash,"Test removes cash")
	TrafficSafety.treat()
	var a := TrafficSafety.latest()
	runner.eq(a["debt"],1800.0,"emergency bill remains payable")
	runner.check(not TrafficSafety.pay_debt(int(a["id"])),"cannot forgive unpaid bill")
	runner.check(Ledger.check_balanced(),"balanced emergency")
func test_counterparty_choices_capped_no_double_compensation() -> void:
	hit(30)
	var a := TrafficSafety.latest()
	a["counterparty_fault"] = true # explicit liability fixture, not a claimed random observation.
	runner.check(not TrafficSafety.settle()["ok"],"no claim before expense")
	TrafficSafety.treat()
	runner.check(TrafficSafety.settle(true)["pending"],"procedure waits")
	runner.check(not TrafficSafety.settle()["ok"],"cannot collect early")
	Clock.advance(7*Clock.DAY)
	runner.eq(TrafficSafety.settle(true)["amount"],35.0,"verified reimbursement equals actual fee")
	runner.check(not TrafficSafety.settle()["ok"],"no duplicate settlement")
	runner.check(Ledger.check_balanced(),"balanced compensation")
func test_monthly_policy_no_cash_expiry_and_driver_quote_no_income() -> void:
	TrafficSafety.buy_policy()
	S_clear_cash()
	Clock.advance(31*Clock.DAY)
	runner.check(not TrafficSafety.insured(),"policy expires without cash")
	runner.check(not TrafficSafety.S()["renew"],"failed renewal stops")
	var seq: int = GameState.data["ledger"]["seq"]
	runner.eq(TrafficSafety.driver_quote(1000,0.8)["covered"],800.0,"future driver liability insurance hook")
	runner.eq(GameState.data["ledger"]["seq"],seq,"hook never books invented income")
func S_clear_cash() -> void:
	Ledger.expense("player","other",Ledger.cash("player"),"Test removes cash")

func test_glancing_contact_does_not_hide_previous_treatable_injury() -> void:
	hit(30)
	Clock.advance(31)
	TrafficSafety.hit(10,"civic_center",Vector2(620,424))
	runner.eq(TrafficSafety.latest()["severity"],"glancing","new glancing contact recorded")
	runner.check(TrafficSafety.treat()["ok"],"original minor injury still treatable")
	runner.eq(Ledger.balance("player","exp:medical"),35.0,"only actual treatment billed")
func test_partial_settlement_and_history_debt_survive_new_accident() -> void:
	hit(30)
	var first := TrafficSafety.latest()
	first["counterparty_fault"] = true
	TrafficSafety.treat()
	Clock.advance(31)
	TrafficSafety.hit(30,"civic_center",Vector2(620,424))
	TrafficSafety.treat()
	runner.eq(TrafficSafety.settle(false,int(first["id"]))["amount"],26.25,"past medical settlement still available")
	var snapshot: Dictionary = JSON.parse_string(JSON.stringify(GameState.data))
	GameState.data = snapshot
	runner.check(not TrafficSafety.settle(false,int(first["id"]))["ok"],"saved settlement cannot duplicate")
func test_closed_company_does_not_block_personal_treatment() -> void:
	Company.register("Traffic closure","ecommerce","22 Founders Lane")
	GameState.data["entities"][GameState.company_id()]["closed"] = true
	hit(30)
	runner.check(TrafficSafety.treat()["ok"],"personal clinic still works after closure")
	runner.check(Ledger.check_balanced(),"closed company and personal books balance")

func test_actual_save_system_preserves_pending_claim_and_no_duplicate_bill() -> void:
	hit(30)
	TrafficSafety.latest()["counterparty_fault"] = true
	TrafficSafety.treat()
	TrafficSafety.settle(true)
	var seq: int = GameState.data["ledger"]["seq"]
	runner.check(SaveSystem.save(9),"actual save file written")
	GameState.data["traffic_safety"] = {}
	runner.check(SaveSystem.load_data(9),"actual save loaded")
	runner.check(not TrafficSafety.treat()["ok"],"restored treatment not duplicated")
	runner.eq(GameState.data["ledger"]["seq"],seq,"load no new ledger entry")
	runner.check(not TrafficSafety.settle(true)["ok"],"pending claim retains due date")
func test_clinic_primary_and_insufficient_medicine_cash() -> void:
	hit(30)
	S_clear_cash()
	var modal := TrafficModal.new()
	UIRoot.open_modal(modal)
	await runner.get_tree().process_frame
	var treatment := modal.find_child("Treatment",true,false) as Button
	runner.check(treatment.disabled,"medicine requires cash")
	var primaries := 0
	for b in modal.find_children("*","Button",true,false):
		var box = b.get_theme_stylebox("normal")
		if box is StyleBoxTexture and box.texture == Art.tex("ui/button_primary"): primaries += 1
	runner.eq(primaries,0,"disabled treatment is not a misleading primary")
	modal.close()
	await runner.get_tree().process_frame

func test_settlement_credits_expense_not_income() -> void:
	hit(30)
	TrafficSafety.latest()["counterparty_fault"] = true
	TrafficSafety.treat()
	TrafficSafety.settle(false)
	runner.eq(Ledger.balance("player","other_income"),0.0,"no income from settlement")
	runner.check(Ledger.balance("player","exp:medical") < 35.0,"settlement reduces the medical expense")
func test_hospital_stay_pauses_replies_meetings_and_appointment() -> void:
	var t0 := Clock.now()
	GameState.add_message("marcus","Reply soon",{"expires":t0+Clock.DAY,"default_reply":"ack"})
	var mid: String = GameState.data["messages"].back()["id"]
	PhoneMessages.S()["agenda"].append({"id":"MEET-X","npc":"marcus","at":t0+Clock.DAY,"until":t0+Clock.DAY+60,"location":"district:civic_center","conversation":"","status":"planned"})
	hit()
	var days_before := Clock.now()
	var r := TrafficSafety.treat()
	var stay := Clock.now()-days_before
	runner.check(stay >= Clock.DAY,"admitted")
	var m := PhoneMessages.get_message(mid)
	runner.check(not m.has("answered"),"reply did not expire during admission")
	runner.eq(int(m["expires"]),t0+Clock.DAY+stay,"reply deadline moved by the stay")
	var meeting: Dictionary = PhoneMessages.S()["agenda"].back()
	runner.eq(meeting["status"],"planned","meeting not missed")
	runner.eq(int(meeting["at"]),t0+Clock.DAY+stay,"meeting moved by the stay")
	runner.check(r["ok"],"treated")
func test_hospital_stay_ends_before_a_chapter_deadline() -> void:
	var deadline := Clock.now()+Clock.DAY+300
	CityFuture.S()["chapters"]["11"] = {"number":11,"status":"active","decision":"","deadline":deadline,"contracts":[]}
	hit()
	var r := TrafficSafety.treat()
	runner.check(Clock.now() < deadline,"chapter deadline not passed during admission")
	runner.check(r["days"] <= 1,"stay capped to the whole days that fit")
	runner.check(TrafficSafety.latest()["discharged_early"] or r["days"] >= 1,"early discharge recorded or full stay fit")
func test_hospital_with_imminent_hard_deadline_discharges_immediately() -> void:
	var deadline := Clock.now()+600
	CityFuture.S()["chapters"]["11"] = {"number":11,"status":"active","decision":"","deadline":deadline,"contracts":[]}
	hit()
	var before := Clock.now()
	var r := TrafficSafety.treat()
	runner.eq(r["days"],0,"no admission when a deadline is hours away")
	runner.eq(Clock.now(),before,"no time skipped")
	runner.check(TrafficSafety.latest()["discharged_early"],"warning flag set")
