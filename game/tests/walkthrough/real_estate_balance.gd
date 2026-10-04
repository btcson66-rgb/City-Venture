extends Node
## All 120-day outcomes retained across five seeds; starting capital is equity, never operating revenue.
var out := ""
var runs: Array=[]
var failures: Array=[]
func _ready() -> void:call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.substr(6)
	for strategy in ["conservative","normal","aggressive"]:
		for seed_value in [65001,65002,65003,65004,65005]:simulate(strategy,seed_value)
	var grouped := {}
	for strategy in ["conservative","normal","aggressive"]:
		var rows := runs.filter(func(r):return r["strategy"]==strategy)
		var profits := rows.map(func(r):return r["operating_profit"])
		grouped[strategy]={"min_profit":profits.min(),"max_profit":profits.max(),"losing_seeds":rows.filter(func(r):return float(r["operating_profit"])<0).size()}
		if grouped[strategy]["losing_seeds"]==0:failures.append(strategy+" has no observed downside")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out+"/real_estate_balance_120.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"days":120,"opening_capital":120000,"seeds":[65001,65002,65003,65004,65005],"strategies":grouped,"runs":runs,"failures":failures},"\t"))
	print("REAL ESTATE BALANCE: %d runs ×120 days; %d failures"%[runs.size(),failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
func simulate(strategy: String,seed_value: int) -> void:
	Clock.clear_pauses()
	Clock.world_active=false
	GameState.new_game({"name":"Balance realty","seed":seed_value})
	GameState.rng.seed=seed_value
	Company.register("Balance realty","real_estate","Harlow")
	Company.open_business_account(25000)
	Ledger.post(GameState.company_id(),"QA starting equity",[{"acct":"cash","dr":95000},{"acct":"equity","cr":95000}])
	var entity := GameState.company_id()
	var t0 := Clock.now()
	var daily: Array=[]
	Compliance.apply_permit("brokerage")
	for setup_day in 3:
		Clock.advance(Clock.DAY)
		var setup_company := MonthClose.compute(entity,t0,Clock.now()+1)
		var setup_segments := Segments.compute(entity,t0,Clock.now()+1)
		if not Ledger.check_balanced() or absf(float(setup_segments["totals"]["operating_profit"])-float(setup_company["business_profit"]))>.011:failures.append("setup ledger/segment mismatch")
		daily.append({"day":Clock.day_index(),"cash":Ledger.cash(entity),"profit":setup_company["business_profit"],"ar":Ledger.balance(entity,"accounts_receivable"),"mortgage_debt":Bank.debt(entity),"market_index":RealEstateMarket.index(),"property_equity":RealEstate.equity(),"credit":Bank.credit()})
	Living.lease("realty_office")
	RealEstate.start()
	if strategy!="conservative":
		RealEstate.buy("maple_1",.2,25)
		RealEstate.list_rental("maple_1",1.0 if strategy=="normal" else 1.4,650 if strategy=="normal" else 450)
		if strategy=="aggressive":RealEstate.buy("maple_2",.2,30);RealEstate.list_rental("maple_2",1.4,450)
	var crises := 0
	var last_week := -1
	while Clock.now()<t0+120*Clock.DAY:
		for event in EventEngine.S()["queue"].duplicate():
			if str(event["id"]).begins_with("real_estate_"):
				if EventEngine.choose(event["iid"],"respond")["ok"]:crises+=1
		var week := Clock.day_index()/7
		if week!=last_week:
			last_week=week
			for mandate in RealEstate.S()["mandates"].values().duplicate():
				if mandate["status"]!="open":continue
				for client in RealEstate.S()["clients"].values().duplicate():
					if client["status"]!="open" or client["kind"]!=mandate["kind"] or float(client["budget"])<float(mandate["floor"]):continue
					RealEstate.viewing(mandate["id"],client["id"],"hard" if strategy=="conservative" else "balanced" if strategy=="normal" else "soft")
					if mandate["status"]=="closed":break
		Clock.advance_to(mini(t0+120*Clock.DAY,Clock.at_day_time(1,7*60)))
		var company := MonthClose.compute(entity,t0,Clock.now()+1)
		var segments := Segments.compute(entity,t0,Clock.now()+1)
		if not Ledger.check_balanced() or absf(float(segments["totals"]["operating_profit"])-float(company["business_profit"]))>.011:failures.append("ledger/segment mismatch %s/%d/day%d"%[strategy,seed_value,daily.size()+1])
		daily.append({"day":Clock.day_index(),"cash":Ledger.cash(entity),"profit":company["business_profit"],"ar":Ledger.balance(entity,"accounts_receivable"),"mortgage_debt":Bank.debt(entity),"market_index":RealEstateMarket.index(),"property_equity":RealEstate.equity(),"credit":Bank.credit()})
	var company := MonthClose.compute(entity,t0,Clock.now()+1)
	runs.append({"strategy":strategy,"seed":seed_value,"duration_days":120,"daily_records":daily.size(),"operating_profit":company["business_profit"],"revenue":company["net_revenue"],"closing_cash":Ledger.cash(entity),"matches":GameState.stat("realty_matches"),"crises":crises,"balanced":Ledger.check_balanced(),"daily":daily})
	print("BALANCE %s/%d: %d deals, %d crises, profit %.2f"%[strategy,seed_value,int(GameState.stat("realty_matches")),crises,float(company["business_profit"])])
