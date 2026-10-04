extends RefCounted
var runner
func setup() -> String:
	Company.register("Mentor Test","retail_online","Riverside");Company.open_business_account(25000)
	Ledger.post(GameState.company_id(),"QA introduction capital",[{"acct":"cash","dr":200000},{"acct":"equity","cr":200000}])
	return GameState.company_id()
func test_manufacturing_trigger_completed_and_impossible() -> void:check_story("manufacturing")
func test_real_estate_trigger_completed_and_impossible() -> void:check_story("real_estate")
func test_media_trigger_completed_and_impossible() -> void:check_story("media")
func test_hotel_trigger_completed_and_impossible() -> void:check_story("hotel")
func test_automotive_trigger_completed_and_impossible() -> void:check_story("automotive")
func test_energy_trigger_completed_and_impossible() -> void:check_story("energy")
func check_story(business: String) -> void:
	var ent:=setup();var id: String="intro_"+business
	var d:=IndustryGuidance.guide(business)
	runner.eq(d["objectives"].size(),4,"four actual steps for "+business)
	runner.check(StoryEngine.side_available(id),"company and capital qualify")
	GameState.data["npcs"][d["mentor"]]={"met":true}
	runner.check(Cond.all(d["objectives"][0]["complete_when"]),"real NPC meeting receipt read")
	runner.check(StoryEngine.start_side_story(id),"accept registered data story")
	var before:=Ledger.cash(ent)
	# Completion receipts test the no-replay path without fabricating financial transactions.
	for o in d["objectives"]:
		if not o["id"] in StoryEngine.St()["done"]:StoryEngine.St()["done"].append(o["id"])
		StoryEngine.St()["active"].erase(o["id"])
	StoryEngine.check()
	runner.eq(StoryEngine.side_progress()[id]["status"],"completed","already did all work completes")
	runner.check(GameState.flag("contact_"+d["mentor"]),"mentor thread contact reward")
	var timelines: int=GameState.data["timeline"].size()
	StoryEngine.check();runner.eq(GameState.data["timeline"].size(),timelines,"no duplicate reward")
	runner.eq(Ledger.cash(ent),before,"no imaginary income")
	runner.check(not StoryEngine.start_side_story(id),"already completed not accepted twice")
	StoryEngine.side_progress().erase(id)
	for o in d["objectives"]:StoryEngine.St()["done"].erase(o["id"])
	runner.check(StoryEngine.start_side_story(id),"start impossible-flow fixture")
	GameState.data["entities"][ent]["closed"]=Clock.now();StoryEngine.check()
	runner.eq(StoryEngine.side_progress()[id]["status"],"unavailable","company closure stops story")
	for o in d["objectives"]:runner.check(not o["id"] in StoryEngine.St()["active"],"impossible objective removed")
func test_expiry_decline_and_old_save_guides_never_lock() -> void:
	setup();StoryEngine.start_side_story("intro_manufacturing")
	StoryEngine.side_progress()["intro_manufacturing"]["started"]=Clock.now()-91*Clock.DAY
	StoryEngine.check()
	runner.eq(StoryEngine.side_progress()["intro_manufacturing"]["status"],"unavailable","90 day opportunity expires")
	IndustryGuidance.progress("energy")
	GameState.data["tutorial"].erase("industries")
	var p:=IndustryGuidance.progress("energy")
	runner.eq(p["step"],0,"old save lazy industry guide")
	p["skipped"]=true;IndustryGuidance.skip_completed("energy")
	runner.check(p["skipped"],"skipped guide stays optional")
	runner.check(SaveSystem.save(8) and SaveSystem.load_data(8),"side receipts and tutorial roundtrip")
	runner.check(IndustryGuidance.progress("energy")["skipped"],"skip persists")
func test_mentor_data_world_pin_and_omar_schedule() -> void:
	setup()
	for id in ["manufacturing","real_estate","media","hotel","automotive","energy"]:
		var d:=IndustryGuidance.guide(id)
		runner.check(DataDB.npcs.has(d["mentor"]),"actual mentor")
		runner.check(DataDB.buildings.has(d["building"]),"actual workplace")
	var npc: Dictionary=DataDB.npcs["omar_haddad"]
	runner.eq(npc["schedule"][0]["location"],"interior:customs_house","trade introducer actual customs location")
	runner.check(DataDB.dialogue.has("omar_haddad_intro"),"Omar actual dialogue")
	runner.check(Ledger.check_balanced(),"guidance no ledger mutation")

func test_industry_guide_preserves_shared_tutorial_and_partial_old_saves() -> void:
	setup();GameState.data.erase("tutorial")
	IndustryGuidance.progress("energy")
	var shared: Dictionary=GameState.data["tutorial"]
	runner.eq(typeof(shared["seen"]),TYPE_DICTIONARY,"global tutorial seen map initialized")
	runner.check(shared.has("step") and shared.has("off") and shared.has("v"),"global tutorial schema stays complete")
	shared["seen"]["os"]=true;shared["step"]=7;shared.erase("v")
	IndustryGuidance.progress("manufacturing")
	runner.eq(shared["step"],7,"existing first-venture progress preserved")
	runner.check(shared["seen"]["os"],"existing coaching receipts preserved")
	runner.check(SaveSystem.save(9) and SaveSystem.load_data(9),"complete shared guide schema loads")

func test_expired_other_company_story_does_not_change_selected_company_flags() -> void:
	var owner:=setup();StoryEngine.start_side_story("intro_energy")
	StoryEngine.side_progress()["intro_energy"]["started"]=Clock.now()-91*Clock.DAY
	GameState.data["company"]="";Company.register("Second Guide","ecommerce","Riverside")
	IndustryGuidance.check()
	runner.check(not GameState.flag("side_energy_declined"),"inactive owner cannot change selected company flags")
	runner.eq(StoryEngine.side_progress()["intro_energy"]["status"],"active","inactive owner defers safely")
	GameState.data["company"]=owner;StoryEngine.check()
	runner.eq(StoryEngine.side_progress()["intro_energy"]["status"],"unavailable","expiry resolves when owner resumes")

func test_real_defective_order_recovery_slots_are_distinct_and_idempotent() -> void:
	setup();Living.lease("unit12_factory");Manufacturing.start();Manufacturing.acquire_machine();Staff.register_employer();Manufacturing.hire_tomas()
	var rfq: Dictionary=Manufacturing.S()["rfqs"].values()[0]
	runner.check(Manufacturing.quote(rfq["id"],float(rfq["min_price"]))["ok"],"accepted actual OEM order")
	var order: Dictionary=Manufacturing.S()["orders"].values()[0]
	# Quality failure receipt only; production and cash effects below use the actual order and scheduler.
	order["escaped"]=1.0
	var before:=Ledger.cash(GameState.company_id())
	var outsourced:=IndustryGuidance.recovery_plan(true)
	runner.check(outsourced["ok"],"real two-hour outsourced recovery")
	var slot: Dictionary=Manufacturing.S()["slots"][-1]
	runner.check(slot["outsource"] and not slot["overtime"],"outsourcing uses external production")
	runner.check(not IndustryGuidance.recovery_plan(false)["ok"],"already planned cannot double book")
	Clock.advance_to(slot["end"])
	runner.check(int(order["produced"])>0,"actual scheduler creates ordered units")
	runner.check(Ledger.cash(GameState.company_id())<before,"actual subcontract service costs cash")
	runner.check(Ledger.check_balanced(),"recovery books balance")
func test_real_overtime_recovery_stays_in_factory() -> void:
	setup();Living.lease("unit12_factory");Manufacturing.start();Manufacturing.acquire_machine();Staff.register_employer();Manufacturing.hire_tomas()
	var rfq: Dictionary=Manufacturing.S()["rfqs"].values()[0]
	Manufacturing.quote(rfq["id"],float(rfq["min_price"]));var order: Dictionary=Manufacturing.S()["orders"].values()[0];order["escaped"]=1.0
	runner.check(IndustryGuidance.recovery_plan(false)["ok"],"two hours actual overtime capacity")
	var slot: Dictionary=Manufacturing.S()["slots"][-1]
	runner.check(slot["overtime"] and not slot["outsource"],"distinct overtime route")
	runner.check(slot["machine"] in Manufacturing.S()["machines"],"owned rented machine reserved")
	runner.check(Ledger.check_balanced(),"reservation creates no imaginary income")
