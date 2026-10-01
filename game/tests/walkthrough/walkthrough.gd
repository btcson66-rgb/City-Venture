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
	if _arg("from") == "interaction_focus":
		await _interaction_focus_fixture()
		return
	if _arg("from") == "purchase_returns":
		await _purchase_return_fixture()
		return
	if _arg("from") == "contract_closure":
		await _contract_closure_fixture()
		return
	if _arg("from") == "harbor":
		# Isolated logistics fixture; no earlier sales income, so this is not an economy/endgame test.
		await _fast_forward_to_ch10()
		await _harbor_logistics()
		await _save_load()
		bot.expect(Ledger.check_balanced(), "ledger balanced after the harbor fixture")
		return
	if _arg("from") == "ch10":
		# quick rerun of the last chapters: --from=ch10 (the full walkthrough never does this)
		await _fast_forward_to_ch10()
		await _chapters_10_to_12()
		await _summary()
		return
	await _chapter1()
	await _chapter2()
	await _purchase_cancel()
	await _chapter3()
	if not bot.video_mode:
		await _careers()
	if bot.video_mode:
		await _video_epilogue()
	else:
		await _month()
		await _chapters_4_to_6()
		await _chapters_7_to_9()
		await _old_town_cafe()
		await _harbor_logistics()
		await _chapters_10_to_12()
	await _summary()


func _arg(name: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--%s=" % name):
			return a.substr(name.length() + 3)
	return ""


## Force a popup on the exact frame that a real interactable receives focus; reaching it stays successful.
func _interaction_focus_fixture() -> void:
	bot.step("Interaction focus interrupted by popup")
	UIRoot.tutorial.st()["off"] = true
	var it: Interactable = bot.find_interactable(func(n): return n.action == "open_company_os")
	var matched := [false]
	var reached := func():
		if bot.player() != null and bot.player().focus == it:
			matched[0] = true
			UIRoot.open_modal(Help.card("os_operations"))
			return true
		return false
	var ok: bool = await bot.walk_to(it.global_position + Vector2(0, 8), 3.0, 40.0, true, reached)
	bot.expect(ok and matched[0], "real interaction reach survives a same-frame popup")
	bot.expect(UIRoot.top_modal() is InfoModal, "popup really opened at interaction reach")
	await bot.click_text("Got it")
	await bot.wait(0.4)
	Clock.advance_to(Clock.at_day_time(0, 19 * 60))
	await bot.use_action("sleep")
	await bot.click_named("Sleep")
	await bot.until(func(): return not (UIRoot.top_modal() is SleepModal), 8.0)
	bot.expect(Clock.hour() == 7, "real sleep input works after popup closes")


func _summary() -> void:
	await _save_load()
	bot.step("Summary")
	var be := GameState.business_entity()
	bot.log_line("  business entity %s cash %s · personal %s · orders delivered %d · chapters done %s" % [
		be, Fmt.money(Ledger.cash(be)), Fmt.money(Ledger.cash("player")), int(GameState.stat("orders_delivered")),
		str(GameState.data["story"]["chapters_done"])])
	bot.expect(Ledger.check_balanced(), "ledger balanced at the end")
	if not bot.video_mode:
		for c in StoryEngine.chapters():
			for o in c.get("objectives", []):
				bot.expect(o["id"] in StoryEngine.St()["done"], "story objective completed: " + o["id"])


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
		elif m is InfoModal:
			bot.log_line("  info card: %s" % str(m.title_text))
			await bot.shot("info_" + str(m.title_text).to_lower().replace(" ", "_").left(24))
			await bot.click_text(str(m.ok_text), 2.0)
			await bot.wait(0.3)
			if is_instance_valid(m) and UIRoot.top_modal() == m:
				m.close()
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
		"crestline_big_offer":
			return "review"
		"elena_offer":
			return "accept"   # real equity funding also covers the café/van and later operating months
		"supply_shock_plan":
			return "local"     # the local co-op: the chapter's new supplier gets used
		"escrow_offer":
			return "try"       # Chapter 10: open the escrow account
		"rail_frozen":
			return "reroute"   # Chapter 11: pay again by wire while the bridge is frozen
		"acquisition_offer":
			return "counter"   # Chapter 12: ask for more, with an earn-out
		"shipment_lost":
			return "reship"
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


## Let time pass at home until pred() or `max_naps` rounds. The game has no naps or fast-forward: in the evening the bot
## sleeps in the bed; during the day the harness moves the clock 2 hours (a player would work a shift or wait).
## sleep_only: go straight to the night's sleep.
func pass_time_at_home(pred: Callable, max_naps := 12, sleep_only := false) -> bool:
	for i in max_naps:
		await popups()
		if pred.call():
			return true
		var evening := Clock.hour() >= 19 or Clock.hour() < 5
		if not evening and sleep_only:
			Clock.advance(19 * 60 - Clock.minute_of_day())
			evening = true
		if evening:
			await bot.use_action("sleep")
			await bot.wait(0.5)
			await bot.click_named("Sleep")
			var woke: bool = await bot.until(func(): return not (UIRoot.top_modal() is SleepModal), 8.0)
			for retry in 2:
				if woke:
					break
				bot.log_line("  sleep click did not close the modal; retry %d" % (retry + 1))
				await bot.click_named("Sleep")
				woke = await bot.until(func(): return not (UIRoot.top_modal() is SleepModal), 8.0)
			if not woke:
				bot.fail("sleep did not finish after three input attempts")
				await close_modal()
		else:
			bot.log_line("  (harness) wait 2 h")
			Clock.advance(120)
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
	await bot.until(func(): return not (UIRoot.top_modal() is MiniGame), 5.0)   # packed by hand (PackGame)
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


## Isolated legacy-save/closure evidence: real buttons close the fixture company and show its terminal contracts.
func _contract_closure_fixture() -> void:
	bot.step("Company closure contract fixture")
	UIRoot.tutorial.st()["off"] = true
	GameState.set_flag("business_chosen")
	Company.register("Riverlight Goods", "ecommerce", "22 Founders Lane")
	Company.open_business_account(10000)
	var ent := GameState.company_id()
	var po := Ecommerce.buy("tradelink_wholesale", "water_bottle", 60)
	Ecommerce.handle("eco.po_arrive", {"po": po["po_id"]})
	var offered := Contracts.create_offer({"buyer": "harbor_point_fitness", "product": "water_bottle", "qty": 10, "unit_price": 21.0, "tag": "big_contract"})
	var active := Contracts.create_offer({"buyer": "harbor_point_fitness", "product": "water_bottle", "qty": 10, "unit_price": 21.0})
	Contracts.accept(active)
	var delivered := Contracts.create_offer({"buyer": "harbor_point_fitness", "product": "water_bottle", "qty": 10, "unit_price": 21.0})
	Contracts.accept(delivered)
	Contracts.deliver(delivered)
	await _home_laptop("contracts")
	await bot.click_named("Contract_" + delivered)
	await bot.shot("live_invoice_before_closure")
	await close_modal()
	Insolvency.begin(ent, I18n.t("The company can't pay its debts"))
	await bot.until(func(): return UIRoot.top_modal() is InsolvencyModal, 5.0)
	await bot.click_named("CloseCompany")
	await bot.wait(0.5)
	await bot.shot("contract_closure_statement")
	await bot.click_named("StartOver")
	await bot.wait(2.0)
	Company.register("Riverlight Co", "ecommerce", "22 Founders Lane")
	Company.open_business_account(500)
	var new_po := Ecommerce.buy("tradelink_wholesale", "water_bottle", 60)
	Ecommerce.handle("eco.po_arrive", {"po": new_po["po_id"]})
	await _home_laptop("contracts")
	for cid in [offered, active, delivered]:
		await bot.click_named("Contract_" + cid)
		await bot.wait(0.4)
		var m = UIRoot.top_modal()
		var b := m.find_child("DeliverContract", true, false) as Button
		bot.expect(b != null and b.disabled, "closed seller's named delivery button disabled: " + cid)
		await bot.shot("closed_contract_" + str(Contracts.C()[cid]["status"]))
	bot.expect(Contracts.C()[offered]["status"] == "withdrawn" and GameState.flag("big_contract_decided"), "offered closure settles story decision")
	bot.expect(Contracts.C()[active]["status"] == "terminated" and not Contracts.can_deliver(active), "new company cannot deliver old contract")
	var cash := Ledger.cash(ent)
	Contracts.handle("con.pay", {"id": delivered})
	bot.expect(absf(Ledger.cash(ent) - cash) < 0.01 and Ledger.balance(ent, "accounts_receivable") >= 0, "closed company's AR cannot be paid twice")
	bot.expect(Ledger.check_balanced(), "closure fixture ledger balanced")
	await close_modal()


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
			await bot.until(func(): return not (UIRoot.top_modal() is MiniGame), 5.0)   # the photo shoot
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


## Place an extra batch and cancel through the real Operations confirmation controls.
## Isolated delivered-stock fixture for return-screen evidence; the full run still starts from a new game.
func _purchase_return_fixture() -> void:
	bot.step("Supplier return UI fixture")
	UIRoot.tutorial.st()["off"] = true
	GameState.set_flag("business_chosen")
	var result := Ecommerce.buy("tradelink_wholesale", "wireless_earbuds", 50)
	bot.expect(result["ok"], "fixture purchase created")
	var id := str(result["po_id"])
	Ecommerce.handle("eco.po_arrive", {"po": id})
	await _home_laptop("operations")
	await _scroll_to_end()
	await bot.click_named("ReturnPO_" + id)
	await bot.wait(0.5)
	for i in 4:
		await bot.click_named("ReturnQtyPlus")
	var cash := Ledger.cash("player")
	var quote := Ecommerce.return_quote(id, 5)
	await bot.shot("purchase_return_confirmation")
	await bot.click_named("ConfirmReturn")
	await bot.wait(0.5)
	bot.expect(Ecommerce.stock("riverside_studio", "wireless_earbuds") == 45, "five units returned through confirmation")
	bot.expect(absf(Ledger.cash("player") - cash + float(quote["shipping"])) < 0.02, "only shipping cash leaves immediately")
	await _scroll_to_end()
	await bot.shot("purchase_return_pending")
	await close_modal()
	# Jump only this isolated fixture to the supplier receipt; normal walkthrough does not jump for returns.
	GameState.data["clock"]["minutes"] = int(quote["due"])
	Ecommerce.handle("eco.return_refund", {"po": id, "return": 0})
	await _home_laptop("operations")
	await _scroll_to_end()
	await bot.shot("purchase_return_received")
	bot.expect(Ledger.check_balanced(), "return fixture ledger balanced")
	await close_modal()


func _purchase_cancel() -> void:
	bot.step("Purchase cancellation")
	await _home_laptop("operations")
	await bot.click_named("Buy_tradelink_wholesale_wireless_earbuds")
	await bot.wait(0.4)
	var id := "PO-%d" % int(Ecommerce.E()["counters"]["po"])
	var cash := Ledger.cash(GameState.business_entity())
	var quote := Ecommerce.cancel_quote(id)
	await _scroll_to_end()
	await bot.click_named("CancelPO_" + id)
	await bot.wait(0.5)
	await bot.shot("purchase_cancel_confirmation")
	await bot.click_named("ConfirmReturn")
	await bot.wait(0.5)
	bot.expect(Ecommerce.E()["purchase_orders"][id]["status"] == "cancelled", "extra PO cancelled through UI")
	bot.expect(absf(Ledger.cash(GameState.business_entity()) - cash - float(quote["refund"])) < 0.02, "cancellation cash equals quoted refund")
	bot.expect(Ledger.check_balanced(), "ledger balanced after purchase cancellation")
	await _scroll_to_end()
	await bot.shot("purchase_cancelled_operations")
	await close_modal()


func _chapter3() -> void:
	bot.step("Chapter 3 — wait for a weekday morning")
	await pass_time_at_home(func(): return Clock.weekday() >= 1 and Clock.weekday() <= 5 and Clock.hour() >= 7 and Clock.hour() < 12, 8)
	await exit_building()
	bot.step("Metro to Civic Center → City Hall")
	await bot.walk_to(Vector2(1040, 624), 6.0, 40.0)
	await metro_to("civic_center")
	await bot.shot("civic_center")
	if Clock.hour() < 9:
		await ff_until(func(): return Clock.hour() >= 9)
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


func _careers() -> void:
	bot.step("Careers — part-time job at Nexus Co-work")
	await enter_building("nexus_cowork")
	await bot.use_action("business_board")
	await bot.wait(0.6)
	await bot.click_named("Page_jobs")
	await bot.wait(0.5)
	await bot.shot("business_board_jobs")
	await bot.click_named("Job_cowork_host")
	await bot.wait(0.5)
	await bot.click_named("ApplyJob")
	await bot.wait(0.4)
	await bot.shot("job_hired")
	await close_modal()
	await bot.wait(0.3)
	await close_modal()
	bot.expect(Careers.current_job() == "cowork_host", "hired as a community host")
	var cash := Ledger.cash("player")
	var why := Careers.shift_block("cowork_host")
	var hrs := Careers.shift_hours_now("cowork_host")
	if why == "":
		await bot.use_action("work_shift")
		await bot.wait(0.6)
		await bot.shot("job_shift")
		await bot.click_named("WorkShift")
		await bot.until(func(): return not (UIRoot.top_modal() is MiniGame), 5.0)   # the shift is played
		await bot.wait(1.8)
		var paid := Ledger.cash("player") - cash
		bot.expect(paid >= Careers.pay_for("cowork_host", MiniGames.auto, hrs) - 0.01, "a %d-hour shift paid by how it went (%s)" % [hrs, Fmt.money(paid)])
	else:
		bot.log_line("  (no shift now: %s)" % why)
	bot.step("Careers — freelance gig at a hot desk")
	await open_os_at(func(n): return n.action == "open_company_os", "hot desk")
	await bot.click_named("Tab_freelance")
	await bot.wait(0.4)
	await bot.click_named("StartFreelance")
	await bot.wait(0.5)
	var offers: Array = Careers.F()["offers"]
	if offers.is_empty():
		bot.fail("no freelance offers")
	else:
		var oid: String = offers[0]["id"]
		await bot.click_named("Accept_" + oid)
		await bot.wait(0.4)
		await bot.click_named("Work_" + oid)
		await bot.until(func(): return not (UIRoot.top_modal() is MiniGame), 5.0)   # typing the client's spreadsheet
		await bot.wait(0.6)
		await bot.shot("freelance_gig")
		bot.expect(int(Careers.F()["gigs"][oid]["done"]) >= 2, "put hours into a freelance gig")
	bot.step("Careers — start a SaaS product")
	await bot.click_named("Tab_saas")
	await bot.wait(0.4)
	await bot.shot("saas_ideas")
	await bot.click_named("Saas_freelancer_invoicing")
	await bot.wait(0.4)
	await bot.click_named("SaasCode")
	await bot.until(func(): return not (UIRoot.top_modal() is MiniGame), 5.0)   # typing the code
	await bot.wait(0.5)
	await bot.shot("saas_building")
	bot.expect(Saas.active() and float(Saas.S()["dev_done"]) >= 2.0, "started building a SaaS product (%d dev h)" % int(Saas.S()["dev_done"]))
	await close_modal()
	await exit_building()


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


## Test harness: move the clock 5 minutes at a time until pred() (the game has no fast-forward; a player would wait,
## walk around or work in the meantime).
func ff_until(pred: Callable, _timeout := 60.0) -> bool:
	var guard := 0
	while not pred.call() and guard < 24 * 60:
		Clock.advance(5)
		guard += 5
	await bot.wait(0.3)
	return pred.call()


func _home_laptop(tab: String) -> void:
	await open_os_at(func(n): return n.action == "open_company_os", "laptop")
	await bot.click_named("Tab_" + tab)
	await bot.wait(0.5)


func _is_weekday() -> bool:
	return Clock.weekday() >= 1 and Clock.weekday() <= 5


func _chapters_4_to_6() -> void:
	await popups()
	bot.expect(StoryEngine.St()["chapter"] == "ch4_growing_pains", "Chapter 4 started after the June close")
	# ---------------------------------------------------------------- chapter 4
	bot.step("Chapter 4 — register as an employer at City Hall")
	if not _is_weekday() or Clock.hour() >= 15:
		await pass_time_at_home(func(): return _is_weekday() and Clock.hour() < 12, 4, true)
	await exit_building()
	await metro_to("civic_center")
	if Clock.minute_of_day() < 9 * 60 + 5:
		await ff_until(func(): return Clock.minute_of_day() >= 9 * 60 + 5, 30.0)
	await enter_building("city_hall")
	await bot.use_action("permits_info")
	await bot.wait(0.6)
	await bot.shot("permits_kiosk")
	await bot.click_named("RegisterEmployer")
	await bot.wait(0.5)
	await close_modal()
	bot.expect(Staff.employer_registered(), "registered as an employer")
	bot.step("Chapter 4 — post a job, hire, first payroll")
	await exit_building()
	await metro_to("riverside")
	await enter_building("riverside_apartment")
	await _home_laptop("people")
	await bot.shot("people_tab")
	await bot.click_named("Post_support")
	await bot.wait(0.4)
	await close_modal()
	bot.expect(GameState.stat("jobs_posted") >= 1.0, "job ad posted")
	await pass_time_at_home(func(): return not Staff.S()["applicants"].is_empty(), 6)
	await _home_laptop("people")
	await bot.shot("applicants")
	var apps: Array = Staff.S()["applicants"]
	if not apps.is_empty():
		await bot.click_named("Hire_" + str(apps[0]["id"]))
		await bot.wait(0.4)
	await close_modal()
	bot.expect(Staff.count() >= 1, "hired the first employee (%s)" % (Staff.people()[0]["name"] if Staff.count() > 0 else "—"))
	await pass_time_at_home(func(): return GameState.stat("payrolls_run") >= 1.0, 8, true)
	bot.expect(GameState.stat("payrolls_run") >= 1.0, "first payroll paid")
	await _home_laptop("finance")
	await bot.shot("cash_forecast")
	await close_modal()
	await bot.wait(1.0)
	await popups()
	bot.expect("ch4_growing_pains" in StoryEngine.St()["chapters_done"], "Chapter 4 complete")
	# ---------------------------------------------------------------- chapter 5
	bot.step("Chapter 5 — Crestline's offer")
	await pass_time_at_home(func(): return not Contracts.by_tag("big_contract").is_empty(), 9, true)
	var c := Contracts.by_tag("big_contract")
	bot.expect(not c.is_empty(), "Crestline offered the big contract")
	await _home_laptop("contracts")
	await bot.shot("big_contract_offer")
	await bot.click_named("AcceptContract", 3.0)
	await bot.wait(0.5)
	await close_modal()
	bot.expect(GameState.flag("big_contract_accepted"), "accepted Crestline's contract")
	bot.step("Chapter 5 — borrow from Marcus Reed at Nexus Bank")
	await pass_time_at_home(func(): return _is_weekday() and Clock.hour() < 12, 4, true)
	await exit_building()
	await metro_to("financial")
	if Clock.minute_of_day() < 13 * 60 + 5:
		await ff_until(func(): return Clock.minute_of_day() >= 13 * 60 + 5, 60.0)
	await enter_building("nexus_bank")
	await bot.use(func(n): return n.action == "talk" and str(n.params.get("npc", "")) == "marcus", "Marcus Reed")
	await dialogue()
	await bot.until(func(): return UIRoot.top_modal() is LoanModal, 3.0)
	await bot.wait(0.4)
	await bot.shot("loan_offer")
	await bot.click_named("Amt_50", 2.0)
	await bot.click_named("Term_12", 2.0)
	await bot.click_named("TakeLoan", 2.0)
	await bot.wait(0.5)
	await bot.shot("loan_taken")
	await close_modal()
	bot.expect(GameState.flag("loan_taken"), "took a Nexus Bank loan (debt %s)" % Fmt.money(Bank.debt(GameState.business_entity())))
	bot.step("Chapter 5 — order the lamps and deliver")
	await exit_building()
	await metro_to("riverside")
	await enter_building("riverside_apartment")
	await _home_laptop("contracts")
	await bot.click_named("FillContract", 3.0)
	await bot.wait(0.5)
	await bot.shot("contract_restock")
	await close_modal()
	await pass_time_at_home(func(): return Contracts.can_deliver(c["id"]), 12, true)
	await _home_laptop("contracts")
	await bot.click_named("DeliverContract", 3.0)
	await bot.wait(0.6)
	await bot.shot("big_contract_delivered")
	await close_modal()
	bot.expect(GameState.flag("big_contract_delivered"), "delivered 800 lamps to Crestline")
	await bot.wait(1.0)
	await popups()
	bot.expect("ch5_big_contract" in StoryEngine.St()["chapters_done"], "Chapter 5 complete")
	# ---------------------------------------------------------------- chapter 6
	bot.step("Chapter 6 — forecast, early payment, month in the black")
	await _home_laptop("finance")
	await bot.shot("cash_forecast_ch6")
	await bot.click_named("Tab_contracts")
	await bot.wait(0.4)
	await bot.click_named("EarlyPayment", 3.0)
	await bot.wait(0.5)
	await bot.shot("early_payment")
	await close_modal()
	bot.expect(GameState.flag("big_contract_paid"), "Crestline paid early (3% discount)")
	await pass_time_at_home(func(): return GameState.flag("ch6_month_in_black") or GameState.data["reports"]["month_closes"].size() >= 2, 20, true)
	await bot.wait(1.0)
	await popups()
	bot.expect("ch6_cash_is_oxygen" in StoryEngine.St()["chapters_done"], "Chapter 6 complete")
	bot.expect(Ledger.check_balanced(), "ledger balanced after chapters 4–6")


## Chapters 7–9: each opens with the news board at Bloom Coffee, then uses the chapter's new system for real.
func _read_news(tag: String) -> void:
	if SceneRouter.world_scene().kind == "interior":
		await exit_building()
	if SceneRouter.world_scene().scene_id != "riverside":
		await metro_to("riverside")
	await enter_building("bloom_coffee")
	await bot.use_action("read_news")
	await bot.wait(0.6)
	await bot.shot("news_" + tag)
	await close_modal()
	bot.expect(GameState.flag("news_read"), "read the news (%s)" % tag)
	await exit_building()
	await enter_building("riverside_apartment")


func _chapters_7_to_9() -> void:
	await popups()
	bot.expect(StoryEngine.St()["chapter"] == "ch7_supply_shock", "Chapter 7 started after Chapter 6")
	bot.expect(World.year() == 3, "Year 3: the Supply Shock")
	# ---------------------------------------------------------------- chapter 7
	bot.step("Chapter 7 — the news, and Ken's options")
	await _read_news("supply_shock")
	await pass_time_at_home(func(): return GameState.flag("ch7_supply_plan"), 6, true)   # Ken calls within two days
	bot.expect(World.supplier_available("aurelia_makers"), "the local co-op is a supplier now")
	bot.step("Chapter 7 — order from the co-op, raise a price")
	await _home_laptop("operations")
	await bot.shot("operations_supply_shock")
	# the co-op sells in lots of its MOQ (30): buy until the chapter's 100 units are in hand or on the way
	for i in 5:
		if Cond.eval("stock_units>=100"):
			break
		await bot.click_named("Buy_aurelia_makers_desk_lamp", 3.0)
		await bot.wait(0.4)
	StoryEngine.check()   # ch7_stock is done; an earlier price adjustment remains valid.
	await bot.click_named("Tab_sales")
	await bot.wait(0.4)
	await bot.click_named("PriceUp_desk_lamp", 3.0)
	await bot.wait(0.4)
	await close_modal()
	await bot.wait(0.6)
	StoryEngine.check()
	bot.expect("ch7_price" in StoryEngine.St()["done"], "stocked and repriced")
	await pass_time_at_home(func(): return "ch7_supply_shock" in StoryEngine.St()["chapters_done"], 75, true)   # a profitable month, or two month-ends
	bot.expect("ch7_supply_shock" in StoryEngine.St()["chapters_done"], "Chapter 7 complete")
	# ---------------------------------------------------------------- chapter 8
	bot.step("Chapter 8 — the Green Shift")
	bot.expect(World.year() == 4, "Year 4: the Green Shift")
	await _read_news("green_shift")
	await _home_laptop("operations")
	await bot.click_named("Packaging_recycled", 3.0)
	await bot.wait(0.3)
	await bot.click_named("Buy_verdant_supply_solar_lamp", 3.0)
	await bot.wait(0.3)
	await bot.shot("operations_green")
	await close_modal()
	bot.expect(GameState.flag("packaging_green"), "recycled packaging")
	# Sleep through days, as on the latest base; assert arrival before clicking the listing button.
	var solar_arrived := await pass_time_at_home(func(): return Ecommerce.total_units_at_any("solar_lamp") > 0, 8, true)
	bot.expect(solar_arrived, "solar desk lamps arrived before listing")
	await _home_laptop("sales")
	await bot.click_named("ListSelf_solar_lamp", 3.0)
	await bot.until(func(): return not (UIRoot.top_modal() is MiniGame), 8.0)   # the photo shoot
	await bot.wait(0.6)
	await close_modal()
	bot.expect(Cond.eval("listed:solar_lamp"), "solar desk lamps listed")
	bot.step("Chapter 8 — the Green Business Grant at City Hall")
	while not _is_weekday() or Clock.hour() < 9 or Clock.hour() >= 15:
		await pass_time_at_home(func(): return _is_weekday() and Clock.hour() >= 9 and Clock.hour() < 15, 1)
	await exit_building()
	await metro_to("civic_center")
	await enter_building("city_hall")
	await bot.use_action("permits_info")
	await bot.wait(0.6)
	await bot.shot("green_grant")
	await bot.click_named("ApplyGreenGrant", 3.0)
	await bot.wait(0.4)
	await close_modal()
	bot.expect(GameState.flag("green_grant"), "green grant approved")
	await bot.wait(1.0)
	await popups()
	bot.expect("ch8_green_shift" in StoryEngine.St()["chapters_done"], "Chapter 8 complete")
	# ---------------------------------------------------------------- chapter 9
	bot.step("Chapter 9 — the Clearing Crisis: an import stuck on the wire")
	bot.expect(World.year() == 5, "Year 5: the Clearing Crisis")
	await exit_building()
	await metro_to("riverside")
	await _read_news("clearing_crisis")
	await _home_laptop("operations")
	await bot.click_named("Buy_lumina_direct_phone_stand", 3.0)
	await bot.wait(0.6)
	await bot.shot("settlement_choice")
	await bot.click_named("Settle_international_wire", 3.0)
	await bot.wait(0.4)
	await close_modal()
	bot.expect(GameState.stat("import_orders") >= 1, "import ordered, paid by wire")
	bot.step("Chapter 9 — Lina Zhao at Nexus Bank")
	while not _is_weekday() or Clock.hour() < 10 or Clock.hour() >= 15:
		await pass_time_at_home(func(): return _is_weekday() and Clock.hour() >= 10 and Clock.hour() < 15, 1)
	await exit_building()
	await metro_to("financial")
	await enter_building("nexus_bank")
	await bot.use(func(n): return n.action == "talk" and str(n.params.get("npc", "")) == "lina", "Lina Zhao")
	await bot.wait(0.6)
	await bot.shot("lina_intro")
	await talk_through_dialogue_first_choice()
	bot.expect(GameState.flag("met_lina"), "met Lina Zhao")
	await exit_building()
	await metro_to("riverside")
	await enter_building("riverside_apartment")
	await _home_laptop("operations")
	var pend := ""
	for po in Ecommerce.E()["purchase_orders"].values():
		if po["status"] == "awaiting_payment":
			pend = str(po["id"])
	if pend != "":
		await bot.click_named("SpeedUp_" + pend, 3.0)
		await bot.wait(0.5)
		await bot.shot("settlement_speed_up")
		await bot.click_named("Settle_letter_of_credit", 3.0)
		await bot.wait(0.4)
	await close_modal()
	await close_modal()
	await pass_time_at_home(func(): return "ch9_clearing_crisis" in StoryEngine.St()["chapters_done"], 30, true)   # the import takes weeks
	bot.expect("ch9_clearing_crisis" in StoryEngine.St()["chapters_done"], "Chapter 9 complete: the import got through")
	bot.expect(Ledger.check_balanced(), "ledger balanced after chapters 7–9")


## Old Town: lease the corner unit from Mr. Okafor, fit it out, get the food licence at City Hall, and work your own
## counter on opening day.
func _old_town_cafe() -> void:
	bot.step("Old Town — lease the corner café from Mr. Okafor")
	while not _is_weekday() or Clock.hour() < 9 or Clock.hour() >= 14:
		await pass_time_at_home(func(): return _is_weekday() and Clock.hour() >= 9 and Clock.hour() < 14, 1)
	await exit_building()
	await metro_to("old_town")
	await bot.shot("old_town")
	await enter_building("okafor_lettings")
	await bot.use(func(n): return n.action == "talk" and str(n.params.get("npc", "")) == "okafor", "Mr. Okafor")
	await dialogue()
	await bot.wait(0.5)
	await bot.shot("cafe_lease")
	await bot.click_named("SignLease_corner_cafe", 3.0)
	await bot.wait(0.4)
	await close_modal()
	bot.expect(Cafe.leased(), "leased the corner café unit")
	await exit_building()
	await bot.shot("old_town_storefronts")
	await enter_building("corner_cafe_unit")
	await open_os_at(func(n): return n.action == "open_company_os", "the café till")
	await bot.click_named("CafeFitOut", 3.0)
	await bot.wait(0.3)
	await bot.click_named("CafeSupplies_large", 3.0)
	await bot.wait(0.3)
	await bot.shot("cafe_setup")
	await close_modal()
	bot.expect(Cafe.fitting() or Cafe.fitted(), "fit-out under way")
	bot.expect(int(Cafe.S()["incoming"]) > 0, "coffee supplies ordered")
	bot.step("Old Town — the food licence at City Hall (walking via Shopping Street)")
	await exit_building()
	await walk_exit("shopping_street")
	await walk_exit("civic_center")
	await enter_building("city_hall")
	await bot.use_action("permits_info")
	await bot.wait(0.5)
	await bot.click_named("ApplyFoodLicence", 3.0)
	await bot.wait(0.4)
	await bot.shot("food_licence")
	await close_modal()
	bot.expect(Cafe.permit_pending() or Cafe.permitted(), "food licence applied for")
	await exit_building()
	await metro_to("riverside")
	await enter_building("riverside_apartment")
	# the licence takes two days from the application (48 h): sleep through them, then wait for an opening morning
	await pass_time_at_home(func(): return Cafe.ready_to_open() and Cafe.open_day() and Clock.hour() >= 7 and Clock.hour() < 15, 30)
	bot.expect(Cafe.ready_to_open(), "fitted out and licensed")
	bot.step("Old Town — opening day behind your own counter")
	await exit_building()
	await metro_to("old_town")
	await enter_building("corner_cafe_unit")
	await bot.shot("cafe_open")
	await bot.use_action("cafe_counter")
	await bot.until(func(): return not (UIRoot.top_modal() is MiniGame), 10.0)
	await bot.wait(0.8)
	await popups()
	bot.expect(int(Cafe.S()["today"].get("served", 0)) > 0, "served customers at your own café")
	await open_os_at(func(n): return n.action == "open_company_os", "the café till")
	await bot.shot("cafe_tab")
	await close_modal()
	bot.expect(Ledger.check_balanced(), "ledger balanced after opening the café")
	await exit_building()
	await metro_to("riverside")
	await enter_building("riverside_apartment")


## Harbor: the metro to Pier 7, a used van from Sam at Dockside Motors, a lease on the warehouse bay, then the next
## morning's delivery run driven for real in the route minigame, and the pay banked.
func _harbor_logistics() -> void:
	bot.step("Harbor — metro to the docks, a used van from Sam, and Pier 7")
	var be := GameState.business_entity()
	# Do not fabricate capital. The full route accepts the existing investor offer through real input.
	bot.expect(Ledger.cash(be) >= 16000.0, "actual financing covers the van, bay and working capital")
	while not _is_weekday() or Clock.hour() < 9 or Clock.hour() >= 14:
		await pass_time_at_home(func(): return _is_weekday() and Clock.hour() >= 9 and Clock.hour() < 14, 1)
	await exit_building()
	await metro_to("harbor")
	await bot.shot("harbor")
	await bot.walk_to(Vector2(640, 352), 6.0, 60.0)
	await bot.wait(0.6)
	await bot.shot("harbor_street")
	await enter_building("dockside_motors")
	await bot.use(func(n): return n.action == "talk" and str(n.params.get("npc", "")) == "sam", "Sam Okoro")
	await dialogue()
	await bot.until(func(): return UIRoot.top_modal() is VanDealModal, 4.0)
	await bot.wait(0.5)
	await bot.shot("van_dealer")
	await bot.click_named("BuyVan", 3.0)
	await bot.wait(0.5)
	await bot.shot("van_bought")
	await close_modal()
	bot.expect(Logistics.has_van(), "bought the van from Sam")
	bot.expect(Ledger.balance(be, "exp:vehicle") >= 9800.0, "the van is a vehicle expense")
	await exit_building()
	await enter_building("pier7_warehouse")
	await bot.wait(0.5)
	await bot.use_action("lease_property", "the lettings desk")
	await bot.wait(0.5)
	await bot.shot("pier7_lease")
	await bot.click_named("SignLease_pier7_warehouse", 3.0)
	await bot.wait(0.4)
	await close_modal()
	bot.expect(Living.has_lease("pier7_warehouse"), "leased the Pier 7 bay")
	bot.expect("pier7_warehouse" in Ecommerce.stock_locations(), "Pier 7 is a stock location")
	await bot.wait(0.4)
	await bot.shot("pier7_warehouse")
	await exit_building()
	await metro_to("riverside")
	await enter_building("riverside_apartment")
	bot.step("Harbor — the morning's delivery runs")
	await pass_time_at_home(func(): return not Logistics.open_jobs().is_empty() and Clock.hour() >= 8 and Clock.hour() < 15, 14)
	bot.expect(not Logistics.open_jobs().is_empty(), "runs were posted in the morning")
	await exit_building()
	await metro_to("harbor")
	await enter_building("pier7_warehouse")
	await open_os_at(func(n): return n.action == "open_company_os", "the yard office desk")
	await bot.click_named("Tab_logistics", 3.0)
	await bot.wait(0.6)
	await bot.shot("logistics_tab")
	# a "!" badge, pinned by a click
	var tip: Control = null
	for n in bot.get_tree().root.find_children("*", "InfoTip", true, false):
		if (n as Control).is_visible_in_tree():
			tip = n
			break
	if tip != null:
		await bot.click_control(tip)
		await bot.wait(0.5)
		await bot.shot("logistics_badge_pinned")
		await bot.click_named("Tab_logistics", 3.0)   # a click elsewhere puts the card away
		await bot.wait(0.3)
	var open := Logistics.open_jobs()
	if not bot.expect(not open.is_empty(), "delivery runs on the board"):
		await close_modal()
		return
	var jid := str(open[open.size() - 1]["id"])   # the latest deadline: no rush
	await bot.click_named("Accept_" + jid, 3.0)
	await bot.wait(0.4)
	bot.expect(str(Logistics.job(jid).get("status", "")) == "active", "accepted run %s" % jid)
	await bot.shot("logistics_accepted")
	var rev0 := -Ledger.balance(be, "revenue")
	var fuel0 := Ledger.balance(be, "exp:fuel")
	var auto_q := MiniGames.auto
	MiniGames.auto = -1.0   # play this one by hand
	await bot.click_named("Drive_" + jid, 3.0)
	await bot.until(func(): return UIRoot.top_modal() is RouteGame, 4.0)
	await bot.wait(0.5)
	await bot.shot("route_game_intro")
	await bot.click_named("StartGame", 3.0)
	await bot.wait(0.4)
	var g := UIRoot.top_modal() as RouteGame
	if g == null:
		bot.fail("the route game is not open")
	else:
		var best := Logistics.best_order(g.stops)
		for k in (best["order"] as Array).size():
			await bot.click_named("Stop_%d" % (int(best["order"][k]) + 1), 3.0)
			if k == 1:
				await bot.shot("route_game_planning")
		await bot.wait(0.3)
		await bot.shot("route_game_planned")
		await bot.click_named("DriveRoute", 3.0)
		await bot.wait(0.5)
		await bot.shot("route_game_results")
		await bot.click_named("FinishGame", 3.0)
	MiniGames.auto = auto_q
	await bot.wait(0.8)
	await popups()
	bot.expect(Logistics.job(jid).is_empty() and Logistics.history(1)[0]["id"] == jid, "the run is done and in the history")
	var paid := -Ledger.balance(be, "revenue") - rev0
	bot.expect(paid > 60.0, "the pay was banked as revenue (%s for run %s)" % [Fmt.money(paid), jid])
	bot.expect(Ledger.balance(be, "exp:fuel") > fuel0, "fuel was charged")
	bot.expect(float(Logistics.history(1)[0]["score"]) > 0.99, "the best route scored 100%")
	if UIRoot.top_modal() is CompanyOS:
		await bot.wait(0.4)
		await bot.shot("logistics_tab_paid")
		await close_modal()
	bot.expect(Ledger.check_balanced(), "ledger balanced after the first delivery run")
	await exit_building()
	await metro_to("riverside")
	await enter_building("riverside_apartment")


## Chapters 10–12: the digital rails (Year 6), the bridge exploit (Year 7), the regulation wave and Victor Hale's offer
## (Year 8). Each opens with the news board, then uses the chapter's new system for real.
func _until_weekday_hours(h0: int, h1: int) -> void:
	while not _is_weekday() or Clock.hour() < h0 or Clock.hour() >= h1:
		await pass_time_at_home(func(): return _is_weekday() and Clock.hour() >= h0 and Clock.hour() < h1, 1)


## Click the first "!" badge on the top screen: the card stays pinned for the screenshot, then closes.
func _pin_badge_shot(shot_name: String) -> void:
	var m = UIRoot.top_modal()
	if m == null:
		return
	var tips: Array = m.find_children("*", "InfoTip", true, false)
	if tips.is_empty():
		bot.fail("no '!' badge on this screen (%s)" % shot_name)
		return
	var tip: InfoTip = tips[0]
	await bot.click(tip)
	await bot.wait(0.5)
	bot.expect(is_instance_valid(tip._pinned) and tip._pinned.visible, "the '!' badge for %s pins its card" % tip.tip_id)
	await bot.shot(shot_name)
	if is_instance_valid(tip._pinned):
		tip._pinned.hide()
	await bot.wait(0.2)


## Scroll the top screen's content to the bottom (the purchase orders sit below the suppliers).
func _scroll_to_end() -> void:
	var m = UIRoot.top_modal()
	if m == null:
		return
	for sc in m.find_children("*", "ScrollContainer", true, false):
		var s := sc as ScrollContainer
		s.scroll_vertical = 100000
	await bot.wait(0.4)


func _buy_import(product: String, method: String, shot_name := "") -> void:
	await _home_laptop("operations")
	var qty := int(Ecommerce.offer("lumina_direct", product)["moq"])
	if Ecommerce.space_block(Ecommerce.default_stock_location(), qty) != "":
		# the stockroom is full: send it where there's room, as a player would
		for l in Ecommerce.stock_locations():
			if Ecommerce.space_block(l, qty) == "":
				await bot.click_named("DeliverTo_" + l, 3.0)
				await bot.wait(0.4)
				break
	await bot.click_named("Buy_lumina_direct_" + product, 3.0)
	await bot.wait(0.6)
	if shot_name != "":
		await bot.shot(shot_name)
	await bot.click_named("Settle_" + method, 3.0)
	await bot.wait(0.5)


func _chapters_10_to_12() -> void:
	await popups()
	bot.expect(StoryEngine.St()["chapter"] == "ch10_digital_rails", "Chapter 10 started after Chapter 9")
	bot.expect(World.year() == 6, "Year 6: the Digital Finance Boom")
	# ---------------------------------------------------------------- chapter 10
	bot.step("Chapter 10 — the news, and Lina's escrow offer")
	await _read_news("digital_rails")
	await _until_weekday_hours(10, 15)
	await exit_building()
	await metro_to("financial")
	await enter_building("nexus_bank")
	await bot.use(func(n): return n.action == "talk" and str(n.params.get("npc", "")) == "lina", "Lina Zhao")
	await bot.wait(0.6)
	await bot.shot("lina_rails")
	await talk_through_dialogue_first_choice()
	await bot.until(func(): return UIRoot.top_modal() is DecisionModal, 12.0)
	await bot.wait(0.8)
	await _pin_badge_shot("badge_escrow_pinned")
	await popups()   # answers the escrow offer: open the account
	bot.expect(GameState.flag("escrow_open"), "opened an escrow account")
	bot.step("Chapter 10 — an import paid through escrow")
	await exit_building()
	await metro_to("riverside")
	await enter_building("riverside_apartment")
	await _buy_import("phone_stand", "escrow", "settlement_escrow")
	Clock.advance(130)   # (harness) the contract locks within two hours: the order shows as held in escrow
	await bot.click_named("Tab_finance")
	await bot.click_named("Tab_operations")
	await _scroll_to_end()
	await bot.wait(4.5)   # let the toast fade
	await bot.shot("operations_escrow_order")
	await close_modal()
	bot.expect(int(GameState.stat("escrow_orders")) >= 1, "import ordered through escrow")
	await _home_laptop("finance")
	await bot.shot("finance_held_in_escrow")
	await close_modal()
	await pass_time_at_home(func(): return "ch10_digital_rails" in StoryEngine.St()["chapters_done"], 30, true)   # a 12-day import
	await popups()
	bot.expect(int(GameState.stat("escrow_released")) >= 1, "escrow released to the supplier on arrival")
	bot.expect("ch10_digital_rails" in StoryEngine.St()["chapters_done"], "Chapter 10 complete")
	# ---------------------------------------------------------------- chapter 11
	bot.step("Chapter 11 — the bridge exploit")
	bot.expect(World.year() == 7, "Year 7: the Bridge Exploit")
	await _read_news("bridge_before")
	await _buy_import("phone_stand", "escrow", "settlement_before_exploit")
	await close_modal()
	bot.expect(int(GameState.stat("import_orders_y7")) >= 1, "restock ordered through escrow (cash %s)" % Fmt.money0(Ledger.cash(GameState.business_entity())))
	await bot.until(func(): return not EventEngine.pending().is_empty(), 40.0)   # the bridge is hit within the hour
	await bot.until(func(): return UIRoot.top_modal() is DecisionModal, 20.0)
	await bot.wait(0.6)
	bot.expect(Rails.frozen(), "the bridge is frozen with our payment crossing it")
	await _pin_badge_shot("badge_frozen_pinned")
	await popups()   # answers rail_frozen: pay again by wire
	bot.expect(Rails.X().get("decision", "") == "reroute", "paid again by wire")
	await _home_laptop("finance")
	await bot.shot("finance_frozen_funds")
	await bot.click_named("Tab_operations")
	await bot.wait(0.4)
	await _scroll_to_end()
	await bot.wait(4.5)
	await bot.shot("operations_frozen_order")
	await close_modal()
	await _read_news("bridge_frozen")
	await pass_time_at_home(func(): return "ch11_other_side_of_trust" in StoryEngine.St()["chapters_done"], 40, true)
	await popups()
	bot.expect(Rails.state() == "recovered", "the bridge reopened")
	bot.expect(absf(Ledger.balance(GameState.business_entity(), "frozen_funds")) < 0.01, "frozen funds settled")
	bot.expect("ch11_other_side_of_trust" in StoryEngine.St()["chapters_done"], "Chapter 11 complete: through the freeze and restocked")
	# ---------------------------------------------------------------- chapter 12
	bot.step("Chapter 12 — the regulation wave: the import licence")
	bot.expect(World.year() == 8, "Year 8: the Regulation Wave")
	await _read_news("regulation")
	await _until_weekday_hours(9, 15)
	await exit_building()
	await metro_to("civic_center")
	await enter_building("city_hall")
	await bot.use_action("permits_info")
	await bot.wait(0.6)
	await bot.shot("permits_import_licence")
	await _pin_badge_shot("badge_licence_pinned")
	await bot.click_named("ApplyImportLicence", 3.0)
	await bot.wait(0.5)
	await bot.shot("permits_licence_processing")
	await close_modal()
	bot.expect(Compliance.licence_pending() or Compliance.licence_valid(), "import licence applied for")
	await exit_building()
	await metro_to("riverside")
	await enter_building("riverside_apartment")
	await pass_time_at_home(func(): return Compliance.licence_valid(), 6, true)
	await popups()
	bot.expect(GameState.flag("import_licence"), "import licence granted")
	bot.step("Chapter 12 — a large import goes through KYC")
	await _buy_import("wireless_earbuds", "letter_of_credit", "settlement_kyc")
	await close_modal()
	bot.expect(int(GameState.stat("kyc_checks")) >= 1, "the large payment carries a KYC check")
	await pass_time_at_home(func(): return int(GameState.stat("kyc_cleared")) >= 1, 6, true)
	await popups()
	bot.expect(int(GameState.stat("kyc_cleared")) >= 1, "KYC cleared")
	await _home_laptop("finance")
	await bot.shot("finance_compliance_cost")
	await close_modal()
	bot.step("Chapter 12 — Victor Hale's offer")
	await _until_weekday_hours(11, 15)
	await exit_building()
	await metro_to("shopping_street")
	await enter_building("crestline_flagship")
	await bot.use(func(n): return n.action == "talk" and str(n.params.get("npc", "")) == "victor", "Victor Hale")
	await bot.wait(0.6)
	await bot.shot("victor_offer")
	await talk_through_dialogue_first_choice()
	await bot.until(func(): return UIRoot.top_modal() is DecisionModal, 12.0)
	await bot.wait(0.8)
	await _pin_badge_shot("badge_valuation_pinned")
	await popups()   # counter: a better price with an earn-out
	bot.expect(GameState.flag("offer_countered") and GameState.flag("company_sold"), "countered Hale Group's offer")
	await bot.wait(1.2)
	await bot.shot("ending_card")
	await bot.wait(3.0)
	bot.expect("ch12_regulation_scale" in StoryEngine.St()["chapters_done"], "Chapter 12 complete")
	bot.expect(GameState.flag("story_complete"), "the main story is complete")
	bot.expect("goal_growth" in StoryEngine.St()["active"], "free play: the growth goal")
	bot.expect(Ledger.check_balanced(), "ledger balanced after chapters 10–12")
	await exit_building()
	await metro_to("riverside")
	await enter_building("riverside_apartment")


## Test harness for `--from=ch10`: set the first nine chapters' outcome directly (a company, a business account, Suite
## 2B, the exchange account) so Chapters 10–12 can be rerun in minutes.
func _fast_forward_to_ch10() -> void:
	bot.step("(harness) skip to Chapter 10")
	GameState.data["tutorial"] = {"step": 99, "seen": {}, "off": true, "v": 99}
	Company.register("Riverlight Goods", "ecommerce", "22 Founders Lane")
	Company.open_business_account(20000.0)
	Living.lease("suite_2b")
	var st := StoryEngine.St()
	st["active"] = []
	for ch in StoryEngine.chapters():
		if str(ch["id"]) == "ch10_digital_rails":
			break
		st["chapters_done"].append(ch["id"])
		for o in ch.get("objectives", []):
			st["done"].append(o["id"])
	st["chapter"] = "ch9_clearing_crisis"
	World.set_year(5)
	for f in ["phone_opened", "business_chosen", "met_lina", "exchange_account", "employer_registered"]:
		GameState.set_flag(f)
	StoryEngine.start_chapter("ch10_digital_rails")
	await bot.wait(1.0)


func talk_through_dialogue_first_choice() -> void:
	await bot.until(func(): return UIRoot.dialogue.active, 3.0)
	await bot.talk_through_dialogue()


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
