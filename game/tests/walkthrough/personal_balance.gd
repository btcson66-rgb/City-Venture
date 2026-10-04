extends Node
var out := ""
var rows: Array=[]
var failures: Array=[]
func _ready() -> void:call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.substr(6)
	for strategy in ["careful","normal","reckless"]:
		for seed_value in [96001,96002,96003,96004,96005]:simulate(strategy,seed_value)
	var grouped := {}
	for strategy in ["careful","normal","reckless"]:
		var selected := rows.filter(func(r):return r["strategy"]==strategy)
		var profits := selected.map(func(r):return r["profit_aud"])
		var sum := 0.0
		for profit in profits:sum+=float(profit)
		grouped[strategy]={"average_profit_aud":sum/selected.size(),"min_profit_aud":profits.min(),"max_profit_aud":profits.max(),"losing_seeds":selected.filter(func(r):return float(r["profit_aud"])<0).size()}
	if float(grouped["normal"]["average_profit_aud"])<=0:failures.append("normal strategy does not profit on average")
	if int(grouped["reckless"]["losing_seeds"])==0:failures.append("no observed risky-strategy loss")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out+"/personal_balance_120.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"days":120,"opening_capital_aud":20000,"strategies":grouped,"runs":rows,"failures":failures,"scope":"120 calendar days: paid service Jobs plus five contacts, actual personal requests, referral supplies and invoices, daily energy/work, recovery and rest. Explicit 2.5% or 20% nonpayment risk means positive observations are not guarantees."},"\t"))
	print("PERSONAL BALANCE: %d runs; %d failures"%[rows.size(),failures.size()])
	get_tree().quit(0 if failures.is_empty() else 1)
func simulate(strategy: String,seed_value: int) -> void:
	Clock.clear_pauses();Clock.world_active=false
	GameState.new_game({"name":"Balance service","seed":seed_value});GameState.rng.seed=seed_value
	Company.register("Balance service","consulting","22 Founders Lane");Company.open_business_account(20000)
	var entity := GameState.company_id();var t0 := Clock.now()
	var trades := 0;var disputes := 0;var filings := 0
	var referrals := 0;var illnesses := 0;var player_t0 := Ledger.cash("player")
	for npc in ["maya","priya","nina","sam","ken"]:PersonalLife.meet(npc)
	for day in range(120):
		for npc in ["maya","priya","nina","sam","ken"]:
			if day<3:
				var n := PersonalLife.next(npc)
				if n["ok"]:PersonalLife.request_done(npc,int(PersonalLife.contact(npc)["step"]),.25 if strategy=="reckless" else 1.0)
			elif day==3 and int(PersonalLife.contact(npc)["step"])==3:
				var offer := PersonalLife.referral(npc)
				if offer["ok"]:
					Jobs.accept(offer["id"])
					if PersonalLife.referral_work(npc,1)["ok"]:referrals+=1
		PersonalLife.work(240 if strategy=="reckless" else 120)
		if PersonalLife.ill():
			illnesses+=1
			if strategy!="reckless":PersonalLife.recover(false)
		if strategy!="reckless":
			PersonalLife.sleep_begin();Clock.advance(480);PersonalLife.sleep_end(480)
		for c in Legal.cases(entity):
			if c["status"]=="open":
				if Legal.choose(str(c["id"]),"court" if strategy=="reckless" else "settle")["ok"]:disputes+=1
		if strategy!="reckless":
			for r in Tax.returns(entity):
				if r["status"]=="due" and Tax.file(entity,str(r["id"]),"accountant")["ok"]:filings+=1
		var cost := 130.0 if strategy=="careful" else 200.0 if strategy=="normal" else 450.0
		var price := 210.0 if strategy=="careful" else 420.0 if strategy=="normal" else 525.0
		if Ledger.cash(entity)>=cost:
			var job := Jobs.offer({"entity":entity,"client":"Repeat buyer %d"%(day%7),"scope":"Daily commissioned service","segment":"consulting","price":price,"terms":0,"payment_risk":.20 if strategy=="reckless" else .025})
			Jobs.accept(job);Ledger.expense(entity,"other",cost,"Paid subcontracted work",{"type":"job_cost","id":job,"segment":"consulting"});Jobs.progress(job,1);Jobs.deliver(job);Jobs.invoice(job);trades+=1
		Clock.advance_to(maxi(Clock.now(),t0+(day+1)*Clock.DAY))
		if not Ledger.check_balanced():failures.append("unbalanced ledger")
	var report := Segments.compute(entity,t0,Clock.now()+1)
	rows.append({"strategy":strategy,"seed":seed_value,"days":120,"profit_aud":report["totals"]["operating_profit"],"cash_aud":Ledger.cash(entity),"trades":trades,"disputes":disputes,"filings":filings,"tax_payable_aud":-Ledger.balance(entity,"tax_payable"),"balanced":Ledger.check_balanced(),"referrals":referrals,"illness_days_observed":illnesses,"final_energy_percent":PersonalLife.energy(),"final_stress_percent":PersonalLife.S()["stress"],"elapsed_calendar_days":float(Clock.now()-t0)/Clock.DAY,"personal_cash_change_aud":Ledger.cash("player")-player_t0})
	print("BALANCE %s/%d %.2f AUD"%[strategy,seed_value,float(report["totals"]["operating_profit"])])
