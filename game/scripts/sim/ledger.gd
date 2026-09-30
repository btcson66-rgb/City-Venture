class_name Ledger
extends RefCounted
## Double-entry bookkeeping. Every money movement in the game goes through post().
## balance(acct) = Σdebit − Σcredit. Revenue/liability/equity balances are therefore negative.
##
## Accounts:
##   assets       cash, marketplace_balance, accounts_receivable, inventory, inventory_in_transit,
##                goods_out, deposits, investments
##   liabilities  accounts_payable
##   equity       equity
##   income       revenue, refunds (contra), other_income
##   costs        cogs, exp:<category>

const EXPENSE_CATEGORIES := ["advertising", "shipping", "platform_fees", "packaging", "photography", "registration",
	"rent_office", "coworking", "inventory_writeoff", "bank_fees", "late_fees", "rent_home", "living", "coffee", "transport",
	"clothing", "dining", "penalties", "payroll", "recruiting", "interest", "servers", "rent_shop", "rent_warehouse", "fitout",
	"fuel", "vehicle", "insurance", "other"]
const OPEX_BUSINESS := ["advertising", "shipping", "platform_fees", "packaging", "photography", "registration",
	"rent_office", "coworking", "inventory_writeoff", "bank_fees", "late_fees", "penalties", "payroll", "recruiting", "interest",
	"servers", "rent_shop", "rent_warehouse", "fitout", "fuel", "vehicle", "insurance", "other"]
## Rent on business premises, whatever the kind (office, shop, warehouse): one line on the month-end report.
const PREMISES_RENT := ["rent_office", "rent_shop", "rent_warehouse"]
const PERSONAL := ["rent_home", "living", "coffee", "transport", "clothing", "dining"]
## How each expense category reads on a report (translated through the catalogue).
const CATEGORY_NAMES := {"advertising": "Advertising", "shipping": "Shipping", "platform_fees": "Platform fees",
	"packaging": "Packaging", "photography": "Photography", "registration": "Registration fees", "rent_office": "Office rent",
	"coworking": "Co-working", "inventory_writeoff": "Inventory write-off", "bank_fees": "Bank fees", "late_fees": "Late fees",
	"rent_home": "Home rent", "living": "Living costs", "coffee": "Coffee", "transport": "Transport", "clothing": "Clothing",
	"dining": "Dining", "penalties": "Penalties", "payroll": "Payroll", "recruiting": "Recruiting", "interest": "Interest",
	"servers": "Servers", "rent_shop": "Shop rent", "rent_warehouse": "Warehouse rent", "fitout": "Fit-out & equipment",
	"fuel": "Fuel", "vehicle": "Vehicles & upkeep", "insurance": "Insurance", "other": "Other"}


static func category_name(k: String) -> String:
	return I18n.t(str(CATEGORY_NAMES.get(k, k.replace("_", " ").capitalize())))


static func _L() -> Dictionary:
	return GameState.data["ledger"]


static func post(entity: String, memo: String, lines: Array, source := {}) -> Dictionary:
	var dr := 0.0
	var cr := 0.0
	var clean: Array = []
	for l in lines:
		var d := snappedf(float(l.get("dr", 0.0)), 0.01)
		var c := snappedf(float(l.get("cr", 0.0)), 0.01)
		if is_zero_approx(d) and is_zero_approx(c):
			continue
		dr += d
		cr += c
		var e := {"acct": l["acct"]}
		if d != 0.0:
			e["dr"] = d
		if c != 0.0:
			e["cr"] = c
		clean.append(e)
	assert(absf(dr - cr) < 0.011, "Unbalanced journal entry: %s (dr %.2f cr %.2f)" % [memo, dr, cr])
	if clean.is_empty():
		return {}
	var L := _L()
	L["seq"] = int(L["seq"]) + 1
	var entry := {"n": L["seq"], "t": Clock.now(), "entity": entity, "memo": memo, "source": source, "lines": clean}
	L["journal"].append(entry)
	if not L["balances"].has(entity):
		L["balances"][entity] = {}
	var bal: Dictionary = L["balances"][entity]
	var cash_delta := 0.0
	for e in clean:
		var v := float(e.get("dr", 0.0)) - float(e.get("cr", 0.0))
		bal[e["acct"]] = snappedf(float(bal.get(e["acct"], 0.0)) + v, 0.01)
		if e["acct"] == "cash":
			cash_delta += v
	EventBus.ledger_posted.emit(entry)
	if cash_delta != 0.0:
		EventBus.cash_changed.emit(entity, cash_delta)
	return entry


static func balance(entity: String, acct: String) -> float:
	return float(_L()["balances"].get(entity, {}).get(acct, 0.0))


static func cash(entity: String) -> float:
	return balance(entity, "cash")


## Balance of an account as of absolute minute t (inclusive of entries at t-1 and before).
static func balance_at(entity: String, acct: String, t: int) -> float:
	var s := 0.0
	for e in _L()["journal"]:
		if int(e["t"]) >= t:
			break
		if e["entity"] != entity:
			continue
		for l in e["lines"]:
			if l["acct"] == acct:
				s += float(l.get("dr", 0.0)) - float(l.get("cr", 0.0))
	return snappedf(s, 0.01)


## Sum of movement per account for entries with t0 <= t < t1.
static func movements(entity: String, t0: int, t1: int) -> Dictionary:
	var out := {}
	var j: Array = _L()["journal"]
	for i in range(j.size() - 1, -1, -1):
		var e: Dictionary = j[i]
		var t := int(e["t"])
		if t < t0:
			break
		if t >= t1 or e["entity"] != entity:
			continue
		for l in e["lines"]:
			out[l["acct"]] = float(out.get(l["acct"], 0.0)) + float(l.get("dr", 0.0)) - float(l.get("cr", 0.0))
	return out


## Operating cash flow since t0 (ignores opening balances and owner capital moves).
static func operating_cash_since(entity: String, t0: int) -> float:
	var v := 0.0
	var j: Array = _L()["journal"]
	for i in range(j.size() - 1, -1, -1):
		var e: Dictionary = j[i]
		if int(e["t"]) < t0:
			break
		if e["entity"] != entity or str(e.get("source", {}).get("type", "")) in ["opening", "capital", "transfer"]:
			continue
		v += entry_cash(e)
	return v


static func lifetime_gross_profit(entity: String) -> float:
	var b: Dictionary = _L()["balances"].get(entity, {})
	return -float(b.get("revenue", 0.0)) - float(b.get("refunds", 0.0)) - float(b.get("cogs", 0.0))


static func entries(entity: String, limit := 50) -> Array:
	var out: Array = []
	var j: Array = _L()["journal"]
	for i in range(j.size() - 1, -1, -1):
		if j[i]["entity"] == entity:
			out.append(j[i])
			if out.size() >= limit:
				break
	return out


## Cash effect of an entry (for statements).
static func entry_cash(e: Dictionary) -> float:
	var v := 0.0
	for l in e["lines"]:
		if l["acct"] == "cash":
			v += float(l.get("dr", 0.0)) - float(l.get("cr", 0.0))
	return v


## Helpers for common postings --------------------------------------------------
static func expense(entity: String, category: String, amount: float, memo: String, source := {}, pay_from := "cash") -> Dictionary:
	return post(entity, memo, [{"acct": "exp:" + category, "dr": amount}, {"acct": pay_from, "cr": amount}], source)


static func check_balanced() -> bool:
	for entity in _L()["balances"]:
		var s := 0.0
		for a in _L()["balances"][entity]:
			s += float(_L()["balances"][entity][a])
		if absf(s) > 0.05:
			return false
	return true
