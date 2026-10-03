class_name Cafe
extends RefCounted
## Your own café in Old Town. Plays like a shop, not a warehouse: foot traffic × conversion × ticket, and the rent
## is due whether anyone walks in or not.
##  1. Lease the corner unit from Mr. Okafor, fit it out, and get the food handling licence at City Hall.
##  2. Keep coffee supplies in (packs from Old Town Roasters, next morning) and set a daily pastry order (the bakery
##     delivers at opening; whatever isn't sold by closing is binned).
##  3. Open Mon–Sat 7:00–17:00. Someone has to be behind the counter: baristas on staff, or you, working the counter
##     yourself (the barista minigame). Each hour: passers-by × conversion (price and rating) → customers, capped by
##     how many cups the counter can make and by the supplies left.
##  4. The till is banked at closing through the card reader. The rating (★) follows service: queues that walk out,
##     running out of coffee, and prices far above the street's all pull it down; good shifts pull it up.
## State: GameState.data["cafe"]. Money: revenue, cogs (supplies and pastries, booked on delivery),
## exp:platform_fees (card fees), exp:fitout, exp:advertising, exp:rent_shop (through the lease).

const SUPPLIER := "old_town_roasters"


static func S() -> Dictionary:
	if not GameState.data.has("cafe"):
		GameState.data["cafe"] = {"fit_ready": -1, "permit_ready": -1, "supplies": 0, "incoming": 0, "pastries": 0,
			"pastry_order": 20, "prices": {"coffee": 4.2, "pastry": 3.8}, "ads": 0.0, "rating": float(cfg().get("rating_start", 3.4)),
			"owner_from": -1, "owner_until": -1, "today": {}, "days": [], "name": "", "first_sale": -1, "shut_warned": -1}
	return GameState.data["cafe"]


static func cfg() -> Dictionary:
	return DataDB.economy.get("cafe", {})


static func item(id: String) -> Dictionary:
	return cfg().get("items", {}).get(id, {})


static func property_id() -> String:
	return str(cfg().get("property", "corner_cafe"))


static func leased() -> bool:
	return GameState.has_game() and Living.has_lease(property_id())


static func entity() -> String:
	var ls: Dictionary = GameState.data["living"]["leases"].get(property_id(), {})
	var e := str(ls.get("entity", ""))
	return e if e != "" and GameState.data["entities"].has(e) else GameState.business_entity()


static func display_name() -> String:
	if str(S().get("name", "")) != "":
		return str(S()["name"])
	var c := GameState.company_id()
	return I18n.t("%s Café") % (GameState.entity_name(c) if c != "" else I18n.t("Corner"))


static func set_name(n: String) -> void:
	S()["name"] = n.strip_edges().left(28)
	EventBus.world_refresh.emit()


# ------------------------------------------------------------------ setup
static func fitted() -> bool:
	return int(S()["fit_ready"]) >= 0 and Clock.now() >= int(S()["fit_ready"])


static func fitting() -> bool:
	return int(S()["fit_ready"]) >= 0 and Clock.now() < int(S()["fit_ready"])


static func permitted() -> bool:
	return GameState.flag("food_permit")


static func permit_pending() -> bool:
	return not permitted() and int(S()["permit_ready"]) > Clock.now()


## Everything needed to open the doors: the lease, the fit-out and the licence.
static func ready_to_open() -> bool:
	return leased() and fitted() and permitted()


## What still stands between you and your first customer ("" = nothing).
static func open_block() -> String:
	if not leased():
		return "lease the corner unit in Old Town (Okafor Lettings)"
	if not fitted():
		return "the fit-out is still going" if fitting() else "fit out the unit"
	if not permitted():
		return "the food licence is being processed" if permit_pending() else "get the food handling licence at City Hall"
	return ""


static func fit_out() -> Dictionary:
	if not leased():
		return {"ok": false, "error": "Lease the unit first."}
	if int(S()["fit_ready"]) >= 0:
		return {"ok": false, "error": "The unit is already fitted out."}
	var cost := float(cfg().get("fitout_cost", 5800))
	if Ledger.cash(entity()) < cost:
		return {"ok": false, "error": I18n.t("The fit-out costs %s.") % Fmt.money0(cost)}
	Ledger.expense(entity(), "fitout", cost, I18n.t("Café fit-out: espresso machine, counter, tables"), {"segment": "cafe", "type": "cafe"})
	S()["fit_ready"] = Clock.now() + Clock.DAY
	GameState.timeline(I18n.t("Fitted out %s.") % display_name(), "business")
	return {"ok": true, "cost": cost, "ready": int(S()["fit_ready"])}


## City Hall: the food handling licence. Needs the premises (the lease); ready two days later.
static func permit_block() -> String:
	if GameState.company_id() == "":
		return "register a company first"
	if not leased():
		return "lease the café unit first"
	return ""


static func apply_permit() -> Dictionary:
	if permitted():
		return {"ok": false, "error": "You already have the licence."}
	if permit_pending():
		return {"ok": false, "error": "Your application is being processed."}
	var why := permit_block()
	if why != "":
		return {"ok": false, "error": why}
	var fee := float(cfg().get("permit_fee", 280))
	if Ledger.cash(entity()) < fee:
		return {"ok": false, "error": I18n.t("The licence fee is %s.") % Fmt.money0(fee)}
	Ledger.expense(entity(), "registration", fee, "Food handling licence", {"segment": "cafe", "type": "permit"})
	S()["permit_ready"] = Clock.now() + int(cfg().get("permit_hours", 48)) * 60
	Sim.schedule(int(S()["permit_ready"]), "cafe.permit", {})
	return {"ok": true, "fee": fee, "ready": int(S()["permit_ready"])}


# ------------------------------------------------------------------ running it
static func pack(id: String) -> Dictionary:
	for p in cfg().get("supply_packs", []):
		if p["id"] == id:
			return p
	return {}


static func pack_cost(id: String) -> float:
	return snappedf(float(pack(id).get("cost", 0.0)) * World.cost_mult(SUPPLIER), 1.0)


## Coffee, milk and cups from Old Town Roasters: delivered at 6:00 the next morning.
static func order_supplies(id: String) -> Dictionary:
	var p := pack(id)
	if p.is_empty():
		return {"ok": false, "error": "Unknown supply pack."}
	if not leased():
		return {"ok": false, "error": "Lease the café unit first."}
	if int(S()["supplies"]) + int(S()["incoming"]) + int(p["cups"]) > int(cfg().get("supplies_max", 1200)):
		return {"ok": false, "error": "The storeroom can't take that much."}
	var cost := pack_cost(id)
	if Ledger.cash(entity()) < cost:
		return {"ok": false, "error": I18n.t("You need %s.") % Fmt.money0(cost)}
	Ledger.post(entity(), I18n.t("Old Town Roasters: supplies for %d cups") % int(p["cups"]),
		[{"acct": "cogs", "dr": cost}, {"acct": "cash", "cr": cost}], {"segment": "cafe", "type": "cafe"})
	S()["incoming"] = int(S()["incoming"]) + int(p["cups"])
	var t := Clock.now() - Clock.now() % Clock.DAY + Clock.DAY + 6 * 60
	Sim.schedule(t, "cafe.supplies", {"cups": int(p["cups"])})
	return {"ok": true, "cost": cost, "eta": t}


static func set_price(id: String, p: float) -> void:
	var it := item(id)
	S()["prices"][id] = clampf(snappedf(p, 0.05), float(it.get("min", 1.0)), float(it.get("max", 10.0)))


static func price(id: String) -> float:
	return float(S()["prices"].get(id, item(id).get("ref_price", 4.0)))


static func set_pastry_order(n: int) -> void:
	S()["pastry_order"] = clampi(n, 0, int(cfg().get("pastry_order_max", 80)))


static func set_ads(per_day: float) -> void:
	S()["ads"] = clampf(per_day, 0.0, 200.0)


static func open_day(t := -1) -> bool:
	var wd := Clock.weekday(t)
	for d in cfg().get("open_days", [1, 2, 3, 4, 5, 6]):
		if int(d) == wd:   # JSON numbers are floats: compare as ints
			return true
	return false


## True while the doors are open (an open day, between opening and closing time, fitted and licensed).
static func is_open_now() -> bool:
	var h := Clock.hour()
	return ready_to_open() and open_day() and h >= int(cfg().get("open_hour", 7)) and h < int(cfg().get("close_hour", 17))


# ------------------------------------------------------------------ demand model
static func _price_factor(id: String) -> float:
	var ref := float(item(id).get("ref_price", 4.0))
	return clampf(pow(ref / maxf(0.5, price(id)), float(cfg().get("elasticity", 1.6))), 0.15, 1.9)


static func rating_factor() -> float:
	return 0.55 + 0.13 * float(S()["rating"])


static func ads_factor() -> float:
	return (1.0 + 0.35 * (1.0 - exp(-float(S()["ads"]) / 25.0))) * Media.demand_boost("cafe")


## Expected customers who want a coffee in hour `hh` (before the counter's capacity and the supplies).
static func expected_demand(hh: int, saturday := false) -> float:
	var share := float(cfg().get("hour_share", {}).get(str(hh), 0.0))
	var foot := float(cfg().get("footfall_day", 210)) * share * (float(cfg().get("saturday_mult", 1.3)) if saturday else 1.0)
	return foot * Replay.demand("cafe") * float(cfg().get("base_conversion", 0.3)) * _price_factor("coffee") * rating_factor() * ads_factor()


## A normal weekday at today's prices, rating and flyers.
static func expected_day_demand() -> float:
	var n := 0.0
	for hh in range(int(cfg().get("open_hour", 7)), int(cfg().get("close_hour", 17))):
		n += expected_demand(hh)
	return n


static func pastry_attach() -> float:
	return clampf(float(item("pastry").get("attach", 0.35)) * _price_factor("pastry"), 0.0, 0.9)


## Baristas on staff behind the counter at minute t.
static func baristas_at(t: int) -> Array:
	return Staff.people().filter(func(p): return p["role"] == "barista" and Staff.is_working(p, t))


static func barista_capacity(t: int) -> float:
	var c := 0.0
	for p in baristas_at(t):
		c += float(cfg().get("barista_cups_hour", 14)) * Staff.output(p)
	return c


## Fraction of the hour [t0, t0+60) you spent behind the counter yourself.
static func owner_share(t0: int) -> float:
	var a := maxi(t0, int(S()["owner_from"]))
	var b := mini(t0 + 60, int(S()["owner_until"]))
	return clampf((b - a) / 60.0, 0.0, 1.0)


static func counter_block() -> String:
	if not leased():
		return "not your café (yet)"
	var why := open_block()
	if why != "":
		return why
	if not is_open_now():
		return "the café is closed now"
	if int(S()["supplies"]) <= 0:
		return "no coffee supplies"
	return ""


## You work the counter for a couple of hours (after the barista minigame, `score` 0..1): the café can open without
## staff, you add a pair of hands when it's busy, and a good shift lifts the rating.
static func owner_shift(score: float) -> Dictionary:
	var why := counter_block()
	if why != "":
		return {"ok": false, "error": why}
	var mins := int(cfg().get("owner_shift_hours", 2)) * 60
	var s := S()
	s["owner_from"] = Clock.now()
	s["owner_until"] = Clock.now() + mins
	var td := _today()
	td["owner_score"] = float(td.get("owner_score", 0.0)) + clampf(score, 0.0, 1.0)
	td["owner_shifts"] = int(td.get("owner_shifts", 0)) + 1
	GameState.inc_stat("cafe_owner_shifts")
	var before := int(td.get("served", 0))
	Clock.advance(mins)
	return {"ok": true, "served": int(_today().get("served", 0)) - before}


# ------------------------------------------------------------------ clock
static func _today() -> Dictionary:
	var s := S()
	if int(s["today"].get("d", -1)) != Clock.day_index():
		s["today"] = {"d": Clock.day_index(), "served": 0, "pastries": 0, "rev": 0.0, "demand": 0, "queue_lost": 0,
			"stock_lost": 0, "open_hours": 0, "shut_hours": 0, "waste": 0}
	return s["today"]


static func on_hour(t: int, h: int) -> void:
	if not GameState.data.has("cafe") or not leased():
		return
	var oh := int(cfg().get("open_hour", 7))
	var ch := int(cfg().get("close_hour", 17))
	if not ready_to_open() or not open_day(t - 60):
		return
	if h == oh:
		_open_doors()
	elif h > oh and h <= ch:
		_serve_hour(t - 60, h - 1)
		if h == ch:
			_close_day()


static func _open_doors() -> void:
	var s := S()
	_today()
	var n := int(s["pastry_order"])
	if n > 0:
		var cost := snappedf(n * float(item("pastry").get("unit_cost", 1.3)) * World.cost_mult(SUPPLIER), 0.01)
		Ledger.post(entity(), I18n.t("Bakery delivery: %d pastries") % n, [{"acct": "cogs", "dr": cost}, {"acct": "cash", "cr": cost}], {"segment": "cafe", "type": "cafe"})
		s["pastries"] = n
	if float(s["ads"]) > 0.0:
		Ledger.expense(entity(), "advertising", float(s["ads"]), I18n.t("Flyers and a board for %s") % display_name(), {"segment": "cafe", "type": "cafe"})


static func _serve_hour(t0: int, hh: int) -> void:
	var s := S()
	var td := _today()
	var cap := barista_capacity(t0) + float(cfg().get("owner_cups_hour", 16)) * owner_share(t0)
	if cap < 0.5:
		td["shut_hours"] = int(td["shut_hours"]) + 1
		return
	td["open_hours"] = int(td["open_hours"]) + 1
	var want := GameState.poisson(expected_demand(hh, Clock.weekday(t0) == 6))
	var can := mini(want, int(round(cap)))
	var served := mini(can, int(s["supplies"]))
	var ps := mini(int(s["pastries"]), GameState.poisson(served * pastry_attach()))
	s["supplies"] = int(s["supplies"]) - served
	s["pastries"] = int(s["pastries"]) - ps
	td["demand"] = int(td["demand"]) + want
	td["served"] = int(td["served"]) + served
	td["pastries"] = int(td["pastries"]) + ps
	td["queue_lost"] = int(td["queue_lost"]) + (want - can)
	td["stock_lost"] = int(td["stock_lost"]) + (can - served)
	td["rev"] = snappedf(float(td["rev"]) + served * price("coffee") + ps * price("pastry"), 0.01)
	if served > 0 and int(s["first_sale"]) < 0:
		s["first_sale"] = Clock.now()
		GameState.set_flag("cafe_first_sale")
		GameState.timeline(I18n.t("%s served its first customer.") % display_name(), "milestone")
		EventBus.notify.emit(I18n.t("%s served its first customer!") % display_name(), "good", "coffee")


static func _close_day() -> void:
	var s := S()
	var td := _today()
	td["waste"] = int(s["pastries"])
	s["pastries"] = 0
	var gross := float(td["rev"])
	if gross > 0.0:
		var fee := snappedf(gross * float(cfg().get("card_fee", 0.019)), 0.01)
		Ledger.post(entity(), I18n.t("%s till: %d customers") % [display_name(), int(td["served"])],
			[{"acct": "cash", "dr": gross - fee}, {"acct": "exp:platform_fees", "dr": fee}, {"acct": "revenue", "cr": gross}], {"segment": "cafe", "type": "cafe"})
	if int(td["open_hours"]) > 0:
		_update_rating(td)
		GameState.inc_stat("cafe_customers", int(td["served"]))
		GameState.inc_stat("cafe_days_open")
		var msg := I18n.t("%s closed: %d customers, %s in the till.") % [display_name(), int(td["served"]), Fmt.money0(gross)]
		if int(td["queue_lost"]) > 0:
			msg += " " + I18n.t("%d walked out of the queue.") % int(td["queue_lost"])
		if int(td["stock_lost"]) > 0:
			msg += " " + I18n.t("Ran out of coffee for %d.") % int(td["stock_lost"])
		if int(td["waste"]) > 0:
			msg += " " + I18n.t("%d pastries binned.") % int(td["waste"])
		EventBus.notify.emit(msg, "info", "coffee")
	elif int(s["shut_warned"]) != Clock.day_index():
		s["shut_warned"] = Clock.day_index()
		EventBus.notify.emit(I18n.t("%s stayed shut today: nobody was behind the counter. Hire a barista (People tab) or work the counter yourself.") % display_name(), "bad", "coffee")
	var days: Array = s["days"]
	var rec: Dictionary = td.duplicate()
	rec["rating"] = snappedf(float(s["rating"]), 0.01)
	days.append(rec)
	while days.size() > 60:
		days.pop_front()
	GameState.data["stats"]["cafe_rating"] = float(s["rating"])


## The rating drifts toward how today felt to customers.
static func _update_rating(td: Dictionary) -> void:
	var s := S()
	var want := maxf(1.0, float(td["demand"]))
	var service := 0.62
	if int(td.get("owner_shifts", 0)) > 0:
		service = lerpf(service, float(td["owner_score"]) / int(td["owner_shifts"]), 0.6)
	var q := service - 0.9 * float(td["queue_lost"]) / want - (0.25 if int(td["stock_lost"]) > 0 else 0.0)
	q -= maxf(0.0, price("coffee") / float(item("coffee").get("ref_price", 4.2)) - 1.2) * 0.8
	q += 0.08 if int(td["pastries"]) > 0 else 0.0
	var target := clampf(q, 0.0, 1.0) * 5.0
	s["rating"] = clampf(float(s["rating"]) + (target - float(s["rating"])) * float(cfg().get("rating_speed", 0.12)), 1.0, 5.0)


static func last_days(n: int, key: String) -> float:
	var t := 0.0
	var days: Array = S()["days"]
	for i in range(maxi(0, days.size() - n), days.size()):
		t += float(days[i].get(key, 0))
	return t


static func handle(kind: String, p: Dictionary) -> void:
	match kind:
		"cafe.supplies":
			var n := int(p.get("cups", 0))
			S()["incoming"] = maxi(0, int(S()["incoming"]) - n)
			S()["supplies"] = int(S()["supplies"]) + n
			EventBus.notify.emit(I18n.t("Old Town Roasters delivered supplies for %d cups.") % n, "info", "coffee")
		"cafe.permit":
			if not permitted() and int(S()["permit_ready"]) <= Clock.now():
				GameState.set_flag("food_permit")
				GameState.timeline("Food handling licence granted.", "business")
				EventBus.notify.emit("City Hall: your food handling licence is approved.", "good", "civic")


static func is_running() -> bool:
	return leased()


static func os_tab() -> Dictionary:
	return {"id":"cafe", "label":"Café", "icon":"coffee", "method":"_tab_cafe", "order":3}


static func board_detail() -> Callable:
	return IndustryViews.cafe


static func segment_tag() -> String:
	return "cafe"


static func on_company_closed(ent: String) -> void:
	if entity() == ent:
		S()["owner_until"] = -1
		S()["owner_from"] = -1
