class_name PersonalAssets
extends RefCounted
## Personal property and vehicles remain outside company contexts and survive business closure.
static func cfg() -> Dictionary:return DataDB.economy["personal_assets"]
static func S() -> Dictionary:
	if not Living.D().has("personal_assets"):Living.D()["personal_assets"]={"homes":{},"car":{},"style":{},"visits":[],"parking":{},"month":-1}
	return Living.D()["personal_assets"]
static func error(text: String) -> Dictionary:return {"ok":false,"error":I18n.t(text)}
static func owned(id: String) -> bool:return S()["homes"].get(id,{}).get("status","") not in ["","sold"]
static func price(id: String) -> float:return snappedf(float(DataDB.properties[id]["purchase_price"])*market_index(),.01)
static func buy_home(id: String,down: float,years: int) -> Dictionary:
	if Tutorial.first_venture_active() or not Housing.S()["pending"].is_empty():return error("Finish arrival and cancel any reserved move before buying a home.")
	var prop: Dictionary=DataDB.properties.get(id,{})
	var terms:=RealEstate.cfg()
	if not prop.get("owner_purchase",false) or owned(id):return error("Choose a home you do not already own.")
	if int(prop["tier"])>1 and not S()["homes"].values().any(func(h):return int(h["tier"])==int(prop["tier"])-1):return error("Buy the previous housing tier first; it remains an asset you may sell or rent.")
	if not is_finite(down) or down<float(terms["down_min"]) or down>float(terms["down_max"]) or years<int(terms["mortgage_year_min"]) or years>int(terms["mortgage_year_max"]) or personal_credit()<int(terms["mortgage_credit"]):return error("Mortgage terms require 20–30% down and 20–30 years.")
	var value:=price(id)
	var deposit:=snappedf(value*down,.01)
	var fee:=snappedf(value*float(cfg()["purchase_fee"]),.01)
	if Ledger.cash("player")<deposit+fee:return error("Save the down payment and purchase fee personally first.")
	var debt:=value-deposit
	Ledger.post("player",I18n.t("Personal home purchase: %s")%Fmt.money(value),[{"acct":"property_assets","dr":value},{"acct":"cash","cr":deposit},{"acct":"loan_payable","cr":debt}],{"type":"personal_home","id":id})
	Ledger.expense("player","other",fee,I18n.t("Home purchase fee: %s")%Fmt.money(fee),{"type":"personal_home"})
	S()["homes"][id]={"status":"empty","tier":prop["tier"],"book":value,"base_price":prop["purchase_price"],"balance":debt,"months":years*12,"paid_n":0,"next":Clock.now()+30*Clock.DAY,"arrears":0,"tenant":{},"rent":0.0,"invoices":[]}
	GameState.timeline(I18n.t("Purchased home: %s.")%I18n.t(prop["name"]),"home")
	return {"ok":true}
static func move_home(id: String) -> Dictionary:
	if not owned(id) or S()["homes"][id]["status"] not in ["empty","occupied"]:return error("Wait for the tenancy to end before moving into this home.")
	var result:=Housing.request(id,"penalty")
	if result["ok"]:S()["homes"][id]["status"]="occupied"
	return result
static func released(id: String) -> void:
	if owned(id) and S()["homes"][id]["status"]=="occupied":S()["homes"][id]["status"]="empty"
static func sell_home(id: String) -> Dictionary:
	if not owned(id) or Living.home()==id or S()["homes"][id]["status"]=="tenanted":return error("Move out or end the tenancy with notice before selling.")
	var h: Dictionary=S()["homes"][id]
	var proceeds:=snappedf(snappedf(float(h["base_price"])*market_index(),.01)*(1-float(cfg()["sale_fee"])),.01)
	var principal:=float(h["balance"])
	var arrears:=float(h["arrears"])
	var debt:=principal+arrears
	if h["invoices"].any(func(row):return not row["paid"]):return error("Collect outstanding tenant invoices before selling; wait thirty days after each invoice.")
	if Ledger.cash("player")+proceeds<debt:return error("Sale proceeds do not cover the mortgage. Save the shortfall or keep the home.")
	Ledger.post("player",I18n.t("Home sale after fees: %s")%Fmt.money(proceeds),[{"acct":"cash","dr":proceeds},{"acct":"other_income","cr":proceeds},{"acct":"exp:other","dr":h["book"]},{"acct":"property_assets","cr":h["book"]}],{"type":"personal_home_sale","id":id})
	if debt>0:Ledger.post("player",I18n.t("Mortgage repaid: %s")%Fmt.money(debt),[{"acct":"loan_payable","dr":principal},{"acct":"accounts_payable","dr":arrears},{"acct":"cash","cr":debt}],{"type":"personal_home"})
	h["balance"]=0;h["arrears"]=0;h["status"]="sold"
	return {"ok":true,"value":proceeds}
static func rent_home(id: String,ratio: float) -> Dictionary:
	if not owned(id) or Living.home()==id or S()["homes"][id]["status"] not in ["empty","listed"] or not is_finite(ratio) or ratio<float(RealEstate.cfg()["rent_min"]) or ratio>float(RealEstate.cfg()["rent_max"]):return error("Move out and choose valid rent terms before listing this home.")
	var h: Dictionary=S()["homes"][id]
	h["rent"]=snappedf(float(DataDB.properties[id]["monthly_rent"])*ratio,.01);h["status"]="listed";h["available"]=Clock.now()+RealEstate.vacancy_days(ratio,int(RealEstate.cfg()["default_screen"]))*Clock.DAY
	return {"ok":true}
static func end_tenancy(id: String) -> Dictionary:
	if not owned(id):return error("Choose an owned home first.")
	var h: Dictionary=S()["homes"][id]
	if h["status"]=="listed":h["status"]="empty";return {"ok":true}
	if h["status"]!="tenanted":return error("This home has no tenant. Move in, list it or sell it.")
	if not h.has("leave"):h["leave"]=Clock.now()+int(cfg()["move_notice_days"])*Clock.DAY
	return {"ok":true}
static func on_hour() -> void:
	if not S()["homes"].is_empty():CompanyPortfolio.run_in("",func():RealEstateMarket.update())
	for id in S()["homes"]:
		var h: Dictionary=S()["homes"][id]
		if h["status"]=="sold":continue
		if h.has("leave") and Clock.now()>=int(h["leave"]):h["status"]="empty";h["tenant"]={};h.erase("leave")
		if h["status"]=="listed" and Clock.now()>=int(h["available"]):
			if GameState.rng.randf()<float(cfg()["tenant_chance"]):
				h["status"]="tenanted";h["tenant"]={"name":RealEstate.cfg()["tenant_names"].pick_random()}
			else:h["available"]=Clock.now()+int(cfg()["vacancy_days"])*Clock.DAY
		if Clock.now()<int(h["next"]):continue
		h["next"]=Clock.now()+30*Clock.DAY
		var cost:=float(DataDB.properties[id]["management_month"])+float(h["book"])*(float(RealEstate.cfg()["monthly_tax_rate"])+float(cfg()["maintenance_rate"]))
		Ledger.expense("player","other",cost,I18n.t("Home management, maintenance and tax: %s")%Fmt.money(cost),{"type":"personal_home_cost","id":id})
		if float(h["balance"])>0:
			var rate:=market_rate()+float(RealEstate.cfg()["mortgage_margin"])
			var interest:=snappedf(float(h["balance"])*rate/12,.01)
			var due:=minf(Bank.monthly_payment(float(h["balance"]),maxi(1,int(h["months"])-int(h["paid_n"])),rate)+float(h["arrears"]),float(h["balance"])+interest+float(h["arrears"]))
			if Ledger.cash("player")>=due:
				var principal:=maxf(0,due-interest-float(h["arrears"]))
				Ledger.post("player",I18n.t("Personal mortgage payment: %s")%Fmt.money(due),[{"acct":"loan_payable","dr":principal},{"acct":"exp:interest","dr":interest},{"acct":"accounts_payable","dr":h["arrears"]},{"acct":"cash","cr":due}],{"type":"personal_mortgage","id":id})
				h["balance"]=snappedf(float(h["balance"])-principal,.01);h["arrears"]=0;h["paid_n"]=int(h["paid_n"])+1
			else:
				Ledger.post("player",I18n.t("Unpaid mortgage interest: %s")%Fmt.money(interest),[{"acct":"exp:interest","dr":interest},{"acct":"accounts_payable","cr":interest}],{"type":"personal_mortgage","id":id});h["arrears"]=float(h["arrears"])+interest
				EventBus.notify.emit(I18n.t("Mortgage unpaid. Raise personal cash, rent another home or sell an empty property."),"warn","home")
		if h["status"]=="tenanted":
			var rent:=float(h["rent"])
			var paid:=GameState.rng.randf()<float(cfg()["rent_payment_chance"])
			Ledger.post("player",I18n.t("Tenant rent invoice: %s")%Fmt.money(rent),[{"acct":"cash" if paid else "accounts_receivable","dr":rent},{"acct":"revenue","cr":rent}],{"type":"personal_rent","tenant":h["tenant"]["name"],"id":id})
			h["invoices"].append({"t":Clock.now(),"amount":rent,"paid":paid})
			Ledger.expense("player","other",rent*float(cfg()["management_rate"]),I18n.t("Rental management fee: %s")%Fmt.money(rent*float(cfg()["management_rate"])),{"type":"personal_rent","id":id})
	var month:=Clock.day_index()/30
	if not S()["car"].is_empty() and int(S()["month"])!=month:
		S()["month"]=month;Ledger.expense("player","insurance",float(cfg()["insurance_month"]),I18n.t("Personal car insurance: %s")%Fmt.money(float(cfg()["insurance_month"])),{"type":"personal_car"})
static func buy_car(id: String) -> Dictionary:
	var loc: Dictionary=GameState.data["player"]["location"]
	if loc["kind"]!="interior" or DataDB.buildings.get(loc["id"],{}).get("type","") not in ["van_dealer","auto_dealer"]:return error("Visit Dockside Motors or the dealership to buy a personal car.")
	if not S()["car"].is_empty():return error("Sell the current personal car before buying another.")
	var models: Array=cfg()["cars"].filter(func(c):return c["id"]==id)
	if models.is_empty():return error("Choose a car from the personal showroom.")
	var c: Dictionary=models[0].duplicate(true)
	if Ledger.cash("player")<float(c["price"])+float(cfg()["insurance_month"]):return error("Save the car price personally first.")
	Ledger.post("player",I18n.t("Personal car purchase: %s")%Fmt.money(float(c["price"])),[{"acct":"personal_vehicle","dr":c["price"]},{"acct":"cash","cr":c["price"]}],{"type":"personal_car"})
	c["location"]=str(DataDB.buildings[loc["id"]]["district"]);c["energy"]=cfg()["electric_capacity"];c["service"]=Clock.now()+int(cfg()["service_days"])*Clock.DAY
	S()["car"]=c;S()["month"]=Clock.day_index()/30
	Ledger.expense("player","insurance",float(cfg()["insurance_month"]),I18n.t("Personal car insurance: %s")%Fmt.money(float(cfg()["insurance_month"])),{"type":"personal_car"})
	GameState.timeline(I18n.t("Bought personal car: %s.")%I18n.t(c["name"]),"life")
	return {"ok":true}
static func metro_minutes(from: String,to: String) -> int:
	var routes: Dictionary=DataDB.city["metro"]["travel_min"]
	return 0 if from==to else int(routes.get(from+">"+to,routes.get(to+">"+from,15)))
static func trip(from: String,to: String,hour: int) -> Dictionary:
	var rush: bool=hour in cfg()["rush_hours"].map(func(x):return int(x))
	var downtown: bool=to in cfg()["downtown"]
	var driving:=maxi(1,ceili(metro_minutes(from,to)*float(cfg()["drive_ratio"])*(float(cfg()["rush_ratio"]) if rush else 1)))
	var parking:=int(cfg()["rush_parking_minutes"] if rush and downtown else cfg()["parking_minutes"])
	var fee:=float(cfg()["downtown_fee"] if downtown else cfg()["parking_fee"])
	return {"minutes":driving+parking,"drive":driving,"parking":fee,"fuel":snappedf(driving*float(cfg()["fuel_per_minute"]),.01),"kwh":snappedf(driving*float(cfg()["electric_per_minute"]),.01)}
static func drive(to: String) -> Dictionary:
	var c: Dictionary=S()["car"]
	var loc: Dictionary=GameState.data["player"]["location"]
	var from: String=loc["id"] if loc["kind"]=="district" else DataDB.buildings[loc["id"]]["district"]
	if c.is_empty() or c["location"]!=from:return error("Your personal car is parked elsewhere. Take the metro back to it.")
	if not DataDB.districts.has(to) or not BuildingInfo.district_open(to) or from==to:return error("Choose another open district.")
	var q:=trip(from,to,int(Clock.date()["hour"]))
	var day:=Clock.day_index()
	var used:=int(S()["parking"].get(to+":"+str(day),0))
	if to in cfg()["downtown"] and used>=int(cfg()["parking_spaces"]):return error("Central parking is full today. Take the metro or drive to another district.")
	var energy:=float(q["kwh"])
	var service:=float(cfg()["service_cost"]) if Clock.now()>=int(c["service"]) else 0.0
	if c["electric"] and float(c["energy"])<energy:return error("Charge at an open Helio station before driving, or take the metro.")
	var cost: float=float(q["parking"])+service+(0 if c["electric"] else float(q["fuel"]))
	if Ledger.cash("player")<cost:return error("Keep personal cash for parking, fuel and due maintenance, or take the metro.")
	Ledger.expense("player","transport",cost,I18n.t("Driving, parking and maintenance: %s")%Fmt.money(cost),{"type":"personal_drive","to":to})
	if service>0:c["service"]=Clock.now()+int(cfg()["service_days"])*Clock.DAY
	if c["electric"]:c["energy"]=float(c["energy"])-energy
	c["location"]=to;S()["parking"][to+":"+str(day)]=used+1
	SceneRouter.personal_drive(to,int(q["minutes"]))
	return {"ok":true,"close":true}
static func charge() -> Dictionary:
	var c: Dictionary=S()["car"]
	if c.is_empty() or not c["electric"]:return error("Choose an electric personal car first.")
	var loc: Dictionary=GameState.data["player"]["location"]
	var district: String=loc["id"] if loc["kind"]=="district" else DataDB.buildings[loc["id"]]["district"]
	if district!=c["location"]:return error("Your personal car is parked elsewhere. Take the metro back to it.")
	var sites: Array=Energy.open_stations().filter(func(s):return s["district"]==c["location"] and Energy.station_ok(s))
	if sites.is_empty():return error("Park beside an open Helio charging station first.")
	var amount:=maxf(0,float(cfg()["electric_capacity"])-float(c["energy"]))
	var price:=float(sites[0]["price"])
	var cost:=snappedf(amount*price,.01)
	if amount<=0:return error("The battery is already full. Choose a destination.")
	if Ledger.cash("player")<cost:return error("Save the charging cost or take the metro.")
	Ledger.expense("player","transport",cost,I18n.t("EV charging: %s")%Fmt.money(cost),{"type":"personal_charge","kwh":amount})
	Ledger.post(Energy.entity(),I18n.t("Personal EV metered charging: %s")%Fmt.money(cost),[{"acct":"cash","dr":cost},{"acct":"revenue","cr":cost}],Energy.source("personal_charge"))
	Ledger.expense(Energy.entity(),"other",amount*Energy.grid_cost(),I18n.t("EV grid electricity"),Energy.source("personal_charge"))
	c["energy"]=cfg()["electric_capacity"];Clock.advance(30)
	return {"ok":true}
static func decorate(style: String) -> Dictionary:
	if not cfg()["furniture"].has(style):return error("Choose an available furniture style.")
	if S()["style"].get(Living.home(),"")==style:return error("This furniture style is already installed. Keep it or choose another.")
	var spec: Dictionary=cfg()["furniture"][style]
	if Ledger.cash("player")<float(spec["cost"]):return error("Save the furniture cost personally first.")
	Ledger.expense("player","other",float(spec["cost"]),I18n.t("Home decoration: %s")%Fmt.money(float(spec["cost"])),{"type":"home_decoration"})
	S()["style"][Living.home()]=style
	if Clock.world_active and SceneRouter.world_scene()!=null:SceneRouter.reenter_current()
	return {"ok":true}
static func host(npc: String) -> Dictionary:
	if not DataDB.npcs.has(npc) or not GameState.flag("met_"+npc):return error("Meet this person first, then invite them home.")
	var prop: Dictionary=DataDB.properties[Living.home()]
	var count: int=S()["visits"].filter(func(v):return int(v["day"])==Clock.day_index()).size()
	if count>=int(prop.get("guests",1)):return error("Today's home invitations are full. Meet elsewhere or invite them tomorrow.")
	if S()["visits"].any(func(v):return v["npc"]==npc and int(v["day"])==Clock.day_index()):return error("This guest already visited today. Invite someone else or meet tomorrow.")
	S()["visits"].append({"npc":npc,"day":Clock.day_index(),"home":Living.home()})
	var luxury: bool=not S()["car"].is_empty() and S()["car"]["luxury"]
	var text:=I18n.t("We can talk over the table here. The warm wood makes this room feel welcoming.") if S()["style"].get(Living.home(),"")=="warm" else I18n.t("The clean blue lines suit this room. Let's talk about your plans.") if S()["style"].get(Living.home(),"")=="modern" else I18n.t("Thank you for inviting me. Let's sit down and talk.")
	if luxury:text+=" "+I18n.t("I noticed the coupe outside. It must be expensive to keep.")
	GameState.add_message(npc,text);GameState.timeline(I18n.t("Hosted %s at home.")%DataDB.npcs[npc]["name"],"life");Clock.advance(60)
	return {"ok":true}

static func sell_car() -> Dictionary:
	var c: Dictionary=S()["car"]
	if c.is_empty():return error("You have no personal car to sell. Take the metro or buy one.")
	var value:=snappedf(float(c["price"])*float(cfg()["car_resale_ratio"]),.01)
	Ledger.post("player",I18n.t("Personal car sold: %s")%Fmt.money(value),[{"acct":"cash","dr":value},{"acct":"exp:other","dr":float(c["price"])-value},{"acct":"personal_vehicle","cr":c["price"]}],{"type":"personal_car_sale"})
	S()["car"]={};return {"ok":true}
static func collect_rent(id: String) -> Dictionary:
	if not owned(id):return error("Choose an owned home first.")
	var paid:=0.0
	for row in S()["homes"][id]["invoices"]:
		if not row["paid"] and Clock.now()>=int(row["t"])+30*Clock.DAY:
			row["paid"]=true;paid+=float(row["amount"])
	if paid<=0:return error("No overdue tenant invoices are ready. Wait thirty days after the invoice.")
	Ledger.post("player",I18n.t("Collected tenant invoices: %s")%Fmt.money(paid),[{"acct":"cash","dr":paid},{"acct":"accounts_receivable","cr":paid}],{"type":"personal_rent_collect","id":id})
	return {"ok":true}

static func commute(to: String,hour: int,driving: bool) -> int:
	var p: Dictionary=DataDB.properties[Living.home()]
	var from: String=p.get("district",DataDB.buildings[p["building"]]["district"])
	return int(trip(from,to,hour)["minutes"]) if driving else metro_minutes(from,to)+int(p.get("metro_access_minutes",5))

## Resolve household market/credit in the personal context: switching companies cannot refresh a home's price.
static func market_index() -> float:return float(CompanyPortfolio.run_in("",func():return RealEstateMarket.index()))
static func market_rate() -> float:return float(CompanyPortfolio.run_in("",func():return RealEstateMarket.rate()))
static func personal_credit() -> int:return int(CompanyPortfolio.run_in("",func():return Bank.credit()))
