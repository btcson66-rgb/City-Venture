class_name InternalSupply
extends RefCounted
## Group internal supply (#71): one module behind every "one of my businesses sells to another" hook.
##
## A link (data/synergies.json) joins a seller industry to buyer industries. A pair is feasible only while both are
## running on the same company's books. The player chooses the transfer price per pair: at cost, cost plus a markup or
## at the outside market price. Every trade writes both sides into the segment P&L:
##   seller segment  cogs (real cost of supplying)  and  ic_revenue (internal sale at the transfer price)
##   buyer segment   ic_cost (internal purchase at the transfer price)
## ic_revenue and ic_cost use their own accounts routed through the ic_clearing account, so they never reach revenue,
## cogs or opex: the company P&L and the consolidated group totals eliminate them by construction, and the clearing
## account always nets to zero. Group profit therefore does not depend on the transfer price, only on real savings.
## Non-native links replace a purchase the buyer really made outside: the avoided amount (market price x share) is credited back
## to the buyer's own expense accounts (`offset_accts`), capped at what that segment actually spent there in the last 30 days.
## With no outside spend to replace, nothing trades: internal supply never creates income on its own (spec R4).
## State: GameState.data["synergy"]["pairs"][link:buyer].

const MODES := ["cost", "plus", "market"]


static func cfg() -> Dictionary:
	return DataDB.synergies


static func S() -> Dictionary:
	if not GameState.data.has("synergy"):
		GameState.data["synergy"] = {"pairs": {}}
	var s: Dictionary = GameState.data["synergy"]
	if not s.has("pairs"):
		s["pairs"] = {}
	return s


static func links() -> Array:
	return cfg().get("links", [])


static func link(id: String) -> Dictionary:
	for l in links():
		if l["id"] == id:
			return l
	return {}


static func key(link_id: String, buyer: String) -> String:
	return link_id + ":" + buyer


static func parse(k: String) -> Array:
	return [k.get_slice(":", 0), k.get_slice(":", 1)]


static func _ref(path: Array, fallback: float) -> float:
	var node: Variant = DataDB.economy
	for part in path:
		if typeof(node) != TYPE_DICTIONARY or not node.has(part):
			return fallback
		node = node[part]
	return float(node) if typeof(node) in [TYPE_FLOAT, TYPE_INT] else fallback


static func unit_cost(l: Dictionary) -> float:
	return _ref(l["cost_ref"], float(l.get("cost", 0.0))) if l.has("cost_ref") else float(l.get("cost", 0.0))


static func market_price(l: Dictionary) -> float:
	return _ref(l["market_ref"], float(l.get("market", 0.0))) if l.has("market_ref") else float(l.get("market", 0.0))


static func industry_name(id: String) -> String:
	return I18n.t(str(DataDB.businesses.get(id, {}).get("name", id)))


static func state(k: String) -> Dictionary:
	var pairs: Dictionary = S()["pairs"]
	if not pairs.has(k):
		pairs[k] = {"mode": "cost", "markup": 0.2, "paused": false, "seen": -1.0, "last": 0, "day": -1,
			"qty": 0.0, "revenue": 0.0, "cost": 0.0, "saving": 0.0, "trades": 0}
	return pairs[k]


## Transfer price per unit under the pair's policy.
static func price(k: String) -> float:
	var l := link(parse(k)[0])
	if l.is_empty():
		return 0.0
	var st := state(k)
	var c := unit_cost(l)
	match str(st["mode"]):
		"plus": return snappedf(c * (1.0 + float(st["markup"])), 0.0001)
		"market": return snappedf(market_price(l), 0.0001)
	return snappedf(c, 0.0001)


static func set_policy(k: String, mode: String, markup := -1.0) -> Dictionary:
	var parts := parse(k)
	var l := link(parts[0])
	if l.is_empty() or parts[1] not in l["buyers"] or mode not in MODES or (markup != -1.0 and (not is_finite(markup) or markup < 0.0 or markup > 1.0)):
		return {"ok": false, "error": I18n.t("Choose cost, cost plus or market price for a listed supply pair.")}
	var st := state(k)
	st["mode"] = mode
	if markup >= 0:
		st["markup"] = snappedf(markup, 0.01)
	return {"ok": true}


static func set_paused(k: String, paused: bool) -> Dictionary:
	var l := link(parse(k)[0])
	if l.is_empty() or bool(l.get("native", false)):
		return {"ok": false, "error": I18n.t("This supply runs with the business and cannot be paused.")}
	state(k)["paused"] = paused
	return {"ok": true}


# ------------------------------------------------------------------ feasibility
static func running(id: String) -> bool:
	var entry := Industries.find(id)
	return not entry.is_empty() and entry["sim_class"].is_running()


static func entity_of(id: String) -> String:
	if id in ["ecommerce", "consulting"]:
		return GameState.business_entity()
	var entry := Industries.find(id)
	if not entry.is_empty() and entry["sim_class"].has_method("entity"):
		var e := str(entry["sim_class"].entity())
		if e != "":
			return e
	return GameState.business_entity()


## "" when the pair can trade now, otherwise the reason (English; translate when shown).
static func why_not(l: Dictionary, buyer: String) -> String:
	if buyer not in l["buyers"] or buyer == l["seller"]:
		return "Not a supply pair."
	if not GameState.has_game():
		return "No game."
	if not running(l["seller"]):
		return "Open the supplying business first."
	if not running(buyer):
		return "Open the buying business first."
	if entity_of(l["seller"]) != entity_of(buyer):
		return "Both businesses must run on the same company's books."
	match str(l.get("requires", "")):
		"factory":
			if not Manufacturing.valid(): return "Lease Unit 12 and open the factory first."
		"van":
			if not Logistics.has_van(): return "Buy a van first."
	return ""


static func feasible(k: String) -> bool:
	var parts := parse(k)
	var l := link(parts[0])
	return not l.is_empty() and why_not(l, parts[1]) == ""


static func pairs() -> Array:
	var out: Array = []
	for l in links():
		for buyer in l["buyers"]:
			if why_not(l, buyer) != "":
				continue
			var k := key(l["id"], buyer)
			var st := state(k)
			out.append({"key": k, "link": l, "seller": l["seller"], "buyer": buyer, "state": st, "price": price(k),
				"cost": unit_cost(l), "market": market_price(l)})
	return out


## The nearest missing step toward a first supply pair, for the empty Group tab.
static func next_step() -> String:
	for l in links():
		if running(l["seller"]):
			for buyer in l["buyers"]:
				if buyer != l["seller"] and not running(buyer):
					return I18n.t("Open %s to buy from %s.") % [industry_name(buyer), industry_name(l["seller"])]
	for l in links():
		if not running(l["seller"]):
			for buyer in l["buyers"]:
				if running(buyer):
					return I18n.t("Open %s to supply %s.") % [industry_name(l["seller"]), industry_name(buyer)]
	return I18n.t("Open a second business at the Business Board to start trading inside the group.")


# ------------------------------------------------------------------ trades
## Records one internal trade of `qty` units. Both segments are posted in the seller's books; nothing touches revenue.
static func trade(k: String, qty: float, opts := {}) -> Dictionary:
	var parts := parse(k)
	var l := link(parts[0])
	if l.is_empty() or parts[1] not in l["buyers"] or not is_finite(qty) or qty <= 0:
		return {"ok": false, "error": I18n.t("Nothing to trade.")}
	var buyer: String = parts[1]
	var seller: String = l["seller"]
	var ent := str(opts.get("entity", entity_of(seller)))
	var st := state(k)
	var unit := unit_cost(l)
	var p := price(k)
	var amount := snappedf(qty * p, 0.01)
	var cost := snappedf(qty * unit, 0.01)
	if amount <= 0 and cost <= 0:
		return {"ok": false, "error": I18n.t("Nothing to trade.")}
	var avoided := 0.0
	if not bool(l.get("native", false)):
		var room := outside_spend(k, ent)
		var per_unit := market_price(l) * float(l.get("avoid", 1.0))
		if room <= 0.0 or per_unit <= 0.0:
			return {"ok": false, "error": I18n.t("No outside purchase to replace yet.")}
		qty = minf(qty, room / per_unit)
		amount = snappedf(qty * p, 0.01)
		cost = snappedf(qty * unit, 0.01)
		avoided = snappedf(qty * per_unit, 0.01)
	var good := I18n.t(str(l["good"]))
	var source_for := func(segment: String) -> Dictionary: return {"type": "internal_supply", "id": k, "segment": segment, "internal": true}
	if cost > 0:
		var pay := "cash" if Ledger.cash(ent) >= cost else "accounts_payable"
		Ledger.post(ent, I18n.t("Cost of internal supply: %s") % good, [{"acct": "cogs", "dr": cost}, {"acct": pay, "cr": cost}], source_for.call(seller))
	if amount > 0:
		Ledger.post(ent, I18n.t("Internal sale to %s: %s") % [industry_name(buyer), good], [{"acct": "ic_clearing", "dr": amount}, {"acct": "ic_revenue", "cr": amount}], source_for.call(seller))
		Ledger.post(ent, I18n.t("Internal purchase from %s: %s") % [industry_name(seller), good], [{"acct": "ic_cost", "dr": amount}, {"acct": "ic_clearing", "cr": amount}], source_for.call(buyer))
	var saving := 0.0
	if not bool(l.get("native", false)):
		# The buyer no longer pays an outside seller for the share it now takes from the group.
		if avoided > 0:
			Ledger.post(ent, I18n.t("Outside purchase avoided: %s") % good, [{"acct": "cash", "dr": avoided}, {"acct": _offset_acct(l), "cr": avoided}],
				{"type": "internal_saving", "id": k, "segment": buyer})
		saving = snappedf(avoided - cost, 0.01)
	st["qty"] = float(st["qty"]) + qty
	st["revenue"] = snappedf(float(st["revenue"]) + amount, 0.01)
	st["cost"] = snappedf(float(st["cost"]) + cost, 0.01)
	st["saving"] = snappedf(float(st["saving"]) + saving, 0.01)
	st["trades"] = int(st["trades"]) + 1
	GameState.inc_stat("internal_trades")
	return {"ok": true, "amount": amount, "cost": cost, "price": p, "saving": saving}


## What the buyer segment really paid outside on this link's accounts in the last 30 days, minus what earlier
## internal trades on the same pair already credited back. Only that much outside purchasing can be replaced.
static func outside_spend(k: String, ent: String) -> float:
	var parts := parse(k)
	var l := link(parts[0])
	var accts: Array = l.get("offset_accts", [])
	if accts.is_empty():
		return 0.0
	var t0 := Clock.now() - 30 * Clock.DAY
	var spent := 0.0
	var credited := 0.0
	for e in GameState.data["ledger"]["journal"]:
		if e["entity"] != ent or int(e["t"]) < t0:
			continue
		var src: Dictionary = e.get("source", {})
		var mine: bool = str(src.get("type", "")) == "internal_saving" and str(src.get("id", "")) == k
		var seg := str(src.get("segment", Industries.infer_segment(src, e["lines"])))
		if not mine and (seg != parts[1] or bool(src.get("internal", false))):
			continue
		for line in e["lines"]:
			if str(line["acct"]) in accts:
				if mine: credited += float(line.get("cr", 0.0))
				else: spent += float(line.get("dr", 0.0)) - float(line.get("cr", 0.0))
	return maxf(0.0, snappedf(spent - credited, 0.01))


static func _offset_acct(l: Dictionary) -> String:
	var accts: Array = l.get("offset_accts", ["cogs"])
	return str(accts[0])


# ------------------------------------------------------------------ native hooks (called by the buying/selling module)
## Hotel breakfast from the cafe kitchen. Returns true when the internal route booked it (the hotel then skips its own cost).
static func hotel_breakfast(guests: float) -> bool:
	var k := key("cafe_breakfast", "hotel")
	if guests <= 0 or not feasible(k):
		return false
	return bool(trade(k, guests, {"entity": Hotel.entity()}).get("ok", false))


## Electricity for the hotel's nightly utilities. Returns the part of `utilities` still bought from outside.
static func hotel_power(utilities: float) -> float:
	var k := key("energy_power_hotel", "hotel")
	if utilities <= 0 or not feasible(k):
		return utilities
	var l := link("energy_power_hotel")
	var market_part := utilities * float(l.get("power_share", 0.4))
	var kwh := market_part / maxf(0.0001, market_price(l))
	if not bool(trade(k, kwh, {"entity": Hotel.entity()}).get("ok", false)):
		return utilities
	return snappedf(utilities - market_part, 0.01)


# ------------------------------------------------------------------ periodic settlement
static func _driver_qty(l: Dictionary, st: Dictionary) -> float:
	var d: Dictionary = l.get("driver", {})
	if d.has("flat"):
		return float(d["flat"])
	if d.has("stat"):
		var now := GameState.stat(str(d["stat"]))
		var seen := float(st["seen"])
		st["seen"] = now
		return maxf(0.0, now - seen) * float(d.get("per", 1.0)) if seen >= 0 else 0.0
	if d.has("fn") and str(d["fn"]) == "hotel_guests_day":
		var history: Array = Hotel.S()["history"]
		return float(history[-1]["occupied"]) * float(d.get("per", 1.0)) if not history.is_empty() else 0.0
	return 0.0


static func on_hour(t: int, h: int) -> void:
	if GameState.has_game() and h == int(cfg().get("settle_hour", 22)):
		settle_all(t)


## Settles every due periodic pair once. Returns the number of trades booked.
static func settle_all(t := -1) -> int:
	if t < 0:
		t = Clock.now()
	var n := 0
	for p in pairs():
		var l: Dictionary = p["link"]
		var st: Dictionary = p["state"]
		if bool(l.get("native", false)):
			continue
		var driver: Dictionary = l.get("driver", {})
		var fresh := int(st["last"]) == 0
		if bool(st["paused"]) or (fresh and driver.has("stat")):
			# A paused pair, or a first look at a counter, only re-baselines: no backlog trades on resume.
			if driver.has("stat"):
				st["seen"] = GameState.stat(str(driver["stat"]))
			if fresh:
				st["last"] = t
			continue
		if fresh:
			st["last"] = t
		if str(l.get("cadence", "daily")) == "monthly":
			if fresh or t - int(st["last"]) < int(cfg().get("monthly_days", 30)) * Clock.DAY:
				continue
			st["last"] = t
		else:
			if int(st["day"]) == Clock.day_index():
				continue
			st["day"] = Clock.day_index()
		var qty := _driver_qty(l, st)
		if qty > 0 and bool(trade(p["key"], qty).get("ok", false)):
			n += 1
	return n


# ------------------------------------------------------------------ consolidation
## Segment P&L plus the group view: internal sales and purchases eliminated, so internal trade adds no group revenue or profit.
static func group_report(entity: String, t0: int, t1: int) -> Dictionary:
	var report := Segments.compute(entity, t0, t1)
	var totals: Dictionary = report["totals"]
	var internal_sales := float(totals["internal_revenue"])
	var internal_purchases := float(totals["internal_charge"])
	return {"rows": report["rows"], "segments_sum_revenue": snappedf(float(totals["net_revenue"]) + internal_sales, 0.01),
		"internal_sales": internal_sales, "internal_purchases": internal_purchases,
		"eliminated": snappedf(internal_sales, 0.01), "net_revenue": totals["net_revenue"], "operating_profit": totals["operating_profit"],
		"balanced": absf(internal_sales - internal_purchases) < 0.011}


static func lifetime(k: String) -> Dictionary:
	var st := state(k)
	return {"qty": st["qty"], "revenue": st["revenue"], "cost": st["cost"], "saving": st["saving"], "trades": st["trades"]}
