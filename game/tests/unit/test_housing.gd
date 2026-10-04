extends RefCounted
var runner
func setup() -> void:
	GameState.data["tutorial"]={"off":true,"v":3,"step":99}
func test_home_data_and_opening_deposit_are_not_sales_income() -> void:
	setup()
	for property in DataDB.properties.values():
		if property.get("kind","")!="home":continue
		for key in ["building","bed","bed_position","inventory_units","monthly_rent"]:runner.check(property.has(key),"data driven home: "+key)
	runner.eq(Ledger.cash("player"),30000,"arrival savings unchanged")
	runner.eq(Ledger.balance("player","home_deposit"),1250,"pre-arrival deposit is an opening asset")
	runner.eq(MonthClose.current("player")["net_revenue"],0,"deposit is not sales")
func test_immediate_move_rent_stock_deposit_first_fee_and_repeat_guards() -> void:
	setup()
	Ecommerce._add_stock(Living.home(),"phone_stand",8,5,0)
	var before:=Ledger.cash("player")
	var first_fee:=Housing.fee()
	runner.check(first_fee>0,"the first move pays the moving service too")
	runner.check(Housing.request("old_town_studio","penalty")["ok"],"immediate move")
	runner.eq(Living.home(),"old_town_studio","new property")
	runner.eq(Living.home_building(),"old_town_studio","new building")
	runner.eq(Living.home_bed(),"bed_side","configured bed")
	runner.eq(Ledger.cash("player"),before-780-first_fee,"new deposit + old termination - old refund + moving service")
	runner.eq(Ecommerce.stock("old_town_studio","phone_stand"),8,"physical stock moved")
	runner.eq(Ecommerce.stock("riverside_studio","phone_stand"),0,"old stock cleared")
	runner.check(Ecommerce.space_block("riverside_studio",1)!="","cannot buy new stock into released home")
	runner.check(not Housing.request("old_town_studio","penalty")["ok"],"already done cannot pay again")
	runner.check(not Housing.execute()["ok"],"already executed no repeat")
	var cash:=Ledger.cash("player")
	Living.pay_home_rent()
	runner.eq(Ledger.cash("player"),cash-780,"new monthly rent")
	runner.check(Housing.fee()>0,"second move costs real service")
	runner.check(Ledger.check_balanced(),"housing books balanced")
func test_notice_is_real_wait_and_cancel_returns_exact_deposit_once() -> void:
	setup()
	var before:=Ledger.cash("player")
	runner.check(Housing.request("old_town_studio","notice")["ok"],"reserve with notice")
	runner.eq(Living.home(),"riverside_studio","old home until notice expires")
	runner.eq(Ledger.cash("player"),before-780,"new deposit actually held")
	runner.check(not Housing.execute()["ok"],"cannot skip notice")
	runner.check(not Housing.request("old_town_studio","notice")["ok"],"already reserved")
	Housing.cancel();Housing.cancel()
	runner.eq(Ledger.cash("player"),before,"deposit returned once")
	runner.check(Housing.request("old_town_studio","notice")["ok"],"can reserve again")
	GameState.data["clock"]["minutes"]=Housing.S()["pending"]["ready"]
	Housing.on_hour()
	runner.eq(Living.home(),"old_town_studio","notice move completes")
	runner.eq(Housing.S()["history"][-1]["penalty"],0,"notice has no early termination fee")
func test_capacity_incoming_and_blocked_notice_have_cancel_and_retry_escape() -> void:
	setup()
	Ecommerce._add_stock(Living.home(),"phone_stand",201,5,0)
	var before:=Ledger.cash("player")
	runner.check(not Housing.request("old_town_studio","penalty")["ok"],"small home refuses excess stock")
	runner.eq(Ledger.cash("player"),before,"blocked capacity spends nothing")
	Ecommerce.inv(Living.home())["phone_stand"]["qty"]=100
	runner.check(Housing.request("old_town_studio","notice")["ok"],"initial capacity fits")
	Ecommerce._add_stock(Living.home(),"phone_stand",150,5,0)
	GameState.data["clock"]["minutes"]=Housing.S()["pending"]["ready"]
	Housing.on_hour()
	runner.eq(Housing.S()["pending"]["stage"],"blocked","capacity changed during notice")
	runner.eq(Living.home(),"riverside_studio","not displaced or made homeless")
	runner.check(Housing.cancel()["ok"],"impossible move has cancel escape")
	Ecommerce.inv(Living.home())["phone_stand"]["qty"]=100
	Housing.request("old_town_studio","notice")
	GameState.data["clock"]["minutes"]=Housing.S()["pending"]["ready"]
	runner.check(Housing.execute()["ok"],"fixed capacity retries")
func test_home_move_transfers_all_company_stock_pending_work_and_preserves_ownership() -> void:
	setup()
	Company.register("Home First","retail_online","Riverside")
	Company.open_business_account(1000)
	var first:=GameState.company_id()
	Ecommerce._add_stock(Living.home(),"phone_stand",3,5,0)
	Company.register("Home Second","retail_online","Riverside")
	Company.open_business_account(1000)
	var second:=GameState.company_id()
	Ecommerce._add_stock(Living.home(),"phone_stand",4,6,0)
	var paid:=Ledger.cash(second)
	runner.check(Housing.request("old_town_studio","penalty")["ok"],"household move")
	runner.eq(GameState.company_id(),second,"active company preserved")
	runner.eq(Ecommerce.stock(Living.home(),"phone_stand"),4,"second firm stock")
	runner.eq(Ledger.cash(second),paid,"company funds not moving expenses")
	CompanyPortfolio.switch(first)
	runner.eq(Ecommerce.stock(Living.home(),"phone_stand"),3,"first firm stock also moved")
	runner.eq(Ecommerce.avg_cost(Living.home(),"phone_stand"),5,"cost kept")
func test_old_save_default_and_new_save_pending_notice_survive_reload() -> void:
	setup()
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)
	var f:=FileAccess.open(SaveSystem._path(6),FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/contracts_closed_pre36.json"));f.close()
	runner.check(SaveSystem.load_data(6),"actual old fixture loads")
	runner.eq(Living.home(),"riverside_studio","old save defaults Riverside")
	runner.check(Housing.S()["deposits"].is_empty(),"old deposit receipt not invented")
	setup()
	runner.check(Housing.request("old_town_studio","notice")["ok"],"reserve old save home")
	runner.check(SaveSystem.save(5) and SaveSystem.load_data(5),"pending notice persisted")
	GameState.data["clock"]["minutes"]=Housing.S()["pending"]["ready"]
	Housing.on_hour()
	runner.eq(Living.home(),"old_town_studio","loaded scheduled move completes")
	runner.check(Ledger.check_balanced(),"migration and move balanced")
func test_new_home_laptop_table_bed_and_old_tenant_locks() -> void:
	setup()
	Housing.request("old_town_studio","penalty")
	runner.check(BuildingInfo.building_available("old_town_studio"),"owned studio is a public usable destination")
	var interior:=Interior.new()
	interior.build(Living.home_building())
	var actions: Array=DataDB.building(Living.home_building())["interior"]["interactables"].map(func(item):return item["action"])
	for action in ["sleep","open_company_os","pack_orders"]:runner.check(actions.has(action),"new home usable: "+action)
	runner.eq(Actions.lock_reason("open_company_os",{"requires":"home:old_town_studio"}),"","tenant laptop usable")
	runner.check(Actions.lock_reason("sleep",{"requires":"home:riverside_studio"})!="","old home belongs to next tenant")
	interior.free()
func test_first_venture_cannot_move_and_pending_delivery_address_follows_home() -> void:
	GameState.data["tutorial"]={"off":false,"v":Tutorial.VERSION,"step":0}
	runner.check(not Housing.request("old_town_studio","notice")["ok"],"arrival remains Riverside")
	setup()
	var bought:=Ecommerce.buy("tradelink_wholesale","phone_stand",80)
	runner.check(bought["ok"],"real PO")
	var po: Dictionary=Ecommerce.E()["purchase_orders"][bought["po_id"]]
	runner.check(Housing.request("old_town_studio","penalty")["ok"],"move with delivery")
	runner.eq(po["location"],Living.home(),"incoming PO rerouted")
	Ecommerce._h_po_arrive({"po":po["id"]})
	runner.check(Ecommerce.stock(Living.home(),"phone_stand")>=10,"arrives at new home")

func test_notice_cash_shortfall_keeps_home_and_refund_escape_without_fee() -> void:
	setup()
	Housing.S()["moves"]=1
	Housing.request("old_town_studio","notice")
	Ledger.expense("player","living",Ledger.cash("player"),"Consumed personal cash fixture")
	GameState.data["clock"]["minutes"]=Housing.S()["pending"]["ready"]
	Housing.on_hour()
	runner.eq(Living.home(),"riverside_studio","cash shortage cannot displace player")
	runner.eq(Housing.S()["pending"]["stage"],"blocked","no auto overdraft moving fee")
	runner.check(Housing.cancel()["ok"],"refund escape remains")
	runner.eq(Ledger.cash("player"),780,"deposit refund remains real cash")
