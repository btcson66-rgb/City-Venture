extends RefCounted
var runner
func _finish(id: String) -> void:
	PersonalLife.meet(id)
	# Fixture: the relationship already exists through events and gifts; requests alone never reach Partner.
	PersonalLife.change(id,60);PersonalLife.note_kind(id,"event");PersonalLife.note_kind(id,"gift")
	for index in 3:runner.check(PersonalLife.request_done(id,index,1)["ok"],"actual request completes: "+id)
func test_affinity_clamps_and_three_stages_do_not_change_demand_or_apr() -> void:
	var demand := Industries.market_demand("ecommerce");var apr: float = float(Bank.offer().get("apr",0))
	PersonalLife.change("maya",-100);runner.eq(PersonalLife.stage("maya"),0,"acquaintance")
	PersonalLife.change("maya",30);runner.eq(PersonalLife.stage("maya"),1,"friend")
	PersonalLife.change("maya",30);runner.eq(PersonalLife.stage("maya"),2,"partner")
	PersonalLife.change("maya",1000);runner.eq(PersonalLife.contact("maya")["affinity"],100.0,"upper bound")
	runner.eq(Industries.market_demand("ecommerce"),demand,"R16 no demand buff")
	runner.eq(Bank.offer().get("apr",0),apr,"R16 no bank buff")
func test_every_authored_chain_unlocks_and_already_done_is_idempotent() -> void:
	runner.check(PersonalLife.stories().size()>=20,"main and industry NPC chains")
	for id in PersonalLife.stories():
		PersonalLife.meet(id)
		runner.check(not PersonalLife.next(id).is_empty(),"defined next action")
		_finish(id)
		var now := Clock.now();var cash := Ledger.cash("player")
		runner.eq(int(PersonalLife.contact(id)["step"]),3,"three requests done")
		runner.check(not PersonalLife.request_done(id,2,1)["ok"],"already done cannot duplicate")
		runner.eq(Clock.now(),now,"already done spends no time")
		runner.eq(Ledger.cash("player"),cash,"already done spends no supplies")
		# Restore actual test funding through equity, never customer revenue.
		Ledger.post("player","Test funding",[{"acct":"cash","dr":1000},{"acct":"equity","cr":1000}],{"type":"capital"})
	runner.check(Ledger.check_balanced(),"all chains balance")
func test_every_chain_no_longer_possible_after_originating_company_closes() -> void:
	Company.register("Contact firm","ecommerce","22 Founders Lane")
	var entity := GameState.company_id()
	for id in PersonalLife.stories():
		PersonalLife.meet(id)
		PersonalLife.contact(id)["entity"]=entity
	GameState.data["entities"][entity]["closed"]=Clock.now()
	PersonalLife.on_company_closed(entity)
	for id in PersonalLife.stories():
		var cash := Ledger.cash("player")
		runner.check(not PersonalLife.next(id)["ok"],"closed chain has next-step explanation")
		runner.check(not PersonalLife.request_done(id,0,1)["ok"],"closed request cannot run")
		runner.check(not PersonalLife.referral(id)["ok"],"closed referral cannot be issued")
		runner.eq(Ledger.cash("player"),cash,"closed entity cannot spend")
func test_unknown_contact_stage_gate_and_low_quality_retry_costs_real_time() -> void:
	runner.check(not PersonalLife.next("sam")["ok"],"must meet person")
	PersonalLife.meet("sam")
	var c := PersonalLife.contact("sam");c["step"]=1
	runner.check(not PersonalLife.next("sam")["ok"],"friend stage gate")
	c["step"]=0
	var now := Clock.now();var energy := PersonalLife.energy()
	runner.check(not PersonalLife.request_done("sam",0,0)["ok"],"bad evidence is not accepted")
	runner.eq(c["step"],0,"retry remains possible")
	runner.check(Clock.now()>now and PersonalLife.energy()<energy,"work actually consumed")
func test_gifts_use_preference_paid_once_per_day_and_unknown_is_blocked() -> void:
	runner.check(not PersonalLife.gift("sam","coffee")["ok"],"unknown contact")
	PersonalLife.meet("sam");var cash := Ledger.cash("player")
	runner.check(PersonalLife.gift("sam","coffee")["ok"],"preferred gift")
	runner.eq(PersonalLife.contact("sam")["affinity"],6.0,"preference matters")
	runner.eq(Ledger.cash("player"),cash-8,"actual purchase")
	runner.check(not PersonalLife.gift("sam","book")["ok"],"cannot gift spam")
func test_monthly_event_has_date_cost_new_people_and_no_duplicate() -> void:
	var e: Dictionary=PersonalLife.cfg()["events"]["chamber"]
	runner.check(not PersonalLife.attend("chamber")["ok"],"not anytime")
	GameState.data["clock"]["minutes"]=4*Clock.DAY+18*60
	var cash := Ledger.cash("player");var now := Clock.now()
	runner.check(PersonalLife.event_available(e),"correct monthly window")
	runner.check(PersonalLife.attend("chamber")["ok"],"real attendance")
	runner.eq(Ledger.cash("player"),cash-65,"meal charged")
	runner.eq(Clock.now(),now+120,"two hours consumed")
	runner.check(PersonalLife.known("sam"),"met new person")
	runner.check(not PersonalLife.attend("chamber")["ok"],"already attended")
func test_stress_illness_two_real_choices_and_timeout_recover_without_permanent_pause() -> void:
	PersonalLife.S()["stress"]=90;PersonalLife.on_hour(Clock.now(),12)
	runner.check(PersonalLife.ill(),"high stress illness")
	var cash := Ledger.cash("player");var now := Clock.now()
	runner.check(PersonalLife.recover(true)["ok"],"medical recovery")
	runner.eq(Ledger.cash("player"),cash-80,"medical fee")
	runner.eq(Clock.now(),now+90,"shorter recovery")
	PersonalLife.S()["illness_until"]=Clock.now()+3*Clock.DAY
	now=Clock.now();cash=Ledger.cash("player")
	runner.check(PersonalLife.recover(false)["ok"],"free recovery alternative")
	runner.eq(Ledger.cash("player"),cash,"no fee")
	runner.eq(Clock.now(),now+480,"longer rest tradeoff")
	PersonalLife.S()["illness_until"]=Clock.now()+1
	PersonalLife.S()["stress"]=100
	GameState.data["clock"]["minutes"]+=2
	PersonalLife.on_hour(Clock.now(),12)
	runner.check(not PersonalLife.ill() and float(PersonalLife.S()["stress"])<=55,"timeout automatically resolves")
func test_fatigue_changes_response_window_and_never_directly_deducts_score() -> void:
	var g := PersonalRequestGame.new(PersonalLife.stories()["maya"]["steps"][0])
	g.phase="play";g.points=.8;g._round_t=0
	PersonalLife.S()["energy"]=100;g._process(1);var rested := g._round_t
	PersonalLife.S()["energy"]=0;g._round_t=0;g._process(1)
	runner.check(g._round_t>rested,"shorter actual reaction time")
	runner.eq(g.points,.8,"no direct score penalty")
	g.free()
func test_sleep_and_rest_restore_and_no_sleep_debt_accumulation() -> void:
	PersonalLife.work(500);PersonalLife.S()["energy"]=1;PersonalLife.S()["stress"]=50
	PersonalLife.sleep_begin();PersonalLife.on_hour(Clock.now(),20)
	runner.eq(PersonalLife.S()["stress"],50,"sleep skips daily stress")
	PersonalLife.sleep_end(480)
	runner.check(PersonalLife.energy()>90 and float(PersonalLife.S()["stress"])<50,"sleep restores")
	runner.eq(PersonalLife.S()["work_minutes"],0,"continuous work reset")
func test_old_save_lazy_state_and_save_load_preserves_contact_health_and_no_double_reward() -> void:
	GameState.data.erase("personal_life")
	runner.eq(PersonalLife.energy(),100.0,"legacy state neutral")
	_finish("maya");PersonalLife.S()["stress"]=42
	var state: Dictionary = JSON.parse_string(JSON.stringify(PersonalLife.S()))
	SaveSystem.save(7);GameState.data.erase("personal_life");SaveSystem.load_data(7)
	runner.eq(PersonalLife.S(),state,"normal save/load")
	runner.check(not PersonalLife.request_done("maya",2,1)["ok"],"reward remains consumed")
func test_actual_supplier_payment_is_honest_only_once_and_fees_do_not_count() -> void:
	var before := float(PersonalLife.contact("ken")["affinity"])
	var result := Ecommerce.buy("tradelink_wholesale","water_bottle",60)
	runner.check(result["ok"],"actual supplier purchase")
	runner.eq(PersonalLife.contact("ken")["affinity"],before+3,"real prepaid supplies count")
	var po := str(result.get("po",result.get("id","")))
	Ledger.expense("player","bank_fees",1,"Bank fee",{"type":"po","id":po})
	runner.eq(PersonalLife.contact("ken")["affinity"],before+3,"fee cannot farm affinity")
func test_referral_uses_jobs_costs_receivable_and_entity_guards() -> void:
	_finish("sam")
	var cash := Ledger.cash("player");var result := PersonalLife.referral("sam")
	runner.check(result["ok"],"earned offer")
	var id := str(result["id"]);runner.eq(PersonalLife.referral("sam")["id"],id,"one offer")
	runner.eq(Ledger.cash("player"),cash,"relationship is not cash")
	Jobs.accept(id)
	runner.check(PersonalLife.referral_work("sam",1)["ok"],"actual agreed work invoices")
	runner.check(Ledger.balance("player","accounts_receivable")>0,"receivable waits thirty days")
	runner.check(Ledger.cash("player")<cash,"actual supplies paid before collection")
	runner.check(not PersonalLife.referral_work("sam",1)["ok"],"already done cannot double invoice")
	runner.check(Ledger.check_balanced(),"referral balanced")

func test_invalid_referral_quality_cannot_charge_or_invoice() -> void:
	_finish("sam");var id := str(PersonalLife.referral("sam")["id"]);Jobs.accept(id)
	var cash := Ledger.cash("player");var now := Clock.now()
	for quality in [NAN,INF,-.1,1.1]:runner.check(not PersonalLife.referral_work("sam",quality)["ok"],"invalid quality rejected")
	runner.eq(Ledger.cash("player"),cash,"invalid input cannot spend")
	runner.eq(Clock.now(),now,"invalid input cannot consume time")
	runner.eq(Jobs.get_job(id)["status"],"active","no phantom invoice")
func test_expired_referral_is_not_reissued_and_cannot_be_accepted() -> void:
	_finish("sam");var id := str(PersonalLife.referral("sam")["id"])
	GameState.data["clock"]["minutes"]=int(Jobs.get_job(id)["expires_at"])+1
	Jobs.expire_offers()
	runner.eq(Jobs.get_job(id)["status"],"expired","offer expires")
	runner.eq(PersonalLife.referral("sam")["id"],id,"expired referral not farmable")
	runner.check(not Jobs.accept(id)["ok"],"no longer possible")
func test_actual_on_time_quality_job_changes_affinity_once_but_late_delivery_hurts() -> void:
	PersonalLife.meet("sam")
	var id := Jobs.offer({"client":"Fleet buyer","scope":"Handover","price":200,"terms":30,"personal_npc":"sam"})
	Jobs.accept(id);Jobs.progress(id,1);Jobs.deliver(id);Jobs.invoice(id)
	runner.eq(PersonalLife.contact("sam")["affinity"],3.0,"actual quality-approved on-time handover")
	Jobs.invoice(id)
	runner.eq(PersonalLife.contact("sam")["affinity"],3.0,"already invoiced cannot farm honesty")
	id=Jobs.offer({"client":"Fleet buyer","scope":"Handover","price":200,"terms":30,"personal_npc":"sam","due":Clock.now()+1})
	Jobs.accept(id);GameState.data["clock"]["minutes"]+=2;Jobs.progress(id,1);Jobs.deliver(id);Jobs.invoice(id)
	runner.eq(PersonalLife.contact("sam")["affinity"],0.0,"late actual handover hurts trust")
func _primaries(node: Node) -> int:
	var result := 1 if node.get_meta("primary_action",false) else 0
	for child in node.get_children():result+=_primaries(child)
	return result
func test_contacts_and_stress_screens_keep_one_primary_and_two_real_recovery_controls() -> void:
	PersonalLife.meet("sam")
	var screen := ContactsModal.new("sam");runner.add_child(screen)
	await runner.get_tree().process_frame
	runner.check(_primaries(screen)<=1,"normal request primary")
	PersonalLife.S()["illness_until"]=Clock.now()+Clock.DAY;screen.rebuild()
	await runner.get_tree().process_frame
	runner.check(_primaries(screen)<=1,"recovery replaces request as primary")
	runner.check(screen.find_child("RecoveryRest",true,false)!=null and screen.find_child("RecoveryMedical",true,false)!=null,"two genuine recovery choices")
	screen.queue_free();await runner.get_tree().process_frame

func test_request_approaches_trade_time_money_and_trust_and_favours_alone_never_make_a_partner() -> void:
	var node: Dictionary=PersonalLife.stories()["maya"]["steps"][1]
	var thorough := PersonalLife.approach_terms(node,"thorough")
	var lean := PersonalLife.approach_terms(node,"lean")
	var hire := PersonalLife.approach_terms(node,"hire")
	runner.check(float(lean["minutes"])<float(thorough["minutes"]) and float(hire["minutes"])<float(lean["minutes"]),"shorter approaches save time")
	runner.check(float(hire["cost"])>float(thorough["cost"]),"hiring costs more")
	runner.check(float(thorough["affinity"])>float(lean["affinity"]) and float(thorough["affinity"])>float(hire["affinity"]),"the careful approach earns most trust")
	PersonalLife.meet("maya")
	for index in 3:
		PersonalLife.change("maya",60.0-float(PersonalLife.contact("maya")["affinity"]) if index>0 else 0)
		var result := PersonalLife.request_done("maya",index,1)
		if index<2:runner.check(result["ok"],"request %d"%index)
		else:runner.check(not result["ok"],"third request needs variety beyond favours")
	PersonalLife.note_kind("maya","event");PersonalLife.note_kind("maya","gift")
	runner.check(PersonalLife.request_done("maya",2,1,"lean")["ok"],"variety unlocks the third request")
	runner.eq(PersonalLife.stage_name("maya"),I18n.t("Trusted contact"),"top stage label")

func test_daily_debt_and_crisis_stress_applies_even_while_sleeping() -> void:
	PersonalLife.S()["stress"] = 10.0
	PersonalLife.sleep_begin()
	PersonalLife.on_hour(Clock.now(), 20)
	PersonalLife.sleep_end(480)
	runner.eq(PersonalLife.S()["stress_day"], Clock.day_index(), "daily processing ran while sleeping")
	var seen := float(PersonalLife.S()["stress"])
	PersonalLife.on_hour(Clock.now(), 20)
	runner.eq(PersonalLife.S()["stress"], seen, "the same day is never processed twice")
