class_name Contracts
extends RefCounted
## B2B contracts between two entities (Handoff §23). Nothing here assumes the counterparty is an NPC:
## buyer/seller are entity ids, which keeps the Enterprise Network boundary (P4) open.
## Lifecycle: offered → (accept | reject | counter ⇄ offered) → active → delivered (AR) → paid | withdrawn/expired.


static func C() -> Dictionary:
	return GameState.data["contracts"]


static func create_offer(t: Dictionary) -> String:
	var n := C().size() + 1
	var cid := "C-%03d" % n
	var p := DataDB.product(t["product"])
	var qty := int(t["qty"])
	var price := float(t["unit_price"])
	var c := {
		"id": cid, "buyer": t["buyer"], "seller": t.get("seller", GameState.business_entity()), "product": t["product"],
		"qty": qty, "unit_price": price, "total": snappedf(qty * price, 0.01), "orig_price": price,
		"delivery_days": int(t.get("delivery_days", 7)), "payment_terms_days": int(t.get("payment_terms_days", 30)),
		"orig_terms": int(t.get("payment_terms_days", 30)),
		"penalty_rate": float(t.get("penalty_rate", 0.05)), "quality_req": t.get("quality_req", "No defects on arrival"),
		"upfront_rate": float(t.get("upfront_rate", 0.0)), "currency": "AUD", "settlement": "bank_transfer",
		"status": "offered", "offered": Clock.now(), "expires": Clock.now() + int(t.get("expires_days", 2)) * Clock.DAY,
		"patience": int(DataDB.companies.get(t["buyer"], {}).get("negotiation", {}).get("patience", 1)),
		"history": [{"t": Clock.now(), "by": t["buyer"], "text": "Offer: %d × %s @ %s, Net %d" % [qty, p.get("name", ""), Fmt.money(price), int(t.get("payment_terms_days", 30))]}],
	}
	C()[cid] = c
	Sim.schedule(int(c["expires"]), "con.expire", {"id": cid})
	EventBus.contract_changed.emit(cid)
	return cid


static func can_trade() -> bool:
	return GameState.company_id() != ""


static func accept(cid: String) -> Dictionary:
	var c: Dictionary = C().get(cid, {})
	if c.is_empty() or c["status"] != "offered":
		return {"ok": false, "error": "This offer is no longer open."}
	if not can_trade():
		return {"ok": false, "error": "They need an invoice from a registered company."}
	c["seller"] = GameState.business_entity()
	c["status"] = "active"
	c["accepted"] = Clock.now()
	c["due"] = Clock.now() + int(c["delivery_days"]) * Clock.DAY
	c["location"] = Ecommerce.default_stock_location()
	c["history"].append({"t": Clock.now(), "by": c["seller"], "text": "Accepted."})
	if float(c["upfront_rate"]) > 0.0:
		var up := snappedf(float(c["total"]) * float(c["upfront_rate"]), 0.01)
		c["upfront_paid"] = up
		Ledger.post(c["seller"], "Deposit received from %s (%s)" % [GameState.entity_name(c["buyer"]), cid],
			[{"acct": "cash", "dr": up}, {"acct": "deferred_revenue", "cr": up}], {"type": "contract", "id": cid})
	Sim.schedule(int(c["due"]), "con.due", {"id": cid})
	GameState.timeline("Signed contract %s with %s: %s." % [cid, GameState.entity_name(c["buyer"]), Fmt.money(c["total"])], "business")
	EventBus.contract_changed.emit(cid)
	return {"ok": true}


static func reject(cid: String) -> void:
	var c: Dictionary = C().get(cid, {})
	if c.is_empty():
		return
	c["status"] = "rejected"
	c["history"].append({"t": Clock.now(), "by": GameState.business_entity(), "text": "Declined."})
	EventBus.contract_changed.emit(cid)


## Counter-offer. The counterparty evaluates with its data-driven negotiation profile.
static func counter(cid: String, unit_price: float, terms_days: int, upfront_rate: float) -> Dictionary:
	var c: Dictionary = C().get(cid, {})
	if c.is_empty() or c["status"] != "offered":
		return {"ok": false, "error": "This offer is no longer open."}
	if not can_trade():
		return {"ok": false, "error": "Register your company first."}
	var neg: Dictionary = DataDB.companies.get(c["buyer"], {}).get("negotiation", {})
	c["history"].append({"t": Clock.now(), "by": GameState.business_entity(),
		"text": "Counter: %s/unit, Net %d%s" % [Fmt.money(unit_price), terms_days, (", %d%% upfront" % int(upfront_rate * 100)) if upfront_rate > 0 else ""]})
	var max_price := float(c["orig_price"]) * (2.0 - float(neg.get("min_price_factor", 0.9)))  # tolerance above their offer
	var min_terms := int(neg.get("min_terms_days", 15))
	var max_up := float(neg.get("accepts_upfront", 0.3))
	var ok := unit_price <= max_price * 0.96 + 0.001 and terms_days >= min_terms and upfront_rate <= max_up + 0.001
	if ok:
		c["unit_price"] = snappedf(unit_price, 0.01)
		c["payment_terms_days"] = terms_days
		c["upfront_rate"] = upfront_rate
		c["total"] = snappedf(int(c["qty"]) * float(c["unit_price"]), 0.01)
		c["history"].append({"t": Clock.now(), "by": c["buyer"], "text": "Deal. Send it over."})
		EventBus.contract_changed.emit(cid)
		return {"ok": true, "result": "agreed"}
	c["patience"] = int(c["patience"]) - 1
	if int(c["patience"]) < 0:
		c["status"] = "withdrawn"
		c["history"].append({"t": Clock.now(), "by": c["buyer"], "text": "We'll source elsewhere. Thanks anyway."})
		EventBus.contract_changed.emit(cid)
		return {"ok": true, "result": "withdrawn"}
	# meet in the middle
	var mid_price := snappedf((float(c["unit_price"]) + minf(unit_price, max_price * 0.96)) / 2.0, 0.05)
	var mid_terms := maxi(min_terms, int((int(c["payment_terms_days"]) + terms_days) / 2))
	var mid_up := minf(upfront_rate, max_up)
	c["unit_price"] = mid_price
	c["payment_terms_days"] = mid_terms
	c["upfront_rate"] = mid_up
	c["total"] = snappedf(int(c["qty"]) * mid_price, 0.01)
	c["history"].append({"t": Clock.now(), "by": c["buyer"],
		"text": "Best we can do: %s/unit, Net %d%s." % [Fmt.money(mid_price), mid_terms, (", %d%% upfront" % int(mid_up * 100)) if mid_up > 0 else ""]})
	EventBus.contract_changed.emit(cid)
	return {"ok": true, "result": "countered"}


static func can_deliver(cid: String) -> bool:
	var c: Dictionary = C().get(cid, {})
	if c.is_empty() or c["status"] != "active":
		return false
	return Ecommerce.stock(c["location"], c["product"]) >= int(c["qty"])


## Deliver the whole contract quantity from its stock location. Caller advances packing time.
static func deliver(cid: String) -> Dictionary:
	var c: Dictionary = C().get(cid, {})
	if c.is_empty() or c["status"] != "active":
		return {"ok": false, "error": "Nothing to deliver."}
	var loc: String = c["location"]
	var qty := int(c["qty"])
	if Ecommerce.stock(loc, c["product"]) < qty:
		return {"ok": false, "error": "You need %d in stock at %s (have %d)." % [qty, Ecommerce.location_name(loc), Ecommerce.stock(loc, c["product"])]}
	var uc := Ecommerce.avg_cost(loc, c["product"])
	var cogs := snappedf(uc * qty, 0.01)
	Ecommerce.inv(loc)[c["product"]]["qty"] = Ecommerce.stock(loc, c["product"]) - qty
	var total := float(c["total"])
	var up := float(c.get("upfront_paid", 0.0))
	var late := Clock.now() > int(c["due"])
	var penalty := snappedf(total * float(c["penalty_rate"]), 0.01) if late else 0.0
	var freight := float(DataDB.shipping()["b2b_freight"]["flat_fee"])
	var ent: String = c["seller"]
	var lines := [
		{"acct": "accounts_receivable", "dr": total - up}, {"acct": "deferred_revenue", "dr": up}, {"acct": "revenue", "cr": total},
		{"acct": "cogs", "dr": cogs}, {"acct": "inventory", "cr": cogs},
		{"acct": "exp:shipping", "dr": freight}, {"acct": "cash", "cr": freight}]
	if penalty > 0:
		lines += [{"acct": "exp:penalties", "dr": penalty}, {"acct": "accounts_receivable", "cr": penalty}]
	Ledger.post(ent, "Contract %s delivered to %s: %d × %s @ %s" % [cid, GameState.entity_name(c["buyer"]), qty,
		DataDB.product(c["product"])["name"], Fmt.money(c["unit_price"])], lines, {"type": "contract", "id": cid})
	c["status"] = "delivered"
	c["delivered"] = Clock.now()
	c["receivable"] = snappedf(total - up - penalty, 0.01)
	c["pay_due"] = Clock.now() + int(c["payment_terms_days"]) * Clock.DAY
	c["history"].append({"t": Clock.now(), "by": ent, "text": "Delivered%s. Invoice %s due in %d days." % [" late (penalty %s)" % Fmt.money(penalty) if late else "", Fmt.money(c["receivable"]), int(c["payment_terms_days"])]})
	Sim.cancel("con.due", "id", cid)
	Sim.schedule(int(c["pay_due"]), "con.pay", {"id": cid})
	GameState.inc_stat("contracts_delivered")
	GameState.inc_stat("revenue_total", total)
	EventBus.contract_changed.emit(cid)
	return {"ok": true, "receivable": c["receivable"]}


static func on_hour(_t: int, _h: int) -> void:
	pass


static func handle(kind: String, p: Dictionary) -> void:
	var c: Dictionary = C().get(p.get("id", ""), {})
	if c.is_empty():
		return
	match kind:
		"con.expire":
			if c["status"] == "offered":
				c["status"] = "expired"
				c["history"].append({"t": Clock.now(), "by": c["buyer"], "text": "Offer expired."})
				EventBus.contract_changed.emit(c["id"])
		"con.due":
			if c["status"] == "active":
				GameState.add_message("harbor_point", "Hey — the %d %s were due today. Still coming?" % [int(c["qty"]), DataDB.product(c["product"])["name"].to_lower()])
				EventBus.notify.emit("Contract %s is overdue. Late penalty %s applies." % [c["id"], Fmt.pct(c["penalty_rate"])], "bad", "contracts")
		"con.pay":
			if c["status"] == "delivered":
				var amt := float(c["receivable"])
				Ledger.post(c["seller"], "Invoice paid by %s (%s)" % [GameState.entity_name(c["buyer"]), c["id"]],
					[{"acct": "cash", "dr": amt}, {"acct": "accounts_receivable", "cr": amt}], {"type": "contract", "id": c["id"]})
				c["status"] = "paid"
				c["history"].append({"t": Clock.now(), "by": c["buyer"], "text": "Paid %s." % Fmt.money(amt)})
				EventBus.notify.emit("%s paid invoice %s: %s" % [GameState.entity_name(c["buyer"]), c["id"], Fmt.money(amt)], "good", "cash")
				EventBus.contract_changed.emit(c["id"])


static func open_list() -> Array:
	var out: Array = C().values()
	out.sort_custom(func(a, b): return int(a["offered"]) > int(b["offered"]))
	return out
