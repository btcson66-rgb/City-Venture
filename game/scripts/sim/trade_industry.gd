class_name TradeIndustry
extends RefCounted
## Brokerage projects use shared Jobs; physical shipments and documents control invoicing.
static func cfg() -> Dictionary:return TradeQuote.cfg().get("execution",{})
static func S() -> Dictionary:
	if not GameState.data.has("trade"):
		GameState.data["trade"]={"active":false,"entity":"","registered":false,"deals":{},"seq":1,"usage":{},"completed":0,"contracts":{},"agency":false,"freight_until":0,"freight_mult":1.0}
	var state: Dictionary=GameState.data["trade"]
	for key in {"contracts":{},"agency":false,"freight_until":0,"freight_mult":1.0}:
		if not state.has(key):state[key]={"contracts":{},"agency":false,"freight_until":0,"freight_mult":1.0}[key]
	return state
static func segment_tag() -> String:return "international_trade"
static func entity() -> String:return str(S()["entity"])
static func is_running() -> bool:return GameState.has_game() and bool(S()["active"])
static func valid() -> bool:return is_running() and GlobalMarket.live(entity())
static func source(id: String) -> Dictionary:return {"type":"trade","id":id,"segment":"international_trade"}
static func error(text: String) -> Dictionary:return {"ok":false,"error":I18n.t(text)}
static func stage() -> int:return 3 if S()["agency"] else (2 if int(S()["completed"])>=int(cfg().get("contract_threshold",3)) else 1)
static func sign_repeat(id: String) -> Dictionary:
	var d: Dictionary=S()["deals"].get(id,{})
	if not valid() or stage()<2 or d.is_empty() or d["status"]!="paid":return error("Complete three paid trades before negotiating a repeat contract.")
	if S()["contracts"].has(id):return error("This repeat contract already exists. Resume or end it instead.")
	S()["contracts"][id]={"deal":id,"remaining":3,"next":Clock.now()+30*Clock.DAY,"paused":false,"ended":false,"error":"","jobs":[]}
	return {"ok":true}
static func pause_repeat(id: String, pause: bool) -> Dictionary:
	var c: Dictionary=S()["contracts"].get(id,{})
	if not valid() or c.is_empty() or c["ended"]:return error("This repeat contract has ended.")
	c["paused"]=pause
	return {"ok":true}
static func end_repeat(id: String) -> Dictionary:
	var c: Dictionary=S()["contracts"].get(id,{})
	if not valid() or c.is_empty() or c["ended"]:return error("This repeat contract has ended.")
	c["ended"]=true
	return {"ok":true}
static func open_agency() -> Dictionary:
	if not valid() or stage()<2:return error("Complete three paid trades before applying for an agency.")
	if S()["agency"]:return error("The regional agency is already active.")
	if not Living.has_lease("meridian_bonded_warehouse"):return error("Lease the bonded warehouse before applying for an agency.")
	var fee: float=cfg().get("agency_fee",2500)
	if Ledger.cash(entity())<fee:return error("Fund the regional agency application fee first.")
	Ledger.expense(entity(),"compliance",fee,I18n.t("Regional agency application"),source("agency"))
	S()["agency"]=true
	return {"ok":true}
static func lease_warehouse() -> Dictionary:
	if not valid() or stage()<2:return error("Complete three paid trades before leasing the bonded warehouse.")
	return Living.lease("meridian_bonded_warehouse")
static func hedge_receipt(id: String) -> Dictionary:
	var d: Dictionary=S()["deals"].get(id,{})
	if not valid() or d.is_empty() or d.get("procurement",false) or d["status"] not in ["booked","delayed","customs_hold","in_transit","awaiting_bank","receivable"]:return error("This trade has no pending foreign receipt to hedge.")
	var ccy: String=d["quote"]["buyer_currency"]
	var amount: float=minf(float(d["quote"]["buyer_quote"]),FXForward.exposure(entity(),ccy,30))
	return FXForward.open(ccy,amount,30)
static func register() -> Dictionary:
	if GameState.company_id()=="" or not GameState.flag("business_account_opened"):return error("Register a company and open its bank account first.")
	if S()["registered"]:return error("Import and export registration is already complete.")
	var fee: float=cfg().get("registration_fee",200)
	if Ledger.cash(GameState.company_id())<fee:return error("Fund the import and export registration fee first.")
	S()["entity"]=GameState.company_id();S()["registered"]=true
	Ledger.expense(entity(),"compliance",fee,I18n.t("Import and export registration"),source("registration"))
	return {"ok":true}
static func start() -> Dictionary:
	if not S()["registered"] or entity()!=GameState.company_id():return error("Apply for import and export registration at Customs House first.")
	if not Living.has_lease("meridian_trade_office"):return error("Lease Meridian Trade Desk before opening the brokerage.")
	if is_running():return error("The trade brokerage is already open.")
	S()["active"]=true;GameState.set_flag("trade_active")
	GameState.timeline(I18n.t("Registered trade brokerage opened at Meridian."),"business")
	return {"ok":true}
static func paid_cargo_assets(ent: String) -> float:
	var total:=0.0
	for d in GameState.data.get("trade",{}).get("deals",{}).values():
		if d["entity"]==ent and d["status"] in ["booked","delayed","customs_hold","in_transit"]:total+=float(d["cost"])
	return total
static func crisis(kind: String, retain: bool) -> Dictionary:
	return crisis_context(kind,retain,{})
static func crisis_context(kind: String, retain: bool, ctx: Dictionary) -> Dictionary:
	var owner: String=str(ctx.get("trade_entity",entity()))
	if owner!="" and owner!=GameState.company_id():
		if not GlobalMarket.live(owner):return {"ok":true}
		var result: Variant=CompanyPortfolio.run_in(owner,func():return crisis_context(kind,retain,ctx))
		return result if result is Dictionary else {"ok":true}
	if not valid():return {"ok":true}
	for d in S()["deals"].values():
		if ctx.has("trade") and d["id"]!=ctx["trade"]:continue
		if kind=="port" and d["status"]=="delayed":return resolve_delay(d["id"],retain)
		if kind=="fx" and not d.get("procurement",false) and d["quote"]["payment"]!="tt_prepaid" and d["status"] in ["booked","in_transit","receivable"]:
			return hedge_receipt(d["id"]) if retain else {"ok":true}
	return {"ok":true}
static func _usage_key(region: String, product: String) -> String:return "%d:%s:%s"%[Clock.day_index()/int(cfg().get("capacity_period_days",30)),region,product]
static func available(q: Dictionary, procurement := false) -> String:
	if not valid():return "Open the registered trade brokerage first."
	if not TradeQuote.valid(q):return "This RFQ expired. Refresh the route quote."
	if not procurement and not q.get("competitive",false):return "The buyer cannot accept this landed price. Reduce the markup or choose another route."
	for region in [q["origin"],q["destination"]]:
		var r: Dictionary=TradeQuote.cfg()["goods"][q["product"]]["regions"][region]
		var limit: int=int(r["capacity"]) if region==q["origin"] else ceili(float(r["demand"])*CityFuture.demand_factor("international_trade"))
		if int(S()["usage"].get(_usage_key(region,q["product"]),0))+int(q["quantity"])>limit:return "This month's regional capacity or demand is used. Wait for renewal or choose another route."
	if Ledger.cash(entity())<_initial_cost(q):return "Fund the supplier purchase and seller-paid route costs first."
	return ""
static func procure(q: Dictionary) -> Dictionary:
	var why:=available(q,true)
	if why!="":return error(why)
	if not S()["agency"] or not Living.has_lease("meridian_bonded_warehouse") or q["destination"]!="aurelia" or q["term"]!="DDP":return error("Use a home-bound DDP route with an active agency and bonded warehouse.")
	why=Ecommerce.space_block("meridian_bonded_warehouse",int(q["quantity"]))
	if why!="":return error(why)
	var cost: float=_initial_cost(q)
	var id: String="TRD-%04d"%int(S()["seq"])
	var job: String=Jobs.offer({"entity":entity(),"client":I18n.t("Regional supplier"),"scope":I18n.t("Brokered cargo: %d units")%int(q["quantity"]),"price":cost,"work":int(q["quantity"]),"terms":0,"direction":"purchase","segment":"international_trade","due":Clock.now()+(int(q["wait_days"])+int(q["transit_days"])+14)*Clock.DAY})
	if job=="":return error("The buyer contract is invalid. Refresh the route quote.")
	var accepted:=Jobs.accept_purchase(job)
	if not accepted["ok"]:return accepted
	var paid:=Jobs.purchase_milestone(job,cost,0,"goods_out")
	if not paid["ok"]:return paid
	var d: Dictionary={"id":id,"job":job,"entity":entity(),"quote":q.duplicate(true),"status":"booked","quantity":int(q["quantity"]),"cost":cost,"procurement":true,"documents":{"invoice":true,"packing_list":true,"bill_of_lading":true},"code":TradeQuote.cfg()["goods"][q["product"]]["tariff_code"],"lc":"none","signed":Clock.now(),"depart":Clock.now()+int(q["wait_days"])*Clock.DAY,"held_at":-1,"last_rent":-1,"due":0,"supplier_receipt":{"region":q["origin"],"product":q["product"],"units":int(q["quantity"]),"foreign_paid":snappedf(float(q["purchase"])/float(q["source_rate"]),.01)}}
	S()["seq"]=int(S()["seq"])+1;S()["deals"][id]=d
	for region in [q["origin"],q["destination"]]:
		var key:=_usage_key(region,q["product"]);S()["usage"][key]=int(S()["usage"].get(key,0))+int(q["quantity"])
	Sim.schedule(d["depart"],"trade.depart",{"id":id})
	GameState.timeline(I18n.t("Trade supplier cargo purchased")+" · "+id+" · "+Fmt.money(cost),"business")
	return {"ok":true,"id":id}
static func _initial_cost(q: Dictionary) -> float:
	var total: float=float(q["purchase"])/float(q["source_rate"])*FX.rate(q["source_currency"])+float(q["fee"])
	for line in q["segments"]:
		if line["payer"]=="seller":total+=float(line["cost"])
	return snappedf(total,.01)
static func sign(q: Dictionary) -> Dictionary:
	var why:=available(q)
	if why!="":return error(why)
	var id: String="TRD-%04d"%int(S()["seq"])
	var contract_price: float=snappedf(float(q["buyer_quote"])*FX.rate(q["buyer_currency"]),.01)
	var terms: int=30 if q["payment"]=="open_account" else 0
	var job: String=Jobs.offer({"entity":entity(),"client":I18n.t("Regional trade buyer")+" · "+str(q["destination"]),"scope":I18n.t("Brokered cargo: %d units")%int(q["quantity"]),"price":contract_price,"work":int(q["quantity"]),"terms":terms,"deposit":1.0 if q["payment"]=="tt_prepaid" else 0.0,"due":Clock.now()+(int(q["wait_days"])+int(q["transit_days"])+int(cfg().get("maximum_delay_days",14)))*Clock.DAY,"segment":"international_trade","trade_deal":id})
	if job=="":return error("The buyer contract is invalid. Refresh the route quote.")
	var accepted:=Jobs.accept(job)
	if not accepted["ok"]:return accepted
	var purchase: float=snappedf(float(q["purchase"])/float(q["source_rate"])*FX.rate(q["source_currency"]),.01)
	var d: Dictionary={"id":id,"job":job,"entity":entity(),"quote":q.duplicate(true),"status":"booked","quantity":int(q["quantity"]),"cost":purchase,"documents":{"invoice":true,"packing_list":true,"bill_of_lading":true},"code":TradeQuote.cfg()["goods"][q["product"]]["tariff_code"],"lc":"issued" if q["payment"]=="lc" else "none","signed":Clock.now(),"depart":Clock.now()+int(q["wait_days"])*Clock.DAY,"held_at":-1,"last_rent":-1,"due":0,"supplier_receipt":{"region":q["origin"],"product":q["product"],"units":int(q["quantity"]),"foreign_paid":snappedf(float(q["purchase"])/float(q["source_rate"]),.01)}}
	S()["seq"]=int(S()["seq"])+1;S()["deals"][id]=d
	Ledger.post(entity(),I18n.t("Trade supplier cargo purchased"),[{"acct":"goods_out","dr":purchase},{"acct":"cash","cr":purchase}],source(id))
	Ledger.expense(entity(),"bank_fees",float(q["fee"]),I18n.t("Trade payment arrangement fee"),source(id))
	for line in q["segments"]:
		if line["payer"]!="seller":continue
		var category: String="insurance" if line["kind"]=="Cargo insurance" else ("compliance" if line["kind"]=="Import duty" else "shipping")
		Ledger.expense(entity(),category,float(line["cost"]),I18n.t(str(line["kind"]))+" · "+id,source(id))
	if q["payment"]=="tt_prepaid":Ledger.expense(entity(),"bank_fees",float(q["spread"]),I18n.t("Trade currency conversion fee"),source(id))
	for region in [q["origin"],q["destination"]]:
		var key:=_usage_key(region,q["product"]);S()["usage"][key]=int(S()["usage"].get(key,0))+int(q["quantity"])
	Sim.schedule(d["depart"],"trade.depart",{"id":id})
	GameState.timeline(I18n.t("Trade supplier cargo purchased")+" · "+id+" · "+Fmt.money(purchase),"business")
	if q["payment"]!="tt_prepaid" and q["buyer_currency"]!=FX.cfg().get("home_currency","AUD") and GameState.rng.randf()<float(cfg().get("fx_shock_risk",.03)):
		FX.add_shock(q["buyer_currency"],3.0,7)
		EventEngine.trigger("trade_fx_volatility",{"trade":id,"trade_entity":entity(),"company":GameState.data["entities"][entity()]["name"]})
	return {"ok":true,"id":id}
static func set_document(id: String, key: String, present: bool) -> Dictionary:
	var d: Dictionary=S()["deals"].get(id,{})
	if d.is_empty() or d["status"] not in ["booked","customs_hold"] or not d["documents"].has(key):return error("These shipping documents can no longer be changed.")
	d["documents"][key]=present;return {"ok":true}
static func set_code(id: String, code: String) -> Dictionary:
	var d: Dictionary=S()["deals"].get(id,{})
	if d.is_empty() or d["status"] not in ["booked","customs_hold"] or not Customs.cfg().get("codes",{}).has(code):return error("Choose a supported tariff code before clearance.")
	d["code"]=code;return {"ok":true}
static func document_block(d: Dictionary) -> String:
	if not d["documents"].values().all(func(v):return bool(v)):return "Complete the commercial invoice, packing list and bill of lading."
	if d["code"]!=TradeQuote.cfg()["goods"][d["quote"]["product"]]["tariff_code"]:return "Correct the cargo tariff code before clearance."
	return ""
static func clear(id: String) -> Dictionary:
	var d: Dictionary=S()["deals"].get(id,{})
	if d.is_empty() or d["status"]!="customs_hold" or not valid():return error("This trade customs hold is no longer active.")
	if d.get("procurement",false):
		if not Living.has_lease("meridian_bonded_warehouse"):return error("Lease the bonded warehouse before applying for an agency.")
		var storage: String=Ecommerce.space_block("meridian_bonded_warehouse",int(d["quantity"]))
		if storage!="":return error(storage)
	var why:=document_block(d)
	if why!="":return error(why)
	var fee: float=Customs.cfg().get("misclassification_fine",25)
	if Ledger.cash(entity())<fee:return error("Fund the document correction fee or withdraw the cargo.")
	Ledger.expense(entity(),"compliance",fee,I18n.t("Trade customs document correction"),source(id))
	d["clearance"]={"code":d["code"],"at":Clock.now(),"entity":entity()};d["status"]="in_transit"
	d["eta"]=Clock.now()+int(d["quote"]["transit_days"])*Clock.DAY
	Sim.schedule(d["eta"],"trade.arrive",{"id":id});return {"ok":true}
static func bank_documents(id: String) -> Dictionary:
	var d: Dictionary=S()["deals"].get(id,{})
	if d.is_empty() or d["quote"]["payment"]!="lc" or d["lc"]!="issued" or not valid():return error("This letter of credit is no longer awaiting documents.")
	var why:=document_block(d)
	if why!="":return error(why)
	d["lc"]="documents_accepted";d["bank_receipt"]={"at":Clock.now(),"fee":d["quote"]["fee"],"documents":d["documents"].duplicate(),"entity":entity()}
	if d["status"]=="awaiting_bank":_invoice(d)
	return {"ok":true}
static func _invoice(d: Dictionary) -> void:
	var job:=Jobs.get_job(d["job"])
	Jobs.progress(d["job"],d["quantity"]);Jobs.deliver(d["job"])
	# Post the shared invoice, then replace only this project's ordinary cash callback.
	job["terms"]=30;Jobs.invoice(d["job"]);Sim.cancel("job.pay","id",d["job"])
	job["trade_days"]=int(d["quote"]["payment_days"]);job["pay_due"]=Clock.now()+job["trade_days"]*Clock.DAY
	d["status"]="receivable";d["due"]=job["pay_due"]
	Sim.schedule(d["due"],"trade.collect",{"id":d["id"]})
	if int(job["trade_days"])==0:collect(d)
static func collect(d: Dictionary) -> void:
	var job:=Jobs.get_job(d["job"])
	if not valid() or d["status"]!="receivable" or Clock.now()<int(d["due"]) or job["status"]!="invoiced":return
	var book: float=job["receivable"]
	var failed: bool=d["quote"]["payment"]!="lc" and GameState.rng.randf()<float(d["quote"]["default_risk"])
	if failed:
		Ledger.post(entity(),I18n.t("Trade buyer default"),[{"acct":"exp:other","dr":book},{"acct":"accounts_receivable","cr":book}],source(d["id"]))
		d["status"]="defaulted";job["status"]="closed"
	else:
		var cash: float=0.0 if float(job["deposit_paid"])>0 else FX.to_home(float(d["quote"]["buyer_quote"]),d["quote"]["buyer_currency"])
		var delta: float=snappedf(cash-book,.01)
		var lines: Array=[{"acct":"cash","dr":cash},{"acct":"accounts_receivable","cr":book}]
		if delta>0:lines.append({"acct":"fx_gain_loss","cr":delta})
		elif delta<0:lines.append({"acct":"fx_gain_loss","dr":-delta})
		Ledger.post(entity(),I18n.t("Trade buyer payment and exchange result"),lines,source(d["id"]))
		d["cash_received"]=cash;d["fx_result"]=delta;d["status"]="paid";job["status"]="paid"
		S()["completed"]=int(S()["completed"])+1;GameState.inc_stat("trade_deliveries")
	Sim.cancel("trade.collect","id",d["id"])
static func _lost(d: Dictionary, covered := true) -> void:
	var cost: float=d["cost"];var recovery: float=snappedf(cost*float(TradeQuote.cfg()["insurance_coverage"]),.01) if covered and d["quote"]["insured"] else 0.0
	Ledger.post(entity(),I18n.t("Trade cargo loss and insurance claim"),[{"acct":"cogs","dr":cost-recovery},{"acct":"cash","dr":recovery},{"acct":"goods_out","cr":cost}],source(d["id"]))
	_refund(d);d["status"]="lost";d["insurance_receipt"]={"units":d["quantity"],"paid":recovery,"at":Clock.now()}
static func _refund(d: Dictionary) -> void:
	var job:=Jobs.get_job(d["job"])
	if float(job.get("deposit_paid",0))>0:
		Ledger.post(entity(),I18n.t("Undelivered trade buyer advance returned"),[{"acct":"deferred_revenue","dr":job["deposit_paid"]},{"acct":"cash","cr":job["deposit_paid"]}],source(d["id"]))
		job["deposit_paid"]=0.0
	job["status"]="closed"
static func resolve_delay(id: String, reroute: bool) -> Dictionary:
	var d: Dictionary=S()["deals"].get(id,{})
	if not valid() or d.is_empty() or d["status"]!="delayed":return error("This shipping delay has already ended.")
	if reroute:
		var fee: float=float(TradeQuote.cfg()["transport"]["air"]["base_fee"])+float(TradeQuote.cfg()["transport"]["air"]["unit_fee"])*int(d["quantity"])
		if Ledger.cash(entity())<fee:return error("Fund the air rerouting fee or wait for the port to reopen.")
		Ledger.expense(entity(),"shipping",fee,I18n.t("Trade cargo rerouted by air"),source(id))
		d["quote"]["transit_days"]=TradeQuote.cfg()["transport"]["air"]["days"]
		d["quote"]["cargo_risk"]=TradeQuote.cfg()["transport"]["air"]["loss_risk"]
		d["reroute_receipt"]={"fee":fee,"at":Clock.now()}
		d["depart"]=Clock.now()
	else:d["depart"]=Clock.now()+3*Clock.DAY
	d["status"]="booked"
	Sim.cancel("trade.resume","id",id)
	Sim.schedule(d["depart"],"trade.depart",{"id":id})
	return {"ok":true}
static func withdraw(id: String) -> Dictionary:
	var d: Dictionary=S()["deals"].get(id,{})
	if d.is_empty() or d["status"] not in ["booked","delayed","customs_hold","awaiting_bank"] or not valid():return error("This cargo can no longer be withdrawn.")
	if d.get("cost_posted",false):
		_refund(d);d["status"]="unpaid_documents"
		return {"ok":true}
	var cost: float=d["cost"];var salvage: float=snappedf(cost*float(cfg().get("supplier_return_fraction",.5)),.01)
	# Supplier return is a recovery of a paid purchase, not sales revenue.
	Ledger.post(entity(),I18n.t("Trade cargo returned to supplier"),[{"acct":"cash","dr":salvage},{"acct":"exp:inventory_writeoff","dr":cost-salvage},{"acct":"goods_out","cr":cost}],source(id))
	_refund(d);d["status"]="withdrawn";d["supplier_return"]={"units":d["quantity"],"paid":salvage,"at":Clock.now()}
	for kind in ["trade.depart","trade.arrive","trade.collect","trade.resume"]:Sim.cancel(kind,"id",id)
	return {"ok":true}
static func handle(kind: String, payload: Dictionary) -> void:
	var d: Dictionary=S()["deals"].get(str(payload.get("id","")),{})
	if d.is_empty() or not valid():return
	if kind=="trade.resume" and d["status"]=="delayed":
		d["status"]="booked"
		handle("trade.depart",payload)
		return
	if kind=="trade.depart" and d["status"]=="booked":
		if document_block(d)!="":d["status"]="customs_hold";d["held_at"]=Clock.now();return
		if d["quote"]["mode"]=="sea" and not d.get("disruption_checked",false):
			d["disruption_checked"]=true
			if GameState.rng.randf()<float(cfg().get("port_disruption_risk",.08)):
				d["status"]="delayed";d["resume"]=Clock.now()+3*Clock.DAY
				S()["freight_until"]=Clock.now()+7*Clock.DAY;S()["freight_mult"]=1.8
				Sim.schedule(d["resume"],"trade.resume",{"id":d["id"]})
				EventEngine.trigger("trade_port_strike",{"trade":d["id"],"trade_entity":entity(),"company":GameState.data["entities"][entity()]["name"],"reroute_fee":Fmt.money(float(TradeQuote.cfg()["transport"]["air"]["base_fee"])+float(TradeQuote.cfg()["transport"]["air"]["unit_fee"])*int(d["quantity"]))})
				return
		d["clearance"]={"code":d["code"],"at":Clock.now(),"entity":entity()}
		if GameState.rng.randf()<float(cfg().get("supplier_failure_risk",.03)):_lost(d,false);return
		d["status"]="in_transit";d["eta"]=Clock.now()+int(d["quote"]["transit_days"])*Clock.DAY
		Sim.schedule(d["eta"],"trade.arrive",{"id":d["id"]})
	elif kind=="trade.arrive" and d["status"]=="in_transit":
		# Title transfer determines whose insured cargo was at risk during the main carriage.
		if d["quote"]["risk_transfer"]=="Buyer delivery" and GameState.rng.randf()<float(d["quote"]["cargo_risk"]):_lost(d);return
		if d.get("procurement",false):
			if not Living.has_lease("meridian_bonded_warehouse") or Ecommerce.space_block("meridian_bonded_warehouse",int(d["quantity"]))!="":
				d["status"]="customs_hold";d["held_at"]=Clock.now();return
			Ledger.post(entity(),I18n.t("Agency cargo received into bonded warehouse"),[{"acct":"inventory","dr":d["cost"]},{"acct":"goods_out","cr":d["cost"]}],source(d["id"]))
			Ecommerce._add_stock("meridian_bonded_warehouse",d["quote"]["product"],int(d["quantity"]),float(d["cost"])/float(d["quantity"]),float(DataDB.product(d["quote"]["product"]).get("defect_rate",0)))
			Jobs.progress(d["job"],d["quantity"]);Jobs.deliver(d["job"])
			d["status"]="received";d["cost_posted"]=true;d["delivered"]={"region":"aurelia","location":"meridian_bonded_warehouse","units":d["quantity"],"at":Clock.now()}
			return
		d["delivered"]={"region":d["quote"]["destination"],"product":d["quote"]["product"],"units":d["quantity"],"at":Clock.now()}
		Ledger.post(entity(),I18n.t("Trade delivered cargo cost"),[{"acct":"cogs","dr":d["cost"]},{"acct":"goods_out","cr":d["cost"]}],source(d["id"]))
		d["cost_posted"]=true
		if d["quote"]["payment"]=="lc" and d["lc"]!="documents_accepted":d["status"]="awaiting_bank";d["held_at"]=Clock.now()
		else:_invoice(d)
	elif kind=="trade.collect":collect(d)
static func on_hour(_t: int, h: int) -> void:
	if not valid():return
	for worker in Staff.people():
		if worker["role"]!="trade_coordinator" or not Staff.is_working(worker,_t-60):continue
		for d in S()["deals"].values():
			if d["status"]=="customs_hold" and not d["supplier_receipt"].is_empty():
				for key in d["documents"]:set_document(d["id"],key,true)
				set_code(d["id"],TradeQuote.cfg()["goods"][d["quote"]["product"]]["tariff_code"])
				clear(d["id"])
			elif d["quote"]["payment"]=="lc" and d["lc"]=="issued" and GlobalMarket.company(entity())["bank"]:bank_documents(d["id"])
	if h!=0:return
	FXForward.on_hour()
	for c in S()["contracts"].values():
		if c["paused"] or c["ended"] or Clock.now()<int(c["next"]):continue
		var previous: Dictionary=S()["deals"][c["deal"]]["quote"]
		var markup: float=float(previous["sales"])/float(previous["purchase"])-1.0
		var q:=TradeQuote.sheet(previous["origin"],previous["destination"],previous["product"],previous["quantity"],previous["term"],previous["mode"],previous["payment"],previous["insured"],markup)
		var result: Dictionary=TradeIndustry.sign(q)
		if not result["ok"]:
			c["paused"]=true;c["error"]=result["error"]
			continue
		c["jobs"].append(S()["deals"][result["id"]]["job"])
		c["remaining"]=int(c["remaining"])-1;c["next"]=Clock.now()+30*Clock.DAY;c["error"]=""
		if int(c["remaining"])==0:c["ended"]=true
	for d in S()["deals"].values():
		if d["status"] not in ["customs_hold","awaiting_bank"]:continue
		if Clock.now()-int(d["held_at"])>=int(Customs.cfg().get("hold_timeout_days",7))*Clock.DAY:
			if d["status"]=="awaiting_bank":
				# Delivered goods cannot be returned twice or resurrected as warehouse stock.
				_refund(d);d["status"]="unpaid_documents"
			else:withdraw(d["id"])
			continue
		if d["last_rent"]==Clock.day_index():continue
		d["last_rent"]=Clock.day_index()
		Ledger.expense(entity(),"rent_warehouse",float(d["quote"]["warehouse_rent_day"]),I18n.t("Held trade cargo warehouse rent"),source(d["id"]))
static func on_company_closed(ent: String) -> void:
	if not GameState.data.has("trade") or entity()!=ent:return
	FXForward.close_for_entity(ent)
	for d in S()["deals"].values():
		for kind in ["trade.depart","trade.arrive","trade.collect","trade.resume"]:Sim.cancel(kind,"id",d["id"])
		if d["status"] not in ["paid","received","defaulted","lost","withdrawn","unpaid_documents"]:d["status"]="closed"
	S()["active"]=false
	EventEngine.S()["queue"]=EventEngine.S()["queue"].filter(func(q):return not (q["id"] in ["trade_port_strike","trade_fx_volatility"] and str(q["ctx"].get("trade_entity",ent))==ent))
	GameState.set_flag("trade_active",false)
static func os_tab() -> Dictionary:return {"id":"international_trade","label":"International Trade","icon":"world","order":10,"start_label":"Open Trade Desk","render":TradeDeskUI.render}
static func board_detail() -> Callable:return TradeDeskUI.board
static func open_action(_params: Dictionary, _source: Node) -> void:TradeDeskUI.open()
