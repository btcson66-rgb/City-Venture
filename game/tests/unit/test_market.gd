extends RefCounted

var runner


func _start(seed_value := 90) -> void:
	Clock.clear_pauses()
	Clock.world_active = false
	GameState.new_game({"name": "Market QA", "seed": seed_value})
	Macro.initialize()


func _path(seed_value: int) -> String:
	_start(seed_value)
	Macro.advance_to(120)
	return JSON.stringify(Macro.S()["path"])


func test_seeded_path_and_saved_rng_resume() -> void:
	var first := _path(90)
	runner.eq(first, _path(90), "same seed reproduces 120 daily rates/cycle/prices")
	runner.check(first != _path(91), "different seeds differ")
	_start(90)
	Macro.advance_to(45)
	GameState.data = JSON.parse_string(JSON.stringify(GameState.data))
	Macro.advance_to(120)
	runner.eq(JSON.stringify(JSON.parse_string(first)), JSON.stringify(JSON.parse_string(JSON.stringify(Macro.S()["path"]))), "JSON load resumes private RNG")
	var size: int = Macro.S()["path"].size()
	Macro.advance_to(120)
	runner.eq(Macro.S()["path"].size(), size, "same day never advances twice")


func test_cycle_boundaries_industry_sensitivity_and_expiring_shock() -> void:
	_start()
	Macro.S()["index"] = 0.7
	Macro.S()["rate"] = 0.09
	runner.eq(Macro.phase(), "Trough", "low cycle phase")
	runner.check(Macro.demand("real_estate") < Macro.demand("cafe") and Macro.demand("automotive") < Macro.demand("cafe"), "rate-sensitive sectors fall further")
	Macro.S()["shock"] = -0.05
	Macro.S()["shock_until"] = 0
	Macro.advance_to(1)
	runner.check(float(Macro.S()["shock"]) != -0.05, "expired shock clears")
	Macro.advance_to(1000)
	for point in Macro.S()["path"]:
		runner.check(float(point["rate"]) >= float(Macro.cfg()["rate_min"]) and float(point["rate"]) <= float(Macro.cfg()["rate_max"]), "bounded rate")
		runner.check(float(point["index"]) >= float(Macro.cfg()["cycle_min"]) and float(point["index"]) <= float(Macro.cfg()["cycle_max"]), "bounded cycle")
	runner.check(Macro.S()["path"].size() <= int(Macro.cfg()["history_days"]), "bounded history")
	World.set_year(3)
	runner.check(World.cost_mult("tradelink_wholesale") != Macro.costs(), "scripted era overlays cost process")


func test_rival_weekly_bounds_shares_and_bankruptcy() -> void:
	_start()
	for week in 100:
		Rivals.decide_week()
	for industry in DataDB.businesses:
		var share := Rivals.shares(industry)
		var total := 0.0
		for value in share.values():
			runner.check(float(value) >= 0 and float(value) <= 1, "bounded share")
			total += float(value)
		runner.check(absf(total - 1.0) < 0.000001, "shares sum to one")
		for rival in Rivals.companies(industry):
			for trade in rival["trades"]:
				runner.check(absf(float(trade["revenue"]) - snappedf(int(trade["units"]) * float(trade["unit_price"]), 0.01)) < 0.001, "rival receipts trace quantity times charged price")
			runner.check(float(rival["price"]) >= float(Rivals.cfg()["price_min"]) and float(rival["price"]) <= float(Rivals.cfg()["price_max"]), "price boundary")
			runner.check(int(rival["locations"]) <= int(Rivals.cfg()["max_locations"]), "expansion boundary")
	var victim: Dictionary = Rivals.companies("cafe")[0]
	victim["status"] = "active"
	victim["cash"] = -100000
	Rivals.decide_week()
	runner.check(victim["status"] in ["bankrupt", "acquired"] and Rivals.shares("cafe")[victim["id"]] == 0, "failed rival exits share and bids")
	runner.check(Ledger.check_balanced(), "AI simulation does not post unbalanced player money")


func test_poaching_two_choices_expiry_and_closed_company() -> void:
	Clock.world_active = false
	GameState.new_game({"seed": 90, "run": {"scenario": "inherited_cafe", "story": false}})
	Macro.initialize()
	var employee := str(Staff.people()[0]["id"])
	var salary := float(Staff.people()[0]["salary_week"])
	runner.check(Rivals.make_offer(employee, "cafe_1"), "offer created")
	runner.check(Rivals.answer(employee, true), "match salary retains")
	runner.check(Staff.count() == 1 and float(Staff.people()[0]["salary_week"]) > salary, "retaining has real recurring payroll cost")
	runner.check(not Rivals.answer(employee, false), "answer once")
	runner.check(Rivals.make_offer(employee, "cafe_1"), "second offer created")
	GameState.data["clock"]["minutes"] = int(Rivals.S()["offers"][employee]["expires"])
	Rivals.on_hour(Clock.now(), 12)
	runner.check(Staff.count() == 0 and Rivals.pending().is_empty(), "timeout automatically releases without pause")
	runner.check(Ledger.check_balanced(), "poaching preserves books")


func test_acquisition_cash_double_entry_and_closed_company() -> void:
	_start()
	Company.register("Market buyer", "cafe", "riverside_studio")
	Company.open_business_account(20000)
	runner.check(not Acquisition.buy_rival("cafe_1")["ok"], "late-game gate")
	GameState.data["clock"]["minutes"] = 200 * Clock.DAY
	var rival: Dictionary = Rivals.S()["companies"]["cafe_1"]
	rival["cash"] = 0
	var before := Ledger.cash(GameState.company_id())
	var price := Rivals.acquire_price("cafe_1")
	var worth := Replay.net_worth()
	var company_value := Company.company_value()
	runner.check(Acquisition.buy_rival("cafe_1")["ok"], "affordable acquisition")
	runner.eq(Ledger.cash(GameState.company_id()), before - price, "cash paid once")
	runner.eq(Ledger.balance(GameState.company_id(), "investments"), price, "asset recorded")
	runner.eq(Replay.net_worth(), worth, "purchase exchanges cash for asset, not instant wealth")
	runner.eq(Company.company_value(), company_value, "company book value includes acquired asset")
	runner.check(not Acquisition.buy_rival("cafe_1")["ok"], "cannot buy twice")
	var entity := GameState.company_id()
	runner.check(Insolvency.close_company()["ok"], "company closes normally")
	runner.eq(Ledger.balance(entity, "investments"), 0.0, "acquired investment written off at closure")
	runner.eq(rival["status"], "bankrupt", "owned rival exits at closure")
	runner.check(not Acquisition.buy_rival("cafe_2")["ok"] and not Rivals.participates("cafe"), "closed company cannot acquire or claim share")
	runner.check(Ledger.check_balanced(), "acquisition ledger balances")


func test_news_daily_count_dedup_bounds_and_legacy_quotes() -> void:
	_start()
	for day in 80:
		GameState.data["clock"]["minutes"] = day * Clock.DAY + 8 * 60
		CityNews.enqueue("First story", "rival")
		CityNews.enqueue("First story", "rival")
		CityNews.enqueue("Second story", "event")
		CityNews.publish_day()
		CityNews.publish_day()
		var count: int = CityNews.S()["items"].filter(func(item): return int(item["day"]) == day + 1).size()
		runner.check(count >= 1 and count <= 3, "one to three stories per day, no duplicate publishing")
	runner.check(CityNews.S()["items"].size() <= int(Rivals.cfg()["news_limit"]), "bounded news history")
	GameState.data.erase("macro")
	GameState.data.erase("rivals")
	runner.eq(Macro.demand("cafe"), 1.0, "old save neutral until play initializes")
	runner.eq(Rivals.demand("ecommerce"), 1.0, "old save neutral market")
	runner.check(not Macro.active() and not Rivals.active(), "passive quotes do not mutate old save")

