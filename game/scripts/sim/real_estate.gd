class_name RealEstate
extends RefCounted
## Brokerage transactions, tenant invoices and paid construction milestones share one saved entity.
static func cfg() -> Dictionary: return DataDB.economy.get("real_estate",{})
static func S() -> Dictionary:
	if not GameState.data.has("real_estate"):
		GameState.data["real_estate"]={"active":false,"entity":"","stage":1,"mandates":{},"clients":{},"properties":{},"invoices":{},"project":{},"seq":1,"week":-1}
	return GameState.data["real_estate"]
static func entity() -> String: return str(S()["entity"])
static func segment_tag() -> String: return "real_estate"
static func source(id := "") -> Dictionary: return {"type":"real_estate","segment":"real_estate","id":id}
static func error(message: String) -> Dictionary: return {"ok":false,"error":I18n.t(message)}
static func is_running() -> bool: return GameState.has_game() and bool(S()["active"])
static func valid() -> bool: return is_running() and Assets._valid_entity(entity())
static func licence() -> bool: return Compliance.permit_valid("brokerage")
static func start() -> Dictionary:
	if GameState.company_id()=="" or not GameState.flag("business_account_opened") or Acquisition.sold(): return error("Register a company and open its bank account first.")
	if not licence(): return error("Apply for the brokerage licence at City Hall; processing takes three days.")
	if not Living.has_lease("realty_office"): return error("Lease Harlow & Finch in Residential first.")
	if is_running(): return error("The brokerage is already open.")
	if entity()!="" and entity()!=GameState.company_id(): GameState.data.erase("real_estate")
	S()["entity"]=GameState.company_id()
	S()["active"]=true
	GameState.set_flag("real_estate_active")
	refresh()
	GameState.timeline(I18n.t("Opened Harlow & Finch brokerage."),"milestone")
	return {"ok":true}
static func _id(prefix: String) -> String:
	var id := prefix+str(S()["seq"])
	S()["seq"]=int(S()["seq"])+1
	return id
static func listings() -> Array:
	return DataDB.properties.values().filter(func(p):return p.get("kind","")=="investment_home" and p.get("district","")=="residential")
static func refresh() -> void:
	if not valid(): return
	var week := Clock.day_index()/7
	if week==int(S()["week"]):return
	S()["week"]=week
	for record in S()["mandates"].values():
		if record["status"]=="open":record["status"]="expired"
	for record in S()["clients"].values():
		if record["status"]=="open":record["status"]="expired"
	var homes := listings()
	if homes.is_empty():return
	for i in int(cfg()["weekly_mandates"]):
		var home: Dictionary=homes[GameState.rng.randi_range(0,homes.size()-1)]
		var sale := i==0
		var price := float(home["purchase_price"])*RealEstateMarket.index() if sale else float(home["monthly_rent"])
		var id := _id("M-")
		S()["mandates"][id]={"id":id,"property":home["id"],"rooms":int(home["rooms"]),"district":"residential","kind":"sale" if sale else "rent","floor":snappedf(price,.01),"status":"open"}
	for i in int(cfg()["weekly_clients"]):
		var mandate: Dictionary=S()["mandates"].values()[-1-i%int(cfg()["weekly_mandates"])]
		var id := _id("C-")
		S()["clients"][id]={"id":id,"name":cfg()["tenant_names"][GameState.rng.randi_range(0,cfg()["tenant_names"].size()-1)],"kind":mandate["kind"],"budget":snappedf(float(mandate["floor"])*GameState.rng.randf_range(float(cfg()["budget_range"][0]),float(cfg()["budget_range"][1])),.01),"rooms":int(mandate["rooms"]),"district":"residential","urgency":GameState.rng.randi_range(1,5),"status":"open"}
static func score(mandate: Dictionary, client: Dictionary) -> float:
	if mandate.is_empty() or client.is_empty() or mandate["kind"]!=client["kind"]:return 0
	var budget := minf(1,float(client["budget"])/maxf(1,float(mandate["floor"])))
	return clampf(budget*float(cfg()["match_weights"][0])+(float(cfg()["match_weights"][1]) if int(mandate["rooms"])>=int(client["rooms"]) else 0)+(float(cfg()["match_weights"][2]) if mandate["district"]==client["district"] else 0),0,1)
static func viewing(mandate_id: String, client_id: String, negotiation: String) -> Dictionary:
	var mandate: Dictionary=S()["mandates"].get(mandate_id,{})
	var client: Dictionary=S()["clients"].get(client_id,{})
	if not valid() or mandate.is_empty() or client.is_empty() or mandate["status"]!="open" or client["status"]!="open" or not cfg()["commission_rates"].has(negotiation):return error("Choose an open owner mandate and a matching client.")
	if Ledger.cash(entity())<float(cfg()["show_cost"]):return error("Not enough cash for a viewing.")
	Ledger.expense(entity(),"other",float(cfg()["show_cost"]),I18n.t("Property viewing"),source(mandate_id))
	var chance := float(cfg()["match_chance"])*score(mandate,client)*RealEstateMarket.index()+float(cfg()["negotiation_chance"][negotiation])+int(client["urgency"])*float(cfg()["urgency_chance"])+Staff.count("realty_agent")*float(cfg()["agent_chance"])
	# Rate shocks reduce buyer financing appetite even when their nominal budget fits.
	chance*=maxf(float(cfg()["market_heat_floor"]),1-maxf(0,RealEstateMarket.rate()-Bank.base_rate())*float(cfg()["market_heat_rate_sensitivity"]))
	var success: bool = mandate["kind"]==client["kind"] and float(client["budget"])>=float(mandate["floor"]) and GameState.rng.randf()<clampf(chance,.02,.9)
	client["status"]="matched" if success else "declined"
	Clock.advance(int(cfg()["show_minutes"]))
	if not valid():return error("The brokerage closed during this viewing.")
	if not success:return {"ok":true,"closed":false}
	mandate["status"]="closed"
	var commission := snappedf(float(mandate["floor"])*(float(cfg()["commission_rates"][negotiation]) if mandate["kind"]=="sale" else 1.0),.01)
	var job := Jobs.offer({"entity":entity(),"client":client["name"],"scope":"Property brokerage commission","price":commission,"work":1,"terms":0,"segment":"real_estate"})
	Jobs.accept(job)
	Jobs.progress(job,1)
	Jobs.deliver(job)
	Jobs.invoice(job)
	GameState.inc_stat("realty_matches")
	GameState.timeline(I18n.t("Brokerage commission received: %s.")%Fmt.money(commission),"business")
	return {"ok":true,"closed":true,"job":job,"commission":commission}
static func buy(id: String, down: float, years: int) -> Dictionary:
	if not valid():return error("Open the brokerage first.")
	var property: Dictionary=DataDB.properties.get(id,{})
	if property.get("kind","")!="investment_home" or S()["properties"].has(id):return error("Choose an unowned residential unit.")
	var result := Bank.property_mortgage(id,snappedf(float(property["purchase_price"])*RealEstateMarket.index(),.01),down,years)
	if not result["ok"]:return result
	S()["properties"][id]={"id":id,"name":property["name"],"entity":entity(),"base_price":float(property["purchase_price"]),"book":result["price"],"uplift":0.0,"rent":float(property["monthly_rent"]),"base_rent":float(property["monthly_rent"]),"mortgage":result["id"],"status":"empty","screen":int(cfg()["default_screen"]),"tenant":{},"renovation":{}}
	S()["stage"]=maxi(2,int(S()["stage"]))
	GameState.timeline(I18n.t("Purchased residential property: %s.")%I18n.t(property["name"]),"milestone")
	return result
static func vacancy_days(ratio: float, screen: int) -> int:
	return maxi(1,ceili(float(cfg()["vacancy_base_days"])+maxf(0,ratio-1)*float(cfg()["vacancy_price_days"])+maxf(0,screen-int(cfg()["screen_min"]))/float(int(cfg()["screen_max"])-int(cfg()["screen_min"]))*float(cfg()["vacancy_screen_days"])))
static func list_rental(id: String, ratio: float, screen: int) -> Dictionary:
	var property: Dictionary=S()["properties"].get(id,{})
	if not valid() or property.is_empty() or property["status"] not in ["empty","listed"] or not property["renovation"].is_empty() or not is_finite(ratio) or ratio<float(cfg()["rent_min"]) or ratio>float(cfg()["rent_max"]) or screen<int(cfg()["screen_min"]) or screen>int(cfg()["screen_max"]):return error("Choose an empty finished unit and valid rent and screening terms.")
	property["rent"]=snappedf(float(property["base_rent"])*(1+float(property["uplift"]))*ratio,.01)
	property["screen"]=screen
	property["status"]="listed"
	property["available"]=Clock.now()+vacancy_days(ratio,screen)*Clock.DAY
	Sim.cancel("re.tenant","id",id)
	Sim.schedule(int(property["available"]),"re.tenant",{"id":id})
	return {"ok":true,"days":vacancy_days(ratio,screen)}
## Publish all empty completed units as one rental portfolio, retaining separate tenant invoices.
static func list_building(ratio: float, screen: int) -> Dictionary:
	if not valid() or S()["project"].get("status","")!="completed" or not is_finite(ratio) or ratio<float(cfg()["rent_min"]) or ratio>float(cfg()["rent_max"]) or screen<int(cfg()["screen_min"]) or screen>int(cfg()["screen_max"]):return error("Choose an empty finished unit and valid rent and screening terms.")
	var count := 0
	for property in S()["properties"].values():
		if str(property["id"]).begins_with("tower_") and property["status"]=="empty" and property["renovation"].is_empty():
			if list_rental(property["id"],ratio,screen)["ok"]:count+=1
	return {"ok":count>0,"units":count,"error":I18n.t("Sell an empty finished unit.")}
static func renovate(id: String, grade: String) -> Dictionary:
	var property: Dictionary=S()["properties"].get(id,{})
	if not valid() or property.is_empty() or property["status"]!="empty" or not property["renovation"].is_empty() or not cfg()["renovations"].has(grade):return error("Renovate an empty owned unit before listing it.")
	var spec: Dictionary=cfg()["renovations"][grade]
	if Ledger.cash(entity())<float(spec["cost"]):return error("Not enough cash for renovation.")
	Ledger.post(entity(),I18n.t("Residential renovation"),[{"acct":"property_assets","dr":spec["cost"]},{"acct":"cash","cr":spec["cost"]}],source(id))
	property["book"]=float(property["book"])+float(spec["cost"])
	property["renovation"]={"grade":grade,"due":Clock.now()+int(spec["days"])*Clock.DAY,"cost":spec["cost"]}
	Sim.schedule(int(property["renovation"]["due"]),"re.renovation",{"id":id})
	return {"ok":true}
static func develop(scale: String, name: String) -> Dictionary:
	if not valid() or int(S()["stage"])<2 or not Compliance.permit_valid("building"):return error("Own a rental and obtain the Lot 7 building permit at City Hall first.")
	if not cfg()["development"].has(scale) or not S()["project"].is_empty() or name.strip_edges()=="" or name.length()>32:return error("Choose a project scale and a name of 1–32 characters.")
	var spec: Dictionary=cfg()["development"][scale]
	var months := ceili(int(spec["days"])/30.0)
	var installment := snappedf(float(spec["cost"])/months,.01)
	if Ledger.cash(entity())<installment:return error("Fund the first construction milestone before breaking ground.")
	var id := Jobs.offer({"entity":entity(),"client":"Ruiz Construction","scope":"Lot 7 construction","price":spec["cost"],"work":months,"due":Clock.now()+int(spec["days"])*Clock.DAY,"terms":0,"direction":"purchase","segment":"real_estate"})
	Jobs.accept_purchase(id)
	S()["project"]={"name":name.strip_edges(),"scale":scale,"status":"building","job":id,"units":int(spec["units"]),"budget":float(spec["cost"]),"paid":0.0,"milestones":months,"due":Clock.now()+int(spec["days"])*Clock.DAY,"next":Clock.now(),"delay_until":0,"overrun":false}
	S()["stage"]=3
	_milestone()
	GameState.timeline(I18n.t("Construction started: %s.")%name,"milestone")
	EventBus.world_refresh.emit()
	return {"ok":true,"job":id}
static func _milestone() -> void:
	var project: Dictionary=S()["project"]
	if not valid() or project.get("status","") not in ["building","paused"]:return
	if Clock.now()<int(project["delay_until"]):Sim.schedule(int(project["delay_until"]),"re.build",{});return
	var job := Jobs.get_job(project["job"])
	if float(job["progress"])<float(job["work"]):
		var amount := snappedf(float(project["budget"])-float(project["paid"]),.01) if float(job["progress"])+1>=float(job["work"]) else snappedf(float(project["budget"])/int(project["milestones"]),.01)
		var result := Jobs.purchase_milestone(project["job"],amount,1,"construction_in_progress")
		if not result["ok"]:
			project["status"]="paused"
			project["due"]=maxi(int(project["due"]),Clock.now()+Clock.DAY)
			Sim.schedule(Clock.now()+Clock.DAY,"re.build",{})
			return
		project["paid"]=snappedf(float(project["paid"])+amount,.01)
		project["status"]="building"
		project["next"]=Clock.now()+30*Clock.DAY
		Sim.schedule(int(project["next"]),"re.build",{})
	if float(job["progress"])>=float(job["work"]) and float(project["paid"])+.01<float(project["budget"]):
		var amount := snappedf(float(project["budget"])-float(project["paid"]),.01)
		if not Jobs.purchase_milestone(project["job"],amount,0,"construction_in_progress")["ok"]:
			project["status"]="paused"
			Sim.schedule(Clock.now()+Clock.DAY,"re.build",{})
			return
		project["paid"]=project["budget"]
	if float(job["progress"])>=float(job["work"]) and Clock.now()>=int(project["due"]):
		Jobs.deliver(project["job"])
		job["status"]="paid"
		project["status"]="completed"
		GameState.inc_stat("re_projects_completed")
		GameState.data["real_estate_landmark"]={"name":project["name"],"completed":true}
		var total := float(project["paid"])
		Ledger.post(entity(),I18n.t("Completed Lot 7 building"),[{"acct":"property_assets","dr":total},{"acct":"construction_in_progress","cr":total}],source(project["job"]))
		for n in int(project["units"]):
			var id := "tower_"+str(n+1)
			S()["properties"][id]={"id":id,"name":project["name"]+" · "+str(n+1),"entity":entity(),"base_price":float(cfg()["development_unit_price"]),"book":snappedf(total/int(project["units"]),.01),"uplift":0.0,"rent":float(cfg()["development_unit_rent"]),"base_rent":float(cfg()["development_unit_rent"]),"mortgage":"","status":"empty","screen":int(cfg()["default_screen"]),"tenant":{},"renovation":{}}
		# Last unit owns the rounding remainder, so sale/closure cannot leave an asset cent behind.
		S()["properties"]["tower_"+str(project["units"])]["book"]=snappedf(total-snappedf(total/int(project["units"]),.01)*(int(project["units"])-1),.01)
		GameState.timeline(I18n.t("Building completed: %s.")%project["name"],"milestone")
		EventBus.world_refresh.emit()
	elif float(job["progress"])>=float(job["work"]):Sim.schedule(int(project["due"]),"re.build",{})
static func sell(id: String) -> Dictionary:
	var property: Dictionary=S()["properties"].get(id,{})
	if not valid() or property.is_empty() or property["status"] not in ["empty","listed"] or not property["renovation"].is_empty():return error("Sell an empty finished unit.")
	var value := RealEstateMarket.value(property)
	var loan: Dictionary=Bank.B()["loans"].get(property["mortgage"],{})
	var owed := float(loan["balance"]) if not loan.is_empty() and loan["status"] in ["active","late","called"] else 0.0
	# Selling below the mortgage leaves a shortfall that must come out of company cash: refuse the sale if it can't.
	if owed>value+.005 and Ledger.cash(entity())+value<owed:
		return error("The sale would not cover the mortgage and the company cannot pay the shortfall. Raise cash or wait for prices to recover.")
	Ledger.post(entity(),I18n.t("Residential unit sold"),[{"acct":"cash","dr":value},{"acct":"revenue","cr":value},{"acct":"cogs","dr":property["book"]},{"acct":"property_assets","cr":property["book"]}],source(id))
	property["status"]="sold"
	Sim.cancel("re.tenant","id",id)
	if owed>0:
		var repaid := Bank.repay(loan["id"],owed)
		if not repaid.get("ok",false):push_warning("RealEstate: mortgage repayment failed after sale: "+str(repaid.get("error","")))
	return {"ok":true,"value":value,"shortfall":maxf(0,owed-value)}
## Market value minus mortgage, summed over every owned unit. `floor_at_zero` keeps each unit's equity non-negative
## (what the player sees as net worth); lending leaves it off, so a unit worth less than its mortgage reduces capacity.
static func equity(floor_at_zero := true) -> float:
	if not valid():return 0
	var total := 0.0
	for property in S()["properties"].values():
		if property["status"]=="sold":continue
		var loan: Dictionary=Bank.B()["loans"].get(property["mortgage"],{})
		var unit := RealEstateMarket.value(property)-float(loan.get("balance",0))
		total+=maxf(0,unit) if floor_at_zero else unit
	return total
static func handle(kind: String, payload: Dictionary) -> void:
	if not valid():return
	if kind=="re.build":_milestone();return
	if kind=="re.collect":
		var invoice: Dictionary=S()["invoices"].get(str(payload.get("id","")),{})
		if invoice.is_empty() or invoice["status"]!="unpaid":return
		var paid := GameState.rng.randf()<float(cfg()["collection_chance"])
		Ledger.post(entity(),I18n.t("Tenant arrears settled"),[{"acct":"cash" if paid else "exp:other","dr":invoice["amount"]},{"acct":"accounts_receivable","cr":invoice["amount"]}],source(invoice["id"]))
		invoice["status"]="paid" if paid else "written_off"
		return
	var id := str(payload.get("id",""))
	var property: Dictionary=S()["properties"].get(id,{})
	if property.is_empty() or property["status"]=="sold":return
	match kind:
		"re.tenant":
			if property["status"]!="listed" or Clock.now()<int(property["available"]):return
			var types: Array=cfg()["tenant_types"].keys()
			var type: String=types[GameState.rng.randi_range(0,types.size()-1)]
			var spec: Dictionary=cfg()["tenant_types"][type]
			var credit := GameState.rng.randi_range(int(spec["credit"][0]),int(spec["credit"][1]))
			if credit<int(property["screen"]):property["available"]=Clock.now()+int(cfg()["vacancy_base_days"])*Clock.DAY;Sim.schedule(int(property["available"]),"re.tenant",payload);return
			property["tenant"]={"type":type,"credit":credit,"name":cfg()["tenant_names"][GameState.rng.randi_range(0,cfg()["tenant_names"].size()-1)]}
			property["status"]="occupied"
			handle("re.rent",payload)
		"re.rent":
			if property["status"]!="occupied":return
			var spec: Dictionary=cfg()["tenant_types"][property["tenant"]["type"]]
			var unpaid := bool(property.get("force_arrears",false)) or GameState.rng.randf()<float(spec["arrears"])
			property["force_arrears"]=false
			var invoice := _id("RENT-")
			Ledger.post(entity(),I18n.t("Tenant monthly rent"),[{"acct":"accounts_receivable" if unpaid else "cash","dr":property["rent"]},{"acct":"revenue","cr":property["rent"]}],source(invoice))
			S()["invoices"][invoice]={"id":invoice,"property":id,"amount":property["rent"],"status":"unpaid" if unpaid else "paid","tenant":property["tenant"]["name"]}
			if unpaid:Sim.schedule(Clock.now()+30*Clock.DAY,"re.collect",{"id":invoice})
			if GameState.rng.randf()<float(spec["damage"]):Ledger.expense(entity(),"maintenance",float(cfg()["damage_cost"]),I18n.t("Tenant damage repair"),source(id),"cash" if Ledger.cash(entity())>=float(cfg()["damage_cost"]) else "accounts_payable")
			Sim.schedule(Clock.now()+30*Clock.DAY,"re.rent",payload)
		"re.renovation":
			var work: Dictionary=property["renovation"]
			if work.is_empty() or Clock.now()<int(work["due"]):return
			if GameState.rng.randf()<float(cfg()["overrun_chance"]):
				var extra := snappedf(float(work["cost"])*float(cfg()["overrun_fraction"]),.01)
				Ledger.post(entity(),I18n.t("Renovation budget overrun"),[{"acct":"property_assets","dr":extra},{"acct":"cash" if Ledger.cash(entity())>=extra else "accounts_payable","cr":extra}],source(id))
				property["book"]=float(property["book"])+extra
			property["uplift"]=maxf(float(property["uplift"]),float(cfg()["renovations"][work["grade"]]["uplift"]))
			property["renovation"]={}
static func crisis(kind: String, _retain := true) -> Dictionary:
	if not valid():return error("Open the brokerage first.")
	match kind:
		"rate":RealEstateMarket.S()["rate_shift"]=float(RealEstateMarket.S()["rate_shift"])+float(cfg()["rate_shock"]);RealEstateMarket.S()["month"]=-1;RealEstateMarket.update()
		"arrears":
			for property in S()["properties"].values():
				if property["status"]=="occupied":property["force_arrears"]=true;return {"ok":true}
		"delay","neighbors":
			var project: Dictionary=S()["project"]
			if project.get("status","") not in ["building","paused"]:return {"ok":true}
			var days := int(cfg()["development_delay_days"] if kind=="delay" else cfg()["neighbor_delay_days"])
			project["due"]=int(project["due"])+days*Clock.DAY
			project["delay_until"]=maxi(Clock.now(),int(project["delay_until"]))+days*Clock.DAY
			if kind=="neighbors":Ledger.expense(entity(),"compliance",float(cfg()["neighbor_cost"]),I18n.t("Neighbor mediation"),source(project["job"]),"cash" if Ledger.cash(entity())>=float(cfg()["neighbor_cost"]) else "accounts_payable")
			elif not project["overrun"]:
				project["overrun"]=true
				var extra := snappedf(float(project["budget"])*float(cfg()["material_increase"]),.01)
				project["budget"]=float(project["budget"])+extra
				Jobs.get_job(project["job"])["price"]=project["budget"]
			Sim.cancel("re.build", "", null)
			Sim.schedule(maxi(int(project["next"]),int(project["delay_until"])),"re.build",{})
		_:return error("Unknown property crisis.")
	return {"ok":true}
static func on_hour(_t: int, h: int) -> void:
	if not valid() or h!=9:return
	refresh()
	RealEstateMarket.update()
	if Clock.day_index()%30!=0:return
	for property in S()["properties"].values():
		if property["status"]=="sold":continue
		var cost := snappedf(RealEstateMarket.value(property)*float(cfg()["monthly_tax_rate"])+float(cfg()["monthly_management"]),.01)
		Ledger.expense(entity(),"other",cost,I18n.t("Property taxes and management"),source(property["id"]),"cash" if Ledger.cash(entity())>=cost else "accounts_payable")
static func on_company_closed(closed: String) -> void:
	if not is_running() or entity()!=closed:return
	for property in S()["properties"].values():
		if property["status"]=="sold":continue
		var book := float(property["book"])
		var sale := snappedf(RealEstateMarket.value(property)*float(cfg()["closure_recovery"]),.01)
		var lines := [{"acct":"cash","dr":sale},{"acct":"property_assets","cr":book}]
		lines.append({"acct":"other_income","cr":sale-book} if sale>=book else {"acct":"exp:other","dr":book-sale})
		Ledger.post(closed,I18n.t("Property closure auction"),lines,source(property["id"]))
		property["status"]="sold"
	var work := Ledger.balance(closed,"construction_in_progress")
	if work>0:Ledger.post(closed,I18n.t("Unfinished construction auction"),[{"acct":"cash","dr":snappedf(work*float(cfg()["closure_recovery"]),.01)},{"acct":"exp:other","dr":work-snappedf(work*float(cfg()["closure_recovery"]),.01)},{"acct":"construction_in_progress","cr":work}],source())
	S()["active"]=false
	GameState.set_flag("real_estate_active",false)
	S()["project"]["status"]="closed"
	for kind in ["re.build","re.tenant","re.rent","re.collect","re.renovation"]:Sim.cancel(kind, "", null)
static func lot_definition(base: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	var landmark: Dictionary=GameState.data.get("real_estate_landmark",{})
	var project: Dictionary=S()["project"]
	if landmark.get("completed",false):
		result["name"]=landmark["name"]
		result["exterior"]["sign"]=landmark["name"]
		result["exterior"]["sprite"]="venture_tower"
		result["exterior"]["fallback"]="apartment_mid"
		return result
	if not is_running() or project.is_empty():return result
	result["name"]=project["name"]
	result["exterior"]["sign"]=project["name"]
	result["exterior"]["sprite"]="venture_tower" if project["status"]=="completed" else "lot7_construction"
	result["exterior"]["fallback"]="apartment_mid" if project["status"]=="completed" else "warehouse_shed"
	return result
static func os_tab() -> Dictionary:return {"id":"real_estate","label":"Real Estate","icon":"home","order":6,"start_label":"Open Matchmaker","render":RealEstateUI.render}
static func board_detail() -> Callable:return RealEstateUI.board
static func open_action(_params: Dictionary,_source: Node) -> void:RealEstateUI.open()
