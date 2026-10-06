class_name Insurance
extends RefCounted
## Shared premiums and claims refer to actual loss journals. No cover for fines, investments or hypothetical lost sales.
static var crisis_context: Dictionary = {}
static func cfg() -> Dictionary:return DataDB.economy.get("governance",{})["insurance"]
static func S() -> Dictionary:
	if not GameState.data.has("insurance_service"):GameState.data["insurance_service"]={"policies":{},"claims":{},"seq":1,"legacy":{}}
	return GameState.data["insurance_service"]
static func policies(entity: String) -> Dictionary:
	if not S()["policies"].has(entity):S()["policies"][entity]={}
	return S()["policies"][entity]
static func buy(entity: String,kind: String) -> Dictionary:
	if not Tax.valid(entity) or not cfg()["policies"].has(kind):return {"ok":false,"error":I18n.t("Choose cover for an open company.")}
	var existing: Dictionary=policies(entity).get(kind,{})
	if existing.get("active",false):return {"ok":false,"error":I18n.t("This cover is already active.")}
	var fee := float(cfg()["policies"][kind]["monthly"])
	if Ledger.cash(entity)<fee:return {"ok":false,"error":I18n.t("Save the insurance premium first.")}
	Ledger.expense(entity,"insurance",fee,I18n.t("Insurance premium: %s")%Fmt.money(fee),{"type":"insurance_service","segment":"shared"})
	policies(entity)[kind]={"kind":kind,"active":true,"from":Clock.now(),"ready":Clock.now()+int(cfg()["waiting_days"])*Clock.DAY,"until":Clock.now()+int(cfg()["renew_days"])*Clock.DAY,"paid":0.0,"auto":true}
	return {"ok":true,"premium":fee}
static func cancel(entity: String,kind: String) -> void:
	var policy: Dictionary=policies(entity).get(kind,{})
	if not policy.is_empty():policy["auto"]=false  # already-paid cover lasts to its end
static func covered(entity: String,kind: String) -> bool:
	var policy: Dictionary=policies(entity).get(kind,{})
	return Tax.valid(entity) and policy.get("active",false) and Clock.now()>=int(policy.get("ready",0)) and Clock.now()<int(policy.get("until",0))
static func _journal(entity: String,n: int) -> Dictionary:
	var journal: Array=GameState.data["ledger"]["journal"]
	if not journal.is_empty() and int(journal.back()["n"])==n and journal.back()["entity"]==entity:return journal.back()
	for entry in GameState.data["ledger"]["journal"]:
		if entry["entity"]==entity and int(entry["n"])==n:return entry
	return {}
static func claim(entity: String,kind: String,n: int,legacy_pay := -1.0) -> float:
	var key := entity+":"+str(n)+":"+kind
	var entry := _journal(entity,n)
	if not Tax.valid(entity) or entry.is_empty() or S()["claims"].has(key):return 0.0
	var cause: Dictionary=entry["source"]
	if cause.get("loss_kind","")!=kind and cause.get("type","")!="rental_damage" and crisis_context.get("entity","")!=entity:return 0.0
	var eligible := 0.0
	for line in entry["lines"]:
		if (kind=="property" and line["acct"] in ["exp:maintenance","exp:vehicle"]) or (kind=="liability" and line["acct"] in ["refunds","exp:legal"]) or (kind=="interruption" and line["acct"] in ["exp:other","exp:payroll"]):eligible+=float(line.get("dr",0))
	if eligible<=0:return 0.0
	var pay := 0.0
	if legacy_pay>=0:
		var segment := str(entry["source"].get("segment","shared"))
		var legacy := legacy_cover(entity,segment)
		if Clock.now()<int(legacy.get("until",0)) and int(legacy.get("journal",0))<n:pay=minf(eligible,legacy_pay)
	elif covered(entity,kind) and int(entry["t"])>=int(policies(entity)[kind]["ready"]) and int(entry["t"])<int(policies(entity)[kind]["until"]):
		var policy: Dictionary=policies(entity)[kind]
		pay=minf(maxf(0,eligible*float(cfg()["cover_share"])-float(cfg()["deductible"])),maxf(0,float(cfg()["period_limit"])-float(policy["paid"])))
		policy["paid"]=snappedf(float(policy["paid"])+pay,.01)
	pay=snappedf(pay,.01)
	if pay<=0:return 0.0
	var id := "INS-%d"%int(S()["seq"])
	S()["seq"]=int(S()["seq"])+1
	S()["claims"][key]={"id":id,"entity":entity,"kind":kind,"journal":n,"loss":eligible,"amount":pay,"status":"pending","segment":entry["source"].get("segment","shared"),"due":Clock.now()+int(cfg()["claim_days"])*Clock.DAY}
	Ledger.post(entity,I18n.t("Approved insurance claim: %s")%Fmt.money(pay),[{"acct":"insurance_receivable","dr":pay},{"acct":"other_income","cr":pay}],{"type":"insurance_claim","id":id,"segment":entry["source"].get("segment","shared")})
	Sim.schedule(int(S()["claims"][key]["due"]),"gov.insurance_claim",{"id":key,"entity":entity})
	return pay
static func on_ledger(entry: Dictionary) -> void:
	var entity := str(entry["entity"])
	if not Tax.valid(entity):return
	var source: Dictionary=entry["source"]
	if source.get("type","")=="insurance" and source.get("segment","") in ["logistics","automotive"]:
		var premium := 0.0
		for line in entry["lines"]:
			if line["acct"]=="exp:insurance":premium+=float(line.get("dr",0))
		if premium>0:S()["legacy"][entity+":"+str(source["segment"]) ]={"until":int(source.get("cover_until",next_month() if source["segment"]=="automotive" else Clock.now()+int(cfg()["renew_days"])*Clock.DAY)),"premium":premium,"basis":source.get("premium_basis",premium),"journal":entry["n"]}
	if not crisis_context.is_empty() and crisis_context.get("entity","")==entity:
		for kind in cfg()["policies"]:
			claim(entity,str(kind),int(entry["n"]))
	elif source.get("loss_kind","") in cfg()["policies"]:claim(entity,str(source["loss_kind"]),int(entry["n"]))
static func handle(kind: String,p: Dictionary) -> void:
	if kind!="gov.insurance_claim":return
	var c: Dictionary=S()["claims"].get(str(p.get("id","")),{})
	if c.is_empty() or c["status"]!="pending" or not Tax.valid(str(c["entity"])):return
	Ledger.post(c["entity"],I18n.t("Insurance claim received: %s")%Fmt.money(float(c["amount"])),[{"acct":"cash","dr":c["amount"]},{"acct":"insurance_receivable","cr":c["amount"]}],{"type":"insurance_claim","id":c["id"],"segment":c["segment"]})
	c["status"]="paid"
static func on_hour() -> void:
	for entity in S()["policies"]:
		if not Tax.valid(str(entity)):continue
		for policy in policies(entity).values():
			if Clock.now()<int(policy["until"]):continue
			policy["active"]=false
			if not policy["auto"]:continue
			var fee := float(cfg()["policies"][policy["kind"]]["monthly"])
			if Ledger.cash(entity)>=fee:
				Ledger.expense(entity,"insurance",fee,I18n.t("Insurance renewal: %s")%Fmt.money(fee),{"type":"insurance_service","segment":"shared"})
				policy["active"]=true
				policy["ready"]=Clock.now()+int(cfg()["waiting_days"])*Clock.DAY if Clock.now()>int(policy["until"])+60 else Clock.now()
				policy["until"]=Clock.now()+int(cfg()["renew_days"])*Clock.DAY
				policy["paid"]=0.0
static func on_company_closed(entity: String) -> void:
	var receivable := maxf(0,Ledger.balance(entity,"insurance_receivable"))
	if receivable>0:Ledger.post(entity,I18n.t("Insurance receivable transferred for liquidation"),[{"acct":"accounts_receivable","dr":receivable},{"acct":"insurance_receivable","cr":receivable}],{"type":"insurance_claim","segment":"shared"})
	for policy in policies(entity).values():policy["active"]=false;policy["auto"]=false
	for c in S()["claims"].values():
		if c["entity"]==entity and c["status"]=="pending":c["status"]="closed"
	Sim.cancel("gov.insurance_claim","entity",entity)

## Older saves retain only cover proved by an actual recent premium journal, scanned once lazily.
static func legacy_cover(entity: String,segment: String) -> Dictionary:
	if not S().get("legacy_scanned",false):
		S()["legacy_scanned"]=true
		for entry in GameState.data["ledger"]["journal"]:
			var source: Dictionary=entry["source"]
			if source.get("type","")!="insurance" or source.get("segment","") not in ["logistics","automotive"]:continue
			var premium := 0.0
			for line in entry["lines"]:
				if line["acct"]=="exp:insurance":premium+=float(line.get("dr",0))
			if premium>0:S()["legacy"][str(entry["entity"])+":"+str(source["segment"]) ]={"until":source.get("cover_until",next_month(int(entry["t"])) if source["segment"]=="automotive" else int(entry["t"])+int(cfg()["renew_days"])*Clock.DAY),"premium":premium,"basis":source.get("premium_basis",premium),"journal":entry["n"]}
	return S()["legacy"].get(entity+":"+segment,{})

static func next_month(t := -1) -> int:
	var date := Clock.date_at(Clock.now() if t<0 else t)
	var month := int(date["month"])+1
	var year := int(date["year"])+(1 if month>12 else 0)
	if month>12:month=1
	var next := {"year":year,"month":month,"day":1,"hour":0,"minute":0,"second":0}
	return int((Time.get_unix_time_from_datetime_dict(next)-Time.get_unix_time_from_datetime_dict(Clock.date_at(0)))/60)

static func loss_source(source: Dictionary,kind: String) -> Dictionary:
	var tagged := source.duplicate(true)
	tagged["loss_kind"]=kind
	return tagged

## Existing fleet cover is billed before rentals and prorated for upgrades; loss-time journals must follow the premium.
static func ensure_vehicle_cover(entity: String,credit_allowed := false) -> Dictionary:
	if not Tax.valid(entity) or Automotive.policy()["insurance"]=="none":return {"ok":true}
	var old := legacy_cover(entity,"automotive")
	var amount := Automotive.monthly_premium()
	var active := Clock.now()<int(old.get("until",0))
	var difference := maxf(0,amount-float(old.get("basis",0))) if active else amount
	if difference<=0:return {"ok":true}
	var until := next_month()
	var fee := snappedf(difference*minf(1.0,float(until-Clock.now())/(30.0*Clock.DAY)),.01)
	if not credit_allowed and Ledger.cash(entity)<fee:return {"ok":false,"error":I18n.t("Save the vehicle-cover upgrade premium first.")}
	Ledger.expense(entity,"insurance",fee,I18n.t("Vehicle cover premium: %s")%Fmt.money(fee),{"type":"insurance","segment":"automotive","premium_basis":amount,"cover_until":until},"cash" if Ledger.cash(entity)>=fee else "accounts_payable")
	return {"ok":true,"premium":fee}
