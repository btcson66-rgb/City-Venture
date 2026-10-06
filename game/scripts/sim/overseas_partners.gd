class_name OverseasPartners
extends RefCounted
## Lumina distributor contracts and a separate overseas stock point using the existing ecommerce inventory books.


static func cfg() -> Dictionary:
	return DataDB.economy.get("overseas_partners", {})


static func S() -> Dictionary:
	if not GameState.data.has("overseas_partners"):
		GameState.data["overseas_partners"] = {"companies": {}, "chapters": {}, "shock": {}}
	return GameState.data["overseas_partners"]


static func company(entity := "") -> Dictionary:
	if entity == "":
		entity = GameState.company_id()
	if not S()["companies"].has(entity):
		S()["companies"][entity] = {"warehouse": {}, "transfers": [], "home_invoices": false, "visiting": false, "next_offer": 0}
	return S()["companies"][entity]


static func warehouse_location(entity := "") -> String:
	if entity == "":
		entity = GameState.company_id()
	return "lumina_3pl:" + entity


static func begin(chapter: String) -> void:
	if not S()["chapters"].has(chapter):
		S()["chapters"][chapter] = {"entity": GameState.company_id(), "started": Clock.now(), "month_closes": GameState.stat("month_closes")}
	if not GlobalMarket.live(str(S()["chapters"][chapter]["entity"])):
		GameState.set_flag(chapter + "_unavailable")
	if chapter == "ch15_currency_swing" and S()["shock"].is_empty():
		var ccy := str(cfg()["shock"]["currency"])
		var before := FX.rate(ccy)
		var estimated := FXForward.exposure(GameState.company_id(), ccy, 30, true)
		FX.S()["rates"][ccy] = snappedf(before * (1 - float(cfg()["shock"]["drop"])), 0.000001)
		FX.add_shock(ccy, float(cfg()["shock"]["volatility"]), int(cfg()["shock"]["days"]))
		S()["shock"] = {"currency": ccy, "before": before, "after": FX.rate(ccy), "started": Clock.now(), "exposure_estimate": estimated}
		GameState.set_flag("fx_shock_started")
		GameState.add_message("marcus", "Auroria's currency fell 12% over the past week. Keeping the same local price now brings home less cash. Reprice, hedge expected receipts, or invoice future overseas contracts in home currency.")


static func net_unit(region: String, price: float, rate: float) -> float:
	return snappedf(price * rate * (1 - float(Ecommerce.mk().get("fee_rate", 0.1))) * (1 - float(FX.cfg().get("bank_spread", 0.015))), 0.01)


static func choose_home_invoices() -> bool:
	if not GlobalMarket.live(GameState.company_id()):
		return false
	company()["home_invoices"] = true
	GameState.set_flag("fx_response_home")
	StoryEngine.check()
	return true


static func contact_omar() -> void:
	GameState.set_flag("met_omar")
	UIRoot.queue_dialogue("omar_trade")
	StoryEngine.check()


static func travel(payer: String, returning := false) -> Dictionary:
	var ent := GameState.company_id()
	if not GlobalMarket.live(ent) or not payer in ["player", ent]:
		return {"ok": false, "error": "Choose your personal account or the current company account."}
	var c := company()
	if bool(c["visiting"]) == not returning:
		return {"ok": false, "error": "This journey was already completed."}
	var fare := float(cfg()["flight_fare"])
	if Ledger.cash(payer) < fare:
		return {"ok": false, "error": "Keep enough cash for the ticket, or call Omar by video."}
	Ledger.expense(payer, "transport", fare, I18n.t("Lumina %s flight ticket: %s") % [(I18n.t("Return") if returning else I18n.t("Outbound")), Fmt.money(fare)], {"type": "lumina_flight"})
	c["visiting"] = not returning
	Clock.advance(int(cfg()["flight_days"]) * Clock.DAY)
	GameState.set_flag("visited_lumina")
	if not returning and not GameState.flag("met_omar"):
		contact_omar()
	var card := InfoModal.new()
	card.title_text = "Lumina journey"
	card.icon_name = "world"
	card.lines = [I18n.t("%s flight completed: %s paid; %d day elapsed. Business simulation continued during the journey.") % [(I18n.t("Return") if returning else I18n.t("Outbound")), Fmt.money(fare), int(cfg()["flight_days"])]]
	UIRoot.open_modal(card)
	return {"ok": true}


static func listing() -> Dictionary:
	for l in Ecommerce.E()["listings"].values():
		if l.get("active", false):
			return l
	return {}


static func distributor_offer(product := "", clearance := false) -> Dictionary:
	var ent := GameState.company_id()
	if not GlobalMarket.live(ent) or not GameState.flag("met_omar"):
		return {"ok": false, "error": "Contact Omar with a live registered company first."}
	var l := listing() if product == "" else Ecommerce.listing_for(product)
	if l.is_empty():
		return {"ok": false, "error": "Create an active product listing first; Omar needs a product and a price."}
	var tag := "lumina_clearance" if clearance else "lumina_distributor"
	for existing in Contracts.C().values():
		if existing.get("tag", "") == tag and existing["seller"] == ent and existing["status"] in ["offered", "active", "shipped", "delivered"]:
			return {"ok": true, "id": existing["id"]}
	if Clock.now() < int(company()["next_offer"]):
		return {"ok": false, "error": "The buyer declined the home-currency quote. Try a new quote tomorrow or choose overseas warehousing."}
	var qty := int(cfg()["distributor_units"])
	if clearance:
		if not clearance_available():
			return {"ok": false, "error": "Review slow overseas stock after 45 days."}
		qty = Ecommerce.available(warehouse_location(), str(l["product"]))
	if qty <= 0:
		return {"ok": false, "error": "No unreserved overseas stock remains to sell."}
	var unit := snappedf(float(l["price"]) * float(cfg()["wholesale_factor"]), 0.01)
	if company()["home_invoices"]:
		if GameState.randf() > float(cfg()["home_invoice_acceptance"]):
			company()["next_offer"] = Clock.now() + Clock.DAY
			return {"ok": false, "error": "The buyer declined the home-currency quote. Try a new quote tomorrow or choose overseas warehousing."}
		unit = snappedf(unit * float(cfg()["home_invoice_price_factor"]), 0.01)
	var id := Contracts.create_offer({"buyer": "lumina_trade", "product": l["product"], "qty": qty, "unit_price": unit,
		"delivery_days": int(cfg()["distributor_delivery_days"]), "payment_terms_days": int(cfg()["distributor_payment_days"]),
		"tag": tag, "type": "lumina_distributor", "region": "lumina", "home_invoice": company()["home_invoices"]})
	return {"ok": true, "id": id}


static func open_warehouse() -> Dictionary:
	if not GlobalMarket.live(GameState.company_id()) or not GameState.flag("met_omar"):
		return {"ok": false, "error": "Contact Omar with a live registered company first."}
	if not GlobalMarket.company()["bank"]:
		return {"ok": false, "error": "Open the international bank account before leasing overseas stock space."}
	if not company()["warehouse"].is_empty():
		return {"ok": true}
	var fee := float(cfg()["warehouse_open_fee"])
	if Ledger.cash(GameState.company_id()) < fee:
		return {"ok": false, "error": "Transfer company cash for warehouse opening, or choose a distributor."}
	Ledger.expense(GameState.company_id(), "rent_warehouse", fee, I18n.t("Lumina warehouse opening: %s") % Fmt.money(fee), {"type": "lumina_warehouse"})
	company()["warehouse"] = {"opened": Clock.now(), "last_month": Clock.month_key()}
	GlobalMarket.open_store("lumina")
	return {"ok": true}


static func transfer(product: String, qty: int) -> Dictionary:
	var ent := GameState.company_id()
	if not GlobalMarket.live(ent) or company()["warehouse"].is_empty() or qty <= 0:
		return {"ok": false, "error": "Open the overseas warehouse and choose a positive quantity first."}
	var source := Ecommerce.best_location(product)
	if source == "" or Ecommerce.available(source, product) < qty:
		return {"ok": false, "error": "Keep enough unreserved domestic stock before sending a batch overseas."}
	var used := Ecommerce.total_units_at(warehouse_location())
	for t in company()["transfers"]:
		if t["status"] == "in_transit":
			used += int(t["qty"])
	if used + qty > int(cfg()["warehouse_capacity"]):
		return {"ok": false, "error": "Overseas stock and incoming batches exceed the warehouse capacity."}
	var freight := snappedf(float(cfg()["transfer_freight_base"]) + qty * float(cfg()["transfer_freight_unit"]), 0.01)
	var unit := Ecommerce.avg_cost(source, product)
	var cost := snappedf(unit * qty, 0.01)
	var duty := Customs.duty({"region": "lumina", "product": product, "foreign_price": unit / FX.rate(GlobalMarket.currency("lumina")), "qty": qty, "currency": GlobalMarket.currency("lumina")})
	if Ledger.cash(ent) < freight + duty:
		return {"ok": false, "error": "Company cash must cover sea freight and arrival duty before dispatch."}
	Ecommerce.inv(source)[product]["qty"] -= qty
	Ledger.post(ent, I18n.t("Lumina stock batch: %d units") % qty, [{"acct": "inventory_in_transit", "dr": cost}, {"acct": "inventory", "cr": cost}], {"type": "lumina_stock"})
	Ledger.expense(ent, "shipping", freight, I18n.t("Lumina sea freight: %s") % Fmt.money(freight), {"type": "lumina_stock_freight"})
	Ledger.expense(ent, "compliance", duty, I18n.t("Lumina batch duty: %s") % Fmt.money(duty), {"type": "lumina_stock_duty"})
	var t := {"index": company()["transfers"].size(), "status": "in_transit", "product": product, "qty": qty, "unit_cost": unit,
		"cost": cost, "defect_rate": Ecommerce.inv(source)[product].get("defect_rate", 0), "eta": Clock.now() + int(cfg()["transfer_days"]) * Clock.DAY}
	company()["transfers"].append(t)
	Sim.schedule(int(t["eta"]), "partners.arrive", {"entity": ent, "index": t["index"]})
	GameState.set_flag("lumina_stock_dispatched")
	StoryEngine.check()
	return {"ok": true}


static func handle(_kind: String, p: Dictionary) -> void:
	var ent := str(p.get("entity", ""))
	if not GlobalMarket.live(ent) or int(p.get("index", -1)) < 0 or int(p["index"]) >= company(ent)["transfers"].size():
		return
	var t: Dictionary = company(ent)["transfers"][int(p["index"])]
	if t["status"] != "in_transit" or Clock.now() < int(t["eta"]):
		return
	Ecommerce._add_stock(warehouse_location(ent), str(t["product"]), int(t["qty"]), float(t["unit_cost"]), float(t["defect_rate"]))
	Ledger.post(ent, I18n.t("Lumina batch arrived: %d units") % int(t["qty"]), [{"acct": "inventory", "dr": t["cost"]}, {"acct": "inventory_in_transit", "cr": t["cost"]}], {"type": "lumina_stock_arrival"})
	t["status"] = "arrived"
	StoryEngine.check()


static func order_location(region: String, product: String, domestic: String) -> String:
	if region == "lumina" and GlobalMarket.live(GameState.company_id()) and Ecommerce.available(warehouse_location(), product) > 0:
		return warehouse_location()
	return domestic


static func ship_contract(c: Dictionary) -> Dictionary:
	var ent := str(c["seller"])
	var qty := int(c["qty"])
	var clearance: bool = c.get("tag", "") == "lumina_clearance"
	var freight := snappedf(qty * float(cfg()["warehouse_shipping_unit"]) if clearance else float(cfg()["transfer_freight_base"]) + qty * float(cfg()["transfer_freight_unit"]), 0.01)
	var duty := 0.0 if clearance else Customs.duty({"region": "lumina", "product": c["product"], "foreign_price": float(c["unit_price"]) / FX.rate(GlobalMarket.currency("lumina")), "qty": qty, "currency": GlobalMarket.currency("lumina")})
	if Ledger.cash(ent) < freight + duty:
		return {"ok": false, "error": "Keep company cash for distributor freight and duty before dispatch."}
	var locations: Array = [warehouse_location(ent)] if clearance else Ecommerce.stock_locations()
	var left := qty
	var cost := 0.0
	for loc in locations:
		var take := mini(left, Contracts.available_for_contract(c, str(loc)))
		cost += take * Ecommerce.avg_cost(str(loc), str(c["product"]))
		if take > 0:
			Ecommerce.inv(str(loc))[c["product"]]["qty"] -= take
		left -= take
		if left == 0:
			break
	assert(left == 0, "Distributor stock was validated before dispatch")
	cost = snappedf(cost, 0.01)
	Ledger.post(ent, I18n.t("Distributor %s dispatched: %d units") % [c["id"], qty], [{"acct": "goods_out", "dr": cost}, {"acct": "inventory", "cr": cost}], {"type": "lumina_distributor_dispatch", "id": c["id"]})
	Ledger.expense(ent, "shipping", freight, I18n.t("Distributor freight %s: %s") % [c["id"], Fmt.money(freight)], {"type": "lumina_distributor_freight", "id": c["id"]})
	Ledger.expense(ent, "compliance", duty, I18n.t("Distributor duty %s: %s") % [c["id"], Fmt.money(duty)], {"type": "lumina_distributor_duty", "id": c["id"]})
	c.merge({"status": "shipped", "shipped": Clock.now(), "shipment_cost": cost, "eta": Clock.now() + int(cfg()["warehouse_delivery_days"] if clearance else cfg()["transfer_days"]) * Clock.DAY}, true)
	Sim.cancel("con.due", "id", c["id"])
	Sim.schedule(int(c["eta"]), "con.partner_arrive", {"id": c["id"]})
	EventBus.contract_changed.emit(str(c["id"]))
	return {"ok": true, "receivable": 0.0}


static func receive_contract(c: Dictionary) -> void:
	if c["status"] != "shipped" or Clock.now() < int(c["eta"]) or not GlobalMarket.live(str(c["seller"])):
		return
	var total := snappedf(float(c["foreign_total"]) * FX.rate(str(c["invoice_currency"])), 0.01)
	var penalty := snappedf(total * float(c["penalty_rate"]), 0.01) if Clock.now() > int(c["due"]) else 0.0
	var cost := float(c["shipment_cost"])
	Ledger.post(str(c["seller"]), I18n.t("Distributor %s received; invoice %s") % [c["id"], Fmt.money(total)],
		[{"acct": "accounts_receivable", "dr": total - penalty}, {"acct": "revenue", "cr": total}, {"acct": "exp:penalties", "dr": penalty}, {"acct": "cogs", "dr": cost}, {"acct": "goods_out", "cr": cost}], {"type": "lumina_distributor_delivery", "id": c["id"]})
	c.merge({"status": "delivered", "total": total, "delivered": Clock.now(), "receivable": total - penalty,
		"foreign_receivable": (total - penalty) / FX.rate(str(c["invoice_currency"])), "pay_due": Clock.now() + int(c["payment_terms_days"]) * Clock.DAY}, true)
	Sim.schedule(int(c["pay_due"]), "con.pay", {"id": c["id"]})
	Contracts._tag(c, "delivered")
	GameState.inc_stat("contracts_delivered")
	GameState.inc_stat("revenue_total", total)
	EventBus.contract_changed.emit(str(c["id"]))


static func fulfil(o: Dictionary) -> void:
	if o["status"] != "placed" or not str(o["location"]).begins_with("lumina_3pl:"):
		return
	var fee := snappedf(float(cfg()["warehouse_shipping_unit"]) * int(o["qty"]), 0.01)
	var packaging := float(DataDB.product(str(o["product"])).get("packaging_cost", 0.5)) + Ecommerce.packaging_extra()
	if Ledger.cash(str(o["entity"])) < fee + packaging:
		return   # retain the order; hourly retry or liquidation remains possible
	Ecommerce.pack_orders(str(o["location"]), 1)
	if o["status"] != "packed":
		return
	Ledger.expense(str(o["entity"]), "shipping", fee, I18n.t("Lumina 3PL shipment %s: %s") % [o["id"], Fmt.money(fee)], {"type": "lumina_3pl_shipping", "order": o["id"]})
	o["partner_channel"] = "3pl"
	o["customs"] = {"policy": "ddp", "code": Customs.code_for(str(o["product"])), "cleared": true, "duty_paid": 0}
	o["ship"] = {"method": "international_express", "cost": fee, "mode": "3pl"}
	Ecommerce._ship(o)


static func clearance_available() -> bool:
	var w: Dictionary = company()["warehouse"]
	return not w.is_empty() and Clock.now() - int(w["opened"]) >= int(cfg()["clearance_after_days"]) * Clock.DAY


static func review_available() -> bool:
	var ch: Dictionary = S()["chapters"].get("ch16_partner_overseas", {})
	return not ch.is_empty() and Clock.now() - int(ch["started"]) >= int(cfg()["clearance_after_days"]) * Clock.DAY


static func review() -> void:
	if review_available():
		GameState.set_flag("ch16_reviewed")
		StoryEngine.check()


static func on_hour() -> void:
	FXForward.on_hour()
	for ent in S()["companies"]:
		if not GlobalMarket.live(str(ent)):
			continue
		var c := company(str(ent))
		var w: Dictionary = c["warehouse"]
		if not w.is_empty() and w["last_month"] != Clock.month_key():
			var rent := snappedf(Ecommerce.total_units_at(warehouse_location(str(ent))) * float(cfg()["warehouse_rent_unit_month"]), 0.01)
			Ledger.expense(str(ent), "rent_warehouse", rent, I18n.t("Lumina monthly stock rent: %s") % Fmt.money(rent), {"type": "lumina_warehouse_rent"})
			w["last_month"] = Clock.month_key()
	for o in Ecommerce.orders_with(["placed"]):
		if GlobalMarket.live(str(o["entity"])):
			fulfil(o)


static func reconcile() -> void:
	for chapter in S()["chapters"]:
		if not GlobalMarket.live(str(S()["chapters"][chapter]["entity"])):
			GameState.set_flag(str(chapter) + "_unavailable")
	for c in Contracts.C().values():
		if c.get("type", "") == "lumina_distributor" and c["seller"] == GameState.company_id():
			if c["status"] in ["active", "shipped", "delivered", "paid"]:
				GameState.set_flag("lumina_channel_ready")
			if c["status"] == "paid":
				GameState.set_flag("lumina_channel_income")
	for o in Ecommerce.E()["orders"].values():
		if o.get("entity", "") == GameState.company_id() and o.get("partner_channel", "") == "3pl" and o.get("global_paid", false):
			GameState.set_flag("lumina_channel_income")
	if GameState.flag("lumina_stock_dispatched"):
		GameState.set_flag("lumina_channel_ready")


static func close_for_entity(entity: String) -> void:
	FXForward.close_for_entity(entity)
	for t in company(entity)["transfers"]:
		if t["status"] == "in_transit":
			Ledger.post(entity, I18n.t("Lumina transit stock written off at closure"), [{"acct": "exp:inventory_writeoff", "dr": t["cost"]}, {"acct": "inventory_in_transit", "cr": t["cost"]}], {"type": "lumina_transit_closure"})
			t["status"] = "cancelled"
	for c in Contracts.C().values():
		if c.get("type", "") == "lumina_distributor" and c["seller"] == entity and c.has("shipment_cost") and not c.has("delivered") and not c.get("closure_written_off", false):
			Ledger.post(entity, I18n.t("Lumina distributor goods written off at closure"), [{"acct": "exp:inventory_writeoff", "dr": c["shipment_cost"]}, {"acct": "goods_out", "cr": c["shipment_cost"]}], {"type": "lumina_distributor_closure", "id": c["id"]})
			c["closure_written_off"] = true
	Sim.cancel("partners.arrive", "entity", entity)
