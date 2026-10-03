extends RefCounted
var runner

func stock() -> void:
	Ecommerce._add_stock("home","water_bottle",30,10.0,0.0)
	Ecommerce.create_listing("water_bottle",20.0,"self")

func test_research_premium_tiers_cache_and_invalid_product() -> void:
	stock()
	var before := Clock.now()
	var result := ShopLife.research("water_bottle")
	runner.check(result["ok"],"owned product researched")
	var ref := float(DataDB.product("water_bottle")["ref_price"])
	runner.check(float(result["card"]["price"])>=ref*1.3-0.01 and float(result["card"]["price"])<=ref*1.6+0.01,"premium interval")
	runner.eq(Clock.now()-before,30,"research uses 30 minutes")
	before=Clock.now()
	var again := ShopLife.research("water_bottle")
	runner.eq(again["card"],result["card"],"seven-day cache stable")
	runner.eq(Clock.now(),before,"cache uses no time")
	Ecommerce.listing_for("water_bottle")["price"]=ref*0.5
	runner.eq(ShopLife.tier("water_bottle"),"Cheap","cheap comparison")
	Ecommerce.listing_for("water_bottle")["price"]=ref*1.3
	runner.eq(ShopLife.tier("water_bottle"),"Expensive","high comparison")
	runner.check(not ShopLife.research("missing")["ok"],"invalid product rejected")
	GameState.data["clock"]["minutes"]=int(result["card"]["until"])
	before=Clock.now()
	runner.check(not ShopLife.research("water_bottle")["cached"] and Clock.now()==before+30,"expiry requires fresh work")

func test_membership_renewal_cancel_rejoin_and_insufficient_cash() -> void:
	var cash := Ledger.cash("player")
	runner.check(ShopLife.buy(true)["ok"],"monthly purchase")
	runner.eq(Ledger.cash("player"),cash-45.0,"personal fee 45")
	runner.check(not ShopLife.buy(true)["ok"],"duplicate signup rejected")
	var due := int(ShopLife.S()["paid_until"])
	GameState.data["clock"]["minutes"]=due
	ShopLife.on_hour(due)
	runner.eq(Ledger.cash("player"),cash-90.0,"one monthly renewal")
	ShopLife.on_hour(due)
	runner.eq(Ledger.cash("player"),cash-90.0,"renewal is idempotent")
	ShopLife.cancel()
	runner.check(ShopLife.has_pass(),"paid access remains after cancellation")
	runner.check(ShopLife.buy(true)["ok"],"rejoin within paid period")
	runner.eq(Ledger.cash("player"),cash-90.0,"rejoin never charges paid month twice")
	ShopLife.cancel()
	GameState.data["clock"]["minutes"]=int(ShopLife.S()["paid_until"])
	ShopLife.on_hour(Clock.now())
	runner.eq(Ledger.cash("player"),cash-90.0,"cancel stops renewal")
	runner.check(not ShopLife.has_pass(),"paid access expires")
	var balance := Ledger.cash("player")
	Ledger.expense("player","living",balance,"QA zero cash")
	runner.check(not ShopLife.buy(false)["ok"],"cannot buy on insufficient cash")
	runner.check(Ledger.check_balanced(),"personal fitness ledger balanced")
	# A future renewal can also stop automatically without overdrafting personal cash.
	ShopLife.S()["membership"]=true
	ShopLife.S()["paid_until"]=Clock.now()
	ShopLife.on_hour(Clock.now())
	runner.check(not bool(ShopLife.S()["membership"]),"insufficient renewal automatically cancels")
	runner.eq(Ledger.cash("player"),0.0,"failed renewal never creates overdraft")
	runner.check("personal_fitness" in Ledger.PERSONAL and Ledger.CATEGORY_NAMES.has("personal_fitness"),"personal category has translated label")

func test_single_class_time_duplicate_and_saved_state() -> void:
	runner.check(ShopLife.buy(false)["ok"],"single purchase")
	runner.check(not ShopLife.buy(false)["ok"],"one unused single pass")
	GameState.data["clock"]["minutes"]=Clock.at_day_time(1,390)
	var before := Clock.now()
	runner.check(ShopLife.attend("boxing")["ok"],"attend scheduled boxing")
	runner.eq(Clock.now()-before,60,"class consumes one hour")
	runner.check(not ShopLife.has_pass(),"single pass consumed")
	GameState.data["clock"]["minutes"]=before
	runner.check(not ShopLife.attend("boxing")["ok"],"cannot repeat same class")
	GameState.data=JSON.parse_string(JSON.stringify(GameState.data))
	runner.check(ShopLife.S()["classes"].has("%d:boxing"%Clock.day_index()),"class receipt survives load")
	runner.check(not ShopLife.attend("missing")["ok"],"unknown class rejected")
	GameState.data.erase("shop_life")
	runner.check(not ShopLife.has_pass(),"old save has no invented membership")

func test_network_cooldown_real_contract_shipping_and_paid_press() -> void:
	stock()
	var old_chance := float(ShopLife.cfg()["network_chance"])
	ShopLife.cfg()["network_chance"]=1.0
	var seen := {}
	for attempt in 5:
		var id := ShopLife.network()
		if id!="":
			runner.check(not seen.has(id),"network does not repeat within 30 days")
			seen[id]=true
			var inst: Dictionary = EventEngine.pending().filter(func(e):return e["id"]==id)[0]
			runner.check(EventEngine.choose(inst["iid"],"decline")["ok"],"every opportunity can be declined")
	runner.eq(seen.size(),3,"three applicable opportunities")
	ShopLife.cfg()["network_chance"]=old_chance
	var inst := EventEngine.trigger("fitness_press", {"product_id":"water_bottle", "press_fee":Fmt.money(float(ShopLife.cfg()["press_cost"])),"press_days":7})
	var before := Ledger.cash("player")
	runner.check(EventEngine.choose(inst["iid"],"accept")["ok"],"paid press choice through EventEngine")
	runner.eq(Ledger.cash("player"),before-75.0,"event charges disclosed fee once")
	runner.check(not EventEngine.choose(inst["iid"],"accept")["ok"],"completed opportunity cannot be repeated")
	var revenue := Ledger.balance("player","revenue")
	ShopLife.network_choice("order",{})
	runner.check(GameState.data["contracts"].values().any(func(c):return c["buyer"]=="harbor_point_fitness" and c["status"]=="offered"),"network creates actual offered contract")
	runner.eq(Ledger.balance("player","revenue"),revenue,"offer is not income")
	ShopLife.network_choice("carrier",{})
	runner.eq(ShopLife.shipping_factor(),0.85,"carrier changes actual label cost")
	GameState.data["clock"]["minutes"]=int(ShopLife.S()["shipping_until"])
	runner.eq(ShopLife.shipping_factor(),1.0,"carrier trial expires")
	var cash := Ledger.cash(GameState.business_entity())
	runner.check(ShopLife.network_choice("press",{"product_id":"water_bottle"})["ok"],"paid report accepted")
	runner.eq(Ledger.cash(GameState.business_entity()),cash-75.0,"advertising costs actual cash")
	runner.check(Ledger.check_balanced(),"network ledger balanced")
	runner.eq(DataDB.validate().size(),0,"new data fields valid")


func test_renewal_short_month_and_single_primary_screens() -> void:
	var january := Time.get_unix_time_from_datetime_string("2032-01-31T12:00:00")
	var base := Time.get_unix_time_from_datetime_string("2031-06-01T00:00:00")
	var minute := int((january-base)/60)
	var due := ShopLife.next_renewal(minute)
	runner.eq(int(Clock.date_at(due)["month"]),2,"anniversary enters next month")
	runner.eq(int(Clock.date_at(due)["day"]),29,"leap-year short month clamps to last day")
	stock()
	for modal in [FitnessModal.new(true),ResearchModal.new()]:
		UIRoot.open_modal(modal)
		await UIRoot.get_tree().process_frame
		var primary := 0
		for button in modal.find_children("*","Button",true,false):
			if bool(button.get_meta("primary_action",false)):primary+=1
		runner.check(primary<=1,"screen has at most one primary")
		modal.close()
		await UIRoot.get_tree().process_frame


func test_new_shop_destinations_hours_and_preserved_story_look() -> void:
	runner.check(BuildingInfo.building_enterable("harbor_point_fitness"),"fitness is playable destination")
	runner.check(BuildingInfo.building_available("crestline_flagship"),"research store is available before main-story contract")
	var lighting: Dictionary=DataDB.building("crestline_flagship")["interior"]["interactables"][0]
	runner.check(lighting["action"]=="look" and not lighting["params"]["alt"].is_empty(),"chapter five lighting alt preserved")
	GameState.data["clock"]["minutes"]=Clock.at_day_time(0,23*60)
	runner.check(not SceneRouter.building_open("crestline_flagship")["open"],"shop hours still enforced")
