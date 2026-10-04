class_name LifeLegacy
extends RefCounted
## Data-defined scoring, immutable life snapshots and separate-slot next lives.

static func cfg() -> Dictionary:
	return DataDB.legacy

static func S() -> Dictionary:
	if not GameState.data.has("life_legacy"):
		GameState.data["life_legacy"] = {"review": {}, "retired": false, "shown": false}
	return GameState.data["life_legacy"]

static func net_worth() -> float:
	return Ledger.balance("player","property_assets") + Ledger.balance("player","personal_vehicle") + Ledger.cash("player") + Ledger.balance("player", "investments") + Ledger.balance("player","home_deposit") - Insolvency.liabilities("player")

static func metrics() -> Dictionary:
	var contacts := 0
	for id in DataDB.npcs:
		if GameState.flag("met_" + str(id)): contacts += 1
	var hours := GameState.stat("gig_hours") + (GameState.stat("saas_work_minutes") + GameState.stat("paid_work_minutes") + GameState.stat("cafe_work_minutes")) / 60.0
	return {"industries":Growth.metric("industries"), "employees":float(Staff.count()), "net_worth":net_worth(),
		"delivered":GameState.stat("orders_delivered"), "overseas":Growth.metric("foreign_deliveries"),
		"features":float(GameState.data.get("saas", {}).get("features", 0)), "energy_installs":GameState.stat("energy_installs"),
		"chargers":float(GameState.data.get("energy", {}).get("sites", {}).values().filter(func(site): return site.get("status", "") == "open").size()),
		"city_projects":GameState.stat("re_projects_completed"), "contacts":float(contacts), "work_hours":hours,
		"quiet_work":1.0 / (1.0 + hours / float(cfg()["quiet_work_hours"])),
		"recovery":1.0 if GameState.stat("companies_closed") > 0 and GlobalMarket.live(GameState.company_id()) and Growth.metric("annual_revenue") > 0 else 0.0}

static func scores(values: Dictionary) -> Array:
	var out: Array = []
	for d in cfg()["archetypes"]:
		var score := 0.0
		for term in d["formula"]:
			var value := float(values.get(term["metric"], 0))
			if not is_finite(value): value = 0
			score += clampf(value / maxf(0.01, float(term["divisor"])), 0, float(term.get("cap", 1))) * float(term["weight"])
		score = minf(100,score+float(CapitalMarket.cfg()["route_bonus"].get(CapitalMarket.S()["route"],{}).get(d["id"],0)))
		out.append({"id":d["id"], "score":score, "name":d["name"]})
	out.sort_custom(func(a, b): return a["score"] > b["score"] if not is_equal_approx(a["score"], b["score"]) else str(a["id"]) < str(b["id"]))
	return out

static func category(row: Dictionary) -> String:
	return str(row.get("category", cfg()["categories"].get(row.get("kind", "life"), "life")))

static func events(filter := "all", year := -1) -> Array:
	var out: Array = []
	for row in GameState.data["timeline"]:
		if filter != "all" and category(row) != filter: continue
		var date := Clock.date_at(int(row["t"]))
		if year >= 0 and int(date["year"]) != year: continue
		out.append(row)
	out.reverse()
	return out

static func key_moments(rows: Array) -> Array:
	var chosen := rows.duplicate(true)
	chosen.sort_custom(func(a,b):
		var aw := float(cfg()["event_weights"].get(a.get("kind", "life"), 1))
		var bw := float(cfg()["event_weights"].get(b.get("kind", "life"), 1))
		return aw > bw if aw != bw else int(a["t"]) > int(b["t"]))
	return chosen.slice(0, mini(5, chosen.size()))

static func can_retire() -> bool:
	return Growth.enabled() or Clock.now() >= int(cfg()["retire_days"]) * Clock.DAY

static func review(retire := false) -> Dictionary:
	if retire and not can_retire(): return {"ok":false, "error":"Live thirty days or finish the main story before retiring."}
	# A review is a snapshot of the life so far: it is refreshed once after the civic finale and again when the player records retirement.
	var existing: Dictionary = S()["review"]
	if not existing.is_empty():
		var civic_done: bool = GameState.flag("city24_review") and not existing.get("after_civic",false)
		var retiring: bool = retire and not S()["retired"]
		if not civic_done and not retiring: return {"ok":true, "review":existing}
	var values := metrics()
	var ranked := scores(values)
	var primary: Dictionary = cfg()["archetypes"].filter(func(a): return a["id"] == ranked[0]["id"])[0]
	var secondary: Dictionary = ranked[1]
	S()["review"] = {"t":Clock.now(), "primary":ranked[0], "secondary":secondary, "scores":ranked, "metrics":values,
		"moments":key_moments(GameState.data["timeline"]), "player":GameState.data["player"].duplicate(true),
		"epilogue":I18n.t("%s's story leans toward %s, with a trace of %s. %s The next life begins with fewer resources; this record preserves what actually happened.") % [GameState.data["player"]["name"], I18n.t(primary["name"]), I18n.t(secondary["name"]), I18n.t(primary["text"])]}
	S()["review"]["epilogue"] += " " + CapitalMarket.route_text()
	S()["review"]["after_civic"] = GameState.flag("city24_review")
	S()["retired"] = bool(S()["retired"]) or retire
	S()["shown"] = true
	return {"ok":true, "review":S()["review"]}

static func next_life_block() -> String:
	if S()["review"].is_empty() or not (Growth.enabled() or S()["retired"]): return "Finish the epilogue or choose retirement before starting another life."
	if SaveSystem.free_slot() < 0: return "No empty save slot. Keep this life and manage saves from the title screen."
	return ""

static func next_life(kind: String) -> Dictionary:
	if not kind in ["generation", "next"]: return {"ok":false, "error":"Choose the next generation or the next chapter of this character."}
	var why := next_life_block()
	if why != "": return {"ok":false, "error":why}
	var snapshot: Dictionary = S()["review"].duplicate(true)
	var old_slot := SaveSystem.current_slot()
	if not SaveSystem.save(old_slot): return {"ok":false, "error":"The current life could not be saved. Keep playing and try again."}
	var level := int(GameState.data["meta"].get("difficulty", 0)) + 1
	var wealth := maxf(0, net_worth())
	var d: Dictionary = cfg()["archetypes"].filter(func(a): return a["id"] == snapshot["primary"]["id"])[0]
	var inheritance := snappedf(minf(float(d["inherit_cash_home"]), minf(float(cfg()["max_inheritance_home"]), wealth * float(cfg()["max_inheritance_share"]))), 0.01)
	var setup: Dictionary = snapshot["player"].duplicate(true)
	if kind == "generation": setup["name"] = I18n.t("%s's next generation") % str(setup["name"])
	var old_data := GameState.data.duplicate(true)
	SaveSystem.next_slot = SaveSystem.free_slot()
	if not GameState.new_game(setup):
		GameState.data = old_data
		GameState.unpack_rng()
		return {"ok":false, "error":"The next life could not be created. Your current life is preserved."}
	GameState.data["meta"]["difficulty"] = level
	GameState.data["meta"]["previous_life"] = {"slot":old_slot, "kind":kind, "review":snapshot}
	var base := float(DataDB.living().get("start_cash", 30000))
	var reduced := snappedf(base * pow(float(cfg()["difficulty"]["opening_cash_factor"]), level), 0.01)
	Ledger.post("player", I18n.t("Next-life starting capital adjustment"), [{"acct":"cash", "cr":base - reduced}, {"acct":"equity", "dr":base - reduced}], {"type":"opening"})
	if inheritance > 0:
		Ledger.post("player", I18n.t("Inherited capital: %s") % Fmt.money(inheritance), [{"acct":"cash", "dr":inheritance}, {"acct":"equity", "cr":inheritance}], {"type":"opening"})
	if d["id"] == "local_legend": GameState.set_flag("met_maya")
	if not GameState.data["timeline"].is_empty():
		GameState.data["timeline"][0]["text"] = I18n.t("Moved to Aurelia City with $%s in savings.") % Fmt.money0(Ledger.cash("player")).trim_prefix("$")
	GameState.timeline(I18n.t("A new life at difficulty %d, carrying %s home dollars. Previous save: slot %d.") % [level, Fmt.money(inheritance), old_slot], "life")
	return {"ok":true, "slot":SaveSystem.current_slot(), "inherited":inheritance, "difficulty":level}

static func demand_factor() -> float:
	return maxf(float(cfg()["difficulty"]["min_demand_factor"]), pow(float(cfg()["difficulty"]["demand_factor"]), int(GameState.data["meta"].get("difficulty", 0))))
