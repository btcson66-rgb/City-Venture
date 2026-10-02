class_name Bank
extends RefCounted
## Nexus Bank business lending (P1). Marcus Reed lends on cash flow and collateral, not ideas:
## the offer comes from the company's own books (trailing gross profit, receivables, signed contracts,
## stock at cost) minus existing debt. Loans amortise monthly: interest is an expense, principal
## reduces `loan_payable`. A missed payment costs a late fee and credit; two in a row and the bank
## calls the loan (full balance due in 7 days) — an unpaid call sends the company into insolvency.
## Credit score (300–850) lives in GameState.data["bank"] and follows the player's history.

const MIN_AGE_DAYS := 14
const MAX_LOAN := 250000.0
const LATE_FEE := 50.0


static func B() -> Dictionary:
	if not GameState.data.has("bank"):
		GameState.data["bank"] = {"credit": 680, "loans": {}, "seq": 1}
	return GameState.data["bank"]


static func credit() -> int:
	return int(B()["credit"])


static func adjust_credit(d: int, why := "") -> void:
	B()["credit"] = clampi(credit() + d, 300, 850)
	var _u := why


static func credit_band() -> String:
	var c := credit()
	return "Excellent" if c >= 760 else ("Good" if c >= 690 else ("Fair" if c >= 620 else "Poor"))


static func loans(ent := "") -> Array:
	return B()["loans"].values().filter(func(l): return l["status"] in ["active", "late", "called"] and (ent == "" or l["entity"] == ent))


static func debt(ent: String) -> float:
	return -Ledger.balance(ent, "loan_payable")


static func base_rate() -> float:
	return Macro.rate()


static func apr() -> float:
	return clampf(base_rate() + Replay.number("interest_surcharge", 0.0) + 0.06 + (720 - credit()) * 0.0004, 0.06, 0.24)


static func monthly_payment(principal: float, months: int, rate := -1.0) -> float:
	var r := (apr() if rate < 0 else rate) / 12.0
	if r <= 0.0:
		return principal / months
	return snappedf(principal * r / (1.0 - pow(1.0 + r, -months)), 0.01)


## The existing lending formula, also used to explain every prerequisite before an offer is available.
static func lending_basis() -> Dictionary:
	var cid := GameState.company_id()
	var age := 0
	var gp := 0.0
	var ar := 0.0
	var contracts := 0.0
	var stock := 0.0
	var existing := 0.0
	if cid != "":
		age = int((Clock.now() - int(GameState.data["entities"][cid].get("founded", 0))) / Clock.DAY)
		gp = maxf(0.0, float(MonthClose.compute(cid, Clock.now() - 30 * Clock.DAY, Clock.now())["gross_profit"]))
		ar = maxf(0.0, Ledger.balance(cid, "accounts_receivable") + Ledger.balance(cid, "marketplace_balance"))
		stock = maxf(0.0, Ledger.balance(cid, "inventory") + Ledger.balance(cid, "inventory_in_transit"))
		existing = debt(cid)
		for c in GameState.data["contracts"].values():
			if c["status"] == "active" and c.get("seller", "") == cid:
				contracts += float(c["total"]) - float(c.get("upfront_paid", 0.0))
	var collateral := ar * 0.7 + contracts * 0.6 + stock * 0.5
	var raw := maxf(0.0, gp * 3.0) + collateral - existing
	return {"age": age, "contracts": contracts, "raw": raw,
		"max": floorf(minf(MAX_LOAN, raw) / 1000.0) * 1000.0,
		"parts": [[I18n.t("3 × last 30 days' gross profit"), gp * 3],
		[I18n.t("70% of money owed to you"), ar * 0.7], [I18n.t("60% of signed contracts"), contracts * 0.6],
		[I18n.t("50% of stock at cost"), stock * 0.5], [I18n.t("minus existing debt"), -existing]]}


## Each row is the single source for both refusal order and the player's actionable checklist.
static func eligibility() -> Array[Dictionary]:
	var cid := GameState.company_id()
	var basis := lending_basis()
	var arrears := 0
	for l in loans(cid) if cid != "" else []:
		if l["status"] != "active":
			arrears += 1
	var ban := int(B().get("no_loans_until", 0))
	return [
		{"id": "company", "ok": cid != "", "label": "Registered company", "value": int(cid != ""), "need": 1, "gap": int(cid == ""),
		"hint_action": I18n.t("Register at City Hall, Civic Center."), "error": "We lend to registered companies."},
		{"id": "account", "ok": GameState.flag("business_account_opened"), "label": "Business bank account", "value": int(GameState.flag("business_account_opened")), "need": 1, "gap": int(not GameState.flag("business_account_opened")),
		"hint_action": I18n.t("Open a business account at the Nexus Bank counter, Financial District."), "error": "Open a business account with us first."},
		{"id": "credit", "ok": credit() >= 560 and Clock.now() >= ban, "label": "Credit score and lending ban", "value": credit(), "need": 560, "gap": maxi(0, 560 - credit()),
		"hint_action": I18n.t("Pay bills on time. Lending ban ends: %s.") % (Clock.fmt_datetime(ban) if ban > Clock.now() else I18n.t("No lending ban")), "error": "Your credit history needs time to recover."},
		{"id": "arrears", "ok": arrears == 0, "label": "Overdue or called loans", "value": arrears, "need": 0, "gap": arrears,
		"hint_action": I18n.t("Repay overdue loans in this screen; if the company is in insolvency, use the recovery options."), "error": "Not while a loan is in arrears."},
		{"id": "age", "ok": int(basis["age"]) >= MIN_AGE_DAYS or float(basis["contracts"]) > 0, "label": "Company days or an active contract", "value": basis["age"], "need": MIN_AGE_DAYS,
		"gap": 0 if float(basis["contracts"]) > 0 else maxi(0, MIN_AGE_DAYS - int(basis["age"])),
		"hint_action": I18n.t("Active contracts cover this condition: %s still to collect.") % Fmt.money0(float(basis["contracts"])) if float(basis["contracts"]) > 0 else I18n.t("%d more days, or accept an active contract in Company OS → Contracts.") % maxi(0, MIN_AGE_DAYS - int(basis["age"])),
		"error": I18n.t("Come back when %s has %d days of statements, or a signed contract.") % [GameState.business_display_name(), MIN_AGE_DAYS]},
		{"id": "capacity", "ok": float(basis["max"]) >= 2000, "label": "Lending capacity", "value": maxf(0, float(basis["max"])), "need": 2000, "gap": maxf(0, 2000 - float(basis["max"])),
		"hint_action": I18n.t("Earn about %s more gross profit through sales in Company OS, or add eligible collateral. Capacity is rounded down to $1,000 and capped at $250,000.") % Fmt.money0(ceilf(maxf(0, 2000 - float(basis["raw"])) / 3)),
		"error": "Your books don't support a loan yet. Show me more gross profit."}]


static func offer() -> Dictionary:
	for requirement in eligibility():
		if not requirement["ok"]:
			return {"ok": false, "error": requirement["error"]}
	var basis := lending_basis()
	var reasons: Array = [basis["parts"][0]]
	for i in range(1, basis["parts"].size()):
		var part: Array = basis["parts"][i]
		if (i < 4 and float(part[1]) > 0) or (i == 4 and float(part[1]) < 0):
			reasons.append(part)
	return {"ok": true, "max": basis["max"], "apr": apr(), "reasons": reasons}


static func at_bank() -> bool:
	var scene := SceneRouter.world_scene()
	return scene != null and scene.kind == "interior" and scene.scene_id == "nexus_bank"


static func marcus_on_duty(at := -1) -> bool:
	var t := Clock.now() if at < 0 else at
	var slot: Dictionary = DataDB.npc("marcus")["schedule"][0]
	return str(slot["days"]).split(",").has(Clock.WEEKDAYS[Clock.weekday(t)].to_lower().substr(0, 3)) and Clock.minute_of_day(t) >= Clock.parse_hm(slot["from"]) and Clock.minute_of_day(t) < Clock.parse_hm(slot["to"])


static func next_appointment() -> int:
	if marcus_on_duty():
		return Clock.now()
	var start := Clock.parse_hm(DataDB.npc("marcus")["schedule"][0]["from"])
	for day in range(8):
		var t := Clock.at_day_time(day, start)
		if t >= Clock.now() and marcus_on_duty(t):
			return t
	return -1


static func appointment_hint() -> String:
	var t := int(B().get("appointment", -1))
	if t < 0:
		return ""
	return I18n.t("Loan appointment: %s. Go to Marcus Reed's manager desk at Nexus Bank, Financial District. If you miss the slot, book again at the lending sign.") % Clock.fmt_datetime(t)


static func book_appointment() -> int:
	var t := next_appointment()
	B()["appointment"] = t
	Sim.cancel("bank.appointment", "id", "lending")
	Sim.schedule(t, "bank.appointment", {"id": "lending"})
	GameState.add_message("marcus", appointment_hint())
	return t


static func take_loan(amount: float, months: int) -> Dictionary:
	var o := offer()
	if not o["ok"]:
		return o
	amount = floorf(amount / 100.0) * 100.0
	if amount < 1000.0 or amount > float(o["max"]) + 0.01:
		return {"ok": false, "error": I18n.t("Between $1,000 and %s.") % Fmt.money0(float(o["max"]))}
	var cid := GameState.company_id()
	var rate := apr()
	var id := "L%d" % int(B()["seq"])
	B()["seq"] = int(B()["seq"]) + 1
	var pmt := monthly_payment(amount, months, rate)
	var l := {"id": id, "entity": cid, "principal": amount, "balance": amount, "apr": rate, "months": months, "payment": pmt,
		"paid_n": 0, "missed": 0, "status": "active", "opened": Clock.now(), "next": Clock.now() + 30 * Clock.DAY}
	B()["loans"][id] = l
	Ledger.post(cid, I18n.t("Nexus Bank loan %s: %s over %d months at %s") % [id, Fmt.money0(amount), months, Fmt.pct(rate, 1)],
		[{"acct": "cash", "dr": amount}, {"acct": "loan_payable", "cr": amount}], {"type": "loan", "id": id})
	Sim.schedule(int(l["next"]), "bank.payment", {"id": id})
	adjust_credit(-10, "new credit")
	GameState.set_flag("loan_taken")
	GameState.inc_stat("loans_taken")
	GameState.timeline(I18n.t("Borrowed %s from Nexus Bank (%d months, %s APR).") % [Fmt.money0(amount), months, Fmt.pct(rate, 1)], "business")
	return {"ok": true, "loan": l}


## Pay down (or pay off) a loan early. No penalty.
static func repay(id: String, amount: float) -> Dictionary:
	var l: Dictionary = B()["loans"].get(id, {})
	if l.is_empty() or not l["status"] in ["active", "late", "called"]:
		return {"ok": false, "error": "No such loan."}
	amount = minf(amount, float(l["balance"]))
	if Ledger.cash(l["entity"]) < amount:
		return {"ok": false, "error": "Not enough cash."}
	Ledger.post(l["entity"], I18n.t("Loan %s — extra repayment") % id, [{"acct": "loan_payable", "dr": amount}, {"acct": "cash", "cr": amount}],
		{"type": "loan_payment", "id": id})
	l["balance"] = snappedf(float(l["balance"]) - amount, 0.01)
	if float(l["balance"]) <= 0.01:
		_close(l)
	return {"ok": true, "balance": l["balance"]}


static func _close(l: Dictionary) -> void:
	l["status"] = "closed"
	l["balance"] = 0.0
	Sim.cancel("bank.payment", "id", l["id"])
	Sim.cancel("bank.called", "id", l["id"])
	adjust_credit(15, "loan repaid")
	GameState.inc_stat("loans_repaid")
	GameState.timeline(I18n.t("Loan %s repaid in full.") % l["id"], "milestone")
	EventBus.notify.emit(I18n.t("Loan %s repaid in full. Your credit score went up.") % l["id"], "good", "bank")


static func _payment(l: Dictionary) -> void:
	if not l["status"] in ["active", "late"]:
		return
	var r := float(l["apr"]) / 12.0
	var interest := snappedf(float(l["balance"]) * r, 0.01)
	var due := minf(float(l["payment"]), float(l["balance"]) + interest)
	var principal := snappedf(due - interest, 0.01)
	var ent: String = l["entity"]
	if Ledger.cash(ent) >= due:
		Ledger.post(ent, I18n.t("Loan %s — monthly payment") % l["id"], [{"acct": "exp:interest", "dr": interest}, {"acct": "loan_payable", "dr": principal},
			{"acct": "cash", "cr": due}], {"type": "loan_payment", "id": l["id"]})
		l["balance"] = snappedf(float(l["balance"]) - principal, 0.01)
		l["paid_n"] = int(l["paid_n"]) + 1
		l["missed"] = 0
		l["status"] = "active"
		adjust_credit(4, "on-time payment")
		if float(l["balance"]) <= 0.01:
			_close(l)
			return
		l["next"] = int(l["next"]) + 30 * Clock.DAY
		Sim.schedule(int(l["next"]), "bank.payment", {"id": l["id"]})
		return
	# missed
	Ledger.expense(ent, "late_fees", LATE_FEE, I18n.t("Late payment fee — loan %s") % l["id"], {"type": "fee"})
	l["missed"] = int(l["missed"]) + 1
	l["status"] = "late"
	adjust_credit(-40, "missed payment")
	GameState.inc_stat("loan_payments_missed")
	if int(l["missed"]) >= maxi(1, ceili(2 * Replay.number("debt_tolerance", 1.0))):
		l["status"] = "called"
		adjust_credit(-60, "loan called")
		l["call_due"] = Clock.now() + 7 * Clock.DAY
		Sim.schedule(int(l["call_due"]), "bank.called", {"id": l["id"]})
		GameState.add_message("marcus", I18n.t("%d missed payments. Loan %s is called: %s is due in full within 7 days.") % [int(l["missed"]), l["id"], Fmt.money(float(l["balance"]))])
		EventBus.notify.emit(I18n.t("Nexus Bank called loan %s. %s due in 7 days.") % [l["id"], Fmt.money(float(l["balance"]))], "bad", "warning")
		return
	GameState.add_message("marcus", I18n.t("Your payment on loan %s bounced. We'll try again in 3 days. It's cheaper to call me before this happens.") % l["id"])
	Sim.schedule(Clock.now() + 3 * Clock.DAY, "bank.payment", {"id": l["id"]})


static func handle(kind: String, p: Dictionary) -> void:
	if kind == "bank.appointment":
		EventBus.notify.emit(appointment_hint(), "info", "bank")
		return
	var l: Dictionary = B()["loans"].get(str(p.get("id", "")), {})
	if l.is_empty():
		return
	match kind:
		"bank.payment":
			_payment(l)
		"bank.called":
			if l["status"] != "called":
				return
			var ent: String = l["entity"]
			if Ledger.cash(ent) >= float(l["balance"]):
				repay(l["id"], float(l["balance"]))
				return
			l["status"] = "defaulted"
			adjust_credit(-150, "default")
			GameState.set_flag("loan_defaulted")
			Insolvency.begin(ent, I18n.t("Nexus Bank called loan %s and it could not be repaid.") % l["id"])
