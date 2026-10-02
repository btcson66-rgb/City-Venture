class_name Ecommerce
extends RefCounted
## Ecommerce business module (Vertical Slice industry).
##
## Supplier offer ─buy ≥ MOQ─▶ PurchaseOrder ─lead─▶ Inventory@location
## Inventory ─photo+listing─▶ Listing(price, ads) ─hourly demand─▶ Order(placed)
## placed ─pack@location─▶ packed ─courier | PostPoint─▶ shipped ─transit─▶ delivered
## delivered: revenue + COGS + platform fee → marketplace balance (NOT cash)
## Monday 09:00 payout: marketplace balance → cash.   Returns / reviews follow delivery.

const OPEN_STATUSES := ["placed", "packed", "awaiting_pickup", "carried", "shipped", "customs_hold"]


static func E() -> Dictionary:
	return GameState.data["ecommerce"]


static func mk() -> Dictionary:
	return DataDB.marketplace()


# ================================================================ suppliers / purchasing
static func offers_for(supplier_id: String) -> Array:
	return DataDB.supplier(supplier_id).get("offers", [])


static func offer(supplier_id: String, product_id: String) -> Dictionary:
	for o in offers_for(supplier_id):
		if o["product"] == product_id:
			return o
	return {}


static func cost_multiplier(supplier_id: String, product_id: String) -> float:
	var m := 1.0
	var t := Clock.now()
	for mod in E()["supplier_mods"]:
		if int(mod.get("until", 0)) > t and mod.get("from", 0) <= t and (mod["supplier"] == supplier_id or mod["supplier"] == "*") \
				and (mod.get("product", "*") == "*" or mod["product"] == product_id):
			m *= float(mod["mult"])
	return m


static func unit_cost(supplier_id: String, product_id: String) -> float:
	var o := offer(supplier_id, product_id)
	if o.is_empty():
		return 0.0
	return snappedf(float(o["unit_cost"]) * cost_multiplier(supplier_id, product_id) * World.cost_mult(supplier_id), 0.01)


static func can_use_net_terms(supplier_id: String) -> bool:
	var s := DataDB.supplier(supplier_id)
	if not s.has("net_terms_for_companies"):
		return false
	return GameState.company_id() != "" and GameState.flag("business_account_opened")


## Place a purchase order. Returns {ok, error?, po_id?, total?}.
## settlement: how an import is paid from the Clearing Crisis (Year 5) on: international_wire (default),
## letter_of_credit, stablecoin_settlement or (Year 6+) escrow. Ignored for local suppliers and before Year 5.
## Year 8: importing needs a licence, and a large payment goes through a KYC check (fee, one more day).
static func buy(supplier_id: String, product_id: String, qty: int, location := "", use_terms := false, lead_override := -1, cost_mult := 1.0, settlement := "") -> Dictionary:
	var o := offer(supplier_id, product_id)
	if o.is_empty():
		return {"ok": false, "error": "That supplier doesn't sell this."}
	if not World.supplier_available(supplier_id):
		return {"ok": false, "error": "That supplier isn't open to you yet."}
	var no_licence := Compliance.import_block(supplier_id)
	if no_licence != "":
		return {"ok": false, "error": no_licence}
	if qty < int(o["moq"]):
		return {"ok": false, "error": I18n.t("Minimum order is %d units.") % int(o["moq"])}
	if location == "":
		location = default_stock_location()
	var full := space_block(location, qty)
	if full != "":
		return {"ok": false, "error": full}
	var entity := GameState.business_entity()
	var uc := snappedf(unit_cost(supplier_id, product_id) * cost_mult, 0.01)
	var total := snappedf(uc * qty, 0.01)
	var terms := use_terms and can_use_net_terms(supplier_id)
	var settle := ""
	var settle_fee := 0.0
	var kyc := {}
	if needs_settlement(supplier_id) and not terms:
		settle = settlement if settlement != "" else "international_wire"
		var why := settlement_block(settle)
		if why != "":
			return {"ok": false, "error": why}
		settle_fee = settlement_fee(settle, total)
		kyc = Compliance.kyc(total)
	var kyc_fee := float(kyc.get("fee", 0.0))
	if not terms and Ledger.cash(entity) < total + settle_fee + kyc_fee:
		return {"ok": false, "error": I18n.t("Not enough cash. You need %s.") % Fmt.money(total + settle_fee + kyc_fee)}
	var e := E()
	e["counters"]["po"] = int(e["counters"]["po"]) + 1
	var po_id := "PO-%d" % int(e["counters"]["po"])
	var lead := int(ceil(float(o["lead_days"]) * World.lead_mult(supplier_id))) if lead_override < 0 else lead_override
	var eta := Clock.at_day_time(lead, 10 * 60 + GameState.randi_range(0, 360))
	if lead == 0:
		eta = Clock.now() + 180
	var po := {"id": po_id, "supplier": supplier_id, "product": product_id, "qty": qty, "unit_cost": uc, "total": total,
		"placed": Clock.now(), "eta": eta, "location": location, "status": "in_transit", "entity": entity,
		"terms": "net" if terms else "prepay", "defect_rate": float(o.get("defect_rate", 0.0)), "year": World.year()}
	e["purchase_orders"][po_id] = po
	var sup_name: String = I18n.t(DataDB.supplier(supplier_id).get("name", supplier_id))
	var escrow := settle != "" and Rails.is_escrow(settle)
	if escrow:
		# the money is locked in the contract, not with the supplier: it's paid out when the goods arrive
		po["escrow"] = "held"
		Ledger.post(entity, I18n.t("%s: %d × %s (into escrow)") % [sup_name, qty, I18n.t(DataDB.product(product_id)["name"])],
			[{"acct": "escrow_held", "dr": total}, {"acct": "cash", "cr": total}], {"type": "po", "id": po_id})
	elif terms:
		var days := int(DataDB.supplier(supplier_id)["net_terms_for_companies"]["days"])
		po["due"] = Clock.now() + days * Clock.DAY
		Ledger.post(entity, I18n.t("%s: %d × %s on Net %d") % [sup_name, qty, I18n.t(DataDB.product(product_id)["name"]), days],
			[{"acct": "inventory_in_transit", "dr": total}, {"acct": "accounts_payable", "cr": total}], {"type": "po", "id": po_id})
		Sim.schedule(int(po["due"]), "eco.ap_due", {"po": po_id})
	else:
		Ledger.post(entity, I18n.t("%s: %d × %s (prepaid)") % [sup_name, qty, I18n.t(DataDB.product(product_id)["name"])],
			[{"acct": "inventory_in_transit", "dr": total}, {"acct": "cash", "cr": total}], {"type": "po", "id": po_id})
	if settle != "":
		# the money has left, but the supplier won't ship until it lands on their side
		var clears := Clock.now() + settlement_hours(settle) * 60
		po["status"] = "awaiting_payment"
		po["settlement"] = {"method": settle, "fee": settle_fee, "clears": clears}
		if not kyc.is_empty():
			# Year 8: a large payment goes through the KYC check first, then over the rail
			var kyc_until := Clock.now() + int(kyc["hours"]) * 60
			clears += int(kyc["hours"]) * 60
			po["settlement"]["clears"] = clears
			po["settlement"]["kyc_until"] = kyc_until
			po["settlement"]["kyc"] = true
			Ledger.expense(entity, "compliance", kyc_fee, I18n.t("KYC check — %s") % po_id, {"type": "po", "id": po_id})
			GameState.inc_stat("kyc_checks")
		eta = clears + (eta - Clock.now())
		po["eta"] = eta
		if settle_fee > 0.0:
			Ledger.expense(entity, "bank_fees", settle_fee, I18n.t("%s — %s") % [I18n.t(str(settlement_def(settle)["name"])), po_id], {"type": "po", "id": po_id})
		Sim.schedule(clears, "eco.po_cleared", {"po": po_id})
		GameState.inc_stat("import_orders")
		GameState.inc_stat("import_orders_y%d" % World.year())
		if escrow:
			GameState.inc_stat("escrow_orders")
	Sim.schedule(eta, "eco.po_arrive", {"po": po_id})
	GameState.inc_stat("purchase_orders")
	if int(GameState.stat("purchase_orders")) == 1:
		GameState.timeline(I18n.t("First inventory order: %d × %s from %s.") % [qty, I18n.t(DataDB.product(product_id)["name"]), sup_name], "business")
	EventBus.po_placed.emit(po_id)
	if Tutorial.first_venture_active() and int(GameState.stat("purchase_orders")) == 1:
		# a new seller's first order is dropped off the same afternoon, so the guided first venture never stalls
		po["eta"] = Clock.now()
		_h_po_arrive({"po": po_id})
	return {"ok": true, "po_id": po_id, "total": total, "eta": eta}


static func _h_po_arrive(p: Dictionary) -> void:
	var po: Dictionary = E()["purchase_orders"].get(p["po"], {})
	if po.is_empty() or po["status"] != "in_transit":
		return
	po["status"] = "delivered"
	po["arrived"] = Clock.now()
	if World.is_import(po["supplier"]):
		GameState.inc_stat("import_received")
		GameState.inc_stat("import_received_y%d" % int(po.get("year", 0)))
	_add_stock(po["location"], po["product"], int(po["qty"]), float(po["unit_cost"]), float(po["defect_rate"]))
	# an escrow contract pays the supplier out of escrow now; every other order was already paid or is on terms
	Ledger.post(po["entity"], I18n.t("Stock received: %s") % po["id"],
		[{"acct": "inventory", "dr": po["total"]}, {"acct": Rails.arrival_account(po), "cr": po["total"]}], {"type": "po", "id": po["id"]})
	Rails.on_arrived(po)
	GameState.inc_stat("stock_received")
	var pname: String = I18n.t(DataDB.product(po["product"])["name"])
	EventBus.notify.emit(I18n.t("Delivered: %d × %s → %s") % [int(po["qty"]), pname, location_name(po["location"])], "good", "parcel")
	var contact: String = DataDB.supplier(po["supplier"]).get("contact_npc", "")
	if contact != "":
		GameState.add_message(contact, I18n.t("Dropped %d %s at %s. Don't let them sit around.") % [int(po["qty"]), pname if I18n.is_zh() else pname.to_lower(), location_name(po["location"])])
	EventBus.po_arrived.emit(po["id"])


# ================================================================ cross-border settlement (Year 5)
static func needs_settlement(supplier_id: String) -> bool:
	return World.cross_border_delay() and World.is_import(supplier_id)


static func settlement_def(id: String) -> Dictionary:
	for m in DataDB.economy.get("settlement_methods", {}).get("methods", []):
		if m["id"] == id:
			return m
	return {}


## The cross-border rails on offer in this era (digital dollars from Year 5, escrow from Year 6).
static func settlement_options() -> Array:
	var out: Array = []
	for m in DataDB.economy.get("settlement_methods", {}).get("methods", []):
		if bool(m.get("cross_border", false)) and settlement_open(str(m["id"])):
			out.append(m)
	return out


static func settlement_open(id: String) -> bool:
	var m := settlement_def(id)
	return not m.is_empty() and m.get("status", "") == "active" and World.year() >= int(m.get("from_year", 1))


## Why a rail can't be used right now ("" = it can).
static func settlement_block(id: String) -> String:
	if not settlement_open(id):
		return "That payment method isn't available."
	var frozen := Rails.freeze_block(id)
	if frozen != "":
		return frozen
	var m := settlement_def(id)
	var req := str(m.get("requires", ""))
	if req != "" and not Cond.eval(req):
		return I18n.t("This %s.") % I18n.t(str(m.get("requires_text", "has a requirement you don't meet yet")))
	return ""


static func settlement_fee(id: String, amount: float) -> float:
	var m := settlement_def(id)
	var fee := float(m.get("fixed_fee", 0.0)) + amount * float(m.get("fee_rate", 0.0))
	return snappedf(maxf(fee, float(m.get("fee_min", 0.0))) * Rails.fee_mult(id), 0.01)


## Hours a payment on this rail takes to land, [fastest, slowest]. Wires speed up once the correspondent banks catch up.
static func settlement_range(id: String) -> Array:
	var h: Array = settlement_def(id).get("clear_hours", [24, 24])
	var mult := World.wire_clear_mult() if id == "international_wire" else 1.0
	return [int(round(float(h[0]) * mult)), int(round(float(h[1]) * mult))]


static func settlement_hours(id: String) -> int:
	var r := settlement_range(id)
	return GameState.randi_range(int(r[0]), int(r[1]))


## Swap a payment that's stuck on the wire for a faster rail: pay that rail's fee, the supplier ships sooner.
static func switch_settlement(po_id: String, method: String) -> Dictionary:
	var po: Dictionary = E()["purchase_orders"].get(po_id, {})
	if po.is_empty() or po["status"] != "awaiting_payment":
		return {"ok": false, "error": "That payment already went through."}
	if Rails.is_frozen_po(po):
		return Rails.reroute(po_id, method)   # stuck on the bridge: pay again by another rail
	var why := settlement_block(method)
	if why != "":
		return {"ok": false, "error": why}
	var st: Dictionary = po["settlement"]
	var clears := maxi(Clock.now(), int(st.get("kyc_until", 0))) + settlement_hours(method) * 60   # a KYC check still has to finish first
	if clears >= int(st["clears"]):
		return {"ok": false, "error": "That wouldn't be any faster."}
	var fee := settlement_fee(method, float(po["total"]))
	if Ledger.cash(po["entity"]) < fee:
		return {"ok": false, "error": I18n.t("Not enough cash. You need %s.") % Fmt.money(fee)}
	if fee > 0.0:
		Ledger.expense(po["entity"], "bank_fees", fee, I18n.t("%s — %s") % [I18n.t(str(settlement_def(method)["name"])), po_id], {"type": "po", "id": po_id})
	# the money moves between "held in escrow" and "paid to the supplier" with the rail
	var was_escrow := str(po.get("escrow", "")) == "held"
	var to_escrow := Rails.is_escrow(method)
	if to_escrow != was_escrow:
		var amt := float(po["total"])
		Ledger.post(str(po["entity"]), (I18n.t("%s: money moved into escrow") if to_escrow else I18n.t("%s: money moved out of escrow")) % po_id,
			[{"acct": "escrow_held" if to_escrow else "inventory_in_transit", "dr": amt}, {"acct": "inventory_in_transit" if to_escrow else "escrow_held", "cr": amt}],
			{"type": "po", "id": po_id})
		po["escrow"] = "held" if to_escrow else "switched"
	var transit := int(po["eta"]) - int(st["clears"])
	st["method"] = method
	st["fee"] = float(st["fee"]) + fee
	st["clears"] = clears
	po["eta"] = clears + transit
	Sim.schedule(clears, "eco.po_cleared", {"po": po_id})
	Sim.schedule(int(po["eta"]), "eco.po_arrive", {"po": po_id})
	return {"ok": true, "clears": clears, "fee": fee}


static func _h_po_cleared(p: Dictionary) -> void:
	var po: Dictionary = E()["purchase_orders"].get(p["po"], {})
	if po.is_empty() or po["status"] != "awaiting_payment" or Clock.now() < int(po["settlement"]["clears"]) or Rails.is_frozen_po(po):
		return   # already cleared, or this is the old (slower) rail's reminder, or the money is stuck on the bridge
	po["status"] = "in_transit"
	GameState.inc_stat("import_cleared")
	var st: Dictionary = po["settlement"]
	Rails.note_settled(str(st["method"]))
	if bool(st.get("kyc", false)):
		GameState.inc_stat("kyc_cleared")
	var sup_name := I18n.t(DataDB.supplier(po["supplier"])["name"])
	if str(po.get("escrow", "")) == "held":
		EventBus.notify.emit(I18n.t("Escrow funded: %s ships %s (arrives %s). The money is released when it lands.") % [sup_name, po["id"], Clock.fmt_short(int(po["eta"]))], "good", "bank")
	else:
		EventBus.notify.emit(I18n.t("Payment landed: %s ships %s (arrives %s).") % [sup_name, po["id"], Clock.fmt_short(int(po["eta"]))], "good", "bank")


static func _h_ap_due(p: Dictionary) -> void:
	var po: Dictionary = E()["purchase_orders"].get(p["po"], {})
	if po.is_empty() or po.get("paid", false):
		return
	po["paid"] = true
	if po["status"] == "cancelled" and GameState.data["entities"].get(po["entity"], {}).has("closed"):
		return   # liquidation already settled or wrote off the remaining cancellation fee
	var due := float(po.get("payable_remaining", po["total"]))
	if due <= 0.0:
		return
	Ledger.post(po["entity"], I18n.t("Supplier invoice paid: %s") % po["id"],
		[{"acct": "accounts_payable", "dr": due}, {"acct": "cash", "cr": due}], {"type": "ap", "id": po["id"]})
	EventBus.notify.emit(I18n.t("Paid supplier invoice %s: %s") % [po["id"], Fmt.money(due)], "info", "bank")


# ================================================================ purchase cancellations / supplier returns
## Supplier overrides sit over the tunable defaults; imports have no delivered-goods return window.
static func return_policy(supplier_id: String) -> Dictionary:
	var policy: Dictionary = DataDB.economy.get("returns", {}).duplicate()
	if World.is_import(supplier_id):
		policy["return_window_days"] = 0
	policy.merge(DataDB.supplier(supplier_id).get("returns", {}), true)
	return policy


static func purchase_block(po: Dictionary) -> String:
	if po.is_empty():
		return I18n.t("That purchase order no longer exists.")
	if GameState.data["entities"].get(po["entity"], {}).has("closed"):
		return I18n.t("This purchase belongs to a closed company.")
	if str(po["entity"]) != GameState.business_entity():
		return I18n.t("This purchase belongs to another business.")
	return ""


static func cancel_block(po_id: String) -> String:
	var po: Dictionary = E()["purchase_orders"].get(po_id, {})
	var why := purchase_block(po)
	if why != "":
		return why
	if not str(po["status"]) in ["in_transit", "awaiting_payment"]:
		return I18n.t("Only a purchase still on the way can be cancelled.")
	if Rails.is_frozen_po(po):
		return I18n.t("Payment is frozen. Wait for the bridge to reopen before cancelling.")
	var policy := return_policy(str(po["supplier"]))
	if Clock.now() - int(po["placed"]) >= int(float(policy["cancel_window_hours"]) * 60):
		if int(policy["return_window_days"]) <= 0:
			return I18n.t("Cancellation window ended.") + " " + I18n.t("This supplier does not accept returns after delivery.")
		return I18n.t("Cancellation window ended. Return eligible stock within %d days of arrival.") % int(policy["return_window_days"])
	return ""


static func cancel_quote(po_id: String) -> Dictionary:
	var po: Dictionary = E()["purchase_orders"].get(po_id, {})
	if po.is_empty():
		return {}
	var pending := str(po["status"]) == "awaiting_payment"
	var fee := 0.0 if pending else snappedf(float(po["total"]) * float(return_policy(str(po["supplier"]))["cancel_fee_rate"]), 0.01)
	return {"refund": snappedf(float(po["total"]) - fee, 0.01), "fee": fee,
		"unpaid": po["terms"] == "net" and not bool(po.get("paid", false)), "pending": pending}


static func _purchase_message(po: Dictionary, text: String) -> void:
	var contact := str(DataDB.supplier(str(po["supplier"])).get("contact_npc", ""))
	if contact != "":
		GameState.add_message(contact, text)
	GameState.timeline(text, "business")


## Reduce an unpaid invoice; paid orders return cash. Settlement fees already charged stay on the books.
static func cancel_purchase(po_id: String) -> Dictionary:
	var why := cancel_block(po_id)
	if why != "":
		return {"ok": false, "error": why}
	var po: Dictionary = E()["purchase_orders"][po_id]
	var quote := cancel_quote(po_id)
	var refund := float(quote["refund"])
	var fee := float(quote["fee"])
	Ledger.post(str(po["entity"]), I18n.t("Purchase cancelled: %s") % po_id,
		[{"acct": "accounts_payable" if quote["unpaid"] else "cash", "dr": refund},
		{"acct": "exp:restocking", "dr": fee}, {"acct": Rails.arrival_account(po), "cr": po["total"]}], {"type": "po", "id": po_id})
	po["status"] = "cancelled"
	po["cancelled"] = Clock.now()
	po["cancel_fee"] = fee
	if quote["unpaid"]:
		po["payable_remaining"] = fee
		if fee == 0.0:
			Sim.cancel("eco.ap_due", "po", po_id)
			po["paid"] = true
	if str(po.get("escrow", "")) == "held":
		po["escrow"] = "refunded"
	Sim.cancel("eco.po_arrive", "po", po_id)
	Sim.cancel("eco.po_cleared", "po", po_id)
	GameState.inc_stat("purchase_orders_cancelled")
	_purchase_message(po, I18n.t("%s cancelled: %s refunded or removed from your unpaid invoice; fee %s. Settlement fees are not refundable.") % [po_id, Fmt.money(refund), Fmt.money(fee)])
	return {"ok": true, "refund": refund, "fee": fee}


## Count cumulative returns as well as stock reserved for customer orders and active contracts.
static func return_max(po_id: String) -> int:
	var po: Dictionary = E()["purchase_orders"].get(po_id, {})
	if po.is_empty():
		return 0
	return maxi(0, mini(int(po["qty"]) - int(po.get("returned_qty", 0)), available(str(po["location"]), str(po["product"]))))


static func return_block(po_id: String) -> String:
	var po: Dictionary = E()["purchase_orders"].get(po_id, {})
	var why := purchase_block(po)
	if why != "":
		return why
	if str(po["status"]) != "delivered":
		return I18n.t("Only delivered purchases can be returned.")
	var days := int(return_policy(str(po["supplier"]))["return_window_days"])
	if days <= 0:
		return I18n.t("This supplier does not accept returns after delivery.")
	if Clock.now() - int(po.get("arrived", po["eta"])) >= days * Clock.DAY:
		return I18n.t("The %d-day return window has ended.") % days
	if return_max(po_id) <= 0:
		return I18n.t("No returnable stock here: units were sold, reserved, moved, or already returned.")
	return ""


static func return_quote(po_id: String, qty: int) -> Dictionary:
	var po: Dictionary = E()["purchase_orders"].get(po_id, {})
	if po.is_empty():
		return {}
	var policy := return_policy(str(po["supplier"]))
	var value := snappedf(qty * float(po["unit_cost"]), 0.01)
	var fee := snappedf(value * float(policy["restocking_fee_rate"]), 0.01)
	return {"refund": snappedf(value - fee, 0.01), "fee": fee,
		"shipping": snappedf(qty * float(policy["return_ship_per_unit"]) * World.shipping_index(), 0.01),
		"due": Clock.now() + int(policy["return_days"]) * Clock.DAY}


## Remove stock at its current average cost; the supplier's original PO price determines the receivable.
static func return_purchase(po_id: String, qty: int) -> Dictionary:
	var why := return_block(po_id)
	if why != "":
		return {"ok": false, "error": why}
	if qty <= 0 or qty > return_max(po_id):
		return {"ok": false, "error": I18n.t("Choose between 1 and %d returnable units.") % return_max(po_id)}
	var po: Dictionary = E()["purchase_orders"][po_id]
	var quote := return_quote(po_id, qty)
	var entity := str(po["entity"])
	if Ledger.cash(entity) < float(quote["shipping"]):
		return {"ok": false, "error": I18n.t("Not enough cash for return shipping: %s.") % Fmt.money(float(quote["shipping"]))}
	var value := snappedf(qty * avg_cost(str(po["location"]), str(po["product"])), 0.01)
	var refund := float(quote["refund"])
	var gap := snappedf(value - refund, 0.01)
	var lines: Array = [{"acct": "accounts_receivable", "dr": refund}, {"acct": "inventory", "cr": value}]
	lines.append({"acct": "exp:restocking", "dr": gap} if gap >= 0 else {"acct": "other_income", "cr": -gap})
	Ledger.post(entity, I18n.t("Stock returned to supplier: %s (%d units)") % [po_id, qty], lines, {"type": "po_return", "id": po_id})
	Ledger.expense(entity, "shipping", float(quote["shipping"]), I18n.t("Return shipping: %s") % po_id, {"type": "po_return", "id": po_id})
	inv(str(po["location"]))[po["product"]]["qty"] = stock(str(po["location"]), str(po["product"])) - qty
	po["returned_qty"] = int(po.get("returned_qty", 0)) + qty
	if not po.has("returns"):
		po["returns"] = []
	var record := {"qty": qty, "refund": refund, "fee": quote["fee"], "shipping": quote["shipping"],
		"t": Clock.now(), "due": quote["due"], "status": "in_transit", "entity": entity}
	po["returns"].append(record)
	Sim.schedule(int(record["due"]), "eco.return_refund", {"po": po_id, "return": po["returns"].size() - 1})
	_purchase_message(po, I18n.t("%s: returning %d units. Refund %s on %s; restocking fee %s, shipping %s.") % [po_id, qty, Fmt.money(refund), Clock.fmt_short(int(record["due"])), Fmt.money(float(quote["fee"])), Fmt.money(float(quote["shipping"]))])
	return {"ok": true, "refund": refund, "due": record["due"]}


static func _h_return_refund(p: Dictionary) -> void:
	var po: Dictionary = E()["purchase_orders"].get(p.get("po", ""), {})
	var records: Array = po.get("returns", [])
	var index := int(p.get("return", -1))
	if index < 0 or index >= records.size():
		return
	var r: Dictionary = records[index]
	if r["status"] == "in_transit" and GameState.data["entities"].get(r["entity"], {}).has("closed"):
		r["status"] = "sold_to_collector"   # liquidation already sold this receivable; never collect it a second time
		return
	if r["status"] != "in_transit" or Clock.now() < int(r["due"]):
		return
	r["status"] = "refunded"
	Ledger.post(str(r["entity"]), I18n.t("Supplier return refund: %s") % po["id"],
		[{"acct": "cash", "dr": r["refund"]}, {"acct": "accounts_receivable", "cr": r["refund"]}], {"type": "po_return", "id": po["id"]})
	_purchase_message(po, I18n.t("%s: received the returned stock. Refund %s has reached your account.") % [po["id"], Fmt.money(float(r["refund"]))])


# ================================================================ inventory
static func default_stock_location() -> String:
	if GameState.data["living"]["leases"].has("suite_2b"):
		return "suite_2b"
	return "riverside_studio"


static func location_name(loc: String) -> String:
	return I18n.t(DataDB.properties.get(loc, {}).get("name", loc))


static func location_capacity(loc: String) -> int:
	return int(DataDB.properties.get(loc, {}).get("capacity", {}).get("inventory_units", 0))


## Why `qty` more units won't fit at `location` ("" when they fit), naming the stock location with the most room.
static func space_block(location: String, qty: int) -> String:
	var used := total_units_at(location) + incoming_units(location)
	var cap := location_capacity(location)
	if used + qty <= cap:
		return ""
	var msg := I18n.t("%s is full: %d of %d units, counting stock on the way.") % [location_name(location), used, cap]
	var best := ""
	var best_room := qty - 1
	for l in stock_locations():
		var room := location_capacity(l) - total_units_at(l) - incoming_units(l)
		if l != location and room > best_room:
			best = l
			best_room = room
	if best != "":
		return msg + " " + I18n.t("%s has room: choose it under \"Deliver to\" in Operations.") % location_name(best)
	return msg + " " + I18n.t("Sell some stock first, or lease more space.")


static func stock_locations() -> Array:
	var out: Array = ["riverside_studio"]
	if GameState.data["living"]["leases"].has("suite_2b"):
		out.append("suite_2b")
	# any leased warehouse holds stock too (Pier 7, Harbor)
	for pid in GameState.data["living"]["leases"]:
		if str(DataDB.properties.get(pid, {}).get("kind", "")) == "warehouse":
			out.append(pid)
	return out


static func inv(loc: String) -> Dictionary:
	var i: Dictionary = E()["inventory"]
	if not i.has(loc):
		i[loc] = {}
	return i[loc]


static func _add_stock(loc: String, product_id: String, qty: int, cost: float, defect_rate: float) -> void:
	var l := inv(loc)
	var cur: Dictionary = l.get(product_id, {"qty": 0, "avg_cost": 0.0, "defect_rate": 0.0})
	var q0 := int(cur["qty"])
	var q1 := q0 + qty
	if q1 > 0:
		cur["avg_cost"] = snappedf((float(cur["avg_cost"]) * q0 + cost * qty) / q1, 0.0001)
		cur["defect_rate"] = (float(cur["defect_rate"]) * q0 + defect_rate * qty) / q1
	cur["qty"] = q1
	l[product_id] = cur


static func stock(loc: String, product_id: String) -> int:
	return int(inv(loc).get(product_id, {}).get("qty", 0))


static func avg_cost(loc: String, product_id: String) -> float:
	return float(inv(loc).get(product_id, {}).get("avg_cost", 0.0))


static func reserved(loc: String, product_id: String) -> int:
	var n := 0
	for o in E()["orders"].values():
		if o["status"] == "placed" and o["location"] == loc and o["product"] == product_id:
			n += int(o["qty"])
	for c in GameState.data["contracts"].values():
		if c.get("status", "") == "active" and c.get("location", "") == loc and c.get("product", "") == product_id:
			n += int(c["qty"])
	return n


static func available(loc: String, product_id: String) -> int:
	return stock(loc, product_id) - reserved(loc, product_id)


static func available_anywhere(product_id: String) -> int:
	var n := 0
	for loc in stock_locations():
		n += maxi(0, available(loc, product_id))
	return n


static func best_location(product_id: String) -> String:
	var best := ""
	var best_n := 0
	for loc in stock_locations():
		var a := available(loc, product_id)
		if a > best_n:
			best_n = a
			best = loc
	return best


static func total_units() -> int:
	var n := 0
	for loc in E()["inventory"]:
		for p in E()["inventory"][loc]:
			n += int(E()["inventory"][loc][p]["qty"])
	return n


static func total_units_at(loc: String) -> int:
	var n := 0
	for p in inv(loc):
		n += int(inv(loc)[p]["qty"])
	return n


static func incoming_units(loc := "") -> int:
	var n := 0
	for po in E()["purchase_orders"].values():
		if po["status"] in ["in_transit", "awaiting_payment"] and (loc == "" or po["location"] == loc):
			n += int(po["qty"])
	return n


static func incoming_units_of(product_id: String) -> int:
	var n := 0
	for po in E()["purchase_orders"].values():
		if po["status"] in ["in_transit", "awaiting_payment"] and po["product"] == product_id:
			n += int(po["qty"])
	return n


static func inventory_value(entity: String) -> float:
	return Ledger.balance(entity, "inventory")


# ================================================================ listings
static func listing_for(product_id: String) -> Dictionary:
	for l in E()["listings"].values():
		if l["product"] == product_id:
			return l
	return {}


## Create (or re-shoot) a listing. photo = "self" | "studio". Time cost is applied by the caller (UI) via Clock.advance.
## photo_q: how good your own photos came out (PhotoShootGame, 0..1); -1 = not shot in the minigame.
static func create_listing(product_id: String, price: float, photo: String, photo_q := -1.0) -> Dictionary:
	if total_units_at_any(product_id) <= 0:
		return {"ok": false, "error": "You need the product in hand to photograph it."}
	var p := DataDB.product(product_id)
	price = clampf(price, float(p["price_min"]), float(p["price_max"]))
	var entity := GameState.business_entity()
	if photo == "studio":
		var cost := float(mk().get("studio_photo_cost", 120))
		if Ledger.cash(entity) < cost:
			return {"ok": false, "error": I18n.t("Studio photos cost %s.") % Fmt.money(cost)}
		Ledger.expense(entity, "photography", cost, I18n.t("Studio Lumen product photos: %s") % I18n.t(p["name"]), {"type": "photo", "id": product_id})
	var l := listing_for(product_id)
	if l.is_empty():
		E()["counters"]["listing"] = int(E()["counters"]["listing"]) + 1
		var lid := "L%d" % int(E()["counters"]["listing"])
		l = {"id": lid, "product": product_id, "price": price, "photo": photo, "ad_budget": 0.0, "active": true,
			"created": Clock.now(), "views": 0, "orders": 0, "rating_sum": 0.0, "rating_n": 0, "paused_reason": ""}
		if photo == "self" and photo_q >= 0.0:
			l["photo_q"] = photo_q
		E()["listings"][lid] = l
		GameState.inc_stat("listings_created")
		if int(GameState.stat("listings_created")) == 1:
			GameState.timeline(I18n.t("First ShopLane listing: %s at %s.") % [I18n.t(p["name"]), Fmt.money(price)], "business")
	else:
		l["price"] = price
		if photo == "studio" or l["photo"] != "studio":
			l["photo"] = photo
			if photo == "self" and photo_q >= 0.0:
				l["photo_q"] = photo_q
		l["active"] = true
		l["paused_reason"] = ""
	EventBus.listing_changed.emit(l["id"])
	return {"ok": true, "listing_id": l["id"]}


static func total_units_at_any(product_id: String) -> int:
	var n := 0
	for loc in E()["inventory"]:
		n += int(E()["inventory"][loc].get(product_id, {}).get("qty", 0))
	return n


static func set_price(lid: String, price: float) -> void:
	var l: Dictionary = E()["listings"].get(lid, {})
	if l.is_empty():
		return
	var p := DataDB.product(l["product"])
	var before := float(l["price"])
	l["price"] = snappedf(clampf(price, float(p["price_min"]), float(p["price_max"])), 0.01)
	if float(l["price"]) > before + 0.001:
		GameState.set_flag("repriced")   # Chapter 7 asks you to pass rising costs on
	EventBus.listing_changed.emit(lid)


static func set_ad_budget(lid: String, budget: float) -> void:
	var l: Dictionary = E()["listings"].get(lid, {})
	if l.is_empty():
		return
	l["ad_budget"] = clampf(snappedf(budget, 1.0), 0.0, 200.0)
	EventBus.listing_changed.emit(lid)


static func set_active(lid: String, active: bool) -> void:
	var l: Dictionary = E()["listings"].get(lid, {})
	if l.is_empty():
		return
	if active and is_capped():
		EventBus.notify.emit("ShopLane: personal seller limit reached this month.", "warn", "warning")
		return
	l["active"] = active
	l["paused_reason"] = "" if active else "manual"
	EventBus.listing_changed.emit(lid)


static func rating(l: Dictionary) -> float:
	if int(l.get("rating_n", 0)) == 0:
		return 0.0
	return float(l["rating_sum"]) / float(l["rating_n"])


# ================================================================ demand model
static func rating_factor(l: Dictionary) -> float:
	var n := int(l.get("rating_n", 0))
	if n == 0:
		return 0.85
	var r := rating(l)
	var f := 0.55 + 0.11 * r            # 5★ → 1.10, 3★ → 0.88, 1★ → 0.66
	var w := minf(1.0, n / 5.0)          # few reviews count less
	return lerpf(0.85, f, w)


static func ad_factor(l: Dictionary) -> float:
	var b := float(l.get("ad_budget", 0.0)) / float(E().get("ad_price_mult", 1.0))
	if b <= 0.0:
		return 1.0
	var half := float(mk().get("ad_half_budget", 15))
	return 1.0 + float(mk().get("ad_max_boost", 1.2)) * b / (b + half)


static func demand_mult(product_id: String) -> float:
	var m := 1.0 + Staff.demand_boost()
	if bool(DataDB.product(product_id).get("eco", false)):
		m *= World.eco_demand_mult()   # Year 4 on: green products are in demand
	if packaging() == "recycled" and World.packaging_levy() > 0.0:
		m *= 1.05   # "plastic-free packaging" on the listing
	var t := Clock.now()
	for d in E()["demand_mods"]:
		if int(d["until"]) > t and (d.get("product", "*") == "*" or d["product"] == product_id):
			m *= float(d["mult"])
	return m


## Expected orders/day for a listing (also shown in Company OS so pricing is a readable decision).
static func lambda_day(l: Dictionary) -> float:
	var p := DataDB.product(l["product"])
	var price := maxf(1.0, float(l["price"]))
	var pf := pow(float(p["ref_price"]) / price, float(p["elasticity"]))
	pf = clampf(pf, 0.05, 3.0)
	var photo_f := photo_factor(l)
	var fresh := 1.0
	if Clock.now() - int(l.get("created", 0)) < int(mk().get("new_listing_days", 3)) * Clock.DAY:
		fresh = float(mk().get("new_listing_boost", 1.6))   # marketplaces promote new listings
	return float(p["base_daily_demand"]) * pf * rating_factor(l) * photo_f * ad_factor(l) * demand_mult(l["product"]) * fresh


static func on_hour(t: int, h: int) -> void:
	GlobalMarket.on_hour(t, h)
	if h == 0:
		_charge_ads()
		_expire_mods()
	if Clock.weekday(t) == int(mk().get("payout_weekday", 1)) and h == int(mk().get("payout_hour", 9)):
		payout_all()
	_generate_demand(t, h)


static func _generate_demand(t: int, h: int) -> void:
	var weights: Array = mk().get("hourly_weights", [])
	var wsum := 0.0
	for w in weights:
		wsum += float(w)
	if wsum <= 0.0:
		return
	var wh := float(weights[h]) / wsum
	for l in E()["listings"].values():
		if not l.get("active", false):
			continue
		var lam := lambda_day(l) * wh
		l["views"] = int(l["views"]) + int(round(lam * 35.0 + GameState.randf() * 4.0))
		var n := GameState.poisson(lam)
		for i in n:
			Sim.schedule(t + GameState.randi_range(1, 59), "eco.order_place", {"listing": l["id"]})


static func _h_order_place(p: Dictionary) -> void:
	var region := str(p.get("region", ""))
	if region != "" and not GlobalMarket.order_allowed(region, str(p["listing"])):
		return
	var l: Dictionary = E()["listings"].get(p["listing"], {})
	if l.is_empty() or not l.get("active", false):
		return
	var loc := best_location(l["product"])
	if loc == "":
		GameState.inc_stat("missed_sales")
		l["missed"] = int(l.get("missed", 0)) + 1
		if int(l["missed"]) == 1 or int(l["missed"]) % 5 == 0:
			EventBus.notify.emit(I18n.t("Missed a sale: %s is out of stock.") % I18n.t(DataDB.product(l["product"])["name"]), "warn", "warning")
		return
	var e := E()
	e["counters"]["order"] = int(e["counters"]["order"]) + 1
	var oid := "#%d" % int(e["counters"]["order"])
	var names: Array = mk().get("customer_first_names", ["Alex"])
	var inits: Array = mk().get("customer_last_initials", ["A."])
	var dr: float = float(inv(loc).get(l["product"], {}).get("defect_rate", 0.0))
	var o := {"id": oid, "listing": l["id"], "product": l["product"], "qty": 1, "unit_price": float(l["price"]),
		"customer": "%s %s" % [GameState.pick(names), GameState.pick(inits)], "placed": Clock.now(), "status": "placed",
		"location": loc, "entity": GameState.business_entity(), "defective": GameState.randf() < dr}
	if region != "":
		o["entity"] = GameState.company_id()
		GlobalMarket.annotate_order(o, region)
		Customs.annotate(o)
	e["orders"][oid] = o
	l["orders"] = int(l["orders"]) + 1
	l["missed"] = 0
	var mkey := Clock.month_key()
	e["month_gmv"][mkey] = float(e["month_gmv"].get(mkey, 0.0)) + float(o["unit_price"])
	GameState.inc_stat("orders_placed")
	EventBus.notify.emit(I18n.t("New order %s — %s — %s") % [oid, I18n.t(DataDB.product(o["product"])["name"]), Fmt.money(o["unit_price"])], "good", "orders")
	EventBus.order_placed.emit(oid)
	_check_cap()


# ================================================================ seller cap
static func month_gmv() -> float:
	return float(E()["month_gmv"].get(Clock.month_key(), 0.0))


static func seller_cap() -> float:
	return float(mk().get("personal_seller_cap", 2500))


static func is_personal() -> bool:
	return GameState.company_id() == ""


static func is_capped() -> bool:
	return is_personal() and month_gmv() >= seller_cap()


static func _check_cap() -> void:
	if not is_personal():
		return
	var g := month_gmv()
	var mkey := Clock.month_key()
	var notified: Dictionary = E()["cap_notified"]
	if g >= seller_cap() * 0.8 and not notified.has(mkey + "_80"):
		notified[mkey + "_80"] = true
		GameState.add_message("shoplane", I18n.t("You've sold %s of your %s personal seller limit this month. Register a business to lift it.") % [Fmt.money0(g), Fmt.money0(seller_cap())])
		GameState.set_flag("seller_cap_warned")
	if g >= seller_cap() and not notified.has(mkey + "_100"):
		notified[mkey + "_100"] = true
		for l in E()["listings"].values():
			if l["active"]:
				l["active"] = false
				l["paused_reason"] = "seller_cap"
		GameState.add_message("shoplane", "Personal seller limit reached. Your listings are paused until next month — or until you register a business.")
		EventBus.notify.emit("ShopLane paused your listings: personal seller limit reached.", "bad", "warning")
		GameState.set_flag("seller_cap_hit")
		EventBus.listing_changed.emit("")


static func lift_cap() -> void:
	for l in E()["listings"].values():
		if l.get("paused_reason", "") == "seller_cap":
			l["active"] = true
			l["paused_reason"] = ""
	EventBus.listing_changed.emit("")


# ================================================================ fulfilment
static func orders_with(statuses: Array, loc := "") -> Array:
	var out: Array = []
	for o in E()["orders"].values():
		if o["status"] in statuses and (loc == "" or o["location"] == loc):
			out.append(o)
	out.sort_custom(func(a, b): return int(a["placed"]) < int(b["placed"]))
	return out


## How much the listing photo helps: studio photos are fixed; your own depend on how the shoot went.
static func photo_factor(l: Dictionary) -> float:
	if l.get("photo", "self") == "self" and l.has("photo_q"):
		return lerpf(0.7, 1.1, clampf(float(l["photo_q"]), 0.0, 1.0))
	return float(mk().get("photo_factor", {}).get(l.get("photo", "self"), 1.0))


## Pack every placed order whose stock is at `loc`. Returns number packed. Caller advances time.
## quality: order id → {q, label_ok} from the packing minigame; orders beyond the
## ones packed by hand get the session's average. Staff packers pass nothing (they pack well).
static func pack_orders(loc: String, max_n := -1, quality := {}) -> int:
	var avg := 0.85
	if not quality.is_empty():
		avg = 0.0
		for v in quality.values():
			avg += float(v["q"])
		avg /= quality.size()
	var n := 0
	for o in orders_with(["placed"], loc):
		if max_n >= 0 and n >= max_n:
			break
		if stock(loc, o["product"]) < int(o["qty"]):
			continue
		var l := inv(loc)
		var cost := snappedf(avg_cost(loc, o["product"]) * int(o["qty"]), 0.01)
		l[o["product"]]["qty"] = int(l[o["product"]]["qty"]) - int(o["qty"])
		o["cogs"] = cost
		o["status"] = "packed"
		o["packed"] = Clock.now()
		if not quality.is_empty():
			var qv: Dictionary = quality.get(str(o["id"]), {"q": avg, "label_ok": true})
			o["pack_q"] = float(qv["q"])
			o["label_ok"] = bool(qv["label_ok"])
		var pack := float(DataDB.product(o["product"]).get("packaging_cost", 0.5)) + packaging_extra()
		Ledger.post(o["entity"], I18n.t("Packed order %s") % o["id"], [
			{"acct": "goods_out", "dr": cost}, {"acct": "inventory", "cr": cost},
			{"acct": "exp:packaging", "dr": pack}, {"acct": "cash", "cr": pack}], {"type": "order", "id": o["id"]})
		EventBus.order_packed.emit(o["id"])
		n += 1
	if n > 0:
		GameState.inc_stat("orders_packed", n)
	return n


## "standard" (bubble wrap) or "recycled" (paper padding: a little dearer, and no levy from Year 4).
static func packaging() -> String:
	return str(E().get("packaging", "standard"))


static func set_packaging(kind: String) -> void:
	E()["packaging"] = kind
	if kind == "recycled":
		GameState.set_flag("packaging_green")


## Per-parcel packaging on top of the product's own box: recycled padding costs more, bubble wrap pays the levy.
static func packaging_extra() -> float:
	if packaging() == "recycled":
		return float(mk().get("recycled_packaging_extra", 0.25))
	return World.packaging_levy()


static func ship_cost(o: Dictionary, method: String) -> float:
	if o.has("region"):
		return GlobalMarket.shipping_cost(o, method)
	var m := DataDB.ship_method(method)
	var cls: String = DataDB.product(o["product"]).get("ship_class", "small")
	return snappedf(float(m.get("cost", {}).get(cls, 5.0)) * World.shipping_index(), 0.01)   # the era's courier rates


## Book a courier pickup for all packed orders at `loc`.
static func courier_pickup(loc: String, method: String) -> Dictionary:
	var packed := orders_with(["packed"], loc)
	if packed.is_empty():
		return {"ok": false, "error": "Nothing packed here."}
	var fee := float(DataDB.shipping()["pickup"]["courier_fee_per_batch"])
	var total := fee
	for o in packed:
		total += ship_cost(o, method)
	var entity: String = packed[0]["entity"]
	Ledger.expense(entity, "shipping", total, I18n.t("Courier pickup: %d parcels (%s)") % [packed.size(), I18n.t(DataDB.ship_method(method)["name"])], {"type": "ship"})
	var t := Clock.now() + int(DataDB.shipping()["pickup"]["pickup_delay_min"])
	if Tutorial.first_venture_active() and GameState.stat("orders_shipped") < 1:
		t = Clock.now() + 10   # the guided first parcel: the courier is round the corner
	for o in packed:
		o["status"] = "awaiting_pickup"
		o["pickup_fee_share"] = snappedf(fee / packed.size(), 0.01)
		o["ship"] = {"method": method, "cost": ship_cost(o, method), "mode": "courier"}
	Sim.schedule(t, "eco.pickup", {"ids": packed.map(func(x): return x["id"])})
	return {"ok": true, "count": packed.size(), "cost": total, "pickup_at": t}


## Take packed parcels with you to drop at PostPoint (cheaper, costs your time).
static func carry_parcels(loc: String) -> int:
	var packed := orders_with(["packed"], loc)
	var carry: Array = GameState.data["player"]["carrying_parcels"]
	for o in packed:
		o["status"] = "carried"
		carry.append(o["id"])
	return packed.size()


static func carried_count() -> int:
	return GameState.data["player"]["carrying_parcels"].size()


static func dropoff_carried(method: String) -> Dictionary:
	var carry: Array = GameState.data["player"]["carrying_parcels"]
	if carry.is_empty():
		return {"ok": false, "error": "You're not carrying any parcels."}
	var total := 0.0
	var ids: Array = carry.duplicate()
	var entity := ""
	for oid in ids:
		var o: Dictionary = E()["orders"].get(oid, {})
		if o.is_empty():
			continue
		entity = o["entity"]
		var c := ship_cost(o, method) * (1.0 - Careers.perk_value("ship_discount"))
		total += c
		o["ship"] = {"method": method, "cost": c, "mode": "dropoff"}
		_ship(o)
	carry.clear()
	if entity != "":
		Ledger.expense(entity, "shipping", total, I18n.t("PostPoint drop-off: %d parcels (%s)") % [ids.size(), I18n.t(DataDB.ship_method(method)["name"])], {"type": "ship"})
	return {"ok": true, "count": ids.size(), "cost": total}


static func _h_pickup(p: Dictionary) -> void:
	var n := 0
	for oid in p.get("ids", []):
		var o: Dictionary = E()["orders"].get(oid, {})
		if not o.is_empty() and o["status"] == "awaiting_pickup":
			_ship(o)
			n += 1
	if n > 0:
		EventBus.notify.emit(I18n.t("Courier picked up %d parcel%s.") % [n, I18n.pl(n)], "info", "parcel")


static func _ship(o: Dictionary) -> void:
	if o.has("region"):
		o["ship"]["method"] = GlobalMarket.shipping_method(o, str(o["ship"]["method"]))
		if not Customs.prepare(o):
			return
	var m := DataDB.ship_method(o["ship"]["method"])
	o["status"] = "shipped"
	o["ship"]["shipped"] = Clock.now()
	var eta := Clock.now() + int(m.get("transit_days", 3)) * Clock.DAY + GameState.randi_range(-240, 240)
	if not bool(o.get("label_ok", true)):
		eta += 2 * Clock.DAY   # wrong label: it goes to the wrong address first
	if Tutorial.first_venture_active() and GameState.stat("orders_delivered") < 1:
		eta = Clock.now() + (40 if not bool(o.get("label_ok", true)) else 20)   # the guided first parcel: across town
	if o["ship"].has("van_eta"):
		eta = int(o["ship"]["van_eta"])   # your own van: same day, and you know the address (Logistics.ship_own_van)
	if o.has("region"):
		eta = Clock.now() + GlobalMarket.shipping_days(o, str(o["ship"]["method"])) * Clock.DAY
	o["ship"]["eta"] = eta
	Sim.schedule(eta, "eco.deliver", {"order": o["id"]})
	GameState.inc_stat("orders_shipped")
	EventBus.order_shipped.emit(o["id"])


static func _h_deliver(p: Dictionary) -> void:
	var o: Dictionary = E()["orders"].get(p["order"], {})
	if o.is_empty() or o["status"] != "shipped":
		return
	if o.has("region") and not GlobalMarket.live(str(o["entity"])):
		o["status"] = "cancelled"
		return
	o["status"] = "delivered"
	o["delivered"] = Clock.now()
	var price := snappedf(float(o["unit_price"]) * int(o["qty"]), 0.01)
	var fee := snappedf(price * float(mk().get("fee_rate", 0.1)), 0.01)
	var pname: String = I18n.t(DataDB.product(o["product"])["name"])
	if o.has("region"):
		GlobalMarket.deliver(o)
	else:
		_post_local_delivery(o, price, fee, pname)
	GameState.inc_stat("orders_delivered")
	if not o.has("region"):
		GameState.inc_stat("revenue_total", price)
	if int(GameState.stat("orders_delivered")) == 1:
		GameState.timeline(I18n.t("First sale: %s bought %s for %s.") % [o["customer"], pname, Fmt.money(price)], "milestone")
	EventBus.order_delivered.emit(o["id"])
	# after-sale: poorly padded parcels arrive broken sometimes (the packing minigame's quality)
	var pq := float(o.get("pack_q", 1.0))
	if pq < 0.6 and not o.get("defective", false) and GameState.randf() < (0.6 - pq) * 1.2:
		o["defective"] = true
		o["damaged"] = true
	# after-sale: returns & reviews
	var p_ret := 0.8 if o.get("defective", false) else float(DataDB.product(o["product"]).get("return_base_rate", 0.03))
	if o.has("customs") and GameState.randf() < Customs.refusal_chance(o):
		o["customs_refused"] = true
		Sim.schedule(Clock.now() + 1, "eco.return_request", {"order": o["id"]})
	elif GameState.flag("force_next_return") or GameState.randf() < p_ret:
		GameState.set_flag("force_next_return", false)
		Sim.schedule(Clock.now() + GameState.randi_range(12 * 60, 3 * Clock.DAY), "eco.return_request", {"order": o["id"]})
	elif GameState.randf() < float(DataDB.product(o["product"]).get("review_rate", 0.4)):
		Sim.schedule(Clock.now() + GameState.randi_range(8 * 60, 3 * Clock.DAY), "eco.review", {"order": o["id"]})


static func _post_local_delivery(o: Dictionary, price: float, fee: float, pname: String) -> void:
	Ledger.post(o["entity"], I18n.t("Sale delivered %s: %d × %s @ %s") % [o["id"], int(o["qty"]), pname, Fmt.money(o["unit_price"])], [
		{"acct": "marketplace_balance", "dr": price}, {"acct": "revenue", "cr": price},
		{"acct": "cogs", "dr": float(o.get("cogs", 0.0))}, {"acct": "goods_out", "cr": float(o.get("cogs", 0.0))},
		{"acct": "exp:platform_fees", "dr": fee}, {"acct": "marketplace_balance", "cr": fee}], {"type": "order", "id": o["id"]})
	o["fee"] = fee


static func _review_stars(o: Dictionary) -> int:
	if o.get("defective", false):
		return 1 + int(GameState.randf() < 0.3)
	var s := 4.6 + GameState.randf() * 0.6
	var ship: Dictionary = o.get("ship", {})
	if ship.get("method", "economy") == "economy":
		s -= 0.25
	var ref := float(DataDB.product(o["product"])["ref_price"])
	if float(o["unit_price"]) > ref * 1.25:
		s -= 0.6
	elif float(o["unit_price"]) < ref * 0.85:
		s += 0.2
	if int(o.get("delivered", 0)) - int(o.get("placed", 0)) > 4 * Clock.DAY:
		s -= 0.8
	return clampi(int(round(s)), 1, 5)


static func post_review(o: Dictionary, stars: int) -> void:
	if o.has("review"):
		return
	var texts: Dictionary = mk().get("review_texts", {})
	var arr: Array = texts.get(str(stars), ["."])
	o["review"] = {"stars": stars, "text": GameState.pick(arr), "t": Clock.now()}
	var l: Dictionary = E()["listings"].get(o["listing"], {})
	if not l.is_empty():
		l["rating_sum"] = float(l["rating_sum"]) + stars
		l["rating_n"] = int(l["rating_n"]) + 1
	GameState.inc_stat("reviews")
	EventBus.review_posted.emit(o["id"], stars)
	EventBus.notify.emit(I18n.t("New review %s: %s \"%s\"") % [o["id"], "★".repeat(stars), I18n.t(o["review"]["text"])], "good" if stars >= 4 else "bad", "star")


static func _h_review(p: Dictionary) -> void:
	var o: Dictionary = E()["orders"].get(p["order"], {})
	if o.is_empty() or o["status"] != "delivered":
		return
	post_review(o, _review_stars(o))


static func _h_return_request(p: Dictionary) -> void:
	var o: Dictionary = E()["orders"].get(p["order"], {})
	if o.is_empty() or o["status"] != "delivered":
		return
	var reasons: Array = mk().get("return_reasons_defective" if o.get("defective", false) else "return_reasons_normal", [])
	var reason: String = GameState.pick(reasons)
	if o["product"] != "wireless_earbuds" and reason.contains("earbud"):
		reason = "Doesn't work. Out of the box."
	o["status"] = "return_requested"
	o["return"] = {"reason": reason, "t": Clock.now()}
	GameState.inc_stat("returns_requested")
	EventBus.return_requested.emit(o["id"])
	if GameState.flag("first_issue_resolved") and Staff.auto_resolve_return(o["id"]):
		return
	var ev := "customer_return" if GameState.flag("first_issue_resolved") else "customer_return_first"
	EventEngine.trigger(ev, {"order": o["id"], "customer": o["customer"], "product": I18n.t(DataDB.product(o["product"])["name"]),
		"product_id": o["product"], "price": Fmt.money(o["unit_price"]), "reason": reason})


## Resolve a return request. choice: refund | replace | partial | refuse
static func resolve_return(order_id: String, choice: String) -> Dictionary:
	var o: Dictionary = E()["orders"].get(order_id, {})
	if o.is_empty() or o["status"] != "return_requested":
		return {"ok": false, "error": "Nothing to resolve."}
	if o.has("region") and choice in ["refund", "partial"]:
		return GlobalMarket.resolve_return(o, choice)
	var price := float(o["unit_price"]) * int(o["qty"])
	var fee := float(o.get("fee", 0.0))
	var ent: String = o["entity"]
	var pname: String = I18n.t(DataDB.product(o["product"])["name"])
	match choice:
		"refund":
			var lines := [{"acct": "refunds", "dr": price}, {"acct": "marketplace_balance", "cr": price},
				{"acct": "marketplace_balance", "dr": fee}, {"acct": "exp:platform_fees", "cr": fee}]
			var label := float(DataDB.ship_method("economy")["cost"].get("small", 4.2))
			lines += [{"acct": "exp:shipping", "dr": label}, {"acct": "cash", "cr": label}]
			if not o.get("defective", false):
				# resellable: back into stock, reverse the COGS
				_add_stock(o["location"], o["product"], int(o["qty"]), float(o.get("cogs", 0.0)) / maxi(1, int(o["qty"])), 0.0)
				lines += [{"acct": "inventory", "dr": float(o.get("cogs", 0.0))}, {"acct": "cogs", "cr": float(o.get("cogs", 0.0))}]
			Ledger.post(ent, I18n.t("Refund %s: %s (return label paid)") % [order_id, pname], lines, {"type": "return", "id": order_id})
			o["status"] = "refunded"
		"replace":
			var loc := best_location(o["product"])
			if loc == "":
				return {"ok": false, "error": I18n.t("No %s in stock to send.") % pname}
			var uc := avg_cost(loc, o["product"])
			inv(loc)[o["product"]]["qty"] = stock(loc, o["product"]) - 1
			var ship := ship_cost(o, "express")
			Ledger.post(ent, I18n.t("Replacement sent %s: %s (express)") % [order_id, pname], [
				{"acct": "cogs", "dr": uc}, {"acct": "inventory", "cr": uc},
				{"acct": "exp:shipping", "dr": ship}, {"acct": "cash", "cr": ship}], {"type": "return", "id": order_id})
			o["status"] = "replaced"
			Sim.schedule(Clock.now() + Clock.DAY + 120, "eco.review_fixed", {"order": order_id, "stars": 5})
		"partial":
			var amt := snappedf(price * 0.3, 0.01)
			Ledger.post(ent, I18n.t("Partial refund 30%% %s: %s") % [order_id, pname],
				[{"acct": "refunds", "dr": amt}, {"acct": "marketplace_balance", "cr": amt}], {"type": "return", "id": order_id})
			o["status"] = "partial_refund"
			Sim.schedule(Clock.now() + 600, "eco.review_fixed", {"order": order_id, "stars": 3})
		"refuse":
			o["status"] = "refused"
			post_review(o, 1)
			if GameState.randf() < 0.5:
				Sim.schedule(Clock.now() + 2 * Clock.DAY, "eco.dispute", {"order": order_id})
		_:
			return {"ok": false, "error": "Unknown choice."}
	GameState.inc_stat("returns_resolved")
	return {"ok": true}


static func _h_review_fixed(p: Dictionary) -> void:
	var o: Dictionary = E()["orders"].get(p["order"], {})
	if not o.is_empty():
		post_review(o, int(p["stars"]))


static func _h_dispute(p: Dictionary) -> void:
	var o: Dictionary = E()["orders"].get(p["order"], {})
	if o.is_empty() or o["status"] != "refused":
		return
	if o.has("region"):
		if not GlobalMarket.live(str(o["entity"])):
			return
		GlobalMarket.refund(o, 1.0)
		Ledger.expense(str(o["entity"]), "platform_fees", 15.0, "Overseas dispute fee", {"type": "global_dispute"})
		o["status"] = "disputed"
		return
	var price := float(o["unit_price"]) * int(o["qty"])
	var ent: String = o["entity"]
	Ledger.post(ent, I18n.t("ShopLane dispute lost %s: forced refund + $15 fee") % o["id"], [
		{"acct": "refunds", "dr": price}, {"acct": "exp:platform_fees", "dr": 15.0}, {"acct": "marketplace_balance", "cr": price + 15.0}],
		{"type": "dispute", "id": o["id"]})
	o["status"] = "disputed"
	GameState.add_message("shoplane", I18n.t("Buyer %s opened a dispute on order %s. We refunded them and charged a $15 dispute fee.") % [o["customer"], o["id"]])
	EventBus.notify.emit(I18n.t("Dispute lost on %s: −%s") % [o["id"], Fmt.money(price + 15.0)], "bad", "warning")


# ================================================================ money: payouts & ads
static func held_amount(entity: String) -> float:
	var hold := int(mk().get("payout_hold_days", 2)) * Clock.DAY
	var t := Clock.now()
	var s := 0.0
	for o in E()["orders"].values():
		if not o.has("region") and o["entity"] == entity and o["status"] == "delivered" and t - int(o.get("delivered", 0)) < hold:
			s += float(o["unit_price"]) * int(o["qty"]) - float(o.get("fee", 0.0))
	return s


static func payout_all() -> void:
	var ents := ["player"]
	if GameState.company_id() != "":
		ents.append(GameState.company_id())
	for ent in ents:
		payout(ent)


static func payout(entity: String) -> float:
	var bal := Ledger.balance(entity, "marketplace_balance")
	var amt := snappedf(bal - held_amount(entity), 0.01)
	if amt > 0.0:
		Ledger.post(entity, "ShopLane weekly payout", [{"acct": "cash", "dr": amt}, {"acct": "marketplace_balance", "cr": amt}], {"type": "payout"})
		GameState.inc_stat("payouts")
		EventBus.notify.emit(I18n.t("ShopLane payout received: %s") % Fmt.money(amt), "good", "cash")
		GameState.add_message("shoplane", (I18n.t("Payout sent: %s to your business account.") if entity != "player" else I18n.t("Payout sent: %s to your personal account.")) % Fmt.money(amt))
		if int(GameState.stat("payouts")) == 1:
			GameState.timeline(I18n.t("First payout from ShopLane: %s.") % Fmt.money(amt), "business")
	elif bal < -0.01:
		Ledger.post(entity, "ShopLane negative balance charged to card", [{"acct": "marketplace_balance", "dr": -bal}, {"acct": "cash", "cr": -bal}], {"type": "payout"})
	return amt


static func _charge_ads() -> void:
	for l in E()["listings"].values():
		var b := float(l.get("ad_budget", 0.0))
		if b > 0.0 and l.get("active", false):
			Ledger.expense(GameState.business_entity(), "advertising", b, I18n.t("ShopLane ads: %s") % I18n.t(DataDB.product(l["product"])["name"]), {"type": "ads", "id": l["id"]})


static func _expire_mods() -> void:
	var t := Clock.now()
	E()["supplier_mods"] = E()["supplier_mods"].filter(func(m): return int(m["until"]) > t)
	E()["demand_mods"] = E()["demand_mods"].filter(func(m): return int(m["until"]) > t)
	if int(E().get("ad_price_until", 0)) <= t:
		E()["ad_price_mult"] = 1.0


static func pause_all_ads() -> void:
	for l in E()["listings"].values():
		l["ad_budget"] = 0.0
	EventBus.listing_changed.emit("")


static func total_ad_budget() -> float:
	var s := 0.0
	for l in E()["listings"].values():
		if l.get("active", false):
			s += float(l.get("ad_budget", 0.0))
	return s


# ================================================================ recovery & company
## Sell every unit in stock to a liquidator at `rate` of cost. Returns cash raised.
static func liquidate_all(rate: float) -> float:
	var raised := 0.0
	for loc in E()["inventory"]:
		for pid in E()["inventory"][loc]:
			var it: Dictionary = E()["inventory"][loc][pid]
			var q := int(it["qty"]) - reserved(loc, pid)
			if q <= 0:
				continue
			var value := snappedf(q * float(it["avg_cost"]), 0.01)
			var cash_in := snappedf(value * rate, 0.01)
			it["qty"] = int(it["qty"]) - q
			Ledger.post(GameState.business_entity(), I18n.t("Sold %d × %s to liquidator (%d%% of cost)") % [q, I18n.t(DataDB.product(pid)["name"]), int(rate * 100)], [
				{"acct": "cash", "dr": cash_in}, {"acct": "exp:inventory_writeoff", "dr": value - cash_in}, {"acct": "inventory", "cr": value}],
				{"type": "liquidation"})
			raised += cash_in
	return raised


## After registration: move the business assets from the sole-proprietor books into the company (in-kind capital).
static func transfer_business_to(company: String) -> void:
	var lines_player: Array = []
	var lines_co: Array = []
	var total := 0.0
	for acct in ["inventory", "inventory_in_transit", "goods_out", "marketplace_balance", "escrow_held", "frozen_funds"]:
		var b := Ledger.balance("player", acct)
		if absf(b) < 0.01:
			continue
		total += b
		if b > 0:
			lines_player.append({"acct": acct, "cr": b})
			lines_co.append({"acct": acct, "dr": b})
		else:
			lines_player.append({"acct": acct, "dr": -b})
			lines_co.append({"acct": acct, "cr": -b})
	if absf(total) >= 0.01:
		if total > 0:
			lines_player.append({"acct": "investments", "dr": total})
			lines_co.append({"acct": "equity", "cr": total})
		else:
			lines_player.append({"acct": "investments", "cr": -total})
			lines_co.append({"acct": "equity", "dr": -total})
		Ledger.post("player", I18n.t("Business assets contributed to %s (in kind)") % GameState.entity_name(company), lines_player, {"type": "capital"})
		Ledger.post(company, "Capital contributed in kind by founder", lines_co, {"type": "capital"})
	for o in E()["orders"].values():
		if o["status"] in OPEN_STATUSES or o["status"] == "return_requested" or o["status"] == "delivered":
			o["entity"] = company
	for po in E()["purchase_orders"].values():
		if po["status"] in ["in_transit", "awaiting_payment", "delivered"]:
			po["entity"] = company


# ================================================================ dispatch
static func handle(kind: String, p: Dictionary) -> void:
	match kind:
		"eco.po_arrive":
			_h_po_arrive(p)
		"eco.ap_due":
			_h_ap_due(p)
		"eco.po_cleared":
			_h_po_cleared(p)
		"eco.return_refund":
			_h_return_refund(p)
		"eco.order_place":
			_h_order_place(p)
		"eco.pickup":
			_h_pickup(p)
		"eco.deliver":
			_h_deliver(p)
		"eco.review":
			_h_review(p)
		"eco.review_fixed":
			_h_review_fixed(p)
		"eco.return_request":
			_h_return_request(p)
		"eco.dispute":
			_h_dispute(p)
		_:
			push_warning("Ecommerce: unknown " + kind)


# ================================================================ reporting helpers
static func month_sales_summary() -> Dictionary:
	var t0 := Clock.month_start()
	var units := 0
	var gmv := 0.0
	for o in E()["orders"].values():
		if int(o["placed"]) >= t0:
			units += int(o["qty"])
			gmv += float(o["unit_price"]) * int(o["qty"])
	return {"units": units, "gmv": gmv}
