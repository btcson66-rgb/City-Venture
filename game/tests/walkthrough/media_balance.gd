extends Node
var out := ""
var runs: Array=[]
var failures: Array=[]
func _ready() -> void:call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.substr(6)
	for strategy in ["conservative","normal","aggressive"]:
		for seed_value in [66001,66002,66003,66004,66005]:simulate(strategy,seed_value)
	var grouped := {}
	for strategy in ["conservative","normal","aggressive"]:
		var rows := runs.filter(func(r):return r["strategy"]==strategy)
		var profits := rows.map(func(r):return r["operating_profit"])
		grouped[strategy]={"min_profit":profits.min(),"max_profit":profits.max(),"losing_seeds":rows.filter(func(r):return float(r["operating_profit"])<0).size()}
		if grouped[strategy]["losing_seeds"]==0:failures.append(strategy+" has no observed downside")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out+"/media_balance_120.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"days":120,"opening_capital":60000,"strategies":grouped,"runs":runs,"failures":failures},"\t"))
	print("MEDIA BALANCE: %d runs ×120 days; %d failures"%[runs.size(),failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
func recruit(role: String) -> void:
	if Staff.post_job(role).get("ok",false):
		Clock.advance(18*60)
		if not Staff.S()["applicants"].is_empty():Staff.hire(Staff.S()["applicants"][0]["id"])
func simulate(strategy: String,seed_value: int) -> void:
	Clock.clear_pauses()
	Clock.world_active=false
	GameState.new_game({"name":"Balance agency","seed":seed_value})
	GameState.rng.seed=seed_value
	Company.register("Balance agency","media","The Loft")
	Company.open_business_account(25000)
	Ledger.post(GameState.company_id(),"QA starting equity",[{"acct":"cash","dr":35000},{"acct":"equity","cr":35000}])
	var entity := GameState.company_id()
	var t0 := Clock.now()
	Living.lease("loft_office")
	Media.start()
	Staff.register_employer()
	if strategy=="conservative":recruit("media_intern")
	else:recruit("media_designer");recruit("media_buyer")
	var daily: Array=[]
	var crises := 0
	while Clock.now()<t0+120*Clock.DAY:
		for event in EventEngine.S()["queue"].duplicate():
			if str(event["id"]).begins_with("media_"):
				if EventEngine.choose(event["iid"],"continue" if event["id"]=="media_pr" and strategy=="aggressive" else "respond").get("ok",false):crises+=1
		for campaign in Media.occupied():
			if campaign["status"]=="paused":Media.resume(campaign["id"])
		for brief in Media.S()["briefs"].values().duplicate():
			if brief["status"]!="open" or Media.occupied().size()>=Media.capacity():continue
			if strategy=="conservative" and float(brief["budget"])>25000:continue
			Media.prepare(brief["id"],.55 if strategy=="conservative" else .85 if strategy=="normal" else 1)
			Media.propose(brief["id"])
		if strategy=="aggressive" and Media.stage()==2 and Ledger.cash(entity)>float(Media.cfg()["agency_asset_price"])+5000:Media.buy_radio()
		if not Media.S()["radio"].is_empty():
			for offer in Media.S()["radio"]["offers"].values():Media.sell_slot(offer["id"])
		Clock.advance_to(mini(t0+120*Clock.DAY,Clock.at_day_time(1,7*60)))
		var company := MonthClose.compute(entity,t0,Clock.now()+1)
		var segments := Segments.compute(entity,t0,Clock.now()+1)
		if not Ledger.check_balanced() or absf(float(segments["totals"]["operating_profit"])-float(company["business_profit"]))>.011:failures.append("ledger/segment mismatch")
		daily.append({"day":Clock.day_index(),"cash":Ledger.cash(entity),"profit":company["business_profit"],"reputation":Media.S()["reputation"],"campaigns":Media.S()["completed"],"ar":Ledger.balance(entity,"accounts_receivable")})
	var company := MonthClose.compute(entity,t0,Clock.now()+1)
	runs.append({"strategy":strategy,"seed":seed_value,"duration_days":120,"operating_profit":company["business_profit"],"revenue":company["net_revenue"],"closing_cash":Ledger.cash(entity),"campaigns":Media.S()["completed"],"crises":crises,"balanced":Ledger.check_balanced(),"daily":daily})
	print("BALANCE %s/%d: profit %.2f"%[strategy,seed_value,float(company["business_profit"])])
