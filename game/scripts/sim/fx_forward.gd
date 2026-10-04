class_name FXForward
extends RefCounted
## Cash-settled sale of foreign currency; collateral covers the configured worst quote, not free speculation.


static func cfg() -> Dictionary:
	return DataDB.economy.get("overseas_partners", {}).get("forward", DataDB.economy.get("trade", {}).get("forward", {}))


static func S() -> Dictionary:
	if not GameState.data.has("fx_forwards"):
		GameState.data["fx_forwards"] = {"items": {}, "seq": 1}
	return GameState.data["fx_forwards"]


static func exposure(entity: String, ccy: String, days: int) -> float:
	if not GlobalMarket.live(entity):
		return 0.0
	var c := GlobalMarket.company(entity)
	var b := GlobalMarket.balance(entity, ccy)
	var total := float(b["wallet"]) + float(b["receivable"])
	for region in c["stores"]:
		if GlobalMarket.currency(region) != ccy:
			continue
		for listing in c["stores"][region]["prices"]:
			var l: Dictionary = Ecommerce.E()["listings"].get(listing, {})
			if not l.is_empty():
				total += float(c["stores"][region]["prices"][listing]) * GlobalMarket.demand(region, l) * days
	for deal in GameState.data.get("trade",{}).get("deals",{}).values():
		if deal["entity"]==entity and deal["quote"]["buyer_currency"]==ccy and deal["quote"]["payment"]!="tt_prepaid" and not deal.get("procurement",false) and deal["status"] in ["booked","delayed","customs_hold","in_transit","awaiting_bank","receivable"]:
			total+=float(deal["quote"]["buyer_quote"])
	for f in S()["items"].values():
		if f["entity"] == entity and f["currency"] == ccy and f["status"] == "open":
			total -= float(f["notional"])
	return maxf(0, minf(total, float(cfg().get("maximum_notional", 10000))))


static func quote(ccy: String, notional: float, days: int) -> Dictionary:
	var ent := GameState.company_id()
	if not GlobalMarket.live(ent) or not GlobalMarket.company()["bank"]:
		return {"ok": false, "error": "Open an international company account first."}
	if not FX.cfg().get("currencies", {}).has(ccy) or not days in [30, 60] or not is_finite(notional) or notional < 1:
		return {"ok": false, "error": "Choose a foreign currency, positive notional and a 30- or 60-day maturity."}
	if notional > exposure(ent, ccy, days) + 0.001:
		return {"ok": false, "error": "Notional exceeds receipts and estimated sales available to hedge. Reduce the amount."}
	var rate := FX.rate(ccy)
	var maximum := float(FX.cfg()["currencies"][ccy]["start_rate"]) * float(FX.cfg().get("max_factor", 2))
	var collateral := snappedf(maxf(0, maximum - rate) * notional, 0.01)
	var fee := snappedf(float(cfg().get("fixed_fee", 5)) + notional * rate * float(cfg().get("fee_rates", {}).get(str(days), 0.008)), 0.01)
	if Ledger.cash(ent) < collateral + fee:
		return {"ok": false, "error": "Company cash must cover the fee and refundable hedge collateral. Transfer cash or reduce the amount."}
	return {"ok": true, "entity": ent, "currency": ccy, "notional": snappedf(notional, 0.01), "days": days,
		"rate": rate, "fee": fee, "collateral": collateral}


static func open(ccy: String, notional: float, days: int) -> Dictionary:
	var q := quote(ccy, notional, days)
	if not q["ok"]:
		return q
	var id := "FWD-%04d" % int(S()["seq"])
	S()["seq"] = int(S()["seq"]) + 1
	var f := q.duplicate()
	f.merge({"id": id, "status": "open", "opened": Clock.now(), "due": Clock.now() + days * Clock.DAY})
	S()["items"][id] = f
	Ledger.expense(str(q["entity"]), "bank_fees", float(q["fee"]), I18n.t("Forward %s fee: %s") % [id, Fmt.money(float(q["fee"]))], {"type": "fx_forward_fee", "id": id})
	Ledger.post(str(q["entity"]), I18n.t("Forward %s refundable collateral: %s") % [id, Fmt.money(float(q["collateral"]))],
		[{"acct": "deposits", "dr": q["collateral"]}, {"acct": "cash", "cr": q["collateral"]}], {"type": "fx_forward_collateral", "id": id})
	GameState.set_flag("fx_response_forward")
	StoryEngine.check()
	return {"ok": true, "id": id}


static func settle(id: String, early := false) -> Dictionary:
	var f: Dictionary = S()["items"].get(id, {})
	if f.is_empty() or f["status"] != "open" or (not early and Clock.now() < int(f["due"])):
		return {"ok": false, "error": "This hedge is not due or was already settled."}
	var spot := FX.rate(str(f["currency"]))
	var delta := snappedf(float(f["notional"]) * (float(f["rate"]) - spot), 0.01)
	var collateral := float(f["collateral"])
	var lines := [{"acct": "cash", "dr": collateral + delta}, {"acct": "deposits", "cr": collateral}]
	if delta >= 0:
		lines.append({"acct": "fx_gain_loss", "cr": delta})
	else:
		lines.append({"acct": "fx_gain_loss", "dr": -delta})
	Ledger.post(str(f["entity"]), I18n.t("Forward %s settled at %s: exchange result %s") % [id, Fmt.money(spot), Fmt.money(delta, true)], lines,
		{"type": "fx_forward_settlement", "id": id, "currency": f["currency"], "notional": f["notional"], "rate": spot, "realized": delta})
	f.merge({"status": "settled", "settled": Clock.now(), "spot": spot, "gain_loss": delta, "early": early}, true)
	StoryEngine.check()
	return {"ok": true, "gain_loss": delta}


static func on_hour() -> void:
	for f in S()["items"].values():
		if f["status"] == "open" and Clock.now() >= int(f["due"]):
			settle(str(f["id"]))


static func close_for_entity(entity: String) -> void:
	for f in S()["items"].values():
		if f["entity"] == entity and f["status"] == "open":
			settle(str(f["id"]), true)
