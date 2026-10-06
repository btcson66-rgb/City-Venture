extends RefCounted
var runner
func setup(extra := 200000.0,mode := "own") -> String:
	Company.register("Hotel Test","hotel","The Aster")
	Company.open_business_account(25000)
	if extra>0:Ledger.post(GameState.company_id(),"QA hotel equity",[{"acct":"cash","dr":extra},{"acct":"equity","cr":extra}])
	GameState.mark_visited("the_aster")
	runner.check(Hotel.start(mode)["ok"],"hotel opens (%s)"%mode)
	return GameState.company_id()
func hire(role: String,count := 1) -> void:
	if not Staff.employer_registered():Staff.register_employer()
	for i in count:
		runner.check(Staff.post_job(role)["ok"],"recruit "+role)
		Clock.advance(18*60)
		runner.check(Staff.hire(Staff.S()["applicants"][0]["id"])["ok"],"hire "+role)
func staff_up() -> void:
	hire("housekeeper",2)
	hire("front_desk")
func run_days(days: int) -> void:Clock.advance(days*Clock.DAY)
func test_opening_gates_district_and_registry() -> void:
	runner.check(not Hotel.start()["ok"],"company gate")
	Company.register("Hotel Test","hotel","The Aster")
	Company.open_business_account(25000)
	runner.check(not Hotel.start()["ok"],"must visit The Aster first")
	GameState.mark_visited("the_aster")
	runner.check(not Hotel.start("own")["ok"],"takeover needs $150,000 cash")
	var entity := GameState.company_id()
	Ledger.post(entity,"QA equity",[{"acct":"cash","dr":160000},{"acct":"equity","cr":160000}])
	runner.check(Hotel.start("own")["ok"],"takeover with cash")
	runner.eq(DataDB.district_def_in_city("luxury_heights")["status"],"active","Luxury Heights active")
	runner.check(DataDB.districts.has("luxury_heights") and DataDB.districts["luxury_heights"]["buildings"].size()>=3,"district has the three hotel buildings")
	runner.eq(Hotel.total_rooms(),12,"12-room Aster Inn")
	runner.eq(Hotel.stage(),1,"stage one")
	runner.check(GameState.flag("hotel_active"),"flag for crisis events and Media demand")
	runner.check(Industries.tabs().any(func(t):return t["id"]=="hotel"),"OS registry tab")
	runner.check(Industries.find("hotel")["sim_class"].has_method("crisis"),"industry crisis hook")
	runner.check(Ledger.balance(entity,"fixed_assets")>=149999,"takeover capitalised as room equipment assets")
	runner.eq(Assets.S()["items"].values().filter(func(a):return a["segment"]=="hotel").size(),3,"one fit-out asset per room type")
	runner.check(BuildingInfo.building_enterable("the_aster") and BuildingInfo.district_open("luxury_heights"),"data-driven visibility (#44)")
	runner.check(not Hotel.start("own")["ok"],"cannot open twice")
func test_lease_route_uses_rent_and_rented_assets() -> void:
	var entity := setup(30000,"lease")
	runner.check(Living.has_lease("aster_inn"),"building lease signed")
	runner.eq(Ledger.balance(entity,"fixed_assets"),0.0,"leased fit-outs are not capitalised")
	runner.check(Ledger.balance(entity,"exp:asset_rent")>0 and Ledger.balance(entity,"exp:rent_shop")>=9000,"first rent and equipment rent")
	runner.check(Ledger.check_balanced(),"lease balanced")
func test_full_operating_cycle_ledger_balanced_and_segment_total() -> void:
	var entity := setup()
	staff_up()
	var t0 := 0
	run_days(14)
	runner.check(Hotel.S()["history"].size()>=12,"night audits recorded")
	var info := Hotel.stats(14)
	runner.check(float(info["occupancy"])>.15 and float(info["occupancy"])<=1.0,"occupancy within range (%.2f)"%float(info["occupancy"]))
	runner.check(float(info["adr"])>=60 and float(info["adr"])<=450,"ADR in the price bands (%.2f)"%float(info["adr"]))
	runner.check(-Ledger.balance(entity,"revenue")>0,"room revenue booked")
	runner.check(Ledger.balance(entity,"cogs")>0 and Ledger.balance(entity,"exp:other")>0,"variable costs and utilities")
	runner.check(Ledger.check_balanced(),"ledger balanced")
	var company := MonthClose.compute(entity,t0,Clock.now()+1)
	var segments := Segments.compute(entity,t0,Clock.now()+1)
	runner.check(absf(float(segments["totals"]["operating_profit"])-float(company["business_profit"]))<.011,"segment total equals company")
	runner.check(float(segments["rows"]["hotel"]["revenue"])>0,"hotel segment carries the revenue")
func test_demand_calendar_events_and_prices() -> void:
	setup()
	var rows := Hotel.calendar(30)
	runner.eq(rows.size(),30,"30-day calendar")
	var saturday := rows.filter(func(r):return int(r["weekday"])==6)
	var tuesday := rows.filter(func(r):return int(r["weekday"])==2)
	runner.check(float(saturday[0]["index"])>float(tuesday[0]["index"]),"weekend demand above midweek")
	Hotel.S()["events"]=[{"id":"harbor_music","name":"Harbor Music Festival","start":Clock.day_index()+5,"end":Clock.day_index()+7,"mult":1.7}]
	runner.check(Hotel.forecast(Clock.day_index()+6)["event"]=="Harbor Music Festival","city event named in the forecast")
	runner.check(float(Hotel.forecast(Clock.day_index()+6)["index"])>=1.7*float(Hotel.cfg()["dow"].min())*.8,"event multiplies demand")
	var before := float(Hotel.demand("standard",Clock.day_index()+1)["direct"])
	Hotel.set_price("standard",float(Hotel.rack_price("standard"))+60)
	runner.check(float(Hotel.demand("standard",Clock.day_index()+1)["direct"])<before,"higher price lowers demand")
	runner.check(not Hotel.set_price("standard",1000)["ok"] and not Hotel.set_price("standard",NAN)["ok"],"price bounds and NaN rejected")
	Hotel.set_peak(.3)
	var peak_day := Clock.day_index()+6
	runner.check(Hotel.price_at("standard",peak_day)>Hotel.rack_price("standard"),"peak surcharge applies on peak days")
	runner.check(not Hotel.set_overbook(.2)["ok"] and Hotel.set_overbook(.1)["ok"],"overbooking limited to 10%")
	var snapshot := JSON.stringify(GameState.rng.state)
	Hotel.calendar(30)
	runner.eq(JSON.stringify(GameState.rng.state),snapshot,"forecast consumes no random numbers")
func test_overbooking_walk_settlement() -> void:
	var entity := setup()
	staff_up()
	var no_show: Dictionary=Hotel.cfg()["no_show"]
	var saved := no_show.duplicate()
	no_show["direct"]=0.0
	no_show["ota"]=0.0
	Hotel.add_mod("demand",6.0,60)
	Hotel.set_overbook(.1)
	Hotel.set_channels(true,"standard",1.0)
	run_days(10)
	runner.check(int(Hotel.S()["stats"]["walks"])>0,"overbooked guests are walked when everyone arrives")
	runner.check(float(Hotel.S()["stats"]["walk_cost"])>0,"walk compensation recorded")
	runner.eq(Ledger.balance(entity,"exp:penalties"),float(Hotel.S()["stats"]["walk_cost"]),"walk compensation equals the penalty expense")
	runner.check(Ledger.check_balanced(),"walk settlement balanced")
	var guest_scores: Array=Hotel.S()["reviews"].filter(func(r):return r["kind"]=="guest").map(func(r):return float(r["s"]))
	runner.check(guest_scores.min()<float(Hotel.cfg()["review"]["service_base"])+float(Hotel.cfg()["review"]["service_desk"])+.8,"walks lower the service score")
	Hotel.set_overbook(0.0)
	var walks := int(Hotel.S()["stats"]["walks"])
	run_days(5)
	runner.eq(int(Hotel.S()["stats"]["walks"]),walks,"no overbooking, no walks")
	for key in saved:no_show[key]=saved[key]
func test_channel_commission_accounting_via_jobs() -> void:
	var entity := setup()
	Hotel.set_channels(true,"featured",1.0)
	staff_up()
	run_days(9)
	var statements: Array=Jobs.S()["items"].values().filter(func(j):return j["entity"]==entity and j["segment"]=="hotel" and j["client"]==Hotel.cfg()["ota_name"])
	runner.check(not statements.is_empty(),"OTA nights are billed as a Jobs statement")
	var job: Dictionary=statements[0]
	runner.check(absf(float(job["commission"])/float(job["price"])-.18)<.005,"commission rate 18%")
	runner.eq(float(job["receivable"]),float(job["price"])-float(job["commission"]),"receivable is net of commission")
	runner.check(Ledger.balance(entity,"exp:platform_fees")>=float(job["commission"])-.01,"commission is an operating expense")
	runner.check(Ledger.balance(entity,"accounts_receivable")>0,"statement sits in accounts receivable")
	run_days(31)
	runner.eq(Jobs.get_job(job["id"])["status"],"paid","Net 30 collection")
	runner.check(Ledger.check_balanced(),"OTA flow balanced")
	Hotel.set_channels(true,"standard",1.0)
	runner.check(float(Hotel.cfg()["ota_tiers"]["standard"]["commission"])==.15,"standard tier is 15%")
	runner.check(float(Hotel.demand("standard",Clock.day_index()+1)["ota"])>0 and not Hotel.set_channels(true,"gold",.5)["ok"],"unknown tier rejected")
	Hotel.set_channels(false,"standard",.5)
	runner.eq(float(Hotel.demand("standard",Clock.day_index()+1)["ota"]),0.0,"closed OTA brings no volume")
func test_group_block_locks_rooms_and_settles_net_30() -> void:
	var entity := setup()
	staff_up()
	var offers := Hotel.open_blocks()
	runner.check(not offers.is_empty(),"agency blocks offered through Jobs")
	var b: Dictionary=offers[0]
	runner.eq(b["rate"],snappedf(float(b["rack"])*.75,.01),"25% group discount")
	runner.eq(Jobs.get_job(b["id"])["status"],"offered","block is a Jobs offer")
	runner.check(Hotel.accept_block(b["id"])["ok"],"accepted")
	runner.eq(Jobs.get_job(b["id"])["status"],"active","Jobs active")
	var deposit := float(Jobs.get_job(b["id"])["deposit_paid"])
	var revenue_before := -Ledger.balance(entity,"revenue")
	runner.check(deposit>0 and absf(deposit-float(Jobs.get_job(b["id"])["price"])*.2)<.02,"20% deposit")
	runner.eq(-Ledger.balance(entity,"revenue"),revenue_before,"deposit is not revenue")
	var day := int(b["start"])
	runner.eq(Hotel.forecast(day)["blocked"],int(b["rooms"]),"locked rooms leave the calendar")
	run_days(int(b["end"])-Clock.day_index()+1)
	runner.eq(Hotel.S()["blocks"][b["id"]]["status"],"stayed","stay finished")
	runner.eq(Jobs.get_job(b["id"])["status"],"invoiced","invoiced after the last night")
	runner.check(-Ledger.balance(entity,"revenue")>=float(Jobs.get_job(b["id"])["price"])-.02,"group revenue recognised at invoice")
	run_days(31)
	runner.eq(Jobs.get_job(b["id"])["status"],"paid","Net 30")
	runner.check(Ledger.check_balanced(),"group flow balanced")
func test_review_formula_and_vera_weight() -> void:
	var cfg: Dictionary=Hotel.cfg()["review"]
	runner.eq(Hotel.review_score(5,3,1),.35*5+.35*3+.30*1,"cleanliness 35, service 35, value 30")
	setup()
	var day := Clock.day_index()
	Hotel.S()["reviews"]=[{"day":day,"kind":"guest","w":1.0,"score":5.0,"c":5.0,"s":5.0,"v":5.0},{"day":day,"kind":"vera","w":float(cfg["vera_weight"]),"score":1.0,"c":1.0,"s":1.0,"v":1.0}]
	runner.eq(Hotel.rating(),(5.0+5.0*1.0)/6.0,"Vera's review weighs five times")
	runner.eq(Hotel.review_count(),6,"review count uses weights")
	var good := Hotel._guest_review(day,10,0.0,5.0,0,1000.0,1000.0,"standard")
	var cheap := Hotel._guest_review(day,10,0.0,5.0,0,700.0,1000.0,"standard")
	var dear := Hotel._guest_review(day,10,0.0,5.0,0,1600.0,1000.0,"standard")
	runner.check(float(cheap["v"])>float(good["v"]) and float(good["v"])>float(dear["v"]),"value falls as price rises against quality")
	var dirty := Hotel._guest_review(day,10,4.0,5.0,0,1000.0,1000.0,"standard")
	runner.check(float(dirty["c"])<float(good["c"]),"housekeeping shortfall lowers cleanliness")
	var walks := Hotel._guest_review(day,10,0.0,5.0,5,1000.0,1000.0,"standard")
	runner.check(float(walks["s"])<float(good["s"]),"walked guests lower service")
	Hotel.S()["rooms"]["standard"]["cond"]=20.0
	var tired := Hotel._guest_review(day,10,0.0,5.0,0,1000.0,1000.0,"standard")
	runner.check(float(tired["c"])<float(good["c"]),"old rooms lower cleanliness")
	Hotel.S()["reviews"]=[]
	Hotel.crisis("vera_vip")
	hire("housekeeper",2)
	hire("front_desk")
	run_days(6)
	runner.check(Hotel.S()["reviews"].any(func(r):return r["kind"]=="vera" and float(r["w"])==float(cfg["vera_weight"])),"Vera's stay produced a x5 review")
func test_housekeeping_capacity_limits_sellable_rooms() -> void:
	setup()
	Hotel.S()["last_occupied"]=12
	runner.eq(Hotel.hk_capacity(),float(Hotel.cfg()["owner_clean"]),"owner only cleans a few rooms")
	var low := Hotel.audit()
	runner.check(int(low["dirty"])>0,"dirty rooms are withheld from sale (%d)"%int(low["dirty"]))
	runner.check(int(low["occupied"])<=12-int(low["dirty"]),"occupancy cannot exceed cleaned rooms")
	Clock.advance(Clock.DAY)
	Hotel.S()["last_occupied"]=12
	Hotel.set_temp(true)
	var with_temp := Hotel.audit()
	runner.check(int(with_temp["dirty"])<int(low["dirty"]),"temporary cleaners unlock rooms")
	runner.check(Ledger.balance(GameState.company_id(),"exp:other")>0,"temporary cleaners cost money")
	Hotel.set_temp(false)
	hire("housekeeper",3)
	Clock.advance(Clock.DAY)
	Hotel.S()["last_occupied"]=12
	var capacity := Hotel.hk_capacity()
	runner.check(capacity>Hotel.turnover_work(),"staff capacity %.1f covers the workload %.1f"%[capacity,Hotel.turnover_work()])
	runner.eq(int(Hotel.audit()["dirty"]),0,"enough housekeepers leave no dirty rooms")
func test_equipment_asset_failure_maintenance_and_renovation() -> void:
	var entity := setup()
	staff_up()
	var asset_id: String=Hotel.S()["rooms"]["standard"]["assets"][0]
	var asset: Dictionary=Assets.S()["items"][asset_id]
	runner.check(asset["segment"]=="hotel" and float(asset["maintenance_cost"])>0,"room equipment is an Asset")
	run_days(3)
	runner.check(float(Assets.S()["items"][asset_id]["book"])<float(asset["price"]),"equipment depreciates")
	asset["status"]="broken"
	runner.check(Hotel.out_of_order("standard"),"broken equipment takes the room type off sale")
	runner.eq(Hotel.forecast(Clock.day_index()+1)["blocked"],0,"calendar sees no group rooms")
	runner.check(Hotel.maintain("standard")["ok"] and not Hotel.out_of_order("standard"),"servicing repairs and reopens the rooms")
	var cond_before := float(Hotel.S()["rooms"]["standard"]["cond"])
	var cost := Hotel.renovation_cost("standard")
	var fixed := Ledger.balance(entity,"fixed_assets")
	runner.check(Hotel.renovate("standard")["ok"],"renovation starts")
	runner.check(Hotel.out_of_order("standard"),"renovating rooms cannot be sold")
	runner.check(absf(Ledger.balance(entity,"fixed_assets")-fixed-cost)<.02,"renovation is capitalised")
	runner.check(not Hotel.renovate("standard")["ok"],"no double renovation")
	runner.check(Sim.pending("hotel.reno").size()==1,"completion is scheduled")
	run_days(int(Hotel.cfg()["types"]["standard"]["renovate_days"])+1)
	runner.check(not Hotel.out_of_order("standard") and float(Hotel.S()["rooms"]["standard"]["cond"])>cond_before,"renovation restores condition")
	var worn := float(Hotel.S()["rooms"]["deluxe"]["cond"])
	runner.check(worn<float(Hotel.cfg()["condition_start"]),"wear lowers condition over time")
	runner.check(Ledger.check_balanced(),"equipment flow balanced")
func test_crisis_choices_have_real_effects_and_decay() -> void:
	var entity := setup()
	staff_up()
	run_days(3)
	for id in ["hotel_slump","hotel_review_storm","hotel_equipment_failure","hotel_event_cancelled","hotel_strike","hotel_vera_visit"]:
		runner.check(DataDB.events[id]["choices"].size()>=2,id+" offers at least two choices")
	var slump := EventEngine.trigger("hotel_slump")
	runner.check(EventEngine.choose(slump["iid"],"wait")["ok"],"slump: wait")
	runner.eq(Hotel.mod_mult("demand"),float(Hotel.cfg()["crisis"]["slump_mult"]),"slump lowers demand")
	var cash := Ledger.cash(entity)
	slump=EventEngine.trigger("hotel_slump")
	runner.check(EventEngine.choose(slump["iid"],"promo")["ok"] and Ledger.cash(entity)<cash,"slump: promotion costs cash")
	runner.check(Hotel.mod_mult("demand")>float(Hotel.cfg()["crisis"]["slump_mult"]),"promotion softens the dip")
	run_days(int(Hotel.cfg()["crisis"]["slump_days"])+1)
	runner.eq(Hotel.mod_mult("demand"),1.0,"the slump decays by itself")
	var rating := Hotel.rating()
	var storm := EventEngine.trigger("hotel_review_storm")
	runner.check(EventEngine.choose(storm["iid"],"ignore")["ok"],"storm: ignore")
	runner.check(Hotel.rating()<rating,"ignored storm lowers the rating")
	var ignored := Hotel.rating()
	storm=EventEngine.trigger("hotel_review_storm")
	cash=Ledger.cash(entity)
	runner.check(EventEngine.choose(storm["iid"],"respond")["ok"] and Ledger.cash(entity)<cash,"storm: response costs cash")
	run_days(int(Hotel.cfg()["review"]["window_days"])+2)
	runner.check(not Hotel.S()["reviews"].any(func(r):return r["kind"]=="storm"),"storm reviews age out of the window")
	var _unused := ignored
	var failure := EventEngine.trigger("hotel_equipment_failure")
	runner.check(EventEngine.choose(failure["iid"],"slow")["ok"],"failure: slow repair")
	runner.check(Hotel.S()["mods"].any(func(m):return m["kind"]=="ooo"),"slow repair takes rooms offline")
	run_days(int(Hotel.cfg()["crisis"]["breakdown_slow_days"])+1)
	runner.check(not Hotel.S()["mods"].any(func(m):return m["kind"]=="ooo"),"rooms return to sale")
	failure=EventEngine.trigger("hotel_equipment_failure")
	cash=Ledger.cash(entity)
	runner.check(EventEngine.choose(failure["iid"],"fast")["ok"] and Ledger.cash(entity)<cash-2000,"failure: emergency repair")
	var strike := EventEngine.trigger("hotel_strike")
	var capacity := Hotel.hk_capacity()
	runner.check(EventEngine.choose(strike["iid"],"hold")["ok"],"strike: hold firm")
	runner.check(Hotel.hk_capacity()<capacity*.5,"strike cuts cleaning capacity")
	run_days(int(Hotel.cfg()["crisis"]["strike_hold_days"])+1)
	runner.check(absf(Hotel.hk_capacity()-capacity)<.01,"strike effect expires")
	strike=EventEngine.trigger("hotel_strike")
	cash=Ledger.cash(entity)
	runner.check(EventEngine.choose(strike["iid"],"raise")["ok"] and Ledger.cash(entity)<cash,"strike: bonus costs cash")
	runner.check(Ledger.check_balanced(),"crises balanced")
func test_cancelled_event_refunds_group_deposits() -> void:
	var entity := setup()
	staff_up()
	Hotel.S()["events"]=[{"id":"trade_expo","name":"Aurelia Trade Expo","start":Clock.day_index()+8,"end":Clock.day_index()+11,"mult":1.5}]
	var b: Dictionary=Hotel.open_blocks()[0]
	b["start"]=Clock.day_index()+8
	b["end"]=Clock.day_index()+8+int(b["nights"])-1
	b["event"]="trade_expo@"+str(Clock.day_index()+8)
	runner.check(Hotel.accept_block(b["id"])["ok"],"block on the expo")
	var cash := Ledger.cash(entity)
	var event := EventEngine.trigger("hotel_event_cancelled")
	runner.check(EventEngine.choose(event["iid"],"accept")["ok"],"cancelled event: accept")
	runner.check(Hotel.event_at(Clock.day_index()+9).is_empty(),"event removed from the calendar")
	runner.eq(Hotel.S()["blocks"][b["id"]]["status"],"cancelled","tied block cancelled")
	runner.check(Ledger.cash(entity)<cash,"deposit refunded")
	runner.eq(Ledger.balance(entity,"deferred_revenue"),0.0,"no deferred revenue left")
	runner.check(Ledger.check_balanced(),"refund balanced")
func test_growth_tiers_need_conditions_and_add_rooms() -> void:
	var entity := setup(900000)
	staff_up()
	runner.check(not Hotel.upgrade()["ok"],"stage two is gated")
	runner.check(Hotel.gate(2).any(func(r):return not r[0]),"unmet conditions are listed")
	Hotel.S()["stage_since"]=Clock.now()-40*Clock.DAY
	Hotel.S()["history"]=[]
	for i in 30:Hotel.S()["history"].append({"day":i,"occupied":10,"rooms":12,"room_revenue":1200.0,"walks":0,"dirty":0})
	Hotel.S()["reviews"]=[{"day":Clock.day_index(),"kind":"guest","w":30.0,"score":4.2,"c":4,"s":4,"v":4}]
	hire("housekeeper")
	runner.check(Hotel.gate(2).all(func(r):return r[0]),"all stage two conditions can be met")
	runner.check(Hotel.upgrade()["ok"],"expansion")
	runner.eq(Hotel.total_rooms(),30,"30 rooms")
	runner.eq(Hotel.stage(),2,"stage two")
	Clock.advance(Clock.DAY)
	runner.check(Assets.S()["items"][Hotel.S()["restaurant"]]["status"]=="working","restaurant kitchen is an asset")
	runner.check(not Hotel.upgrade()["ok"],"stage three still gated")
	Hotel.S()["stage_since"]=Clock.now()-60*Clock.DAY
	Hotel.S()["history"]=[]
	for i in 30:Hotel.S()["history"].append({"day":i,"occupied":24,"rooms":30,"room_revenue":3600.0,"walks":0,"dirty":0})
	Hotel.S()["reviews"]=[{"day":Clock.day_index(),"kind":"guest","w":40.0,"score":4.5,"c":4,"s":4,"v":4}]
	hire("housekeeper")
	runner.check(Hotel.upgrade()["ok"],"harbor resort")
	runner.eq(Hotel.total_rooms(),50,"50 rooms")
	runner.eq(Hotel.stage(),3,"stage three")
	runner.check(Hotel.upgrade_price(2)>0 and Ledger.balance(entity,"fixed_assets")>0,"growth is capitalised")
	run_days(2)
	runner.check(Ledger.check_balanced(),"growth balanced")
func test_media_group_campaign_lifts_hotel_demand() -> void:
	setup()
	runner.check(Living.lease("loft_office")["ok"], "media has an operating office")
	var before := float(Hotel.demand("standard",Clock.day_index()+1)["direct"])
	Media.S()["boosts"]["hotel"]={"until":Clock.now()+3*Clock.DAY,"value":.2,"id":"QA"}
	Media.S()["active"]=true
	Media.S()["entity"]=GameState.company_id()
	runner.check(float(Hotel.demand("standard",Clock.day_index()+1)["direct"])>before,"measured media campaign raises hotel demand")
func test_breakfast_synergy_with_own_cafe() -> void:
	setup(300000)
	runner.check(not Hotel.set_breakfast("own_cafe")["ok"],"own-cafe breakfast needs the cafe lease")
	Living.lease("corner_cafe")
	runner.check(Hotel.set_breakfast("own_cafe")["ok"],"own-cafe breakfast")
	runner.check(float(Hotel.cfg()["breakfast"]["own_cafe"]["cost"])<float(Hotel.cfg()["breakfast"]["standard"]["cost"]),"cafe breakfast is cheaper")
	runner.check(float(Hotel.cfg()["breakfast"]["own_cafe"]["service"])>float(Hotel.cfg()["breakfast"]["standard"]["service"]),"and better for service")
func test_save_load_old_save_and_company_close() -> void:
	var entity := setup()
	staff_up()
	var b: Dictionary=Hotel.open_blocks()[0]
	Hotel.accept_block(b["id"])
	Hotel.renovate("suite")
	run_days(2)
	runner.check(SaveSystem.save(94),"hotel save")
	GameState.data.erase("hotel")
	runner.check(SaveSystem.load_data(94),"hotel load")
	runner.check(Hotel.is_running() and Hotel.total_rooms()==12,"state restored")
	Insolvency.close_company()
	runner.check(not Hotel.is_running() and Sim.pending("hotel.reno").is_empty(),"closing cancels scheduled hotel work")
	runner.check(not GameState.flag("hotel_active"),"flag cleared")
	runner.check(Jobs.get_job(b["id"])["status"] in ["closed","paid"],"locked group block closed")
	runner.eq(Ledger.balance(entity,"deferred_revenue"),0.0,"guest deposits settled")
	runner.eq(Assets.S()["items"][Hotel.S()["rooms"]["standard"]["assets"][0]]["status"],"sold","equipment auctioned")
	runner.check(Ledger.check_balanced(),"closure balanced")
	GameState.data.erase("hotel")
	runner.check(SaveSystem.save(95),"legacy save without hotel state")
	runner.check(SaveSystem.load_data(95),"legacy load")
	runner.check(not Hotel.is_running() and Hotel.stage()==1 and Hotel.S()["rooms"].is_empty(),"old save lazily defaults")
func test_rate_board_ui_exposes_named_controls() -> void:
	var entity := setup()
	var board := HotelUI.new()
	UIRoot.open_modal(board)
	await UIRoot.get_tree().process_frame
	for name in ["HotelTab_board","HotelTab_ops","HotelTab_groups","HotelTab_reviews","HotelTab_growth","BoardNextOps","Price_standard_10","ToggleOTA","OverbookMore"]:
		runner.check(board.find_child(name,true,false)!=null,"named control "+name)
	for page in ["board","ops","groups","reviews","growth"]:
		board.switch(page)
		await UIRoot.get_tree().process_frame
		var primaries := 0
		for node in board.find_children("*","Button",true,false):
			var box := (node as Button).get_theme_stylebox("normal")
			if box is StyleBoxTexture and box.texture!=null and box.texture==Art.tex("ui/button_primary"):primaries+=1
		runner.eq(primaries,1,"exactly one primary button on the %s page"%page)
	board.close()
	var _unused := entity
func test_closed_view_checks_and_single_primary() -> void:
	var board := HotelUI.new()
	UIRoot.open_modal(board)
	await UIRoot.get_tree().process_frame
	var primaries := 0
	for node in board.find_children("*","Button",true,false):
		var box := (node as Button).get_theme_stylebox("normal")
		if box is StyleBoxTexture and box.texture!=null and box.texture==Art.tex("ui/button_primary"):primaries+=1
	runner.eq(primaries,1,"one primary route before opening")
	board.close()
func test_luxury_heights_is_visible_in_guide_map_and_metro() -> void:
	var groups: Array=BuildingInfo.guide_groups().filter(func(g):return g["id"]=="luxury_heights")
	runner.check(not groups.is_empty() and groups[0]["open"],"City Guide lists the open district from data")
	if not groups.is_empty():
		for bid in ["the_aster","skyline_grand","observation_deck"]:
			runner.check(bid in groups[0]["buildings"],"guide lists "+bid)
	runner.check(BuildingInfo.district_open("luxury_heights") and BuildingInfo.building_enterable("skyline_grand"),"district and building are enterable")
	var stations: Array=[]
	var metro: Dictionary=DataDB.city["metro"]
	for line in metro["lines"]:
		if line["id"]=="M5":stations=line["stations"]
	runner.check("luxury_heights" in stations,"M5 reaches Luxury Heights")
	for other in ["civic_center","startup_hub","shopping_street","old_town","residential","financial","riverside","university","harbor","industrial"]:
		runner.check(metro["travel_min"].has("luxury_heights>"+other),"travel time to "+other)
	for npc in ["henri_dubois","priya_nair","owen_blake","vera_stone"]:
		runner.check(DataDB.npcs.has(npc) and DataDB.dialogue.has(DataDB.npcs[npc]["dialogue"][0]["conversation"]),npc+" has dialogue")
	var errors: Array=DataDB.validate().filter(func(e):return str(e).contains("hotel") or str(e).contains("luxury") or str(e).contains("aster"))
	runner.eq(errors.size(),0,"data validation is clean for the hotel content")
