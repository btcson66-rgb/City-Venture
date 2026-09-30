class_name MonthClose
extends RefCounted
## Month Close report (kickoff §13): Revenue, COGS, OpEx, Rent, Advertising, Shipping, Refunds, Profit, Cash.
## Profit and cash are computed independently from the ledger, so Profit ≠ Cash shows up on its own.


static func compute(entity: String, t0: int, t1: int) -> Dictionary:
	var mv := Ledger.movements(entity, t0, t1)
	var revenue := -float(mv.get("revenue", 0.0))
	var refunds := float(mv.get("refunds", 0.0))
	var net_rev := revenue - refunds
	var cogs := float(mv.get("cogs", 0.0))
	var opex := {}
	var opex_total := 0.0
	for c in Ledger.OPEX_BUSINESS:
		var v := float(mv.get("exp:" + c, 0.0))
		if absf(v) > 0.001:
			opex[c] = v
			opex_total += v
	var personal := {}
	var personal_total := 0.0
	for c in Ledger.PERSONAL:
		var v2 := float(mv.get("exp:" + c, 0.0))
		if absf(v2) > 0.001:
			personal[c] = v2
			personal_total += v2
	var other_income := -float(mv.get("other_income", 0.0))
	var wages := -float(mv.get("wages", 0.0))   # part-time job pay (personal income, not business profit)
	var business_profit := net_rev - cogs - opex_total + other_income
	var cash_open := Ledger.balance_at(entity, "cash", t0)
	var cash_close := Ledger.balance_at(entity, "cash", t1)
	# owner money in/out during the period (arrival savings, founder capital) - not operating cash
	var owner_moves := 0.0
	for je in Ledger.entries(entity, 100000):
		var tt := int(je["t"])
		if tt >= t0 and tt < t1 and str(je.get("source", {}).get("type", "")) in ["opening", "capital", "transfer"]:
			owner_moves += Ledger.entry_cash(je)
	return {
		"entity": entity, "name": GameState.entity_name(entity) if entity != "player" else "Personal / sole proprietor",
		"revenue": revenue, "refunds": refunds, "net_revenue": net_rev, "cogs": cogs, "gross_profit": net_rev - cogs,
		"opex": opex, "opex_total": opex_total,
		"advertising": float(opex.get("advertising", 0.0)), "shipping": float(opex.get("shipping", 0.0)),
		"rent": _premises(opex) + float(personal.get("rent_home", 0.0)),
		"rent_office": _premises(opex), "rent_home": float(personal.get("rent_home", 0.0)),
		"personal": personal, "personal_total": personal_total, "other_income": other_income,
		"business_profit": business_profit, "profit": business_profit + wages - personal_total, "wages": wages,
		"cash_open": cash_open, "cash_close": cash_close, "cash_change": cash_close - cash_open, "owner_moves": owner_moves,
		"ar": Ledger.balance_at(entity, "marketplace_balance", t1) + Ledger.balance_at(entity, "accounts_receivable", t1),
		"ap": -Ledger.balance_at(entity, "accounts_payable", t1),
		"inventory": Ledger.balance_at(entity, "inventory", t1) + Ledger.balance_at(entity, "inventory_in_transit", t1) + Ledger.balance_at(entity, "goods_out", t1),
	}


static func _premises(opex: Dictionary) -> float:
	var r := 0.0
	for k in Ledger.PREMISES_RENT:
		r += float(opex.get(k, 0.0))
	return r


static func run(year: int, month: int) -> Dictionary:
	var t1 := Clock.now()
	var d := Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_datetime_dict({"year": year, "month": month, "day": 1, "hour": 0, "minute": 0, "second": 0})))
	var t0 := t1 - _days_in_month(year, month) * Clock.DAY
	t0 = maxi(0, t0)
	var ents := ["player"]
	if GameState.company_id() != "":
		ents.append(GameState.company_id())
	var rep := {"period": "%04d-%02d" % [year, month], "label": "%s %d" % [Clock.MONTHS[month - 1], year], "t0": t0, "t1": t1, "entities": {}}
	for e in ents:
		rep["entities"][e] = compute(e, t0, t1)
	GameState.data["reports"]["month_closes"].append(rep)
	var main: Dictionary = rep["entities"][ents[-1]]
	GameState.data["stats"]["best_month_revenue"] = maxf(GameState.stat("best_month_revenue"), float(main["revenue"]))
	if StoryEngine.St().get("chapter", "") == "ch6_cash_is_oxygen":
		if float(main["cash_close"]) >= 0.0:
			GameState.set_flag("ch6_month_in_black")
		else:
			GameState.inc_stat("ch6_cash_loss_months")
			if GameState.stat("ch6_cash_loss_months") >= float(DataDB.economy.get("story_recovery", {}).get("loss_months", 2)):
				GameState.set_flag("ch6_cash_reviewed")
				GameState.add_message("maya", "Two month-ends with negative cash. That isn't a recovery yet, but you've seen the gap. Cut costs or work shifts while you rebuild; the story carries on.")
	if StoryEngine.St().get("chapter", "") == "ch7_supply_shock" and "ch7_close" in StoryEngine.St()["active"]:
		if float(main.get("business_profit", main.get("net_profit", 0.0))) >= 0.0:
			GameState.set_flag("ch7_month_profit")   # made money through the shock
		elif GameState.stat("ch7_loss_months") >= 1.0:
			# a second losing month: the chapter moves on (never a soft-lock), and says honestly what happened
			GameState.set_flag("ch7_month_profit")
			GameState.set_flag("ch7_survived_losses")
			GameState.add_message("maya", "Two months in the red, but you're still open. Plenty of shops aren't. Keep the prices you set and the local supplier; the shock won't last forever.")
		else:
			GameState.inc_stat("ch7_loss_months")
			GameState.add_message("maya", "Rough month. The shock hit everyone. Next month counts too.")
	GameState.timeline(I18n.t("Closed %s: business profit %s, cash %s.") % [label_of(rep), Fmt.money0(main["business_profit"]), Fmt.money0(main["cash_close"])], "milestone")
	GameState.inc_stat("month_closes")
	var _unused := d
	return rep


## Display label for a report ("Jun 2031" / "2031年6月"), rebuilt in the current language.
static func label_of(r: Dictionary) -> String:
	var p := str(r.get("period", ""))
	if p.length() == 7:
		return Clock.fmt_month(int(p.left(4)), int(p.right(2)))
	return str(r.get("label", ""))


static func current(entity: String) -> Dictionary:
	return compute(entity, Clock.month_start(), Clock.now() + 1)


static func _days_in_month(y: int, m: int) -> int:
	if m == 2:
		return 29 if (y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)) else 28
	if m in [4, 6, 9, 11]:
		return 30
	return 31
