extends RefCounted
var runner
func setup() -> String:
	Company.register("Popup Test","ecommerce","Riverside");Company.open_business_account(5000)
	var ent:=GameState.company_id()
	Ledger.post(ent,"QA inventory purchase",[{"acct":"inventory","dr":500},{"acct":"cash","cr":500}])
	Ecommerce._add_stock(Living.home(),"water_bottle",100,5,0)
	return ent
func ready() -> int:
	setup();var start:=PopupStore.next_weekend();PopupStore.sign(start)
	PopupStore.move_stock("water_bottle",Living.home(),50)
	GameState.data["clock"]["minutes"]=start
	GameState.data["player"]["location"]={"kind":"interior","id":"popup_unit"}
	return start
func test_weekend_registration_advance_and_duplicate_no_softlock() -> void:
	runner.check(not PopupStore.sign(PopupStore.next_weekend())["ok"],"unregistered cannot reserve")
	var ent:=setup();var start:=PopupStore.next_weekend();var cash:=Ledger.cash(ent)
	runner.check(not PopupStore.sign(start+Clock.DAY)["ok"],"Sunday cannot start lease")
	runner.check(not PopupStore.sign(start+1)["ok"],"only 10:00")
	GameState.data["clock"]["minutes"]=start-Clock.DAY+1
	runner.check(not PopupStore.sign(start)["ok"],"one day advance enforced")
	GameState.data["clock"]["minutes"]=start-Clock.DAY
	runner.check(PopupStore.sign(start)["ok"],"exact one day accepted")
	runner.eq(Ledger.cash(ent),cash-380,"one weekend rent dollars")
	runner.check(not PopupStore.sign(start)["ok"],"already done no double rent")
	Living._charge_lease("popup_retail",Living.D()["leases"]["popup_retail"])
	runner.eq(Ledger.cash(ent),cash-380,"not charged monthly")
	runner.check(Ledger.check_balanced(),"rent balances")
func test_transfer_cost_time_capacity_and_reserved_orders() -> void:
	var ent:=setup();PopupStore.sign(PopupStore.next_weekend());var start:=Clock.now();var cash:=Ledger.cash(ent)
	runner.check(PopupStore.move_stock("water_bottle",Living.home(),50)["ok"],"move available goods")
	runner.eq(Clock.now(),start+60,"one hour transport")
	runner.eq(Ledger.cash(ent),cash-25,"no van costs dollars25")
	runner.eq(Ecommerce.stock(Living.home(),"water_bottle"),50,"origin fifty fewer")
	runner.eq(Ecommerce.stock("popup_retail","water_bottle"),50,"temporary stock fifty")
	runner.eq(PopupStore.return_reserved(Living.home()),50,"return capacity reserved")
	runner.check(not PopupStore.move_stock("water_bottle",Living.home(),-1)["ok"],"negative quantity rejected")
	runner.check(not PopupStore.move_stock("water_bottle",Living.home(),51)["ok"],"no unavailable stock")
	runner.check(not PopupStore.move_stock("water_bottle","popup_retail",1)["ok"],"no self-transfer")
	runner.check(Ledger.check_balanced(),"transfer balances")
func test_no_staff_no_sales_and_final_hour_closes_once() -> void:
	var start:=ready();var a:=PopupStore.active();var end:=int(a["end"])
	PopupStore.on_hour(start+60,11)
	runner.eq(a["units"],0,"no checkout no income")
	runner.eq(a["customers"],0,"closed shop has no visitors counted")
	GameState.data["clock"]["minutes"]=end
	PopupStore.handle("popup.close",{"start":start})
	runner.eq(Ecommerce.stock(Living.home(),"water_bottle"),100,"all leftovers return")
	runner.check(PopupStore.active().is_empty(),"no staff still closes no softlock")
	PopupStore.handle("popup.close",{"start":start});PopupStore.finish()
	runner.eq(PopupStore.S()["history"].size(),1,"already settled exactly one report")
	runner.check(not Living.has_lease("popup_retail"),"lease removed")
func test_real_checkout_fee_cogs_report_and_leftovers() -> void:
	var start:=ready();var ent:=GameState.company_id();GameState.rng.seed=4
	var a:=PopupStore.active();var before:=Ledger.cash(ent)
	runner.check(PopupStore.owner_shift(.9)["ok"],"owner serves one hour")
	var sold:=int(a["units"])
	runner.check(sold>0 and sold<=10,"actual buyers limited by capacity")
	runner.eq(Ecommerce.stock("popup_retail","water_bottle"),50-sold,"real units deducted")
	runner.eq(Ledger.balance(ent,"revenue"),-float(a["revenue"]),"sales canonical revenue")
	runner.eq(Ledger.balance(ent,"exp:platform_fees"),float(a["fee"]),"card fee actual cents")
	runner.eq(Ledger.balance(ent,"cogs"),sold*5,"inventory cost recognized")
	runner.eq(Ledger.cash(ent),snappedf(before+float(a["revenue"])-Ledger.balance(ent,"tax_payable")-float(a["fee"]),.01),"net cash traceable (revenue plus collected VAT, less fee)")
	PopupStore.on_hour(start+60,11);runner.eq(a["units"],sold,"repeated hour earns nothing")
	GameState.data["clock"]["minutes"]=a["end"];PopupStore.handle("popup.close",{"start":start})
	var r: Dictionary=PopupStore.S()["history"][-1]
	runner.eq(Ecommerce.stock(Living.home(),"water_bottle"),100-sold,"unsold returns to origin")
	runner.eq(r["net"],snappedf(float(r["revenue"])-sold*5-405-float(r["fee"]),.01),"report matches paid rent move cost fee")
	runner.eq(r["shoplane_fee"],snappedf(float(r["revenue"])*float(Ecommerce.mk()["fee_rate"])+sold*float(Ecommerce.mk().get("fixed_fee",0)),.01),"current marketplace comparison only")
	runner.check(Ledger.check_balanced(),"checkout accounting balances")
func test_closed_company_impossible_shift_does_not_resurrect_stock() -> void:
	ready();var ent:=GameState.company_id();Insolvency.begin(ent,"Popup closed");Insolvency.close_company()
	runner.check(PopupStore.active().is_empty(),"closure ends obligation")
	runner.check(not PopupStore.owner_shift(.5)["ok"],"impossible work has next step")
	var total:=Ecommerce.total_units_at(Living.home())+Ecommerce.total_units_at("popup_retail")
	PopupStore.finish();runner.eq(Ecommerce.total_units_at(Living.home())+Ecommerce.total_units_at("popup_retail"),total,"repeat close no stock recreation")
	runner.check(Ledger.check_balanced(),"closure balances")
func test_old_save_lazy_defaults_save_load_and_finite_price() -> void:
	setup();GameState.data.erase("popup");runner.check(PopupStore.active().is_empty(),"old save no active lease")
	PopupStore.sign(PopupStore.next_weekend());PopupStore.move_stock("water_bottle",Living.home(),50)
	runner.check(not PopupStore.set_price("water_bottle",NAN)["ok"],"NaN refused")
	runner.check(not PopupStore.set_price("water_bottle",0)["ok"],"zero refused")
	runner.check(SaveSystem.save(8) and SaveSystem.load_data(8),"active weekend saved")
	runner.eq(Ecommerce.stock("popup_retail","water_bottle"),50,"stock survives load")
	runner.eq(PopupStore.return_reserved(Living.home()),50,"origin survives load")
	runner.check(Housing.capacity_block("riverside_1a")!="","moving waits for return no overflow")
func test_employee_actual_hourly_pay_fired_staff_stops() -> void:
	var start:=ready();var ent:=GameState.company_id()
	Staff.S()["people"]["QA"]={"id":"QA","name":"Checkout","role":"packer","start":start,"skill":3,"morale":70,"salary_week":500,"appearance":GameState.default_appearance(),"outfit":"startup_casual"}
	runner.check(PopupStore.assign("QA",6)["ok"],"Saturday assigned")
	GameState.data["clock"]["minutes"]=start+60;PopupStore.on_hour(start+60,11)
	runner.eq(PopupStore.active()["wages"],18,"one actual extra hour paid")
	runner.eq(Ledger.balance(ent,"exp:payroll"),18,"payroll journal eighteen dollars")
	Staff.S()["people"].erase("QA");var sold: int=int(PopupStore.active()["units"])
	PopupStore.on_hour(start+120,12);runner.eq(PopupStore.active()["units"],sold,"fired staff cannot keep selling")
	runner.eq(PopupStore.active()["wages"],18,"fired staff not paid again")
	runner.check(Ledger.check_balanced(),"employee ledger balances")

func test_van_transfer_busy_guard_and_no_duplicate_staff_work() -> void:
	ready();Ledger.post(GameState.company_id(),"QA van capital",[{"acct":"cash","dr":20000},{"acct":"equity","cr":20000}]);runner.check(Logistics.buy_van()["ok"],"actual funded van purchase")
	var before:=Ledger.balance(GameState.company_id(),"exp:shipping");var t:=Clock.now()
	runner.check(PopupStore.move_stock("water_bottle",Living.home(),10)["ok"],"van transfers actual inventory")
	runner.eq(Ledger.balance(GameState.company_id(),"exp:shipping"),before,"available van no extra service fee")
	runner.eq(Clock.now(),t+60,"van still takes one hour")
	LogisticsDepth.vehicles()["van1"]["busy_until"]=Clock.now()+120
	runner.check(not PopupStore.move_stock("water_bottle",Living.home(),1)["ok"],"busy van wait actionable")
	Staff.S()["people"]["QA"]={"id":"QA","role":"barista","start":0}
	PopupStore.assign("QA",6)
	var start:=int(PopupStore.active()["start"])
	runner.check(not Staff.is_working(Staff.S()["people"]["QA"],start+60),"normal duties overridden")
	runner.check(not CafeDepth.scheduled(Staff.S()["people"]["QA"],start+60,"corner_cafe"),"no two counters simultaneously")
func test_capacity_return_reservation_and_shared_premises() -> void:
	setup();PopupStore.sign(PopupStore.next_weekend());PopupStore.move_stock("water_bottle",Living.home(),50)
	var cap:=Ecommerce.location_capacity(Living.home())
	runner.check(Ecommerce.space_block(Living.home(),cap-99)!="","origin reserved stock prevents overflow")
	runner.check(not Living.lease("popup_cafe")["ok"],"same premises not double-leased")
	var actions:=BuildingInfo.interactables("popup_unit")
	runner.check(not actions.any(func(it):return it["action"]=="cafe_counter"),"retail tenant no wrong cafe counter")
	PopupStore.finish();Ledger.post(GameState.company_id(),"QA premises capital",[{"acct":"cash","dr":10000},{"acct":"equity","cr":10000}]);runner.check(Living.lease("popup_cafe")["ok"],"actual cafe tenant")
	runner.check(not PopupStore.sign(PopupStore.next_weekend())["ok"],"cafe tenant blocks retail too")
func test_checkout_minigame_practice_and_abort_no_income() -> void:
	ready();var ent:=GameState.company_id();var before:=Ledger.cash(ent)
	var game:=PopupCheckoutGame.new()
	game.rounds=1;game.points=1
	runner.eq(game.score(),1.0,"checkout score measures correct amount")
	runner.eq(Ledger.cash(ent),before,"practice creates no cash")
	runner.eq(PopupStore.active()["units"],0,"practice creates no imaginary sale")
	game.free()
func test_balance_three_strategies_real_trades_with_low_traffic_risk() -> void:
	var results: Array=[]
	var original:=float(PopupStore.cfg()["footfall_hour"])
	for strategy in ["owner","employee","expensive"]:
		var profits: Array=[]
		for seed in [4,12,24]:
			runner._fresh_game();setup();GameState.rng.seed=seed
			var start:=PopupStore.next_weekend();PopupStore.sign(start);PopupStore.move_stock("water_bottle",Living.home(),100)
			var a:=PopupStore.active()
			if strategy=="expensive":PopupStore.set_price("water_bottle",40)
			if strategy=="employee":
				Staff.S()["people"]["QA"]={"id":"QA","role":"packer","start":0}
				PopupStore.assign("QA",6);PopupStore.assign("QA",0)
			# Controlled downside sensitivity; no injected revenue or assumed sell-through.
			PopupStore.cfg()["footfall_hour"]=2.0 if seed==24 else original
			for day in [0,1]:
				for hour in range(10,18):
					var t: int=start+day*Clock.DAY+(hour-10)*60
					GameState.data["clock"]["minutes"]=t+60
					if strategy!="employee":a["owner_from"]=t;a["owner_until"]=t+60;a["score"]=.85
					PopupStore.on_hour(t+60,hour+1)
			PopupStore.finish()
			var r: Dictionary=PopupStore.S()["history"][-1];profits.append(float(r["net"]))
			runner.check(Ledger.check_balanced(),"strategy books balance")
		var average: float=(profits[0]+profits[1]+profits[2])/3.0
		runner.check(profits.any(func(p):return p<0),"each strategy can lose under low traffic")
		if strategy=="owner":runner.check(average>0,"reasonable owner strategy profits on average")
		results.append({"strategy":strategy,"profits":profits,"average":average})
	PopupStore.cfg()["footfall_hour"]=original
	print("popup_balance: "+JSON.stringify(results))
