extends RefCounted
var runner

func setup(branch := "independent") -> String:
	GameState.new_game({"name": "Legacy Test", "seed": 43001})
	var fixture = load("res://tests/unit/test_global.gd").new()
	var ent: String = fixture._setup()
	GameState.set_flag("company_sold", branch != "independent")
	GameState.set_flag("offer_countered", branch == "counter")
	GameState.data["cap_table"] = {"founder": 1.0} if branch == "independent" else {"hale_group": 1.0}
	StoryEngine.St()["active"].clear()
	return ent

func start(branch := "independent") -> String:
	var ent := setup(branch)
	StoryEngine.start_chapter("ch17_consolidation")
	return ent

func finish_market(strategy := "niche") -> void:
	var news := InfoModal.news()
	news.free()
	runner.check(LegacyBusiness.choose(strategy)["ok"], "real strategic choice")
	runner.check(LegacyBusiness.respond()["ok"], "actual operating response")
	GameState.data["clock"]["minutes"] += 60 * Clock.DAY
	LegacyBusiness.reconcile()
	StoryEngine.check()
	runner.check(LegacyBusiness.interview()["ok"], "actual record interview")
	runner.check("ch17_consolidation" in StoryEngine.St()["chapters_done"], "chapter17 completes")
	GameState.set_flag("legacy_met_maya")

func finish_ending(choice: String) -> void:
	runner.check(LegacyBusiness.end_story(choice)["ok"], "ending available: " + choice)
	for i in 5:
		LegacyBusiness.view_next()
	runner.check("ch18_legacy" in StoryEngine.St()["chapters_done"], "chapter18 completes: " + choice)
	runner.check(Ledger.check_balanced(), "ending books balanced")

func test_three_acquisition_branches_complete_both_routes_and_all_endings() -> void:
	for branch in ["independent", "sold", "counter"]:
		for route in ["niche", "scale"]:
			for ending in ["independent", "sale", "employees", "mentor"]:
				start(branch)
				finish_market(route)
				Staff.S()["people"]["EMP1"] = {"id": "EMP1", "name": "Existing employee", "role": "support", "salary_week": 500, "skill": 2, "morale": 70, "hired": Clock.now()}
				finish_ending(ending)

func test_strategy_receipt_requires_actual_price_and_cost_or_stock_action() -> void:
	var ent := start()
	var cash := Ledger.cash(ent)
	var l := LegacyBusiness.listing()
	var original := float(GlobalMarket.company()["stores"]["northridge"]["prices"][l["id"]])
	LegacyBusiness.choose("niche")
	runner.check(not GameState.flag("consolidation_response"), "choice alone is insufficient")
	LegacyBusiness.respond()
	runner.check(float(GlobalMarket.company()["stores"]["northridge"]["prices"][l["id"]]) > original, "real price increased")
	runner.eq(Ledger.cash(ent), cash - 60, "brand campaign actually paid")
	runner.check(not LegacyBusiness.respond()["ok"], "no duplicate charge")
	start()
	LegacyBusiness.choose("scale")
	LegacyBusiness.respond()
	runner.check(Ecommerce.E()["purchase_orders"].size() > 0, "scale buys actual inventory")
	runner.check(float(GlobalMarket.company()["stores"]["northridge"]["prices"][LegacyBusiness.listing()["id"]]) < original, "real price decreased")

func test_niche_reviews_replace_paid_ad_and_unaffordable_action_does_not_commit() -> void:
	var ent := start()
	LegacyBusiness.listing()["rating_n"] = 5
	LegacyBusiness.listing()["rating_sum"] = 23
	Company.transfer(ent, "player", Ledger.cash(ent))
	LegacyBusiness.choose("niche")
	runner.check(LegacyBusiness.respond()["ok"], "good existing reviews provide the free niche route")
	runner.eq(Ledger.balance(ent, "exp:advertising"), 0, "no fictitious ad or saving")
	ent = start()
	Company.transfer(ent, "player", Ledger.cash(ent))
	LegacyBusiness.choose("niche")
	runner.check(not LegacyBusiness.respond()["ok"], "cash short does not commit")
	runner.check(not GameState.flag("consolidation_response"), "uncompleted response remains honest")
	LegacyBusiness.review_unavailable()
	runner.check("ch17_consolidation" in StoryEngine.St()["chapters_done"], "unavailable route can end without inventing survival")
	runner.check(not GameState.flag("consolidation_survived"), "no survival receipt on review")

func test_demand_curve_directions_are_local_and_crisis_decays() -> void:
	start()
	var l := LegacyBusiness.listing()
	runner.eq(LegacyBusiness.demand_factor(l, "home"), 1, "unaffected market unchanged")
	runner.eq(LegacyBusiness.demand_factor(l, "northridge"), 0.65, "initial rival takes 35 percent")
	GameState.data["clock"]["minutes"] += 30 * Clock.DAY
	runner.check(LegacyBusiness.demand_factor(l, "northridge") > 0.65, "crisis begins recovering")
	GameState.data["clock"]["minutes"] += 30 * Clock.DAY
	runner.eq(LegacyBusiness.demand_factor(l, "northridge"), 1, "shock fully expires")
	LegacyBusiness.choose("niche")
	LegacyBusiness.respond()
	var niche := LegacyBusiness.demand_factor(l, "northridge")
	runner.eq(LegacyBusiness.elasticity(l, "northridge", 1.4), 0.8, "niche is less price sensitive")
	start()
	LegacyBusiness.choose("scale")
	LegacyBusiness.respond()
	GameState.data["clock"]["minutes"] += 60 * Clock.DAY
	runner.check(LegacyBusiness.demand_factor(LegacyBusiness.listing(), "northridge") > niche, "scale increases volume relative to niche")
	runner.eq(LegacyBusiness.elasticity(LegacyBusiness.listing(), "northridge", 1.4), 2, "scale is more price sensitive")

func test_closed_store_falls_back_to_local_and_closed_company_skips_without_revenue() -> void:
	start()
	GlobalMarket.company()["stores"].clear()
	LegacyBusiness.reconcile()
	runner.eq(LegacyBusiness.market()["region"], "home", "removed overseas store becomes local competitor")
	LegacyBusiness.choose("niche")
	runner.check(LegacyBusiness.respond()["ok"], "local price and brand route works")
	var ent := start()
	GameState.data["entities"][ent]["closed"] = Clock.now()
	LegacyBusiness.reconcile()
	StoryEngine.check()
	runner.check("ch17_consolidation" in StoryEngine.St()["chapters_done"], "closed company drains every chapter17 objective")
	runner.check(not GameState.flag("consolidation_survived") and not GameState.flag("kai_interviewed"), "no fake success")
	GameState.data["company"] = ""
	GameState.set_flag("legacy_met_maya")
	finish_ending("independent")

func test_every_objective_already_done_for_all_three_branches_has_no_soft_lock() -> void:
	for branch in ["independent", "sold", "counter"]:
		setup(branch)
		for flag in ["consolidation_news_read", "consolidation_response", "consolidation_survived", "kai_interviewed", "legacy_met_maya", "legacy_chosen", "legacy_cards_viewed"]:
			GameState.set_flag(flag)
		StoryEngine.start_chapter("ch17_consolidation")
		runner.check("ch17_consolidation" in StoryEngine.St()["chapters_done"] and "ch18_legacy" in StoryEngine.St()["chapters_done"], "both chapters drain already-done receipts")

func test_every_chapter_unavailable_then_legacy_finishes_for_every_ownership_branch() -> void:
	for branch in ["independent", "sold", "counter"]:
		for choice in ["independent", "sale", "mentor"]:
			var ent := setup(branch)
			GameState.data["entities"][ent]["closed"] = Clock.now()
			GameState.data["company"] = ""
			StoryEngine.start_chapter("ch17_consolidation")
			runner.check("ch17_consolidation" in StoryEngine.St()["chapters_done"], "no company cannot strand chapter17")
			GameState.set_flag("legacy_met_maya")
			finish_ending(choice)

func test_sale_uses_same_current_valuation_and_prior_owner_cannot_collect_twice() -> void:
	var ent := start()
	finish_market()
	var quote := Acquisition.quote()
	var cash := Ledger.cash("player")
	LegacyBusiness.end_story("sale")
	runner.eq(Ledger.cash("player") - cash, quote["take"], "exact Chapter12 algorithm and current books")
	runner.eq(Acquisition.quote()["founder_share"], 0, "Hale-owned company has no default founder equity")
	runner.check(not LegacyBusiness.end_story("sale")["ok"], "no duplicate sale ending")
	start("sold")
	finish_market()
	cash = Ledger.cash("player")
	LegacyBusiness.end_story("sale")
	runner.eq(Ledger.cash("player"), cash, "previous sale never pays again")

func test_employee_grant_preserves_shares_and_balances_actual_equity_entries() -> void:
	var ent := start()
	finish_market()
	runner.check(LegacyBusiness.ending_block("employees") != "", "no employee gets explicit blocker")
	Staff.S()["people"]["EMP1"] = {"id": "EMP1", "role": "support"}
	var book := -Ledger.balance(ent, "equity")
	var investment := Ledger.balance("player", "investments")
	LegacyBusiness.end_story("employees")
	runner.eq(GameState.data["cap_table"]["founder"], 0.9, "shares transferred, not minted")
	runner.eq(GameState.data["cap_table"]["employees"], 0.1, "team share")
	runner.eq(-Ledger.balance(ent, "equity:employees"), snappedf(book * .1, .01), "team equity account credited")
	runner.eq(Ledger.balance("player", "investments"), snappedf(investment * .9, .01), "founder gives up carrying value")
	runner.check(Ledger.check_balanced(), "ownership transfer balanced")

func test_save_load_mid_response_and_epilogue_and_old_save_without_keys() -> void:
	start()
	LegacyBusiness.choose("niche")
	runner.check(SaveSystem.save(43) and SaveSystem.load_data(43), "pending route persists")
	runner.eq(LegacyBusiness.market()["strategy"], "niche", "same pending choice")
	finish_market()
	LegacyBusiness.end_story("independent")
	LegacyBusiness.view_next()
	runner.check(SaveSystem.save(43) and SaveSystem.load_data(43), "epilogue persists")
	runner.eq(int(LegacyBusiness.S()["viewed"]), 1, "resume correct card")
	var old: Dictionary = GameState.data.duplicate(true)
	old.erase("legacy_story")
	GameState.data = SaveSystem._migrate(old)
	runner.check(LegacyBusiness.market().is_empty(), "old save initializes additive state")
	DirAccess.remove_absolute(SaveSystem._path(43))

func test_contract_manager_bills_real_cost_fulfils_orders_and_stops_at_closure() -> void:
	var ent := start()
	finish_market()
	LegacyBusiness.end_story("mentor")
	var cash := Ledger.cash(ent)
	Ecommerce._h_order_place({"listing": LegacyBusiness.listing()["id"]})
	var order: Dictionary = Ecommerce.E()["orders"]["#%d" % int(Ecommerce.E()["counters"]["order"])]
	GameState.data["clock"]["minutes"] = Clock.at_day_time(1, 10 * 60)
	LegacyBusiness.on_hour()
	runner.check(Ledger.cash(ent) < cash and Ledger.balance(ent, "exp:payroll") >= 80, "real contract manager fee")
	runner.eq(order["status"], "awaiting_pickup", "manager actually packs and books courier")
	var entries: int = GameState.data["ledger"]["journal"].size()
	LegacyBusiness.on_hour()
	runner.eq(GameState.data["ledger"]["journal"].size(), entries, "same hour does not duplicate")
	GameState.data["entities"][ent]["closed"] = Clock.now()
	GameState.data["clock"]["minutes"] += 40 * Clock.DAY
	LegacyBusiness.on_hour()
	runner.eq(GameState.data["ledger"]["journal"].size(), entries, "closed company cannot bill or work")

func test_interview_uses_records_and_estimated_share_is_named_honestly() -> void:
	start()
	runner.check(not LegacyBusiness.interview()["ok"], "cannot interview before survival")
	var report := LegacyBusiness.report()
	runner.eq(report["revenue"], 0, "no invented revenue")
	runner.eq(report["units"], 0, "no invented sales")
	finish_market()
	runner.check(GameState.data["messages"].any(func(m): return m["from"] == "kai" and str(m["text"]).contains(I18n.t("Model-estimated"))), "report identifies estimate")
	var entries: int = GameState.data["messages"].size()
	LegacyBusiness.interview()
	runner.eq(GameState.data["messages"].size(), entries, "no duplicate interview")

func test_second_offer_uses_recorded_ch12_price_and_old_saves_disclose_missing_history() -> void:
	setup()
	var ctx := Acquisition.context()
	Acquisition.decide("decline", ctx)
	Ledger.post(GameState.company_id(), "Later funding", [{"acct": "cash", "dr": 50000}, {"acct": "equity", "cr": 50000}])
	StoryEngine.start_chapter("ch17_consolidation")
	runner.check(LegacyBusiness.market()["previous_offer_known"], "recorded previous offer")
	runner.check(float(LegacyBusiness.market()["second_offer"]) < float(ctx["price_v"]), "second offer below actual prior quote despite later funding")
	start()
	runner.check(not LegacyBusiness.market()["previous_offer_known"], "old save does not invent a prior price")

func test_pending_rival_decision_has_free_exit_after_closure() -> void:
	var ent := start()
	GameState.data["entities"][ent]["closed"] = Clock.now()
	runner.check(Effects.apply({"op": "market_strategy", "strategy": "review"}, {})["ok"], "stale event has an available real review")
	runner.check("ch17_consolidation" in StoryEngine.St()["chapters_done"], "stale event cannot soft lock closure")

func test_valuation_includes_foreign_book_assets_and_second_sale_is_rejected() -> void:
	var ent := setup()
	var before := float(Acquisition.quote()["owed"])
	Ledger.post(ent, "Foreign asset fixture", [{"acct": "fx_wallet:NRD", "dr": 100}, {"acct": "cash", "cr": 100}])
	runner.eq(Acquisition.quote()["owed"], before + 100, "foreign historical book asset included")
	var ctx := Acquisition.context()
	Acquisition.decide("accept", ctx)
	var cash := Ledger.cash("player")
	runner.check(not Acquisition.decide("accept", ctx)["ok"], "direct API cannot replay founder sale")
	runner.eq(Ledger.cash("player"), cash, "repeat context creates no money")

func test_route_trade_scenarios_profit_on_average_and_can_lose_real_costs() -> void:
	var rows: Array = []
	var profitable_route := false
	for route in ["niche", "scale"]:
		var profit_sum := 0.0
		var loss := false
		for scenario in 4:
			var ent := setup()
			GlobalMarket.set_price("northridge", str(Ecommerce.listing_for("wireless_earbuds")["id"]), 60 / FX.rate("NRD"))
			StoryEngine.start_chapter("ch17_consolidation")
			var t0 := Clock.now()
			var l := LegacyBusiness.listing()
			if scenario == 0:
				Ecommerce.inv("riverside_studio")[l["product"]]["avg_cost"] = 45
				Ledger.post(ent, "Input-cost stress fixture", [{"acct": "inventory", "dr": 540}, {"acct": "cash", "cr": 540}])
			LegacyBusiness.choose(route)
			runner.check(LegacyBusiness.respond()["ok"], "real strategic price/cost action")
			for i in 20:
				Ecommerce._h_order_place({"listing": l["id"], "region": "northridge"})
			Ecommerce.pack_orders("riverside_studio")
			Ecommerce.courier_pickup("riverside_studio", "economy")
			var orders: Array = Ecommerce.E()["orders"].values()
			var ids: Array = []
			for o in orders:
				ids.append(o["id"])
			Ecommerce._h_pickup({"ids": ids})
			for o in orders:
				if o["status"] == "shipped":
					GameState.data["clock"]["minutes"] = maxi(Clock.now(), int(o["ship"]["eta"]))
					Ecommerce._h_deliver({"order": o["id"]})
			GameState.data["clock"]["minutes"] += 3 * Clock.DAY
			GlobalMarket.payout(ent)
			GlobalMarket.convert_currency(ent, "NRD")
			var profit: float = MonthClose.compute(ent, t0, Clock.now() + 1)["business_profit"]
			profit_sum += profit
			loss = loss or profit < 0
			rows.append({"strategy": route, "scenario": scenario, "profit_home_dollars": profit})
			runner.check(Ledger.check_balanced(), "traceable route accounting")
		profitable_route = profitable_route or profit_sum / 4 > 0
		runner.check(loss, "expensive input stock can lose on either strategy")
	runner.check(profitable_route, "at least one sensible route profits on average including opening fees")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--legacy-balance-out="):
			var file := FileAccess.open(arg.trim_prefix("--legacy-balance-out="), FileAccess.WRITE)
			file.store_string(JSON.stringify(rows, " "))

func check_screen(expected := "") -> void:
	var modal := LegacyModal.new()
	modal.body = UIK.vbox()
	modal.add_child(modal.body)
	modal.build()
	var pending: Array = [modal]
	var primary: Array = []
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		if node is Button and node.has_theme_stylebox_override("normal"):
			primary.append(str(node.name))
	runner.check(primary.size() <= 1, "at most one primary step: " + str(primary))
	if expected != "":
		runner.check(expected in primary, "current next step is primary: " + expected)
	modal.free()

func test_screens_prioritize_next_step_and_endings_do_not_nudge_a_choice() -> void:
	start()
	check_screen("read_consolidation_news")
	GameState.set_flag("consolidation_news_read")
	LegacyBusiness.choose("niche")
	check_screen("apply_market_response")
	LegacyBusiness.respond()
	check_screen("continue_market_operations")
	GameState.data["clock"]["minutes"] += 60 * Clock.DAY
	LegacyBusiness.reconcile()
	check_screen("kai_interview")
	LegacyBusiness.interview()
	check_screen("meet_maya_legacy")
	GameState.set_flag("legacy_met_maya")
	check_screen()
	LegacyBusiness.end_story("independent")
	check_screen("legacy_next_card")

func test_unpaid_manager_suspends_and_restarted_company_can_finish_any_available_ending() -> void:
	var ent := start()
	finish_market()
	Company.transfer(ent, "player", Ledger.cash(ent))
	LegacyBusiness.end_story("mentor")
	GameState.data["clock"]["minutes"] += Clock.DAY
	LegacyBusiness.on_hour()
	runner.eq(Ledger.cash(ent), 0, "fee shortfall does not invent cash")
	runner.eq(-Ledger.balance(ent, "wages_payable"), 80, "fee remains actual liability")
	runner.check(Ledger.check_balanced(), "deferred fee balanced")
	for ending in ["independent", "sale", "mentor"]:
		setup()
		GameState.data["entities"][GameState.company_id()]["closed"] = Clock.now()
		GameState.data["company"] = ""
		Company.register("Restarted Founder", "retail_online", "22 Founders Lane")
		StoryEngine.start_chapter("ch18_legacy")
		GameState.set_flag("legacy_met_maya")
		finish_ending(ending)

func test_restart_ownership_and_valuation_never_use_personal_savings() -> void:
	var ent := setup()
	var ctx := Acquisition.context()
	Acquisition.decide("counter", ctx)
	var deferred: Dictionary = Sim.pending("acq.earnout")[0]["p"]
	runner.eq(deferred["entity"], ent, "earnout stays on sold company")
	Insolvency.close_company()
	var personal := Ledger.cash("player")
	runner.eq(Acquisition.quote()["price"], 0, "closed company never values personal savings")
	runner.check(Company.register("Restarted Legacy", "retail_online", "22 Founders Lane")["ok"], "actual restart")
	var restarted := GameState.company_id()
	runner.check(not Acquisition.sold(), "new company is not the old owner's division")
	runner.eq(GameState.data["cap_table"].get("founder", 0), 1, "new founder owns new company")
	runner.eq(Acquisition.quote()["price"], 0, "unbanked registration cannot generate a shell-sale windfall")
	runner.check(not Acquisition.decide("accept", ctx)["ok"], "stale old-company offer cannot sell new company")
	runner.check(Company.open_business_account(1000)["ok"], "new bank account")
	runner.eq(Acquisition.quote()["cash"], Ledger.cash(restarted), "only actual new-company cash valued")
	runner.check(Company.transfer(restarted, "player", 10)["ok"], "new-company founder withdrawal")
	var before := Ledger.cash("player")
	Acquisition.handle("acq.earnout", deferred)
	runner.eq(Ledger.cash("player"), before, "closed sold company never earns from restart's sales")
	runner.check(personal > 0 and Ledger.check_balanced(), "restart accounting balanced")
