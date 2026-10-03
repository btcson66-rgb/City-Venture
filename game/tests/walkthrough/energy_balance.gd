extends Node
## 120-day energy balance: three strategies x three seeds. Reports profit, installs, stations and downside.
var out := ""
var runs: Array = []
var failures: Array = []
const CHOICES := {
	"conservative": {"energy_shortage":"premium", "energy_typhoon":"honour", "energy_subsidy_cut":"rush", "energy_vandal":"secure", "energy_tariff":"hold", "energy_rule":"retrofit"},
	"normal": {"energy_shortage":"premium", "energy_typhoon":"honour", "energy_subsidy_cut":"accept", "energy_vandal":"repair", "energy_tariff":"pass", "energy_rule":"retrofit"},
	"aggressive": {"energy_shortage":"wait", "energy_typhoon":"triage", "energy_subsidy_cut":"accept", "energy_vandal":"repair", "energy_tariff":"pass", "energy_rule":"exempt"}}

func _ready() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.substr(6)
	for strategy in ["conservative", "normal", "aggressive"]:
		for seed_value in [69001, 69002, 69003]: simulate(strategy, seed_value)
	var grouped := {}
	for strategy in ["conservative", "normal", "aggressive"]:
		var rows := runs.filter(func(r): return r["strategy"] == strategy)
		var profits := rows.map(func(r): return r["operating_profit"])
		var total := 0.0
		for p in profits: total += float(p)
		grouped[strategy] = {"mean_profit":snappedf(total / profits.size(), 0.01), "min_profit":profits.min(), "max_profit":profits.max(), "losing_seeds":rows.filter(func(r): return float(r["operating_profit"]) < 0).size()}
	var any_profitable := false
	for strategy in grouped:
		if float(grouped[strategy]["mean_profit"]) > 0: any_profitable = true
		if grouped[strategy]["losing_seeds"] == 0 and float(grouped[strategy]["min_profit"]) > 0.5 * float(grouped[strategy]["mean_profit"]): failures.append(strategy + " looks risk-free")
	if not any_profitable: failures.append("no strategy is profitable on average")
	if out != "":
		DirAccess.make_dir_recursive_absolute(out)
		var file := FileAccess.open(out + "/energy_balance_120.json", FileAccess.WRITE)
		file.store_string(JSON.stringify({"days":120, "seeds":3, "strategies":grouped, "runs":runs, "failures":failures}, "\t"))
	print("ENERGY BALANCE: %d runs x120 days; %d failures" % [runs.size(), failures.size()])
	for strategy in grouped: print("  %s: mean %s min %s max %s losing %d/3" % [strategy, str(grouped[strategy]["mean_profit"]), str(grouped[strategy]["min_profit"]), str(grouped[strategy]["max_profit"]), grouped[strategy]["losing_seeds"]])
	for f in failures: print("  FAIL " + str(f))
	get_tree().quit(0 if failures.is_empty() else 1)
func recruit(role: String) -> void:
	if Staff.post_job(role).get("ok", false):
		Clock.advance(18 * 60)
		if not Staff.S()["applicants"].is_empty(): Staff.hire(Staff.S()["applicants"][0]["id"])
func simulate(strategy: String, seed_value: int) -> void:
	Clock.clear_pauses()
	Clock.world_active = false
	GameState.new_game({"name":"Balance solar", "seed":seed_value})
	GameState.rng.seed = seed_value
	Company.register("Balance solar", "energy", "Helio")
	Company.open_business_account(25000)
	Ledger.post(GameState.company_id(), "QA starting equity", [{"acct":"cash", "dr":35000}, {"acct":"equity", "cr":25000 + 10000}])
	var entity := GameState.company_id()
	var t0 := Clock.now()
	Living.lease("helio_warehouse")
	Energy.start()
	Staff.register_employer()
	if strategy == "normal": recruit("electrician")
	if strategy == "aggressive":
		recruit("electrician")
		recruit("electrician")
	var margin := 0.3 if strategy == "conservative" else 0.24 if strategy == "normal" else 0.18
	var installs := 0
	var crises := 0
	var quotes := 0
	while Clock.now() < t0 + 120 * Clock.DAY:
		for event in EventEngine.S()["queue"].duplicate():
			var id := str(event["id"])
			if id.begins_with("energy_") and EventEngine.choose(event["iid"], CHOICES[strategy][id]).get("ok", false): crises += 1
		for claim in Energy.claims_open():
			Energy.resolve_claim(claim["id"], strategy != "aggressive" or float(claim["cost"]) < 600)
		if strategy != "conservative" and not Energy.S()["storage_cert"] and int(Energy.S()["completed"]) >= 2: Energy.certify_storage()
		for lead in Energy.open_leads():
			if lead["kind"] == "own": continue
			if strategy == "conservative" and lead["kind"] != "home": continue
			if Ledger.cash(entity) < 14000 and strategy != "aggressive": continue
			Energy.auto_layout(lead["id"])
			var battery := 5.0 if Energy.S()["storage_cert"] and lead["kind"] != "home" else 0.0
			Energy.set_options(lead["id"], battery, margin, strategy != "conservative")
			quotes += 1
			Energy.quote(lead["id"])
		for inst in Energy.installs_in("contracted"): Energy.start_install(inst["id"])
		if strategy == "aggressive" and Energy.stage() >= 2:
			for spot_id in ["shop_garage", "fin_deck", "hub_lot", "riv_plaza", "fin_plaza"]:
				if Energy.open_stations().size() + Energy.S()["sites"].values().filter(func(s): return s["status"] == "building").size() >= 2: break
				if Energy.spot_taken(spot_id) or Ledger.cash(entity) < 12000: continue
				if Energy.S()["deals"].has(spot_id) or Energy.site_deal(spot_id, "share").get("signed", false): Energy.build_station(spot_id, "fast" if Ledger.cash(entity) > 50000 else "l2", false, Ledger.cash(entity) < 45000)
		for site in Energy.open_stations():
			var item: Dictionary = Assets.S()["items"][site["asset"]]
			if item["status"] != "working" or item.get("maintenance_due", false): Energy.maintain_station(site["spot"])
		Clock.advance_to(mini(t0 + 120 * Clock.DAY, Clock.at_day_time(1, 7 * 60)))
		var company := MonthClose.compute(entity, t0, Clock.now() + 1)
		var segments := Segments.compute(entity, t0, Clock.now() + 1)
		if not Ledger.check_balanced() or absf(float(segments["totals"]["operating_profit"]) - float(company["business_profit"])) > .011: failures.append("ledger/segment mismatch")
	var company := MonthClose.compute(entity, t0, Clock.now() + 1)
	installs = int(Energy.S()["completed"])
	runs.append({"strategy":strategy, "seed":seed_value, "duration_days":120, "operating_profit":company["business_profit"], "revenue":company["net_revenue"], "closing_cash":Ledger.cash(entity),
		"installs":installs, "quotes":quotes, "stations":Energy.open_stations().size(), "charging_revenue":snappedf(Energy.open_stations().reduce(func(a, s): return a + float(s["revenue"]), 0.0), 0.01),
		"claims":Energy.S()["claims"].size(), "crises":crises, "debt":Bank.debt(entity), "cogs":Ledger.balance(entity, "cogs"), "payroll":Ledger.balance(entity, "exp:payroll"), "interest":Ledger.balance(entity, "exp:interest"), "depreciation":Ledger.balance(entity, "exp:depreciation"), "maintenance":Ledger.balance(entity, "exp:maintenance"), "other":Ledger.balance(entity, "exp:other"), "penalties":Ledger.balance(entity, "exp:penalties"), "balanced":Ledger.check_balanced()})
	print("BALANCE %s/%d: profit %.2f installs %d stations %d" % [strategy, seed_value, float(company["business_profit"]), installs, Energy.open_stations().size()])
