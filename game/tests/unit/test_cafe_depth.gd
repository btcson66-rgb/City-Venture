extends RefCounted
var runner
func setup() -> String:
	Company.register("Café Depth","retail_online","Lantern Row")
	Company.open_business_account(20000)
	Ledger.post(GameState.company_id(),"Operating fixture equity",[{"acct":"cash","dr":60000},{"acct":"equity","cr":60000}])
	Living.lease("corner_cafe");Cafe.fit_out();Cafe.apply_permit();Cafe.order_supplies("large")
	Clock.advance(3*Clock.DAY)
	return GameState.company_id()
func hire() -> Dictionary:
	Staff.register_employer();Staff.post_job("barista")
	Clock.advance(19*60)
	var app: Dictionary=Staff.S()["applicants"][0]
	Staff.hire(app["id"])
	return Staff.people()[0]
func test_six_items_prices_margin_recipe_and_seasonal_demand() -> void:
	setup()
	runner.eq(Cafe.cfg()["items"].size(),6,"six different menu items")
	for id in Cafe.cfg()["items"]:
		var item:=Cafe.item(id)
		runner.eq(CafeDepth.margin(id),Cafe.price(id)-float(item["unit_cost"]),"unit dollars margin: "+id)
		var cost:=0.0
		for material in item["materials"]:cost+=float(Cafe.cfg()["materials"][material]["unit_cost"])*int(item["materials"][material])
		runner.check(absf(cost-float(item["unit_cost"]))<.001,"recipe and declared cost match: "+id)
		for ingredient in item["materials"]:runner.check(Cafe.cfg()["materials"].has(ingredient),"real ingredient: "+ingredient)
	var june:=Clock.now()
	runner.check(CafeDepth.seasonal("seasonal",june),"summer special available")
	runner.check(not CafeDepth.seasonal("seasonal",june+95*Clock.DAY),"autumn special off menu")
	var before:=Cafe.price("latte");Cafe.set_price("latte",NAN)
	runner.eq(Cafe.price("latte"),before,"nonfinite price rejected")
func test_material_delivery_separate_inventory_cost_and_capacity() -> void:
	var entity:=setup()
	var before:=Ledger.cash(entity)
	runner.check(CafeDepth.order("milk")["ok"],"actual milk purchase")
	runner.eq(Cafe.S()["materials"]["milk"],0,"milk does not appear before delivery")
	runner.eq(Cafe.S()["material_incoming"]["milk"],100,"incoming milk units")
	Clock.advance(Clock.DAY)
	runner.eq(Cafe.S()["materials"]["milk"],100,"paid milk arrives")
	runner.check(Ledger.cash(entity)<before,"cash actually leaves company")
	Cafe.S()["materials"]["food"]=1200
	runner.check(not CafeDepth.order("food")["ok"],"full ingredient bin guarded")
	runner.check(Ledger.check_balanced(),"ingredient costs balance")
func test_no_shift_no_customers_and_two_locations_cannot_double_book_staff() -> void:
	setup();var person:=hire()
	CafeDepth.roster()[person["id"]]={}
	var t:=Clock.DAY+8*60
	runner.eq(Cafe.baristas_at(t).size(),0,"explicit unassigned morning")
	CafeDepth.assign(person["id"],1,"early")
	runner.eq(Cafe.baristas_at(t).size(),1 if t>=int(person["start"]) else 0,"real scheduled barista")
	Living.lease("popup_cafe")
	Cafe.in_shop("popup_cafe",func():CafeDepth.assign(person["id"],1,"early"))
	runner.check(CafeDepth.roster()[person["id"]]["1:early"]=="popup_cafe","staff moved to second roster once")
	runner.eq(Cafe.baristas_at(t).size(),0,"first shop no longer has worker")
func test_actual_overtime_and_cleanup_minutes_are_paid() -> void:
	var entity:=setup();var person:=hire()
	var t:=int(person["start"])+60
	while Clock.weekday(t)!=1:t+=Clock.DAY
	t=t-t%Clock.DAY+8*60
	CafeDepth.roster()[person["id"]]={"1:early":"corner_cafe"}
	GameState.data["cafe"]["work_hours"][person["id"]]={"week":Clock.day_index_at(t)/7,"hours":40.0,"last":-1}
	var before:=Ledger.cash(entity)
	CafeDepth.record_hours(t)
	runner.eq(Ledger.cash(entity),before-snappedf(float(person["salary_week"])/40*1.5,.01),"one overtime hour at 1.5 pay")
	var paid:=Ledger.cash(entity);CafeDepth.record_hours(t)
	runner.eq(Ledger.cash(entity),paid,"same hour cannot double pay")
	CafeDepth.record_hours(t,.25)
	runner.check(Ledger.cash(entity)<paid,"fifteen cleaning minutes consume overtime")
	runner.check(Ledger.check_balanced(),"wages balance")
func test_inspection_pass_improvement_fine_and_pause_decay() -> void:
	var entity:=setup()
	var s:=Cafe.S()
	s["inspection_pending"]=true;s["cleaned"]=Clock.now();s["rating"]=4;s["days"]=[]
	runner.eq(CafeDepth.inspect()["outcome"],"pass","clean shop passes")
	runner.check(not CafeDepth.inspect()["ok"],"already inspected no repeated rating")
	s["inspection_pending"]=true;s["cleaned"]=-1
	runner.eq(CafeDepth.inspect()["outcome"],"improve","single failure means improve")
	runner.check(int(s["inspection_until"])>Clock.now(),"actual one-day closure")
	runner.check(not Cafe.is_open_now(),"owner cannot bypass inspection closure")
	Clock.advance(Clock.DAY+60)
	runner.check(int(s["inspection_until"])<Clock.now(),"closure expires")
	s["inspection_pending"]=true;s["rating"]=1;s["days"]=[{"served":10,"waste":8,"stock_lost":2}]
	var before:=Ledger.cash(entity)
	runner.eq(CafeDepth.inspect()["outcome"],"fine","bad stock/waste/rating fines")
	runner.eq(Ledger.cash(entity),before-250,"actual fine in dollars")
	runner.check(Ledger.check_balanced(),"inspection costs balance")
func test_second_shop_ledger_stock_ratings_separate_and_till_idempotent() -> void:
	var entity:=setup()
	runner.check(Living.lease("popup_cafe")["ok"],"actual second location lease")
	Cafe.in_shop("popup_cafe",func():
		Cafe.fit_out();Cafe.apply_permit();Cafe.order_supplies("large"))
	Clock.advance(3*Clock.DAY)
	var first:=Cafe.S()
	var second: Dictionary=Cafe.in_shop("popup_cafe",Cafe.S)
	first["rating"]=4.5;second["rating"]=2.5
	runner.eq(first["rating"],4.5,"second rating independent")
	var before:=int(first["supplies"])
	Cafe.in_shop("popup_cafe",func():CafeDepth.sell(20))
	runner.eq(first["supplies"],before,"second recipe consumption not first stock")
	var td:=Cafe._today();td["rev"]=100;td["served"]=10;td["open_hours"]=1
	Cafe._close_day();var cash:=Ledger.cash(entity);Cafe._close_day()
	runner.eq(Ledger.cash(entity),cash,"already closed till cannot pay again")
	runner.check(Ledger.check_balanced(),"two locations balanced")
func test_legacy_single_store_defaults_save_roundtrip_and_closure() -> void:
	var entity:=setup()
	var old: Dictionary=GameState.data["cafe"].duplicate(true)
	for key in ["branches","roster","work_hours","materials","material_incoming","cleaned","inspection_next","inspection_until","inspection_pending","inspections"]:old.erase(key)
	old["prices"]={"coffee":4.2,"pastry":3.8}
	GameState.data["cafe"]=old
	runner.eq(Cafe.S()["prices"].size(),6,"old price map defaults added")
	runner.eq(Cafe.S()["materials"]["beans"],old["supplies"],"legacy coffee units retained")
	runner.check(SaveSystem.save(5) and SaveSystem.load_data(5),"new cafe depth roundtrip")
	Insolvency.begin(entity,"Closure boundary")
	runner.check(Insolvency.close_company()["ok"],"company closes")
	runner.check(not CafeDepth.order("milk")["ok"],"closed company cannot buy ingredients")
	runner.check(Ledger.check_balanced(),"closure balanced")

func test_inspection_real_choices_timeout_and_closed_company_no_softlock() -> void:
	var entity:=setup()
	var s:=Cafe.S()
	s["inspection_next"]=Clock.now();s["cleaned"]=-1;s["rating"]=4;s["days"]=[]
	CafeDepth.inspection_due()
	var iid: String=s["inspection_iid"]
	var before:=Clock.now()
	runner.check(EventEngine.choose(iid,"prepare")["ok"],"prepare is real clock and clean action")
	runner.eq(Clock.now(),before+15,"preparing uses 15 minutes")
	runner.eq(s["inspections"][-1]["outcome"],"pass","prepared clean shop passes")
	runner.check(not EventEngine.choose(iid,"prepare")["ok"],"already decided cannot replay")
	s["inspection_next"]=Clock.now();s["cleaned"]=-1
	CafeDepth.inspection_due();GameState.data["clock"]["minutes"]=s["inspection_deadline"]
	CafeDepth.inspection_due()
	runner.check(not s["inspection_pending"],"ignored notice times out without soft lock")
	runner.eq(s["inspections"][-1]["outcome"],"improve","timeout inspects current state")
	s["inspection_next"]=Clock.now();CafeDepth.inspection_due()
	var closed_iid: String=s["inspection_iid"]
	Insolvency.begin(entity,"Inspection closure test");Insolvency.close_company()
	var cash:=Ledger.cash("player")
	runner.check(EventEngine.choose(closed_iid,"as_is")["ok"],"impossible closed shop decision settles")
	runner.eq(Ledger.cash("player"),cash,"no unrelated personal penalty")
	runner.check(Ledger.check_balanced(),"event choices balance")

func test_genuine_pre_depth_played_save_loads_old_cafe_defaults() -> void:
	var text:=FileAccess.get_file_as_string("res://tests/fixtures/saves/moving_house_32.json")
	runner.check(SaveSystem._atomic_write(SaveSystem._path(7),text),"unedited pre-depth save installed")
	runner.check(SaveSystem.load_data(7),"genuine pre-depth save loads")
	var supplies:=int(Cafe.S()["supplies"])
	runner.eq(Cafe.S()["prices"].size(),6,"historical menu receives defaults")
	runner.eq(Cafe.S()["materials"]["beans"],supplies,"historical stock retained")
	runner.check(Ledger.check_balanced(),"historical books preserved")

func test_second_licence_and_cleaning_do_not_skip_real_hours() -> void:
	setup();Living.lease("popup_cafe")
	runner.check(not Cafe.in_shop("popup_cafe",Cafe.permitted),"first licence never licenses second premises")
	var p:=hire()
	var t:=int(p["start"])+Clock.DAY
	while Clock.weekday(t)!=1:t+=Clock.DAY
	t=t-t%Clock.DAY+8*60
	CafeDepth.roster()[p["id"]]={"1:early":"corner_cafe"}
	CafeDepth.record_hours(t,.25);CafeDepth.record_hours(t)
	runner.eq(GameState.data["cafe"]["work_hours"][p["id"]]["hours"],1.25,"cleaning does not suppress operating hour")

func test_report_costs_belong_to_current_company_only() -> void:
	var company:=setup()
	var current:=CafeDepth.booked_margin(Clock.day_index(),100)
	Ledger.post("player","Different owner same address",[{"acct":"cogs","dr":50},{"acct":"cash","cr":50}],{"property":"corner_cafe"})
	runner.eq(CafeDepth.booked_margin(Clock.day_index(),100),current,"other entity cannot change café margin")
	runner.check(GameState.company_id()==company and Ledger.check_balanced(),"scope and ledger preserved")
