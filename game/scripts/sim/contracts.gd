class_name Contracts
extends RefCounted
## B2B contracts between two entities (Handoff §23). Nothing here assumes the counterparty is an NPC:
## buyer/seller are entity ids, which keeps the Enterprise Network boundary (P4) open.
## Lifecycle: offered → (accept | reject | counter ⇄ offered) → active → delivered (AR) → paid | withdrawn/expired.
## Company closure: offered → withdrawn, active → terminated, delivered → sold_to_collector.


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
		"tag": str(t.get("tag", "")),
		"patience": int(DataDB.companies.get(t["buyer"], {}).get("negotiation", {}).get("patience", 1)),
		"history": [{"t": Clock.now(), "by": t["buyer"], "text": I18n.t("Offer: %d × %s @ %s, Net %d") % [qty, I18n.t(p.get("name", "")), Fmt.money(price), int(t.get("payment_terms_days", 30))]}],
	}
	C()[cid] = c
	Sim.schedule(int(c["expires"]), "con.expire", {"id": cid})
	EventBus.contract_changed.emit(cid)
	return cid


## Story hooks: a tagged contract ("big_contract") sets <tag>_accepted / _declined / _delivered / _paid.
static func _tag(c: Dictionary, what: String) -> void:
	var tag := str(c.get("tag", ""))
	if tag == "":
		return
	GameState.set_flag(tag + "_" + what)
	if what in ["accepted", "declined"]:
		GameState.set_flag(tag + "_decided")


## Rebuild tagged story receipts from existing statuses in old saves, including ended offers and paid deliveries.
static func reconcile_tags() -> void:
	for c in C().values():
		var tag := str(c.get("tag", ""))
		if tag != "":
			GameState.set_flag(tag + "_offered")
			if str(c.get("status", "")) in ["active", "delivered", "paid"]:
				_tag(c, "accepted")
			if str(c.get("status", "")) in ["delivered", "paid"]:
				_tag(c, "delivered")
			if str(c.get("status", "")) == "paid":
				_tag(c, "paid")
		if tag != "" and str(c.get("status", "")) in ["rejected", "withdrawn", "expired"] and not GameState.flag(tag + "_decided"):
			_tag(c, "declined")


static func seller_closed(c: Dictionary) -> bool:
	return GameState.data["entities"].get(c.get("seller", ""), {}).has("closed")


## End contracts before liquidation sells AR. Also repairs old saves, without posting money again.
static func close_for_entity(entity: String) -> void:
	for c in C().values():
		if str(c.get("seller", "")) != entity:
			continue
		var text := ""
		match str(c.get("status", "")):
			"offered":
				c["status"] = "withdrawn"
				_tag(c, "declined")
				text = I18n.t("The company closed. This unanswered offer was withdrawn.")
			"active":
				c["status"] = "terminated"
				var tag := str(c.get("tag", ""))
				if tag != "" and not GameState.flag(tag + "_decided"):
					_tag(c, "declined")
				text = I18n.t("The company closed. This undelivered contract was terminated with no additional penalty.")
			"delivered":
				c["status"] = "sold_to_collector"
				text = I18n.t("This invoice was sold to a collector as part of the company liquidation. The buyer will not pay the closed company again.")
		if text != "":
			if not c.has("history"):
				c["history"] = []
			c["history"].append({"t": Clock.now(), "by": entity, "text": text})
			EventBus.contract_changed.emit(str(c["id"]))
		# Even an already-terminal contract in an old save may still have a stale reminder.
		for event in GameState.data["schedule"].duplicate():
			if str(event["kind"]).begins_with("con.") and str(event["p"].get("id", "")) == str(c["id"]):
				Sim.cancel(str(event["kind"]), "id", c["id"])


static func reconcile_closed() -> void:
	for entity in GameState.data["entities"]:
		if GameState.data["entities"][entity].has("closed"):
			close_for_entity(str(entity))


static func contact_npc(c: Dictionary) -> String:
	return str(DataDB.companies.get(c["buyer"], {}).get("contact_npc", "harbor_point"))


static func can_trade() -> bool:
	return GameState.company_id() != ""


static func accept(cid: String) -> Dictionary:
	var c: Dictionary = C().get(cid, {})
	if c.is_empty() or c["status"] != "offered":
		return {"ok": false, "error": "This offer is no longer open."}
	if seller_closed(c):
		return {"ok": false, "error": I18n.t("This is a contract of a closed company.")}
	if not can_trade():
		return {"ok": false, "error": "They need an invoice from a registered company."}
	c["seller"] = GameState.business_entity()
	c["status"] = "active"
	c["accepted"] = Clock.now()
	c["due"] = Clock.now() + int(c["delivery_days"]) * Clock.DAY
	var best := Ecommerce.default_stock_location()
	for loc in Ecommerce.stock_locations():
		if Ecommerce.stock(loc, c["product"]) > Ecommerce.stock(best, c["product"]):
			best = loc
	c["location"] = best
	c["history"].append({"t": Clock.now(), "by": c["seller"], "text": "Accepted."})
	if float(c["upfront_rate"]) > 0.0:
		var up := snappedf(float(c["total"]) * float(c["upfront_rate"]), 0.01)
		c["upfront_paid"] = up
		Ledger.post(c["seller"], I18n.t("Deposit received from %s (%s)") % [GameState.entity_name(c["buyer"]), cid],
			[{"acct": "cash", "dr": up}, {"acct": "deferred_revenue", "cr": up}], {"type": "contract", "id": cid})
	Sim.schedule(int(c["due"]), "con.due", {"id": cid})
	_tag(c, "accepted")
	GameState.timeline(I18n.t("Signed contract %s with %s: %s.") % [cid, GameState.entity_name(c["buyer"]), Fmt.money(c["total"])], "business")
	EventBus.contract_changed.emit(cid)
	return {"ok": true}


static func reject(cid: String) -> void:
	var c: Dictionary = C().get(cid, {})
	if c.is_empty():
		return
	c["status"] = "rejected"
	c["history"].append({"t": Clock.now(), "by": GameState.business_entity(), "text": "Declined."})
	_tag(c, "declined")
	EventBus.contract_changed.emit(cid)


## Counter-offer. The counterparty evaluates with its data-driven negotiation profile.
static func counter(cid: String, unit_price: float, terms_days: int, upfront_rate: float) -> Dictionary:
	var c: Dictionary = C().get(cid, {})
	if c.is_empty() or c["status"] != "offered":
		return {"ok": false, "error": "This offer is no longer open."}
	if seller_closed(c):
		return {"ok": false, "error": I18n.t("This is a contract of a closed company.")}
	if not can_trade():
		return {"ok": false, "error": "Register your company first."}
	var neg: Dictionary = DataDB.companies.get(c["buyer"], {}).get("negotiation", {})
	c["history"].append({"t": Clock.now(), "by": GameState.business_entity(),
		"text": I18n.t("Counter: %s/unit, Net %d%s") % [Fmt.money(unit_price), terms_days, (I18n.t(", %d%% upfront") % int(upfront_rate * 100)) if upfront_rate > 0 else ""]})
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
		_tag(c, "declined")   # the offer is settled: a story step waiting on the decision moves on
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
		"text": I18n.t("Best we can do: %s/unit, Net %d%s.") % [Fmt.money(mid_price), mid_terms, (I18n.t(", %d%% upfront") % int(mid_up * 100)) if mid_up > 0 else ""]})
	EventBus.contract_changed.emit(cid)
	return {"ok": true, "result": "countered"}


static func can_deliver(cid: String) -> bool:
	return delivery_block(cid) == ""


## One reason shared by the button and the action, so a stale UI cannot use another company's stock.
static func delivery_block(cid: String) -> String:
	var c: Dictionary = C().get(cid, {})
	if not c.is_empty() and seller_closed(c):
		return I18n.t("This is a contract of a closed company.")
	if not c.is_empty() and str(c["seller"]) != GameState.company_id():
		return I18n.t("This contract belongs to another company.")
	if c.is_empty() or c["status"] != "active":
		return I18n.t("Nothing to deliver.")
	if stock_for(c) < int(c["qty"]):
		return I18n.t("You need %d in stock (have %d).") % [int(c["qty"]), stock_for(c)]
	return ""


## Units of the contract's product across every stock location (a big order can ship from two).
static func stock_for(c: Dictionary) -> int:
	var n := 0
	for loc in Ecommerce.stock_locations():
		n += Ecommerce.stock(loc, c["product"])
	return n


## Deliver the whole contract quantity from its stock location. Caller advances packing time.
static func deliver(cid: String) -> Dictionary:
	var why := delivery_block(cid)
	if why != "":
		return {"ok": false, "error": why}
	var c: Dictionary = C().get(cid, {})
	var qty := int(c["qty"])
	# pick from the signing location first, then anywhere else
	var locs: Array = [c["location"]]
	for l2 in Ecommerce.stock_locations():
		if not l2 in locs:
			locs.append(l2)
	var left := qty
	var cogs := 0.0
	for loc in locs:
		var take := mini(left, Ecommerce.stock(loc, c["product"]))
		if take <= 0:
			continue
		cogs += Ecommerce.avg_cost(loc, c["product"]) * take
		Ecommerce.inv(loc)[c["product"]]["qty"] = Ecommerce.stock(loc, c["product"]) - take
		left -= take
		if left <= 0:
			break
	cogs = snappedf(cogs, 0.01)
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
	Ledger.post(ent, I18n.t("Contract %s delivered to %s: %d × %s @ %s") % [cid, GameState.entity_name(c["buyer"]), qty,
		I18n.t(DataDB.product(c["product"])["name"]), Fmt.money(c["unit_price"])], lines, {"type": "contract", "id": cid})
	c["status"] = "delivered"
	c["delivered"] = Clock.now()
	c["receivable"] = snappedf(total - up - penalty, 0.01)
	c["pay_due"] = Clock.now() + int(c["payment_terms_days"]) * Clock.DAY
	c["history"].append({"t": Clock.now(), "by": ent, "text": I18n.t("Delivered%s. Invoice %s due in %d days.") % [I18n.t(" late (penalty %s)") % Fmt.money(penalty) if late else "", Fmt.money(c["receivable"]), int(c["payment_terms_days"])]})
	Sim.cancel("con.due", "id", cid)
	Sim.schedule(int(c["pay_due"]), "con.pay", {"id": cid})
	GameState.inc_stat("contracts_delivered")
	_tag(c, "delivered")
	GameState.inc_stat("revenue_total", total)
	EventBus.contract_changed.emit(cid)
	return {"ok": true, "receivable": c["receivable"]}


static func on_hour(_t: int, _h: int) -> void:
	pass


static func handle(kind: String, p: Dictionary) -> void:
	var c: Dictionary = C().get(p.get("id", ""), {})
	if c.is_empty():
		return
	if seller_closed(c):
		return   # a missed cleanup must never collect a receivable already sold in liquidation
	match kind:
		"con.expire":
			if c["status"] == "offered":
				c["status"] = "expired"
				c["history"].append({"t": Clock.now(), "by": c["buyer"], "text": "Offer expired."})
				_tag(c, "declined")
				EventBus.contract_changed.emit(c["id"])
		"con.due":
			if c["status"] == "active":
				GameState.add_message(contact_npc(c), I18n.t("Hey — the %d %s were due today. Still coming?") % [int(c["qty"]), I18n.t(DataDB.product(c["product"])["name"]) if I18n.is_zh() else I18n.t(DataDB.product(c["product"])["name"]).to_lower()])
				EventBus.notify.emit(I18n.t("Contract %s is overdue. Late penalty %s applies.") % [c["id"], Fmt.pct(c["penalty_rate"])], "bad", "contracts")
		"con.pay":
			if c["status"] == "delivered":
				var amt := float(c["receivable"])
				Ledger.post(c["seller"], I18n.t("Invoice paid by %s (%s)") % [GameState.entity_name(c["buyer"]), c["id"]],
					[{"acct": "cash", "dr": amt}, {"acct": "accounts_receivable", "cr": amt}], {"type": "contract", "id": c["id"]})
				c["status"] = "paid"
				c["history"].append({"t": Clock.now(), "by": c["buyer"], "text": I18n.t("Paid %s.") % Fmt.money(amt)})
				_tag(c, "paid")
				EventBus.notify.emit(I18n.t("%s paid invoice %s: %s") % [GameState.entity_name(c["buyer"]), c["id"], Fmt.money(amt)], "good", "cash")
				EventBus.contract_changed.emit(c["id"])


## Invoice discounting: the buyer pays a delivered invoice now, minus a discount (default 3%).
static func early_payment(cid: String, rate := 0.03) -> Dictionary:
	var c: Dictionary = C().get(cid, {})
	if not c.is_empty() and seller_closed(c):
		return {"ok": false, "error": I18n.t("This is a contract of a closed company.")}
	if c.is_empty() or c["status"] != "delivered":
		return {"ok": false, "error": "Only a delivered, unpaid invoice can be paid early."}
	var amt := float(c["receivable"])
	var disc := snappedf(amt * rate, 0.01)
	Ledger.post(c["seller"], I18n.t("Early payment from %s (%s), %s discount") % [GameState.entity_name(c["buyer"]), cid, Fmt.pct(rate)],
		[{"acct": "cash", "dr": amt - disc}, {"acct": "exp:bank_fees", "dr": disc}, {"acct": "accounts_receivable", "cr": amt}], {"type": "contract", "id": cid})
	c["status"] = "paid"
	c["history"].append({"t": Clock.now(), "by": c["buyer"], "text": I18n.t("Paid early: %s (discount %s).") % [Fmt.money(amt - disc), Fmt.money(disc)]})
	Sim.cancel("con.pay", "id", cid)
	GameState.set_flag("early_payment_agreed")
	_tag(c, "paid")
	EventBus.contract_changed.emit(cid)
	return {"ok": true, "cash": amt - disc, "discount": disc}


## What to order to cover a contract: missing units rounded up to the cheapest supplier's MOQ,
## delivered to the stock location with the most free space. {} if nothing is missing.
static func restock_plan(c: Dictionary) -> Dictionary:
	var short := int(c["qty"]) - stock_for(c) - Ecommerce.incoming_units_of(c["product"])
	if short <= 0:
		return {}
	var best := {}
	for sid in DataDB.suppliers:
		var o := Ecommerce.offer(sid, c["product"])
		if o.is_empty() or not World.supplier_available(sid):
			continue
		var uc := Ecommerce.unit_cost(sid, c["product"])
		if best.is_empty() or uc < float(best["uc"]):
			best = {"supplier": sid, "uc": uc, "moq": int(o["moq"])}
	if best.is_empty():
		return {"error": "No supplier carries this product."}
	var qty := int(ceil(float(short) / best["moq"])) * int(best["moq"])
	var loc := ""
	var room := -1
	for l in Ecommerce.stock_locations():
		var free := Ecommerce.location_capacity(l) - Ecommerce.total_units_at(l) - Ecommerce.incoming_units(l)
		if free > room:
			room = free
			loc = l
	if room < qty:
		return {"error": I18n.t("Not enough storage for %d more units (most free space: %d). Lease Suite 2B for 1,500 units.") % [qty, maxi(0, room)]}
	return {"supplier": best["supplier"], "qty": qty, "location": loc, "cost": snappedf(float(best["uc"]) * qty, 0.01)}


static func by_tag(tag: String) -> Dictionary:
	for c in C().values():
		if c.get("tag", "") == tag:
			return c
	return {}


static func open_list() -> Array:
	var out: Array = C().values()
	out.sort_custom(func(a, b): return int(a["offered"]) > int(b["offered"]))
	return out
