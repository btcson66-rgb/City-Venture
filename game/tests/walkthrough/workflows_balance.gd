extends Node
var rows: Array = []
func _ready() -> void: call_deferred("run")
func profit() -> float:
	var value := Ledger.lifetime_gross_profit("player")
	for category in Ledger.EXPENSE_CATEGORIES: value -= Ledger.balance("player", "exp:" + category)
	return value
func run() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.substr(6)
	for strategy in ["conservative","normal","aggressive"]:
		for seed_value in [11401,11402,11403]: simulate(strategy, seed_value)
	var failures: Array = []
	var grouped := {}
	for strategy in ["conservative","normal","aggressive"]:
		var matched := rows.filter(func(row): return row["strategy"] == strategy)
		var mean := 0.0
		var losing_days := 0
		for row in matched: mean += float(row["profit"]) / matched.size(); losing_days += int(row["losing_days"])
		grouped[strategy] = {"mean_profit":snappedf(mean,0.01),"losing_days":losing_days}
		if strategy == "normal" and mean <= 0: failures.append("normal strategy does not profit on average")
		if losing_days == 0: failures.append(strategy + " has no observed downside")
	for row in rows:
		if not row["balanced"] or absf(float(row["consulting_profit"]) + float(row["shared_profit"]) - float(row["profit"])) > 0.01: failures.append("segment or ledger mismatch")
	DirAccess.make_dir_recursive_absolute(out)
	var f := FileAccess.open(out.path_join("workflows_balance_120.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"days":120,"scope":"Actual existing freelance offer generation, interviews, scope changes, work-clock advancement, revisions, acceptance, invoices/payment and existing personal living costs. No operating income injected. Uncollected invoiced receivables remain distinct from cash.","strategies":grouped,"runs":rows,"failures":failures},"\t"))
	print("WORKFLOWS BALANCE: %d runs x 120 days, %d failures" % [rows.size(), failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
func simulate(strategy: String, seed_value: int) -> void:
	GameState.new_game({"name":"Consulting QA","seed":seed_value})
	Clock.clear_pauses()
	Clock.world_active = false
	GameState.data["tutorial"] = {"v":3,"off":true,"seen":{}}
	Careers.start_freelance()
	var start := Clock.now()
	var losing_days := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for day in 120:
		var before := profit()
		Clock.advance_to(Clock.at_day_time(1, 8 * 60))
		Careers.refresh_offers()
		if Careers.active_gigs().is_empty() and not Careers.F()["offers"].is_empty(): Careers.accept(Careers.F()["offers"][0]["id"])
		var chance := 0.12 if strategy == "normal" else (0.08 if strategy == "conservative" else 0.35)
		if rng.randf() >= chance:
			for guard in 12:
				var active := Careers.active_gigs()
				if active.is_empty(): break
				var g: Dictionary = active[0]
				var id: String = g["id"]
				match FreelanceWorkflow.stage(g):
					"interview":
						for topic in ["goal","audience","budget"].slice(0, 1 if strategy == "aggressive" else 3): FreelanceWorkflow.ask(id, topic)
						FreelanceWorkflow.prepare_proposal(id)
					"proposal": FreelanceWorkflow.propose(id, 0.8 if strategy == "conservative" else 1.0, 0 if strategy == "aggressive" else 1)
					"work", "revision_work":
						var q := 0.9 if strategy == "normal" else (0.8 if strategy == "conservative" else 0.45)
						if rng.randf() < 0.12: q = 0.2
						var result := FreelanceWorkflow.work(id, 2.0, q)
						if not result["ok"]: break
					"scope": FreelanceWorkflow.scope(id, strategy != "conservative")
					"delivery": FreelanceWorkflow.deliver(id)
					"revision":
						if strategy == "aggressive": FreelanceWorkflow.accept_delivery(id, true)
						else: FreelanceWorkflow.revise(id, false)
					"acceptance": FreelanceWorkflow.accept_delivery(id)
					"failed": FreelanceWorkflow.accept_delivery(id, true)
		if profit() - before < -0.01: losing_days += 1
	var expense := 0.0
	for category in Ledger.EXPENSE_CATEGORIES: expense += Ledger.balance("player", "exp:" + category)
	var invoices := -Ledger.balance("player", "revenue")
	var gigs: Array = Careers.F()["gigs"].values()
	rows.append({"strategy":strategy,"seed":seed_value,"elapsed_minutes":Clock.now()-start,"profit":snappedf(profit(),0.01),"consulting_profit":invoices,"shared_profit":-expense,"revenue":invoices,"expenses":expense,"receivables":Ledger.balance("player","accounts_receivable"),"cash":Ledger.cash("player"),"accepted":gigs.size(),"invoiced_or_paid":gigs.filter(func(g):return g["status"] in ["invoiced","paid"]).size(),"cancelled":gigs.filter(func(g):return g["status"]=="cancelled").size(),"losing_days":losing_days,"reputation":Careers.rep(),"balanced":Ledger.check_balanced()})
