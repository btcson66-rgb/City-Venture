extends Node
## 120-day auto desk simulation: three strategies x three seeds. Usage (see tools/qa/automotive_balance.gd):
##   godot --headless --path game --script ../tools/qa/automotive_balance.gd -- --out=<dir>
var out := ""
var runs: Array = []
var failures: Array = []
const PROFILES := {
	"conservative":{"flip_ceiling":0.77, "inspect":true, "recon":true, "list_ratio":1.02, "fleet":0, "fleet_class":"economy", "service":true, "insurance":"basic", "dealer":"", "crisis":"safe", "capital":60000},
	"normal":{"flip_ceiling":0.82, "inspect":true, "recon":true, "list_ratio":1.05, "fleet":10, "fleet_class":"economy", "service":true, "insurance":"basic", "dealer":"", "crisis":"safe", "capital":150000},
	"aggressive":{"flip_ceiling":0.97, "inspect":false, "recon":false, "list_ratio":1.25, "fleet":14, "fleet_class":"premium", "service":false, "insurance":"none", "dealer":"volt", "crisis":"risky", "capital":560000}}
func _ready() -> void: call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.substr(6)
	for strategy in PROFILES:
		for seed_value in [68001, 68002, 68003]: simulate(strategy, seed_value)
	var grouped := {}
	for strategy in PROFILES:
		var rows := runs.filter(func(r): return r["strategy"] == strategy)
		var profits := rows.map(func(r): return r["operating_profit"])
		var total := 0.0
		for value in profits: total += float(value)
		grouped[strategy] = {"min_profit":profits.min(), "max_profit":profits.max(), "mean_profit":snappedf(total / profits.size(), .01), "losing_seeds":rows.filter(func(r): return float(r["operating_profit"]) < 0).size(),
			"worst_30_day_profit":rows.map(func(r): return float(r["worst_30_day_profit"])).min(),
			"mean_utilization":snappedf(rows.map(func(r): return float(r["utilization"])).reduce(func(a, b): return a + b) / rows.size(), .001)}
	var profitable := false
	for strategy in grouped:
		if float(grouped[strategy]["mean_profit"]) > 0: profitable = true
		if int(grouped[strategy]["losing_seeds"]) == 0 and float(grouped[strategy]["worst_30_day_profit"]) >= 0: failures.append(strategy + " has no observed downside")
	if not profitable: failures.append("no strategy is profitable on average")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out + "/automotive_balance_120.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"days":120, "strategies":grouped, "runs":runs, "failures":failures}, "\t"))
	file.close()
	var lines := ["strategy,seed,operating_profit,revenue,closing_cash,flips,fleet,utilization,breakdowns,claims,crises,stage,worst_30_day_profit"]
	for r in runs: lines.append("%s,%d,%.2f,%.2f,%.2f,%d,%d,%.3f,%d,%d,%d,%d,%.2f" % [r["strategy"], r["seed"], r["operating_profit"], r["revenue"], r["closing_cash"], r["flips"], r["fleet"], r["utilization"], r["breakdowns"], r["claims"], r["crises"], r["stage"], r["worst_30_day_profit"]])
	for strategy in grouped: lines.append("# %s mean %.2f min %.2f max %.2f losing %d worst30d %.2f utilization %.3f" % [strategy, grouped[strategy]["mean_profit"], grouped[strategy]["min_profit"], grouped[strategy]["max_profit"], grouped[strategy]["losing_seeds"], grouped[strategy]["worst_30_day_profit"], grouped[strategy]["mean_utilization"]])
	var csv := FileAccess.open(out + "/automotive_balance_120.csv", FileAccess.WRITE)
	csv.store_string("\n".join(lines) + "\n")
	csv.close()
	print("AUTOMOTIVE BALANCE: %d runs x120 days; %d failures" % [runs.size(), failures.size()])
	for failure in failures: print("  FAIL " + str(failure))
	for line in lines: print(line)
	get_tree().quit(0 if failures.is_empty() else 1)

func flip_day(profile: Dictionary) -> void:
	if not Automotive.auction_day(): return
	Automotive.refresh()
	for lot in Automotive.open_lots():
		if Automotive.stock_count() >= Automotive.slots(): break
		if profile["inspect"] and float(Automotive.visible_value(lot["car"])) > 5000: Automotive.inspect(lot["id"], false)
		var seen: float = Automotive.true_value(lot["car"]) if bool(lot["inspected"]) else Automotive.visible_value(lot["car"])
		Automotive.auction_auto(lot["id"], seen * float(profile["flip_ceiling"]))
func tend_stock(profile: Dictionary) -> void:
	for car in Automotive.S()["stock"].values().duplicate():
		if bool(car["new"]) or car["status"] == "shop": continue
		if profile["recon"] and car["status"] == "lot":
			var spec: Dictionary = Automotive.cfg()["defects"].get(str(car["defect"]), {})
			if str(car["defect"]) != "" and bool(car["known"]) and float(spec.get("fix", 0.0)) > float(car["fixed"]) and Automotive.recon(car["id"], "repair")["ok"]: continue
			if float(car["ext"]) < 0.85 and Automotive.recon(car["id"], "detail")["ok"]: continue
		if car["status"] == "lot":
			Automotive.list_car(car["id"], Automotive.market_value(car) * float(profile["list_ratio"]))
func fleet_to(profile: Dictionary) -> void:
	if int(profile["fleet"]) <= 0: return
	if not Living.has_lease("gateway_counter"): Living.lease("gateway_counter")
	while Automotive.fleet_cars().size() < int(profile["fleet"]):
		if not Automotive.buy_fleet(str(profile["fleet_class"]))["ok"]: break
func dealer_step(profile: Dictionary, entity: String) -> void:
	if str(profile["dealer"]) == "":return
	if not Automotive.dealership_active():
		if not Living.has_lease("gateway_showroom"): Living.lease("gateway_showroom")
		Automotive.sign_franchise(str(profile["dealer"]))
	elif Automotive.new_stock().size() + Automotive.incoming_count() < 4 and Ledger.cash(entity) > 100000:
		var brand: Dictionary = Automotive.brand_def()
		Automotive.order_new(str(brand["models"][0]["id"]), 3)
func crisis_pick(id: String, risky: bool) -> String:
	return {"automotive_claim":"claim_fight" if risky else "claim_pay", "automotive_flood":"flood_hide" if risky else "flood_disclose", "automotive_fuel":"fuel_hold" if risky else "fuel_cut", "automotive_recall":"recall_run" if risky else "recall_pull"}[id]
func simulate(strategy: String, seed_value: int) -> void:
	var profile: Dictionary = PROFILES[strategy]
	Clock.clear_pauses()
	Clock.world_active = false
	GameState.new_game({"name":"Balance auto", "seed":seed_value})
	GameState.rng.seed = seed_value
	Company.register("Balance auto", "automotive", "Gateway")
	Company.open_business_account(25000)
	Ledger.post(GameState.company_id(), "QA starting equity", [{"acct":"cash", "dr":float(profile["capital"])}, {"acct":"equity", "cr":float(profile["capital"])}])
	var entity := GameState.company_id()
	var t0 := Clock.now()
	var opened := Automotive.start()
	if not opened["ok"]: failures.append("%s/%d could not open: %s" % [strategy, seed_value, str(opened.get("error", ""))])
	Automotive.set_policy("insurance", str(profile["insurance"]))
	fleet_to(profile)
	var crises := 0
	var mismatch := false
	var profit_track: Array = []
	var flips := 0
	for day in 120:
		for event in EventEngine.S()["queue"].duplicate():
			if not str(event["id"]).begins_with("automotive_"): continue
			var risky: bool = profile["crisis"] == "risky"
			if EventEngine.choose(event["iid"], crisis_pick(str(event["id"]), risky)).get("ok", false): crises += 1
			else: EventEngine.choose(event["iid"], crisis_pick(str(event["id"]), not risky))
		if Automotive.is_running():
			if Automotive.auction_day(): Clock.advance(3 * 60)
			flip_day(profile)
			tend_stock(profile)
			if profile["service"]: Automotive.service_all_due()
			fleet_to(profile)
			if day % 10 == 3: dealer_step(profile, entity)
		Clock.advance_to(Clock.at_day_time(1, 7 * 60))
		if day % 10 == 9:
			var company := MonthClose.compute(entity, t0, Clock.now() + 1)
			var segments := Segments.compute(entity, t0, Clock.now() + 1)
			if not Ledger.check_balanced() or absf(float(segments["totals"]["operating_profit"]) - float(company["business_profit"])) > .011: mismatch = true
			profit_track.append(float(company["business_profit"]))
	if mismatch: failures.append("%s/%d ledger/segment mismatch" % [strategy, seed_value])
	var company := MonthClose.compute(entity, t0, Clock.now() + 1)
	var worst_window := 0.0
	for i in profit_track.size():
		var base := float(profit_track[i - 3]) if i >= 3 else 0.0
		worst_window = minf(worst_window, float(profit_track[i]) - base)
	var breakdowns := 0
	for id in Automotive.S()["fleet"]: breakdowns += int(Automotive.S()["fleet"][id]["breakdowns"])
	runs.append({"strategy":strategy, "seed":seed_value, "duration_days":120, "worst_30_day_profit":snappedf(worst_window, .01), "operating_profit":snappedf(float(company["business_profit"]), .01),
		"revenue":snappedf(float(company["net_revenue"]), .01), "closing_cash":snappedf(Ledger.cash(entity), .01), "flips":int(Automotive.S()["sold_count"]), "fleet":Automotive.fleet_cars().size(),
		"utilization":snappedf(Automotive.utilization(), .001), "breakdowns":breakdowns, "claims":int(Automotive.S()["claims"]), "crises":crises, "stage":Automotive.stage(), "balanced":Ledger.check_balanced()})
	print("BALANCE %s/%d: profit %.2f util %.2f" % [strategy, seed_value, float(company["business_profit"]), Automotive.utilization()])
