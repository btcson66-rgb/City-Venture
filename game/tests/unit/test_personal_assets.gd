extends RefCounted
var runner
func setup() -> void:
	GameState.data["tutorial"]={"off":true}
	Ledger.post("player","Test capital",[{"acct":"cash","dr":2000000},{"acct":"equity","cr":2000000}])
func test_personal_mortgage_and_owned_move_use_real_cost_and_no_double_rent() -> void:
	setup()
	var before:=Ledger.cash("player")
	runner.check(PersonalAssets.buy_home("maple_owner_home",.2,20)["ok"],"buy small apartment")
	runner.eq(Ledger.cash("player"),before-41400,"20% down and 3% fee")
	runner.eq(-Ledger.balance("player","loan_payable"),144000,"real mortgage")
	runner.check(not PersonalAssets.buy_home("maple_owner_home",.2,20)["ok"],"already owned")
	runner.check(PersonalAssets.move_home("maple_owner_home")["ok"],"move actual home stock")
	runner.eq(Living.home_rent(),0,"owner not charged rental rent")
	GameState.data["clock"]["minutes"]=31*Clock.DAY;PersonalAssets.on_hour()
	runner.check(float(PersonalAssets.S()["homes"]["maple_owner_home"]["balance"])<144000,"principal amortizes")
	runner.check(Ledger.check_balanced(),"mortgage books balance")
func test_housing_ladder_no_softlock_and_sale_has_fee_downside() -> void:
	setup()
	runner.check(not PersonalAssets.buy_home("garden_villa",.2,20)["ok"],"need previous tier")
	runner.check(not PersonalAssets.buy_home("maple_owner_home",NAN,20)["ok"],"finite deposit")
	runner.check(PersonalAssets.buy_home("maple_owner_home",.2,20)["ok"],"first tier")
	runner.check(PersonalAssets.buy_home("heights_penthouse",.3,30)["ok"],"second tier")
	runner.check(PersonalAssets.buy_home("garden_villa",.2,20)["ok"],"villa tier")
	var before:=Ledger.cash("player")
	runner.check(PersonalAssets.sell_home("maple_owner_home")["ok"],"sell empty asset")
	runner.eq(Ledger.cash("player"),before+27000,"sale 171000 minus debt144000")
	runner.check(not PersonalAssets.sell_home("maple_owner_home")["ok"],"sold guard no repeat")
	runner.check(Ledger.check_balanced(),"sale books balance")
	PersonalAssets.move_home("heights_penthouse")
	var city_commute:=PersonalAssets.commute("financial",12,false)
	PersonalAssets.move_home("garden_villa")
	runner.check(PersonalAssets.commute("financial",12,false)>city_commute,"villa access adds actual commute estimate")
func test_occupied_negative_equity_and_rental_notice_recovery() -> void:
	setup();PersonalAssets.buy_home("maple_owner_home",.2,20)
	PersonalAssets.move_home("maple_owner_home")
	runner.check(not PersonalAssets.rent_home("maple_owner_home",1)["ok"],"cannot rent personal home")
	runner.check(not PersonalAssets.sell_home("maple_owner_home")["ok"],"cannot sell current home")
	Housing.request("old_town_studio","penalty")
	runner.check(PersonalAssets.rent_home("maple_owner_home",1)["ok"],"list vacated home")
	var h: Dictionary=PersonalAssets.S()["homes"]["maple_owner_home"]
	h["status"]="tenanted";h["tenant"]={"name":"Test Tenant"}
	runner.check(not PersonalAssets.move_home("maple_owner_home")["ok"],"tenant locks occupancy")
	runner.check(PersonalAssets.end_tenancy("maple_owner_home")["ok"],"real notice")
	var leave:=int(h["leave"]);PersonalAssets.end_tenancy("maple_owner_home")
	runner.eq(h["leave"],leave,"repeated notice does not postpone")
	GameState.data["clock"]["minutes"]=leave;PersonalAssets.on_hour()
	runner.eq(h["status"],"empty","notice completes")
	RealEstateMarket.S()["index"]=.55
	Ledger.expense("player","other",Ledger.cash("player"),"Test outflow")
	runner.check(not PersonalAssets.sell_home("maple_owner_home")["ok"],"negative equity guard")
	runner.check(not PersonalAssets.collect_rent("maple_owner_home")["ok"],"no invented cash invoices")
	runner.check(Ledger.check_balanced(),"rental and arrears balanced")
func test_commute_rush_parking_car_costs_and_repeated_sale() -> void:
	setup()
	runner.check(PersonalAssets.trip("harbor","financial",8)["minutes"]>PersonalAssets.trip("harbor","financial",12)["minutes"],"rush takes longer")
	runner.eq(PersonalAssets.trip("harbor","financial",12)["parking"],14,"central parking dollar fee")
	runner.check(PersonalAssets.trip("industrial","airport",12)["minutes"]<PersonalAssets.metro_minutes("industrial","airport"),"car can be faster")
	runner.check(PersonalAssets.trip("harbor","financial",8)["minutes"]>PersonalAssets.metro_minutes("harbor","financial"),"metro can be faster")
	GameState.data["player"]["location"]={"kind":"interior","id":"dockside_motors"}
	var before:=Ledger.cash("player")
	runner.check(PersonalAssets.buy_car("kite_hatch")["ok"],"personal purchase")
	runner.eq(Ledger.cash("player"),before-10855,"actual price")
	runner.check(not PersonalAssets.buy_car("duke_coupe")["ok"],"one personal car")
	PersonalAssets.S()["parking"]["financial:"+str(Clock.day_index())]=2
	runner.check(not PersonalAssets.drive("financial")["ok"],"parking full offers metro, no soft lock")
	var retained:=Ledger.cash("player")
	runner.eq(retained,before-10855,"failed parking does not charge")
	runner.check(PersonalAssets.sell_car()["ok"],"actual resale depreciation")
	runner.eq(Ledger.cash("player"),before-2215,"no risk free resale")
	runner.check(not PersonalAssets.sell_car()["ok"],"repeat sale no invented income")
	runner.check(Ledger.check_balanced(),"car books balanced")
func test_legacy_save_and_company_closure_leave_personal_assets() -> void:
	setup();PersonalAssets.buy_home("maple_owner_home",.2,20)
	var snap:=PersonalAssets.S().duplicate(true)
	Company.register("Personal boundary","retail_online","Riverside")
	CompanyPortfolio.capture();runner.eq(PersonalAssets.S(),snap,"company context leaves personal state")
	Insolvency.begin(GameState.company_id(),"Boundary test")
	runner.check(Insolvency.close_company()["ok"],"company actually closes")
	runner.eq(PersonalAssets.S(),snap,"closure preserves home mortgage and ownership")
	GameState.data["living"].erase("personal_assets")
	runner.eq(PersonalAssets.S()["homes"].size(),0,"old saves lazy empty assets")
	runner.check(not PersonalAssets.move_home("maple_owner_home")["ok"],"unowned impossible next action")
func test_home_invites_and_furniture_have_costs_limits_no_stat_boost() -> void:
	setup()
	GameState.set_flag("met_maya")
	var cash:=Ledger.cash("player")
	runner.check(PersonalAssets.decorate("warm")["ok"],"paid visual furniture")
	runner.eq(Ledger.cash("player"),cash-850,"furniture costs money")
	runner.check(not PersonalAssets.decorate("warm")["ok"],"already installed")
	runner.check(PersonalAssets.host("maya")["ok"],"actual one hour invitation")
	runner.check(not PersonalAssets.host("maya")["ok"],"no duplicate visit")
	runner.check(not PersonalAssets.host("unknown")["ok"],"unknown guest impossible")
	runner.check(Ledger.check_balanced(),"cosmetic costs balanced")

func test_actual_old_fixture_and_personal_save_roundtrip() -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)
	var f:=FileAccess.open(SaveSystem._path(6),FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string("res://tests/fixtures/contracts_closed_pre36.json"));f.close()
	runner.check(SaveSystem.load_data(6),"real pre-feature fixture")
	runner.eq(PersonalAssets.S()["homes"].size(),0,"no invented owner property")
	setup();Bank.B()["credit"]=680
	runner.check(PersonalAssets.buy_home("maple_owner_home",.2,20)["ok"],"legacy home purchase")
	var balance:=float(PersonalAssets.S()["homes"]["maple_owner_home"]["balance"])
	runner.check(SaveSystem.save(5) and SaveSystem.load_data(5),"owner mortgage state roundtrip")
	runner.eq(PersonalAssets.S()["homes"]["maple_owner_home"]["balance"],balance,"mortgage exact saved")
	runner.check(Ledger.check_balanced(),"save books balance")
func test_electric_charge_requires_real_station_and_metered_cash() -> void:
	setup()
	GameState.data["player"]["location"]={"kind":"interior","id":"dockside_motors"}
	PersonalAssets.buy_car("lumen_ev")
	PersonalAssets.S()["car"]["energy"]=0
	runner.check(not PersonalAssets.charge()["ok"],"no station no invented charge")
	Company.register("Charge Test","energy","Helio")
	Company.open_business_account(25000)
	Ledger.post(GameState.company_id(),"Station equity",[{"acct":"cash","dr":150000},{"acct":"equity","cr":150000}])
	Living.lease("helio_warehouse");Energy.start()
	Energy.S()["storage_cert"]=true;Energy.S()["completed"]=2
	Energy.S()["deals"]["hub_lot"]={"kind":"fee","fee":380.0,"share":0.0}
	runner.check(Energy.build_station("hub_lot","l2")["ok"],"real station build")
	Clock.advance(6*Clock.DAY)
	var site:=Energy.site_of("hub_lot")
	PersonalAssets.S()["car"]["location"]=site["district"]
	GameState.data["player"]["location"]={"kind":"district","id":site["district"]}
	var before:=Ledger.cash("player")
	var amount:=60.0*float(site["price"])
	runner.check(PersonalAssets.charge()["ok"],"physical open station charges")
	runner.eq(PersonalAssets.S()["car"]["energy"],60,"metered kWh")
	runner.eq(Ledger.cash("player"),before-snappedf(amount,.01),"actual operator payment")
	runner.check(not PersonalAssets.charge()["ok"],"already full no double payment")
	runner.check(Ledger.check_balanced(),"personal/operator books balanced")

func test_company_switch_cannot_arbitrage_personal_housing_prices() -> void:
	setup()
	PersonalAssets.buy_home("maple_owner_home",.2,20)
	var price:=PersonalAssets.price("maple_owner_home")
	Company.register("Market separation","retail_online","Riverside")
	RealEstateMarket.S()["index"]=1.7
	runner.eq(PersonalAssets.price("maple_owner_home"),price,"business market cannot change personal sale quote")
	CompanyPortfolio.switch("",false,true)
	runner.eq(PersonalAssets.price("maple_owner_home"),price,"personal market retained")

func test_rental_claims_and_interest_settle_before_sale() -> void:
	setup();PersonalAssets.buy_home("maple_owner_home",.2,20)
	var h: Dictionary=PersonalAssets.S()["homes"]["maple_owner_home"]
	h["invoices"].append({"t":Clock.now(),"amount":75.0,"paid":false})
	Ledger.post("player","Actual unpaid rent",[{"acct":"accounts_receivable","dr":75},{"acct":"revenue","cr":75}])
	runner.check(not PersonalAssets.sell_home("maple_owner_home")["ok"],"cannot strand tenant AR by selling")
	GameState.data["clock"]["minutes"]=Clock.now()+30*Clock.DAY
	runner.check(PersonalAssets.collect_rent("maple_owner_home")["ok"],"claim collects after its due date")
	h["arrears"]=20
	Ledger.post("player","Unpaid mortgage interest",[{"acct":"exp:interest","dr":20},{"acct":"accounts_payable","cr":20}])
	runner.check(PersonalAssets.sell_home("maple_owner_home")["ok"],"sale repays principal and accrued interest")
	runner.eq(Ledger.balance("player","accounts_receivable"),0,"no orphan AR")
	runner.eq(Ledger.balance("player","accounts_payable"),0,"no orphan interest")
	runner.check(Ledger.check_balanced(),"all sale obligations settled")
func test_import_rejects_malformed_personal_assets_before_loading() -> void:
	setup();PersonalAssets.buy_home("maple_owner_home",.2,20)
	runner.check(SaveSystem.save(5),"valid owner save")
	var payload: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SaveSystem._path(5)))
	runner.check(SaveCodec.decode(JSON.stringify(payload))["ok"],"valid nested household record")
	payload["data"]["living"]["personal_assets"]["homes"]["maple_owner_home"]["invoices"]="bad"
	runner.check(not SaveCodec.decode(JSON.stringify(payload))["ok"],"reject malformed invoice array")
	runner.check(PersonalAssets.owned("maple_owner_home"),"rejection did not alter active game")
func test_home_sale_books_only_gain_or_loss_against_book_value() -> void:
	setup()
	PersonalAssets.buy_home("maple_owner_home",.2,20)
	var book:=float(PersonalAssets.S()["homes"]["maple_owner_home"]["book"])
	var income:=Ledger.balance("player","other_income")
	runner.check(PersonalAssets.sell_home("maple_owner_home")["ok"],"sell at a loss after fees")
	runner.eq(Ledger.balance("player","other_income"),income,"proceeds are not income when sold below book")
	runner.check(Ledger.balance("player","exp:other")>=book-171000,"loss against carrying value is expensed")
	runner.eq(Ledger.balance("player","property_assets"),0,"asset leaves the books at its carrying value")
	PersonalAssets.buy_home("maple_owner_home",.2,20)
	RealEstateMarket.S()["index"]=1.4
	var before:=Ledger.balance("player","other_income")
	runner.check(PersonalAssets.sell_home("maple_owner_home")["ok"],"sell after the market rose")
	var h: Dictionary=PersonalAssets.S()["homes"]["maple_owner_home"]
	var proceeds:=snappedf(snappedf(float(h["base_price"])*1.4,.01)*(1-float(PersonalAssets.cfg()["sale_fee"])),.01)
	runner.eq(Ledger.balance("player","other_income"),before-(proceeds-float(h["book"])),"only the gain above book is income (credit-negative balance)")
	runner.check(Ledger.check_balanced(),"disposal balanced")
func test_repeated_missed_mortgage_payments_end_in_foreclosure_without_homelessness() -> void:
	setup()
	PersonalAssets.buy_home("maple_owner_home",.2,20)
	runner.check(PersonalAssets.move_home("maple_owner_home")["ok"],"live in the owned home")
	Ledger.expense("player","other",Ledger.cash("player"),"QA personal cash drain")
	var credit:=PersonalAssets.personal_credit()
	var home: Dictionary=PersonalAssets.S()["homes"]["maple_owner_home"]
	for month in int(PersonalAssets.cfg()["foreclosure_missed"]):
		GameState.data["clock"]["minutes"]=int(home["next"])
		PersonalAssets.on_hour()
	runner.eq(home["status"],"sold","lender repossesses after repeated default")
	runner.eq(float(home["balance"]),0.0,"no mortgage remains after the forced sale")
	runner.eq(Ledger.balance("player","property_assets"),0,"home leaves the personal books")
	runner.check(PersonalAssets.personal_credit()<credit,"foreclosure damages credit")
	runner.eq(Living.home(),"riverside_studio","the player is never left without a home")
	runner.check(Ledger.check_balanced(),"foreclosure books balance")
	runner.check(not PersonalAssets.sell_home("maple_owner_home")["ok"],"a foreclosed home cannot be sold again")
func test_personal_market_reads_do_not_switch_company_context() -> void:
	setup()
	Company.register("Housing Reader","retail_online","Riverside")
	Company.open_business_account(1000)
	var active:=GameState.company_id()
	RealEstateMarket.S()
	CompanyPortfolio.capture()
	var quote:=PersonalAssets.price("maple_owner_home")
	runner.check(quote>0,"personal price is available from a company view")
	runner.eq(GameState.company_id(),active,"quote never switches the viewed company")
	runner.eq(PersonalAssets.personal_credit(),CompanyPortfolio.run_in("",func():return Bank.credit()),"stored personal credit matches the personal context")
