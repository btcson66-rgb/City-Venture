extends Node
var runs: Array=[]
var failures: Array=[]
var out: String=""
func _ready() -> void:call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.substr(6)
	for strategy in ["conservative","normal","aggressive"]:
		for seed_value in [70001,70002,70003]:simulate(strategy,seed_value)
	var grouped: Dictionary={}
	var profitable:=false
	for strategy in ["conservative","normal","aggressive"]:
		var rows: Array=runs.filter(func(r):return r["strategy"]==strategy)
		var total:=0.0
		for row in rows:total+=float(row["profit"])
		grouped[strategy]={"mean_profit_home_dollars":snappedf(total/rows.size(),.01),"losses":rows.filter(func(r):return float(r["profit"])<0).size(),"runs":rows.size()}
		if total>0:profitable=true
	if not profitable:failures.append("no sensible strategy profits on average")
	if out!="":
		DirAccess.make_dir_recursive_absolute(out)
		var file:=FileAccess.open(out+"/trade_balance_120.json",FileAccess.WRITE)
		file.store_string(JSON.stringify({"days":120,"strategies":grouped,"runs":runs,"failures":failures,"limits":"Three seeds do not establish a probability of loss. Every signed quote also records its feasible cargo/FX downside."},"\t"))
	print("TRADE BALANCE: ",JSON.stringify(grouped)," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)
func best_quote(strategy: String) -> Dictionary:
	var best: Dictionary={}
	for origin in DataDB.regions:
		for destination in DataDB.regions:
			if origin==destination:continue
			for product in TradeQuote.cfg()["goods"]:
				for markup in [.25,.4,.55,.7,.85]:
					var q:=TradeQuote.sheet(origin,destination,product,100 if strategy=="aggressive" else 50,"CIF" if strategy=="conservative" else ("FOB" if strategy=="normal" else "DDP"),"sea","lc" if strategy=="conservative" else ("tt_delivery" if strategy=="normal" else "open_account"),strategy!="aggressive",markup)
					if not q.get("ok",false) or float(q["margin"])<=0 or TradeIndustry.available(q)!="":continue
					if best.is_empty() or float(q["margin"])>float(best["margin"]):best=q
	return best
func simulate(strategy: String, seed_value: int) -> void:
	Clock.clear_pauses();Clock.world_active=false
	GameState.new_game({"name":"Trade balance","seed":seed_value});GameState.rng.seed=seed_value
	Company.register("Trade balance","international_trade","Meridian");Company.open_business_account(25000)
	Ledger.post(GameState.company_id(),"QA starting equity",[{"acct":"cash","dr":75000},{"acct":"equity","cr":75000}])
	var entity: String=GameState.company_id();var t0:=Clock.now()
	TradeIndustry.register();Living.lease("meridian_trade_office");TradeIndustry.start();GlobalMarket.open_bank()
	var signed:=0;var downside_quotes:=0;var crises:=0
	for day in 120:
		for d in TradeIndustry.S()["deals"].values():
			if d["status"]=="delayed":TradeIndustry.resolve_delay(d["id"],strategy=="aggressive")
			if d["quote"]["payment"]=="lc" and d["lc"]=="issued":TradeIndustry.bank_documents(d["id"])
		for event in EventEngine.pending().duplicate():
			if event["id"] in ["trade_port_strike","trade_fx_volatility"]:
				EventEngine.choose(event["iid"],"wait" if event["id"]=="trade_port_strike" else "spot");crises+=1
		var q:=best_quote(strategy)
		if not q.is_empty():
			var result:=TradeIndustry.sign(q)
			if result["ok"]:
				signed+=1
				if float(q["stress_margin"])<0:downside_quotes+=1
		Clock.advance(Clock.DAY)
		if not Ledger.check_balanced():failures.append("unbalanced actual ledger: "+strategy+"/"+str(seed_value))
	var pnl:=MonthClose.compute(entity,t0,Clock.now()+1)
	var segments:=Segments.compute(entity,t0,Clock.now()+1)
	if absf(float(segments["totals"]["operating_profit"])-float(pnl["business_profit"]))>.011:failures.append("segment mismatch")
	var losses: int=TradeIndustry.S()["deals"].values().filter(func(d):return d["status"] in ["lost","defaulted"]).size()
	runs.append({"strategy":strategy,"seed":seed_value,"days":120,"profit":pnl["business_profit"],"revenue":pnl["net_revenue"],"cash":Ledger.cash(entity),"signed":signed,"paid":TradeIndustry.S()["completed"],"cargo_or_credit_losses":losses,"downside_quotes":downside_quotes,"crises":crises,"balanced":Ledger.check_balanced()})
	print("TRADE RUN ",strategy,"/",seed_value,": ",pnl["business_profit"]," signed=",signed," losses=",losses)
