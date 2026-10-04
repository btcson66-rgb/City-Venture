extends Node
## 120-day Aster Inn simulation: three operating strategies x three seeds. Usage:
##   godot --headless --path game res://tests/walkthrough/hotel_balance.tscn? (see tools/qa/hotel_balance.gd) -- --out=<dir>
var out := ""
var runs: Array=[]
var failures: Array=[]
const PROFILES := {
	"conservative":{"mode":"lease","price_bias":0.9,"dynamic":true,"ota_allot":0.5,"tier":"standard","overbook":0.0,"housekeepers":2,"desk":1,"blocks":"offpeak","renovate":false,"expand":false,"temp":false,"crisis":"cheap","capital":175000},
	"normal":{"mode":"own","price_bias":1.06,"dynamic":true,"ota_allot":0.5,"tier":"standard","overbook":0.04,"housekeepers":2,"desk":1,"blocks":"offpeak","renovate":true,"expand":true,"temp":true,"crisis":"fix","capital":175000},
	"aggressive":{"mode":"own","price_bias":1.22,"dynamic":true,"ota_allot":0.3,"tier":"featured","overbook":0.10,"housekeepers":1,"desk":0,"blocks":"all","renovate":false,"expand":true,"temp":false,"crisis":"cheap","capital":395000}}
func _ready() -> void:call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.substr(6)
	for strategy in PROFILES:
		for seed_value in [67001,67002,67003]:simulate(strategy,seed_value)
	var grouped := {}
	for strategy in PROFILES:
		var rows := runs.filter(func(r):return r["strategy"]==strategy)
		var profits := rows.map(func(r):return r["operating_profit"])
		var total := 0.0
		for value in profits:total+=float(value)
		grouped[strategy]={"min_profit":profits.min(),"max_profit":profits.max(),"mean_profit":snappedf(total/profits.size(),.01),"losing_seeds":rows.filter(func(r):return float(r["operating_profit"])<0).size(),"worst_30_day_profit":rows.map(func(r):return float(r["worst_30_day_profit"])).min(),
			"mean_occupancy":snappedf(rows.map(func(r):return float(r["occupancy"])).reduce(func(a,b):return a+b)/rows.size(),.001),"mean_rating":snappedf(rows.map(func(r):return float(r["rating"])).reduce(func(a,b):return a+b)/rows.size(),.01)}
	var profitable := false
	for strategy in grouped:
		if float(grouped[strategy]["mean_profit"])>0:profitable=true
		if int(grouped[strategy]["losing_seeds"])==0 and float(grouped[strategy]["worst_30_day_profit"])>=0:failures.append(strategy+" has no observed downside")
	if not profitable:failures.append("no strategy is profitable on average")
	DirAccess.make_dir_recursive_absolute(out)
	var file := FileAccess.open(out+"/hotel_balance_120.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"days":120,"opening_capital":"200000 (aggressive 420000)","strategies":grouped,"runs":runs,"failures":failures},"\t"))
	file.close()
	var lines := ["strategy,seed,operating_profit,revenue,closing_cash,occupancy,adr,rating,walks,crises,stage,worst_30_day_profit"]
	for r in runs:lines.append("%s,%d,%.2f,%.2f,%.2f,%.3f,%.2f,%.2f,%d,%d,%d,%.2f"%[r["strategy"],r["seed"],r["operating_profit"],r["revenue"],r["closing_cash"],r["occupancy"],r["adr"],r["rating"],r["walks"],r["crises"],r["stage"],r["worst_30_day_profit"]])
	for strategy in grouped:lines.append("# %s mean %.2f min %.2f max %.2f losing %d worst30d %.2f occupancy %.3f rating %.2f"%[strategy,grouped[strategy]["mean_profit"],grouped[strategy]["min_profit"],grouped[strategy]["max_profit"],grouped[strategy]["losing_seeds"],grouped[strategy]["worst_30_day_profit"],grouped[strategy]["mean_occupancy"],grouped[strategy]["mean_rating"]])
	var csv := FileAccess.open(out+"/hotel_balance_120.csv",FileAccess.WRITE)
	csv.store_string("\n".join(lines)+"\n")
	csv.close()
	print("HOTEL BALANCE: %d runs x120 days; %d failures"%[runs.size(),failures.size()])
	for failure in failures:print("  FAIL "+str(failure))
	for line in lines:print(line)
	get_tree().quit(0 if failures.is_empty() else 1)
func recruit(role: String) -> void:
	if Staff.post_job(role).get("ok",false):
		Clock.advance(18*60)
		if not Staff.S()["applicants"].is_empty():Staff.hire(Staff.S()["applicants"][0]["id"])
func staff_to(profile: Dictionary) -> void:
	if not Staff.employer_registered():Staff.register_employer()
	while Staff.count("housekeeper")<int(profile["housekeepers"]) and Staff.count()<12:
		var before := Staff.count()
		recruit("housekeeper")
		if Staff.count()==before:break
	while Staff.count("front_desk")<int(profile["desk"]) and Staff.count()<12:
		var before := Staff.count()
		recruit("front_desk")
		if Staff.count()==before:break
func set_prices(profile: Dictionary) -> void:
	var tomorrow := Clock.day_index()+1
	var index := Hotel.demand_index(tomorrow)
	for type in Hotel.TYPES:
		var ref := float(Hotel.cfg()["types"][type]["ref_price"])
		var bias := float(profile["price_bias"])
		var factor := bias*(0.85+0.3*clampf(index,.7,1.8)) if profile["dynamic"] else bias
		var t: Dictionary=Hotel.cfg()["types"][type]
		Hotel.set_price(type,clampf(snappedf(ref*factor,1.0),float(t["min_price"]),float(t["max_price"])))
func simulate(strategy: String,seed_value: int) -> void:
	var profile: Dictionary=PROFILES[strategy]
	Clock.clear_pauses()
	Clock.world_active=false
	GameState.new_game({"name":"Balance hotel","seed":seed_value})
	GameState.rng.seed=seed_value
	Company.register("Balance hotel","hotel","The Aster")
	Company.open_business_account(25000)
	Ledger.post(GameState.company_id(),"QA starting equity",[{"acct":"cash","dr":float(profile["capital"])},{"acct":"equity","cr":float(profile["capital"])}])
	GameState.mark_visited("the_aster")
	var entity := GameState.company_id()
	var t0 := Clock.now()
	var opened := Hotel.start(str(profile["mode"]))
	if not opened["ok"]:failures.append("%s/%d could not open: %s"%[strategy,seed_value,str(opened.get("error",""))])
	staff_to(profile)
	Hotel.set_channels(true,str(profile["tier"]),float(profile["ota_allot"]))
	Hotel.set_overbook(float(profile["overbook"]))
	Hotel.set_temp(bool(profile["temp"]))
	var crises := 0
	var mismatch := false
	var profit_track: Array=[]
	for day in 120:
		for event in EventEngine.S()["queue"].duplicate():
			if not str(event["id"]).begins_with("hotel_"):continue
			var choice: String=event["id"].replace("hotel_","")
			var pick: String={"slump":"promo" if profile["crisis"]=="fix" else "wait","review_storm":"respond" if profile["crisis"]=="fix" else "ignore","equipment_failure":"fast" if profile["crisis"]=="fix" else "slow","event_cancelled":"promo" if profile["crisis"]=="fix" else "accept","strike":"raise" if profile["crisis"]=="fix" else "hold","vera_visit":"vip" if profile["crisis"]=="fix" else "normal"}[choice]
			if EventEngine.choose(event["iid"],pick).get("ok",false):crises+=1
			else:EventEngine.choose(event["iid"],{"slump":"wait","review_storm":"ignore","equipment_failure":"slow","event_cancelled":"accept","strike":"hold","vera_visit":"normal"}[choice])
		if Hotel.is_running():
			if profile["dynamic"] or day==0:set_prices(profile)
			for type in Hotel.TYPES:
				if Hotel.type_issues(type)["broken"] or (Hotel.type_issues(type)["due"] and Ledger.cash(entity)>5000):Hotel.maintain(type)
				if profile["renovate"] and float(Hotel.S()["rooms"][type]["cond"])<48 and Ledger.cash(entity)>Hotel.renovation_cost(type)+30000 and Hotel.S()["blocks"].values().filter(func(b):return b["type"]==type and b["status"]=="locked").is_empty():Hotel.renovate(type)
			for b in Hotel.open_blocks():
				var peak: bool=float(Hotel.demand_index(int(b["start"])))>=1.5
				if profile["blocks"]=="all" or not peak:Hotel.accept_block(b["id"])
			if profile["expand"] and Hotel.stage()<3 and Ledger.cash(entity)>Hotel.upgrade_price(Hotel.stage()+1)+20000:
				if Hotel.gate(Hotel.stage()+1).all(func(r):return r[0]):
					Hotel.upgrade()
					staff_to({"housekeepers":Staff.count("housekeeper")+1,"desk":Staff.count("front_desk")})
			if day%30==15 and Hotel.stage()>=2 and Staff.count("housekeeper")<int(profile["housekeepers"])+Hotel.stage():staff_to({"housekeepers":Staff.count("housekeeper")+1,"desk":int(profile["desk"])+(1 if Hotel.stage()>=2 else 0)})
		Clock.advance_to(Clock.at_day_time(1,7*60))
		if day%10==9:
			var company := MonthClose.compute(entity,t0,Clock.now()+1)
			var segments := Segments.compute(entity,t0,Clock.now()+1)
			if not Ledger.check_balanced() or absf(float(segments["totals"]["operating_profit"])-float(company["business_profit"]))>.011:mismatch=true
			profit_track.append(float(company["business_profit"]))
	if mismatch:failures.append("%s/%d ledger/segment mismatch"%[strategy,seed_value])
	var company := MonthClose.compute(entity,t0,Clock.now()+1)
	var info := Hotel.stats(120)
	var worst_window := 0.0
	for i in profit_track.size():
		var base := float(profit_track[i-3]) if i>=3 else 0.0
		worst_window=minf(worst_window,float(profit_track[i])-base)
	runs.append({"strategy":strategy,"worst_30_day_profit":snappedf(worst_window,.01),"seed":seed_value,"duration_days":120,"operating_profit":snappedf(float(company["business_profit"]),.01),"revenue":snappedf(float(company["net_revenue"]),.01),"closing_cash":snappedf(Ledger.cash(entity),.01),
		"occupancy":snappedf(float(info["occupancy"]),.001),"adr":snappedf(float(info["adr"]),.01),"rating":Hotel.rating(),"walks":int(Hotel.S()["stats"]["walks"]),"crises":crises,"stage":Hotel.stage(),"rooms":Hotel.total_rooms(),
		"ar":snappedf(Ledger.balance(entity,"accounts_receivable"),.01),"balanced":Ledger.check_balanced()})
	print("BALANCE %s/%d: profit %.2f occupancy %.2f rating %.2f"%[strategy,seed_value,float(company["business_profit"]),float(info["occupancy"]),Hotel.rating()])
