class_name LogisticsDepth
extends RefCounted
## Fleet occupancy is reserved before advancing the clock; only completed trips earn route fees.
static func cfg() -> Dictionary:return Logistics.cfg()["fleet"]
static func routes_cfg() -> Dictionary:return Logistics.cfg()["delivery_routes"]
static func enrich(s: Dictionary) -> void:
	if not s.has("fleet"):s["fleet"]={}
	s["fleet"]["van1"]=s["van"]
	if not s.has("assignments"):s["assignments"]={}
	for id in s["fleet"]:
		var v: Dictionary=s["fleet"][id]
		for pair in [["model","used"],["condition",90.0],["busy_until",0],["revenue",0.0],["fuel",0.0],["maintenance",0.0],["service_until",0],["reminded",false]]:
			if not v.has(pair[0]):v[pair[0]]=pair[1]
static func vehicles() -> Dictionary:return Logistics.S()["fleet"]
static func model(v: Dictionary) -> Dictionary:return cfg()["models"][v.get("model","used")]
static func available(id: String) -> bool:
	var v: Dictionary=vehicles().get(id,{})
	return not v.is_empty() and GlobalMarket.live(str(v.get("entity",""))) and bool(v.get("owned",false)) and Clock.now()>=int(v["busy_until"]) and Clock.now()>=int(v["service_until"])
static func buy(id: String) -> Dictionary:
	if not Logistics.has_van() or vehicles().has("van2") or not cfg()["models"].has(id):return {"ok":false,"error":"Buy the first company van, then choose one second van."}
	var m: Dictionary=cfg()["models"][id]
	var insurance:=float(m["insurance_month"])
	if Ledger.cash(Logistics.entity())<float(m["price"])+insurance:return {"ok":false,"error":"Save enough company cash for the vehicle and first insurance payment."}
	var result:=Assets.buy({"id":"fleet_van2_"+Logistics.entity(),"entity":Logistics.entity(),"segment":"logistics","price":m["price"],"life_days":1800,"resale":.5,"maintenance_days":99999,"failure_chance":0.0})
	if not result["ok"]:return result
	Ledger.expense(Logistics.entity(),"insurance",insurance,I18n.t("Fleet insurance: %s")%Fmt.money(insurance),{"segment":"logistics","vehicle":"van2"})
	vehicles()["van2"]={"owned":true,"entity":Logistics.entity(),"model":id,"condition":m["condition"],"km":0.0,"bought":Clock.now(),"next_insurance":Clock.now()+30*Clock.DAY,"asset":result["id"]}
	enrich(Logistics.S())
	return {"ok":true}
static func assign(employee: String,vehicle: String) -> Dictionary:
	var person: Dictionary=Staff.S()["people"].get(employee,{})
	if person.is_empty() or person["role"]!="driver" or not vehicles().get(vehicle,{}).get("owned",false):return {"ok":false,"error":"Choose a current driver and an owned vehicle."}
	var assignments: Dictionary=Logistics.S()["assignments"]
	for id in assignments.keys():
		if id==employee or assignments[id]==vehicle:assignments.erase(id)
	assignments[employee]=vehicle
	return {"ok":true}
static func chance(v: Dictionary) -> float:return clampf((90-float(v["condition"]))*float(cfg()["breakdown_per_condition"])*float(model(v)["failure_mult"]),0,float(cfg()["breakdown_cap"]))
static func prepare(j: Dictionary,st: Dictionary,vehicle: String) -> void:
	var v: Dictionary=vehicles()[vehicle]
	st["fuel_cost"]=snappedf(float(st["km"])*float(model(v)["l_per_km"])*float(Logistics.cfg()["fuel"]["price_l"])*Logistics.fuel_mult(),.01)
	st["fuel_l"]=float(st["km"])*float(model(v)["l_per_km"])
	j["vehicle"]=vehicle
	if chance(v)>0 and GameState.randf()<chance(v):
		j["breakdown"]=true;st["minutes"]=int(st["minutes"])+int(cfg()["delay_minutes"])
		var cost:=float(cfg()["tow"])+float(cfg()["repair"])
		Ledger.expense(Logistics.entity(),"maintenance",cost,I18n.t("Tow and repair: %s")%Fmt.money(cost),{"segment":"logistics","vehicle":vehicle,"type":"breakdown"})
		v["maintenance"]=float(v["maintenance"])+cost;v["condition"]=maxf(float(v["condition"]),55)
	v["busy_until"]=Clock.now()+int(st["minutes"])
static func settle(j: Dictionary,st: Dictionary,pay: float) -> void:
	var id: String=j.get("vehicle","van1")
	var v: Dictionary=vehicles()[id]
	v["km"]=float(v["km"])+float(st["km"]);v["revenue"]=float(v["revenue"])+pay;v["fuel"]=float(v["fuel"])+float(st["fuel_cost"]);v["maintenance"]=float(v["maintenance"])+float(st["upkeep"])
	v["condition"]=maxf(0,float(v["condition"])-float(st["km"])*float(cfg()["wear_per_km"]))
	if float(v["condition"])<float(cfg()["remind_below"]) and not v["reminded"]:
		v["reminded"]=true;GameState.add_message("sam",I18n.t("Sam: %s needs maintenance. Book half a day before another breakdown.")%vehicle_name(id))
	if j.has("route"):
		var c: Dictionary=Contracts.C().get(j["route"],{})
		if not c.is_empty() and c["status"]=="active" and int(c["week_start"])==int(j["route_week"]):c["completed"]=int(c["completed"])+1
static func service(id: String) -> Dictionary:
	if not available(id):return {"ok":false,"error":"The vehicle is busy or already in service. Wait, then book maintenance."}
	var cost:=float(cfg()["service_cost"])
	if Ledger.cash(Logistics.entity())<cost:return {"ok":false,"error":"Save enough company cash for maintenance."}
	Ledger.expense(Logistics.entity(),"maintenance",cost,I18n.t("Preventive maintenance: %s")%Fmt.money(cost),{"segment":"logistics","vehicle":id})
	var v: Dictionary=vehicles()[id]
	v["maintenance"]=float(v["maintenance"])+cost;v["service_until"]=Clock.now()+int(cfg()["service_minutes"])
	Sim.schedule(int(v["service_until"]),"log.service_done",{"vehicle":id})
	return {"ok":true}
static func dispatch(t: int) -> void:
	var day:=Clock.day_index_at(t)
	for p in Logistics.drivers_at(t):
		if int(Logistics.S()["driver_day"].get(p["id"],-1))==day:continue
		var assigned: Dictionary=Logistics.S()["assignments"]
		if not assigned.has(p["id"]) and not assigned.values().has("van1"):assigned[p["id"]]="van1"
		var vehicle: String=assigned.get(p["id"],"")
		if not available(vehicle):continue
		var pick: Dictionary={};var stats: Dictionary={}
		for job in Logistics.open_jobs():
			var best:=Logistics.best_order(job["stops"])
			var st:=Logistics.stats_for_px(job["stops"].size(),float(best["px"])/maxf(.2,Logistics.driver_score(p)),float(best["px"]))
			if t+int(st["minutes"])>int(job["by"]):continue
			if pick.is_empty() or (job.has("route") and not pick.has("route")) or (job.has("route")==pick.has("route") and float(job["pay"])>float(pick["pay"])):pick=job;stats=st
		if pick.is_empty():continue
		Logistics.S()["driver_day"][p["id"]]=day
		prepare(pick,stats,vehicle)
		pick["status"]="driving";pick["driver"]=p["id"];pick["driver_stats"]=stats
		Sim.schedule(t+int(stats["minutes"]),"log.driver_done",{"job":pick["id"],"driver":p["id"],"vehicle":vehicle})
static func offer(t: Dictionary) -> String:
	var id: String="C-%03d"%(Contracts.C().size()+1)
	var now:=Clock.now();var terms:=routes_cfg()
	var price:=float(t.get("unit_price",terms["pay_run"]))
	var c: Dictionary={"id":id,"type":"delivery_route","buyer":t["buyer"],"seller":GameState.company_id(),"product":"","qty":int(terms["runs_week"]),"unit_price":price,"orig_price":price,"total":price*int(terms["runs_week"]),"orig_terms":0,"payment_terms_days":0,"upfront_rate":0.0,"delivery_days":int(terms["days"]),"penalty_rate":0.0,"status":"offered","offered":now,"expires":now+int(terms["offer_days"])*Clock.DAY,"patience":2,"history":[],"tag":"","place":t["place"],"completed":0,"internal":bool(t.get("internal",false))}
	Contracts.C()[id]=c;Sim.schedule(c["expires"],"con.expire",{"id":id});return id
static func sign(c: Dictionary) -> Dictionary:
	if c["seller"]!=GameState.company_id() or not Logistics.has_van() or Clock.now()>=int(c["expires"]):return {"ok":false,"error":"Use the owning company with a van before this route offer expires."}
	c["status"]="active";c["accepted"]=Clock.now();c["due"]=Clock.now()+int(c["delivery_days"])*Clock.DAY;c["week_start"]=Clock.now();c["week_end"]=mini(int(c["due"]),Clock.now()+7*Clock.DAY)
	return {"ok":true}
static func counter(c: Dictionary,price: float,terms: int,upfront: float) -> Dictionary:
	if Clock.now()>=int(c["expires"]) or c["seller"]!=GameState.company_id() or not is_finite(price) or price<=0 or terms!=0 or upfront!=0:return {"ok":false,"error":"Route fees are paid per completed trip. Choose a positive price and no advance or payment delay."}
	if price<=float(c["orig_price"])*float(routes_cfg()["counter_factor"]):
		c["unit_price"]=snappedf(price,.01);c["total"]=float(c["unit_price"])*int(c["qty"]);return {"ok":true,"result":"agreed"}
	c["patience"]=int(c["patience"])-1
	if int(c["patience"])<0:c["status"]="withdrawn"
	return {"ok":true,"result":"withdrawn" if c["status"]=="withdrawn" else "countered"}
static func run_route(id: String,vehicle: String) -> Dictionary:
	var c: Dictionary=Contracts.C().get(id,{})
	if c.is_empty() or c["status"]!="active" or c["seller"]!=GameState.company_id() or not available(vehicle):return {"ok":false,"error":"Choose an active route and an available company vehicle."}
	route_tick(Clock.now())
	if c["status"]!="active" or int(c["completed"])>=int(c["qty"]):return {"ok":false,"error":"This week's trips are complete or the contract has ended. Wait for next week or choose another route."}
	var job: Dictionary={}
	for existing in Logistics.S()["jobs"].values():
		if existing.get("route","")==id:
			if existing["status"]=="driving":return {"ok":false,"error":"This route is already in progress. Wait for its vehicle."}
			job=existing;break
	if job.is_empty():
		job=make_route_job(c);Logistics.S()["jobs"][job["id"]]=job
	if job["status"]=="open":Logistics.accept(job["id"])
	return Logistics.drive(job["id"],[0],vehicle)
static func make_route_job(c: Dictionary) -> Dictionary:
	var id: String="R%d"%int(Logistics.S()["seq"]);Logistics.S()["seq"]=int(Logistics.S()["seq"])+1
	return {"id":id,"client":GameState.entity_name(c["buyer"]),"stops":[c["place"]],"kind":"same_day","posted":Clock.now(),"by":c["week_end"],"pay":c["unit_price"],"status":"open","route":c["id"],"route_week":c["week_start"],"internal":c.get("internal",false)}
static func route_tick(t: int) -> void:
	for c in Contracts.C().values():
		if c.get("type","")!="delivery_route" or c["status"]!="active":continue
		while t>=int(c["week_end"]) and c["status"]=="active":
			var fraction:=float(int(c["week_end"])-int(c["week_start"]))/float(7*Clock.DAY)
			var missing:=maxi(0,int(ceil(int(c["qty"])*fraction))-int(c["completed"]))
			var cost:=missing*float(routes_cfg()["penalty_run"]) if not c.get("internal",false) else 0.0
			if cost>0:Ledger.expense(c["seller"],"penalties",cost,I18n.t("Missed route trips: %s")%Fmt.money(cost),{"segment":"logistics","contract":c["id"]})
			if int(c["week_end"])>=int(c["due"]):c["status"]="paid";break
			c["week_start"]=c["week_end"];c["week_end"]=mini(int(c["due"]),int(c["week_end"])+7*Clock.DAY);c["completed"]=0
static func on_hour(t: int,h: int) -> void:
	for id in vehicles():
		var v: Dictionary=vehicles()[id]
		if not v.get("owned",false):continue
		if int(v["service_until"])>0 and t>=int(v["service_until"]):v["service_until"]=0;v["condition"]=float(cfg()["service_condition"]);v["reminded"]=false
		if id!="van1" and t>=int(v.get("next_insurance",t+Clock.DAY)):
			var cost:=float(model(v)["insurance_month"])
			Ledger.expense(Logistics.entity(),"insurance",cost,I18n.t("Fleet insurance: %s")%Fmt.money(cost),{"segment":"logistics","vehicle":id});v["next_insurance"]=t+30*Clock.DAY
	route_tick(t)
	if h==7:
		for client in routes_cfg()["clients"]:
			if not Contracts.C().values().any(func(c):return c.get("type","")=="delivery_route" and c["buyer"]==client["id"]):Contracts.create_offer({"type":"delivery_route","buyer":client["id"],"place":client["place"]})
		if Cafe.in_shop("corner_cafe",Cafe.leased) and not Contracts.C().values().any(func(c):return c.get("type","")=="delivery_route" and c.get("internal",false)):
			Contracts.create_offer({"type":"delivery_route","buyer":GameState.company_id(),"place":"corner_cafe_unit","internal":true})
		for c in Contracts.C().values():
			if c.get("type","")=="delivery_route" and c["status"]=="active" and int(c["completed"])<int(c["qty"]) and not Logistics.S()["jobs"].values().any(func(j):return j.get("route","")==c["id"]):
				var job:=make_route_job(c);Logistics.S()["jobs"][job["id"]]=job
static func close() -> void:
	for v in vehicles().values():v["owned"]=false
	Logistics.S()["assignments"].clear()

static func report(id: String) -> Dictionary:
	var v: Dictionary=vehicles()[id]
	var insurance:=0.0;var depreciation:=0.0
	for entry in GameState.data["ledger"]["journal"]:
		if entry["entity"]!=Logistics.entity():continue
		var source: Dictionary=entry.get("source",{})
		if source.get("vehicle","")==id or (id=="van1" and source.get("segment","")=="logistics" and source.get("type","")=="insurance"):
			for line in entry["lines"]:
				if line["acct"]=="exp:insurance":insurance+=float(line.get("dr",0))-float(line.get("cr",0))
		if source.get("id","")==v.get("asset","__none__"):
			for line in entry["lines"]:
				if line["acct"]=="exp:depreciation":depreciation+=float(line.get("dr",0))
	var direct:=float(v["revenue"])-float(v["fuel"])-float(v["maintenance"])-insurance-depreciation
	var total_km:=0.0
	for item in vehicles().values():total_km+=float(item.get("km",0))
	var company_report:=Segments.compute(Logistics.entity(),0,Clock.now()+1)
	var profit:=float(company_report["rows"]["logistics"]["operating_profit"])
	var share:=float(v["km"])/total_km if total_km>0 else 1.0/vehicles().size()
	return {"insurance":insurance,"depreciation":depreciation,"profit_km":direct/maxf(1,float(v["km"])),"allocated_profit":profit*share,"allocated_profit_km":profit*share/maxf(1,float(v["km"]))}

static func vehicle_name(id: String) -> String:return I18n.t("First van" if id=="van1" else "Second van")

static func service_done(id: String) -> void:
	var v: Dictionary=vehicles().get(id,{})
	if not v.is_empty() and v.get("owned",false) and int(v["service_until"])>0 and Clock.now()>=int(v["service_until"]):
		v["service_until"]=0;v["condition"]=float(cfg()["service_condition"]);v["reminded"]=false
