extends RefCounted
var runner

func setup() -> String:
	GameState.new_game({"name":"Legacy Founder", "seed":92001})
	return load("res://tests/unit/test_global.gd").new()._setup()

func test_seven_formulas_are_data_driven_and_distinguish_three_strategies() -> void:
	setup()
	runner.eq(LifeLegacy.cfg()["archetypes"].size(), 7, "seven defined types")
	for row in [{"metrics":{"delivered":100, "overseas":20},"type":"merchant"}, {"metrics":{"features":8,"energy_installs":10,"chargers":3},"type":"innovator"}, {"metrics":{"recovery":1,"work_hours":100},"type":"comeback"}, {"metrics":{"industries":3,"employees":10,"net_worth":100000},"type":"builder"}, {"metrics":{"work_hours":150},"type":"operator"}, {"metrics":{"city_projects":3,"chargers":3,"contacts":10},"type":"local_legend"}, {"metrics":{"net_worth":100000,"quiet_work":1},"type":"quiet_owner"}]:
		var scored := LifeLegacy.scores(row["metrics"])
		runner.eq(scored[0]["id"], row["type"], "different traceable strategy")
		for score in scored: runner.check(score["score"] >= 0 and score["score"] <= 100, "bounded score")
	var bad := LifeLegacy.scores({"features":NAN, "delivered":INF, "employees":-100})
	for score in bad: runner.check(is_finite(score["score"]), "bad input cannot poison scores")

func test_actual_metrics_include_work_and_city_sources_without_estimated_old_hours() -> void:
	setup()
	GameState.data["stats"]["paid_work_minutes"] = 120
	GameState.data["stats"]["cafe_work_minutes"] = 60
	GameState.data["stats"]["gig_hours"] = 4
	GameState.data["stats"]["shifts_worked"] = 1000
	GameState.data["stats"]["re_projects_completed"] = 2
	GameState.data["stats"]["energy_installs"] = 3
	Energy.S()["sites"]["QA"] = {"status":"open"}
	GameState.set_flag("met_maya")
	var metrics := LifeLegacy.metrics()
	runner.eq(metrics["work_hours"], 7, "actual minutes only, old shift count not invented hours")
	runner.eq(metrics["city_projects"], 2, "actual completed projects")
	runner.eq(metrics["chargers"], 1, "actual open stations")
	runner.eq(metrics["contacts"], 1, "actual contact receipt")

func test_key_moment_ranking_categories_and_year_filter_are_stable() -> void:
	setup()
	var rows: Array = []
	for i in 10: rows.append({"t":i * Clock.DAY, "text":"QA record", "kind":"life" if i < 8 else "crisis"})
	var chosen := LifeLegacy.key_moments(rows)
	runner.eq(chosen.size(), 5, "five key moments")
	runner.eq(chosen[0]["t"], 9 * Clock.DAY, "higher category then recency")
	runner.eq(rows.size(), 10, "ranking does not reorder source")
	GameState.data["timeline"] = rows
	runner.eq(LifeLegacy.events("crisis").size(), 2, "category filter")
	var year := int(Clock.date_at(0)["year"])
	runner.eq(LifeLegacy.events("all", year).size(), 10, "calendar year filter")
	runner.eq(LifeLegacy.events("company", year + 1).size(), 0, "empty result supported")

func test_review_is_idempotent_and_unavailable_retirement_leaves_play_possible() -> void:
	setup()
	runner.check(not LifeLegacy.review(true)["ok"], "early retirement unavailable")
	runner.check(LifeLegacy.S()["review"].is_empty(), "no fabricated early ending")
	GameState.data["clock"]["minutes"] += 31 * Clock.DAY
	runner.check(LifeLegacy.review(true)["ok"], "optional real retirement")
	var before: Dictionary = LifeLegacy.S()["review"].duplicate(true)
	GameState.inc_stat("orders_delivered", 999)
	LifeLegacy.review(true)
	runner.eq(LifeLegacy.S()["review"], before, "already recorded does not rewrite history")
	SaveSystem.save(92)
	SaveSystem.load_data(92)
	runner.eq(LifeLegacy.S()["review"]["primary"]["id"], before["primary"]["id"], "life review type survives save/load")
	runner.eq(LifeLegacy.S()["review"]["epilogue"], before["epilogue"], "life review text survives save/load")
	for key in before["metrics"]: runner.eq(LifeLegacy.S()["review"]["metrics"][key], before["metrics"][key], "saved metric " + key)
	GameState.data.erase("life_legacy")
	runner.check(LifeLegacy.S()["review"].is_empty(), "old save lazy state")

func test_new_life_preserves_prior_save_and_separates_money_ownership_and_difficulty() -> void:
	setup()
	GameState.set_flag("legacy_cards_viewed")
	LifeLegacy.review()
	var old_slot := SaveSystem.current_slot()
	var old_name := str(GameState.data["player"]["name"])
	var before_worth := LifeLegacy.net_worth()
	var result := LifeLegacy.next_life("next")
	runner.check(result["ok"], "explicit next life")
	if not result["ok"]: return
	runner.check(int(result["slot"]) != old_slot and SaveSystem.has_save(old_slot), "separate slot, original retained")
	runner.eq(GameState.data["player"]["name"], old_name, "same character")
	runner.eq(GameState.company_id(), "", "old company not transplanted")
	runner.eq(GameState.stat("orders_delivered"), 0, "old sales not new income")
	runner.check(result["inherited"] <= 2500 and result["inherited"] <= before_worth * 0.05, "limited inheritance")
	runner.eq(GameState.data["meta"]["difficulty"], 1, "difficulty actually increments")
	runner.eq(LifeLegacy.demand_factor(), 0.9, "new retail competition lowers demand")
	runner.eq(Ledger.cash("player"), 24000 + float(result["inherited"]), "harder initial cash plus equity inheritance")
	runner.eq(MonthClose.current("player")["net_revenue"], 0, "inheritance is not sale")
	runner.check(Ledger.check_balanced(), "new-life books balanced")
	var new_data := GameState.data.duplicate(true)
	SaveSystem.load_data(old_slot)
	runner.eq(GameState.data["player"]["name"], old_name, "prior game loads")
	runner.check(LifeLegacy.S()["review"].size() > 0, "prior review retained")
	GameState.data = new_data

func test_next_generation_company_closure_and_zero_wealth_are_not_soft_locks() -> void:
	setup()
	Insolvency.close_company()
	GameState.set_flag("legacy_cards_viewed")
	LifeLegacy.review()
	var result := LifeLegacy.next_life("generation")
	runner.check(result["ok"], "next generation works after company closes")
	if result["ok"]:
		runner.check(str(GameState.data["player"]["name"]).contains("Legacy Founder"), "next generation retains identity link")
		runner.eq(GameState.company_id(), "", "fresh company-free world")
		runner.check(Ledger.check_balanced(), "inheritance book balanced")

func test_full_slots_keep_original_game_and_main_action_always_returns_to_play() -> void:
	setup()
	GameState.set_flag("legacy_cards_viewed")
	LifeLegacy.review()
	for slot in SaveSystem.GAME_SLOTS: SaveSystem.save(slot)
	var before := GameState.data.duplicate(true)
	runner.check(not LifeLegacy.next_life("next")["ok"], "no silent save replacement")
	runner.eq(GameState.data, before, "blocked NG+ preserves complete game")
	var modal := LifeReviewModal.new()
	modal.body = UIK.vbox()
	modal.add_child(modal.body)
	modal.build()
	runner.check(modal.find_child("KeepThisLife", true, false) != null, "unavailable never traps player")
	modal.free()
	for slot in SaveSystem.GAME_SLOTS:
		DirAccess.remove_absolute(SaveSystem._path(slot))

func test_negative_net_worth_and_productivity_bonus_do_not_rewrite_actual_hours() -> void:
	setup()
	Ledger.expense("player", "other", 50000, "QA personal loss")
	runner.check(LifeLegacy.metrics()["net_worth"] < 0, "negative wealth is displayed honestly")
	Saas.start("freelancer_invoicing")
	Saas.add_dev(8, true, 4)
	runner.eq(LifeLegacy.metrics()["work_hours"], 4, "productivity credit is not physical work time")
	GameState.set_flag("legacy_cards_viewed")
	LifeLegacy.review()
	var result := LifeLegacy.next_life("next")
	runner.check(result["ok"], "negative wealth never traps next life")
	if result["ok"]: runner.eq(result["inherited"], 0, "no wealth creates no inherited capital")
