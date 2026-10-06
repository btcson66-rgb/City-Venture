class_name TradeQuote
extends RefCounted
## Read-only RFQ estimates. Execution will use the shared industry Jobs service, not a second job ledger.


static func cfg() -> Dictionary:
	return DataDB.economy.get("trade", {})


static func currency(region: String) -> String:
	return str(FX.cfg().get("home_currency", "AUD")) if region == "aurelia" else GlobalMarket.currency(region)


static func sheet(origin: String, destination: String, product: String, quantity: int, term: String, mode: String, payment: String, insured: bool, markup: float = 0.3) -> Dictionary:
	var c := cfg()
	if origin == destination or not DataDB.regions.has(origin) or not DataDB.regions.has(destination):
		return {"ok": false, "error": "Choose two different trading regions."}
	if not c.get("goods", {}).has(product) or not c.get("terms", {}).has(term) or not c.get("transport", {}).has(mode) or not c.get("payments", {}).has(payment):
		return {"ok": false, "error": "Choose a supported product, term, transport and payment method."}
	if mode == "air" and term in ["FOB", "CIF"]:
		return {"ok": false, "error": "FOB and CIF require sea transport. For air, choose EXW or DDP."}
	var goods: Dictionary = c["goods"][product]
	var supply: Dictionary = goods.get("regions", {}).get(origin, {})
	var demand: Dictionary = goods.get("regions", {}).get(destination, {}).duplicate(true)
	demand["demand"] = ceili(float(demand.get("demand",0))*CityFuture.demand_factor("international_trade"))
	if quantity < 1 or quantity > int(supply.get("capacity", 0)) or quantity > int(demand.get("demand", 0)) or not is_finite(markup) or markup < 0 or markup > 1:
		return {"ok": false, "error": "Quantity exceeds regional capacity or demand, or markup is outside 0–100%."}
	var source_rate := FX.rate(currency(origin))
	var buyer_rate := FX.rate(currency(destination))
	if source_rate <= 0 or buyer_rate <= 0:
		return {"ok": false, "error": "No valid exchange quote is available."}
	var terms: Dictionary = c["terms"][term]
	var transport: Dictionary = c["transport"][mode]
	var pay: Dictionary = c["payments"][payment]
	var purchase := snappedf(float(supply["price"]) * source_rate * quantity, 0.01)
	var trade_state: Dictionary=GameState.data.get("trade",{})
	var freight_factor: float=float(trade_state.get("freight_mult",1.0)) if Clock.now()<int(trade_state.get("freight_until",0)) else 1.0
	var freight := snappedf((float(transport["base_fee"]) + float(transport["unit_fee"]) * quantity) * float(c["routes"][destination]["freight_factor"])*freight_factor, 0.01)
	var origin_cost := snappedf(float(c["origin_handling_per_unit"]) * quantity, 0.01)
	var insured_now: bool = insured or bool(terms["insurance_required"])
	var insurance := snappedf(purchase * float(c["insurance_rate"]), 0.01) if insured_now else 0.0
	var sales := snappedf(purchase * (1 + markup), 0.01)
	var duty_rate := float(Customs.cfg().get("regions", {}).get(destination, {}).get(goods["tariff_code"], 0))
	if destination == "aurelia":
		duty_rate = float(c.get("home_import_rates", {}).get(goods["tariff_code"], 0))
	var duty := snappedf(sales * duty_rate, 0.01)
	var segments := [
		{"kind": "Origin handling", "cost": origin_cost, "payer": terms["origin_payer"]},
		{"kind": "Main freight", "cost": freight, "payer": terms["freight_payer"]},
		{"kind": "Cargo insurance", "cost": insurance, "payer": terms["insurance_payer"]},
		{"kind": "Import duty", "cost": duty, "payer": terms["duty_payer"]}]
	var costs := purchase
	var buyer_cost := sales
	for segment in segments:
		if segment["payer"] == "seller":
			costs += float(segment["cost"])
		else:
			buyer_cost += float(segment["cost"])
	var fee := snappedf(sales * float(pay["fee_rate"]) + float(pay["fixed_fee"]), 0.01)
	var spread := snappedf(sales * float(FX.cfg().get("bank_spread", 0.015)), 0.01) if currency(destination) != currency("aurelia") else 0.0
	costs += fee + spread
	var wait_days := (int(transport["departure_weekday"]) - Clock.weekday() + 7) % 7 if mode == "sea" else 0
	var maximum_sale := snappedf(float(demand["price"]) * buyer_rate * quantity, 0.01)
	var default_risk := float(pay["default_multiplier"]) * float(c["routes"][destination]["default_risk"])
	var cargo_risk := float(transport["loss_risk"])
	var exposed := purchase * (1 - float(c["insurance_coverage"])) if insured_now else purchase
	# CIF pays freight/insurance but passes cargo risk at loading; DDP retains it until delivery.
	var seller_loss := exposed if terms["risk_transfer"] == "Buyer delivery" else float(c["origin_loss_exposure"]) * purchase
	var stress_factor := 1.0 if currency(destination) == currency("aurelia") else float(c["stress_fx_factor"])
	var stress_margin := sales * stress_factor - costs - seller_loss
	return {"ok": true, "origin": origin, "destination": destination, "product": product, "quantity": quantity,
		"term": term, "mode": mode, "payment": payment, "insured": insured_now, "segments": segments,
		"purchase": purchase, "sales": sales, "costs": snappedf(costs, 0.01), "fee": fee, "spread": spread,
		"margin": snappedf(sales - costs, 0.01), "stress_margin": snappedf(stress_margin, 0.01),
		"buyer_landed": snappedf(buyer_cost, 0.01), "buyer_ceiling": maximum_sale, "competitive": buyer_cost <= maximum_sale,
		"source_currency": currency(origin), "source_rate": source_rate, "buyer_currency": currency(destination),
		"buyer_rate": buyer_rate, "buyer_quote": snappedf(sales / buyer_rate, 0.01),
		"wait_days": wait_days, "transit_days": int(transport["days"]), "payment_days": int(pay["days"]),
		"risk_transfer": terms["risk_transfer"], "default_risk": default_risk, "cargo_risk": cargo_risk,
		"quoted_at": Clock.now(), "valid_until": Clock.now() + int(c["quote_valid_days"]) * Clock.DAY,
		"warehouse_rent_day": snappedf(quantity * float(c["warehouse_rent_per_unit_day"]), 0.01)}


static func valid(quote: Dictionary) -> bool:
	return bool(quote.get("ok", false)) and Clock.now() < int(quote.get("valid_until", 0))
