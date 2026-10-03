extends RefCounted
var runner
func setup() -> String:
	Company.register("Fleet Test","logistics","Pier 7");Company.open_business_account(20000)
	Ledger.post(GameState.company_id(),"QA fleet equity",[{"acct":"cash","dr":50000},{"acct":"equity","cr":50000}])
	Logistics.buy_van()
	return GameState.company_id()
func offer() -> String:return Contracts.create_offer({"type":"delivery_route","buyer":"bloom_coffee","place":"bloom_coffee"})
func driver() -> Dictionary:
	Staff.register_employer();Staff.post_job("driver");Clock.advance(19*60)
	Staff.hire(Staff.S()["applicants"][0]["id"])
	return Staff.people()[-1]
func test_route_negotiation_actual_trip_and_idempotence() -> void:
	var entity:=setup();var id:=offer()
	runner.check(Contracts.counter(id,115,0,0)["ok"],"counter trip fee")
	runner.check(Contracts.accept(id)["ok"],"sign real route")
	var start:=Clock.now();var before:=Ledger.balance(entity,"revenue")
	runner.check(LogisticsDepth.run_route(id,"van1")["ok"],"actual route completes")
	runner.check(Clock.now()>start,"driving uses time")
	runner.eq(Ledger.balance(entity,"revenue"),before-115,"only completed trip earns fee")
	runner.eq(Contracts.C()[id]["completed"],1,"trip counted once")
	LogisticsDepth.run_route(id,"van1");LogisticsDepth.run_route(id,"van1")
	var cash:=Ledger.cash(entity)
	runner.check(not LogisticsDepth.run_route(id,"van1")["ok"],"already did weekly quota no extra fee")
	runner.eq(Ledger.cash(entity),cash,"repeat no ledger mutation")
	runner.check(Ledger.check_balanced(),"route books balance")
func test_missed_route_penalty_expiry_and_closed_company_no_softlock() -> void:
	var entity:=setup();var id:=offer();Contracts.accept(id)
	var before:=Ledger.balance(entity,"exp:penalties")
	LogisticsDepth.route_tick(Contracts.C()[id]["week_end"])
	runner.eq(Ledger.balance(entity,"exp:penalties"),before+165,"three missed trips actual penalty")
	var paid:=Ledger.balance(entity,"exp:penalties");LogisticsDepth.route_tick(Contracts.C()[id]["week_start"])
	runner.eq(Ledger.balance(entity,"exp:penalties"),paid,"already settled week not charged twice")
	LogisticsDepth.route_tick(Contracts.C()[id]["due"])
	runner.eq(Contracts.C()[id]["status"],"paid","90-day obligation ends")
	var second:=offer();Contracts.accept(second)
	Insolvency.begin(entity,"Fleet closed");Insolvency.close_company()
	runner.eq(Contracts.C()[second]["status"],"terminated","impossible company route closes")
	runner.check(not LogisticsDepth.run_route(second,"van1")["ok"],"closed van cannot operate")
	runner.check(Ledger.check_balanced(),"closure balances")
func test_buy_second_vehicle_model_cost_capacity_and_save() -> void:
	var entity:=setup();var before:=Ledger.cash(entity)
	runner.check(LogisticsDepth.buy("new")["ok"],"actual second van purchase")
	runner.eq(Ledger.cash(entity),before-17010,"vehicle and insurance dollars")
	runner.eq(LogisticsDepth.vehicles()["van2"]["condition"],100,"new condition")
	runner.check(not LogisticsDepth.buy("used")["ok"],"two-vehicle cap")
	runner.check(SaveSystem.save(8) and SaveSystem.load_data(8),"two vans save roundtrip")
	runner.eq(LogisticsDepth.vehicles().size(),2,"fleet retained")
	runner.check(Ledger.check_balanced(),"capitalized vehicle balances")
func test_fixed_seed_condition_failure_delay_pay_and_real_costs() -> void:
	var entity:=setup();var v: Dictionary=LogisticsDepth.vehicles()["van1"]
	var high:=LogisticsDepth.chance(v);v["condition"]=0
	runner.check(LogisticsDepth.chance(v)>high,"worse condition higher failure chance")
	GameState.rng.seed=13
	var id:=offer();Contracts.accept(id)
	var before:=Ledger.balance(entity,"exp:maintenance")
	var result:=LogisticsDepth.run_route(id,"van1")
	runner.check(result["ok"],"bad vehicle trip completes after repair")
	runner.check(Ledger.balance(entity,"exp:maintenance")>before,"actual tow and repair fees")
	runner.check(float(result["pay"])<110,"breakdown reduces trip fee")
	runner.check(int(result["minutes"])>=120,"breakdown delay in minutes")
	runner.check(Ledger.check_balanced(),"breakdown books balance")
func test_service_half_day_recovers_condition_and_repeat_guard() -> void:
	setup();Clock.advance(25);var v: Dictionary=LogisticsDepth.vehicles()["van1"];v["condition"]=35
	runner.check(LogisticsDepth.service("van1")["ok"],"real maintenance booking")
	runner.check(not LogisticsDepth.available("van1"),"van unavailable half a day")
	runner.check(not LogisticsDepth.service("van1")["ok"],"already servicing guard")
	Clock.advance(12*60)
	runner.check(LogisticsDepth.available("van1"),"half-day closure decays")
	runner.eq(v["condition"],90,"condition restored")
func test_two_drivers_two_vans_and_busy_vehicle_not_double_used() -> void:
	setup();LogisticsDepth.buy("new")
	var first:=driver();var second:=driver()
	LogisticsDepth.assign(first["id"],"van1");LogisticsDepth.assign(second["id"],"van2")
	var t:=Clock.now()+Clock.DAY
	while Clock.weekday(t)>5 or Clock.weekday(t)<1:t+=Clock.DAY
	t=t-t%Clock.DAY+9*60
	GameState.data["clock"]["minutes"]=t
	Logistics.post_jobs();LogisticsDepth.dispatch(t)
	var active: Array=Logistics.S()["jobs"].values().filter(func(j):return j["status"]=="driving")
	runner.eq(active.size(),2,"two drivers occupy two vans")
	runner.check(active[0]["vehicle"]!=active[1]["vehicle"],"each run distinct vehicle")
	LogisticsDepth.dispatch(t)
	runner.eq(Logistics.S()["jobs"].values().filter(func(j):return j["status"]=="driving").size(),2,"repeat no third booking")
	Clock.advance(8*60)
	runner.check(LogisticsDepth.available("van1") and LogisticsDepth.available("van2"),"both schedules complete")
	runner.check(Ledger.check_balanced(),"two driver trips balance")
func test_genuine_pre_fleet_save_and_single_van_defaults() -> void:
	var text:=FileAccess.get_file_as_string("res://tests/fixtures/saves/cafe_depth_33.json")
	SaveSystem._atomic_write(SaveSystem._path(9),text)
	runner.check(SaveSystem.load_data(9),"real pre-fleet played save loads")
	var state:=Logistics.S();state.erase("fleet");state.erase("assignments");state["van"]={"owned":true,"bought":0,"entity":GameState.company_id(),"ins_day":1,"km":123.0}
	runner.eq(LogisticsDepth.vehicles()["van1"]["km"],123,"old mileage retained")
	runner.eq(LogisticsDepth.vehicles()["van1"]["condition"],90,"old vehicle condition default")
	runner.check(LogisticsDepth.vehicles()["van1"]==Logistics.S()["van"],"old canonical van retained")

func test_posted_route_is_runnable_and_internal_cafe_fees_eliminate() -> void:
	var entity:=setup();Living.lease("corner_cafe")
	var id:=Contracts.create_offer({"type":"delivery_route","buyer":entity,"place":"corner_cafe_unit","internal":true})
	Contracts.accept(id)
	LogisticsDepth.on_hour(Clock.now(),7)
	var revenue:=Ledger.balance(entity,"revenue")
	runner.check(LogisticsDepth.run_route(id,"van1")["ok"],"already posted route can actually be driven")
	runner.eq(Ledger.balance(entity,"revenue"),revenue,"own café never creates external sales")
	var report:=Segments.compute(entity,0,Clock.now()+1)
	runner.eq(report["totals"]["internal_revenue"],report["totals"]["internal_charge"],"own café transfer eliminated")
	runner.check(Ledger.check_balanced(),"internal service balances")

func test_vehicle_allocated_profit_sums_to_actual_segment() -> void:
	var entity:=setup();LogisticsDepth.buy("new")
	var id:=offer();Contracts.accept(id);LogisticsDepth.run_route(id,"van1")
	var first:=LogisticsDepth.report("van1");var second:=LogisticsDepth.report("van2")
	var report:=Segments.compute(entity,0,Clock.now()+1)
	runner.check(absf(float(first["allocated_profit"])+float(second["allocated_profit"])-float(report["rows"]["logistics"]["operating_profit"]))<.01,"vehicle allocations equal posted segment profit")
	Contracts.reject(id)
	runner.eq(Contracts.C()[id]["status"],"active","stale decline cannot escape active route")
