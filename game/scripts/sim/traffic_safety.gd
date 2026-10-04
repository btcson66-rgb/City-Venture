class_name TrafficSafety
extends RefCounted
## Personal injuries and policy live in JSON state; settlements reimburse only actual medical bills.
static func cfg() -> Dictionary: return DataDB.economy["traffic_safety"]
static func S() -> Dictionary:
	if not GameState.data.has("traffic_safety"):
		GameState.data["traffic_safety"] = {"accidents": [], "injury": "none", "until": 0, "startle_until": 0, "cooldown": 0, "active_accident": 0, "policy_until": 0, "renew": false}
	return GameState.data["traffic_safety"]
const SEVERITIES := {"major":"Severe injury", "minor":"Minor injury", "none":"No injury", "glancing":"Glancing contact"}
static func severity_label(value: String) -> String: return I18n.t(SEVERITIES.get(value,"No injury"))
static func grade(speed: float) -> String:
	if not is_finite(speed) or speed < 0: return "none"
	if speed < float(cfg()["glancing_below_px_s"]): return "glancing"
	return "major" if speed >= float(cfg()["major_from_px_s"]) else "minor"
static func green(t := -1) -> bool:
	return posmod(Clock.now() if t < 0 else t, int(cfg()["crossing_cycle_minutes"])) < int(cfg()["crossing_green_minutes"])
static func crossing(district: String, point: Vector2) -> bool:
	for g in DataDB.districts.get(district, {}).get("ground", []):
		if str(g["type"]) == "crosswalk_h":
			var r: Array = g["rect"]
			if Rect2(float(r[0])*16, float(r[1])*16, float(r[2])*16, float(r[3])*16).has_point(point): return true
	return false
static func protected_crossing(district: String, point: Vector2) -> bool: return crossing(district, point) and green()
static func speed_multiplier() -> float:
	if not GameState.has_game(): return 1.0
	var s := S()
	if Clock.now() < int(s["startle_until"]): return 0.0
	if s["injury"] == "minor" and Clock.now() >= int(s["until"]): s["injury"] = "none"
	return float(cfg()["minor_speed_factor"]) if s["injury"] != "none" else 1.0
static func hit(speed: float, district: String, point: Vector2) -> Dictionary:
	var severity := grade(speed)
	if speed <= 0 or severity == "none" or protected_crossing(district, point) or Clock.now() < int(S()["cooldown"]) or S()["injury"] == "major": return {"ok": false}
	var s := S()
	s["cooldown"] = Clock.now() + int(cfg()["contact_cooldown_minutes"])
	s["startle_until"] = Clock.now() + int(cfg()["startle_minutes"])
	if severity != "glancing":
		s["injury"] = severity
		s["until"] = Clock.now() + int(cfg()["minor_days"]) * Clock.DAY
	var lawful := not crossing(district, point) # Red crossing is always the pedestrian's fault.
	var a := {"id": s["accidents"].size()+1, "t": Clock.now(), "speed_px_s": speed, "severity": severity, "counterparty_fault": lawful and GameState.randf() < float(cfg()["counterparty_fault_chance"]), "medical_paid": 0.0, "health_claim": 0.0, "settled": false, "procedure_due": 0, "treated": false, "insured_at_hit": Clock.now() < int(s["policy_until"])}
	s["accidents"].append(a)
	if severity != "glancing": s["active_accident"] = int(a["id"])
	GameState.timeline(I18n.t("Traffic collision: %s. Visit the clinic or pharmacy.") % severity_label(severity), "life")
	return {"ok": true, "accident": a}
static func accident(id: int) -> Dictionary:
	for a in S()["accidents"]:
		if int(a["id"]) == id: return a
	return {}
static func latest() -> Dictionary: return S()["accidents"].back() if not S()["accidents"].is_empty() else {}
static func insured() -> bool: return Clock.now() < int(S()["policy_until"])
static func buy_policy() -> Dictionary:
	if insured() or Ledger.cash("player") < float(cfg()["premium"]): return {"ok": false}
	Ledger.expense("player", "personal_health", float(cfg()["premium"]), I18n.t("Personal health premium: %s / 30 days") % Fmt.money(float(cfg()["premium"])), {"type":"personal_health_premium"})
	S()["policy_until"] = Clock.now() + int(cfg()["policy_days"]) * Clock.DAY
	S()["renew"] = true
	return {"ok": true}
static func on_hour(_t: int, _h: int) -> void:
	if not GameState.data.has("traffic_safety"): return
	if S()["renew"] and not insured():
		S()["renew"] = false
		var result := buy_policy()
		if not result["ok"]: GameState.timeline(I18n.t("Health policy expired: add cash and buy a new policy."), "life")
static func current_injury() -> Dictionary: return accident(int(S().get("active_accident",0)))
static func treat() -> Dictionary:
	var a := current_injury()
	if a.is_empty() or a["treated"] or S()["injury"] == "none" or a["severity"] == "glancing": return {"ok": false}
	var fee := float(cfg()["major_fee"] if a["severity"] == "major" else cfg()["medicine_fee"])
	# Emergency care is billed as a payable if cash cannot cover the uninsured portion.
	if a["severity"] == "minor" and Ledger.cash("player") < fee * (1.0-float(cfg()["coverage"]) if a["insured_at_hit"] else 1.0): return {"ok":false}
	var claim := snappedf(fee * float(cfg()["coverage"]), 0.01) if a["insured_at_hit"] else 0.0
	Ledger.post("player", I18n.t("Medical treatment: %s") % Fmt.money(fee), [{"acct":"exp:medical", "dr":fee},{"acct":"accounts_payable", "cr":fee}], {"type":"traffic_medical", "accident":a["id"]})
	if claim > 0:
		Ledger.post("player", I18n.t("Health insurance claim: %s") % Fmt.money(claim), [{"acct":"accounts_payable", "dr":claim},{"acct":"other_income", "cr":claim}], {"type":"health_claim", "accident":a["id"]})
	var paid := minf(maxf(0.0, Ledger.cash("player")), fee-claim)
	if paid > 0: Ledger.post("player", I18n.t("Paid medical bill: %s") % Fmt.money(paid), [{"acct":"accounts_payable", "dr":paid},{"acct":"cash", "cr":paid}], {"type":"traffic_medical_payment", "accident":a["id"]})
	a["medical_paid"] = fee
	a["health_claim"] = claim
	a["debt"] = snappedf(fee-claim-paid, 0.01)
	a["treated"] = true
	var days := GameState.randi_range(int(cfg()["hospital_min_days"]), int(cfg()["hospital_max_days"])) if a["severity"] == "major" else 0
	a["hospital_days"] = days
	# Mark the bill and treatment before advancing so a resumed save cannot bill twice.
	S()["injury"] = "none"
	S()["startle_until"] = 0
	if days > 0: Clock.advance(days * Clock.DAY)
	GameState.timeline(I18n.t("Treatment complete: %d hospital days; medical bill %s; health claim %s.") % [days, Fmt.money(fee), Fmt.money(claim)], "life")
	return {"ok": true, "days": days, "fee":fee, "claim":claim}
static func settle(procedure := false, id := 0) -> Dictionary:
	var a := latest() if id == 0 else accident(id)
	if a.is_empty() or not a["counterparty_fault"] or not a["treated"] or a["settled"]: return {"ok": false}
	if procedure and int(a["procedure_due"]) == 0:
		a["procedure_due"] = Clock.now() + int(cfg()["procedure_days"]) * Clock.DAY
		GameState.timeline(I18n.t("Traffic claim filed. Return after seven days to collect the verified medical reimbursement."), "life")
		return {"ok": true, "pending":true}
	if int(a["procedure_due"]) > Clock.now(): return {"ok": false}
	var amount := snappedf((float(a["medical_paid"])-float(a["health_claim"])) * (1.0 if int(a["procedure_due"]) > 0 else float(cfg()["settlement_share"])), 0.01)
	a["settled"] = true
	var debt := minf(float(a.get("debt",0)), amount)
	Ledger.post("player", I18n.t("Counterparty medical settlement: %s") % Fmt.money(amount), [{"acct":"cash", "dr":amount-debt},{"acct":"accounts_payable", "dr":debt},{"acct":"other_income", "cr":amount}], {"type":"traffic_settlement", "accident":a["id"]})
	a["debt"] = float(a.get("debt",0))-debt
	GameState.timeline(I18n.t("Counterparty medical settlement: %s") % Fmt.money(amount), "life")
	return {"ok":true, "amount":amount}
static func pay_debt(id := 0) -> bool:
	var a := latest() if id == 0 else accident(id)
	var debt := float(a.get("debt",0))
	if debt <= 0 or Ledger.cash("player") < debt: return false
	Ledger.post("player", I18n.t("Paid medical bill: %s") % Fmt.money(debt), [{"acct":"accounts_payable", "dr":debt},{"acct":"cash", "cr":debt}], {"type":"traffic_medical_payment", "accident":a["id"]})
	a["debt"] = 0.0
	return true
## #94 hook: quote only. The vehicle owner must supply a real accident and post actual liability.
static func driver_quote(actual_damages: float, policy_coverage: float) -> Dictionary:
	if not is_finite(actual_damages) or actual_damages < 0 or not is_finite(policy_coverage): return {"ok": false}
	return {"ok":true, "liability":snappedf(actual_damages,0.01), "covered":snappedf(actual_damages*clampf(policy_coverage,0,1),0.01), "fault":"driver"}
