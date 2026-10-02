class_name Logistics
extends RefCounted
## Your own van and the delivery business (Harbor, Pier 7). Thin margins: every hour and every litre counts.
##  1. Buy a used van from Sam Okoro at Dockside Motors (company account → exp:vehicle). Insurance is charged monthly
##     (exp:insurance).
##  2. Two ways to earn with it:
##     - Ship your own ecommerce parcels: Ecommerce's pack & ship flow gets an "Own van" option (fuel per parcel →
##       exp:fuel, same-day delivery, and it takes your time).
##     - Delivery runs: every morning a few local runs are posted (client, 4–6 stops, pay, deadline). Accept one in
##       Company OS → Logistics and drive it in the route-planning minigame (RouteGame): the shorter your route the
##       better the pay and the less fuel. Paid into the company account as revenue; fuel → exp:fuel, wear →
##       exp:vehicle. Late runs pay less; a run left undone long after its deadline is cancelled.
##  3. A Van Driver (Staff) takes one posted run every workday from 8:00 and plans the route less well than you do.
## The Pier 7 warehouse (property `pier7_warehouse`) is a separate lease: a 5,000-unit stock location for ecommerce.
## The route model is a schematic city map (data/economy/logistics.json → map, places): straight legs, crossing the
## river only at a bridge. Route length in map pixels × km_per_px = kilometres; the best order is found by brute force.
## State: GameState.data["logistics"]. Money: revenue, exp:vehicle, exp:insurance, exp:fuel.


static func S() -> Dictionary:
	if not GameState.data.has("logistics"):
		GameState.data["logistics"] = {"van": {"owned": false, "bought": -1, "entity": "", "ins_day": 1, "km": 0.0},
			"jobs": {}, "history": [], "seq": 1, "driver_day": {}}
	return GameState.data["logistics"]


static func cfg() -> Dictionary:
	return DataDB.economy.get("logistics", {})


static func runs_cfg() -> Dictionary:
	return cfg().get("runs", {})


static func van_cfg() -> Dictionary:
	return cfg().get("van", {})


static func property_id() -> String:
	return str(cfg().get("property", "pier7_warehouse"))


static func warehouse_leased() -> bool:
	return GameState.has_game() and Living.has_lease(property_id())


static func has_van() -> bool:
	return GameState.has_game() and bool(GameState.data.get("logistics", {}).get("van", {}).get("owned", false))


## The company that owns the van (the books its runs and running costs go on).
static func entity() -> String:
	var e := str(S()["van"].get("entity", ""))
	return e if e != "" and GameState.data["entities"].has(e) else GameState.business_entity()


# ------------------------------------------------------------------ the van
## What still stands between you and the keys ("" = nothing).
static func buy_block() -> String:
	if has_van():
		return "you already own the van"
	if GameState.company_id() == "":
		return "register a company first"
	if not GameState.flag("business_account_opened"):
		return "open a business bank account first"
	var need := float(van_cfg().get("price", 9800)) + float(van_cfg().get("insurance_month", 165))
	if Ledger.cash(GameState.business_entity()) < need:
		return I18n.t("the company account needs %s (van and first month's insurance)") % Fmt.money0(need)
	return ""


## Buy the van from the company account: the price is a vehicle expense, plus the first month's insurance.
static func buy_van() -> Dictionary:
	var why := buy_block()
	if why != "":
		return {"ok": false, "error": why}
	var ent := GameState.business_entity()
	var price := float(van_cfg().get("price", 9800))
	var ins := float(van_cfg().get("insurance_month", 165))
	Ledger.expense(ent, "vehicle", price, I18n.t("Dockside Motors: %s") % I18n.t(str(van_cfg().get("name", "Used panel van"))), {"type": "vehicle"})
	Ledger.expense(ent, "insurance", ins, I18n.t("Van insurance: first month"), {"type": "insurance"})
	var v: Dictionary = S()["van"]
	v["owned"] = true
	v["bought"] = Clock.now()
	v["entity"] = ent
	v["ins_day"] = mini(28, int(Clock.date()["day"]))
	v["km"] = 0.0
	GameState.set_flag("van_owned")
	GameState.inc_stat("vans_bought")
	GameState.timeline(I18n.t("Bought a used van from Sam Okoro at Dockside Motors for %s.") % Fmt.money0(price), "business")
	EventBus.world_refresh.emit()
	return {"ok": true, "cost": price, "insurance": ins}


## The company closes: the van is sold at auction (returns the money it fetched).
static func on_company_closed(ent: String) -> float:
	if not has_van() or str(S()["van"].get("entity", "")) != ent:
		return 0.0
	var got := snappedf(float(van_cfg().get("price", 9800)) * float(van_cfg().get("resale", 0.55)), 0.01)
	Ledger.post(ent, I18n.t("Van sold at auction"), [{"acct": "cash", "dr": got}, {"acct": "other_income", "cr": got}], {"type": "liquidation"})
	S()["van"]["owned"] = false
	S()["jobs"] = {}
	GameState.set_flag("van_owned", false)
	return got


# ------------------------------------------------------------------ what it costs to run
## Fuel gets dearer with the era's shipping index (couriers add fuel surcharges, and so do the pumps).
static func fuel_mult() -> float:
	return 1.0 + float(cfg().get("fuel", {}).get("era_sensitivity", 0.5)) * (World.shipping_index() - 1.0)


static func fuel_cost_per_km() -> float:
	var f: Dictionary = cfg().get("fuel", {})
	return float(f.get("l_per_km", 0.14)) * float(f.get("price_l", 2.1)) * fuel_mult() * Macro.costs()


static func upkeep_per_km() -> float:
	return float(cfg().get("fuel", {}).get("upkeep_per_km", 0.07))


static func fuel_l_per_km() -> float:
	return float(cfg().get("fuel", {}).get("l_per_km", 0.14))


# ------------------------------------------------------------------ the map and the route model
static func map_cfg() -> Dictionary:
	return cfg().get("map", {})


static func map_size() -> Vector2:
	var s: Array = map_cfg().get("size", [580, 236])
	return Vector2(float(s[0]), float(s[1]))


static func depot() -> Vector2:
	var d: Dictionary = map_cfg().get("depot", {"x": 58, "y": 192})
	return Vector2(float(d["x"]), float(d["y"]))


static func places() -> Array:
	return cfg().get("places", [])


static func place(id: String) -> Dictionary:
	for p in places():
		if str(p["id"]) == id:
			return p
	return {}


static func place_pos(id: String) -> Vector2:
	var p := place(id)
	return Vector2(float(p.get("x", 0)), float(p.get("y", 0)))


static func place_name(id: String) -> String:
	return I18n.t(str(place(id).get("name", id)))


static func river() -> Array:
	var out: Array = []
	for pt in map_cfg().get("river", []):
		out.append(Vector2(float(pt[0]), float(pt[1])))
	return out


static func bridges() -> Array:
	var out: Array = []
	for pt in map_cfg().get("bridges", []):
		out.append(Vector2(float(pt[0]), float(pt[1])))
	return out


## The river's x at height y (it runs top-right to bottom-left, so x is a function of y).
static func river_x(y: float) -> float:
	var pts := river()
	if pts.is_empty():
		return 1e9
	if y <= pts[0].y:
		return pts[0].x
	for i in range(1, pts.size()):
		if y <= pts[i].y:
			var a: Vector2 = pts[i - 1]
			var b: Vector2 = pts[i]
			return lerpf(a.x, b.x, (y - a.y) / maxf(0.001, b.y - a.y))
	return pts[pts.size() - 1].x


## Which bank a point is on (true = the far side of the river from the depot).
static func across(p: Vector2) -> bool:
	return p.x >= river_x(p.y)


## The way from a to b: straight, or via the nearest-in-total bridge when the river is between them.
static func leg(a: Vector2, b: Vector2) -> Array:
	if across(a) == across(b):
		return [a, b]
	var best: Array = []
	var best_len := INF
	for br in bridges():
		var l: float = a.distance_to(br) + br.distance_to(b)
		if l < best_len:
			best_len = l
			best = [a, br, b]
	return best if not best.is_empty() else [a, b]


static func leg_px(a: Vector2, b: Vector2) -> float:
	var pts := leg(a, b)
	var l := 0.0
	for i in range(1, pts.size()):
		l += (pts[i - 1] as Vector2).distance_to(pts[i])
	return l


## Points along a whole route: depot → stops in `order` (indices into `stops`) → depot.
static func route_points(stops: Array, order: Array) -> Array:
	var out: Array = [depot()]
	var cur := depot()
	for i in order:
		var nxt := place_pos(str(stops[int(i)]))
		out.append_array(leg(cur, nxt).slice(1))
		cur = nxt
	out.append_array(leg(cur, depot()).slice(1))
	return out


static func route_px(stops: Array, order: Array) -> float:
	var pts := route_points(stops, order)
	var l := 0.0
	for i in range(1, pts.size()):
		l += (pts[i - 1] as Vector2).distance_to(pts[i])
	return l


static func valid_order(stops: Array, order: Array) -> bool:
	if order.size() != stops.size():
		return false
	var seen := {}
	for i in order:
		var k := int(i)
		if k < 0 or k >= stops.size() or seen.has(k):
			return false
		seen[k] = true
	return true


## The shortest round trip through every stop, by trying every order (at most 6! = 720 for a run).
static func best_order(stops: Array) -> Dictionary:
	var pts: Array = [depot()]
	for s in stops:
		pts.append(place_pos(str(s)))
	var m: Array = []
	for i in pts.size():
		var row: Array = []
		for j in pts.size():
			row.append(0.0 if i == j else leg_px(pts[i], pts[j]))
		m.append(row)
	var st := {"px": INF, "order": []}
	_search(m, [], 0, 0, 0.0, st)
	return {"order": st["order"], "px": float(st["px"])}


static func _search(m: Array, order: Array, used: int, last: int, acc: float, st: Dictionary) -> void:
	var n := m.size() - 1
	if order.size() == n:
		var total := acc + float(m[last][0])
		if total < float(st["px"]) - 0.0001:
			st["px"] = total
			st["order"] = order.duplicate()
		return
	if acc >= float(st["px"]):
		return   # already no better than the best found
	for i in range(1, n + 1):
		if used & (1 << i) != 0:
			continue
		order.append(i - 1)
		_search(m, order, used | (1 << i), i, acc + float(m[last][i]), st)
		order.pop_back()


static func to_km(px: float) -> float:
	return px * float(map_cfg().get("km_per_px", 0.045))


## What a run costs in time and fuel for a route of `px` map pixels through `n_stops` stops.
static func stats_for_px(n_stops: int, px: float, best_px: float) -> Dictionary:
	var r := runs_cfg()
	var km := to_km(px)
	var best_km := to_km(best_px)
	var minutes := int(r.get("load_minutes", 30)) + int(round(km / float(r.get("speed_kmh", 24)) * 60.0)) + n_stops * int(r.get("stop_minutes", 12))
	var fuel_l := snappedf(km * fuel_l_per_km(), 0.1)
	return {"px": px, "km": snappedf(km, 0.1), "best_px": best_px, "best_km": snappedf(best_km, 0.1), "score": clampf(best_px / maxf(0.001, px), 0.0, 1.0),
		"minutes": minutes, "fuel_l": fuel_l, "fuel_cost": snappedf(km * fuel_cost_per_km(), 0.01), "upkeep": snappedf(km * upkeep_per_km(), 0.01)}


## Score and costs of driving `stops` in `order` (empty if `order` isn't a visit to every stop once).
static func route_stats(stops: Array, order: Array) -> Dictionary:
	if not valid_order(stops, order):
		return {}
	return stats_for_px(stops.size(), route_px(stops, order), float(best_order(stops)["px"]))


# ------------------------------------------------------------------ posted runs
static func kind_def(id: String) -> Dictionary:
	for k in runs_cfg().get("kinds", []):
		if str(k["id"]) == id:
			return k
	return {}


static func kind_name(id: String) -> String:
	return I18n.t(str(kind_def(id).get("name", id)))


static func job(id: String) -> Dictionary:
	return S()["jobs"].get(id, {})


static func _jobs_with(status: String) -> Array:
	var out: Array = S()["jobs"].values().filter(func(j): return j["status"] == status)
	out.sort_custom(func(a, b): return int(a["by"]) < int(b["by"]) or (int(a["by"]) == int(b["by"]) and str(a["id"]) < str(b["id"])))
	return out


static func open_jobs() -> Array:
	return _jobs_with("open")


static func active_jobs() -> Array:
	return _jobs_with("active")


static func _pick_weighted(kinds: Array) -> Dictionary:
	var total := 0.0
	for k in kinds:
		total += float(k.get("weight", 1))
	var r := GameState.randf() * total
	for k in kinds:
		r -= float(k.get("weight", 1))
		if r <= 0.0:
			return k
	return kinds[kinds.size() - 1]


static func _make_job() -> Dictionary:
	var r := runs_cfg()
	var pool: Array = places().map(func(p): return str(p["id"]))
	var n := mini(GameState.randi_range(int(r["stops"][0]), int(r["stops"][1])), pool.size())
	var stops: Array = []
	while stops.size() < n:
		stops.append(pool.pop_at(GameState.randi_range(0, pool.size() - 1)))
	var kind := _pick_weighted(r.get("kinds", []))
	var client: Dictionary = GameState.pick(cfg().get("clients", [{"name": "Local client"}]))
	var best := best_order(stops)
	var st := stats_for_px(n, float(best["px"]), float(best["px"]))
	var pay := (float(r.get("base_pay", 32)) + float(r.get("pay_per_stop", 21)) * n) * float(kind.get("pay_mult", 1.0)) * lerpf(0.92, 1.12, GameState.randf())
	var by := Clock.at_day_time(int(kind.get("day", 0)), int(kind.get("by_hour", 17)) * 60)
	if by < Clock.now() + int(st["minutes"]) + 60:
		by += Clock.DAY   # posted too late in the day for that slot: the next one
	var id := "R%d" % int(S()["seq"])
	S()["seq"] = int(S()["seq"]) + 1
	return {"id": id, "client": str(client["name"]), "stops": stops, "kind": str(kind["id"]), "posted": Clock.now(), "by": by,
		"pay": float(int(round(pay))), "km_best": st["km"], "est_min": int(st["minutes"]), "status": "open"}


## The morning's runs: two to four new ones on the board (never more than `max_open` waiting).
static func post_jobs() -> int:
	if not has_van():
		return 0
	var r := runs_cfg()
	var want := roundi(GameState.randi_range(int(r["per_day"][0]), int(r["per_day"][1])) * Macro.demand("logistics") * Rivals.demand("logistics"))
	var n := 0
	while n < want and open_jobs().size() < int(r.get("max_open", 8)):
		var j := _make_job()
		S()["jobs"][j["id"]] = j
		n += 1
	if n > 0:
		EventBus.notify.emit(I18n.t("%d new delivery runs are posted (Company OS → Logistics).") % n, "info", "parcel")
	return n


static func accept(id: String) -> Dictionary:
	var j := job(id)
	if j.is_empty() or j["status"] != "open":
		return {"ok": false, "error": "That run has been taken."}
	if active_jobs().size() >= int(runs_cfg().get("max_active", 3)):
		return {"ok": false, "error": "You already have as many runs as you can handle."}
	j["status"] = "active"
	j["accepted"] = Clock.now()
	GameState.inc_stat("runs_accepted")
	return {"ok": true, "job": j}


## Drive an accepted run in `order` (indices into the job's stops): the time passes, the client pays, fuel and wear are
## charged. Late pays less, and how well the route was planned moves the pay a little (`score_pay`).
static func drive(id: String, order: Array) -> Dictionary:
	var j := job(id)
	if j.is_empty() or j["status"] != "active":
		return {"ok": false, "error": "That run isn't on your list."}
	if not has_van():
		return {"ok": false, "error": "You need a van."}
	var st := route_stats(j["stops"], order)
	if st.is_empty():
		return {"ok": false, "error": "That route doesn't visit every stop once."}
	j["status"] = "driving"
	Clock.advance(int(st["minutes"]))
	return _settle(j, st, "")


## Pay the client's fee and book the running costs; the run moves to the history.
static func _settle(j: Dictionary, st: Dictionary, driver: String) -> Dictionary:
	var r := runs_cfg()
	var late := Clock.now() > int(j["by"])
	var sp: Array = r.get("score_pay", [0.9, 0.2])
	var pay := float(j["pay"]) * (float(sp[0]) + float(sp[1]) * float(st["score"]))
	if late:
		pay *= 1.0 - float(r.get("late_penalty", 0.4))
	pay = snappedf(pay, 0.01)
	var ent := entity()
	var client := I18n.t(str(j["client"]))
	Ledger.post(ent, I18n.t("Delivery run %s: %s (%d stops)") % [j["id"], client, (j["stops"] as Array).size()],
		[{"acct": "cash", "dr": pay}, {"acct": "revenue", "cr": pay}], {"type": "delivery", "id": j["id"]})
	if float(st["fuel_cost"]) > 0.0:
		Ledger.expense(ent, "fuel", float(st["fuel_cost"]), I18n.t("Fuel: run %s, %.1f km") % [j["id"], float(st["km"])], {"type": "delivery", "id": j["id"]})
	if float(st["upkeep"]) > 0.0:
		Ledger.expense(ent, "vehicle", float(st["upkeep"]), I18n.t("Van upkeep: run %s") % j["id"], {"type": "delivery", "id": j["id"]})
	S()["van"]["km"] = float(S()["van"].get("km", 0.0)) + float(st["km"])
	j["status"] = "late" if late else "done"
	j["done"] = Clock.now()
	var rec := {"id": j["id"], "client": j["client"], "stops": (j["stops"] as Array).size(), "pay": pay, "fuel": st["fuel_cost"], "km": st["km"],
		"score": snappedf(float(st["score"]), 0.01), "minutes": st["minutes"], "late": late, "status": j["status"], "t": Clock.now(), "who": driver}
	_archive(j, rec)
	GameState.inc_stat("van_runs")
	if late:
		GameState.inc_stat("van_runs_late")
	GameState.inc_stat("van_km", float(st["km"]))
	GameState.inc_stat("van_fuel_l", float(st["fuel_l"]))
	if int(GameState.stat("van_runs")) == 1:
		GameState.set_flag("first_delivery_run")
		GameState.timeline(I18n.t("First delivery run for %s: %s.") % [client, Fmt.money(pay)], "milestone")
	var msg := I18n.t("Run %s paid %s.") % [j["id"], Fmt.money(pay)]
	if driver != "":
		msg = I18n.t("%s drove run %s: paid %s.") % [driver, j["id"], Fmt.money(pay)]
	if late:
		msg += " " + I18n.t("It was late, so the pay was cut.")
	EventBus.notify.emit(msg, "warn" if late else "good", "parcel")
	return {"ok": true, "pay": pay, "fuel": st["fuel_cost"], "upkeep": st["upkeep"], "km": st["km"], "score": st["score"], "minutes": st["minutes"], "late": late}


static func _archive(j: Dictionary, rec: Dictionary) -> void:
	S()["jobs"].erase(j["id"])
	var h: Array = S()["history"]
	h.append(rec)
	while h.size() > 40:
		h.pop_front()


## Recent runs (newest first).
static func history(n := 6) -> Array:
	var h: Array = S()["history"]
	var out: Array = []
	for i in range(h.size() - 1, maxi(-1, h.size() - 1 - n), -1):
		out.append(h[i])
	return out


static func history_sum(days: int, key: String) -> float:
	var t0 := Clock.now() - days * Clock.DAY
	var s := 0.0
	for r in S()["history"]:
		if int(r["t"]) >= t0 and str(r.get("status", "")) != "failed":
			s += float(r.get(key, 0.0))
	return s


static func history_count(days: int) -> int:
	var t0 := Clock.now() - days * Clock.DAY
	var n := 0
	for r in S()["history"]:
		if int(r["t"]) >= t0 and str(r.get("status", "")) != "failed":
			n += 1
	return n


# ------------------------------------------------------------------ drivers
static func driver_score(p: Dictionary) -> float:
	var d: Dictionary = cfg().get("driver", {})
	return clampf(float(d.get("score_base", 0.66)) + float(d.get("score_per_skill", 0.04)) * int(p.get("skill", 3)), 0.0, 0.92)


static func drivers_at(t: int) -> Array:
	return Staff.people().filter(func(p): return p["role"] == "driver" and Staff.is_working(p, t))


## Each working driver takes the best-paying open run they can finish in time.
static func _dispatch_drivers(t: int) -> void:
	var day := Clock.day_index_at(t)
	for p in drivers_at(t):
		if int(S()["driver_day"].get(p["id"], -1)) == day:
			continue
		S()["driver_day"][p["id"]] = day
		var pick := {}
		var pick_st := {}
		for j in open_jobs():
			var best := best_order(j["stops"])
			var px := float(best["px"]) / maxf(0.2, driver_score(p))
			var st := stats_for_px((j["stops"] as Array).size(), px, float(best["px"]))
			if t + int(st["minutes"]) > int(j["by"]):
				continue
			if pick.is_empty() or float(j["pay"]) > float(pick["pay"]):
				pick = j
				pick_st = st
		if pick.is_empty():
			EventBus.notify.emit(I18n.t("%s found no run to take today.") % str(p["name"]).get_slice(" ", 0), "info", "people")
			continue
		pick["status"] = "driving"
		pick["driver"] = p["id"]
		pick["driver_stats"] = pick_st
		Sim.schedule(t + int(pick_st["minutes"]), "log.driver_done", {"job": pick["id"], "driver": p["id"]})


static func handle(kind: String, p: Dictionary) -> void:
	match kind:
		"log.driver_done":
			var j := job(str(p.get("job", "")))
			if j.is_empty() or j["status"] != "driving" or not j.has("driver_stats"):
				return
			var who: Dictionary = Staff.S()["people"].get(str(p.get("driver", "")), {})
			var nm := str(who.get("name", "")).get_slice(" ", 0)
			_settle(j, j["driver_stats"], nm if nm != "" else I18n.t("The driver"))


# ------------------------------------------------------------------ clock
static func on_hour(t: int, h: int) -> void:
	if not has_van():
		return
	var r := runs_cfg()
	if h == int(r.get("post_hour", 7)):
		post_jobs()
	_housekeeping(t)
	if h == 9:
		_insurance(t)
	if h == int(cfg().get("driver", {}).get("start_hour", 8)):
		_dispatch_drivers(t)


## Open runs nobody took lapse at their deadline; an accepted run left undone long after it is cancelled.
static func _housekeeping(t: int) -> void:
	var cancel_after := int(runs_cfg().get("cancel_after_hours", 6)) * 60
	for j in S()["jobs"].values():
		match str(j["status"]):
			"open":
				if t >= int(j["by"]):
					S()["jobs"].erase(j["id"])
			"active":
				if t >= int(j["by"]) + cancel_after:
					var rec := {"id": j["id"], "client": j["client"], "stops": (j["stops"] as Array).size(), "pay": 0.0, "fuel": 0.0, "km": 0.0, "score": 0.0,
						"minutes": 0, "late": true, "status": "failed", "t": t, "who": ""}
					_archive(j, rec)
					GameState.inc_stat("van_runs_failed")
					GameState.add_message("client", I18n.t("%s: Nobody came for our delivery, so we've booked another courier. No fee to pay, and no more work from us this month.") % I18n.t(str(j["client"])))
					EventBus.notify.emit(I18n.t("Run %s was cancelled: the deadline passed.") % j["id"], "bad", "warning")
				elif t >= int(j["by"]) and not j.get("warned", false):
					j["warned"] = true
					EventBus.notify.emit(I18n.t("Run %s is past its deadline. Deliver soon, the pay drops.") % j["id"], "warn", "clock")


static func _insurance(t: int) -> void:
	var v: Dictionary = S()["van"]
	if int(Clock.date_at(t)["day"]) == int(v.get("ins_day", 1)) and t - int(v.get("bought", 0)) > 20 * Clock.DAY:
		Ledger.expense(entity(), "insurance", float(van_cfg().get("insurance_month", 165)), I18n.t("Van insurance: monthly"), {"type": "insurance"})


# ------------------------------------------------------------------ shipping your own parcels
## Why the own-van option isn't available at `loc` ("" = it is).
static func ship_block(loc: String) -> String:
	if not has_van():
		return "you need a van (Dockside Motors, Harbor)"
	if Ecommerce.orders_with(["packed"], loc).is_empty():
		return "nothing packed here"
	return ""


## What delivering the packed parcels at `loc` yourself would cost: {count, all, fuel, minutes}.
static func ship_quote(loc: String) -> Dictionary:
	var packed := Ecommerce.orders_with(["packed"], loc)
	var s: Dictionary = cfg().get("own_van_shipping", {})
	var n := mini(packed.size(), int(van_cfg().get("capacity_parcels", 40)))
	return {"count": n, "all": packed.size(), "fuel": snappedf(n * float(s.get("km_per_parcel", 4.5)) * fuel_cost_per_km(), 0.01),
		"minutes": int(s.get("minutes_base", 25)) + n * int(s.get("minutes_per_parcel", 12))}


## Load the packed parcels into your van and deliver them today: fuel instead of a courier fee, the drive takes
## `minutes` of your time (the caller advances the clock) and the parcels arrive when you do.
static func ship_own_van(loc: String) -> Dictionary:
	var why := ship_block(loc)
	if why != "":
		return {"ok": false, "error": why}
	var q := ship_quote(loc)
	var n := int(q["count"])
	var packed := Ecommerce.orders_with(["packed"], loc).slice(0, n)
	var ent: String = packed[0]["entity"]
	if float(q["fuel"]) > 0.0:
		Ledger.expense(ent, "fuel", float(q["fuel"]), I18n.t("Own-van delivery: %d parcels") % n, {"type": "ship"})
	var eta := Clock.now() + int(q["minutes"])
	var each := snappedf(float(q["fuel"]) / maxf(1.0, float(n)), 0.01)
	for o in packed:
		o["ship"] = {"method": "own_van", "cost": each, "mode": "van", "van_eta": eta}
		Ecommerce._ship(o)
	GameState.inc_stat("van_parcels", n)
	var km := n * float((cfg().get("own_van_shipping", {}) as Dictionary).get("km_per_parcel", 4.5))
	S()["van"]["km"] = float(S()["van"].get("km", 0.0)) + km
	return {"ok": true, "count": n, "cost": float(q["fuel"]), "minutes": int(q["minutes"]), "eta": eta}
