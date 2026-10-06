extends Node
## Actual delivery transactions for 120 days, three policies and three disclosed pricing scenarios.
var rows: Array=[]
func _ready() -> void:call_deferred("run")
func run() -> void:
	for strategy in ["conservative","normal","aggressive"]:
		for scenario in ["baseline","mild","stress"]:simulate(strategy,scenario)
	var grouped: Dictionary={}
	for strategy in ["conservative","normal","aggressive"]:
		var sum:=0.0;var losses:=0
		for row in rows:
			if row["strategy"]==strategy:sum+=float(row["profit"]);losses+=1 if float(row["profit"])<0 else 0
		grouped[strategy]={"mean_profit_dollars":snappedf(sum/3,.01),"losses":losses}
	var failures: Array=[]
	if not grouped.values().any(func(g):return float(g["mean_profit_dollars"])>0):failures.append("No reasonable strategy profits on average")
	for strategy in grouped:
		if grouped[strategy]["losses"]==0:failures.append(strategy+" has no downside scenario")
	if not rows.all(func(r):return r["balanced"] and r["segment_sum_matches"]):failures.append("Ledger or segment totals mismatch")
	var out: String=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	var f:=FileAccess.open(out.path_join("logistics_balance_120.json"),FileAccess.WRITE)
	f.store_string(JSON.stringify({"days":120,"failures":failures,"scenarios":"baseline/mild/stress run pay per stop 20/18/8 dollars; route fees 110/100/45 dollars; randomized jobs and failures; no artificial receipts","strategies":grouped,"runs":rows},"\t"))
	print("LOGISTICS BALANCE ",grouped)
	get_tree().quit(0 if failures.is_empty() else 1)
func simulate(strategy: String,scenario: String) -> void:
	Clock.clear_pauses();Clock.world_active=false
	GameState.new_game({"name":"Fleet balance","seed":34001 if scenario=="baseline" else 34002 if scenario=="mild" else 34003})
	var rc: Dictionary=Logistics.cfg()["runs"]
	rc["pay_per_stop"]=20 if scenario=="baseline" else 18 if scenario=="mild" else 8
	Logistics.cfg()["delivery_routes"]["pay_run"]=110 if scenario=="baseline" else 100 if scenario=="mild" else 45
	Company.register("Fleet balance","logistics","Pier 7");Company.open_business_account(20000)
	var entity:=GameState.company_id()
	Ledger.post(entity,"QA equity",[{"acct":"cash","dr":40000},{"acct":"equity","cr":40000}],{"type":"qa_fixture"})
	var start:=Clock.now();Logistics.buy_van()
	if strategy!="conservative":recruit("van1")
	if strategy=="aggressive":LogisticsDepth.buy("new");recruit("van2")
	var id:=Contracts.create_offer({"type":"delivery_route","buyer":"bloom_coffee","place":"bloom_coffee"});Contracts.accept(id)
	var threshold:=65 if strategy=="conservative" else 50 if strategy=="normal" else 30
	while Clock.now()<start+120*Clock.DAY:
		var before:=Clock.now()
		for vehicle in LogisticsDepth.vehicles():
			if float(LogisticsDepth.vehicles()[vehicle]["condition"])<threshold and LogisticsDepth.available(vehicle):LogisticsDepth.service(vehicle)
		var available: Array=LogisticsDepth.vehicles().keys().filter(func(v):return LogisticsDepth.available(v))
		if not available.is_empty() and Clock.hour()>=10 and Clock.hour()<17:
			var jobs: Array=(Logistics.active_jobs()+Logistics.open_jobs()).filter(func(j):return Clock.now()+int(Logistics.route_stats(j["stops"],Logistics.best_order(j["stops"])["order"])["minutes"])<=int(j["by"]))
			jobs.sort_custom(func(a,b):return a.has("route") and not b.has("route") if a.has("route")!=b.has("route") else float(a["pay"])>float(b["pay"]))
			if not jobs.is_empty():
				var job: Dictionary=jobs[0]
				if job["status"]=="open":Logistics.accept(job["id"])
				Logistics.drive(job["id"],Logistics.best_order(job["stops"])["order"],available[0])
		if before==Clock.now():Clock.advance(60)
	var report:=Segments.compute(entity,start,Clock.now()+1)
	var total:=0.0
	for segment in report["rows"].values():total+=float(segment["operating_profit"])
	var profit:=float(report["totals"]["operating_profit"])
	rows.append({"strategy":strategy,"scenario":scenario,"profit":snappedf(profit,.01),"revenue_dollars":report["totals"]["net_revenue"],"balanced":Ledger.check_balanced(),"segment_sum_matches":absf(total-profit)<.01,"trips":GameState.stat("van_runs"),"balances":GameState.data["ledger"]["balances"][entity]})
	print("Completed ",strategy," ",scenario," profit ",profit," revenue ",report["totals"]["net_revenue"]," trips ",GameState.stat("van_runs"))
func recruit(vehicle: String) -> void:
	Staff.register_employer();Staff.post_job("driver");Clock.advance(19*60)
	if not Staff.S()["applicants"].is_empty():
		Staff.hire(Staff.S()["applicants"][0]["id"])
		LogisticsDepth.assign(Staff.people()[-1]["id"],vehicle)
