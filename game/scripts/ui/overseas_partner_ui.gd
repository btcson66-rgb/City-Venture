class_name OverseasPartnerUI
extends RefCounted
## Links stay secondary beside existing sales/finance primary actions.


static func sales(box: VBoxContainer) -> void:
	var risk := UIK.button("Manage exchange risk", func(): UIRoot.open_modal(FXRiskModal.new()))
	risk.name = "ManageFXRisk"
	box.add_child(risk)
	var partner := UIK.button("Compare Lumina partners", func(): UIRoot.open_modal(OverseasPartnerModal.new()))
	partner.name = "CompareLuminaPartners"
	box.add_child(partner)


static func finance(box: VBoxContainer) -> void:
	box.add_child(UIK.label_tip("Forward contract", "forward_contract"))
	for f in FXForward.S()["items"].values():
		if f["entity"] != GameState.company_id():
			continue
		box.add_child(UIK.kv(str(f["id"]), Fmt.money(float(f["notional"])) + " " + str(f["currency"]) + " · " + Clock.fmt_short(int(f["due"]))))
		box.add_child(UIK.kv("Fee / collateral (home dollars)", Fmt.money(float(f["fee"])) + " / " + Fmt.money(float(f["collateral"]))))
		if f["status"] == "settled":
			box.add_child(UIK.kv("Actual hedge gain / loss (home dollars)", Fmt.money(float(f["gain_loss"]), true)))
		else:
			box.add_child(UIK.wrap("✓ Hedge open. Wait for maturity; both gains and losses settle automatically.", 7, Art.C_SKY, 460))
	var go := UIK.button("Manage exchange risk", func(): UIRoot.open_modal(FXRiskModal.new()))
	go.name = "FinanceFXRisk"
	box.add_child(go)


static func price(box: VBoxContainer, region: String, price: float) -> void:
	var shock: Dictionary = OverseasPartners.S()["shock"]
	var currency := GlobalMarket.currency(region)
	if shock.is_empty() or shock["currency"] != currency:
		return
	box.add_child(UIK.label_tip("Exchange risk", "fx_risk"))
	box.add_child(UIK.wrap(I18n.t("Net per unit now: %s; before the currency fall: %s (home dollars, platform fee and bank spread included; stock, freight and duty excluded).") % [Fmt.money(OverseasPartners.net_unit(region, price, FX.rate(currency))), Fmt.money(OverseasPartners.net_unit(region, price, float(shock["before"])))], 7, Art.C_SKY, 460))


static func fx_card() -> void:
	var m := InfoModal.new()
	m.title_text = "Exchange response — compare the assumptions"
	m.icon_name = "finance"
	m.help_key = "fx_risk"
	m.lines = ["The unhedged comparison values the starting estimated foreign receipts at today's quote versus the quote before the shock. It is not a second simulated business or guaranteed profit."]
	var shock: Dictionary = OverseasPartners.S()["shock"]
	if not shock.is_empty():
		var quantity := float(shock.get("exposure_estimate", 0))
		m.lines.append(["Starting receipt estimate (foreign units)", Fmt.money(quantity) + " " + str(shock["currency"])])
		m.lines.append(["Unhedged quote change (home dollars)", Fmt.money(quantity * (FX.rate(str(shock["currency"])) - float(shock["before"])), true)])
	var total := 0.0
	var fees := 0.0
	for f in FXForward.S()["items"].values():
		if f["entity"] == GameState.company_id():
			fees += float(f["fee"])
			if f["status"] == "settled":
				total += float(f["gain_loss"])
	m.lines.append(["Actual settled hedge / fees (home dollars)", Fmt.money(total, true) + " / " + Fmt.money(fees)])
	m.lines.append("Open hedges are not counted as settled income. Repricing affects demand; home-currency invoices lower buyer acceptance and price. Check the actual month-close exchange line.")
	UIRoot.open_modal(m)


static func partner_card() -> void:
	var m := InfoModal.new()
	m.title_text = "Customer ownership — 90-day estimate"
	m.icon_name = "finance"
	m.help_key = "overseas_partner"
	var l := OverseasPartners.listing()
	if l.is_empty():
		m.lines = ["No active product price is available. The expansion ended through the review or company-closure alternative, without invented sales."]
	else:
		var units := int(OverseasPartners.cfg()["comparison_units_90"])
		var price := float(l["price"])
		var cost := Ecommerce.avg_cost(Ecommerce.default_stock_location(), str(l["product"]))
		var distributor := units * (price * float(OverseasPartners.cfg()["wholesale_factor"]) - cost) - float(OverseasPartners.cfg()["transfer_freight_base"]) - units * float(OverseasPartners.cfg()["transfer_freight_unit"])
		var warehouse := units * (price * (1 - float(Ecommerce.mk().get("fee_rate", 0.1))) * (1 - float(FX.cfg().get("bank_spread", 0.015))) - cost - float(OverseasPartners.cfg()["warehouse_shipping_unit"])) - float(OverseasPartners.cfg()["warehouse_open_fee"]) - float(OverseasPartners.cfg()["transfer_freight_base"]) - units * float(OverseasPartners.cfg()["transfer_freight_unit"])
		var slow := warehouse - units * float(OverseasPartners.cfg()["warehouse_rent_unit_month"]) * 3
		m.lines = [["Assumed sales over 90 days (units)", str(units)], ["Distributor margin estimate (home dollars)", Fmt.money(distributor)], ["Warehouse margin estimate (home dollars)", Fmt.money(warehouse)], ["Warehouse with three months' slow-stock rent (home dollars)", Fmt.money(slow)],
			"These use the current product price and domestic stock cost, assume all units sell, and exclude duties, refunds, packing, FX movement and other overhead. They are comparisons, not guaranteed profit. No second business was run.",
			"The distributor owns the customers and pays wholesale. With your warehouse, you own the customers and also fund stock, rent and unsold risk."]
	UIRoot.open_modal(m)
