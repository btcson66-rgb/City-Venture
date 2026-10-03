class_name Energy
extends RefCounted
## Solar installer -> storage -> EV charging network (#69).
## Installs are Jobs (quote, accept, progress by crew capacity, deliver, invoice) with a warranty tail; materials are
## stock until delivery. Stations are Assets with real failure; charger revenue is metered kWh x price. Subsidies are a
## City Hall process (fee, queue, quota, rejection). Nothing earns without a transaction.

static func cfg() -> Dictionary: return DataDB.economy.get("energy", {})
static func S() -> Dictionary:
	if not GameState.data.has("energy"):
		GameState.data["energy"] = {}
	var s: Dictionary = GameState.data["energy"]
	var defaults := {"active":false, "entity":"", "reputation":float(cfg().get("reputation_start", 0.5)), "week":-1, "leads":{}, "installs":{},
		"claims":{}, "completed":0, "storage_cert":false, "mods":{}, "weather":{"day":-1, "kind":"clear"}, "subsidy":{"year":-1, "used":0.0, "charger_used":0.0, "apps":{}},
		"sites":{}, "deals":{}, "arrays":{}, "ev_boost":0.0, "seq":1, "retry":{}}
	for key in defaults:
		if not s.has(key): s[key] = defaults[key]
	return s
static func entity() -> String: return str(S()["entity"])
static func segment_tag() -> String: return "energy"
static func source(type := "energy", id := "") -> Dictionary: return {"type":type, "id":id, "segment":"energy"}
static func error(text: String) -> Dictionary: return {"ok":false, "error":I18n.t(text)}
static func is_running() -> bool: return GameState.has_game() and bool(S()["active"])
static func valid() -> bool: return is_running() and Assets._valid_entity(entity())
static func _id(prefix: String) -> String:
	var id := prefix + str(S()["seq"])
	S()["seq"] = int(S()["seq"]) + 1
	return id

# ------------------------------------------------------------------ opening and growth tiers
static func start() -> Dictionary:
	if GameState.company_id() == "" or not GameState.flag("business_account_opened") or Acquisition.sold(): return error("Register a company and open its bank account first.")
	if not Living.has_lease(str(cfg()["warehouse"]["property"])): return error("Lease the Helio warehouse office in Industrial first.")
	if is_running(): return error("The energy business is already open.")
	if entity() != "" and entity() != GameState.company_id(): GameState.data.erase("energy")
	S()["active"] = true
	S()["entity"] = GameState.company_id()
	GameState.set_flag("energy_active")
	refresh()
	GameState.timeline(I18n.t("Opened a solar installation business at the Helio warehouse."), "milestone")
	return {"ok":true}
static func open_stations() -> Array: return S()["sites"].values().filter(func(s): return s["status"] == "open")
static func stage() -> int:
	if open_stations().size() >= int(cfg()["charging"]["network_stage"]): return 3
	if bool(S()["storage_cert"]) and int(S()["completed"]) >= int(cfg()["storage_min_completed"]): return 2
	return 1
static func stage_text() -> String: return [I18n.t("Installer"), I18n.t("Installer with storage"), I18n.t("Charging network operator")][stage() - 1]
static func certify_storage() -> Dictionary:
	if not valid() or bool(S()["storage_cert"]): return error("Open the business first, then complete the battery course once.")
	if int(S()["completed"]) < int(cfg()["storage_min_completed"]): return error("Complete two solar installs before the battery course.")
	var fee := float(cfg()["materials"]["storage_cert_fee"])
	if Ledger.cash(entity()) < fee: return error("Save the battery course fee first.")
	Ledger.expense(entity(), "other", fee, I18n.t("Helio battery installer certification"), source("training"))
	Clock.advance(int(cfg()["materials"]["storage_cert_minutes"]))
	if not valid(): return error("The business closed during the course.")
	S()["storage_cert"] = true
	GameState.timeline(I18n.t("Earned the battery installer certification."), "milestone")
	return {"ok":true}

# ------------------------------------------------------------------ decaying market effects
static func set_mod(key: String, value: float, days: int) -> void:
	S()["mods"][key] = {"v":value, "t0":Clock.now(), "t1":Clock.now() + days * Clock.DAY}
## A shock returns linearly to 1.0 over its duration.
static func mod(key: String) -> float:
	var m: Dictionary = S()["mods"].get(key, {})
	if m.is_empty() or Clock.now() >= int(m["t1"]): return 1.0
	var left := float(int(m["t1"]) - Clock.now()) / maxf(1.0, float(int(m["t1"]) - int(m["t0"])))
	return 1.0 + (float(m["v"]) - 1.0) * left

# ------------------------------------------------------------------ weather
static func weather() -> String: return str(S()["weather"].get("kind", "clear"))
static func _roll_weather() -> void:
	var w: Dictionary = cfg()["weather"]
	var storm := float(w["storm"]) * (float(w["typhoon_mult"]) if int(Clock.date()["month"]) in w["typhoon_months"] else 1.0)
	var r := GameState.rng.randf()
	S()["weather"] = {"day":Clock.day_index(), "kind":"storm" if r < storm else "rain" if r < storm + float(w["rain"]) else "clear"}
static func weather_text() -> String: return {"clear":I18n.t("Clear"), "rain":I18n.t("Rain"), "storm":I18n.t("Storm")}[weather()]

# ------------------------------------------------------------------ roofs, shading and yield
static func _roll(range_: Array) -> int: return GameState.rng.randi_range(int(range_[0]), int(range_[1]))
static func _new_roof(spec: Dictionary) -> Dictionary:
	var w := _roll(spec["w"])
	var h := _roll(spec["h"])
	var shade: Array = []
	for y in h:
		var row: Array = []
		row.resize(w)
		row.fill(0.0)
		shade.append(row)
	var sc: Dictionary = cfg()["shade"]
	if GameState.rng.randf() < 0.6:
		var side := GameState.rng.randi_range(0, 3)
		var depth := _roll(sc["building_depth"])
		var loss := GameState.rng.randf_range(float(sc["building_loss"][0]), float(sc["building_loss"][1]))
		for y in h:
			for x in w:
				var d: int = [x, w - 1 - x, y, h - 1 - y][side]
				if d < depth: shade[y][x] = snappedf(loss * (1.0 - 0.3 * d), 0.01)
	for tree in _roll(sc["trees"]):
		var cx := GameState.rng.randi_range(0, w - 1)
		var cy := GameState.rng.randi_range(0, h - 1)
		var tl := GameState.rng.randf_range(float(sc["tree_loss"][0]), float(sc["tree_loss"][1]))
		for y in h:
			for x in w:
				var dist := absi(x - cx) + absi(y - cy)
				if dist <= 1: shade[y][x] = maxf(float(shade[y][x]), snappedf(tl * (1.0 - 0.3 * dist), 0.01))
	return {"w":w, "h":h, "shade":shade, "orientation":str(GameState.pick(cfg()["orientations"])), "load_kg":_roll(spec["load_kg"])}
static func max_panels(roof: Dictionary) -> int:
	return mini(int(roof["w"]) * int(roof["h"]), floori(float(roof["load_kg"]) / float(cfg()["panel"]["kg"])))
static func cell_output(roof: Dictionary, x: int, y: int) -> float:
	return (1.0 - float(roof["shade"][y][x])) * float(cfg()["panel"]["kw"]) * float(cfg()["kwh_per_kw_year"]) * float(cfg()["orientation_factor"][roof["orientation"]])
static func layout_check(roof: Dictionary, cells: Array) -> Dictionary:
	var seen := {}
	for c in cells:
		var x := int(c[0])
		var y := int(c[1])
		if x < 0 or y < 0 or x >= int(roof["w"]) or y >= int(roof["h"]) or seen.has(Vector2i(x, y)): return error("Place panels on free roof cells only.")
		seen[Vector2i(x, y)] = true
	if cells.size() > max_panels(roof): return error("The roof load limit allows fewer panels.")
	return {"ok":true}
static func _blend(peak_share: float) -> float:
	var t: Dictionary = cfg()["tariff"]
	return peak_share * float(t["peak_price"]) + (1.0 - peak_share) * float(t["offpeak_price"])
## Pure quote maths: yield, client savings (solar self-use + export + battery shifting), price and payback.
static func evaluate(lead: Dictionary, cells: Array, battery_kwh := 0.0, margin := -1.0, with_subsidy := false) -> Dictionary:
	var roof: Dictionary = lead["roof"]
	var check := layout_check(roof, cells)
	if not check["ok"]: return check
	if cells.is_empty(): return error("Place at least one panel on the roof.")
	var kind: Dictionary = cfg()["roof_kinds"][lead["kind"]]
	var t: Dictionary = cfg()["tariff"]
	var annual := 0.0
	var loss := 0.0
	for c in cells:
		annual += cell_output(roof, int(c[0]), int(c[1]))
		loss += float(roof["shade"][int(c[1])][int(c[0])])
	annual = snappedf(annual, 0.1)
	var kw := snappedf(cells.size() * float(cfg()["panel"]["kw"]), 0.01)
	var usage := float(lead.get("kwh_year", 0.0))
	var self_kwh := minf(annual * float(kind["self_use"]), usage * 0.6)
	var surplus := maxf(0.0, annual - self_kwh)
	var solar_saving := self_kwh * _blend(float(t["peak_share_solar"])) + surplus * float(t["export_price"])
	var battery_saving := 0.0
	if battery_kwh > 0:
		var usable := battery_kwh * float(t["battery_efficiency"])
		var stored := minf(usable, surplus / 365.0)
		var arbitrage := maxf(0.0, usable - stored)
		battery_saving = (stored * (float(t["peak_price"]) - float(t["export_price"])) + arbitrage * (float(t["peak_price"]) - float(t["offpeak_price"])) * float(t["battery_efficiency"])) * float(t["battery_cycles"])
	var m: Dictionary = cfg()["materials"]
	var materials := snappedf((kw * float(m["panel_per_kw"]) + battery_kwh * float(m["battery_per_kwh"])) * mod("materials"), 0.01)
	var base_materials := snappedf(kw * float(m["panel_per_kw"]) + battery_kwh * float(m["battery_per_kwh"]), 0.01)
	if margin < 0: margin = float(cfg()["default_margin"])
	var work := snappedf(kw * float(cfg()["work_days_per_kw"]) + battery_kwh * float(cfg()["battery_work_days_per_kwh"]), 0.01)
	var out := {"ok":true, "panels":cells.size(), "kw":kw, "annual_kwh":annual, "shade_loss":loss / cells.size(), "load_used":cells.size() * float(cfg()["panel"]["kg"]),
		"load_cap":float(roof["load_kg"]), "work_days":work, "battery_kwh":battery_kwh, "materials":materials, "margin":margin}
	if lead["kind"] == "own":
		var saving := annual * float(t["feed_in_price"])
		out.merge({"price":base_materials, "price_net":base_materials, "grant":0.0, "saving_year":snappedf(saving, 0.01), "payback":base_materials / maxf(1.0, saving), "payback_net":base_materials / maxf(1.0, saving), "accept":1.0})
		return out
	var price := snappedf(base_materials / (1.0 - margin), 0.01)
	var grant := grant_amount("install", price) if with_subsidy else 0.0
	var saving_year := snappedf(solar_saving + battery_saving, 0.01)
	var net := snappedf(price - grant, 0.01)
	out.merge({"price":price, "grant":grant, "price_net":net, "saving_year":saving_year, "solar_saving":snappedf(solar_saving, 0.01), "battery_saving":snappedf(battery_saving, 0.01),
		"payback":price / maxf(1.0, saving_year), "payback_net":net / maxf(1.0, saving_year), "gross_margin":(price - base_materials) / price})
	out["accept"] = accept_chance(float(out["payback_net"]), str(lead["kind"]))
	return out
static func accept_chance(payback: float, kind: String) -> float:
	var over := maxf(0.0, payback - float(cfg()["roof_kinds"][kind]["payback_ok"]))
	var chance := clampf(float(cfg()["accept_base"]) - float(cfg()["accept_per_year_over"]) * over, float(cfg()["accept_min"]), float(cfg()["accept_max"]))
	return clampf(chance * (0.85 + float(cfg()["accept_reputation"]) * float(S()["reputation"])), float(cfg()["accept_min"]), float(cfg()["accept_max"]))

# ------------------------------------------------------------------ leads
static func refresh() -> void:
	if not valid(): return
	var week := Clock.day_index() / 7
	if int(S()["week"]) == week: return
	S()["week"] = week
	for id in S()["leads"].keys():
		var lead: Dictionary = S()["leads"][id]
		if lead["kind"] != "own" and lead["status"] == "open" and Clock.now() > int(lead["expires"]): lead["status"] = "expired"
		if lead["status"] in ["expired", "declined", "won"] and Clock.now() > int(lead["expires"]) + 28 * Clock.DAY: S()["leads"].erase(id)
	var count := int(cfg()["weekly_leads"]) + GameState.rng.randi_range(-int(cfg()["weekly_leads_spread"]), int(cfg()["weekly_leads_spread"])) + (1 if float(S()["reputation"]) >= 0.7 else 0)
	for n in count: _new_lead()
	_own_leads()
static func _new_lead() -> void:
	var kinds: Dictionary = cfg()["roof_kinds"]
	var total := 0
	for k in kinds: total += int(kinds[k]["weight"])
	var pick := GameState.rng.randi_range(1, total)
	var kind := "home"
	for k in kinds:
		pick -= int(kinds[k]["weight"])
		if pick <= 0 and int(kinds[k]["weight"]) > 0:
			kind = k
			break
	var spec: Dictionary = kinds[kind]
	var id := _id("ROOF-")
	S()["leads"][id] = {"id":id, "kind":kind, "client":str(GameState.pick(spec["names"])), "district":str(GameState.pick(spec["districts"])), "roof":_new_roof(spec),
		"kwh_year":float(_roll(spec["kwh_year"])), "status":"open", "layout":[], "battery":0.0, "margin":float(cfg()["default_margin"]), "subsidy":false,
		"expires":Clock.now() + int(cfg()["lead_expiry_days"]) * Clock.DAY}
static func _own_leads() -> void:
	var owned: Dictionary = GameState.data.get("real_estate", {}).get("properties", {})
	for pid in owned:
		var id := "OWN-" + str(pid)
		if S()["leads"].has(id) or S()["arrays"].has(id) or S()["installs"].has(id): continue
		var spec: Dictionary = cfg()["roof_kinds"]["own"]
		S()["leads"][id] = {"id":id, "kind":"own", "client":str(owned[pid].get("name", pid)), "district":"residential", "roof":_new_roof(spec), "kwh_year":0.0, "status":"open",
			"layout":[], "battery":0.0, "margin":0.0, "subsidy":false, "expires":0, "property":str(pid)}
static func open_leads() -> Array: return S()["leads"].values().filter(func(l): return l["status"] == "open")
static func set_layout(id: String, cells: Array) -> Dictionary:
	var lead: Dictionary = S()["leads"].get(id, {})
	if lead.is_empty() or lead["status"] != "open": return error("Choose an open roof survey.")
	var check := layout_check(lead["roof"], cells)
	if not check["ok"]: return check
	lead["layout"] = cells.duplicate(true)
	return {"ok":true}
static func toggle_cell(id: String, x: int, y: int) -> Dictionary:
	var lead: Dictionary = S()["leads"].get(id, {})
	if lead.is_empty() or lead["status"] != "open": return error("Choose an open roof survey.")
	var cells: Array = lead["layout"].duplicate(true)
	for i in cells.size():
		if int(cells[i][0]) == x and int(cells[i][1]) == y:
			cells.remove_at(i)
			lead["layout"] = cells
			return {"ok":true}
	cells.append([x, y])
	return set_layout(id, cells)
static func auto_layout(id: String) -> Dictionary:
	var lead: Dictionary = S()["leads"].get(id, {})
	if lead.is_empty() or lead["status"] != "open": return error("Choose an open roof survey.")
	var roof: Dictionary = lead["roof"]
	var all: Array = []
	for y in int(roof["h"]):
		for x in int(roof["w"]): all.append([x, y, cell_output(roof, x, y)])
	all.sort_custom(func(a, b): return float(a[2]) > float(b[2]))
	var cells: Array = []
	for c in all.slice(0, max_panels(roof)):
		if float(c[2]) >= float(cfg()["kwh_per_kw_year"]) * float(cfg()["panel"]["kw"]) * float(cfg()["orientation_factor"][roof["orientation"]]) * 0.6: cells.append([c[0], c[1]])
	lead["layout"] = cells
	return {"ok":true}
static func set_options(id: String, battery: float, margin: float, with_subsidy: bool) -> Dictionary:
	var lead: Dictionary = S()["leads"].get(id, {})
	if lead.is_empty() or lead["status"] != "open" or lead["kind"] == "own" and (battery > 0 or with_subsidy): return error("Choose an open roof survey.")
	if battery > 0 and not bool(S()["storage_cert"]): return error("Earn the battery installer certification before selling storage.")
	if not is_finite(battery) or battery < 0 or battery > 20 or not is_finite(margin) or margin < 0 or margin > 0.5: return error("Choose a listed battery size and margin.")
	lead["battery"] = battery
	if lead["kind"] != "own": lead["margin"] = margin
	lead["subsidy"] = with_subsidy
	return {"ok":true}
static func lead_eval(id: String) -> Dictionary:
	var lead: Dictionary = S()["leads"].get(id, {})
	if lead.is_empty(): return error("Choose an open roof survey.")
	return evaluate(lead, lead["layout"], float(lead["battery"]), float(lead["margin"]), bool(lead["subsidy"]))

# ------------------------------------------------------------------ quote -> job
static func quote(id: String) -> Dictionary:
	var lead: Dictionary = S()["leads"].get(id, {})
	if not valid() or lead.is_empty() or lead["status"] != "open": return error("Choose an open roof survey.")
	var ev := lead_eval(id)
	if not ev["ok"]: return ev
	var sub: bool = bool(lead["subsidy"]) and lead["kind"] != "own"
	if sub:
		var why := subsidy_block("install")
		if why != "": return error(why)
	if lead["kind"] == "own": return _start_own(lead, ev)
	Clock.advance(int(cfg()["quote_minutes"]))
	if not valid() or lead["status"] != "open": return error("This roof survey is no longer available.")
	if GameState.rng.randf() > float(ev["accept"]):
		lead["status"] = "declined"
		return {"ok":true, "accepted":false, "evaluation":ev}
	var kind: Dictionary = cfg()["roof_kinds"][lead["kind"]]
	var job := Jobs.offer({"entity":entity(), "client":lead["client"], "scope":"Rooftop solar installation", "price":float(ev["price_net"]), "work":float(ev["work_days"]),
		"due":Clock.now() + int(cfg()["promise_days"]) * Clock.DAY, "terms":int(kind["terms"]), "deposit":float(kind["deposit"]), "segment":"energy", "penalty_rate":float(cfg()["late_penalty"])})
	if job == "" or not Jobs.accept(job)["ok"]: return error("This job is no longer available.")
	lead["status"] = "won"
	S()["installs"][job] = {"id":job, "lead":id, "client":lead["client"], "kind":lead["kind"], "district":lead["district"], "kw":ev["kw"], "panels":ev["panels"], "annual_kwh":ev["annual_kwh"],
		"battery":float(lead["battery"]), "materials":float(ev["materials"]), "gross":float(ev["price"]), "price":float(ev["price_net"]), "grant":float(ev["grant"]) if sub else 0.0,
		"subsidy":"none", "work":float(ev["work_days"]), "done":0.0, "status":"contracted", "due":Clock.now() + int(cfg()["promise_days"]) * Clock.DAY, "materials_paid":0.0,
		"warranty_until":0, "payback":float(ev["payback"]), "saving":float(ev["saving_year"])}
	if sub:
		var applied := apply_subsidy("install", job)
		if not applied["ok"]: S()["installs"][job]["grant"] = 0.0
	GameState.timeline(I18n.t("Roof survey accepted: %s.") % lead["client"], "business")
	return {"ok":true, "accepted":true, "job":job, "evaluation":ev}
static func _start_own(lead: Dictionary, ev: Dictionary) -> Dictionary:
	var id: String = str(lead["id"])
	if Ledger.cash(entity()) < float(ev["materials"]): return error("Save the panel materials cost first.")
	lead["status"] = "won"
	S()["installs"][id] = {"id":id, "lead":id, "client":lead["client"], "kind":"own", "district":"residential", "kw":ev["kw"], "panels":ev["panels"], "annual_kwh":ev["annual_kwh"], "battery":0.0,
		"materials":float(ev["materials"]), "gross":0.0, "price":0.0, "grant":0.0, "subsidy":"none", "work":float(ev["work_days"]), "done":0.0, "status":"contracted", "due":0, "materials_paid":0.0, "warranty_until":0, "payback":float(ev["payback"]), "saving":float(ev["saving_year"])}
	return {"ok":true, "accepted":true, "job":id, "evaluation":ev}
static func installs_in(status: String) -> Array: return S()["installs"].values().filter(func(i): return i["status"] == status)
static func electrician_power() -> float:
	var c: Dictionary = cfg()["crew"]
	var total := 0.0
	for person in Staff.people():
		if person["role"] == "electrician": total += float(c["electrician_base"]) + float(c["per_skill"]) * int(person["skill"])
	return total
static func crew_capacity(t := -1) -> float:
	if t < 0: t = Clock.now()
	return float(cfg()["crew"]["owner"]) + (electrician_power() if Clock.weekday(t) in [1, 2, 3, 4, 5] else 0.0)
## Days to finish `work` crew-days at the current team, using the weekly average (electricians work weekdays).
static func duration_days(work: float, other_load := 0.0) -> int:
	var per_day := float(cfg()["crew"]["owner"]) + electrician_power() * 5.0 / 7.0
	return maxi(1, ceili((work + other_load) / maxf(0.1, per_day * 0.93)))
static func start_install(id: String) -> Dictionary:
	var inst: Dictionary = S()["installs"].get(id, {})
	if not valid() or inst.is_empty() or inst["status"] != "contracted": return error("Choose a contracted install that is ready to start.")
	if inst["subsidy"] == "pending": return error("Wait for City Hall's subsidy decision before ordering materials.")
	var base := snappedf(float(inst["kw"]) * float(cfg()["materials"]["panel_per_kw"]) + float(inst["battery"]) * float(cfg()["materials"]["battery_per_kwh"]), 0.01)
	var materials := snappedf(base * mod("materials"), 0.01)
	var permit := 0.0 if inst["kind"] == "own" else float(cfg()["permit_fee"])
	if Ledger.cash(entity()) < materials + permit: return error("Save the Helio Supply materials cost first.")
	if permit > 0: Ledger.expense(entity(), "registration", permit, I18n.t("Grid connection permit: %s") % id, source("permit", id))
	if inst["kind"] == "own":
		var own: Dictionary = cfg()["own_array"]
		var asset := Assets.buy({"entity":entity(), "name":"Rooftop array: %s" % inst["client"], "price":materials, "life_days":own["life_days"], "maintenance_days":own["maintenance_days"],
			"maintenance_cost":own["maintenance_cost"], "failure_chance":own["failure_chance"], "segment":"energy"})
		if not asset["ok"]: return asset
		inst["asset"] = asset["id"]
	else:
		Ledger.post(entity(), I18n.t("Helio Supply materials: %s") % id, [{"acct":"inventory", "dr":materials}, {"acct":"cash", "cr":materials}], source("materials", id))
	inst["materials_paid"] = materials
	inst["materials"] = materials
	inst["status"] = "installing"
	inst["started"] = Clock.now()
	return {"ok":true, "materials":materials}
static func _work_day() -> void:
	var cap := crew_capacity() * float(cfg()["weather"]["install_factor"][weather()])
	var order: Array = installs_in("installing")
	order.sort_custom(func(a, b): return int(a["started"]) < int(b["started"]))
	for inst in order:
		if cap <= 0: break
		var give := minf(float(inst["work"]) - float(inst["done"]), cap)
		cap -= give
		inst["done"] = snappedf(float(inst["done"]) + give, 0.0001)
		if inst["kind"] != "own": Jobs.progress(inst["id"], give)
		if float(inst["done"]) >= float(inst["work"]) - 0.0002:
			inst["done"] = inst["work"]
			_complete(inst)
static func _complete(inst: Dictionary) -> void:
	inst["status"] = "delivered"
	inst["delivered"] = Clock.now()
	if inst["kind"] == "own":
		S()["arrays"][inst["id"]] = {"id":inst["id"], "client":inst["client"], "kw":inst["kw"], "annual_kwh":inst["annual_kwh"], "asset":inst["asset"], "kwh":0.0, "revenue":0.0}
		GameState.timeline(I18n.t("Your rooftop array is feeding the grid: %s.") % inst["client"], "milestone")
		return
	var job: Dictionary = Jobs.get_job(inst["id"])
	job["progress"] = job["work"]
	var late := Clock.now() > int(job["due"])
	Jobs.deliver(inst["id"])
	Jobs.invoice(inst["id"])
	var cost := float(inst["materials_paid"])
	Ledger.post(entity(), I18n.t("Installed materials expensed: %s") % inst["id"], [{"acct":"cogs", "dr":cost}, {"acct":"inventory", "cr":cost}], source("install", inst["id"]))
	inst["warranty_until"] = Clock.now() + int(cfg()["warranty"]["days"]) * Clock.DAY
	S()["completed"] = int(S()["completed"]) + 1
	_reputation(-float(cfg()["reputation_late"]) if late else float(cfg()["reputation_done"]))
	GameState.inc_stat("energy_installs")
	if inst["subsidy"] == "approved": Sim.schedule(Clock.now() + int(cfg()["subsidy"]["pay_days"]) * Clock.DAY, "energy.grant", {"key":"install:" + str(inst["id"])})
	GameState.timeline(I18n.t("Installed %.1f kW for %s.") % [float(inst["kw"]), inst["client"]], "business")
static func _reputation(delta: float) -> void:
	S()["reputation"] = clampf(float(S()["reputation"]) + delta, float(cfg()["reputation_min"]), 1.0)
static func cancel_install(id: String, reason := "") -> void:
	var inst: Dictionary = S()["installs"].get(id, {})
	if inst.is_empty() or inst["status"] in ["delivered", "cancelled"]: return
	var job: Dictionary = Jobs.get_job(id)
	if not job.is_empty() and float(job.get("deposit_paid", 0)) > 0 and job["status"] == "active":
		var refund := float(job["deposit_paid"])
		Ledger.post(entity(), I18n.t("Install deposit refunded: %s") % id, [{"acct":"deferred_revenue", "dr":refund}, {"acct":"cash" if Ledger.cash(entity()) >= refund else "accounts_payable", "cr":refund}], source("install", id))
		job["deposit_paid"] = 0.0
	if not job.is_empty(): job["status"] = "closed"
	if float(inst["materials_paid"]) > 0 and inst["kind"] != "own":
		var cost := float(inst["materials_paid"])
		Ledger.post(entity(), I18n.t("Unused materials written off: %s") % id, [{"acct":"exp:inventory_writeoff", "dr":cost}, {"acct":"inventory", "cr":cost}], source("install", id))
	var app: Dictionary = subsidy()["apps"].get("install:" + id, {})
	if not app.is_empty() and app["status"] in ["approved", "pending"]:
		if app["status"] == "approved": subsidy()["used"] = maxf(0.0, float(subsidy()["used"]) - float(app["grant"]))
		app["status"] = "cancelled"
	inst["status"] = "cancelled"
	inst["reason"] = reason

# ------------------------------------------------------------------ warranty
static func claims_open() -> Array: return S()["claims"].values().filter(func(c): return c["status"] == "open")
static func make_claim(install_id: String, share := -1.0, reason := "Panel or inverter defect") -> String:
	var inst: Dictionary = S()["installs"].get(install_id, {})
	if inst.is_empty() or inst["status"] != "delivered" or inst["kind"] == "own" or Clock.now() > int(inst["warranty_until"]): return ""
	for c in S()["claims"].values():
		if c["install"] == install_id and c["status"] == "open": return ""
	if share < 0: share = float(cfg()["warranty"]["cost_share"])
	var id := _id("CLAIM-")
	S()["claims"][id] = {"id":id, "install":install_id, "client":inst["client"], "cost":snappedf(float(inst["gross"]) * share, 0.01), "reason":reason, "status":"open",
		"opened":Clock.now(), "due":Clock.now() + int(cfg()["warranty"]["resolve_days"]) * Clock.DAY}
	return id
static func resolve_claim(id: String, honour: bool, markup := 1.0) -> Dictionary:
	var claim: Dictionary = S()["claims"].get(id, {})
	if not valid() or claim.is_empty() or claim["status"] != "open": return error("Choose an open warranty claim.")
	var cost := snappedf(float(claim["cost"]) * markup, 0.01)
	if honour:
		var from := "cash" if Ledger.cash(entity()) >= cost else "accounts_payable"
		Ledger.expense(entity(), "maintenance", cost, I18n.t("Warranty repair: %s") % claim["client"], source("warranty", claim["install"]), from)
		claim["status"] = "repaired"
		claim["paid"] = cost
		_reputation(0.01)
	else:
		claim["status"] = "disputed"
		_reputation(-float(cfg()["reputation_claim_ignored"]))
		if GameState.rng.randf() < float(cfg()["warranty"]["dispute_loss_chance"]):
			var penalty := snappedf(cost * float(cfg()["warranty"]["dispute_penalty"]), 0.01)
			Ledger.expense(entity(), "penalties", penalty, I18n.t("Warranty dispute lost: %s") % claim["client"], source("warranty", claim["install"]), "cash" if Ledger.cash(entity()) >= penalty else "accounts_payable")
			claim["paid"] = penalty
	return {"ok":true}
static func warranty_exposure() -> float:
	var total := 0.0
	for inst in S()["installs"].values():
		if inst["status"] == "delivered" and inst["kind"] != "own" and Clock.now() <= int(inst["warranty_until"]):
			total += float(inst["gross"]) * float(cfg()["warranty"]["cost_share"]) * float(cfg()["warranty"]["daily_claim"]) * 365.0
	return total
static func _warranty_day() -> void:
	for claim in claims_open():
		if Clock.now() >= int(claim["due"]):
			resolve_claim(claim["id"], true, float(cfg()["warranty"]["auto_markup"]))
			_reputation(-float(cfg()["warranty"]["auto_rep"]))
	for inst in S()["installs"].values():
		if inst["status"] == "delivered" and inst["kind"] != "own" and Clock.now() <= int(inst["warranty_until"]) and GameState.rng.randf() < float(cfg()["warranty"]["daily_claim"]):
			make_claim(inst["id"])

# ------------------------------------------------------------------ City Hall subsidy desk
static func subsidy() -> Dictionary:
	var sb: Dictionary = S()["subsidy"]
	var year := Clock.day_index() / 365
	if int(sb["year"]) != year:
		sb["year"] = year
		sb["used"] = 0.0
		sb["charger_used"] = 0.0
	return sb
static func quota_total(program: String) -> float: return float(cfg()["subsidy"]["annual_quota" if program == "install" else "charger_quota"])
static func quota_left(program: String) -> float:
	var sb := subsidy()
	return maxf(0.0, quota_total(program) - float(sb["used" if program == "install" else "charger_used"]))
static func grant_amount(program: String, price: float) -> float:
	var s: Dictionary = cfg()["subsidy"]
	var rate := float(s["rate" if program == "install" else "charger_rate"]) * mod("subsidy")
	return snappedf(minf(float(s["cap" if program == "install" else "charger_cap"]), price * rate), 0.01)
static func subsidy_block(program: String) -> String:
	if int(Clock.date()["month"]) > int(cfg()["subsidy"]["season_last_month"]): return "This year's subsidy applications are closed."
	if quota_left(program) <= 0: return "This year's subsidy quota is used up."
	if Ledger.cash(entity()) < float(cfg()["subsidy"]["fee"]): return "Save the subsidy application fee first."
	return ""
static func reject_chance(program: String, ref: String) -> float:
	var s: Dictionary = cfg()["subsidy"]
	var extra := 0.0
	if program == "install":
		var inst: Dictionary = S()["installs"].get(ref, {})
		var lead: Dictionary = S()["leads"].get(str(inst.get("lead", "")), {})
		if not lead.is_empty() and not lead["layout"].is_empty():
			var loss := 0.0
			for c in lead["layout"]: loss += float(lead["roof"]["shade"][int(c[1])][int(c[0])])
			extra = float(s["reject_shade"]) * loss / lead["layout"].size()
	return clampf(float(s["reject_base"]) + extra, 0.02, float(s["reject_max"]))
static func apply_subsidy(program: String, ref: String) -> Dictionary:
	if not valid(): return error("Open the business first.")
	var why := subsidy_block(program)
	if why != "": return error(why)
	var key := ("install:" if program == "install" else "charger:") + ref
	var apps: Dictionary = subsidy()["apps"]
	if apps.has(key) and apps[key]["status"] in ["pending", "approved"]: return error("This application is already filed.")
	var price := 0.0
	if program == "install":
		var inst: Dictionary = S()["installs"].get(ref, {})
		if inst.is_empty() or inst["status"] not in ["contracted", "installing"]: return error("Choose a contracted install first.")
		price = float(inst["gross"])
	else:
		var site: Dictionary = S()["sites"].get(ref, {})
		if site.is_empty() or stage() < int(cfg()["subsidy"]["charger_min_stage"]): return error("Reach installer-with-storage stage before applying for a charger grant.")
		price = float(site["cost"])
	var fee := float(cfg()["subsidy"]["fee"])
	Ledger.expense(entity(), "registration", fee, I18n.t("Energy subsidy application fee"), source("subsidy", ref))
	var due := Clock.now() + int(cfg()["subsidy"]["decision_days"]) * Clock.DAY
	apps[key] = {"key":key, "program":program, "ref":ref, "grant":grant_amount(program, price), "status":"pending", "due":due, "filed":Clock.now()}
	if program == "install": S()["installs"][ref]["subsidy"] = "pending"
	Sim.schedule(due, "energy.decision", {"key":key})
	return {"ok":true, "due":due, "grant":apps[key]["grant"]}
static func _decide(key: String) -> void:
	var app: Dictionary = subsidy()["apps"].get(key, {})
	if app.is_empty() or app["status"] != "pending": return
	var program: String = app["program"]
	if not app.get("rushed", false): app["grant"] = snappedf(float(app["grant"]) * mod("subsidy"), 0.01)
	var field := "used" if program == "install" else "charger_used"
	var granted: bool = quota_left(program) >= float(app["grant"]) and GameState.rng.randf() >= reject_chance(program, str(app["ref"]))
	app["status"] = "approved" if granted else "rejected"
	app["reason"] = "" if granted else ("quota" if quota_left(program) < float(app["grant"]) else "review")
	if granted: subsidy()[field] = float(subsidy()[field]) + float(app["grant"])
	if program == "install":
		var inst: Dictionary = S()["installs"].get(str(app["ref"]), {})
		if inst.is_empty(): return
		inst["subsidy"] = app["status"]
		if not granted: _subsidy_rejected(inst)
	else:
		var site: Dictionary = S()["sites"].get(str(app["ref"]), {})
		if granted and not site.is_empty() and site["status"] == "open": _pay_charger_grant(site, app)
	GameState.timeline(I18n.t("Energy subsidy %s for %s.") % [I18n.t("approved") if granted else I18n.t("rejected"), str(app["ref"])], "business")
## A rejected grant lifts the client's price back to full; the client may walk away.
static func _subsidy_rejected(inst: Dictionary) -> void:
	var job: Dictionary = Jobs.get_job(inst["id"])
	inst["price"] = inst["gross"]
	job["price"] = inst["gross"]
	inst["grant"] = 0.0
	if GameState.rng.randf() > accept_chance(float(inst["gross"]) / maxf(1.0, float(inst["saving"])), str(inst["kind"])):
		cancel_install(inst["id"], "subsidy rejected")
		_reputation(-0.01)
static func _pay_grant(key: String) -> void:
	var app: Dictionary = subsidy()["apps"].get(key, {})
	if app.is_empty() or app["status"] != "approved" or app["program"] != "install": return
	var inst: Dictionary = S()["installs"].get(str(app["ref"]), {})
	if inst.is_empty() or inst["status"] != "delivered": return
	var grant := float(app["grant"])
	Ledger.post(entity(), I18n.t("Energy subsidy paid by City Hall: %s") % inst["id"], [{"acct":"cash", "dr":grant}, {"acct":"revenue", "cr":grant}], source("subsidy", inst["id"]))
	app["status"] = "paid"
static func _pay_charger_grant(site: Dictionary, app: Dictionary) -> void:
	var grant := float(app["grant"])
	var item: Dictionary = Assets.S()["items"].get(str(site["asset"]), {})
	if item.is_empty(): return
	Ledger.post(entity(), I18n.t("Charger capital grant: %s") % site["spot"], [{"acct":"cash", "dr":grant}, {"acct":"fixed_assets", "cr":grant}], source("subsidy", site["spot"]))
	item["price"] = snappedf(float(item["price"]) - grant, 0.01)
	item["book"] = snappedf(float(item["book"]) - grant, 0.01)
	app["status"] = "paid"
static func applications() -> Array: return subsidy()["apps"].values()

# ------------------------------------------------------------------ EV adoption
static func adoption() -> float:
	var ev: Dictionary = cfg()["ev"]
	var boost := minf(float(ev["boost_cap"]), float(S()["ev_boost"]) + float(GameState.data.get("automotive", {}).get("ev_boost", 0.0)))
	return float(ev["adoption_start"]) + float(ev["adoption_growth_year"]) * float(Clock.day_index()) / 365.0 + boost
## Optional hook for dealership modules: raises the city EV adoption rate (capped).
static func add_ev_boost(delta: float) -> void:
	if is_finite(delta): S()["ev_boost"] = clampf(float(S()["ev_boost"]) + delta, 0.0, float(cfg()["ev"]["boost_cap"]))

# ------------------------------------------------------------------ charging network
static func spots() -> Array: return cfg()["charging"]["spots"]
static func spot_def(id: String) -> Dictionary:
	for s in spots():
		if s["id"] == id: return s
	return {}
static func spots_in(district: String) -> Array: return spots().filter(func(s): return s["district"] == district)
static func site_of(spot: String) -> Dictionary: return S()["sites"].get(spot, {})
static func spot_taken(spot: String) -> bool:
	var site := site_of(spot)
	return not site.is_empty() and site["status"] in ["building", "open"]
static func free_spots(district: String) -> int: return spots_in(district).filter(func(s): return not spot_taken(s["id"])).size()
static func owned_deal(spot: Dictionary) -> bool:
	if spot.has("lease") and Living.has_lease(str(spot["lease"])): return true
	var owned: Dictionary = GameState.data.get("real_estate", {}).get("properties", {})
	for pid in spot.get("property", []):
		if owned.has(pid): return true
	return false
static func site_deal(spot_id: String, option: String) -> Dictionary:
	var spot := spot_def(spot_id)
	if not valid() or spot.is_empty() or spot_taken(spot_id): return error("Choose a free charging site.")
	if stage() < int(cfg()["charging"]["min_stage"]): return error("Reach installer-with-storage stage before opening charging sites.")
	if owned_deal(spot):
		S()["deals"][spot_id] = {"kind":"owned", "fee":0.0, "share":0.0}
		return {"ok":true, "kind":"owned"}
	if option not in ["fee", "share"]: return error("Choose a fixed fee or revenue share.")
	if int(S()["retry"].get(spot_id, 0)) > Clock.day_index(): return error("The landlord asked you to come back tomorrow.")
	Clock.advance(int(cfg()["charging"]["deal_minutes"]))
	if not valid(): return error("The business closed during the negotiation.")
	var c: Dictionary = cfg()["charging"]
	if GameState.rng.randf() > clampf(float(c["deal_chance"]) + float(c["deal_reputation"]) * (float(S()["reputation"]) - 0.5), 0.1, 0.95):
		S()["retry"][spot_id] = Clock.day_index() + int(c["retry_days"])
		return {"ok":true, "signed":false}
	S()["deals"][spot_id] = {"kind":option, "fee":float(spot["fee"]) if option == "fee" else 0.0, "share":float(c["share"]) if option == "share" else 0.0}
	return {"ok":true, "signed":true, "kind":option}
static func station_cost(type: String) -> float:
	var t: Dictionary = cfg()["charging"]["types"][type]
	return snappedf(float(t["cost"]) * (1.0 - (float(cfg()["charging"]["stage3_discount"]) if stage() >= 3 else 0.0)), 0.01)
static func build_station(spot_id: String, type: String, with_grant := false, finance := false) -> Dictionary:
	var spot := spot_def(spot_id)
	var types: Dictionary = cfg()["charging"]["types"]
	if not valid() or spot.is_empty() or not types.has(type) or spot_taken(spot_id): return error("Choose a free charging site and station type.")
	if stage() < int(types[type]["min_stage"]): return error("Reach installer-with-storage stage before opening charging sites.")
	if not S()["deals"].has(spot_id) or (S()["deals"][spot_id]["kind"] == "owned" and not owned_deal(spot)): return error("Agree terms with the landlord or use your own property first.")
	var cost := station_cost(type)
	if with_grant:
		var why := subsidy_block("charger")
		if why != "": return error(why)
	var loan := floorf(cost * float(cfg()["charging"]["loan_share"]) / 100.0) * 100.0 if finance else 0.0
	if Ledger.cash(entity()) + loan < cost + (float(cfg()["subsidy"]["fee"]) if with_grant else 0.0): return error("Save the station build cost first.")
	if finance:
		var taken := Bank.take_loan(loan, int(cfg()["charging"]["loan_months"]))
		if not taken["ok"]: return taken
	var t: Dictionary = types[type]
	var asset := Assets.buy({"entity":entity(), "name":"Charging station: %s" % I18n.t(spot["label"]), "price":cost, "life_days":t["life_days"], "maintenance_days":t["maintenance_days"],
		"maintenance_cost":t["maintenance_cost"], "failure_chance":t["failure_chance"], "segment":"energy"})
	if not asset["ok"]: return asset
	var due := Clock.now() + int(t["build_days"]) * Clock.DAY
	S()["sites"][spot_id] = {"spot":spot_id, "district":spot["district"], "type":type, "ports":int(t["ports"]), "asset":asset["id"], "cost":cost, "price":float(cfg()["charging"]["default_price"]),
		"status":"building", "due":due, "accessible":false, "deal":S()["deals"][spot_id].duplicate(), "kwh":0.0, "revenue":0.0, "energy_cost":0.0, "sessions":0, "days":0, "down_days":0, "faults":0, "down_until":0}
	Sim.schedule(due, "energy.open", {"spot":spot_id})
	GameState.set_flag("energy_chargers")
	if with_grant: apply_subsidy("charger", spot_id)
	GameState.timeline(I18n.t("Started building a charging station: %s.") % I18n.t(spot["label"]), "business")
	return {"ok":true, "due":due}
static func _open_station(spot_id: String) -> void:
	var site := site_of(spot_id)
	if site.is_empty() or site["status"] != "building": return
	site["status"] = "open"
	site["opened"] = Clock.now()
	var app: Dictionary = subsidy()["apps"].get("charger:" + spot_id, {})
	if not app.is_empty() and app["status"] == "approved": _pay_charger_grant(site, app)
	GameState.timeline(I18n.t("Charging station opened: %s.") % I18n.t(spot_def(spot_id)["label"]), "milestone")
static func set_price(spot_id: String, price: float) -> Dictionary:
	var site := site_of(spot_id)
	var c: Dictionary = cfg()["charging"]
	if site.is_empty() or not is_finite(price) or price < float(c["price_min"]) - 0.0001 or price > float(c["price_max"]) + 0.0001: return error("Choose a price within the listed range.")
	site["price"] = snappedf(price, 0.01)
	return {"ok":true}
static func util_factor(price: float) -> float:
	var c: Dictionary = cfg()["charging"]
	return pow(float(c["price_ref"]) / maxf(0.05, price), float(c["elasticity"]))
static func network_mult() -> float:
	var c: Dictionary = cfg()["charging"]
	return 1.0 + minf(float(c["network_bonus_cap"]), float(c["network_bonus"]) * maxi(0, open_stations().size() - 1))
## Expected kWh in a normal day: city adoption x district traffic x price response x weather, capped by port power.
static func demand_kwh(site: Dictionary, weather_kind := "clear") -> float:
	var c: Dictionary = cfg()["charging"]
	var t: Dictionary = c["types"][site["type"]]
	var base := float(t["ports"]) * float(t["kwh_port_day"])
	var d := base * adoption() / float(cfg()["ev"]["adoption_ref"]) * float(c["districts"].get(site["district"], 1.0)) * util_factor(float(site["price"])) * float(c["weather_factor"][weather_kind]) * network_mult()
	return minf(d, float(t["ports"]) * float(t["kw"]) * 24.0 * float(c["util_cap"]))
static func grid_cost() -> float:
	var t: Dictionary = cfg()["tariff"]
	return snappedf(float(t["commercial_mult"]) * _blend(float(t["charger_peak_share"])) * mod("tariff"), 0.001)
static func margin_per_kwh(site: Dictionary) -> float: return float(site["price"]) - grid_cost() - float(site["deal"]["share"]) * float(site["price"])
static func station_ok(site: Dictionary) -> bool:
	var item: Dictionary = Assets.S()["items"].get(str(site["asset"]), {})
	return site["status"] == "open" and item.get("status", "") == "working" and Clock.now() >= int(site["down_until"])
static func _ops_day() -> void:
	var c: Dictionary = cfg()["charging"]
	for site in open_stations():
		site["days"] = int(site["days"]) + 1
		var item: Dictionary = Assets.S()["items"].get(str(site["asset"]), {})
		if item.get("status", "") == "sold": continue
		if station_ok(site) and GameState.rng.randf() < float(c["outage_chance"]) * mod("security"):
			item["status"] = "broken"
			site["faults"] = int(site["faults"]) + 1
		if not station_ok(site):
			site["down_days"] = int(site["down_days"]) + 1
			continue
		var kwh := snappedf(demand_kwh(site, weather()) * GameState.rng.randf_range(0.9, 1.1), 0.1)
		if kwh <= 0: continue
		var revenue := snappedf(kwh * float(site["price"]), 0.01)
		var cost := snappedf(kwh * grid_cost(), 0.01)
		Ledger.post(entity(), I18n.t("Charging sessions: %s") % site["spot"], [{"acct":"cash", "dr":revenue}, {"acct":"revenue", "cr":revenue}], source("charging", site["spot"]))
		Ledger.post(entity(), I18n.t("Grid electricity for charging: %s") % site["spot"], [{"acct":"cogs", "dr":cost}, {"acct":"cash" if Ledger.cash(entity()) >= cost else "accounts_payable", "cr":cost}], source("charging", site["spot"]))
		if float(site["deal"]["share"]) > 0:
			var share := snappedf(revenue * float(site["deal"]["share"]), 0.01)
			Ledger.expense(entity(), "other", share, I18n.t("Landlord revenue share: %s") % site["spot"], source("charging", site["spot"]), "cash" if Ledger.cash(entity()) >= share else "accounts_payable")
		site["kwh"] = float(site["kwh"]) + kwh
		site["revenue"] = float(site["revenue"]) + revenue
		site["energy_cost"] = float(site["energy_cost"]) + cost
		site["sessions"] = int(site["sessions"]) + maxi(1, roundi(kwh / 28.0))
static func _site_fees() -> void:
	if int(Clock.date()["day"]) != 1: return
	for site in S()["sites"].values():
		if site["status"] in ["building", "open"] and float(site["deal"]["fee"]) > 0:
			var fee := float(site["deal"]["fee"])
			Ledger.expense(entity(), "other", fee, I18n.t("Charging site fee: %s") % site["spot"], source("charging", site["spot"]), "cash" if Ledger.cash(entity()) >= fee else "accounts_payable")
static func maintain_station(spot_id: String) -> Dictionary:
	var site := site_of(spot_id)
	if site.is_empty() or site["status"] != "open": return error("Choose an open station.")
	return Assets.maintain(str(site["asset"]))
static func _arrays_day() -> void:
	for arr in S()["arrays"].values():
		var item: Dictionary = Assets.S()["items"].get(str(arr["asset"]), {})
		if item.get("status", "") != "working": continue
		var kwh := snappedf(float(arr["annual_kwh"]) / 365.0 * float(cfg()["weather"]["output_factor"][weather()]), 0.1)
		var revenue := snappedf(kwh * float(cfg()["tariff"]["feed_in_price"]), 0.01)
		if revenue <= 0: continue
		Ledger.post(entity(), I18n.t("Grid export from your rooftop array: %s") % arr["client"], [{"acct":"cash", "dr":revenue}, {"acct":"revenue", "cr":revenue}], source("feed_in", arr["id"]))
		arr["kwh"] = float(arr["kwh"]) + kwh
		arr["revenue"] = float(arr["revenue"]) + revenue

# ------------------------------------------------------------------ street scene
## Chargers the player has built (or is building) appear on that district's pavement.
static func street_props(district: String) -> Array:
	var out: Array = []
	if not GameState.has_game(): return out
	for site in GameState.data.get("energy", {}).get("sites", {}).values():
		if site["district"] != district or site["status"] not in ["building", "open"]: continue
		var x := int(spot_def(str(site["spot"])).get("x", 600))
		var sprite := "ev_charger" if site["status"] == "open" else "cone"
		if not Art.has_tex("props/" + sprite): sprite = "bollard"
		for i in (2 if site["type"] == "fast" else 3):
			out.append({"sprite":sprite, "x":x + i * 22, "y":344, "solid":[0, 18, 8, 6]})
	return out

# ------------------------------------------------------------------ crises, each with two real answers
static func crisis(kind: String, _retain := true) -> Dictionary:
	if not valid(): return error("Open the energy business first.")
	var c: Dictionary = cfg()["crisis"]
	match kind:
		"shortage_premium":
			var fee := float(c["premium_fee"])
			if Ledger.cash(entity()) < fee: return error("Save the premium supplier fee first.")
			Ledger.expense(entity(), "other", fee, I18n.t("Premium panel allocation fee"), source("crisis"))
			set_mod("materials", float(c["premium_mult"]), int(c["premium_days"]))
		"shortage_wait": set_mod("materials", float(c["shortage_mult"]), int(c["shortage_days"]))
		"typhoon_honour", "typhoon_triage":
			var share := float(c["typhoon_cost_share"]) if kind == "typhoon_honour" else float(c["triage_cost_share"])
			for inst in S()["installs"].values():
				if inst["status"] == "delivered" and inst["kind"] != "own" and Clock.now() <= int(inst["warranty_until"]) and GameState.rng.randf() < float(c["typhoon_claim_chance"]):
					var id := make_claim(inst["id"], share, "Typhoon damage")
					if id != "": resolve_claim(id, true)
			if kind == "typhoon_triage": _reputation(-float(c["triage_rep_loss"]))
		"cut_rush":
			var pending := applications().filter(func(a): return a["status"] == "pending")
			var fee := float(c["rush_fee"]) * pending.size()
			if Ledger.cash(entity()) < fee: return error("Save the rush filing fees first.")
			if fee > 0: Ledger.expense(entity(), "registration", fee, I18n.t("Subsidy rush filing"), source("subsidy"))
			for a in pending: a["rushed"] = true
			set_mod("subsidy", float(c["cut_mult"]), int(c["cut_days"]))
			S()["rush_until"] = Clock.now() + int(c["cut_days"]) * Clock.DAY
		"cut_accept": set_mod("subsidy", float(c["cut_mult"]), int(c["cut_days"]))
		"vandal_repair", "vandal_secure":
			var target := open_stations()
			if target.is_empty(): return error("Open a charging station first.")
			var cost := float(c["vandal_repair"] if kind == "vandal_repair" else c["vandal_secure"])
			if Ledger.cash(entity()) < cost: return error("Save the repair cost first.")
			Ledger.expense(entity(), "maintenance", cost, I18n.t("Charger vandalism repair"), source("crisis"))
			var site: Dictionary = target[GameState.rng.randi_range(0, target.size() - 1)]
			site["down_until"] = Clock.now() + int(c["vandal_down_days" if kind == "vandal_repair" else "vandal_secure_down_days"]) * Clock.DAY
			if kind == "vandal_secure": set_mod("security", float(c["vandal_secure_mult"]), int(c["vandal_secure_days"]))
		"tariff_hold": set_mod("tariff", float(c["tariff_mult"]), int(c["tariff_days"]))
		"tariff_pass":
			set_mod("tariff", float(c["tariff_mult"]), int(c["tariff_days"]))
			for site in open_stations(): site["price"] = minf(float(cfg()["charging"]["price_max"]), snappedf(float(site["price"]) + float(c["tariff_pass_price"]), 0.01))
		"rule_retrofit":
			var stations := open_stations().filter(func(s): return not s["accessible"])
			var cost := float(c["rule_retrofit"]) * stations.size()
			if Ledger.cash(entity()) < cost: return error("Save the accessibility retrofit cost first.")
			if cost > 0: Ledger.post(entity(), I18n.t("Accessible bay retrofit"), [{"acct":"exp:maintenance", "dr":cost}, {"acct":"cash", "cr":cost}], source("crisis"))
			for s in stations: s["accessible"] = true
		"rule_exempt":
			var stations := open_stations().filter(func(s): return not s["accessible"])
			var fee := float(c["rule_exempt_fee"])
			if Ledger.cash(entity()) < fee: return error("Save the exemption filing fee first.")
			Ledger.expense(entity(), "registration", fee, I18n.t("Accessibility exemption filing"), source("crisis"))
			if GameState.rng.randf() < float(c["rule_exempt_chance"]):
				for s in stations: s["accessible"] = true
			else:
				var fine := float(c["rule_fine"]) * stations.size()
				if fine > 0: Ledger.expense(entity(), "penalties", fine, I18n.t("Accessibility rule fine"), source("crisis"), "cash" if Ledger.cash(entity()) >= fine else "accounts_payable")
				_reputation(-float(c["rule_rep_loss"]))
		_: return error("Unknown energy crisis.")
	return {"ok":true}

# ------------------------------------------------------------------ registry hooks
static func on_hour(_t: int, h: int) -> void:
	if not valid(): return
	match h:
		5: _roll_weather()
		9:
			refresh()
			_site_fees()
		17: _work_day()
		18: _warranty_day()
		20: _arrays_day()
		22: _ops_day()
static func handle(kind: String, payload: Dictionary) -> void:
	if not valid(): return
	match kind:
		"energy.decision": _decide(str(payload.get("key", "")))
		"energy.grant": _pay_grant(str(payload.get("key", "")))
		"energy.open": _open_station(str(payload.get("spot", "")))
static func on_company_closed(closed: String) -> void:
	if not is_running() or entity() != closed: return
	for inst in S()["installs"].values():
		if inst["status"] in ["contracted", "installing"]:
			var cost := float(inst["materials_paid"])
			if cost > 0 and inst["kind"] != "own":
				Ledger.post(closed, I18n.t("Unused materials written off: %s") % inst["id"], [{"acct":"exp:inventory_writeoff", "dr":cost}, {"acct":"inventory", "cr":cost}], source("install", inst["id"]))
			inst["status"] = "cancelled"
	for site in S()["sites"].values():
		if site["status"] in ["building", "open"]: site["status"] = "closed"
	for app in applications():
		if app["status"] == "pending": app["status"] = "cancelled"
	S()["active"] = false
	GameState.set_flag("energy_active", false)
	for kind in ["energy.decision", "energy.grant", "energy.open"]: Sim.cancel(kind, "", null)
static func os_tab() -> Dictionary: return {"id":"energy", "label":"Energy", "icon":"sun", "order":8, "start_label":"Open Energy Console", "render":EnergyUI.render}
static func board_detail() -> Callable: return EnergyUI.board
static func open_action(_params: Dictionary, _source: Node) -> void: EnergyUI.open()
static func subsidy_action(_params: Dictionary, _source: Node) -> void: EnergyUI.open("subsidy")
