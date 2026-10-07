class_name Partnerships
extends RefCounted
## Strategic partnership contracts (#116): distribution, co-brand and long-term supply. Each period the partner
## issues a real Job; the player does the work and the partner pays after the job's terms. A revenue share of each
## payment actually received goes to the partner, and an exclusive deal blocks rivals of the same kind. Nothing is
## income until a delivered job is paid.

static func cfg() -> Dictionary:
	return Fundraising.cfg()
static func P() -> Dictionary:
	return Fundraising.S()["partnerships"]
static func get_item(id: String) -> Dictionary:
	return P().get(id, {})
static func def(id: String) -> Dictionary:
	return cfg()["partners"].get(id, {})
static func name_of(id: String) -> String:
	return I18n.t(str(def(id).get("name", id)))
static func kind_label(kind: String) -> String:
	return I18n.t(str(cfg()["partner_kinds"].get(kind, {}).get("label", kind)))
static func share_label(kind: String) -> String:
	return I18n.t(str(cfg()["partner_kinds"].get(kind, {}).get("share_label", "Revenue share")))
static func met(id: String) -> bool:
	return Fundraising.N()["partners_met"].has(id)
static func is_live(item: Dictionary) -> bool:
	return str(item.get("status", "")) in ["offered", "active"]
static func item_for(partner: String) -> Dictionary:
	for item in P().values():
		if item["partner"] == partner and is_live(item):
			return item
	return {}
static func block(id: String) -> String:
	if def(id).is_empty():
		return "Choose a partner."
	if not item_for(id).is_empty():
		return ""
	var why := Fundraising.base_block()
	if why != "":
		return why
	if Fundraising.chapter_rank() < int(cfg()["min_chapter_partner"]):
		return "Strategic partners open up from Chapter 7."
	if not met(id):
		return "Meet this partner at a city event first."
	return ""
## An exclusive deal in force for this kind, if any.
static func exclusive_holder(kind: String) -> Dictionary:
	for item in P().values():
		if item["status"] == "active" and item["kind"] == kind and bool(item["exclusive"]):
			return item
	return {}
static func terms_for(id: String) -> Dictionary:
	var d := def(id)
	return {"price": float(d["price"]), "share": float(d["share"]), "periods": int(d["periods"]), "period_days": int(d["period_days"]), "minutes": int(d["minutes"]),
		"supplies": float(d["supplies"]), "exclusive_price": snappedf(float(d["price"]) * (1.0 + float(d["exclusive_bonus"])), 0.01), "exclusive_days": int(d["exclusive_days"]), "break_share": float(d["break_share"])}
## Net cash per delivered period after the partner's share and the supplies, and over the whole deal.
static func net_per_period(t: Dictionary, exclusive: bool) -> float:
	var price := float(t["exclusive_price"]) if exclusive else float(t["price"])
	return snappedf(price * (1.0 - float(t["share"])) - float(t["supplies"]), 0.01)
static func propose(id: String) -> Dictionary:
	var open := item_for(id)
	if not open.is_empty():
		return {"ok": true, "id": open["id"], "resumed": true}
	var why := block(id)
	if why != "":
		return Fundraising.error(why)
	var pid := "PT-%d" % int(Fundraising.S()["pseq"])
	Fundraising.S()["pseq"] = int(Fundraising.S()["pseq"]) + 1
	var d := def(id)
	P()[pid] = {"id": pid, "partner": id, "kind": str(d["kind"]), "status": "offered", "created": Clock.now(), "expires": Clock.now() + int(cfg()["partner_offer_days"]) * Clock.DAY,
		"terms": terms_for(id), "exclusive": false, "jobs": [], "issued": 0, "delivered": 0, "paid": 0, "missed": 0, "share_paid": 0.0, "revenue": 0.0}
	GameState.add_message(id, "Partner terms are ready to review.", {"target":{"kind":"fundraising", "tab":"partners", "id":pid}})
	return {"ok": true, "id": pid}
static func respond(pid: String, choice: String) -> Dictionary:
	match choice:
		"sign":
			return sign_deal(pid, false)
		"exclusive":
			return sign_deal(pid, true)
		"decline":
			return decline(pid)
	return Fundraising.error("Choose how to respond to the partner.")
static func decline(pid: String) -> Dictionary:
	var item := get_item(pid)
	if item.is_empty() or item["status"] != "offered":
		return Fundraising.error("This proposal is no longer open.")
	item["status"] = "declined"
	return {"ok": true}
static func sign_deal(pid: String, exclusive: bool) -> Dictionary:
	var item := get_item(pid)
	if item.is_empty() or item["status"] != "offered":
		return Fundraising.error("This proposal is no longer open.")
	if Clock.now() > int(item["expires"]):
		item["status"] = "expired"
		return Fundraising.error("This proposal is no longer open.")
	var why := Fundraising.base_block()
	if why != "":
		return Fundraising.error(why)
	var holder := exclusive_holder(str(item["kind"]))
	if not holder.is_empty():
		return {"ok": false, "error": I18n.t("You are bound by an exclusive agreement with %s for this kind of deal until it ends.") % name_of(str(holder["partner"]))}
	item["status"] = "active"
	item["exclusive"] = exclusive
	item["started"] = Clock.now()
	item["next_period"] = Clock.now()
	if exclusive:
		item["exclusive_until"] = Clock.now() + int(item["terms"]["exclusive_days"]) * Clock.DAY
	item["price"] = float(item["terms"]["exclusive_price"]) if exclusive else float(item["terms"]["price"])
	_issue(item)
	GameState.set_flag("partnership_signed")
	GameState.set_flag("partner_" + str(item["kind"]))
	GameState.inc_stat("partnerships_signed")
	GameState.timeline(I18n.t("Signed a %s with %s.") % [kind_label(str(item["kind"])).to_lower(), name_of(str(item["partner"]))], "company")
	return {"ok": true}
static func _issue(item: Dictionary) -> void:
	var t: Dictionary = item["terms"]
	var n := int(item["issued"]) + 1
	var job := Jobs.offer({"entity": GameState.company_id(), "client": name_of(str(item["partner"])), "scope": I18n.t("%s: deliverable %d of %d") % [kind_label(str(item["kind"])), n, int(t["periods"])],
		"price": float(item["price"]), "work": float(t["minutes"]), "segment": "shared", "terms": 30, "deposit": 0.0, "penalty_rate": 0.1,
		"due": Clock.now() + int(cfg()["partner_job_days"]) * Clock.DAY, "partnership": item["id"], "partnership_cost": float(t["supplies"])})
	item["issued"] = n
	item["next_period"] = int(item["next_period"]) + int(t["period_days"]) * Clock.DAY
	if job != "":
		item["jobs"].append(job)
static func current_job(item: Dictionary) -> Dictionary:
	if item.get("jobs", []).is_empty():
		return {}
	var job := Jobs.get_job(str(item["jobs"][-1]))
	return job if str(job.get("status", "")) in ["offered", "active"] else {}
## Do this period's deliverable: pay the supplies, spend the work time, deliver and invoice the partner's job.
static func work(pid: String) -> Dictionary:
	var item := get_item(pid)
	if item.is_empty() or item["status"] != "active":
		return Fundraising.error("This partnership is not active.")
	var job := current_job(item)
	if job.is_empty():
		return Fundraising.error("There is no deliverable waiting. The next one arrives on its date.")
	var ent := GameState.company_id()
	var cost := float(item["terms"]["supplies"])
	if Ledger.cash(ent) < cost:
		return Fundraising.error("Fund the deliverable's supplies before working.")
	var accepted := Jobs.accept(str(job["id"])) if job["status"] == "offered" else {"ok": true}
	if not accepted["ok"]:
		return accepted
	Ledger.expense(ent, "other", cost, I18n.t("Partner deliverable supplies: %s") % Fmt.money(cost), {"type": "partner_supplies", "partnership": pid, "id": job["id"]})
	var minutes := int(item["terms"]["minutes"])
	PersonalLife.work(minutes)
	Clock.advance(minutes)
	var done := Jobs.progress(str(job["id"]), float(minutes))
	if not done["ok"]:
		return done
	Jobs.deliver(str(job["id"]))
	var billed := Jobs.invoice(str(job["id"]))
	if billed["ok"]:
		item["delivered"] = int(item["delivered"]) + 1
	return billed
static func terminate(pid: String) -> Dictionary:
	var item := get_item(pid)
	if item.is_empty() or item["status"] != "active":
		return Fundraising.error("This partnership is not active.")
	var ent := GameState.company_id()
	var fee := 0.0
	if bool(item["exclusive"]):
		var remaining := int(item["terms"]["periods"]) - int(item["issued"]) + (1 if not current_job(item).is_empty() else 0)
		fee = snappedf(float(item["terms"]["break_share"]) * float(item["price"]) * remaining, 0.01)
	if fee > 0.0 and Ledger.cash(ent) < fee:
		return Fundraising.error("Not enough company cash for the exit fee. Keep delivering until the agreement ends.")
	if fee > 0.0:
		Ledger.expense(ent, "other", fee, I18n.t("Exclusive partnership exit fee: %s") % Fmt.money(fee), {"type": "partner_exit", "partnership": pid})
	_finish(item, "ended")
	return {"ok": true, "fee": fee}
static func _finish(item: Dictionary, status: String) -> void:
	var job := current_job(item)
	if not job.is_empty():
		job["status"] = "closed"
	item["status"] = status
	item["ended"] = Clock.now()
static func on_job_paid(job: Dictionary) -> void:
	var pid := str(job.get("partnership", ""))
	if pid == "" or not Fundraising.has_state():
		return
	var item := get_item(pid)
	if item.is_empty():
		return
	var share := snappedf(float(job["price"]) * float(item["terms"]["share"]), 0.01)
	item["paid"] = int(item["paid"]) + 1
	item["revenue"] = float(item["revenue"]) + float(job["price"])
	if share > 0.0:
		var category := "platform_fees" if str(item["kind"]) == "distribution" else "other"
		Ledger.expense(str(job["entity"]), category, share, I18n.t("%s: %s of job %s paid to the partner") % [share_label(str(item["kind"])), Fmt.pct(float(item["terms"]["share"])), str(job["id"])], {"type": "partner_share", "partnership": pid, "id": job["id"]})
		item["share_paid"] = float(item["share_paid"]) + share
	GameState.inc_stat("partner_jobs_paid")
static func on_hour() -> void:
	for item in P().values():
		if item["status"] == "offered" and Clock.now() > int(item["expires"]):
			item["status"] = "expired"
			continue
		if item["status"] != "active":
			continue
		var guard := 0
		while int(item["issued"]) < int(item["terms"]["periods"]) and Clock.now() >= int(item["next_period"]) and guard < 12:
			guard += 1
			var pending := current_job(item)
			if not pending.is_empty():
				pending["status"] = "closed"
				item["missed"] = int(item["missed"]) + 1
				GameState.add_message(str(item["partner"]), I18n.t("The deliverable was not finished in time and has been closed."))
			if int(item["missed"]) >= int(cfg()["partner_missed_limit"]):
				_finish(item, "ended")
				GameState.add_message(str(item["partner"]), I18n.t("Too many missed deliverables: we are ending the agreement."))
				break
			_issue(item)
		if item["status"] != "active":
			continue
		if int(item["issued"]) >= int(item["terms"]["periods"]) and Clock.now() >= int(item["next_period"]):
			var last := current_job(item)
			if not last.is_empty():
				last["status"] = "closed"
				item["missed"] = int(item["missed"]) + 1
			_finish(item, "completed")
			GameState.add_message(str(item["partner"]), I18n.t("The agreement has run its full term. Thank you for the work."))
		elif bool(item["exclusive"]) and Clock.now() >= int(item.get("exclusive_until", 0)) and item["status"] == "active":
			item["exclusive"] = false
static func on_company_closed() -> void:
	for item in P().values():
		if is_live(item):
			_finish(item, "closed")
## The Season 3 expo bid counts a partnership only after real delivered work has been paid.
static func expo_quality_bonus() -> float:
	if not Fundraising.has_state():
		return 0.0
	for item in P().values():
		if int(item.get("paid", 0)) > 0:
			return float(cfg()["expo_quality_bonus"])
	return 0.0
