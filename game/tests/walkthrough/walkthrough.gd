class_name Walkthrough
extends RefCounted
## The Vertical Slice walkthrough, played through real input by the bot:
## New Game → Character Creator → Arrival → Apartment → Riverside → Bloom Coffee → Startup Hub →
## Nexus Co-work → Business Board → buy stock → list → first order → pack/ship → first dollar →
## customer issue → City Hall registration → Nexus Bank → Suite 2B lease → Company OS → month close.

var bot
var shots_taken := {}
var _tried := {}


func _init(b) -> void:
	bot = b
	bot.popup_handler = popups


func run() -> void:
	await _new_game()
	await _chapter1()
	await _chapter2()
	await _chapter3()
	if bot.video_mode:
		await _video_epilogue()
	else:
		await _month()
	await _save_load()
	bot.step("Summary")
	var be := GameState.business_entity()
	bot.log_line("  business entity %s cash %s · personal %s · orders delivered %d · chapters done %s" % [
		be, Fmt.money(Ledger.cash(be)), Fmt.money(Ledger.cash("player")), int(GameState.stat("orders_delivered")),
		str(GameState.data["story"]["chapters_done"])])
	bot.expect(Ledger.check_balanced(), "ledger balanced at the end")


# ------------------------------------------------------------------ helpers
func popups() -> void:
	# answer any decision / month close that surfaced while we were busy
	var guard := 0
	while guard < 6:
		guard += 1
		var m = UIRoot.top_modal()
		if m == null:
			return
		if m is DecisionModal:
			var inst: Dictionary = m.inst
			await bot.shot("decision_" + str(inst["id"]))
			var pick := _pick_choice(inst)
			# a decision that is still open after we answered it is a bug: report it, then try another choice
			var tried: Array = _tried.get(inst["iid"], [])
			if not tried.is_empty():
				bot.expect(false, "decision %s stayed open after choosing '%s'" % [inst["id"], tried.back()])
				for c in DataDB.events[inst["id"]]["choices"]:
					if not c["id"] in tried and EventEngine.choice_available(c, inst["ctx"]):
						pick = c["id"]
						break
			tried.append(pick)
			_tried[inst["iid"]] = tried
			bot.log_line("  decision %s → %s" % [inst["id"], pick])
			if not await bot.click_named("Choice_" + pick, 3.0):
				await bot.click_text("", 1.0)
			await bot.wait(1.2)
			if bot.button_text("OK") != null:
				await bot.shot("decision_outcome_" + str(inst["id"]))
				await bot.click_text("OK")
			await bot.wait(0.4)
		elif m is MonthCloseModal:
			await bot.wait(1.5)
			await bot.shot("month_close_report")
			var cont: Button = m.footer.get_child(m.footer.get_child_count() - 1) if m.footer.get_child_count() > 0 else null
			bot.log_line("  click [month close] %s" % (cont.text if cont else "—"))
			await bot.click(cont)
			await bot.wait(0.4)
			if is_instance_valid(m) and UIRoot.top_modal() == m:
				var hov: Control = bot.get_viewport().gui_get_hovered_control()
				bot.fail("month close did not close (pending %d, hovered %s)" % [UIRoot._pending_reports.size(), str(hov.get_path()) if hov else "none"])
				m.close()
		else:
			return


func _pick_choice(inst: Dictionary) -> String:
	match str(inst["id"]):
		"customer_return_first", "customer_return":
			var rep := {}
			for c in DataDB.events[inst["id"]]["choices"]:
				if c["id"] == "replace":
					rep = c
			return "replace" if EventEngine.choice_available(rep, inst["ctx"]) else "refund"
		"supplier_price_increase":
			return "accept"
		"unexpected_large_order":
			return "review"
		"ad_cost_spike":
			return "keep"
		"viral_mention":
			return "ride"
		"low_cash_warning":
			return "reduce"
	return DataDB.events[inst["id"]]["choices"][0]["id"]


func wait_world(timeout := 12.0) -> bool:
	var ok: bool = await bot.until(func(): return SceneRouter.world_scene() != null and SceneRouter.world_scene().player != null and not SceneRouter.transitioning, timeout)
	await bot.wait(0.4)
	return ok


func in_scene(kind: String, id: String) -> bool:
	var s := SceneRouter.world_scene()
	return s != null and s.kind == kind and s.scene_id == id


func dialogue() -> void:
	await bot.until(func(): return UIRoot.dialogue.active, 3.0)
	await bot.talk_through_dialogue()
	await bot.wait(0.3)


func close_modal() -> void:
	var m = UIRoot.top_modal()
	if m != null:
		var b: Button = m.find_child("Close", true, false)
		if b != null:
			await bot.click(b)
		else:
			await bot.key_action("pause")
	await bot.wait(0.3)


func enter_building(bid: String) -> bool:
	var s := SceneRouter.world_scene()
	if s == null or s.kind != "district":
		bot.fail("enter_building: not in a district")
		return false
	var sp: Vector2 = s.spawns.get("door_" + bid, Vector2.ZERO)
	await bot.walk_to(sp)
	await bot.walk_to(Vector2(sp.x, 319), 4.0, 6.0, false)
	var ok: bool = await bot.until(func(): return in_scene("interior", bid), 4.0)
	await wait_world()
	return bot.expect(ok, "entered " + DataDB.building(bid)["name"])


func exit_building() -> bool:
	var s := SceneRouter.world_scene()
	if s == null or s.kind != "interior":
		return false
	var d: Vector2 = s.spawns["door"]
	var sid := s.get_instance_id()
	var exit_y: float = s.size_px.y + 10
	await bot.walk_to(d)
	await bot.walk_to(Vector2(d.x, exit_y), 4.0, 5.0, false)
	var ok: bool = await bot.until(func(): return SceneRouter.world_scene() != null and SceneRouter.world_scene().get_instance_id() != sid and SceneRouter.world_scene().kind == "district", 4.0)
	await wait_world()
	return bot.expect(ok, "walked back outside")


func walk_exit(to_district: String) -> bool:
	var s := SceneRouter.world_scene()
	for ex in s.def.get("exits", []):
		if ex["to"] == to_district:
			var r: Array = ex["rect"]
			var target := Vector2(float(r[0]) + float(r[2]) / 2.0, 430)
			await bot.walk_to(target, 6.0, 60.0)
			break
	var ok: bool = await bot.until(func(): return in_scene("district", to_district), 5.0)
	await wait_world()
	return bot.expect(ok, "walked to " + DataDB.districts[to_district]["name"])


func metro_to(to: String) -> bool:
	await bot.use_action("metro")
	await bot.wait(0.8)
	await bot.shot("metro_" + to)
	await bot.click_named("Go_" + to)
	var ok: bool = await bot.until(func(): return in_scene("district", to), 6.0)
	await wait_world()
	return bot.expect(ok, "took the Metro to " + DataDB.districts[to]["name"])


func once_shot(name: String) -> void:
	if not shots_taken.has(name):
		shots_taken[name] = true
		await bot.shot(name)


## Nap/sleep in the apartment until pred() or max_naps.
func pass_time_at_home(pred: Callable, max_naps := 12, sleep_only := false) -> bool:
	for i in max_naps:
		await popups()
		if pred.call():
			return true
		await bot.use_action("sleep")
		await bot.wait(0.5)
		if not sleep_only and bot.button_named("Nap") != null and Clock.hour() < 19:
			await bot.click_named("Nap")
		else:
			await bot.click_named("Sleep")
		await bot.until(func(): return UIRoot.top_modal() == null or UIRoot.top_modal() is DecisionModal or UIRoot.top_modal() is MonthCloseModal, 8.0)
		await bot.wait(0.6)
		await _pack_and_ship_home()
	await popups()
	return pred.call()


func _pack_and_ship_home() -> void:
	if not in_scene("interior", "riverside_apartment"):
		return
	await popups()
	if Ecommerce.orders_with(["placed"], "riverside_studio").is_empty():
		return
	await bot.use_action("pack_orders")
	await bot.wait(0.6)
	await once_shot("packing_table")
	await bot.click_named("Pack", 3.0)
	await bot.wait(0.8)
	await bot.click_named("CourierExpress", 3.0)
	await bot.wait(0.6)
	await close_modal()


func open_os_at(action_pred: Callable, what: String) -> void:
	await bot.use(action_pred, what)
	await bot.until(func(): return UIRoot.top_modal() is CompanyOS, 3.0)
	await bot.wait(0.5)


# ------------------------------------------------------------------ flow
func _new_game() -> void:
	bot.step("Main menu → New Game")
	await bot.wait(1.5)
	await bot.shot("main_menu")
	await bot.click_named("NewGame")
	await bot.until(func(): return SceneRouter.current is CharacterCreator, 5.0)
	await bot.wait(1.0)
	bot.step("Character Creator")
	await bot.shot("creator_default")
	var cc: CharacterCreator = SceneRouter.current
	await bot.click_named("Tab_hair")
	await bot.click_named("Next_hair")
	await bot.wait(0.3)
	await bot.click_named("Tab_face")
	await bot.click_named("Next_face")
	await bot.click_named("Next_eye_shape")
	await bot.click_named("Tab_body")
	await bot.click_named("Next_presentation")
	await bot.wait(0.4)
	await bot.shot("creator_customised")
	await bot.click_named("Tab_outfit")
	await bot.click_text("Startup Casual")
	await bot.wait(0.3)
	await bot.type_into(cc.name_edit, "Alex Chen")
	bot.expect(cc.app["hair"] != GameState.default_appearance()["hair"], "appearance changed from default (%s)" % cc.app["hair"])
	await bot.shot("creator_final")
	await bot.click_named("Start")
	bot.step("Arrival sequence")
	await bot.until(func(): return SceneRouter.current is ArrivalScene, 5.0)
	await bot.wait(2.2)
	await bot.shot("arrival_train")
	await bot.wait(3.6)
	await bot.shot("arrival_phone")
	await wait_world(20.0)
	bot.expect(in_scene("interior", "riverside_apartment"), "spawned in the Riverside apartment")
	bot.expect(absf(Ledger.cash("player") - 30000.0) < 0.01, "starting cash $30,000")
	bot.expect(GameState.data["player"]["name"] == "Alex Chen", "name saved")
	await bot.wait(1.5)
	await bot.shot("apartment_arrival")


func _chapter1() -> void:
	bot.step("Chapter 1 — phone & Maya")
	await bot.wait(2.5)
	await bot.key_action("phone")
	await bot.wait(0.6)
	await bot.shot("phone_home")
	await bot.click_named("App_messages")
	await bot.wait(0.4)
	await bot.click_named("Thread_maya")
	await dialogue()
	bot.expect(GameState.flag("maya_intro_done"), "Maya conversation done")
	bot.step("Head outside")
	await exit_building()
	bot.expect(GameState.visited("riverside"), "visited Riverside")
	await bot.shot("riverside_outside_home")
	bot.step("Bloom Coffee")
	await enter_building("bloom_coffee")
	await bot.shot("bloom_coffee_inside")
	await bot.use(func(n): return n.action == "buy_item", "coffee counter")
	await dialogue()
	await bot.wait(0.5)
	bot.expect(GameState.flag("bought_coffee_bloom_coffee"), "bought a coffee from Jun")
	await exit_building()
	bot.step("Walk east to Startup Hub")
	var s := SceneRouter.world_scene()
	await bot.walk_to(Vector2(620, 350))
	await bot.shot("riverside_street")
	await walk_exit("startup_hub")
	await bot.shot("startup_hub_arrive")
	bot.step("Nexus Co-work")
	await enter_building("nexus_cowork")
	await bot.shot("cowork_inside")
	await bot.use_action("cowork_desk", "reception")
	await bot.wait(0.6)
	if UIRoot.dialogue.active:
		await dialogue()
		await bot.wait(0.5)
	await bot.click_named("DayPass", 4.0)
	await bot.wait(0.4)
	await close_modal()
	bot.step("Business Board")
	await bot.use_action("business_board")
	await bot.wait(0.6)
	await bot.shot("business_board")
	await bot.click_named("Biz_saas")
	await bot.wait(0.4)
	await bot.shot("business_board_planned_saas")
	await bot.click_named("Biz_ecommerce")
	await bot.click_named("StartEcommerce")
	await bot.wait(0.8)
	await close_modal()
	bot.expect(GameState.flag("business_chosen"), "picked ecommerce as first business")
	await bot.wait(2.5)
	bot.expect("ch1_arrival" in GameState.data["story"]["chapters_done"], "Chapter 1 complete")
	var _u := s


func _chapter2() -> void:
	bot.step("Chapter 2 — buy stock at a hot desk (Company OS)")
	await open_os_at(func(n): return n.action == "open_company_os", "hot desk")
	await bot.shot("company_os_overview_personal")
	await bot.click_named("Tab_operations")
	await bot.wait(0.5)
	await bot.shot("company_os_suppliers")
	for pid in ["wireless_earbuds", "water_bottle", "desk_lamp", "phone_stand"]:
		await bot.click_named("Buy_tradelink_wholesale_" + pid)
		await bot.wait(0.3)
	bot.expect(int(GameState.stat("purchase_orders")) >= 4, "placed purchase orders (MOQ, prepaid): %d POs, cash %s" % [int(GameState.stat("purchase_orders")), Fmt.money(Ledger.cash("player"))])
	await bot.shot("company_os_purchase_orders")
	await close_modal()
	bot.step("Home to wait for stock")
	await exit_building()
	await walk_exit("riverside")
	await enter_building("riverside_apartment")
	var arrived: bool = await pass_time_at_home(func(): return GameState.stat("stock_received") >= GameState.stat("purchase_orders"), 18)
	bot.expect(arrived, "stock delivered to the apartment")
	await bot.wait(0.6)
	await bot.shot("apartment_with_stock")
	bot.step("List products on ShopLane")
	await open_os_at(func(n): return n.action == "open_company_os", "laptop")
	await bot.click_named("Tab_sales")
	await bot.wait(0.5)
	await bot.shot("company_os_sales_ready")
	for pid in ["wireless_earbuds", "water_bottle", "desk_lamp", "phone_stand"]:
		if Ecommerce.total_units_at_any(pid) > 0 and Ecommerce.listing_for(pid).is_empty():
			await bot.click_named("ListSelf_" + pid)
			await bot.wait(0.4)
	await bot.click_named("AdPlus_wireless_earbuds", 2.0)
	await bot.wait(0.4)
	await bot.shot("company_os_listings_live")
	bot.expect(GameState.stat("listings_active") >= 1, "listings live")
	await close_modal()
	bot.step("First order → pack → ship")
	var got: bool = await pass_time_at_home(func(): return GameState.stat("orders_shipped") >= 1 or GameState.stat("orders_placed") >= 1 and not Ecommerce.orders_with(["placed"]).is_empty(), 10)
	await _pack_and_ship_home()
	bot.expect(got or GameState.stat("orders_placed") >= 1, "first order came in")
	bot.expect(GameState.stat("orders_shipped") >= 1 or not Ecommerce.orders_with(["awaiting_pickup"]).is_empty(), "handed to the courier (pickup booked)")
	bot.step("Delivery → first dollar")
	var delivered: bool = await pass_time_at_home(func(): return GameState.stat("orders_delivered") >= 1, 12)
	bot.expect(delivered, "first order delivered (Earn Your First Dollar)")
	var rev := -Ledger.balance("player", "revenue")
	bot.log_line("  revenue booked %s · ShopLane balance %s · cash %s" % [Fmt.money(rev), Fmt.money(Ledger.balance("player", "marketplace_balance")), Fmt.money(Ledger.cash("player"))])
	await bot.shot("first_dollar")
	bot.step("First customer issue")
	var issue: bool = await pass_time_at_home(func(): return GameState.flag("first_issue_resolved"), 10)
	bot.expect(issue, "resolved the first customer issue")
	await bot.wait(2.0)
	bot.expect("ch2_first_customer" in GameState.data["story"]["chapters_done"], "Chapter 2 complete")


func _chapter3() -> void:
	bot.step("Chapter 3 — wait for a weekday morning")
	await pass_time_at_home(func(): return Clock.weekday() >= 1 and Clock.weekday() <= 5 and Clock.hour() >= 7 and Clock.hour() < 12, 8)
	await exit_building()
	bot.step("Metro to Civic Center → City Hall")
	await bot.walk_to(Vector2(1040, 624), 6.0, 40.0)
	await metro_to("civic_center")
	await bot.shot("civic_center")
	if Clock.hour() < 9:
		Input.action_press("fast_forward")
		await bot.until(func(): return Clock.hour() >= 9, 40.0)
		Input.action_release("fast_forward")
	await enter_building("city_hall")
	await bot.shot("city_hall_inside")
	await bot.use_action("register_company", "registration counter")
	await dialogue()
	await bot.until(func(): return UIRoot.top_modal() is RegistrationModal, 3.0)
	var rm = UIRoot.top_modal()
	if rm is RegistrationModal:
		await bot.type_into(rm.name_edit, "Riverlight Goods")
		await bot.shot("registration_form")
		await bot.click_named("Submit")
		await bot.wait(0.8)
		await bot.shot("registration_done")
		await bot.click_text("Thanks")
	bot.expect(GameState.company_id() != "", "registered Riverlight Goods")
	await exit_building()
	bot.step("Walk to the Financial District → Nexus Bank")
	await walk_exit("financial")
	await enter_building("nexus_bank")
	await bot.shot("bank_inside")
	await bot.use_action("bank_counter", "teller")
	await bot.wait(0.6)
	await bot.click_text("$15,000")
	await bot.click_named("OpenAccount")
	await bot.wait(0.8)
	await bot.shot("bank_account_opened")
	await close_modal()
	bot.expect(GameState.flag("business_account_opened"), "business account opened with founder capital")
	await exit_building()
	bot.step("Metro to Startup Hub → lease Suite 2B")
	await bot.walk_to(Vector2(920, 624), 6.0, 40.0)
	await metro_to("startup_hub")
	await enter_building("small_office")
	await bot.shot("suite_2b_tour")
	var tom_here: bool = await bot.until(func(): return Actions.npc_present("tom"), 2.0)
	if tom_here:
		await bot.use(func(n): return n.action == "talk" and n.params.get("npc", "") == "tom", "Tom")
		await dialogue()
		await bot.until(func(): return UIRoot.top_modal() is LeaseModal, 3.0)
		await bot.click_named("SignLease", 3.0)
		await bot.wait(0.6)
		await close_modal()
	bot.expect(Living.has_lease("suite_2b"), "leased Suite 2B")
	await bot.wait(0.6)
	await bot.shot("suite_2b_company_sign")
	bot.step("Sit at the desk → Company OS as the company")
	await open_os_at(func(n): return n.action == "open_company_os", "office desk")
	await bot.wait(0.6)
	await bot.shot("company_os_as_company")
	await bot.click_named("Tab_finance")
	await bot.wait(0.5)
	await bot.shot("company_os_finance")
	await bot.click_named("Tab_inventory")
	await bot.wait(0.4)
	await bot.shot("company_os_inventory")
	await close_modal()
	await bot.wait(3.0)
	await popups()
	bot.expect("ch3_open_for_business" in GameState.data["story"]["chapters_done"], "Chapter 3 complete")
	await exit_building()
	await bot.shot("startup_hub_office_sign")


func _month() -> void:
	bot.step("Run the company to month-end")
	await walk_exit("riverside")
	await enter_building("riverside_apartment")
	var days := 0
	while Clock.date()["month"] == 6 and days < 30:
		days += 1
		await popups()
		# restock when low, via the laptop
		var low := Ecommerce.available_anywhere("water_bottle") < 25 or Ecommerce.available_anywhere("wireless_earbuds") < 10
		var offer_open: bool = GameState.data["contracts"].values().filter(func(c): return c["status"] == "offered").size() > 0
		var active: Array = GameState.data["contracts"].values().filter(func(c): return c["status"] == "active")
		if low or offer_open or not active.is_empty():
			await open_os_at(func(n): return n.action == "open_company_os", "laptop")
			var need_bottles := 0
			for c in active:
				need_bottles += int(c["qty"]) - Ecommerce.stock(c["location"], c["product"])
			if low or need_bottles > 0:
				await bot.click_named("Tab_operations")
				await bot.click_named("DeliverTo_riverside_studio", 1.0)
				for k in range(int(ceil(maxf(0, need_bottles) / 60.0))):
					await bot.click_named("Buy_tradelink_wholesale_water_bottle")
				if Ecommerce.available_anywhere("water_bottle") < 25:
					await bot.click_named("Buy_tradelink_wholesale_water_bottle")
				if Ecommerce.available_anywhere("wireless_earbuds") < 10:
					await bot.click_named("Buy_tradelink_wholesale_wireless_earbuds")
			if offer_open:
				await bot.click_named("Tab_contracts")
				await bot.wait(0.5)
				await once_shot("contract_offer")
				await bot.click_named("AcceptContract", 2.0)
				await bot.wait(0.5)
			if not active.is_empty():
				await bot.click_named("Tab_contracts")
				await bot.wait(0.4)
				if bot.button_named("DeliverContract") != null:
					await bot.click_named("DeliverContract")
					await bot.wait(0.5)
					await once_shot("contract_delivered")
			await close_modal()
		await pass_time_at_home(func(): return false, 1, true)
	await popups()
	await bot.wait(1.0)
	await popups()
	bot.expect(GameState.data["reports"]["month_closes"].size() >= 1, "month close ran (June)")
	await open_os_at(func(n): return n.action == "open_company_os", "laptop")
	await bot.click_named("Tab_finance")
	await bot.wait(0.5)
	await bot.shot("company_os_finance_july")
	await close_modal()


func _video_epilogue() -> void:
	bot.step("A working day at Suite 2B (video epilogue)")
	# stock in the office, a courier run, and a look at the numbers
	if bot.button_named("Close") != null:
		await close_modal()
	await bot.walk_to(Vector2(1000, 450), 6.0, 20.0)
	await bot.wait(1.5)
	await bot.shot("startup_hub_afternoon")
	await walk_exit("riverside")
	await enter_building("riverside_apartment")
	await pass_time_at_home(func(): return Clock.hour() >= 19 or Clock.hour() < 6, 4)
	await _pack_and_ship_home()
	await open_os_at(func(n): return n.action == "open_company_os", "laptop")
	await bot.click_named("Tab_finance")
	await bot.wait(2.5)
	await bot.click_named("Tab_sales")
	await bot.wait(2.5)
	await close_modal()
	await pass_time_at_home(func(): return false, 1, true)
	await bot.wait(1.0)


func _save_load() -> void:
	bot.step("Save → reload → same state")
	var cash := Ledger.cash(GameState.business_entity())
	var t := Clock.now()
	SaveSystem.save(1)
	var loc: Dictionary = GameState.data["player"]["location"].duplicate()
	SaveSystem.load_and_enter(1)
	await wait_world(10.0)
	bot.expect(absf(Ledger.cash(GameState.business_entity()) - cash) < 0.01, "cash restored after load")
	bot.expect(absf(Clock.now() - t) <= 2, "time restored after load")
	bot.expect(GameState.data["player"]["location"]["id"] == loc["id"], "location restored (%s)" % loc["id"])
	await bot.shot("after_load")
