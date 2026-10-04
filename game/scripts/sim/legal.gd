class_name Legal
extends RefCounted
## Disputes retain their original company/job and settle existing receivables or actual paid costs, never invented sales.
static func cfg() -> Dictionary:return DataDB.economy.get("governance",{})["legal"]
static func S() -> Dictionary:
	if not GameState.data.has("legal_service"):GameState.data["legal_service"]={"cases":{},"seq":1,"last_day":-1,"cooldowns":{}}
	return GameState.data["legal_service"]
static func cases(entity: String) -> Array:return S()["cases"].values().filter(func(c):return c["entity"]==entity)
static func get_case(id: String) -> Dictionary:return S()["cases"].get(id,{})
static func options() -> Dictionary:return cfg()["options"]
static func _open(entity: String,kind: String,job_id: String,amount: float,party: String,asset := "") -> String:
	if not Tax.valid(entity) or not is_finite(amount) or amount<=0:return ""
	if cases(entity).any(func(c):return c["kind"]==kind and c["job"]==job_id and c["status"] in ["open","pending"]):return ""
	var id := "LAW-%d"%int(S()["seq"])
	S()["seq"]=int(S()["seq"])+1
	S()["cases"][id]={"id":id,"entity":entity,"kind":kind,"job":job_id,"party":party,"amount":snappedf(amount,.01),"asset":asset,"status":"open","opened":Clock.now(),"expires":Clock.now()+int(cfg()["timeout_days"])*Clock.DAY,"relationship":0,"recovered":0.0,"paid":0.0}
	var job := Jobs.get_job(job_id)
	if not job.is_empty():job["dispute_pause"]=true
	Sim.schedule(int(get_case(id)["expires"]),"gov.legal_timeout",{"id":id,"entity":entity})
	GameState.add_message("ana",I18n.t("Contract dispute with %s. Choose settlement, a lawyer letter or court in Company OS → Governance.")%party)
	return id
static func unpaid(job_id: String) -> String:
	var job := Jobs.get_job(job_id)
	if job.is_empty() or job.get("status","")!="invoiced" or float(job.get("receivable",0))<=0:return ""
	var id := _open(str(job["entity"]),"customer",job_id,float(job["receivable"]),str(job["client"]))
	if id!="":Sim.cancel("job.pay","id",job_id)
	return id
static func customer_payment(job: Dictionary) -> bool:
	if job.get("dispute_pause",false):return false
	if not job.get("payment_checked",false):
		job["payment_checked"]=true
		var risk := clampf(float(job.get("payment_risk",cfg()["unpaid_chance"])),0,1)
		if risk>0 and GameState.randf()<risk and unpaid(str(job["id"]))!="":return false
	return true
static func supplier_breach(job_id: String) -> String:
	var job := Jobs.get_job(job_id)
	if job.is_empty() or job.get("direction","")!="purchase" or job.get("status","")!="active" or str(job.get("supplier_dispute_id",""))!="" or float(job.get("paid_cost",0))<=0 or Clock.now()<=int(job["due"]) or float(job["progress"])>=float(job["work"]):return ""
	var asset := ""
	var journal: Array=GameState.data["ledger"]["journal"]
	for i in range(journal.size()-1,-1,-1):  # newest purchase wins, so the first hit from the end is the answer
		var entry: Dictionary=journal[i]
		if entry["entity"]!=job["entity"] or entry["source"].get("type","")!="job_purchase" or entry["source"].get("id","")!=job_id:continue
		for line in entry["lines"]:
			if float(line.get("dr",0))>0 and line["acct"]!="cash":asset=str(line["acct"])
		if asset!="":break
	if asset=="":return ""
	job["supplier_checked"]=true
	var id := _open(str(job["entity"]),"supplier",job_id,float(job["paid_cost"])*float(cfg()["supplier_compensation_share"]),str(job["client"]),asset)
	if id!="":job["supplier_dispute_id"]=id
	return id
static func employee_dispute(entity: String) -> String:
	var wages := maxf(0,-Ledger.balance(entity,"wages_payable"))
	return _open(entity,"employee","",wages,I18n.t("Employee wages")) if wages>0 else ""
static func ip_dispute(job_id: String) -> String:
	var job := Jobs.get_job(job_id)
	if job.is_empty() or job.get("status","")!="paid" or job.get("segment","") not in ["media","manufacturing"]:return ""
	if job.get("ip_checked",false):return ""
	job["ip_checked"]=true
	return _open(str(job["entity"]),"ip",job_id,float(job["price"])*float(cfg()["ip_claim_share"]),str(job["client"]))

static func choose(id: String,option: String,automatic := false) -> Dictionary:
	var c := get_case(id)
	if c.is_empty() or not Tax.valid(str(c["entity"])) or c["status"]!="open" or not options().has(option):return {"ok":false,"error":I18n.t("Choose an open dispute for this company.")}
	var terms: Dictionary=options()[option]
	var fee := float(terms["fee"])
	if not automatic and Ledger.cash(c["entity"])<fee:return {"ok":false,"error":I18n.t("Save the legal fee first.")}
	Ledger.expense(c["entity"],"legal",fee,I18n.t("Legal fee: %s")%Fmt.money(fee),{"type":"legal","id":id,"segment":Jobs.get_job(str(c["job"])).get("segment","shared")},"cash" if Ledger.cash(c["entity"])>=fee else "accounts_payable")
	c["status"]="pending"
	c["option"]=option
	c["terms"]=terms.duplicate(true)
	c["relationship"]=int(terms["relationship"])
	c["resolves"]=Clock.now()+int(terms["days"])*Clock.DAY
	Sim.cancel("gov.legal_timeout","id",id)
	Sim.schedule(int(c["resolves"]),"gov.legal_result",{"id":id,"entity":c["entity"]})
	Brand.record(c["entity"],"crises",-1 if option=="settle" else -3)
	return {"ok":true,"fee":fee,"days":terms["days"]}

static func _resolve(c: Dictionary) -> void:
	var entity := str(c["entity"])
	if not Tax.valid(entity):return
	var win := GameState.randf()<float(c["terms"]["win"])
	var share := float(c["terms"]["recovery"]) if win else 0.0
	var amount := float(c["amount"])
	var job := Jobs.get_job(str(c["job"]))
	var src := {"type":"legal","id":c["id"],"segment":job.get("segment","shared")}
	if c["kind"]=="customer":
		amount=minf(amount,minf(float(job.get("receivable",0)),maxf(0,Ledger.balance(entity,"accounts_receivable"))))
		var got := snappedf(amount*share,.01)
		Ledger.post(entity,I18n.t("Disputed invoice recovered: %s")%Fmt.money(got),[{"acct":"cash","dr":got},{"acct":"exp:bad_debt","dr":amount-got},{"acct":"accounts_receivable","cr":amount}],src)
		c["recovered"]=got
		job["receivable"]=0.0
		job["status"]="paid" if got>=amount-.01 else "written_off"
	elif c["kind"]=="supplier":
		# Late-performance compensation is an actual counterparty settlement; paid construction remains on its books.
		amount=minf(amount,float(job.get("paid_cost",0))*float(cfg()["supplier_compensation_share"]))
		var got := snappedf(amount*share,.01)
		if got>0:Ledger.post(entity,I18n.t("Supplier breach settlement: %s")%Fmt.money(got),[{"acct":"cash","dr":got},{"acct":"other_income","cr":got}],src)
		c["recovered"]=got
	elif c["kind"]=="employee":
		amount=minf(amount,maxf(0,-Ledger.balance(entity,"wages_payable")))
		Ledger.post(entity,I18n.t("Employee wages settled: %s")%Fmt.money(amount),[{"acct":"wages_payable","dr":amount},{"acct":"cash" if Ledger.cash(entity)>=amount else "accounts_payable","cr":amount}],src)
		var damages := snappedf(amount*(1.0-share)*float(cfg()["employee_damage_share"]),.01)
		if damages>0:Ledger.expense(entity,"legal",damages,I18n.t("Employee dispute compensation: %s")%Fmt.money(damages),Insurance.loss_source(src,"liability"),"cash" if Ledger.cash(entity)>=damages else "accounts_payable")
		c["paid"]=amount+damages
		Brand.record(entity,"employees",-4 if not win else 2)
	elif c["kind"]=="ip":
		var pay := snappedf(amount*(1.0-share),.01)
		if pay>0:Ledger.expense(entity,"legal",pay,I18n.t("IP licence settlement: %s")%Fmt.money(pay),Insurance.loss_source(src,"liability"),"cash" if Ledger.cash(entity)>=pay else "accounts_payable")
		c["paid"]=pay
		Brand.record(entity,"news",-8 if not win else 2)
	if not job.is_empty():
		job["dispute_pause"]=false
		job["client_relationship"]=clampi(int(job.get("client_relationship",50))+int(c["relationship"]),0,100)
		# Counterparties reduce advance-payment terms for a finite period after a dispute.
		job["relationship_until"]=Clock.now()+int(cfg()["cooldown_days"])*Clock.DAY
	c["relationship_until"]=Clock.now()+int(cfg()["cooldown_days"])*Clock.DAY
	c["status"]="resolved"
	c["won"]=win
	Brand.record(entity,"crises",3 if win else -3)
	GameState.timeline(I18n.t("Legal case %s closed. Recovered %s; paid %s.")%[c["id"],Fmt.money(float(c["recovered"])),Fmt.money(float(c["paid"]))],"business")

static func handle(kind: String,p: Dictionary) -> void:
	var c := get_case(str(p.get("id","")))
	if c.is_empty() or not Tax.valid(str(c["entity"])):return
	if kind=="gov.legal_timeout" and c["status"]=="open":choose(str(c["id"]),"settle",true)
	elif kind=="gov.legal_result" and c["status"]=="pending":_resolve(c)
static func on_hour() -> void:
	var day := Clock.day_index()
	var entity := GameState.business_entity()
	# One draw per company per day (#91): a portfolio pass visits each company with its own entity.
	if not S().has("last_days"):S()["last_days"]={}
	var seen := int(S()["last_days"].get(entity,-1 if CompanyPortfolio.is_multi() else int(S()["last_day"])))
	if seen==day:return
	S()["last_day"]=day
	S()["last_days"][entity]=day
	if not Tax.valid(entity) or Clock.now()<int(S()["cooldowns"].get(entity,0)):return
	var id := ""
	if Ledger.balance(entity,"wages_payable")<0 and GameState.randf()<float(cfg()["employee_chance"]):id=employee_dispute(entity)
	for job in Jobs.S()["items"].values():
		if id!="" or job.get("entity","")!=entity or job.get("dispute_pause",false):continue
		if job.get("direction","")=="purchase" and job.get("status","")=="active" and not job.get("supplier_checked",false) and float(job.get("paid_cost",0))>0 and Clock.now()>int(job["due"]) and float(job["progress"])<float(job["work"]) and Ledger.cash(entity)>=maxf(0,float(job["price"])-float(job["paid_cost"])):
			job["supplier_checked"]=true
			if GameState.randf()<float(cfg()["supplier_chance"]):id=supplier_breach(str(job["id"]))
		elif job.get("status","")=="paid" and job.get("segment","") in ["media","manufacturing"] and GameState.randf()<float(cfg()["ip_chance"]):id=ip_dispute(str(job["id"]))
	if id!="":S()["cooldowns"][entity]=Clock.now()+int(cfg()["cooldown_days"])*Clock.DAY
static func on_company_closed(entity: String) -> void:
	for c in cases(entity):
		if c["status"] in ["open","pending"]:c["status"]="closed"
	for kind in ["gov.legal_timeout","gov.legal_result"]:Sim.cancel(kind,"entity",entity)

## A real counterparty changes its next advance payment; effects expire and never alter NPC story relations.
static func client_relationship(entity: String,party: String) -> int:
	var score := 50
	for c in cases(entity):
		if c["party"]==party and c["status"]=="resolved" and Clock.now()<int(c.get("relationship_until",0)):
			score+=int(c["relationship"])
	return clampi(score,0,100)
