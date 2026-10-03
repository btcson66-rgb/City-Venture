class_name PopupStore
extends RefCounted
## Temporary stock is real Ecommerce inventory; every checkout carries COGS and a journal source.
static func cfg() -> Dictionary:return DataDB.economy["popup"]
static func S() -> Dictionary:
	if not GameState.data.has("popup"):GameState.data["popup"]={"active":{},"history":[]}
	return GameState.data["popup"]
static func active() -> Dictionary:return S()["active"]
static func next_weekend() -> int:
	var day:=int(Clock.now()/Clock.DAY)
	for offset in range(15):
		var t: int=(day+offset)*Clock.DAY+int(cfg()["open_hour"])*60
		if Clock.weekday(t)==6 and t>=Clock.now()+Clock.DAY:return t
	return 0
static func fail(message: String) -> Dictionary:return {"ok":false,"error":message}
static func sign(start: int) -> Dictionary:
	var ent:=GameState.company_id()
	if ent=="" or not GlobalMarket.live(ent):return fail("Register a company before reserving a weekend.")
	if not active().is_empty() or Living.D()["leases"].has("popup_retail"):return fail("A weekend is already reserved. Stock it or wait for its report.")
	if Living.D()["leases"].has("popup_cafe"):return fail("This unit already has a café tenant. Choose another sales channel.")
	if Clock.weekday(start)!=6 or start%Clock.DAY!=int(cfg()["open_hour"])*60 or start<Clock.now()+Clock.DAY:return fail("Choose Saturday 10:00 at least one day ahead.")
	if GameState.business_entity()!=ent:return fail("Open your company bank account before reserving stock and rent on its books.")
	var rent:=float(cfg()["rent_weekend"])
	if Ledger.cash(ent)<rent:return fail("Keep enough company cash for the weekend rent.")
	Ledger.expense(ent,"rent_shop",rent,I18n.t("Weekend pop-up rent: %s")%Fmt.money(rent),{"segment":"popup","type":"popup_rent"})
	S()["active"]={"entity":ent,"start":start,"end":start+Clock.DAY+int(cfg()["close_hour"]-cfg()["open_hour"])*60,"origins":{},"prices":{},"staff":{},"last_hour":-1,"owner_from":0,"owner_until":0,"score":0.5,"customers":0,"units":0,"revenue":0.0,"cogs":0.0,"fee":0.0,"wages":0.0,"move":0.0,"rent":rent,"hint_day":-1}
	Living.D()["leases"]["popup_retail"]={"entity":ent,"since":Clock.now(),"rent":rent,"day":0}
	Sim.schedule(int(active()["end"]),"popup.close",{"start":start})
	EventBus.world_refresh.emit()
	return {"ok":true}
static func is_open(t: int) -> bool:
	var a:=active()
	return not a.is_empty() and GlobalMarket.live(a["entity"]) and t>=int(a["start"]) and t<int(a["end"]) and t%Clock.DAY>=int(cfg()["open_hour"])*60 and t%Clock.DAY<int(cfg()["close_hour"])*60
static func return_reserved(loc: String) -> int:
	var total:=0
	var a: Dictionary=GameState.data.get("popup",{}).get("active",{})
	for rows in a.get("origins",{}).values():
		for row in rows:
			if row["loc"]==loc:total+=int(row["qty"])
	return total
static func move_stock(product: String,source: String,quantity: int) -> Dictionary:
	var a:=active()
	if a.is_empty() or not GlobalMarket.live(a["entity"]) or Clock.now()+int(cfg()["move_minutes"])>=int(a["end"]):return fail("Reserve a weekend with time left for moving stock.")
	if source not in Ecommerce.stock_locations() or quantity<=0 or quantity>Ecommerce.available(source,product):return fail("Choose available stock at your home or leased storage; committed orders stay there.")
	if Ecommerce.total_units_at("popup_retail")+quantity>int(cfg()["capacity"]):return fail("The pop-up is full. Sell stock or bring fewer units.")
	var vehicle: String=""
	var owns:=false
	for id in LogisticsDepth.vehicles():
		if LogisticsDepth.vehicles()[id].get("owned",false):
			owns=true
			if LogisticsDepth.available(id):vehicle=id;break
	if owns and vehicle=="":return fail("Your van is busy. Wait for it before moving stock.")
	var fee:=0.0 if vehicle!="" else float(cfg()["move_fee"])
	if Ledger.cash(a["entity"])<fee:return fail("Keep company cash for the one-hour moving service.")
	if fee>0:Ledger.expense(a["entity"],"shipping",fee,I18n.t("Pop-up stock transport: %s")%Fmt.money(fee),{"segment":"popup","type":"popup_move"})
	if vehicle!="":LogisticsDepth.vehicles()[vehicle]["busy_until"]=Clock.now()+int(cfg()["move_minutes"])
	var item: Dictionary=Ecommerce.inv(source)[product]
	Ecommerce._add_stock("popup_retail",product,quantity,float(item["avg_cost"]),float(item.get("defect_rate",0)))
	item["qty"]=int(item["qty"])-quantity
	if not a["origins"].has(product):a["origins"][product]=[]
	a["origins"][product].append({"loc":source,"qty":quantity})
	if not a["prices"].has(product):a["prices"][product]=float(DataDB.products[product]["ref_price"])
	a["move"]=float(a["move"])+fee
	Clock.advance(int(cfg()["move_minutes"]))
	EventBus.world_refresh.emit()
	return {"ok":true}
static func set_price(product: String,price: float) -> Dictionary:
	if not active().get("prices",{}).has(product) or not is_finite(price):return fail("Choose a stocked product and a finite price.")
	var p: Dictionary=DataDB.products[product]
	if price<float(p["price_min"]) or price>float(p["price_max"]):return fail("Choose a price within this product's allowed range.")
	active()["prices"][product]=snappedf(price,.01);return {"ok":true}
static func assigned_at(employee: String,t: int) -> bool:
	var a: Dictionary=GameState.data.get("popup",{}).get("active",{})
	return not a.is_empty() and t>=int(a["start"]) and t<int(a["end"]) and t%Clock.DAY>=600 and t%Clock.DAY<1080 and a["staff"].get(str(Clock.weekday(t)),"")==employee
static func assign(employee: String,weekday: int) -> Dictionary:
	if active().is_empty() or weekday not in [0,6] or not Staff.S()["people"].has(employee):return fail("Reserve a weekend, then choose a current employee for Saturday or Sunday.")
	active()["staff"][str(weekday)]=employee
	return {"ok":true}
static func owner_block() -> String:
	if not is_open(Clock.now()) or Clock.now()%Clock.DAY+int(cfg()["owner_minutes"])>int(cfg()["close_hour"])*60:return "Come back during weekend opening hours, with one hour before closing."
	if GameState.data["player"]["location"].get("id","")!="popup_unit":return "Go to Pop-up Unit 5 to work the checkout."
	if Ecommerce.total_units_at("popup_retail")==0:return "Bring some stock before working the checkout."
	return ""
static func owner_shift(score: float) -> Dictionary:
	var why:=owner_block()
	if why!="":return fail(why)
	if not is_finite(score):return fail("Finish checkout before starting your shift.")
	var a:=active();var before:=int(a["units"])
	a["owner_from"]=Clock.now();a["owner_until"]=Clock.now()+int(cfg()["owner_minutes"]);a["score"]=clampf(score,0,1)
	Clock.advance(int(cfg()["owner_minutes"]))
	return {"ok":true,"served":int(a["units"])-before}
static func open_till() -> void:
	var why:=owner_block()
	if why!="":UIRoot.toast(I18n.t(why),"warn","lock");return
	var game:=PopupCheckoutGame.new()
	MiniGames.play(game,func(result: Dictionary):
		if not result.get("aborted",false):
			var r:=owner_shift(float(result.get("score",.5)))
			UIRoot.toast(I18n.t("Checkout shift finished: %d units sold.")%int(r.get("served",0)) if r["ok"] else I18n.t(r["error"]),"info","cash"))
static func sell(product: String,quantity: int) -> void:
	var a:=active();var item: Dictionary=Ecommerce.inv("popup_retail")[product]
	var qty:=mini(quantity,int(item["qty"]))
	if qty<=0:return
	var revenue:=snappedf(qty*float(a["prices"][product]),.01)
	var cost:=snappedf(qty*float(item["avg_cost"]),.01)
	var fee:=snappedf(revenue*float(cfg()["card_fee"]),.01)
	Ledger.post(a["entity"],I18n.t("Pop-up checkout: %d units · %s")%[qty,Fmt.money(revenue)],[{"acct":"cash","dr":revenue-fee},{"acct":"exp:platform_fees","dr":fee},{"acct":"revenue","cr":revenue},{"acct":"cogs","dr":cost},{"acct":"inventory","cr":cost}],{"segment":"popup","type":"popup_sale","product":product,"qty":qty})
	item["qty"]=int(item["qty"])-qty
	var remaining:=qty
	for row in a["origins"][product]:
		var used:=mini(remaining,int(row["qty"]));row["qty"]=int(row["qty"])-used;remaining-=used
	for pair in [["units",qty],["revenue",revenue],["cogs",cost],["fee",fee]]:a[pair[0]]=a[pair[0]]+pair[1]
static func on_hour(t: int,_h: int) -> void:
	var a:=active();var t0:=t-60
	if not is_open(t0) or int(a["last_hour"])>=t:return
	a["last_hour"]=t
	var share:=clampf((mini(t,int(a["owner_until"]))-maxi(t0,int(a["owner_from"])))/60.0,0,1)
	var employee: String=a["staff"].get(str(Clock.weekday(t0)),"")
	var staffed: bool=Staff.S()["people"].has(employee) and int(Staff.S()["people"][employee].get("start",0))<=t0
	var wage:=float(cfg()["employee_hourly"])
	if staffed and Ledger.cash(a["entity"])<wage:staffed=false
	if staffed:
		Ledger.expense(a["entity"],"payroll",wage,I18n.t("Pop-up weekend hour: %s")%Fmt.money(wage),{"segment":"popup","type":"popup_wage","employee":employee})
		a["wages"]=float(a["wages"])+wage
	var capacity:=int(float(cfg()["owner_capacity_hour"])*share)+(int(cfg()["staff_capacity_hour"]) if staffed else 0)
	if capacity==0:
		if int(a["hint_day"])!=Clock.day_index_at(t0):
			a["hint_day"]=Clock.day_index_at(t0);GameState.add_message("sam","The pop-up is closed without checkout staff. Work there yourself or assign an employee for the day.")
		return
	var visitors:=GameState.poisson(float(cfg()["footfall_hour"])*float(cfg()["weekend_mult"]))
	a["customers"]=int(a["customers"])+visitors
	for i in visitors:
		if capacity<=0:break
		var stocked: Array=a["prices"].keys().filter(func(id):return Ecommerce.stock("popup_retail",id)>0)
		if stocked.is_empty():break
		var product: String=stocked[GameState.rng.randi_range(0,stocked.size()-1)]
		var conversion:=clampf(float(cfg()["base_conversion"])*pow(float(DataDB.products[product]["ref_price"])/float(a["prices"][product]),float(cfg()["price_elasticity"]))*(.75+float(a["score"])*.5 if share>0 else 1.0),0,1)
		if GameState.randf()<conversion:sell(product,1);capacity-=1
	if t>=int(a["end"]):finish()
static func report(a: Dictionary) -> Dictionary:
	var r:=a.duplicate(true)
	r["sales_revenue"]=r["revenue"] # Canonical Ledger account is revenue; never book the same sale twice.
	r["net"]=snappedf(float(r["revenue"])-float(r["cogs"])-float(r["rent"])-float(r["wages"])-float(r["move"])-float(r["fee"]),.01)
	r["shoplane_fee"]=snappedf(float(r["revenue"])*float(Ecommerce.mk().get("fee_rate",.1))+int(r["units"])*float(Ecommerce.mk().get("fixed_fee",0)),.01)
	r["shoplane_net"]=snappedf(float(r["revenue"])-float(r["cogs"])-float(r["shoplane_fee"]),.01)
	return r
static func finish() -> void:
	var a:=active()
	if a.is_empty():return
	for product in a["origins"]:
		var item: Dictionary=Ecommerce.inv("popup_retail").get(product,{})
		for row in a["origins"][product]:
			if int(row["qty"])>0 and not item.is_empty():Ecommerce._add_stock(row["loc"],product,int(row["qty"]),float(item["avg_cost"]),float(item.get("defect_rate",0)))
		if not item.is_empty():item["qty"]=0
	S()["history"].append(report(a));S()["active"]={}
	Living.D()["leases"].erase("popup_retail");EventBus.world_refresh.emit()
	EventBus.notify.emit("Weekend pop-up report is ready. Open the pop-up desk to compare channels.","info","shop")
	if Clock.world_active:UIRoot.open_modal(PopupStoreModal.new())
static func handle(kind: String,payload: Dictionary) -> void:
	if kind=="popup.close" and not active().is_empty() and int(active()["start"])==int(payload.get("start",-1)):
		on_hour(int(active()["end"]),int(cfg()["close_hour"]));finish()
static func on_company_closed(ent: String) -> void:
	if active().get("entity","")==ent:
		# Insolvency liquidates physical inventory after module closure. Never recreate it here.
		S()["history"].append(report(active()));S()["active"]={};Living.D()["leases"].erase("popup_retail")
static func is_running() -> bool:return not active().is_empty() or not S()["history"].is_empty()
static func os_tab() -> Dictionary:return {"id":"popup","label":"Weekend pop-up","icon":"shop","order":12,"render":render_tab}
static func render_tab(owner: Node) -> void:
	var b:=UIK.button("Pop-up stock, weekend staff and report",func():UIRoot.open_modal(PopupStoreModal.new()))
	b.name="PopupConsole";owner.get("content").add_child(b)
static func board_detail() -> Callable:return render_board
static func render_board(details: Control,_board: Node) -> void:
	details.add_child(UIK.wrap("A weekend sales channel for existing stock. Rent and checkout wages can cost more than you sell; this is not a full retail chain.",8,Art.C_MUTED,280))
	details.add_child(UIK.button("Reserve or manage a weekend",func():UIRoot.open_modal(PopupStoreModal.new())))
static func segment_tag() -> String:return "popup"
