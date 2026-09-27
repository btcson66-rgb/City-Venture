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
	return float(DataDB.year_def(int(GameState.data["world"]["year"])).get("interest_rate", 0.025))


static func apr() -> float:
	return clampf(base_rate() + 0.06 + (720 - credit()) * 0.0004, 0.06, 0.24)


static func monthly_payment(principal: float, months: int, rate := -1.0) -> float:
	var r := (apr() if rate < 0 else rate) / 12.0
	if r <= 0.0:
		return principal / months
	return snappedf(principal * r / (1.0 - pow(1.0 + r, -months)), 0.01)


## What Marcus would lend today, and why. {ok, max, apr, reasons[], parts{}}
static func offer() -> Dictionary:
	var cid := GameState.company_id()
	if cid == "":
		return {"ok": false, "error": "We lend to registered companies."}
	if not GameState.flag("business_account_opened"):
		return {"ok": false, "error": "Open a business account with us first."}
	if credit() < 560 or Clock.now() < int(B().get("no_loans_until", 0)):
		return {"ok": false, "error": "Your credit history needs time to recover."}
	for l in loans(cid):
		if l["status"] != "active":
			return {"ok": false, "error": "Not while a loan is in arrears."}
	var age_days := int((Clock.now() - int(GameState.data["entities"][cid].get("founded", 0))) / Clock.DAY)
	var t0 := Clock.now() - 30 * Clock.DAY
	var m := MonthClose.compute(cid, t0, Clock.now())
	var gp := maxf(0.0, float(m["gross_profit"]))
	var cash_flow := maxf(0.0, gp * 3.0)
	var ar := maxf(0.0, Ledger.balance(cid, "accounts_receivable") + Ledger.balance(cid, "marketplace_balance"))
	var contracts := 0.0
	for c in GameState.data["contracts"].values():
		if c["status"] == "active" and c.get("seller", "") == cid:
			contracts += float(c["total"]) - float(c.get("upfront_paid", 0.0))
	var stock := maxf(0.0, Ledger.balance(cid, "inventory") + Ledger.balance(cid, "inventory_in_transit"))
	var collateral := ar * 0.7 + contracts * 0.6 + stock * 0.5
	var reasons: Array = []
	if age_days < MIN_AGE_DAYS and contracts <= 0.0:
		return {"ok": false, "error": I18n.t("Come back when %s has %d days of statements, or a signed contract.") % [GameState.business_display_name(), MIN_AGE_DAYS]}
	var mx := floorf(minf(MAX_LOAN, cash_flow + collateral - debt(cid)) / 1000.0) * 1000.0
	if mx < 2000.0:
		return {"ok": false, "error": "Your books don't support a loan yet. Show me more gross profit."}
	reasons.append([I18n.t("3 × last 30 days' gross profit"), cash_flow])
	if ar > 0.0:
		reasons.append([I18n.t("70% of money owed to you"), ar * 0.7])
	if contracts > 0.0:
		reasons.append([I18n.t("60% of signed contracts"), contracts * 0.6])
	if stock > 0.0:
		reasons.append([I18n.t("50% of stock at cost"), stock * 0.5])
	if debt(cid) > 0.0:
		reasons.append([I18n.t("minus existing debt"), -debt(cid)])
	return {"ok": true, "max": mx, "apr": apr(), "reasons": reasons}


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
	if int(l["missed"]) >= 2:
		l["status"] = "called"
		adjust_credit(-60, "loan called")
		l["call_due"] = Clock.now() + 7 * Clock.DAY
		Sim.schedule(int(l["call_due"]), "bank.called", {"id": l["id"]})
		GameState.add_message("marcus", I18n.t("Two missed payments. The bank has called loan %s: %s is due in full within 7 days.") % [l["id"], Fmt.money(float(l["balance"]))])
		EventBus.notify.emit(I18n.t("Nexus Bank called loan %s. %s due in 7 days.") % [l["id"], Fmt.money(float(l["balance"]))], "bad", "warning")
		return
	GameState.add_message("marcus", I18n.t("Your payment on loan %s bounced. We'll try again in 3 days. It's cheaper to call me before this happens.") % l["id"])
	Sim.schedule(Clock.now() + 3 * Clock.DAY, "bank.payment", {"id": l["id"]})


static func handle(kind: String, p: Dictionary) -> void:
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
