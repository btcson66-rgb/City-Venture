class_name Brand
extends RefCounted
## One company score built from actual reviews and a bounded, decaying history; neutral legacy saves start at 50.
static func cfg() -> Dictionary: return DataDB.economy.get("governance",{})
static func S() -> Dictionary:
	if not GameState.data.has("brand_service"):GameState.data["brand_service"]={"companies":{}}
	return GameState.data["brand_service"]
static func E(entity: String) -> Dictionary:
	if not S()["companies"].has(entity):S()["companies"][entity]={"events":[],"cache_hour":-1,"components":{},"score":50.0}
	return S()["companies"][entity]
static func record(entity: String,component: String,value: float) -> void:
	if not Tax.valid(entity) or not cfg()["brand_weights"].has(component) or not is_finite(value):return
	var state := E(entity)
	state["events"].append({"t":Clock.now(),"component":component,"value":clampf(value,-20,20)})
	while state["events"].size()>64:state["events"].pop_front()
	state["cache_hour"]=-1
static func components(entity: String) -> Dictionary:
	if not Tax.valid(entity):return {"reviews":50.0,"news":50.0,"crises":50.0,"payments":50.0,"employees":50.0}
	var state := E(entity)
	if int(state["cache_hour"])==int(Clock.now()/60):return state["components"]
	var parts := {"reviews":50.0,"news":50.0,"crises":50.0,"payments":50.0,"employees":50.0}
	var horizon := int(cfg()["brand_event_days"])*Clock.DAY
	state["events"]=state["events"].filter(func(e):return Clock.now()-int(e["t"])<horizon)
	for event in state["events"]:
		parts[event["component"]]+=float(event["value"])*(1.0-float(Clock.now()-int(event["t"]))/horizon)
	if entity==GameState.business_entity():
		var n := 0.0
		var sum := 0.0
		for listing in Ecommerce.E().get("listings",{}).values():
			if listing.get("active",false) and listing.get("entity",entity)==entity:
				n+=float(listing.get("rating_n",0))
				sum+=float(listing.get("rating_sum",0))
		for entry in Industries.all():
			var module=entry["sim_class"]
			if module.has_method("S") and module.is_running():
				if module.has_method("entity") and module.entity()!=entity:continue
				var reviews=module.S().get("reviews",{})
				if reviews is Dictionary and float(reviews.get("n",0))>0:
					n+=float(reviews["n"])
					sum+=float(reviews.get("sum",0))
				elif reviews is Array:
					for review in reviews:
						var weight := maxf(0,float(review.get("w",1)))
						n+=weight
						sum+=float(review.get("score",2.5))*weight
		if n>0:parts["reviews"]=clampf(sum/n*20.0,0,100)
		if not Staff.people().is_empty():
			var morale := 0.0
			for person in Staff.people():morale+=float(person.get("morale",50))
			parts["employees"]+=morale/Staff.people().size()-50.0
		if Staff.wages_owed()>0:parts["employees"]-=15.0
	var score := 0.0
	for key in parts:
		parts[key]=clampf(float(parts[key]),0,100)
		score+=float(parts[key])*float(cfg()["brand_weights"][key])
	state["score"]=snappedf(score,.1)
	state["components"]=parts
	state["cache_hour"]=int(Clock.now()/60)
	return parts
static func score(entity: String) -> float:
	components(entity)
	return float(E(entity)["score"]) if Tax.valid(entity) else 50.0
static func apr_adjustment() -> float:
	return (50.0-score(GameState.business_entity()))/50.0*float(cfg()["brand_apr_range"])
static func customer_willingness() -> float:
	return 1.0+(score(GameState.business_entity())-50.0)/50.0*float(cfg()["brand_customer_range"])
static func applicant_count(base: int) -> int:
	return maxi(1,base+roundi((score(GameState.business_entity())-50.0)/50.0*float(cfg()["brand_applicant_range"])))
static func on_ledger(entry: Dictionary) -> void:
	var entity := str(entry["entity"])
	if not Tax.valid(entity):return
	var lines: Array=entry["lines"]
	if lines.any(func(l):return l["acct"]=="wages_payable" and float(l.get("cr",0))>0):record(entity,"employees",-6)
	if lines.any(func(l):return l["acct"]=="wages_payable" and float(l.get("dr",0))>0):record(entity,"employees",4)
	var kind := str(entry["source"].get("type",""))
	if kind in ["payroll","po","job_purchase","payment"] and lines.any(func(l):return l["acct"]=="cash" and float(l.get("cr",0))>0):record(entity,"payments",0.25)
