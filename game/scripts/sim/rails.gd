class_name Rails
extends RefCounted
## Digital rails (Chapters 10–11): escrow on delivery, each rail's track record, and the bridge exploit that freezes
## the digital-dollar rail for a while. Numbers live in data/economy/rails.json; the payment methods themselves are
## rows in settlement_methods.json (`digital_rail`, `escrow`). State: GameState.data["rails"].
##
## Where the money sits on the buyer's books (a rail changes only who holds it until the goods land):
##   prepaid (wire, letter of credit, digital dollars)   Dr inventory_in_transit / Cr cash
##   escrow                                                Dr escrow_held / Cr cash, then on arrival Dr inventory / Cr escrow_held
##   bridge exploit (payments still crossing the bridge)   Dr frozen_funds / Cr (escrow_held | inventory_in_transit)
##   recovery                                              frozen_funds comes back at the published ratio; the gap is a loss
## Chapter 11 story: the exploit strikes shortly after the first Year 7 import order. Only payments still crossing the
## bridge are caught, so whoever paid by wire or letter of credit never notices (the lighter path).


static func R() -> Dictionary:
	if not GameState.data.has("rails"):
		GameState.data["rails"] = {"reliability": {}, "settled": {}, "exploit": {}}
	return GameState.data["rails"]


static func cfg() -> Dictionary:
	return DataDB.economy.get("rails", {})


static func exploit_cfg() -> Dictionary:
	return cfg().get("exploit", {})


static func is_digital(method_id: String) -> bool:
	return bool(Ecommerce.settlement_def(method_id).get("digital_rail", false))


static func is_escrow(method_id: String) -> bool:
	return bool(Ecommerce.settlement_def(method_id).get("escrow", false))


# ================================================================ escrow account
static func open_escrow() -> void:
	GameState.set_flag("escrow_open")
	GameState.set_flag("ch10_decided")
	GameState.timeline(I18n.t("Opened an escrow account on Lina Zhao's payments platform."), "business")


## The account a delivered order's cost leaves: an escrow contract pays the supplier on arrival.
static func arrival_account(po: Dictionary) -> String:
	return "escrow_held" if str(po.get("escrow", "")) == "held" else "inventory_in_transit"


## Goods arrived: the escrow contract releases the money to the supplier.
static func on_arrived(po: Dictionary) -> void:
	if str(po.get("escrow", "")) != "held":
		return
	po["escrow"] = "released"
	GameState.inc_stat("escrow_released")
	EventBus.notify.emit(I18n.t("Escrow released: %s is paid now that the goods are here.") % I18n.t(str(DataDB.supplier(str(po["supplier"])).get("name", ""))), "good", "bank")


## The supplier failed to deliver: an escrowed payment goes back to the buyer's cash. (The fee is not refunded.)
static func refund_escrow(po_id: String) -> Dictionary:
	var po: Dictionary = Ecommerce.E()["purchase_orders"].get(po_id, {})
	if po.is_empty() or str(po.get("escrow", "")) != "held" or str(po["status"]) != "in_transit":
		return {"ok": false, "error": "Only an escrow order that hasn't arrived can be refunded."}
	var amt := float(po["total"])
	Ledger.post(str(po["entity"]), I18n.t("Escrow refund: %s (the goods never came)") % po_id,
		[{"acct": "cash", "dr": amt}, {"acct": "escrow_held", "cr": amt}], {"type": "po", "id": po_id})
	po["escrow"] = "refunded"
	po["status"] = "cancelled"
	GameState.inc_stat("escrow_refunds")
	GameState.timeline(I18n.t("Escrow refunded %s: the shipment never arrived.") % Fmt.money0(amt), "business")
	return {"ok": true, "amount": amt}


## The supplier ships again: the arrival moves back by `days`.
static func reship(po_id: String, days: int) -> Dictionary:
	var po: Dictionary = Ecommerce.E()["purchase_orders"].get(po_id, {})
	if po.is_empty() or str(po["status"]) != "in_transit":
		return {"ok": false, "error": "That order isn't on the way any more."}
	po["eta"] = maxi(int(po["eta"]), Clock.now()) + days * Clock.DAY
	Sim.cancel("eco.po_arrive", "po", po_id)
	Sim.schedule(int(po["eta"]), "eco.po_arrive", {"po": po_id})
	return {"ok": true, "eta": int(po["eta"])}


## Random daily event: an import shipment is lost at sea. Escrow buyers can take their money back.
static func lost_shipment(po_id: String, choice: String) -> Dictionary:
	if choice == "refund":
		return refund_escrow(po_id)
	return reship(po_id, int(cfg().get("shipment_lost", {}).get("reship_days", 10)))


# ================================================================ track record
## Share of payments on this rail that land on time: the published record, moved by what happens to the rails
## (a successful landing closes a tenth of the gap to 100%; the bridge exploit knocks the digital rails down).
static func reliability(method_id: String) -> float:
	var r: Dictionary = R()["reliability"]
	if r.has(method_id):
		return float(r[method_id])
	return float(cfg().get("reliability", {}).get(method_id, 0.97))


static func set_reliability(method_id: String, v: float) -> void:
	R()["reliability"][method_id] = clampf(v, 0.0, 1.0)


static func reliability_text(method_id: String) -> String:
	return I18n.t("%s landed on time") % Fmt.pct(reliability(method_id), 1)


## A payment landed on this rail without trouble.
static func note_settled(method_id: String) -> void:
	var r := reliability(method_id)
	set_reliability(method_id, r + (1.0 - r) * float(cfg().get("reliability_gain", 0.1)))
	R()["settled"][method_id] = int(R()["settled"].get(method_id, 0)) + 1


## A regular on the digital rails (a few settled payments) gets a lower fee.
static func regular() -> bool:
	var n := 0
	for id in R()["settled"]:
		if is_digital(str(id)):
			n += int(R()["settled"][id])
	return n >= int(cfg().get("regular_after", 2))


static func fee_mult(method_id: String) -> float:
	return float(cfg().get("regular_fee_mult", 1.0)) if is_digital(method_id) and regular() else 1.0


# ================================================================ the bridge exploit
static func X() -> Dictionary:
	return R()["exploit"]


## "none" (before the exploit), "frozen" (transfers are stuck) or "recovered".
static func state() -> String:
	return str(X().get("state", "none"))


static func frozen() -> bool:
	return state() == "frozen"


static func frozen_until() -> int:
	return int(X().get("until", 0))


## Why a digital rail can't be used right now ("" = it can).
static func freeze_block(method_id: String) -> String:
	if frozen() and is_digital(method_id):
		return I18n.t("The bridge is frozen until %s.") % Clock.fmt_short(frozen_until())
	return ""


static func is_frozen_po(po: Dictionary) -> bool:
	return bool(po.get("frozen", false))


## Money in limbo right now: what the frozen payments are worth on the books.
static func frozen_amount(ent := "") -> float:
	var total := 0.0
	for it in X().get("items", []):
		if ent == "" or str(it["entity"]) == ent:
			total += float(it["amount"])
	return total if frozen() else 0.0


## Digital-rail payments that are still crossing the bridge (paid, not yet landed).
static func exposed_pos() -> Array:
	var out: Array = []
	for po in Ecommerce.E()["purchase_orders"].values():
		if str(po["status"]) == "awaiting_payment" and not is_frozen_po(po) and is_digital(str(po.get("settlement", {}).get("method", ""))):
			out.append(po)
	return out


## The exploit happens: transfers crossing the bridge freeze. Whoever has money in them decides what to do;
## everyone else just hears about it.
static func exploit() -> Dictionary:
	if state() != "none":
		return {"ok": false, "error": "The bridge was already hit."}
	var c := exploit_cfg()
	var now := Clock.now()
	var until := now + int(c.get("freeze_days", 6)) * Clock.DAY
	var items: Array = []
	var total := 0.0
	for po in exposed_pos():
		var amt := float(po["total"])
		var src := "escrow_held" if str(po.get("escrow", "")) == "held" else "inventory_in_transit"
		Ledger.post(str(po["entity"]), I18n.t("Frozen on the bridge: %s") % po["id"],
			[{"acct": "frozen_funds", "dr": amt}, {"acct": src, "cr": amt}], {"type": "rail", "id": po["id"]})
		po["frozen"] = true
		items.append({"po": po["id"], "amount": amt, "entity": po["entity"], "src": src, "rerouted": false})
		total += amt
	R()["exploit"] = {"state": "frozen", "at": now, "until": until, "ratio": float(c.get("recovery_ratio", 0.9)),
		"items": items, "amount": total, "decision": ""}
	for m in DataDB.economy.get("settlement_methods", {}).get("methods", []):
		if bool(m.get("digital_rail", false)):
			set_reliability(str(m["id"]), reliability(str(m["id"])) * float(c.get("reliability_hit", 0.78)))
	Sim.schedule(until, "rail.unfreeze", {})
	GameState.set_flag("rail_exploit")
	GameState.timeline(I18n.t("The digital-dollar bridge was exploited. Transfers are frozen until about %s.") % Clock.fmt_short(until), "world")
	EventBus.notify.emit(I18n.t("BREAKING: the digital-dollar bridge was exploited. Transfers are frozen until about %s.") % Clock.fmt_short(until), "bad", "warning")
	GameState.add_message("marcus", "Marcus Reed. Wires and letters of credit are unaffected. If the freeze is squeezing your cash, ask me about a bridge loan: weekdays 1 to 4.")
	if items.is_empty():
		GameState.add_message("lina", I18n.t("Lina Zhao. The bridge under our rail was exploited: transfers are frozen until about %s. Nothing of yours was crossing it, so you're fine. Lumina Direct is taking wires only for now.") % Clock.fmt_short(until))
	else:
		EventEngine.trigger("rail_frozen", decision_context())
	return {"ok": true, "frozen": total, "items": items.size()}


## The wire fee for re-paying everything that's stuck, and what the loan would be.
static func _reroute_fee(total_of: Array) -> float:
	var fee := 0.0
	for amt in total_of:
		fee += Ecommerce.settlement_fee("international_wire", float(amt))
	return fee


static func decision_context() -> Dictionary:
	var x := X()
	var amts: Array = []
	var total := 0.0
	var sup := ""
	for it in x.get("items", []):
		amts.append(float(it["amount"]))
		total += float(it["amount"])
		if sup == "":
			sup = str(DataDB.supplier(str(Ecommerce.E()["purchase_orders"].get(str(it["po"]), {}).get("supplier", ""))).get("name", ""))
	var ratio := float(x.get("ratio", 0.9))
	var fee := _reroute_fee(amts)
	var need := total + fee
	var loan := maxf(1000.0, ceilf(need / 100.0) * 100.0)
	var wr: Array = Ecommerce.settlement_range("international_wire")
	return {
		"count": amts.size(), "frozen": Fmt.money0(total), "frozen_v": total,
		"until": Clock.fmt_short(int(x.get("until", 0))), "days": int(exploit_cfg().get("freeze_days", 6)),
		"ratio": Fmt.pct(ratio), "back": Fmt.money0(total * ratio), "lost": Fmt.money0(total * (1.0 - ratio)),
		"reroute_fee": Fmt.money0(fee), "reroute_cost": Fmt.money0(need), "reroute_cost_v": need,
		"wire_days": "%d–%d" % [int(wr[0]) / 24, int(ceil(float(wr[1]) / 24.0))],
		"loan": Fmt.money0(loan), "loan_v": loan, "apr": Fmt.pct(Bank.apr(), 1),
		"supplier": sup, "record": Rails.reliability_text("stablecoin_settlement"),
	}


static func _item(po_id: String) -> Dictionary:
	for it in X().get("items", []):
		if str(it["po"]) == po_id:
			return it
	return {}


## Pay a stuck order again by another rail (wire by default): a fee, a delay, and the money has to be there twice
## for a while. The frozen payment comes back at the recovery ratio when the bridge reopens.
static func reroute(po_id: String, method := "international_wire") -> Dictionary:
	if not frozen():
		return {"ok": false, "error": "The bridge isn't frozen."}
	var it := _item(po_id)
	var po: Dictionary = Ecommerce.E()["purchase_orders"].get(po_id, {})
	if it.is_empty() or po.is_empty() or bool(it["rerouted"]):
		return {"ok": false, "error": "That payment isn't stuck on the bridge."}
	if is_digital(method):
		return {"ok": false, "error": "That rail is frozen."}
	var why := Ecommerce.settlement_block(method)
	if why != "":
		return {"ok": false, "error": why}
	var amt := float(it["amount"])
	var fee := Ecommerce.settlement_fee(method, amt)
	var ent := str(po["entity"])
	if Ledger.cash(ent) < amt + fee:
		return {"ok": false, "error": I18n.t("Not enough cash. You need %s.") % Fmt.money0(amt + fee)}
	Ledger.post(ent, I18n.t("%s: paid again by %s (rerouted)") % [po_id, I18n.t(str(Ecommerce.settlement_def(method)["name"]))],
		[{"acct": "inventory_in_transit", "dr": amt}, {"acct": "cash", "cr": amt}], {"type": "po", "id": po_id})
	if fee > 0.0:
		Ledger.expense(ent, "bank_fees", fee, I18n.t("%s — %s") % [I18n.t(str(Ecommerce.settlement_def(method)["name"])), po_id], {"type": "po", "id": po_id})
	var st: Dictionary = po["settlement"]
	var transit := int(po["eta"]) - int(st["clears"])
	var clears := Clock.now() + Ecommerce.settlement_hours(method) * 60
	st["method"] = method
	st["fee"] = float(st["fee"]) + fee
	st["clears"] = clears
	po["frozen"] = false
	if str(po.get("escrow", "")) == "held":
		po["escrow"] = "rerouted"
	po["eta"] = clears + transit
	it["rerouted"] = true
	Sim.cancel("eco.po_arrive", "po", po_id)
	Sim.schedule(clears, "eco.po_cleared", {"po": po_id})
	Sim.schedule(int(po["eta"]), "eco.po_arrive", {"po": po_id})
	return {"ok": true, "clears": clears, "fee": fee}


static func reroute_all(method := "international_wire") -> Dictionary:
	var need := 0.0
	var ent := ""
	for it in X().get("items", []):
		if not bool(it["rerouted"]):
			need += float(it["amount"]) + Ecommerce.settlement_fee(method, float(it["amount"]))
			ent = str(it["entity"])
	if ent != "" and Ledger.cash(ent) < need:
		return {"ok": false, "error": I18n.t("Not enough cash. You need %s.") % Fmt.money0(need)}
	var n := 0
	for it in X().get("items", []):
		if not bool(it["rerouted"]):
			var r := reroute(str(it["po"]), method)
			if not r["ok"]:
				return r
			n += 1
	return {"ok": true, "count": n}


## What the player picked at the `rail_frozen` decision: wait it out, reroute by wire, or borrow to reroute.
static func decide(choice: String) -> Dictionary:
	if not frozen():
		return {"ok": false, "error": "The bridge isn't frozen."}
	match choice:
		"wait":
			pass
		"reroute":
			var r := reroute_all()
			if not r["ok"]:
				return r
		"loan":
			var ctx := decision_context()
			var lr := Bank.take_loan(float(ctx["loan_v"]), 3)
			if not lr["ok"]:
				return lr
			var rr := reroute_all()
			if not rr["ok"]:
				return rr
		_:
			return {"ok": false, "error": "No such choice."}
	X()["decision"] = choice
	GameState.set_flag("rail_decided")
	return {"ok": true}


## The freeze ends. Frozen balances come back at the published ratio; the shortfall is a real loss.
static func _unfreeze() -> void:
	if not frozen():
		return
	var x := X()
	var ratio := float(x.get("ratio", 0.9))
	var frozen_total := 0.0
	var back_total := 0.0
	var topup_total := 0.0
	for it in x.get("items", []):
		var amt := float(it["amount"])
		var ent := str(it["entity"])
		var back := snappedf(amt * ratio, 0.01)
		var lost := snappedf(amt - back, 0.01)
		var po: Dictionary = Ecommerce.E()["purchase_orders"].get(str(it["po"]), {})
		frozen_total += amt
		if bool(it["rerouted"]):
			Ledger.post(ent, I18n.t("Bridge recovery: %s (%s of the frozen payment)") % [it["po"], Fmt.pct(ratio)],
				[{"acct": "cash", "dr": back}, {"acct": "exp:other", "dr": lost}, {"acct": "frozen_funds", "cr": amt}], {"type": "rail", "id": it["po"]})
			back_total += back
		else:
			# the transfer lands at the ratio; the buyer makes up the gap so the supplier ships
			var dest := "escrow_held" if str(it["src"]) == "escrow_held" else "inventory_in_transit"
			Ledger.post(ent, I18n.t("Bridge recovery: %s lands, you cover the %s gap") % [it["po"], Fmt.money0(lost)],
				[{"acct": dest, "dr": amt}, {"acct": "exp:other", "dr": lost}, {"acct": "frozen_funds", "cr": amt}, {"acct": "cash", "cr": lost}],
				{"type": "rail", "id": it["po"]})
			topup_total += lost
			if not po.is_empty() and str(po["status"]) == "awaiting_payment":
				var transit := int(po["eta"]) - int(po["settlement"]["clears"])
				po["frozen"] = false
				po["status"] = "in_transit"
				po["settlement"]["clears"] = Clock.now()
				po["eta"] = Clock.now() + transit
				Sim.cancel("eco.po_arrive", "po", str(po["id"]))
				Sim.schedule(int(po["eta"]), "eco.po_arrive", {"po": str(po["id"])})
				GameState.inc_stat("import_cleared")
	x["state"] = "recovered"
	x["recovered_at"] = Clock.now()
	x["returned"] = back_total
	x["topup"] = topup_total
	# a decision nobody answered is moot now
	var q: Array = EventEngine.S()["queue"]
	for i in range(q.size() - 1, -1, -1):
		if str(q[i]["id"]) == "rail_frozen":
			q.remove_at(i)
	GameState.set_flag("rail_recovered")
	GameState.timeline(I18n.t("The bridge reopened. Frozen balances came back at %s on the dollar.") % Fmt.pct(ratio), "world")
	EventBus.notify.emit(I18n.t("The bridge is open again."), "info", "bank")
	if frozen_total > 0.0:
		GameState.add_message("lina", I18n.t("The bridge is open again. Frozen balances came back at %d cents on the dollar: %s of your %s. The attacker drained the rest before the freeze. The operators' reserve and insurance pool covered everyone else's share, and nobody covers the gap.") % [int(round(ratio * 100.0)), Fmt.money0(frozen_total * ratio), Fmt.money0(frozen_total)])
	else:
		GameState.add_message("lina", "The bridge is open again, with limits and an insurance pool. Wires never stopped, so you lost nothing but a week of options. Split your payments across rails, and keep a wire route warm.")
	EventBus.world_refresh.emit()


static func headlines(y: Dictionary) -> Array:
	match state():
		"frozen":
			if y.has("headlines_incident"):
				return y["headlines_incident"]
		"recovered":
			if y.has("headlines_after"):
				return y["headlines_after"]
	return y.get("headlines", [])


static func handle(kind: String, _p: Dictionary) -> void:
	match kind:
		"rail.exploit":
			exploit()
		"rail.unfreeze":
			_unfreeze()
		_:
			push_warning("Rails: unknown " + kind)
