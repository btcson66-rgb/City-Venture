class_name CafeDepth
extends RefCounted
## Per-shop ingredients/inspections, one shared staff roster, and actual recorded overtime.
static func enrich(s: Dictionary) -> void:
	if not s.has("materials"):s["materials"]={"beans":int(s["supplies"]),"milk":0,"tea":0,"food":0}
	s["materials"]["beans"]=int(s["supplies"])
	for id in Cafe.cfg()["items"]:
		if not s["prices"].has(id):s["prices"][id]=Cafe.item(id)["ref_price"]
	for pair in [["material_incoming",{}],["cleaned",-1],["inspection_next",-1],["inspection_until",0],["inspection_pending",false],["inspections",[]]]:
		if not s.has(pair[0]):s[pair[0]]=pair[1]
static func seasonal(id: String,t := -1) -> bool:
	var item:=Cafe.item(id)
	return not item.has("months") or int(Clock.date_at(Clock.now() if t<0 else t)["month"]) in item["months"].map(func(m):return int(m))
static func margin(id: String) -> float:return Cafe.price(id)-float(Cafe.item(id)["unit_cost"])
static func available(id: String) -> bool:
	for ingredient in Cafe.item(id).get("materials",{}):
		var units: int=int(Cafe.S()["pastries"]) if ingredient=="bakery_pastry" else int(Cafe.S()["materials"].get(ingredient,0))
		if units<int(Cafe.item(id)["materials"][ingredient]):return false
	return seasonal(id)
static func sell(want: int) -> Dictionary:
	var revenue:=0.0
	var cost:=0.0
	var served:=0
	var state:=Cafe.S()
	var stock: Dictionary=state["materials"]
	for i in want:
		var weights: Dictionary=Cafe.cfg()["drink_shares"].duplicate()
		if seasonal("seasonal"):weights["seasonal"]=float(weights["seasonal"])*(1+float(Cafe.cfg()["seasonal_demand_bonus"]))
		else:weights["coffee"]=float(weights["coffee"])+float(weights["seasonal"]);weights["seasonal"]=0
		var total:=0.0
		for weight in weights.values():total+=float(weight)
		var draw:=GameState.randf()*total
		var id: String="coffee"
		for drink in weights:
			draw-=float(weights[drink])
			if draw<0:id=drink;break
		if not available(id):id="coffee"
		if not available(id):continue
		for ingredient in Cafe.item(id)["materials"]:stock[ingredient]=int(stock[ingredient])-int(Cafe.item(id)["materials"][ingredient])
		state["supplies"]=int(stock["beans"])
		revenue+=Cafe.price(id)
		cost+=float(Cafe.item(id)["unit_cost"]);served+=1
		if GameState.randf()<float(Cafe.item("sandwich")["attach"]) and available("sandwich"):
			stock["food"]=int(stock["food"])-2;revenue+=Cafe.price("sandwich");cost+=float(Cafe.item("sandwich")["unit_cost"])
	Cafe.S()["supplies"]=int(Cafe.S()["materials"]["beans"])
	return {"served":served,"revenue":revenue,"cost":cost}
static func order(pack: String) -> Dictionary:
	var packs: Array=Cafe.cfg()["material_packs"].filter(func(p):return p["id"]==pack)
	if packs.is_empty() or not Cafe.leased():return {"ok":false,"error":"Lease a café and choose an ingredient pack first."}
	var p: Dictionary=packs[0]
	var cost:=float(p["cost"])*World.cost_mult(Cafe.SUPPLIER)
	if Ledger.cash(Cafe.entity())<cost:return {"ok":false,"error":"Save enough café cash for this ingredient pack."}
	for id in p["materials"]:
		if int(Cafe.S()["materials"].get(id,0))+int(Cafe.S()["material_incoming"].get(id,0))+int(p["materials"][id])>int(Cafe.cfg()["supplies_max"]):return {"ok":false,"error":"The ingredient storeroom is full. Use supplies before ordering more."}
	Ledger.post(Cafe.entity(),I18n.t("Café ingredients: %s")%Fmt.money(cost),[{"acct":"cogs","dr":cost},{"acct":"cash","cr":cost}],{"type":"cafe","segment":"cafe","property":Cafe.property_id()})
	for id in p["materials"]:Cafe.S()["material_incoming"][id]=int(Cafe.S()["material_incoming"].get(id,0))+int(p["materials"][id])
	Sim.schedule(Clock.now()-Clock.now()%Clock.DAY+Clock.DAY+6*60,"cafe.materials",{"property":Cafe.property_id(),"materials":p["materials"]})
	return {"ok":true}
static func receive(p: Dictionary) -> void:
	for id in p["materials"]:
		var n:=int(p["materials"][id]);Cafe.S()["materials"][id]=int(Cafe.S()["materials"].get(id,0))+n;Cafe.S()["material_incoming"][id]=maxi(0,int(Cafe.S()["material_incoming"].get(id,0))-n)
static func roster() -> Dictionary:
	Cafe.S()
	return GameState.data["cafe"]["roster"]
static func scheduled(p: Dictionary,t: int,property: String) -> bool:
	var id: String=p["id"]
	if not roster().has(id):
		# A newly encountered/legacy barista receives a visible early weekday roster, never an invisible all-day worker.
		roster()[id]={}
		for day in range(1,6):roster()[id][str(day)+":early"]="corner_cafe"
	if t<int(p.get("start",0)):return false
	var hour:=int((t%Clock.DAY)/60)
	var shift: String="early" if hour>=7 and hour<12 else "late" if hour>=12 and hour<17 else ""
	return shift!="" and roster()[id].get(str(Clock.weekday(t))+":"+shift,"")==property
static func assign(id: String,day: int,shift: String) -> Dictionary:
	if not Staff.S()["people"].has(id) or Staff.S()["people"][id]["role"]!="barista" or day<1 or day>7 or shift not in ["early","late"] or not Cafe.leased():return {"ok":false,"error":"Choose a current barista, day and shift at a leased café."}
	scheduled(Staff.S()["people"][id],Clock.now(),Cafe.property_id())
	var key:=str(day)+":"+shift
	roster()[id][key]="" if roster()[id].get(key,"")==Cafe.property_id() else Cafe.property_id()
	return {"ok":true}
static func record_hours(t: int,extra := 1.0) -> void:
	var root: Dictionary=GameState.data["cafe"]
	for person in Cafe.baristas_at(t):
		var id: String=person["id"]
		var week:=Clock.day_index_at(t)/7
		var row: Dictionary=root["work_hours"].get(id,{"week":week,"hours":0.0,"last":-1})
		if int(row["week"])!=week:row={"week":week,"hours":0.0,"last":-1}
		if extra==1.0 and int(row["last"])==t:continue
		var hours:=float(row["hours"])
		var threshold:=float(Cafe.cfg()["overtime"]["hours"])
		var overtime:=maxf(0,hours+extra-threshold)-maxf(0,hours-threshold)
		if overtime>0:
			var cost:=snappedf(overtime*float(person["salary_week"])/threshold*float(Cafe.cfg()["overtime"]["mult"]),.01)
			Ledger.expense(Cafe.entity(),"payroll",cost,I18n.t("Café overtime: %s")%Fmt.money(cost),{"type":"cafe_overtime","segment":"cafe","employee":id,"property":Cafe.property_id()},"cash" if Ledger.cash(Cafe.entity())>=cost else "wages_payable")
		row["hours"]=hours+extra
		if extra==1.0:row["last"]=t
		root["work_hours"][id]=row
static func clean() -> Dictionary:
	if not Cafe.ready_to_open():return {"ok":false,"error":"Open the café before cleaning."}
	if int(Cafe.S()["cleaned"])/Clock.DAY==Clock.day_index():return {"ok":false,"error":"Already cleaned today. Keep the shop ready or clean tomorrow."}
	var t:=Clock.now()
	CafeDepth.record_hours(t-60,float(Cafe.cfg()["inspection"]["clean_minutes"])/60)
	Cafe.S()["cleaned"]=t;Clock.advance(int(Cafe.cfg()["inspection"]["clean_minutes"]))
	return {"ok":true}
static func inspection_due() -> void:
	var s:=Cafe.S()
	if Cafe.ready_to_open() and int(s["inspection_next"])<0:
		s["inspection_next"]=Clock.now()+GameState.randi_range(int(Cafe.cfg()["inspection"]["min_days"]),int(Cafe.cfg()["inspection"]["max_days"]))*Clock.DAY
	if Cafe.ready_to_open() and not s["inspection_pending"] and int(s["inspection_next"])>=0 and Clock.now()>=int(s["inspection_next"]):
		s["inspection_pending"]=true
		s["inspection_iid"]=EventEngine.trigger("cafe_inspection",{"company":GameState.company_id(),"property":Cafe.property_id()})["iid"]
		s["inspection_deadline"]=Clock.now()+Clock.DAY
	if s["inspection_pending"] and s.has("inspection_deadline") and Clock.now()>=int(s["inspection_deadline"]):EventEngine.choose(s["inspection_iid"],"as_is")
static func inspect() -> Dictionary:
	var s:=Cafe.S()
	if not s["inspection_pending"]:return {"ok":false,"error":"No inspection is due. Keep cleaning and monitor ingredients."}
	var config: Dictionary=Cafe.cfg()["inspection"]
	var served:=maxf(1,Cafe.last_days(7,"served"))
	var issues:=0
	if Cafe.last_days(7,"waste")/served>float(config["waste_limit"]):issues+=1
	if Cafe.last_days(7,"stock_lost")>0:issues+=1
	var recent: Array=s["days"].slice(maxi(0,s["days"].size()-7))
	var rating:=float(s["rating"])
	if not recent.is_empty():
		rating=0
		for day in recent:rating+=float(day.get("rating",s["rating"]))
		rating/=recent.size()
	if rating<float(config["rating_min"]):issues+=1
	if int(s["cleaned"])<0 or Clock.now()-int(s["cleaned"])>int(config["clean_days"])*Clock.DAY:issues+=1
	var outcome: String="pass" if issues==0 else "improve" if issues<=2 else "fine"
	if outcome=="pass":s["rating"]=minf(5,float(s["rating"])+.1)
	else:s["inspection_until"]=Clock.now()+int(config["pause_days"])*Clock.DAY
	if outcome=="fine":Ledger.expense(Cafe.entity(),"penalties",float(config["fine"]),I18n.t("Café health inspection fine: %s")%Fmt.money(float(config["fine"])),{"type":"cafe_inspection","segment":"cafe","property":Cafe.property_id()})
	s["inspections"].append({"t":Clock.now(),"outcome":outcome});s["inspection_pending"]=false
	s["inspection_next"]=Clock.now()+GameState.randi_range(int(config["min_days"]),int(config["max_days"]))*Clock.DAY
	return {"ok":true,"outcome":outcome}

static func decision(ctx: Dictionary,prepare: bool) -> Dictionary:
	if not GlobalMarket.live(str(ctx.get("company",""))):return {"ok":true}
	return CompanyPortfolio.run_in(ctx["company"],func():return Cafe.in_shop(ctx["property"],func():
		if not Cafe.leased() or not Cafe.S()["inspection_pending"]:return {"ok":true}
		if prepare:
			var result:=clean()
			if not result["ok"] and int(Cafe.S()["cleaned"])/Clock.DAY!=Clock.day_index():return result
		return inspect() if Cafe.S()["inspection_pending"] else {"ok":true}))

static func booked_margin(day: int,revenue: float) -> float:
	var cost:=0.0
	for row in GameState.data["ledger"]["journal"]:
		if row["entity"]!=Cafe.entity() or int(row["t"])/Clock.DAY!=day or row.get("source",{}).get("property","")!=Cafe.property_id():continue
		for line in row["lines"]:
			if line["acct"]=="cogs":cost+=float(line.get("dr",0))-float(line.get("cr",0))
	return 100*(revenue-cost)/maxf(1,revenue)
