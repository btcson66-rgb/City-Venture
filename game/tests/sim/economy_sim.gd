class_name EconomySim
extends RefCounted
## Reproducible player policy over the real scheduler, ledger and chapter conditions.
## Information-only visits/reads use the same flags as UI; purchases, payroll and contracts use real APIs.

var strategy := "cautious"
var chapter_days := {}
var objective_days := {}
var rows: Array = []
var bankruptcies := 0
var cash_shortfalls := 0
var insolvencies := 0
var ch7_profit := -INF
var _seen_reports := 0
var _negative := false
var _insolvent := false
var _imports := {}
var _contract_bought := false
var _products: Array = []


func run(policy: String, seed_value: int, months := 18) -> Dictionary:
	strategy = policy
	GameState.new_game({"name": "Balance Player", "seed": seed_value})
	Clock.world_active = false
	UIRoot._suppress_decisions = true
	GameState.data["tutorial"] = {"off": true, "v": 99, "step": 99, "seen": {}}
	_products = ["wireless_earbuds", "water_bottle"] if policy != "aggressive" else ["wireless_earbuds", "water_bottle", "desk_lamp", "phone_stand"]
	StoryEngine.start_chapter("ch1_arrival")
	for day in months * 31:
		if rows.size() >= months:
			break
		_information_actions()
		_decisions()
		_business_actions()
		for hour in 24:
			Clock.advance(60)
			_decisions()
			StoryEngine.check()
			_capture()
		if day % 30 == 0:
			print("sim %s day %d chapter %s cash %.0f" % [policy, day, StoryEngine.St()["chapter"], Ledger.cash(GameState.business_entity())])
	return {"strategy": policy, "seed": seed_value, "months": rows, "chapter_days": chapter_days, "objective_days": objective_days, "bankruptcies": bankruptcies,
		"cash_shortfalls": cash_shortfalls, "insolvencies": insolvencies,
		"ch7_profit": ch7_profit if is_finite(ch7_profit) else null, "balanced": Ledger.check_balanced(),
		"chapter": StoryEngine.St()["chapter"], "objectives_done": StoryEngine.St()["done"]}


func _information_actions() -> void:
	# Opening the phone, visiting and reading are non-financial player actions, not simulated income.
	for flag in ["maya_intro_done", "phone_opened", "bought_coffee_bloom_coffee", "business_chosen", "business_ecommerce"]:
		if not GameState.flag(flag):
			if flag == "bought_coffee_bloom_coffee":
				Ledger.expense("player", "coffee", 4.5, "Bloom Coffee")
			GameState.set_flag(flag)
	for place in ["riverside", "nexus_cowork"]:
		GameState.mark_visited(place)
	StoryEngine.check()
	var chapter: String = StoryEngine.St()["chapter"]
	if chapter.begins_with("ch3"):
		if GameState.company_id() == "":
			Company.register("Balance Goods", "ecommerce", "22 Founders Lane")
		if not GameState.flag("business_account_opened"):
			Company.open_business_account(minf(22000.0, Ledger.cash("player") - 3000.0))
		if not Living.has_lease("suite_2b"):
			Living.lease("suite_2b")
		if Living.has_lease("suite_2b"):
			GameState.set_flag("workspace_chosen")
		GameState.set_flag("company_os_opened_as_company")
	if chapter.begins_with("ch4"):
		Staff.register_employer()
		if Staff.count() == 0:
			if Staff.S()["applicants"].is_empty() and Staff.S()["posting"].is_empty():
				Staff.post_job("support")
			elif not Staff.S()["applicants"].is_empty():
				var applicants: Array = Staff.S()["applicants"].duplicate()
				applicants.sort_custom(func(a, b): return a["salary_week"] < b["salary_week"])
				Staff.hire(applicants[0]["id"])
		Forecast.weekly(GameState.business_entity())
		GameState.set_flag("cash_forecast_viewed")
	if chapter.begins_with("ch6"):
		Forecast.weekly(GameState.business_entity())
		GameState.set_flag("forecast_checked_ch6")
		var contract := Contracts.by_tag("big_contract")
		if not contract.is_empty() and contract["status"] == "delivered" and not GameState.flag("early_payment_agreed"):
			Contracts.early_payment(contract["id"])
	if World.year() >= 3:
		GameState.set_flag("news_read_y%d" % World.year())
	if chapter.begins_with("ch7") and not GameState.flag("repriced"):
		for listing in Ecommerce.E()["listings"].values():
			if strategy != "casual":
				Ecommerce.set_price(listing["id"], float(listing["price"]) * 1.2)
		# Casual intentionally never reprices: its chapter duration remains censored rather than forged.
	if chapter.begins_with("ch8"):
		if not "solar_lamp" in _products:
			var old: String = _products.back()
			var listing := Ecommerce.listing_for(old)
			if not listing.is_empty(): Ecommerce.set_active(listing["id"], false)
			_products.erase(old)
			_products.append("solar_lamp")
		Ecommerce.set_packaging("recycled")
		_buy_list("solar_lamp", "verdant_supply", 30)
		Company.claim_green_grant()
	if World.year() >= 5:
		GameState.set_flag("met_lina")
		GameState.set_flag("exchange_account")
	if chapter.begins_with("ch12"):
		if not Compliance.licence_valid() and not Compliance.licence_pending():
			Compliance.apply_licence()
	StoryEngine.check()


func _decisions() -> void:
	var preferred := {"customer_return_first": "refund", "customer_return": "refund", "supplier_price_increase": "accept",
		"unexpected_large_order": "review", "ad_cost_spike": "keep", "viral_mention": "ride", "low_cash_warning": "reduce",
		"crestline_big_offer": "review", "elena_offer": "accept", "supply_shock_plan": "local", "escrow_offer": "try",
		"rail_frozen": "reroute", "acquisition_offer": "decline", "shipment_lost": "reship"}
	for inst in EventEngine.pending().duplicate():
		var choices: Array = DataDB.events[inst["id"]].get("choices", [])
		choices.sort_custom(func(a, b): return a["id"] == preferred.get(inst["id"], "") and b["id"] != preferred.get(inst["id"], ""))
		for choice in choices:
			if EventEngine.choice_available(choice, inst["ctx"]):
				var result := EventEngine.choose(inst["iid"], choice["id"])
				if result.get("ok", false):
					break
	UIRoot.close_all()


func _business_actions() -> void:
	var ch: String = StoryEngine.St()["chapter"]
	var import_needed := ch.begins_with("ch9") or ch.begins_with("ch10") or ch.begins_with("ch11") or ch.begins_with("ch12")
	for product in _products:
		var demand := float(DataDB.product(product)["base_daily_demand"])
		var days := 42 if strategy == "aggressive" else 21
		var supplier := "verdant_supply" if product == "solar_lamp" else "tradelink_wholesale"
		var wanted := maxi(int(Ecommerce.offer(supplier, product)["moq"]), int(ceil(demand * days)))
		if strategy == "casual" and Clock.day_index() % 10 < 3:
			wanted = 0
		# Preserve room for the actual chapter import instead of endlessly refilling every vacant shelf.
		if not import_needed or _imports.has(ch):
			_buy_list(product, supplier, wanted)
	for loc in Ecommerce.stock_locations():
		Ecommerce.pack_orders(loc, -1, {})
		Ecommerce.courier_pickup(loc, "economy")
	for contract in Contracts.C().values():
		if contract.get("tag", "") != "big_contract":
			continue
		if contract["status"] == "offered":
			Contracts.accept(contract["id"])
		if contract["status"] == "active":
			if not _contract_bought:
				var result := Ecommerce.buy("tradelink_wholesale", "desk_lamp", int(contract["qty"]), "suite_2b", true)
				_contract_bought = result.get("ok", false)
			if Contracts.can_deliver(contract["id"]):
				Contracts.deliver(contract["id"])
	if import_needed:
		if not _imports.has(ch):
			var pid := "wireless_earbuds" if ch.begins_with("ch12") else "phone_stand"
			var method := "letter_of_credit" if ch.begins_with("ch12") else "escrow" if ch.begins_with("ch10") or ch.begins_with("ch11") else "international_wire"
			for loc in Ecommerce.stock_locations():
				var r := Ecommerce.buy("lumina_direct", pid, int(Ecommerce.offer("lumina_direct", pid)["moq"]), loc, false, -1, 1.0, method)
				if r.get("ok", false):
					_imports[ch] = true
					break
	StoryEngine.check()


func _buy_list(pid: String, supplier: String, target: int) -> void:
	var stock := Ecommerce.total_units_at_any(pid) + Ecommerce.incoming_units_of(pid)
	var moq := int(Ecommerce.offer(supplier, pid).get("moq", 1))
	if target > 0 and stock < target / 2:
		var qty := maxi(moq, target - stock)
		for loc in Ecommerce.stock_locations():
			if Ecommerce.space_block(loc, qty) == "":
				Ecommerce.buy(supplier, pid, qty, loc)
				break
	if Ecommerce.total_units_at_any(pid) > 0 and Ecommerce.listing_for(pid).is_empty():
		var ref := float(DataDB.product(pid)["ref_price"])
		var r := Ecommerce.create_listing(pid, ref * (1.0 if strategy == "casual" else 1.2), "self")
		if r.get("ok", false) and strategy == "aggressive":
			Ecommerce.set_ad_budget(r["listing_id"], 20.0)


func _capture() -> void:
	for objective in StoryEngine.St()["done"]:
		if not objective_days.has(objective):
			objective_days[objective] = Clock.day_index()
	for chapter in StoryEngine.St()["chapters_done"]:
		if not chapter_days.has(chapter):
			chapter_days[chapter] = Clock.day_index()
	var negative := Ledger.cash(GameState.business_entity()) < 0
	if negative and not _negative and not "ch12_regulation_scale" in chapter_days:
		cash_shortfalls += 1
	_negative = negative
	if not "ch12_regulation_scale" in chapter_days:
		bankruptcies = int(GameState.stat("companies_closed"))
		if Insolvency.active() and not _insolvent: insolvencies += 1
		_insolvent = Insolvency.active()
	var reports: Array = GameState.data["reports"]["month_closes"]
	while _seen_reports < reports.size():
		var report: Dictionary = reports[_seen_reports]
		_seen_reports += 1
		var book: Dictionary = report["entities"].get(GameState.business_entity(), report["entities"]["player"])
		rows.append({"month": report["period"], "revenue": book["net_revenue"], "gross_profit": book["gross_profit"],
			"opex": book["opex_total"], "net_profit": book["business_profit"], "cash": book["cash_close"], "chapter": StoryEngine.St()["chapter"]})
		if GameState.flag("ch7_month_profit") and not is_finite(ch7_profit):
			ch7_profit = float(book["business_profit"])
			print("ch7_month_profit: %.2f; survived_losses=%s" % [ch7_profit, GameState.flag("ch7_survived_losses")])
