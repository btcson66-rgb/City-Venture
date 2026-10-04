class_name Tax
extends RefCounted
## Fictional Aurelia tax process. Tagged sale prices include VAT; capital/internal trades are not sales.

static func cfg() -> Dictionary: return DataDB.economy.get("tax", {})
static func valid(entity: String) -> bool:
	return GameState.has_game() and entity != "player" and GameState.data["entities"].get(entity, {}).get("kind", "") == "company" and not GameState.data["entities"][entity].has("closed")
static func vat_entity(entity: String) -> bool:return valid(entity) or (GameState.has_game() and entity=="player")
static func S() -> Dictionary:
	if not GameState.data.has("tax_service"): GameState.data["tax_service"] = {"entities":{}}
	return GameState.data["tax_service"]
static func period() -> int: return int(Clock.date()["year"]) * 6 + int((int(Clock.date()["month"])-1)/2)
static func E(entity: String) -> Dictionary:
	if not S()["entities"].has(entity):
		S()["entities"][entity] = {"from":Clock.now(), "year_from":Clock.now(), "year":int(Clock.date()["year"]), "period":period(), "pending":0.0, "pending_segments":{}, "loss":0.0, "returns":{}, "seq":0, "sales":{}}
	if not S()["entities"][entity].has("pending_segments"):S()["entities"][entity]["pending_segments"]={}
	return S()["entities"][entity]
## Drop the per-order VAT memo once an order can no longer be refunded (see Ecommerce.archive_settled).
static func forget_sale(entity: String, key: String) -> void:
	if S()["entities"].has(entity): S()["entities"][entity]["sales"].erase(key)
static func vat(gross: float) -> float:
	return snappedf(maxf(0,gross)*float(cfg()["vat_rate"])/(1.0+float(cfg()["vat_rate"])),.01)

## Split actual, tagged customer transactions in the same balanced journal entry; refunds cannot exceed collected VAT.
static func separate(entity: String, lines: Array, source: Dictionary) -> Array:
	if not vat_entity(entity) or source.get("internal",false) or str(source.get("type",""))=="": return lines
	if not lines.any(func(l):return l["acct"] in ["revenue","refunds"]):return lines
	close_period(entity)
	var state := E(entity)
	var result: Array = lines.duplicate(true)
	var key := str(source.get("segment","shared"))+":"+str(source.get("id",""))
	var tax_lines: Array=[]
	for line in result:
		var tax := 0.0
		if line["acct"]=="revenue" and float(line.get("cr",0))>0:
			tax=vat(float(line["cr"]))
			line["cr"]=snappedf(float(line["cr"])-tax,.01)
			state["sales"][key]=snappedf(float(state["sales"].get(key,0))+tax,.01)
			state["pending"]=snappedf(float(state["pending"])+tax,.01)
		elif line["acct"]=="refunds" and float(line.get("dr",0))>0:
			tax=minf(vat(float(line["dr"])),float(state["sales"].get(key,0)))
			line["dr"]=snappedf(float(line["dr"])-tax,.01)
			state["sales"][key]=snappedf(float(state["sales"].get(key,0))-tax,.01)
			state["pending"]=snappedf(float(state["pending"])-tax,.01)
			tax=-tax
		if tax!=0:
			var segment := str(source.get("segment","shared"))
			state["pending_segments"][segment]=snappedf(float(state["pending_segments"].get(segment,0))+tax,.01)
			tax_lines.append({"acct":"tax_payable", "cr":tax} if tax>0 else {"acct":"tax_payable", "dr":-tax})
	return result+tax_lines

static func _new_return(entity: String, kind: String, amount: float, label: String) -> Dictionary:
	var state := E(entity)
	state["seq"]=int(state["seq"])+1
	var id := "TAX-%d"%int(state["seq"])
	var r := {"id":id,"entity":entity,"kind":kind,"period":label,"amount":snappedf(amount,.01),"fine":0.0,"due":Clock.now()+int(cfg()["filing_due_days"])*Clock.DAY,"status":"filed" if amount<=0 else "due","late":false}
	state["returns"][id]=r
	GameState.add_message("ana",I18n.t("Tax return ready: %s. File by %s.")%[label,Clock.fmt_short(int(r["due"]))])
	return r

static func close_period(entity: String) -> void:
	if not vat_entity(entity): return
	var state := E(entity)
	if int(state["period"])!=period():
		var amount := maxf(0,float(state["pending"]))
		_new_return(entity,"vat",amount,I18n.t("VAT: year %d, period %d / 6")%[int(int(state["period"])/6),int(state["period"])%6+1])
		state["pending"]=snappedf(float(state["pending"])-amount,.01)
		state["pending_segments"]={"shared":state["pending"]} if float(state["pending"])!=0 else {}
		state["period"]=period()
	if valid(entity) and int(state["year"])<int(Clock.date()["year"]):
		var profit := float(Segments.compute(entity,int(state["year_from"]),Clock.now())["totals"]["operating_profit"])
		profit+=float(Ledger.movements(entity,int(state["year_from"]),Clock.now()).get("exp:income_tax",0))
		var loss := float(state["loss"])
		var used := minf(loss,maxf(0,profit))
		state["loss"]=snappedf(loss-used+maxf(0,-profit),.01)
		var amount := snappedf(maxf(0,profit-used)*float(cfg()["income_rate"]),.01)
		var r := _new_return(entity,"income",amount,I18n.t("Income tax year %d")%int(state["year"]))
		r.merge({"pretax_profit":profit,"loss_used":used,"loss_carried":state["loss"]})
		if amount>0: Ledger.post(entity,I18n.t("Annual income tax: %s")%Fmt.money(amount),[{"acct":"exp:income_tax","dr":amount},{"acct":"income_tax_payable","cr":amount}],{"type":"tax","segment":"shared"})
		state["year"]=int(Clock.date()["year"])
		state["year_from"]=Clock.now()

static func returns(entity: String) -> Array:
	return E(entity)["returns"].values() if vat_entity(entity) else []
static func get_return(entity: String,id: String) -> Dictionary:
	return E(entity)["returns"].get(id,{}) if vat_entity(entity) else {}
static func account(r: Dictionary) -> String: return "tax_payable" if r["kind"]=="vat" else "income_tax_payable"
static func payable(r: Dictionary) -> float: return snappedf(float(r.get("amount",0))+float(r.get("fine",0)),.01)
static func file(entity: String,id: String,method: String) -> Dictionary:
	var r := get_return(entity,id)
	if r.is_empty() or r["status"]!="due" or method not in ["diy","accountant"]: return {"ok":false,"error":I18n.t("Choose an unfiled return for this company.")}
	var fee := float(cfg()["accountant_fee"]) if method=="accountant" else 0.0
	var amount := payable(r)
	if Ledger.cash(entity)<amount+fee: return {"ok":false,"error":I18n.t("Fund the tax payment and filing fee first.")}
	if amount>0: Ledger.post(entity,I18n.t("Tax payment: %s")%Fmt.money(amount),[{"acct":account(r),"dr":amount},{"acct":"cash","cr":amount}],{"type":"tax","id":id,"segment":"shared"})
	if fee>0: Ledger.expense(entity,"tax_service",fee,I18n.t("Accountant filing fee: %s")%Fmt.money(fee),{"type":"tax","id":id,"segment":"shared"})
	r["status"]="processing"
	r["method"]=method
	var minutes := int(cfg()["accountant_minutes"] if method=="accountant" else cfg()["diy_minutes"])
	Sim.schedule(Clock.now()+minutes,"gov.tax_file",{"entity":entity,"id":id})
	Clock.advance(minutes)
	return {"ok":true,"minutes":minutes,"fee":fee}

static func correct(entity: String,id: String,method: String) -> Dictionary:
	var r := get_return(entity,id)
	if r.is_empty() or r["status"]!="correction" or method not in ["diy","accountant"]: return {"ok":false,"error":I18n.t("This return needs no correction.")}
	var fee := float(cfg()["correction_fee"]) if method=="accountant" else 0.0
	if Ledger.cash(entity)<fee: return {"ok":false,"error":I18n.t("Save the correction fee first.")}
	if fee>0: Ledger.expense(entity,"tax_service",fee,I18n.t("Filing correction: %s")%Fmt.money(fee),{"type":"tax","id":id,"segment":"shared"})
	r["status"]="filed"
	Sim.cancel("gov.tax_timeout","id",entity+":"+id)
	Clock.advance(int(cfg()["correction_minutes"]) if method=="diy" else int(cfg()["accountant_minutes"]))
	return {"ok":true}

static func handle(kind: String,p: Dictionary) -> void:
	var entity := str(p.get("entity",""))
	var r := get_return(entity,str(p.get("return",p.get("id",""))))
	if r.is_empty():return
	if kind=="gov.tax_file" and r["status"]=="processing":
		if r["method"]=="diy" and GameState.randf()<float(cfg()["diy_error_chance"]):
			r["status"]="correction"
			Sim.schedule(Clock.now()+int(cfg()["correction_timeout_days"])*Clock.DAY,"gov.tax_timeout",{"entity":entity,"return":r["id"],"id":entity+":"+str(r["id"])})
			GameState.add_message("ana",I18n.t("Filing documents need correction. Fix them yourself or hire an accountant; ignored forms incur a processing fee."))
		else:r["status"]="filed"
	elif kind=="gov.tax_timeout" and r["status"]=="correction":
		var fee := float(cfg()["correction_fee"])
		Ledger.expense(entity,"tax_service",fee,I18n.t("Automatic filing correction: %s")%Fmt.money(fee),{"type":"tax","id":r["id"],"segment":"shared"},"cash" if Ledger.cash(entity)>=fee else "accounts_payable")
		r["status"]="filed"
		Bank.adjust_credit(int(cfg()["late_credit"]),"late correction")

static func on_hour() -> void:
	for entity in GameState.data["entities"]:
		if not vat_entity(entity):continue
		close_period(entity)
		for r in returns(entity):
			if r["status"]=="due" and not r["late"] and Clock.now()>int(r["due"]):
				r["late"]=true
				r["fine"]=maxf(float(cfg()["late_min"]),snappedf(float(r["amount"])*float(cfg()["late_rate"]),.01))
				Ledger.post(entity,I18n.t("Late filing penalty: %s")%Fmt.money(float(r["fine"])),[{"acct":"exp:penalties","dr":r["fine"]},{"acct":account(r),"cr":r["fine"]}],{"type":"tax","id":r["id"],"segment":"shared"})
				Bank.adjust_credit(int(cfg()["late_credit"]),"late tax")
				Brand.record(entity,"payments",-8)

static func on_company_closed(entity: String) -> void:
	if not S()["entities"].has(entity):return
	for r in S()["entities"][entity]["returns"].values():r["status"]="closed"
	for kind in ["gov.tax_file","gov.tax_timeout"]:Sim.cancel(kind,"entity",entity)

## Contributed ecommerce operations bring their unfiled VAT obligation and actual refund rights; filed personal returns stay personal.
static func transfer_seller_vat(entity: String) -> void:
	if not valid(entity) or not S()["entities"].has("player"):return
	close_period("player")
	var old := E("player")
	var target := E(entity)
	var amount := minf(maxf(0,-Ledger.balance("player","tax_payable")),minf(maxf(0,float(old["pending"])),maxf(0,float(old["pending_segments"].get("ecommerce",0)))))
	if amount>0:
		Ledger.post("player",I18n.t("Unfiled seller VAT transferred with business"),[{"acct":"tax_payable","dr":amount},{"acct":"investments","cr":amount}],{"type":"transfer","segment":"ecommerce"})
		Ledger.post(entity,I18n.t("Seller VAT obligation assumed"),[{"acct":"equity","dr":amount},{"acct":"tax_payable","cr":amount}],{"type":"transfer","segment":"ecommerce"})
		old["pending"]=snappedf(float(old["pending"])-amount,.01)
		old["pending_segments"]["ecommerce"]=snappedf(float(old["pending_segments"].get("ecommerce",0))-amount,.01)
		target["pending"]=snappedf(float(target["pending"])+amount,.01)
		target["pending_segments"]["ecommerce"]=snappedf(float(target["pending_segments"].get("ecommerce",0))+amount,.01)
	for key in old["sales"].keys():
		if str(key).begins_with("ecommerce:"):
			target["sales"][key]=float(target["sales"].get(key,0))+float(old["sales"][key])
			old["sales"].erase(key)
