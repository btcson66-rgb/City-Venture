class_name Insolvency
extends RefCounted
## Bankruptcy is not game over (Handoff §2.7). When the company can't pay what it owes (a called
## loan, or three payrolls missed), the player chooses: put personal money in, restructure with the
## bank, or close the company. Closing liquidates stock at 40% of cost, collects what's owed at a
## discount, ends the office lease, lets staff go, pays creditors in order (wages → bank →
## suppliers) and writes off the rest. The founder survives: credit drops, loans pause for 90 days,
## and a new company can be registered. State: GameState.data["insolvency"].

const LIQUIDATION_RATE := 0.4
const AR_RECOVERY := 0.8
const COOLDOWN_DAYS := 90


static func state() -> Dictionary:
	return GameState.data.get("insolvency", {})


static func active() -> bool:
	return GameState.has_game() and not state().is_empty() and state().get("stage", "") == "open"


static func begin(ent: String, reason: String) -> void:
	if ent == "player" or active():
		return
	GameState.data["insolvency"] = {"entity": ent, "reason": reason, "t": Clock.now(), "stage": "open"}
	GameState.set_flag("insolvency_open")
	GameState.timeline(I18n.t("%s became insolvent: %s") % [GameState.entity_name(ent), reason], "milestone")
	EventBus.notify.emit(I18n.t("%s can't pay its debts. You have to decide what happens next.") % GameState.entity_name(ent), "bad", "warning")


## Everything the company owes right now.
static func liabilities(ent: String) -> float:
	return -(Ledger.balance(ent, "loan_payable") + Ledger.balance(ent, "wages_payable") + Ledger.balance(ent, "accounts_payable"))


static func shortfall(ent: String) -> float:
	return maxf(0.0, liabilities(ent) - Ledger.cash(ent))


## Option 1: the founder puts personal money in to clear the shortfall (and pays the called loan).
static func rescue_with_savings() -> Dictionary:
	var ent := str(state().get("entity", ""))
	var need := shortfall(ent)
	if Ledger.cash("player") < need:
		return {"ok": false, "error": I18n.t("You'd need %s of your own money.") % Fmt.money(need)}
	if need > 0.0:
		Ledger.post("player", I18n.t("Rescue capital into %s") % GameState.entity_name(ent), [{"acct": "investments", "dr": need}, {"acct": "cash", "cr": need}], {"type": "capital"})
		Ledger.post(ent, "Founder rescue capital", [{"acct": "cash", "dr": need}, {"acct": "equity", "cr": need}], {"type": "capital"})
	for l in Bank.loans(ent):
		if l["status"] == "called" or l["status"] == "defaulted":
			l["status"] = "called"
			Bank.repay(l["id"], float(l["balance"]))
	_settle_wages(ent)
	_resolve("rescued")
	return {"ok": true, "amount": need}


## Option 2: restructure with Nexus Bank: the called loan becomes a new 24-month loan plus a fee.
static func restructure() -> Dictionary:
	var ent := str(state().get("entity", ""))
	var called: Array = Bank.B()["loans"].values().filter(func(l): return l["entity"] == ent and l["status"] in ["called", "defaulted"])
	if called.is_empty():
		return {"ok": false, "error": "There's no bank loan to restructure."}
	if Bank.credit() < 350:
		return {"ok": false, "error": "The bank won't restructure with this credit history."}
	for l in called:
		var fee := snappedf(float(l["balance"]) * 0.03, 0.01)
		Ledger.post(ent, I18n.t("Restructuring fee — loan %s") % l["id"], [{"acct": "exp:bank_fees", "dr": fee}, {"acct": "loan_payable", "cr": fee}], {"type": "fee"})
		l["balance"] = snappedf(float(l["balance"]) + fee, 0.01)
		l["months"] = 24
		l["apr"] = minf(0.24, float(l["apr"]) + 0.03)
		l["payment"] = Bank.monthly_payment(float(l["balance"]), 24, float(l["apr"]))
		l["status"] = "active"
		l["missed"] = 0
		l["next"] = Clock.now() + 30 * Clock.DAY
		Sim.cancel("bank.called", "id", l["id"])
		Sim.schedule(int(l["next"]), "bank.payment", {"id": l["id"]})
	Bank.adjust_credit(-60, "restructured")
	_resolve("restructured")
	return {"ok": true}


## Option 3: close the company. Returns the numbers for the closing statement.
static func close_company() -> Dictionary:
	var ent := str(state().get("entity", GameState.company_id()))
	if ent == "" or ent == "player":
		return {"ok": false, "error": "No company to close."}
	var rep := {"stock": 0.0, "receivables": 0.0, "deposit": 0.0, "paid": {}, "written_off": 0.0}
	Contracts.close_for_entity(ent)   # terminal states only; the existing AR sale below is the sole journal entry
	# 1. assets to cash
	Ecommerce.pause_all_ads()
	for l in GameState.data["ecommerce"]["listings"].values():
		l["active"] = false
	rep["stock"] = Ecommerce.liquidate_all(LIQUIDATION_RATE)
	Logistics.on_company_closed(ent)   # the van goes to auction
	Rivals.on_company_closed(ent)
	var ar := maxf(0.0, Ledger.balance(ent, "accounts_receivable")) + maxf(0.0, Ledger.balance(ent, "marketplace_balance"))
	if ar > 0.01:
		var got := snappedf(ar * AR_RECOVERY, 0.01)
		Ledger.post(ent, "Receivables sold to a collector (80%)", [{"acct": "cash", "dr": got}, {"acct": "exp:other", "dr": ar - got},
			{"acct": "accounts_receivable", "cr": maxf(0.0, Ledger.balance(ent, "accounts_receivable"))},
			{"acct": "marketplace_balance", "cr": maxf(0.0, Ledger.balance(ent, "marketplace_balance"))}], {"type": "liquidation"})
		rep["receivables"] = got
	for pid in GameState.data["living"]["leases"].keys():
		var ls: Dictionary = GameState.data["living"]["leases"][pid]
		if ls.get("entity", "") == ent:
			GameState.data["living"]["leases"].erase(pid)
	var dep := Ledger.balance(ent, "deposits")
	if dep > 0.01:
		Ledger.post(ent, "Office deposit returned", [{"acct": "cash", "dr": dep}, {"acct": "deposits", "cr": dep}], {"type": "liquidation"})
		rep["deposit"] = dep
	# 2. staff go (wages owed come first)
	for p in Staff.people():
		Staff.S()["people"].erase(p["id"])
	Staff.S()["applicants"] = []
	Staff.S()["posting"] = {}
	# 3. pay creditors in order, write off the rest
	for acct in ["wages_payable", "loan_payable", "accounts_payable"]:
		var owed := -Ledger.balance(ent, acct)
		if owed <= 0.01:
			continue
		var pay := minf(owed, maxf(0.0, Ledger.cash(ent)))
		if pay > 0.01:
			Ledger.post(ent, I18n.t("Liquidation payment — %s") % acct.replace("_", " "), [{"acct": acct, "dr": pay}, {"acct": "cash", "cr": pay}], {"type": "liquidation"})
		var rest := snappedf(owed - pay, 0.01)
		if rest > 0.01:
			Ledger.post(ent, I18n.t("Debt written off in liquidation — %s") % acct.replace("_", " "), [{"acct": acct, "dr": rest}, {"acct": "other_income", "cr": rest}], {"type": "liquidation"})
			rep["written_off"] = float(rep["written_off"]) + rest
		rep["paid"][acct] = pay
	for l in Bank.B()["loans"].values():
		if l["entity"] == ent and l["status"] != "closed":
			l["status"] = "written_off"
			l["balance"] = 0.0
			Sim.cancel("bank.payment", "id", l["id"])
			Sim.cancel("bank.called", "id", l["id"])
	for po in GameState.data["ecommerce"]["purchase_orders"].values():
		if po.get("entity", "") == ent and po["status"] in ["in_transit", "awaiting_payment"]:
			po["status"] = "cancelled"
	# 4. whatever cash is left goes back to the founder; the founder's investment is written off
	var left := maxf(0.0, Ledger.cash(ent))
	if left > 0.01:
		Ledger.post(ent, "Final distribution to the founder", [{"acct": "equity", "dr": left}, {"acct": "cash", "cr": left}], {"type": "capital"})
	var inv := Ledger.balance("player", "investments")
	var lines: Array = []
	if left > 0.01:
		lines.append({"acct": "cash", "dr": left})
	if inv - left > 0.01:
		lines.append({"acct": "exp:other", "dr": inv - left})
	if inv > 0.01:
		lines.append({"acct": "investments", "cr": inv})
		Ledger.post("player", I18n.t("%s closed: final distribution, rest of the investment written off") % GameState.entity_name(ent), lines, {"type": "liquidation"})
	elif left > 0.01:
		Ledger.post("player", I18n.t("%s closed: final distribution") % GameState.entity_name(ent), [{"acct": "cash", "dr": left}, {"acct": "other_income", "cr": left}], {"type": "liquidation"})
	rep["returned"] = left
	# 5. the founder carries on
	GameState.data["entities"][ent]["closed"] = Clock.now()
	GameState.data["company"] = ""
	for f in ["business_account_opened", "workspace_chosen", "employer_registered", "company_os_opened_as_company"]:
		GameState.set_flag(f, false)
	var prior := int(GameState.stat("companies_closed"))
	Bank.adjust_credit(-200 if state().get("reason", "") != "voluntary" else -40, "company closed")
	Bank.B()["no_loans_until"] = Clock.now() + COOLDOWN_DAYS * Clock.DAY
	GameState.inc_stat("companies_closed")
	GameState.set_flag("founder_restart")
	GameState.add_message("maya", I18n.t("Hey. I heard. Most founders I know closed something before the thing that worked. Dinner's on me."))
	GameState.timeline(I18n.t("Closed %s. Stock sold for %s; %s of debt written off. Starting again.") % [GameState.entity_name(ent), Fmt.money0(float(rep["stock"])), Fmt.money0(float(rep["written_off"]))], "milestone")
	if active():
		_resolve("closed")
	else:
		GameState.data["insolvency"] = {"entity": ent, "reason": "voluntary", "t": Clock.now(), "stage": "closed"}
	EventBus.world_refresh.emit()
	var _u := prior
	return {"ok": true, "report": rep}


static func _settle_wages(ent: String) -> void:
	var owed := -Ledger.balance(ent, "wages_payable")
	if owed > 0.01 and Ledger.cash(ent) >= owed:
		Ledger.post(ent, "Wages owed paid", [{"acct": "wages_payable", "dr": owed}, {"acct": "cash", "cr": owed}], {"type": "payroll"})


static func _resolve(how: String) -> void:
	var s := state()
	s["stage"] = how
	s["resolved"] = Clock.now()
	GameState.set_flag("insolvency_open", false)
	GameState.inc_stat("insolvencies_" + how)


## Called every Friday after payroll: three missed payrolls in a row means the company is insolvent.
static func check_payroll(ent: String) -> void:
	if int(Staff.S().get("missed_run", 0)) >= maxi(1, ceili(3 * Replay.number("debt_tolerance", 1.0))):
		begin(ent, I18n.t("%d consecutive payrolls went unpaid") % int(Staff.S().get("missed_run", 0)))
