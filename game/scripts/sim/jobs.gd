class_name Jobs
extends RefCounted
## Product-independent B2B scope/work/delivery/invoice lifecycle. Existing product contracts retain stock logic.

static func S() -> Dictionary:
	if not GameState.data.has("jobs_service"):
		GameState.data["jobs_service"] = {"items":{}, "seq":1}
	return GameState.data["jobs_service"]

static func get_job(id: String) -> Dictionary:
	return S()["items"].get(id, {})

static func offer(spec: Dictionary) -> String:
	if not is_finite(float(spec.get("price", 0))) or not is_finite(float(spec.get("work", 1))) or str(spec.get("client", "")) == "" or str(spec.get("scope", "")) == "" or float(spec.get("price", 0)) <= 0 or int(spec.get("terms", 0)) not in [0,30,60] or float(spec.get("work", 1)) <= 0:
		return ""
	var id := "JOB-%d" % int(S()["seq"])
	S()["seq"] = int(S()["seq"]) + 1
	var job := spec.duplicate(true)
	job.merge({"id":id, "status":"offered", "progress":0.0, "entity":spec.get("entity", GameState.business_entity()),
		"due":spec.get("due", Clock.now()+Clock.DAY), "work":spec.get("work", 1.0),
		"segment":spec.get("segment", "shared"), "deposit":clampf(float(spec.get("deposit", 0)), 0, 1),
		"penalty_rate":clampf(float(spec.get("penalty_rate", 0)), 0, 1), "deposit_paid":0.0}, true)
	if job.get("direction","")!="purchase":
		job["client_relationship"]=Legal.client_relationship(str(job["entity"]),str(job["client"]))
		job["deposit"]=float(job["deposit"])*float(job["client_relationship"])/50.0
	# An offer nobody takes lapses at its due time (or an explicit `expires_at`) instead of sitting in the list forever.
	job["expires_at"] = int(spec.get("expires_at", job["due"]))
	job["competitors"] = spec.get("competitors", Rivals.competitors(str(job["segment"]))).duplicate(true)
	S()["items"][id] = job
	return id

static func _available(job: Dictionary) -> bool:
	return not job.is_empty() and GameState.data["entities"].has(job["entity"]) and not GameState.data["entities"][job["entity"]].has("closed") and not job.get("dispute_pause",false)

static func deposit_lines(amount: float) -> Array:
	return [{"acct":"cash", "dr":amount}, {"acct":"deferred_revenue", "cr":amount}]

static func invoice_lines(price: float, deposit: float) -> Array:
	return [{"acct":"accounts_receivable", "dr":price-deposit}, {"acct":"deferred_revenue", "dr":deposit}, {"acct":"revenue", "cr":price}]

static func accept(id: String) -> Dictionary:
	var job := get_job(id)
	if not _available(job) or job["status"] != "offered" or Clock.now() > int(job["due"]) or job.get("direction","")=="purchase":
		return {"ok":false, "error":I18n.t("This job is no longer available.")}
	job["status"] = "active"
	job["deposit_paid"] = snappedf(float(job["price"]) * float(job["deposit"]), 0.01)
	Ledger.post(job["entity"], I18n.t("Job deposit: %s") % id, deposit_lines(job["deposit_paid"]), {"type":"job", "id":id, "segment":job["segment"]})
	GameState.timeline(I18n.t("Accepted job %s: %s") % [id, job["scope"]], "business")
	return {"ok":true}

static func progress(id: String, work: float) -> Dictionary:
	var job := get_job(id)
	if not _available(job) or job["status"] != "active" or work <= 0 or not is_finite(work):
		return {"ok":false, "error":I18n.t("No active job to work on.")}
	job["progress"] = minf(float(job["work"]), float(job["progress"])+work)
	return {"ok":true, "progress":job["progress"]}

## Outbound construction jobs use paid milestones, never a seller's deposit or revenue invoice.
static func accept_purchase(id: String) -> Dictionary:
	var job := get_job(id)
	if not _available(job) or job["status"]!="offered" or job.get("direction","")!="purchase":return {"ok":false,"error":I18n.t("Choose an offered construction contract.")}
	job["status"]="active"
	job["paid_cost"]=0.0
	return {"ok":true}
static func purchase_milestone(id: String, amount: float, work: float, account: String) -> Dictionary:
	var job := get_job(id)
	if not _available(job) or job.get("direction","")!="purchase" or job["status"]!="active" or not is_finite(amount) or amount<=0 or work<0 or not is_finite(work) or Ledger.cash(job["entity"])<amount or float(job.get("paid_cost",0))+amount>float(job["price"])+.01:return {"ok":false,"error":I18n.t("Fund the next construction milestone.")}
	Ledger.post(job["entity"],I18n.t("Contractor milestone paid"),[{"acct":account,"dr":amount},{"acct":"cash","cr":amount}],{"type":"job_purchase","id":id,"segment":job["segment"]})
	job["paid_cost"]=snappedf(float(job["paid_cost"])+amount,.01)
	if work==0:return {"ok":true,"progress":job["progress"]}
	return progress(id,work)

static func deliver(id: String) -> Dictionary:
	var job := get_job(id)
	if not _available(job) or job["status"] != "active" or float(job["progress"]) < float(job["work"]):
		return {"ok":false, "error":I18n.t("Finish the agreed scope before delivery.")}
	job["status"] = "delivered"
	job["delivered"] = Clock.now()
	return {"ok":true}

static func invoice(id: String) -> Dictionary:
	var job := get_job(id)
	if not _available(job) or job["status"] != "delivered" or job.get("direction","")=="purchase":
		return {"ok":false, "error":I18n.t("Deliver this job before invoicing.")}
	var penalty := snappedf(float(job["price"]) * float(job["penalty_rate"]), 0.01) if int(job["delivered"]) > int(job["due"]) else 0.0
	var receivable := maxf(0, float(job["price"])-float(job["deposit_paid"])-penalty)
	var lines := invoice_lines(float(job["price"]), float(job["deposit_paid"]))
	if penalty > 0:
		var credit := minf(penalty, float(job["price"])-float(job["deposit_paid"]))
		lines += [{"acct":"exp:penalties", "dr":penalty}, {"acct":"accounts_receivable", "cr":credit}, {"acct":"cash", "cr":penalty-credit}]
	Ledger.post(job["entity"], I18n.t("Job invoice: %s") % id, lines, {"type":"job", "id":id, "segment":job["segment"]})
	job["status"] = "invoiced"
	job["receivable"] = receivable
	job["pay_due"] = Clock.now()+int(job["terms"])*Clock.DAY
	Sim.schedule(job["pay_due"], "job.pay", {"id":id})
	GameState.timeline(I18n.t("Invoiced job %s: %s") % [id, Fmt.money(receivable)], "business")
	if int(job["terms"]) == 0: handle("job.pay", {"id":id})
	return {"ok":true, "receivable":receivable}

static func handle(kind: String, payload: Dictionary) -> void:
	var job := get_job(str(payload.get("id", "")))
	if kind != "job.pay" or not _available(job) or job["status"] != "invoiced": return
	if not Legal.customer_payment(job):return
	var amount := float(job["receivable"])
	Ledger.post(job["entity"], I18n.t("Job payment: %s") % job["id"], [{"acct":"cash", "dr":amount}, {"acct":"accounts_receivable", "cr":amount}], {"type":"job", "id":job["id"], "segment":job["segment"]})
	job["status"] = "paid"
	Sim.cancel("job.pay", "id", job["id"])
	Fundraising.on_job_paid(job)

## Daily sweep: offers past their expiry become "expired" (they can no longer be accepted, and drop out of lending math).
static func expire_offers() -> int:
	var n := 0
	for job in S()["items"].values():
		if job["status"] == "offered" and Clock.now() > int(job.get("expires_at", job.get("due", Clock.now()))):
			job["status"] = "expired"
			n += 1
	return n

static func on_hour(_t: int, h: int) -> void:
	if h == 0: expire_offers()

static func on_company_closed(entity: String) -> void:
	for job in S()["items"].values():
		if job["entity"] != entity or job["status"] in ["paid", "closed"]: continue
		if float(job.get("deposit_paid", 0)) > 0 and job["status"] in ["active", "delivered"]:
			var amount := float(job["deposit_paid"])
			Ledger.post(entity, I18n.t("Cancelled job deposit: %s") % job["id"], [{"acct":"deferred_revenue", "dr":amount}, {"acct":"accounts_payable", "cr":amount}], {"type":"job", "segment":job["segment"]})
		job["status"] = "closed"
		Sim.cancel("job.pay", "id", job["id"])
