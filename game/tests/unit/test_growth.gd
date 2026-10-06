extends RefCounted
var runner

func setup() -> String:
	GameState.new_game({"name":"Growth Test", "seed":35001})
	var fixture = load("res://tests/unit/test_global.gd").new()
	return fixture._setup()

func provide(source: String, target: float) -> void:
	var ent := GameState.company_id()
	if source.begins_with("stat:"):
		GameState.data["stats"][source.substr(5)] = target
	elif source.begins_with("flag:"):
		GameState.set_flag(source.substr(5))
	elif source.begins_with("ending:"):
		LegacyBusiness.S()["ending"] = source.substr(7)
	else:
		match source:
			"staff":
				for i in int(target): Staff.S()["people"][str(i)] = {"id": str(i), "name":"Test colleague", "role":"packer", "wage":10, "morale":1, "started":Clock.now()}
			"industries":
				Saas.S()["active"] = true
				Living.lease("corner_cafe")
				for segment in ["ecommerce", "saas", "cafe"]:
					Ledger.post(ent, "QA earned sale", [{"acct":"cash", "dr":10}, {"acct":"revenue", "cr":10}], {"segment":segment})
			"cafe_rating":
				Living.lease("corner_cafe")
				Cafe.S()["rating"] = target
				GameState.inc_stat("cafe_customers")
			"earned_revenue", "annual_revenue": Ledger.post(ent, "QA annual sales", [{"acct":"cash", "dr":target}, {"acct":"revenue", "cr":target}])
			"profit_months":
				for month in int(target):
					GameState.data["reports"]["month_closes"].append({"period":"2025-%02d" % (month + 1), "entities":{ent:{"business_profit":5001}}})
			"debt_free": Bank.B()["loans"]["QA"] = {"entity":ent, "status":"closed", "balance":0}
			"foreign_deliveries": Ecommerce.E()["orders"]["QA"] = {"region":"northridge", "delivered":Clock.now(), "status":"delivered"}
			"never_overdrawn": GameState.data["clock"]["minutes"] = int(target) * Clock.DAY
			"negotiation": GameState.data["contracts"]["QA"] = {"buyer":"QA buyer", "history":[{"by":"QA buyer", "text":"Deal. Send it over."}]}

func test_all_goals_and_twenty_five_achievements_have_trigger_receipts() -> void:
	runner.eq(Growth.definitions("achievements").size(), 25, "twenty-five definitions")
	for kind in ["goals", "achievements"]:
		for d in Growth.definitions(kind):
			setup()
			GameState.set_flag("legacy_cards_viewed")
			provide(d["metric"], float(d["value"]))
			runner.check(Growth.met(d), "source triggers " + d["id"])
			Growth.check(true)
			var receipts: Dictionary = Growth.S()["completed" if kind == "goals" else "achievements"]
			runner.check(receipts.has(d["id"]), "dated receipt " + d["id"])
			var before: int = GameState.data["timeline"].size()
			Growth.record(d, kind)
			runner.eq(GameState.data["timeline"].size(), before, "already done never awarded again: " + d["id"])
			runner.check(Ledger.check_balanced(), "goal never unbalances ledger")

func test_three_goals_rotate_after_completion_without_a_cash_reward() -> void:
	setup()
	GameState.set_flag("legacy_cards_viewed")
	Growth.check(true)
	runner.eq(Growth.S()["active"].size(), 3, "three incomplete goals")
	var old: Array = Growth.S()["active"].duplicate()
	var d: Dictionary = Growth.definitions().filter(func(g): return g["id"] == old[0])[0]
	provide(d["metric"], float(d["value"]))
	var cash := Ledger.cash(GameState.company_id())
	var msgs: int = GameState.data["messages"].size()
	Growth.check(true)
	runner.eq(Growth.S()["active"].size(), 3, "refills exactly one slot")
	runner.check(not old[0] in Growth.S()["active"], "completed goal removed")
	runner.eq(Ledger.cash(GameState.company_id()), cash, "no fabricated reward cash")
	runner.check(GameState.data["messages"].size() > msgs, "NPC congratulation")
	runner.check(old[0] in Growth.S()["pending"], "small completion card retained")

func test_every_goal_no_longer_possible_can_be_reviewed_and_closed_company_never_blocks() -> void:
	for d in Growth.definitions():
		setup()
		GameState.set_flag("legacy_cards_viewed")
		Growth.check(true)
		var was_done: bool = Growth.S()["completed"].has(d["id"])
		Growth.S()["active"] = [d["id"]]
		Growth.review(d["id"])
		runner.eq(Growth.S()["completed"].has(d["id"]), was_done, "review never fabricates completion: " + d["id"])
		Growth.check(true)
		Insolvency.close_company()
		Growth.check(true)
		for id in Growth.S()["active"]:
			var g: Dictionary = Growth.definitions().filter(func(row): return row["id"] == id)[0]
			runner.check(not g.get("company", false), "no closed-company objective blocks play")
		runner.check(not Growth.S()["achievements"].has("sold"), "closure cannot invent a sale")

func test_ledger_history_detects_transient_overdraft_and_retains_it_across_save() -> void:
	setup()
	Growth.check(true)
	var ent := GameState.company_id()
	var amount := Ledger.cash(ent) + 1
	Ledger.expense(ent, "other", amount, "QA transient negative cash")
	Ledger.post(ent, "QA recapitalization", [{"acct":"cash", "dr":amount}, {"acct":"equity", "cr":amount}])
	GameState.data["clock"]["minutes"] += 31 * Clock.DAY
	Growth.check(true)
	runner.check(Growth.S()["overdrawn"], "cash never-overdrawn uses intermediate journal, not current positive cash")
	runner.check(not Growth.S()["achievements"].has("never_overdrawn"), "ineligible award remains locked")
	SaveSystem.save(35)
	runner.check(SaveSystem.load_data(35), "growth state loads")
	runner.check(Growth.S()["overdrawn"], "negative-history receipt preserved")

func test_old_save_backfills_met_conditions_without_repaying_rewards() -> void:
	setup()
	GameState.data["stats"]["orders_delivered"] = 120
	GameState.set_flag("offer_declined")
	GameState.data.erase("growth")
	SaveSystem.save(35)
	runner.check(SaveSystem.load_data(35), "old save without growth lazy loads")
	runner.check(Growth.S()["achievements"].has("declined") and Growth.S()["achievements"].has("first_delivery"), "existing history unlocks")
	var n: int = Growth.S()["achievements"].size()
	SaveSystem.save(35)
	SaveSystem.load_data(35)
	runner.eq(Growth.S()["achievements"].size(), n, "reload idempotent")

func test_real_metrics_reject_empty_loan_shell_and_nonconsecutive_profit_months() -> void:
	var ent := setup()
	runner.eq(Growth.metric("debt_free"), 0, "never borrowed is not debt repaid")
	runner.eq(Growth.metric("industries"), 0, "empty OS tabs not operating businesses")
	provide("profit_months", 3)
	runner.eq(Growth.metric("profit_months"), 3, "consecutive reports")
	GameState.data["reports"]["month_closes"].remove_at(1)
	runner.eq(Growth.metric("profit_months"), 1, "gap resets streak")
	Bank.B()["loans"]["QA"] = {"entity":ent, "status":"defaulted", "balance":1000}
	runner.eq(Growth.metric("debt_free"), 0, "default or writeoff not repayment")

func test_achievement_and_timeline_screens_have_one_primary_and_hints_for_locked_items() -> void:
	setup()
	for page in ["goals", "achievements", "timeline"]:
		var modal := GrowthModal.new(page)
		modal.body = UIK.vbox()
		modal.add_child(modal.body)
		modal.build()
		var pending: Array = [modal]
		var buttons := 0
		while not pending.is_empty():
			var node: Node = pending.pop_back()
			pending.append_array(node.get_children())
			if node is Button and not str(node.name).begins_with("GrowthTab_") and node.has_theme_stylebox_override("normal"): buttons += 1
		runner.eq(buttons, 1, "one current next-step button: " + page)
		modal.free()

func test_other_companies_cash_does_not_disqualify_the_player() -> void:
	setup()
	GameState.data["entities"]["external_qa"] = {"id":"external_qa", "kind":"npc", "name":"Other business"}
	Ledger.expense("external_qa", "other", 10, "External debt")
	Growth.check(true)
	runner.check(not Growth.S()["overdrawn"], "NPC cash is not founder cash history")
