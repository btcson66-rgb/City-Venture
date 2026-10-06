class_name Housing
extends RefCounted
## Real personal deposits and notice; a shared physical home moves every owned company's stock, never its money.
static func S() -> Dictionary:
	if not Living.D().has("housing"):Living.D()["housing"]={"deposits":{},"pending":{},"moves":0,"history":[]}
	return Living.D()["housing"]
static func opening() -> void:
	var amount:=float(Living.cfg().get("opening_home_deposit",0))
	if amount>0:
		Ledger.post("player",I18n.t("Opening tenant deposit held before arrival"),[{"acct":"home_deposit","dr":amount},{"acct":"equity","cr":amount}],{"type":"opening"})
		S()["deposits"][Living.home()]=amount
	Living.D()["home_property"]=Living.home()
static func views() -> Array:
	CompanyPortfolio.capture()
	var out: Array=[]
	for id in GameState.data["company_contexts"]:
		if id!="" and not GlobalMarket.live(id):continue
		var state: Dictionary=GameState.data["company_contexts"][id]["states"]
		if state.has("ecommerce"):out.append({"id":id,"ecommerce":state["ecommerce"],"contracts":state.get("contracts",{})})
	return out
static func units_at(pid: String,incoming := true) -> int:
	var total:=0
	for view in views():
		var state: Dictionary=view["ecommerce"]
		for item in state["inventory"].get(pid,{}).values():total+=int(item["qty"])
		for po in state["purchase_orders"].values():
			if incoming and po["location"]==pid and po["status"] in ["in_transit","awaiting_payment"]:total+=int(po["qty"])
		for order in state["orders"].values():
			if order["location"]==pid and order["status"] in ["packed","awaiting_pickup"]:total+=int(order["qty"])
	return total
static func fee() -> float:
	return snappedf(float(Living.cfg()["moving_fee"])+float(Living.cfg()["moving_unit_fee"])*units_at(Living.home(),false),.01)
static func capacity_block(pid: String) -> String:
	for view in views():
		var blocked: bool=CompanyPortfolio.run_in(view["id"],func():return PopupStore.return_reserved(Living.home())>0)
		if blocked:return "Finish the pop-up weekend before moving home. Its unsold stock must return to this home."
	var prop: Dictionary=DataDB.properties.get(pid,{})
	if prop.get("kind","")!="home" or not DataDB.buildings.has(prop.get("building","")):return "Choose a home that is available for moving."
	if prop.get("owner_purchase",false) and not PersonalAssets.owned(pid):return "Buy this home before arranging a move."
	if prop.get("owner_purchase",false) and PersonalAssets.owned(pid) and PersonalAssets.S()["homes"][pid]["status"] not in ["empty","occupied"]:return "Wait for the tenancy to end before moving into this home."
	if pid==Living.home():return "You already live here. Keep this lease or choose another home."
	var required:=units_at(Living.home())+units_at(pid)
	var capacity:=int(prop.get("inventory_units",prop.get("capacity",{}).get("inventory_units",0)))
	if required>capacity:return I18n.t("This home holds %d units; your stock and incoming orders need %d units. Sell stock or move it to leased storage first.")%[capacity,required]
	return ""
static func request(pid: String,mode: String) -> Dictionary:
	if Tutorial.first_venture_active():return {"ok":false,"error":"Finish the arrival tutorial before moving. Your first home stays at Riverside."}
	if not mode in ["notice","penalty"]:return {"ok":false,"error":"Choose thirty days' notice or pay one month's termination fee."}
	if not S()["pending"].is_empty():return {"ok":false,"error":"A move is already booked. Keep it, cancel it or resolve the storage problem."}
	var why:=capacity_block(pid)
	if why!="":return {"ok":false,"error":why}
	var deposit:=0.0 if DataDB.properties[pid].get("owner_purchase",false) else snappedf(float(DataDB.properties[pid]["monthly_rent"])*World.rent_mult(),.01)
	var penalty:=Living.home_rent() if mode=="penalty" else 0.0
	var needed:=deposit+fee()+penalty
	if Ledger.cash("player")<needed:return {"ok":false,"error":I18n.t("Keep %s personally for the new deposit, moving and termination costs.")%Fmt.money(needed)}
	Ledger.post("player",I18n.t("Home deposit paid: %s")%Fmt.money(deposit),[{"acct":"home_deposit","dr":deposit},{"acct":"cash","cr":deposit}],{"type":"home_lease","property":pid})
	S()["deposits"][pid]=deposit
	S()["pending"]={"from":Living.home(),"to":pid,"mode":mode,"ready":Clock.now()+(int(Living.cfg()["notice_days"])*Clock.DAY if mode=="notice" else 0),"stage":"notice"}
	if mode=="penalty":return execute()
	return {"ok":true}
static func cancel() -> Dictionary:
	var pending: Dictionary=S()["pending"]
	if pending.is_empty():return {"ok":true}
	var pid: String=pending["to"]
	var deposit:=float(S()["deposits"].get(pid,0))
	if deposit>0:Ledger.post("player",I18n.t("Reserved home deposit returned: %s")%Fmt.money(deposit),[{"acct":"cash","dr":deposit},{"acct":"home_deposit","cr":deposit}],{"type":"home_lease_cancel","property":pid})
	S()["deposits"].erase(pid);S()["pending"]={}
	return {"ok":true}
static func execute() -> Dictionary:
	var pending: Dictionary=S()["pending"]
	if pending.is_empty():return {"ok":false,"error":"No move is booked. Choose a home first."}
	if Clock.now()<int(pending["ready"]):return {"ok":false,"error":"The notice period is still running. Keep living here or cancel the reservation."}
	var why:=capacity_block(str(pending["to"]))
	var penalty:=Living.home_rent() if pending["mode"]=="penalty" else 0.0
	var moving:=fee()
	if why=="" and Ledger.cash("player")<penalty+moving:why="Keep enough personal cash for the agreed moving and termination costs."
	if why!="":pending["stage"]="blocked";return {"ok":false,"error":why}
	var old: String=pending["from"]
	var target: String=pending["to"]
	if penalty>0:Ledger.expense("player","rent_home",penalty,I18n.t("Home termination fee: %s")%Fmt.money(penalty),{"type":"home_termination","property":old})
	if moving>0:Ledger.expense("player","moving",moving,I18n.t("Moving service: %s")%Fmt.money(moving),{"type":"home_move"})
	var refund:=float(S()["deposits"].get(old,0))
	if refund>0:Ledger.post("player",I18n.t("Previous home deposit returned: %s")%Fmt.money(refund),[{"acct":"cash","dr":refund},{"acct":"home_deposit","cr":refund}],{"type":"home_lease_end","property":old})
	S()["deposits"].erase(old)
	# A lease record for the home being left would keep charging rent and could never be ended later.
	if Living.D()["leases"].has(old) and str(DataDB.properties.get(old, {}).get("kind", "")) == "home": Living.D()["leases"].erase(old)
	PersonalAssets.released(old)
	move_stock(old,target)
	GameState.data["player"]["home"]=target
	Living.D()["home_property"]=target
	if PersonalAssets.owned(target):PersonalAssets.S()["homes"][target]["status"]="occupied"
	S()["moves"]=int(S()["moves"])+1
	S()["history"].append({"from":old,"to":target,"t":Clock.now(),"penalty":penalty,"moving":moving,"refund":refund})
	S()["pending"]={}
	GameState.timeline(I18n.t("Moved to %s; monthly rent %s.")%[I18n.t(DataDB.properties[target]["name"]),Fmt.money(Living.home_rent())],"home")
	EventBus.world_refresh.emit()
	return {"ok":true}
static func move_stock(old: String,target: String) -> void:
	for view in views():
		var state: Dictionary=view["ecommerce"]
		var inventory: Dictionary=state["inventory"]
		if not inventory.has(target):inventory[target]={}
		for product in inventory.get(old,{}):
			var stock: Dictionary=inventory[old][product]
			var dest: Dictionary=inventory[target].get(product,{"qty":0,"avg_cost":0.0,"defect_rate":0.0})
			var count:=int(dest["qty"])+int(stock["qty"])
			if count>0:
				dest["avg_cost"]=(float(dest["avg_cost"])*int(dest["qty"])+float(stock["avg_cost"])*int(stock["qty"]))/count
				dest["defect_rate"]=(float(dest["defect_rate"])*int(dest["qty"])+float(stock["defect_rate"])*int(stock["qty"]))/count
			dest["qty"]=count
			inventory[target][product]=dest
		inventory.erase(old)
		for field in ["purchase_orders","orders"]:
			for item in state[field].values():
				if item.get("location","")==old:item["location"]=target
		for item in view["contracts"].values():
			if item.get("location","")==old:item["location"]=target
	for key in HoldingGroups.S()["margin"].keys():
		if str(key).get_slice(":",1)==old:
			var amount:=float(HoldingGroups.S()["margin"][key])
			HoldingGroups.margin_change(key,-amount)
			HoldingGroups.margin_change(str(key).replace(":"+old+":",":"+target+":"),amount)
static func on_hour() -> void:
	var pending: Dictionary=S()["pending"]
	if not pending.is_empty() and pending["stage"]=="notice" and Clock.now()>=int(pending["ready"]):
		var result:=execute()
		if not result["ok"]:EventBus.notify.emit(I18n.t(result["error"]),"warn","home")
