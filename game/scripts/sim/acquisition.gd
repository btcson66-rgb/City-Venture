class_name Acquisition
extends RefCounted
## The first acquisition offer (Chapter 12): Victor Hale's Hale Group offers to buy the company. The price comes from
## the company's own books: a multiple of the last year's operating profit (or of revenue when profit is thin), plus
## cash, stock and money owed to you, minus what you owe. Numbers: data/economy/acquisition.json.
##  · accept   the founder's share is paid now; the company carries on under Hale Group (no owner withdrawals any more)
##  · counter  a higher price, but part of it is an earn-out: paid a year later only if revenue holds
##  · decline  nothing changes
## Whichever is chosen, `offer_decided` ends the main story (Chapter 12's ending card), then free play.


static func cfg() -> Dictionary:
	return DataDB.economy.get("acquisition", {})


static func sold() -> bool:
	return GameState.has_game() and GameState.flag("company_sold")


## What Hale Group would pay today, and how: {price, basis, profit_year, revenue_year, enterprise, cash, stock, owed,
## debts, founder_share, take}.
static func quote() -> Dictionary:
	var c := cfg()
	var ent := GameState.company_id()
	if ent == "" or not GameState.data["entities"].get(ent, {}).get("bank_account", false):
		return {"price": 0.0, "basis": "assets", "profit_year": 0.0, "revenue_year": 0.0, "enterprise": 0.0,
			"cash": 0.0, "stock": 0.0, "owed": 0.0, "debts": 0.0, "founder_share": 0.0, "take": 0.0}
	var days := int(c.get("window_days", 90))
	var year_factor := 365.0 / float(days)
	var m := MonthClose.compute(ent, Clock.now() - days * Clock.DAY, Clock.now() + 1)
	var profit_year := (float(m["gross_profit"]) - float(m["opex_total"])) * year_factor   # what the business earns, not one-off grants
	var revenue_year := float(m["net_revenue"]) * year_factor
	var by_profit := maxf(0.0, profit_year) * float(c.get("profit_multiple", 3.5))
	var by_revenue := maxf(0.0, revenue_year) * float(c.get("revenue_multiple", 0.35))
	var cash := maxf(0.0, Ledger.cash(ent))
	var stock := maxf(0.0, Ledger.balance(ent, "inventory") + Ledger.balance(ent, "inventory_in_transit") + Ledger.balance(ent, "goods_out")) * float(c.get("stock_haircut", 0.8))
	var owed := maxf(0.0, Ledger.balance(ent, "marketplace_balance") + Ledger.balance(ent, "accounts_receivable") + Ledger.balance(ent, "escrow_held") + Ledger.balance(ent, "frozen_funds"))
	for account in GameState.data["ledger"]["balances"].get(ent, {}):
		if str(account).begins_with("fx_wallet:") or str(account).begins_with("fx_receivable:"):
			owed += maxf(0, Ledger.balance(ent, str(account)))
	var debts := Insolvency.liabilities(ent)
	var raw := snappedf(maxf(by_profit, by_revenue) + cash + stock + owed - debts, 1.0)
	var price := maxf(float(c.get("min_price", 5000.0)), raw)
	var founder := float(GameState.data.get("cap_table", {"founder": 1.0}).get("founder", 0.0))
	var basis := "assets"   # no earnings to price: the company lost money and has no revenue worth a multiple
	if by_profit > 0.0 and by_profit >= by_revenue:
		basis = "profit"
	elif by_revenue > 0.0:
		basis = "revenue"
	return {"price": price, "basis": basis, "profit_year": profit_year, "revenue_year": revenue_year,
		"enterprise": maxf(by_profit, by_revenue), "cash": cash, "stock": stock, "owed": owed, "debts": debts,
		"founder_share": founder, "take": Fundraising.founder_proceeds(price)}


## The numbers behind the `acquisition_offer` decision (placeholders in data/events/acquisition_offer.json).
static func context() -> Dictionary:
	var c := cfg()
	var q := quote()
	var price := float(q["price"])
	var founder := float(q["founder_share"])
	var cprice := snappedf(price * (1.0 + float(c.get("counter_uplift", 0.2))), 1.0)
	var now_part := snappedf(cprice * float(c.get("counter_upfront", 0.6)), 1.0)
	var later_part := cprice - now_part
	var basis := ""
	if str(q["basis"]) == "profit":
		basis = I18n.t("%s × last year's profit of %s") % ["%.1f" % float(c.get("profit_multiple", 3.5)), Fmt.money0(float(q["profit_year"]))]
	elif str(q["basis"]) == "revenue":
		basis = I18n.t("%s × last year's revenue of %s") % ["%.2f" % float(c.get("revenue_multiple", 0.35)), Fmt.money0(float(q["revenue_year"]))]
	else:
		basis = I18n.t("nothing for earnings (last year's profit: %s)") % Fmt.money0(float(q["profit_year"]))
	var share := ""
	if founder >= 0.999:
		share = I18n.t("You own all of it, so the whole amount is yours: %s.") % Fmt.money0(float(q["take"]))
	else:
		share = I18n.t("Investors own %s of it, so your share is %s.") % [Fmt.pct(1.0 - founder), Fmt.money0(float(q["take"]))]
	return {
		"entity": GameState.company_id(),
		"price": Fmt.money0(price), "price_v": price, "basis": basis, "share_line": share,
		"assets": Fmt.money0(float(q["cash"]) + float(q["stock"]) + float(q["owed"])), "debts": Fmt.money0(float(q["debts"])),
		"take": Fmt.money0(float(q["take"])), "take_v": float(q["take"]), "founder_share": founder,
		"counter_price": Fmt.money0(cprice), "counter_price_v": cprice,
		"counter_now": Fmt.money0(now_part * founder), "counter_now_v": now_part, "counter_later": Fmt.money0(later_part * founder), "counter_later_v": later_part,
		"uplift": Fmt.pct(float(c.get("counter_uplift", 0.2))), "floor": Fmt.pct(float(c.get("earnout_floor", 0.9))),
		"revenue_year_v": float(q["revenue_year"]),
	}


## The player's answer to the offer. `ctx` is the decision's context, so the price is the one that was shown.
static func decide(choice: String, ctx: Dictionary) -> Dictionary:
	if GameState.company_id() == "" or str(ctx.get("entity", GameState.company_id())) != GameState.company_id():
		return {"ok": false, "error": "There is no offer on the table."}
	if choice in ["accept", "counter"] and float(quote()["founder_share"]) <= 0:
		return {"ok": false, "error": "The existing owner holds these shares. No second founder sale can be paid."}
	var price := float(ctx.get("price_v", 0.0))
	if price <= 0.0:
		return {"ok": false, "error": "There is no offer on the table."}
	GameState.data["acquisition_receipt"] = {"entity": GameState.company_id(), "price": price, "choice": choice, "t": Clock.now()}
	match choice:
		"accept":
			_sell(price, 0.0, ctx)
			GameState.set_flag("offer_accepted")
			GameState.add_message("victor", I18n.t("Victor Hale. Papers signed. %s is in your account. You stay on as managing director: you know where the levers are.") % str(ctx.get("take", "")))
		"counter":
			var cprice := float(ctx.get("counter_price_v", price))
			var now_part := float(ctx.get("counter_now_v", cprice))
			_sell(now_part, cprice - now_part, ctx)
			GameState.set_flag("offer_countered")
			GameState.add_message("victor", I18n.t("Victor Hale. Fine. %s more, part of it now and the rest if revenue holds for a year. %s is in your account. Don't make me regret it.") % [str(ctx.get("uplift", "")), str(ctx.get("counter_now", ""))])
		"decline":
			GameState.set_flag("offer_declined")
			GameState.timeline(I18n.t("Turned down Hale Group's offer for %s.") % GameState.business_display_name(), "milestone")
			GameState.add_message("victor", "Victor Hale. Understood. Independent suits you. If the number changes, so will the conversation.")
		_:
			return {"ok": false, "error": "No such choice."}
	GameState.set_flag("offer_decided")
	return {"ok": true}


## The founder sells: `now_total` is paid to all shareholders now (the founder's part reaches personal cash) and
## `later_total` is the earn-out, paid a year later if revenue holds.
static func _sell(now_total: float, later_total: float, ctx: Dictionary) -> void:
	var founder := float(ctx.get("founder_share", 1.0))
	var take := Fundraising.founder_proceeds(now_total)
	var carrying := HoldingGroups.basis(GameState.company_id())   # what the founder has put into the company
	var gain := take - carrying
	var lines: Array = [{"acct": "cash", "dr": take}, {"acct": "investments", "cr": carrying}]
	lines.append({"acct": "other_income", "cr": gain} if gain >= 0.0 else {"acct": "exp:other", "dr": -gain})
	Ledger.post("player", I18n.t("Sold %s to Hale Group") % GameState.business_display_name(), lines, {"type": "sale"})
	GameState.data["cap_table"] = {"hale_group": 1.0}
	GameState.set_flag("company_sold")
	GameState.timeline(I18n.t("Sold %s to Hale Group: %s paid to you.") % [GameState.business_display_name(), Fmt.money0(take)], "milestone")
	if later_total > 0.01:
		var c := cfg()
		Sim.schedule(Clock.now() + int(c.get("earnout_days", 365)) * Clock.DAY, "acq.earnout",
			{"entity": GameState.company_id(), "amount": snappedf(later_total * founder, 0.01), "base": float(ctx.get("revenue_year_v", 0.0))})


static func _revenue_year(ent := "") -> float:
	var days := int(cfg().get("window_days", 90))
	var m := MonthClose.compute(ent if ent != "" else GameState.business_entity(), Clock.now() - days * Clock.DAY, Clock.now() + 1)
	return float(m["net_revenue"]) * 365.0 / float(days)


static func handle(kind: String, p: Dictionary) -> void:
	if kind != "acq.earnout":
		push_warning("Acquisition: unknown " + kind)
		return
	var amount := float(p.get("amount", 0.0))
	var base := float(p.get("base", 0.0))
	var floor_r := float(cfg().get("earnout_floor", 0.9))
	var ent := str(p.get("entity", GameState.company_id()))
	var now_rev := _revenue_year(ent)
	var closed: bool = ent == "" or GameState.data["entities"].get(ent, {}).has("closed")
	if not closed and now_rev >= base * floor_r:
		Ledger.post("player", "Hale Group earn-out", [{"acct": "cash", "dr": amount}, {"acct": "other_income", "cr": amount}], {"type": "sale"})
		GameState.add_message("victor", I18n.t("Victor Hale. Twelve months, targets met. The second payment is in your account: %s.") % Fmt.money0(amount))
		GameState.timeline(I18n.t("Hale Group paid the earn-out: %s.") % Fmt.money0(amount), "milestone")
		GameState.set_flag("earnout_paid")
	else:
		GameState.add_message("victor", I18n.t("Victor Hale. Revenue is at %s of the number we signed on. Under our agreement the earn-out doesn't pay. I would rather have paid it.") % Fmt.pct(now_rev / maxf(1.0, base)))
		GameState.timeline(I18n.t("The earn-out did not pay: revenue fell short of the agreed floor."), "milestone")
		GameState.set_flag("earnout_missed")


## Independent late-game purchase; separate from the story offer to sell your own company.
static func buy_rival(id: String) -> Dictionary:
	return Rivals.acquire(id)
