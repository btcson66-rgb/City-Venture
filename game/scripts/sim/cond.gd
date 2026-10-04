class_name Cond
extends RefCounted
## Tiny condition DSL shared by story objectives and events.
##   flag:x  !flag:x  visited:x  stat:name>=n  day>=n  cash<n  company_registered  !company_registered
##   has_ads  best_rating>=4.2  weekday:mon  hour>=h  has_stock  has_stock:product_id  chapter_done:id  objective_done:id
##   has_job  desk_access  carrying_parcels  listed:product_id  world_year>=n  stock_units>=n (in hand + on the way)
##   loan_capacity>=n (what Nexus Bank would lend today)  ctx:key (a true value in the event's context)


static func all(conds: Array, ctx := {}) -> bool:
	for c in conds:
		if not eval(str(c), ctx):
			return false
	return true


static func eval(expr: String, ctx := {}) -> bool:
	expr = expr.strip_edges()
	if expr == "":
		return true
	if expr.contains(" || "):
		for part in expr.split(" || "):
			if eval(part, ctx):
				return true
		return false
	if expr.begins_with("!"):
		return not eval(expr.substr(1), ctx)
	if expr.begins_with("met:"):
		return bool(GameState.data.get("npcs",{}).get(expr.substr(4),{}).get("met",false))
	if expr.begins_with("flag:"):
		return GameState.flag(expr.substr(5))
	if expr.begins_with("visited:"):
		return GameState.visited(expr.substr(8))
	if expr.begins_with("weekday:"):
		return Clock.WEEKDAYS[Clock.weekday()].to_lower() == expr.substr(8).to_lower().left(3)
	if expr.begins_with("ctx:"):
		return bool(ctx.get(expr.substr(4), false))
	if expr.begins_with("has_stock:"):
		# unreserved units of one product somewhere the player can ship from
		return Ecommerce.best_location(expr.substr(10)) != ""
	if expr.begins_with("listed:"):
		var l := Ecommerce.listing_for(expr.substr(7))
		return not l.is_empty() and bool(l.get("active", false))
	if expr.begins_with("chapter_done:"):
		return expr.substr(13) in GameState.data["story"]["chapters_done"]
	if expr.begins_with("objective_done:"):
		return expr.substr(15) in GameState.data["story"]["done"]
	if expr.begins_with("contract_ready:"):
		# enough units in stock or on the way for a tagged contract (or it's already delivered)
		var c := Contracts.by_tag(expr.substr(15))
		if c.is_empty():
			return false
		if c["status"] in ["delivered", "paid"]:
			return true
		if c["status"] != "active":
			return false
		var have := Ecommerce.available_anywhere(c["product"]) + Ecommerce.incoming_units_of(c["product"])
		return c["status"] == "active" and have >= int(c["qty"])
	if expr.begins_with("contract_closed:"):
		var c := Contracts.by_tag(expr.substr(16))
		return not c.is_empty() and GameState.data["entities"].get(c.get("seller", ""), {}).has("closed")
	if expr == "has_listed":
		return not Ecommerce.E()["listings"].is_empty() or GameState.stat("orders_placed") >= 1
	match expr:
		"popup_open":
			return PopupStore.is_open(Clock.now()) and Ecommerce.total_units_at("popup_retail")>0
		"forecast_ok":
			return Forecast.ok(GameState.business_entity())
		"company_registered":
			return GameState.company_id() != ""
		"has_ads":
			return Ecommerce.total_ad_budget() > 0.0
		"has_stock":
			return Ecommerce.total_units() > 0
		"has_job":
			return Careers.current_job() != ""
		"desk_access":
			return Living.has_desk_access()
		"carrying_parcels":
			return Ecommerce.carried_count() > 0
	var m := _cmp(expr)
	if m.is_empty():
		push_warning("Cond: cannot parse " + expr)
		return false
	var lhs := _value(m["name"], ctx)
	var rhs := float(m["value"])
	match m["op"]:
		">=":
			return lhs >= rhs
		"<=":
			return lhs <= rhs
		">":
			return lhs > rhs
		"<":
			return lhs < rhs
		"==":
			return is_equal_approx(lhs, rhs)
		"!=":
			return not is_equal_approx(lhs, rhs)
	return false


static func _cmp(expr: String) -> Dictionary:
	for op in [">=", "<=", "==", "!=", ">", "<"]:
		var i := expr.find(op)
		if i > 0:
			return {"name": expr.left(i).strip_edges(), "op": op, "value": expr.substr(i + op.length()).strip_edges()}
	return {}


static func _value(name: String, ctx: Dictionary) -> float:
	if name.begins_with("metric:"):return SynergyMetrics.value(name.substr(7))
	if name.begins_with("stat:"):
		return GameState.stat(name.substr(5))
	match name:
		"world_year":
			return World.year()
		"stock_units":
			return Ecommerce.total_units() + Ecommerce.incoming_units()
		"loan_capacity":
			var lo := Bank.offer()
			return float(lo["max"]) if lo["ok"] else 0.0
		"day":
			return Clock.day_index()
		"hour":
			return Clock.hour()
		"cash":
			return Ledger.cash(ctx.get("entity", GameState.business_entity()))
		"personal_cash":
			return Ledger.cash("player")
		"best_rating":
			var best := 0.0
			for l in GameState.data["ecommerce"]["listings"].values():
				if int(l.get("rating_n", 0)) >= 3:
					best = maxf(best, Ecommerce.rating(l))
			return best
	return GameState.stat(name)
