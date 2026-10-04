class_name CompanyPortfolio
extends RefCounted
## Active operational views are backed by per-company records. Entity-tagged scheduled work restores the viewer afterwards.
static func cfg() -> Dictionary:
	return DataDB.economy["holding_groups"]
static func active_of(data: Dictionary) -> String:
	var value = data.get("company","")
	return str(data.get("active_company","")) if value is Array else str(value)
static func migrate(data: Dictionary) -> void:
	var value = data.get("company","")
	if not value is Array:
		# Attach pre-portfolio jobs before any view can be switched.
		for item in data.get("schedule",[]):
			if str(item.get("kind","")).get_slice(".",0) in cfg()["business_prefixes"] and item.get("kind","")!="bank.appointment":
				if not item["p"].has("company_context"): item["p"]["company_context"]=str(value)
		data["company"] = [] if str(value)=="" else [str(value)]
		data["active_company"] = str(value)
	if not data.has("active_company"): data["active_company"]=""
	if not data.has("company_contexts"): data["company_contexts"]={}
	_migrate_trade_owner(data)
static func _migrate_trade_owner(data: Dictionary) -> void:
	# Before trade entered the portfolio registry, one global brokerage could be shown in another company's view.
	if not data.get("trade",{}) is Dictionary:return
	var trade: Dictionary=data.get("trade",{})
	var owner: String=str(trade.get("entity",""))
	if owner=="" or not owner in data["company"]:return
	for item in data.get("schedule",[]):
		if str(item.get("kind","")).get_slice(".",0)=="trade" and not item["p"].has("company_context"):
			item["p"]["company_context"]=owner
	for inst in data.get("events",{}).get("queue",[]):
		if inst["id"] in ["trade_port_strike","trade_fx_volatility"] and not inst["ctx"].has("trade_entity"):
			inst["ctx"]["trade_entity"]=owner
			inst["ctx"]["company"]=str(data["entities"].get(owner,{}).get("name",owner))
	for inst in data.get("events",{}).get("queue",[]):
		if inst["id"]!="trade_port_strike" or inst["ctx"].has("reroute_fee"):continue
		var cargo: Dictionary=trade.get("deals",{}).get(str(inst["ctx"].get("trade","")),{})
		if not cargo.is_empty():
			var air: Dictionary=DataDB.economy.get("trade",{}).get("transport",{}).get("air",{})
			inst["ctx"]["reroute_fee"]=Fmt.money(float(air.get("base_fee",0))+float(air.get("unit_fee",0))*int(cargo.get("quantity",0)))
	var active:=active_of(data)
	if owner==active:return
	var view: Dictionary=data["company_contexts"].get(owner,{"states":{},"flags":{},"bank":{}})
	view["states"]["trade"]=trade
	view["flags"]["trade_active"]=bool(trade.get("active",false))
	data["company_contexts"][owner]=view
	var saved_trade: Variant=data["company_contexts"].get(active,{}).get("states",{}).get("trade",{})
	var selected: Dictionary=saved_trade if saved_trade is Dictionary else {}
	if not selected.is_empty() and str(selected.get("entity",""))==active:
		data["trade"]=selected
	else:data.erase("trade")
	data["flags"]["trade_active"]=bool(selected.get("active",false)) if str(selected.get("entity",""))==active else false
static func ids(include_closed := false) -> Array:
	migrate(GameState.data)
	return GameState.data["company"].filter(func(id):return include_closed or GlobalMarket.live(str(id)))
static func capture() -> void:
	var id := active_of(GameState.data)
	migrate(GameState.data)
	var view := {"states":{},"flags":{},"bank":{}}
	for key in cfg()["context_keys"]:
		if GameState.data.has(key): view["states"][key]=GameState.data[key]
	for flag in cfg()["company_flags"]: view["flags"][flag]=GameState.flag(flag)
	for key in ["credit","no_loans_until"]:
		if Bank.B().has(key): view["bank"][key]=Bank.B()[key]
	GameState.data["company_contexts"][id]=view
static func apply(id: String) -> void:
	migrate(GameState.data)
	var view: Dictionary = GameState.data["company_contexts"].get(id,{"states":{},"flags":{},"bank":{}})
	var template := GameState.template()
	for key in cfg()["context_keys"]:
		if view["states"].has(key): GameState.data[key]=view["states"][key]
		elif template.has(key): GameState.data[key]=template[key].duplicate(true) if template[key] is Dictionary or template[key] is Array else template[key]
		else: GameState.data.erase(key)
	for flag in cfg()["company_flags"]: GameState.data["flags"][flag]=bool(view["flags"].get(flag,false))
	for key in ["credit","no_loans_until"]: Bank.B().erase(key)
	Bank.B()["credit"]=int(view["bank"].get("credit",cfg()["default_credit"]))
	if view["bank"].has("no_loans_until"): Bank.B()["no_loans_until"]=view["bank"]["no_loans_until"]
	GameState.data["active_company"]=id
	if id!="": GameState.data["flags"]["company_registered"]=true
static func switch(id: String, notify := true, allow_closed := false) -> Dictionary:
	if id==active_of(GameState.data): return {"ok":true}
	if id!="" and (not ids(true).has(id) or (not allow_closed and not GlobalMarket.live(id))): return {"ok":false,"error":"This company is closed or unavailable. Choose another live company."}
	capture()
	apply(id)
	if notify: EventBus.world_refresh.emit()
	return {"ok":true}
static func register_new(id: String) -> void:
	var previous := active_of(GameState.data)
	var had_company := not ids(true).is_empty()
	var inherited_bank := {}
	var terminal_contracts := {}
	if previous=="" and ids().is_empty():
		terminal_contracts=GameState.data["contracts"].duplicate(true)
		for key in ["credit","no_loans_until"]:
			if Bank.B().has(key):inherited_bank[key]=Bank.B()[key]
	if had_company:
		capture()
		apply("")
		# A new entity never inherits the previous firm's receipts or employees.
		GameState.data["company_contexts"].erase(id)
		apply(id)
	if not inherited_bank.is_empty():Bank.B().merge(inherited_bank,true)
	if not terminal_contracts.is_empty():GameState.data["contracts"].merge(terminal_contracts)
	GameState.data["company"].append(id)
	GameState.data["active_company"]=id
	if not had_company and previous=="":
		for item in GameState.data["schedule"]:
			if item["p"].get("company_context",null)=="":item["p"]["company_context"]=id
		capture()
	HoldingGroups.S()["basis"][id]=0.0
static func run_in(id: String, fn: Callable) -> Variant:
	var previous := active_of(GameState.data)
	if id==previous: return fn.call()
	var result := switch(id,false,true)
	if not result["ok"]: return null
	var output = fn.call()
	capture()
	apply(previous if previous=="" or GlobalMarket.live(previous) else "")
	return output
static func on_closed(id: String) -> void:
	var inherited := {}
	for key in ["credit","no_loans_until"]:
		if Bank.B().has(key):inherited[key]=Bank.B()[key]
	capture()
	var remaining := ids().filter(func(value):return value!=id)
	if remaining.is_empty():
		# Keep terminal records inspectable until a new company is registered; never reactivate closed operations.
		GameState.data["active_company"]=""
		Bank.B().merge(inherited,true)
		capture()
	else:apply(str(remaining[0]))
static func is_multi() -> bool:
	return ids(true).size()>1
