class_name FreelanceWorkflow
extends RefCounted
## Versioned stages stored inside Careers gigs. Legacy gigs retain their original delivery path.
static func cfg() -> Dictionary: return DataDB.economy.get("workflows", {})
static func gig(id: String) -> Dictionary: return Careers.F()["gigs"].get(id, {})
static func available(g: Dictionary) -> bool:
	return not g.is_empty() and g.get("status", "") in ["active", "late"] and not GameState.data["entities"].get(g.get("entity", "player"), {}).has("closed")
static func begin(g: Dictionary) -> void:
	g["workflow"] = {"stage": "interview", "asked": [], "knowledge": 0, "quality": 0.0, "sessions": 0, "revisions": 0, "revision_limit": int(cfg()["revision_limit"]), "scope_done": false, "daily_hours": {}, "type": g.get("work_type", "market")}
const STAGES := {"interview":"Interview", "proposal":"Proposal", "work":"Execution", "scope":"Added scope", "delivery":"Delivery", "revision":"Client revision", "revision_work":"Revision work", "acceptance":"Acceptance", "failed":"Acceptance failed", "accepted":"Accepted", "legacy":"Legacy project"}
static func stage_label(g: Dictionary) -> String: return I18n.t(STAGES.get(stage(g), stage(g)))
static func stage(g: Dictionary) -> String: return str(g.get("workflow", {}).get("stage", "legacy"))
static func ask(id: String, topic: String) -> Dictionary:
	var g := gig(id)
	if not available(g) or stage(g) != "interview" or not topic in ["goal", "audience", "budget"]: return blocked()
	var w: Dictionary = g["workflow"]
	if topic in w["asked"]: return blocked()
	w["asked"].append(topic)
	w["knowledge"] = int(w["knowledge"]) + 1
	return {"ok": true}
static func prepare_proposal(id: String) -> Dictionary:
	var g := gig(id)
	if not available(g) or stage(g) != "interview": return blocked()
	g["workflow"]["stage"] = "proposal"
	return {"ok": true}

static func propose(id: String, multiplier: float, revisions: int) -> Dictionary:
	var g := gig(id)
	if not available(g) or stage(g) != "proposal" or not is_finite(multiplier) or multiplier < float(cfg()["quote_min"]) or multiplier > float(cfg()["quote_max"]) or revisions < 0 or revisions > int(cfg()["revision_max"]): return blocked()
	var ceiling := float(g["fee"]) * (1.0 + maxf(0.0, Careers.rep() - 3.0) * float(cfg()["quote_per_star"]))
	var quote := snappedf(float(g["fee"]) * multiplier, 0.01)
	if quote > ceiling: return {"ok": false, "error": I18n.t("The client rejected this quote. Lower it or build your reputation.")}
	g["fee"] = quote
	g["workflow"]["revision_limit"] = revisions
	g["workflow"]["stage"] = "work"
	g["workflow"]["contract"] = {"fee": quote, "hours": g["hours"], "revisions": revisions}
	return {"ok": true}
static func work(id: String, hours: float, quality: float) -> Dictionary:
	var g := gig(id)
	if not available(g) or stage(g) not in ["work", "revision_work"] or not is_finite(hours) or not is_finite(quality) or hours <= 0 or quality < 0 or quality > 1: return blocked()
	var w: Dictionary = g["workflow"]
	var day := str(Clock.day_index())
	# The allowance belongs to the player, so switching projects cannot bypass it.
	if not Careers.C().has("daily_freelance_hours"):
		Careers.C()["daily_freelance_hours"] = {}
		for existing in Careers.F()["gigs"].values():
			for saved_day in existing.get("workflow", {}).get("daily_hours", {}):
				var totals: Dictionary = Careers.C()["daily_freelance_hours"]
				totals[saved_day] = float(totals.get(saved_day, 0.0)) + float(existing["workflow"]["daily_hours"][saved_day])
	var used := float(Careers.C()["daily_freelance_hours"].get(day, 0.0))
	var clock_h := minf(hours, minf(float(Careers.session_hours()), float(cfg()["daily_hours_max"]) - used))
	if clock_h <= 0: return {"ok": false, "error": I18n.t("Today's consulting hours are used. Rest and continue tomorrow.")}
	w["daily_hours"][day] = float(w["daily_hours"].get(day, 0.0)) + clock_h
	Careers.C()["daily_freelance_hours"][day] = used + clock_h
	w["quality"] = float(w["quality"]) + quality
	w["sessions"] = int(w["sessions"]) + 1
	g["done"] = minf(float(g["hours"]), float(g["done"]) + clock_h * (float(cfg()["work_base_efficiency"]) + float(cfg()["work_quality_efficiency"]) * quality))
	Careers.C()["last_freelance_day"] = Clock.day_index()
	Clock.advance(roundi(clock_h * 60))
	GameState.inc_stat("gig_hours", clock_h)
	# A clock jump can cancel the gig; do not reopen it afterward.
	if not available(g): return {"ok": false, "error": I18n.t("This job is no longer available.")}
	if not w["scope_done"] and float(g["done"]) >= float(g["hours"]) * 0.5:
		w["scope_done"] = true
		if float(g.get("scope_draw", 1.0)) < float(cfg()["scope_chance"]): w["stage"] = "scope"
	if float(g["done"]) >= float(g["hours"]) and w["stage"] != "scope": w["stage"] = "delivery"
	return {"ok": true, "delivered": false, "hours": clock_h}
static func scope(id: String, charge: bool) -> Dictionary:
	var g := gig(id)
	if not available(g) or stage(g) != "scope": return blocked()
	var extra := float(g["hours"]) * float(cfg()["scope_extra"])
	g["hours"] = float(g["hours"]) + extra
	if charge: g["fee"] = snappedf(float(g["fee"]) * (1.0 + float(cfg()["scope_surcharge"])), 0.01)
	g["workflow"]["scope_choice"] = "charge" if charge else "absorb"
	g["workflow"]["stage"] = "work"
	return {"ok": true}
static func deliver(id: String) -> Dictionary:
	var g := gig(id)
	if not available(g) or stage(g) != "delivery" or float(g["done"]) < float(g["hours"]): return blocked()
	var w: Dictionary = g["workflow"]
	# At least one client revision is requested; its treatment follows the signed revision allowance.
	w["stage"] = "revision" if int(w["revisions"]) == 0 else "acceptance"
	return {"ok": true}
static func revise(id: String, charge: bool) -> Dictionary:
	var g := gig(id)
	if not available(g) or stage(g) not in ["revision", "failed"]: return blocked()
	var w: Dictionary = g["workflow"]
	var covered := int(w["revisions"]) < int(w["revision_limit"])
	if not covered and not charge: return {"ok": false, "error": I18n.t("Included revisions are used. Agree a paid revision or settle at a discount.")}
	if not covered:
		g["fee"] = snappedf(float(g["fee"]) + float(cfg()["revision_fee"]), 0.01)
	w["revisions"] = int(w["revisions"]) + 1
	# The clarification obtained during feedback repairs missing interview information.
	w["knowledge"] = mini(3, int(w["knowledge"]) + 1)
	g["hours"] = float(g["hours"]) + float(cfg()["revision_hours"])
	w["stage"] = "revision_work"
	return {"ok": true}
static func accept_delivery(id: String, discount := false) -> Dictionary:
	var g := gig(id)
	if not available(g) or stage(g) not in ["acceptance", "revision", "failed"]: return blocked()
	if not discount and stage(g) != "acceptance": return blocked()
	var w: Dictionary = g["workflow"]
	var quality := float(w["quality"]) / maxi(1, int(w["sessions"]))
	if not discount and (int(w["knowledge"]) < 2 or quality < float(cfg()["accept_quality"])):
		w["stage"] = "failed"
		return {"ok": false, "error": I18n.t("Acceptance failed. Revise the work or settle at a discount.")}
	if discount: g["fee"] = snappedf(float(g["fee"]) * float(cfg()["settlement_rate"]), 0.01)
	w["stage"] = "accepted"
	w["rating"] = 3 if discount else clampi(roundi(quality * 5), 1, 5)
	return Careers._deliver(g)
static func blocked() -> Dictionary: return {"ok": false, "error": I18n.t("This stage is unavailable. Finish the previous step first.")}
