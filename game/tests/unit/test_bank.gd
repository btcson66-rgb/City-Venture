extends RefCounted
## Nexus Bank lending, credit score, missed payments, called loans, insolvency and restart.

var runner


func _company(cash := 20000.0) -> String:
	Company.register("Loan Test Co", "ecommerce", "22 Founders Lane")
	Company.open_business_account(cash)
	return GameState.company_id()


func _with_history(cid: String, gp := 6000.0) -> void:
	# a month of trading: revenue with a cost of goods, as the ecommerce module would post it
	Ledger.post(cid, "test sales", [{"acct": "cash", "dr": gp * 2.0}, {"acct": "revenue", "cr": gp * 2.0}], {"type": "order"})
	Ledger.post(cid, "test cogs", [{"acct": "cogs", "dr": gp}, {"acct": "cash", "cr": gp}], {"type": "order"})
	Clock.advance(15 * Clock.DAY)


func test_no_loan_without_company_or_history() -> void:
	runner.check(not Bank.offer()["ok"], "no company, no loan")
	_company()
	var o := Bank.offer()
	runner.check(not o["ok"], "a brand-new company has no statements yet")


func test_offer_comes_from_the_books() -> void:
	var cid := _company()
	_with_history(cid, 6000.0)
	var o := Bank.offer()
	runner.check(o["ok"], "offer after two weeks of trading: %s" % str(o))
	runner.check(float(o["max"]) >= 18000.0 - 0.01, "3 × gross profit supports at least $18k (got %s)" % str(o.get("max")))
	runner.check(float(o["apr"]) >= 0.06 and float(o["apr"]) <= 0.24, "APR in range")


func test_loan_disburses_and_amortises() -> void:
	var cid := _company()
	_with_history(cid)
	var cash0 := Ledger.cash(cid)
	var r := Bank.take_loan(12000.0, 12)
	runner.check(r["ok"], "loan taken")
	runner.eq(Ledger.cash(cid) - cash0, 12000.0, "cash in")
	runner.eq(Bank.debt(cid), 12000.0, "loan payable recorded")
	var l: Dictionary = r["loan"]
	Clock.advance(31 * Clock.DAY)
	runner.eq(int(l["paid_n"]), 1, "first monthly payment made")
	runner.check(Bank.debt(cid) < 12000.0, "principal went down")
	runner.check(Ledger.balance(cid, "exp:interest") > 0.0, "interest booked as an expense")
	runner.check(Ledger.check_balanced(), "ledger balanced")
	var rp := Bank.repay(l["id"], Bank.debt(cid))
	runner.check(rp["ok"], "paid off early")
	runner.eq(str(l["status"]), "closed", "loan closed")
	runner.eq(Bank.debt(cid), 0.0, "no debt left")


func test_missed_payments_call_the_loan_and_insolvency_follows() -> void:
	var cid := _company(5000.0)
	_with_history(cid, 4000.0)
	var c0 := Bank.credit()
	var r := Bank.take_loan(10000.0, 12)
	runner.check(r["ok"], "loan taken")
	# the cash goes out the door
	Ledger.expense(cid, "other", Ledger.cash(cid) - 5.0, "test drain")
	Clock.advance(31 * Clock.DAY)
	var l: Dictionary = r["loan"]
	runner.eq(str(l["status"]), "late", "first payment missed")
	runner.check(Bank.credit() < c0, "credit score dropped")
	Clock.advance(4 * Clock.DAY)
	runner.eq(str(l["status"]), "called", "second miss: loan called")
	Clock.advance(8 * Clock.DAY)
	runner.check(Insolvency.active(), "unpaid call → insolvency")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_restructure_keeps_the_company_alive() -> void:
	var cid := _company(5000.0)
	_with_history(cid, 4000.0)
	var l: Dictionary = Bank.take_loan(10000.0, 12)["loan"]
	Ledger.expense(cid, "other", Ledger.cash(cid) - 5.0, "test drain")
	Clock.advance(44 * Clock.DAY)
	runner.check(Insolvency.active(), "insolvent")
	var r := Insolvency.restructure()
	runner.check(r["ok"], "restructured: %s" % str(r))
	runner.check(not Insolvency.active(), "no longer insolvent")
	runner.eq(str(l["status"]), "active", "loan active again")
	runner.eq(int(l["months"]), 24, "longer term")


func test_close_company_and_start_again() -> void:
	var cid := _company(8000.0)
	_with_history(cid, 4000.0)
	Bank.take_loan(10000.0, 12)
	Ecommerce.buy("tradelink_wholesale", "water_bottle", 60)
	Clock.advance(6 * Clock.DAY)
	Ledger.expense(cid, "other", Ledger.cash(cid) - 5.0, "test drain")
	Clock.advance(38 * Clock.DAY)
	runner.check(Insolvency.active(), "insolvent")
	var c0 := Bank.credit()
	var r := Insolvency.close_company()
	runner.check(r["ok"], "company closed")
	runner.check(float(r["report"]["stock"]) > 0.0, "stock sold to a liquidator")
	runner.eq(GameState.company_id(), "", "no company any more")
	runner.eq(GameState.business_entity(), "player", "the founder trades personally again")
	runner.check(Bank.credit() < c0, "credit hit")
	runner.eq(Bank.debt(cid), 0.0, "company debt settled or written off")
	runner.check(not Bank.offer()["ok"], "no loans for a while")
	runner.check(Ledger.check_balanced(), "ledger balanced")
	var again := Company.register("Loan Test Co", "ecommerce", "22 Founders Lane")
	runner.check(again["ok"], "a new company can be registered, even with the same name")
	runner.check(GameState.company_id() != cid, "new books, new id")


func test_investor_buys_a_stake() -> void:
	var cid := _company()
	var cash0 := Ledger.cash(cid)
	var r := Effects.apply({"op": "equity_investment", "amount": 50000, "stake": 0.2, "investor": "elena", "memo": "Northlight Capital — seed"}, {})
	runner.check(r["ok"], "investment applied")
	runner.eq(Ledger.cash(cid) - cash0, 50000.0, "cash in")
	runner.eq(float(GameState.data["cap_table"]["founder"]), 0.8, "founder diluted to 80%")
	runner.check(GameState.flag("investor_elena"), "flag set")
