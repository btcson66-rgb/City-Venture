class_name Rivals
extends RefCounted
## Virtual AI books stay separate from the player's ledger. Player acquisition costs are real double entries.


static func cfg() -> Dictionary:
	return DataDB.economy.get("rivals", {})


static func active() -> bool:
	return GameState.has_game() and GameState.data.has("rivals")


static func S() -> Dictionary:
	return GameState.data.get("rivals", {})


static func initialize() -> void:
	if active():
		return
	var random := RandomNumberGenerator.new()
	random.seed = int(GameState.data["rng"]["seed"]) ^ 9002
	GameState.data["rivals"] = {"version": 1, "rng_state": str(random.state), "week": -1, "companies": {}, "offers": {}, "poach_after": 0}
	for id in DataDB.rivals:
		var rival: Dictionary = DataDB.rivals[id].duplicate(true)
		rival.merge({"cash": rival["capital"], "ads": 0.0, "status": "active", "last": "", "buyer": "", "trades": [], "base_quality": rival["quality"], "base_price": rival["price"], "exit_week": -9999}, true)
		S()["companies"][id] = rival


static func companies(industry := "") -> Array:
	return S().get("companies", {}).values().filter(func(r): return industry == "" or r["industry"] == industry)


static func participates(industry: String) -> bool:
	var entity: Dictionary = GameState.data["entities"].get(GameState.company_id(), {})
	if entity.has("closed"):
		return false
	var registration := Industries.find(industry)
	if not registration.is_empty() and registration["sim_class"].is_running():
		return true
	return entity.get("type", "") == industry


static func player_weight(industry: String) -> float:
	if not participates(industry):
		return 0.0
	var weight := float(cfg()["player_weight"])
	if industry == "cafe":
		weight *= clampf(float(Cafe.item("coffee")["ref_price"]) / Cafe.price("coffee"), float(cfg()["player_weight_min"]), float(cfg()["player_weight_max"])) * Cafe.rating_factor() * Cafe.ads_factor()
	elif industry == "saas" and Saas.launched():
		weight *= Saas.quality() * clampf(float(Saas.idea()["ref_price"]) / maxf(1.0, float(Saas.S()["price"])), float(cfg()["player_weight_min"]), float(cfg()["player_weight_max"]))
	elif industry == "ecommerce":
		var sum := 0.0
		var count := 0
		for listing in GameState.data["ecommerce"]["listings"].values():
			if listing["active"]:
				var product: Dictionary = DataDB.product(str(listing["product"]))
				sum += clampf(float(product.get("ref_price", listing["price"])) / maxf(0.1, float(listing["price"])), float(cfg()["player_weight_min"]), float(cfg()["player_weight_max"])) * clampf(Ecommerce.rating(listing) / 3.0, float(cfg()["quality_weight_min"]), float(cfg()["quality_weight_max"]))
				count += 1
		if count > 0:
			weight *= sum / count
	for rival in companies(industry):
		if rival["status"] == "acquired" and rival.get("buyer", "") == GameState.company_id():
			weight += float(rival["quality"]) * pow(float(rival["locations"]), float(cfg()["location_weight_power"]))
	return maxf(float(cfg()["share_floor"]), weight)


## Outside firms absorb failed/absent operators; normalization always includes them and sums to one.
static func shares(industry: String) -> Dictionary:
	var weights := {"outside": float(cfg()["outside_weight"]), "player": player_weight(industry)}
	for rival in companies(industry):
		weights[rival["id"]] = maxf(float(cfg()["share_floor"]), float(rival["quality"]) * pow(float(rival["locations"]), float(cfg()["location_weight_power"])) * (1.0 + float(rival["ads"]) * float(cfg()["ads_weight"])) / float(rival["price"])) if rival["status"] == "active" else 0.0
	var total := 0.0
	for weight in weights.values():
		total += float(weight)
	for id in weights:
		weights[id] = float(weights[id]) / total
	return weights


static func demand(industry: String) -> float:
	return clampf(float(shares(industry)["player"]) / float(cfg()["demand_reference"]), float(cfg()["demand_min"]), float(cfg()["demand_max"])) if active() and participates(industry) else 1.0


static func wages() -> float:
	if not active():
		return 1.0
	var pressure := 0.0
	for rival in companies():
		if rival["status"] == "active":
			pressure += float(rival["ads"]) + float(rival["locations"]) - 1.0
	return clampf(1.0 + pressure / maxf(1.0, companies().size()) * float(cfg()["wage_pressure"]), 1.0, float(cfg()["wage_max"]))


## Snapshot API shared by contract/RFQ/brief callers. Unknown/nonexistent industries produce no rivals.
static func competitors(industry: String) -> Array:
	var out: Array = []
	for rival in companies(industry):
		if rival["status"] == "active":
			out.append({"id": rival["id"], "name": rival["name"], "price": rival["price"], "quality": rival["quality"], "share": shares(industry)[rival["id"]]})
	return out


static func on_hour(_t: int, _h: int) -> void:
	if not active():
		return
	var week := int(Clock.day_index() / int(cfg()["week_days"]))
	while int(S()["week"]) < week:
		S()["week"] = int(S()["week"]) + 1
		decide_week()
	for id in S()["offers"].keys():
		var offer: Dictionary = S()["offers"][id]
		if offer["status"] == "pending" and (Clock.now() >= int(offer["expires"]) or not Staff.S()["people"].has(id) or GameState.company_id() != offer["company"]):
			answer(id, false)
	if Clock.world_active and not UIRoot._suppress_decisions and not pending().is_empty() and UIRoot.modal_layer.get_child_count() == 0:
		_show_offer.call_deferred(str(pending()[0]["employee"]))


static func _show_offer(employee: String) -> void:
	if Clock.world_active and UIRoot.top_modal() == null and S().get("offers", {}).get(employee, {}).get("status", "") == "pending":
		UIRoot.open_modal(PoachModal.new(employee))


static func decide_week() -> void:
	var random := RandomNumberGenerator.new()
	random.state = int(S()["rng_state"])
	for rival in companies():
		if rival["status"] != "active":
			_maybe_reenter(rival)
			continue
		var industry := str(rival["industry"])
		var before := shares(industry)
		var units := maxi(0, roundi(float(cfg()["weekly_units"]) * float(before[rival["id"]]) * float(cfg()["market_size"]) * Macro.demand(industry) * random.randf_range(0.65, 1.35)))
		var unit_price := snappedf(float(cfg()["reference_unit_price"]) * float(rival["price"]), 0.01)
		var revenue := snappedf(units * unit_price, 0.01)
		# Actual simulated market receipts: quantity × charged price, retained for inspection.
		if not rival.has("trades"):
			rival["trades"] = []
		rival["trades"].append({"week": S()["week"], "units": units, "unit_price": unit_price, "revenue": revenue})
		while rival["trades"].size() > int(cfg()["trade_history_weeks"]):
			rival["trades"].pop_front()
		rival["cash"] = snappedf(float(rival["cash"]) + revenue - float(cfg()["weekly_cost"]) * Macro.costs() * float(rival["locations"]) - float(rival["ads"]) * float(cfg()["ads_cost"]), 0.01)
		if float(rival["cash"]) <= 0:
			rival["status"] = "bankrupt"
			for buyer in companies(industry):
				if buyer["id"] != rival["id"] and buyer["status"] == "active" and float(buyer["cash"]) > float(cfg()["location_cost"]) * 2:
					buyer["cash"] = float(buyer["cash"]) - float(cfg()["location_cost"])
					buyer["locations"] = mini(int(cfg()["max_locations"]), int(buyer["locations"]) + 1)
					rival["status"] = "acquired"
					rival["buyer"] = buyer["id"]
					break
			rival["exit_week"] = int(S()["week"])
			rival["last"] = I18n.t("%s left the market.") % rival["name"]
		else:
			match str(rival["strategy"]):
				"low_price": rival["price"] = clampf(float(rival["price"]) + random.randf_range(-float(cfg()["price_move"]), float(cfg()["price_move"]) * 0.5), float(cfg()["price_min"]), float(cfg()["price_max"]))
				"quality":
					# Investing in quality costs cash every week; it only improves while the firm can pay for it.
					if float(rival["cash"]) > float(cfg()["quality_cost"]) * 4:
						rival["cash"] = snappedf(float(rival["cash"]) - float(cfg()["quality_cost"]), 0.01)
						rival["quality"] = clampf(float(rival["quality"]) + float(cfg()["quality_move"]), float(cfg()["quality_min"]), float(cfg()["quality_max"]))
				"expansion":
					if float(rival["cash"]) > float(cfg()["location_cost"]) * 2 and int(rival["locations"]) < int(cfg()["max_locations"]):
						rival["cash"] = float(rival["cash"]) - float(cfg()["location_cost"])
						rival["locations"] = int(rival["locations"]) + 1
			# Standards drift back toward the firm's own baseline when nobody keeps pushing them.
			var base_quality := float(rival.get("base_quality", rival["quality"]))
			var base_price := float(rival.get("base_price", rival["price"]))
			rival["quality"] = clampf(float(rival["quality"]) + (base_quality - float(rival["quality"])) * float(cfg()["quality_revert"]), float(cfg()["quality_min"]), float(cfg()["quality_max"]))
			rival["price"] = clampf(float(rival["price"]) + (base_price - float(rival["price"])) * float(cfg()["price_revert"]), float(cfg()["price_min"]), float(cfg()["price_max"]))
			rival["ads"] = clampf(float(rival["ads"]) + random.randf_range(-float(cfg()["ads_move"]), float(cfg()["ads_move"])), 0.0, float(cfg()["ads_max"]))
			rival["last"] = I18n.t("%s: price %.2f × street level; %d locations.") % [rival["name"], float(rival["price"]), int(rival["locations"])]
			if participates(industry) and Clock.now() >= int(S()["poach_after"]) and random.randf() < float(cfg()["poach_chance"]) and not Staff.people().is_empty():
				make_offer(str(Staff.people()[random.randi_range(0, Staff.count() - 1)]["id"]), str(rival["id"]))
		CityNews.enqueue(str(rival["last"]), "rival")
	S()["rng_state"] = str(random.state)


## A market with a hole in it attracts a fresh entrant; rivals the player bought stay owned.
static func _maybe_reenter(rival: Dictionary) -> void:
	if rival.get("buyer", "") == GameState.company_id() and rival["status"] == "acquired" and GameState.company_id() != "":
		return
	if rival["status"] == "bankrupt" and rival.get("acquired_cost", 0.0) != 0.0:
		return
	var left := int(rival.get("exit_week", -9999))
	if left == -9999:
		rival["exit_week"] = int(S()["week"])
		return
	if int(S()["week"]) - left < int(cfg()["reentry_weeks"]):
		return
	rival["status"] = "active"
	rival["cash"] = float(rival["capital"])
	rival["locations"] = 1
	rival["ads"] = 0.0
	rival["buyer"] = ""
	rival["quality"] = rival.get("base_quality", rival["quality"])
	rival["price"] = rival.get("base_price", rival["price"])
	rival["exit_week"] = -9999
	rival["last"] = I18n.t("%s opened as a new entrant.") % rival["name"]
	CityNews.enqueue(str(rival["last"]), "rival")


static func pending() -> Array:
	return S().get("offers", {}).values().filter(func(o): return o["status"] == "pending")


static func make_offer(employee: String, rival_id: String) -> bool:
	var person: Dictionary = Staff.S()["people"].get(employee, {})
	var rival: Dictionary = S()["companies"].get(rival_id, {})
	if person.is_empty() or rival.is_empty() or rival["status"] != "active" or not pending().is_empty() or GameState.company_id() == "":
		return false
	S()["offers"][employee] = {"employee": employee, "name": person["name"], "rival": rival_id, "company": GameState.company_id(), "salary": snappedf(float(person["salary_week"]) * (1.0 + float(cfg()["poach_raise"])), 0.01), "expires": Clock.now() + int(cfg()["poach_days"]) * Clock.DAY, "status": "pending"}
	S()["poach_after"] = Clock.now() + int(cfg()["poach_cooldown_days"]) * Clock.DAY
	CityNews.enqueue(I18n.t("%s is recruiting experienced staff.") % rival["name"], "rival")
	return true


static func answer(employee: String, retain: bool) -> bool:
	var offer: Dictionary = S().get("offers", {}).get(employee, {})
	if offer.is_empty() or offer["status"] != "pending":
		return false
	var person: Dictionary = Staff.S()["people"].get(employee, {})
	var valid: bool = GameState.company_id() == offer["company"] and not GameState.data["entities"].get(str(offer["company"]), {}).has("closed")
	if retain and valid and not person.is_empty() and Clock.now() < int(offer["expires"]):
		person["salary_week"] = float(offer["salary"])
		person["last_raise"] = Clock.now()
		person["morale"] = maxi(int(person["morale"]), 75)
		offer["status"] = "retained"
	else:
		# No dismissal/severance: the employee voluntarily accepts the competing job.
		if valid:
			Staff.S()["people"].erase(employee)
		offer["status"] = "left"
	EventBus.world_refresh.emit()
	return true


static func acquire_price(id: String) -> float:
	var rival: Dictionary = S().get("companies", {}).get(id, {})
	return snappedf(maxf(0.0, float(rival.get("cash", 0))) * float(cfg()["acquire_multiple"]) + float(rival.get("locations", 1)) * float(cfg()["location_cost"]), 0.01)


static func acquire(id: String) -> Dictionary:
	var rival: Dictionary = S().get("companies", {}).get(id, {})
	var entity := GameState.company_id()
	if rival.is_empty() or rival.get("status", "") != "active" or entity == "" or GameState.data["entities"][entity].has("closed") or Acquisition.sold() or Clock.now() - int(GameState.data["entities"][entity].get("founded", 0)) < int(cfg()["acquire_after_days"]) * Clock.DAY:
		return {"ok": false, "error": "✗ Acquisition unavailable — operate an independent company for 180 days."}
	var price := acquire_price(id)
	if Ledger.cash(entity) < price:
		return {"ok": false, "error": I18n.t("✗ Insufficient company cash — save %s first.") % Fmt.money(price)}
	Ledger.post(entity, I18n.t("Rival acquisition: %s — %s") % [rival["name"], Fmt.money(price)], [{"acct": "investments", "dr": price}, {"acct": "cash", "cr": price}], {"type": "acquisition", "rival": id, "segment": rival["industry"]})
	# Buying market presence does not award cash or guaranteed dividends.
	rival["status"] = "acquired"
	rival["buyer"] = entity
	rival["acquired_cost"] = price
	CityNews.enqueue(I18n.t("%s acquired %s.") % [GameState.entity_name(entity), rival["name"]], "achievement")
	return {"ok": true, "cost": price}


static func on_company_closed(entity: String) -> void:
	if not active():
		return
	for rival in companies():
		if rival["status"] != "acquired" or rival.get("buyer", "") != entity:
			continue
		var cost := minf(float(rival.get("acquired_cost", 0)), maxf(0.0, Ledger.balance(entity, "investments")))
		rival["status"] = "bankrupt"
		rival["acquired_cost"] = 0.0
		if cost > 0:
			Ledger.post(entity, I18n.t("Acquired market presence written off: %s") % Fmt.money(cost), [{"acct": "exp:other", "dr": cost}, {"acct": "investments", "cr": cost}], {"type": "liquidation", "segment": rival["industry"]})
	for offer in pending():
		if offer["company"] == entity:
			offer["status"] = "closed"


## Opponents use their saved price/quality; inactive legacy markets preserve the old odds.
static func bid_chance(base: float, opponents: Array) -> float:
	base=clampf(base*Brand.customer_willingness(),0,1)
	if opponents.is_empty():
		return base
	var strength := 0.0
	for opponent in opponents:
		strength = maxf(strength, float(opponent.get("quality", 1.0)) / maxf(float(cfg()["price_min"]), float(opponent.get("price", 1.0))))
	return clampf(base / (1.0 + strength * float(cfg()["bid_pressure"])), 0.0, 1.0)


static func competing_text(opponents: Array) -> String:
	return I18n.t("Competing firms: %s") % ", ".join(opponents.map(func(r): return str(r["name"])))
