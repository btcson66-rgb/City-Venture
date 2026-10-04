class_name GlobalMarket
extends RefCounted
## Regional prices feed the existing ecommerce orders and shared inventory/packing/shipping flow.


static func cfg() -> Dictionary:
	return DataDB.economy.get("regions_market", {})


static func S() -> Dictionary:
	if not GameState.data.has("global_market"):
		GameState.data["global_market"] = {"companies": {}}
	return GameState.data["global_market"]


static func live(entity: String) -> bool:
	var e: Dictionary = GameState.data["entities"].get(entity, {})
	return entity != "" and entity != "player" and not e.is_empty() and not e.has("closed")


static func company(entity := "") -> Dictionary:
	if entity == "":
		entity = GameState.company_id()
	if not S()["companies"].has(entity):
		S()["companies"][entity] = {"bank": false, "stores": {}, "balances": {}, "auto_fx": false}
	return S()["companies"][entity]


static func currency(region: String) -> String:
	return str(cfg().get("regions", {}).get(region, {}).get("currency", ""))


static func unlocked(region: String) -> bool:
	var r: Dictionary = cfg().get("regions", {}).get(region, {})
	return not r.is_empty() and (World.year() >= int(r.get("unlock_year", 9)) or GameState.flag("global_markets_open") or GameState.flag("region_unlocked:" + region))


static func bank_block() -> String:
	var ent := GameState.company_id()
	if not live(ent):
		return "Register a company at City Hall first."
	if not GameState.flag("business_account_opened"):
		return "Open the company's domestic bank account first."
	if company()["bank"]:
		return ""
	if Ledger.cash(ent) < float(cfg().get("bank_open_fee", 150)):
		return "Keep enough company cash for the international account fee."
	return ""


static func open_bank() -> Dictionary:
	var why := bank_block()
	if why != "":
		return {"ok": false, "error": why}
	if not company()["bank"]:
		var fee := float(cfg().get("bank_open_fee", 150))
		Ledger.expense(GameState.company_id(), "bank_fees", fee,
			I18n.t("International account opening fee: %s") % Fmt.money(fee), {"type": "global_bank"})
		company()["bank"] = true
	StoryEngine.check()
	return {"ok": true}


static func store_block(region: String) -> String:
	if not cfg().get("regions", {}).has(region):
		return "Choose a supported overseas region."
	if not unlocked(region):
		return "Overseas markets open in Chapter 13."
	if not live(GameState.company_id()):
		return "Register a company at City Hall first."
	if not company()["bank"]:
		return "Open an international account at Nexus Bank first."
	return ""


static func open_store(region: String) -> Dictionary:
	var why := store_block(region)
	if why != "":
		return {"ok": false, "error": why}
	if not company()["stores"].has(region):
		company()["stores"][region] = {"prices": {}, "revenue": 0.0}
	StoryEngine.check()
	return {"ok": true}


static func set_price(region: String, listing: String, price: float) -> Dictionary:
	var why := store_block(region)
	if why != "":
		return {"ok": false, "error": why}
	var l: Dictionary = Ecommerce.E()["listings"].get(listing, {})
	if not company()["stores"].has(region) or l.is_empty():
		return {"ok": false, "error": "Open this storefront and create a product listing first."}
	if price <= 0.0 or not is_finite(price):
		return {"ok": false, "error": "Enter a positive price in the region's currency."}
	var p := DataDB.product(str(l["product"]))
	var quote := FX.rate(currency(region))
	var min_price := float(p["price_min"]) / quote
	var max_price := float(p["price_max"]) / quote
	if price < min_price or price > max_price:
		return {"ok": false, "error": I18n.t("Price range: %s–%s %s per unit.") % [Fmt.money(min_price), Fmt.money(max_price), currency(region)]}
	var previous := float(company()["stores"][region]["prices"].get(listing, 0))
	company()["stores"][region]["prices"][listing] = snappedf(price, 0.01)
	if not OverseasPartners.S()["shock"].is_empty() and currency(region) == OverseasPartners.S()["shock"]["currency"] and not is_equal_approx(previous, price):
		GameState.set_flag("fx_response_reprice")
	StoryEngine.check()
	return {"ok": true}


static func order_allowed(region: String, listing: String) -> bool:
	var c := company()
	return live(GameState.company_id()) and unlocked(region) and c["bank"] and c["stores"].get(region, {}).get("prices", {}).has(listing)


static func demand(region: String, l: Dictionary) -> float:
	if not order_allowed(region, str(l["id"])) or not l.get("active", false):
		return 0.0
	var copy := l.duplicate()
	copy["price"] = float(company()["stores"][region]["prices"][l["id"]]) * FX.rate(currency(region))
	var r: Dictionary = cfg()["regions"][region]
	var product := DataDB.product(str(l["product"]))
	var sector := float(r.get("product_multipliers", {}).get(product.get("category", ""), 1.0))
	return Ecommerce.lambda_day(copy, region) * float(r.get("demand_multiplier", 1.0)) * sector * float(r.get("population_millions", 10)) / float(cfg().get("population_reference", 10))


static func on_hour(t: int, h: int) -> void:
	if h == 0:
		FX.on_day(Clock.day_index_at(t))
	if not live(GameState.company_id()):
		return
	if Clock.weekday(t) == int(Ecommerce.mk().get("payout_weekday", 1)) and h == int(Ecommerce.mk().get("payout_hour", 9)):
		payout(GameState.company_id())
	var weights: Array = Ecommerce.mk().get("hourly_weights", [])
	var total := 0.0
	for w in weights:
		total += float(w)
	if total <= 0.0:
		return
	for region in company()["stores"]:
		for l in Ecommerce.E()["listings"].values():
			for i in GameState.poisson(demand(str(region), l) * float(weights[h]) / total):
				Sim.schedule(t + GameState.randi_range(1, 59), "eco.order_place", {"listing": l["id"], "region": region})


static func annotate_order(o: Dictionary, region: String) -> void:
	o["region"] = region
	o["currency"] = currency(region)
	o["foreign_price"] = float(company()["stores"][region]["prices"][o["listing"]])
	o["unit_price"] = snappedf(float(o["foreign_price"]) * FX.rate(o["currency"]), 0.01)


static func shipping_method(o: Dictionary, method: String) -> String:
	if not o.has("region"):
		return method
	return "international_express" if method in ["express", "international_express"] else "international_economy"


static func shipping_cost(o: Dictionary, method: String) -> float:
	var m := DataDB.ship_method(shipping_method(o, method))
	var days := float(DataDB.regions[o["region"]]["shipping_days_from_aurelia"])
	return snappedf((float(m.get("base_cost", 5)) + days * float(m.get("cost_per_day", 0.7))) * World.shipping_index(), 0.01)


static func shipping_days(o: Dictionary, method: String) -> int:
	var m := DataDB.ship_method(shipping_method(o, method))
	var base := float(DataDB.regions[o["region"]]["shipping_days_from_aurelia"])
	return clampi(int(ceil(base * float(m.get("days_factor", 1.0)))), int(m.get("min_days", 7)), int(m.get("max_days", 14)))


static func balance(entity: String, ccy: String) -> Dictionary:
	var c := company(entity)
	if not c["balances"].has(ccy):
		c["balances"][ccy] = {"receivable": 0.0, "wallet": 0.0}
	return c["balances"][ccy]


static func deliver(o: Dictionary) -> void:
	var ccy := str(o["currency"])
	var ent := str(o["entity"])
	var units := snappedf(float(o["foreign_price"]) * int(o["qty"]), 0.01)
	var fee := snappedf(units * float(Ecommerce.mk().get("fee_rate", 0.1)), 0.01)
	var spot := FX.rate(ccy)
	var home := snappedf(units * spot, 0.01)
	var home_fee := snappedf(fee * spot, 0.01)
	o["delivery_rate"] = spot
	o["unit_price"] = snappedf(float(o["foreign_price"]) * spot, 0.01)
	o["fee"] = home_fee
	o["foreign_due"] = units - fee
	Ledger.post(ent, I18n.t("Overseas delivery %s: %s %s") % [o["id"], Fmt.money(units), ccy],
		[{"acct": "fx_receivable:" + ccy, "dr": home - home_fee}, {"acct": "revenue", "cr": home},
		{"acct": "exp:platform_fees", "dr": home_fee}, {"acct": "cogs", "dr": float(o.get("cogs", 0))},
		{"acct": "goods_out", "cr": float(o.get("cogs", 0))}], {"type": "global_delivery", "id": o["id"], "foreign": units, "currency": ccy})
	var b := balance(ent, ccy)
	b["receivable"] = snappedf(float(b["receivable"]) + units - fee, 0.01)
	company(ent)["stores"][o["region"]]["revenue"] += units
	GameState.inc_stat("overseas_orders_delivered")
	GameState.inc_stat("revenue_total", home)


## Moving a foreign receipt into the wallet does not change book value or realize FX gains.
static func payout(entity: String) -> void:
	if not live(entity):
		return
	var hold := int(Ecommerce.mk().get("payout_hold_days", 2)) * Clock.DAY
	for o in Ecommerce.foreign_orders():
		if not o.has("region") or o["entity"] != entity or o.get("global_paid", false) or not o.has("delivery_rate") or Clock.now() - int(o["delivered"]) < hold:
			continue
		var ccy := str(o["currency"])
		var units := float(o.get("foreign_due", 0))
		if units > 0.0:
			var b := balance(entity, ccy)
			var available := float(b["receivable"])
			var book := Ledger.balance(entity, "fx_receivable:" + ccy)
			var moved := snappedf(book * units / maxf(0.01, available), 0.01)
			Ledger.post(entity, I18n.t("ShopLane Global payout: %s %s") % [Fmt.money(units), ccy],
				[{"acct": "fx_wallet:" + ccy, "dr": moved}, {"acct": "fx_receivable:" + ccy, "cr": moved}], {"type": "global_payout", "id": o["id"]})
			b["receivable"] = snappedf(available - units, 0.01)
			b["wallet"] = snappedf(float(b["wallet"]) + units, 0.01)
		o["global_paid"] = true
	if company(entity)["auto_fx"]:
		for ccy in company(entity)["balances"]:
			convert_currency(entity, str(ccy))


static func convert_currency(entity: String, ccy: String) -> Dictionary:
	if not live(entity) or not company(entity)["bank"] or FX.rate(ccy) <= 0.0:
		return {"ok": false, "error": "A live company and international account are required."}
	var b := balance(entity, ccy)
	var units := float(b["wallet"])
	if units <= 0.0:
		return {"ok": false, "error": "No foreign payout is ready to convert."}
	var book := Ledger.balance(entity, "fx_wallet:" + ccy)
	var cash := FX.to_home(units, ccy)
	var delta := snappedf(cash - book, 0.01)
	var lines := [{"acct": "cash", "dr": cash}, {"acct": "fx_wallet:" + ccy, "cr": book}]
	lines.append({"acct": "fx_gain_loss", "cr": delta} if delta >= 0 else {"acct": "fx_gain_loss", "dr": -delta})
	Ledger.post(entity, I18n.t("Convert %s %s to home cash: %s") % [Fmt.money(units), ccy, Fmt.money(cash)], lines,
		{"type": "fx_conversion", "currency": ccy, "foreign": units, "rate": FX.rate(ccy), "realized": delta})
	b["wallet"] = 0.0
	StoryEngine.check()
	return {"ok": true, "cash": cash, "gain_loss": delta}


## Refund in foreign units; consumed receipts retain book value, any shortfall is bought at today's ask.
static func refund(o: Dictionary, fraction: float, fee_refund := false) -> void:
	var ent := str(o["entity"])
	var ccy := str(o["currency"])
	var units := snappedf(float(o["foreign_price"]) * int(o["qty"]) * fraction, 0.01)
	var fee := snappedf(float(o["foreign_price"]) * int(o["qty"]) * float(Ecommerce.mk().get("fee_rate", 0.1)), 0.01) if fee_refund else 0.0
	var remaining := units - fee
	var b := balance(ent, ccy)
	var lines := [{"acct": "refunds", "dr": snappedf(units * float(o["delivery_rate"]), 0.01)}]
	if fee > 0:
		lines.append({"acct": "exp:platform_fees", "cr": float(o["fee"])})
	var book_used := 0.0
	for bucket in ["receivable", "wallet"]:
		if bucket == "receivable" and o.get("global_paid", false):
			continue   # a paid order must never consume another order's unpaid receipt
		var account: String = "fx_" + str(bucket) + ":" + ccy
		var available := float(b[bucket])
		var take := minf(remaining, available)
		if take <= 0:
			continue
		var used := snappedf(Ledger.balance(ent, account) * take / available, 0.01)
		lines.append({"acct": account, "cr": used})
		book_used += used
		b[bucket] = snappedf(available - take, 0.01)
		remaining = snappedf(remaining - take, 0.01)
	if remaining > 0:
		var cost := snappedf(remaining * FX.rate(ccy) * (1.0 + float(FX.cfg().get("bank_spread", 0.015))), 0.01)
		lines.append({"acct": "cash", "cr": cost})
		book_used += cost
	var historical := snappedf(units * float(o["delivery_rate"]), 0.01) - (float(o["fee"]) if fee_refund else 0.0)
	var delta := snappedf(book_used - historical, 0.01)
	lines.append({"acct": "fx_gain_loss", "dr": delta} if delta >= 0 else {"acct": "fx_gain_loss", "cr": -delta})
	Ledger.post(ent, I18n.t("Overseas refund %s: %s %s") % [o["id"], Fmt.money(units), ccy], lines, {"type": "global_refund", "id": o["id"]})
	if not o.get("global_paid", false):
		o["foreign_due"] = maxf(0, float(o.get("foreign_due", 0)) - units + fee)


static func close_for_entity(entity: String) -> void:
	OverseasPartners.close_for_entity(entity)
	if not S()["companies"].has(entity):
		return
	# Flush receivables at their carrying value before the existing company liquidation.
	for ccy in company(entity)["balances"]:
		var b := balance(entity, str(ccy))
		var book := Ledger.balance(entity, "fx_receivable:" + str(ccy))
		if book > 0:
			Ledger.post(entity, "Foreign receipts transferred for company closure", [{"acct": "fx_wallet:" + str(ccy), "dr": book}, {"acct": "fx_receivable:" + str(ccy), "cr": book}])
			b["wallet"] = float(b["wallet"]) + float(b["receivable"])
			b["receivable"] = 0.0
		convert_currency(entity, str(ccy))
	for o in Ecommerce.foreign_orders():
		if not o.has("region") or o["entity"] != entity:
			continue
		Customs.remove_decisions(str(o["id"]))
		if o["status"] in Ecommerce.OPEN_STATUSES:
			var cost := float(o.get("cogs", 0))
			if cost > 0:
				Ledger.post(entity, "Overseas parcel written off at closure", [{"acct": "exp:inventory_writeoff", "dr": cost}, {"acct": "goods_out", "cr": cost}])
			o["status"] = "cancelled"
		for kind in ["eco.deliver", "eco.return_request", "eco.dispute", "eco.review_fixed"]:
			Sim.cancel(kind, "order", o["id"])
	company(entity)["stores"].clear()
	company(entity)["auto_fx"] = false


static func resolve_return(o: Dictionary, choice: String) -> Dictionary:
	if not live(str(o["entity"])):
		return {"ok": false, "error": "This company's books are closed."}
	if choice == "refund":
		refund(o, 1.0, true)
		Ledger.expense(str(o["entity"]), "shipping", shipping_cost(o, "economy"), "International return postage", {"type": "global_return"})
		if not o.get("defective", false):
			HoldingGroups.return_margin(o)
			var cost := float(o.get("cogs", 0))
			Ecommerce._add_stock(str(o["location"]), str(o["product"]), int(o["qty"]), cost / maxi(1, int(o["qty"])), 0.0)
			Ledger.post(str(o["entity"]), "Returned overseas goods restocked", [{"acct": "inventory", "dr": cost}, {"acct": "cogs", "cr": cost}])
		o["status"] = "refunded"
	elif choice == "partial":
		refund(o, 0.3)
		o["status"] = "partial_refund"
		Sim.schedule(Clock.now() + 600, "eco.review_fixed", {"order": o["id"], "stars": 3})
	else:
		return {"ok": false, "error": "Unknown choice."}
	GameState.inc_stat("returns_resolved")
	return {"ok": true}
