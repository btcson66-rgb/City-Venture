extends Node
## 120 simulated days across three strategies and three seeds; no operating income is injected.
var results: Array = []
var failures: Array = []
var out := ""
func _ready() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.substr(6)
	for strategy in ["conservative", "normal", "aggressive"]:
		for seed_value in [64001,64002,64003]: simulate(strategy, seed_value)
	var grouped := {}
	for strategy in ["conservative", "normal", "aggressive"]:
		var rows := results.filter(func(r): return r["strategy"] == strategy)
		var profits := rows.map(func(r): return r["operating_profit"])
		grouped[strategy] = {"min_profit":profits.min(), "max_profit":profits.max(), "losing_seeds":rows.filter(func(r): return float(r["operating_profit"]) < 0).size()}
		var mean: float = 0.0
		for p in profits: mean += float(p) / profits.size()
		grouped[strategy]["mean_profit"] = mean
		# Sensible play must pay on average; only the aggressive strategy has to show real downside.
		if strategy != "aggressive" and mean <= 0.0: failures.append(strategy+" does not profit on average")
		if strategy == "aggressive" and grouped[strategy]["losing_seeds"] == 0: failures.append(strategy+" has no observed downside")
	DirAccess.make_dir_recursive_absolute(out)
	var f := FileAccess.open(out+"/manufacturing_balance_120.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"days":120, "opening_capital":40000, "seeds":[64001,64002,64003], "strategies":grouped, "runs":results, "failures":failures}, "\t"))
	print("MANUFACTURING BALANCE: %d runs ×120 days; %d failures" % [results.size(),failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
func simulate(strategy: String, seed_value: int) -> void:
	Clock.clear_pauses()
	Clock.world_active = false
	GameState.new_game({"name":"Balance founder", "seed":seed_value})
	GameState.rng.seed = seed_value
	# Experimental opening endowment, explicitly equity, never operating income.
	Ledger.post("player", "QA starting equity", [{"acct":"cash", "dr":12000}, {"acct":"equity", "cr":12000}])
	Company.register("Balance OEM", "manufacturing", "Unit 12")
	Company.open_business_account(40000)
	Living.lease("unit12_factory")
	Manufacturing.start()
	Manufacturing.acquire_machine(true)
	Staff.register_employer()
	Manufacturing.hire_tomas()
	Manufacturing.set_inspection(1.0 if strategy == "conservative" else 0.5 if strategy == "normal" else 0.0)
	var entity := GameState.company_id()
	var t0 := Clock.now()
	var daily: Array = []
	var crises := 0
	var deliveries := 0
	for day in 120:
		Clock.advance_to(Clock.at_day_time(0, 8*60))
		# Apply the actual queued crisis choice; leave unrelated legacy events unchosen.
		for queued in EventEngine.S()["queue"].duplicate():
			if str(queued["id"]).begins_with("manufacturing_"):
				var definition: Dictionary = DataDB.events[queued["id"]]
				EventEngine.choose(queued["iid"], definition["choices"][0]["id"])
				crises += 1
		if not Manufacturing.valid(): break
		if strategy != "aggressive" and Staff.count("technician") == 0: Manufacturing.hire_tomas()
		if strategy == "normal" and Ledger.cash(entity) < 6000:
			var loan := Bank.offer()
			if loan["ok"]: Bank.take_loan(minf(float(loan["max"]), 12000), 24)
		var machine := str(Manufacturing.S()["machines"][0])
		var asset: Dictionary = Assets.S()["items"][machine]
		# The aggressive player skips preventive maintenance and only repairs once the machine has actually broken.
		if asset["status"] == "broken" or (strategy != "aggressive" and asset.get("maintenance_due", false)): Assets.maintain(machine)
		if Clock.weekday() == 1:
			var accepted := 0
			for rfq in Manufacturing.S()["rfqs"].values():
				if rfq["status"] != "open" or int(rfq["due"]) <= Clock.now(): continue
				if accepted >= (2 if strategy == "conservative" else 3): break
				# Quote position inside the client's band: the floor always wins, the ceiling wins least often.
				var band := 0.0 if strategy == "conservative" else 0.4 if strategy == "normal" else 1.0
				var price := lerpf(float(rfq["min_price"]), float(rfq["max_price"]), band)
				if Manufacturing.quote(rfq["id"], price)["ok"]: accepted += 1
		var pending := 0
		for po in Manufacturing.S()["pos"].values():
			if po["status"] == "transit": pending += int(po["qty"])
		if Manufacturing.material_units()+pending < 1800: Manufacturing.order_material(4000 if strategy != "conservative" else 3000)
		var overtime := strategy == "aggressive"
		if overtime or Clock.weekday() in [1,2,3,4,5]:
			for order in Manufacturing.S()["orders"].values():
				if order["status"] == "active" and int(order["produced"]) < int(order["qty"]):
					Manufacturing.plan(order["job"], machine, Clock.at_day_time(0, 9*60), 16 if overtime else 8, overtime)
					break
		Clock.advance_to(Clock.at_day_time(1, 7*60))
		for order in Manufacturing.S()["orders"].values():
			if order["status"] == "active" and int(order["produced"]) >= int(order["qty"]):
				if Manufacturing.deliver(order["job"])["ok"]: deliveries += 1
		var report := Segments.compute(entity, t0, Clock.now()+1)
		var total := MonthClose.compute(entity, t0, Clock.now()+1)
		if not Ledger.check_balanced() or absf(float(report["totals"]["operating_profit"])-float(total["business_profit"])) > 0.011: failures.append("ledger/segments mismatch %s/%d/day%d" % [strategy,seed_value,day])
		daily.append({"day":day+1, "cash":Ledger.cash(entity), "profit":total["business_profit"], "ar":Ledger.balance(entity,"accounts_receivable"), "credit":Bank.credit(), "raw_units":Manufacturing.material_units()})
	var report := MonthClose.compute(entity, t0, Clock.now()+1)
	results.append({"strategy":strategy,"seed":seed_value,"days":daily.size(),"operating_profit":report["business_profit"],"revenue":report["net_revenue"],"gross_profit":report["gross_profit"],"closing_cash":Ledger.cash(entity),"deliveries":deliveries,"crises":crises,"balanced":Ledger.check_balanced(),"daily":daily})
	print("BALANCE %s/%d: %d deliveries, %d crises, profit %.2f" % [strategy,seed_value,deliveries,crises,report["business_profit"]])
