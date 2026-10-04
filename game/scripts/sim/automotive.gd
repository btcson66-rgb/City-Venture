class_name Automotive
extends RefCounted
## Automotive (#68): weekly auction flips, an airport rental fleet and a franchised dealership.
## Money only moves through traceable transactions: an auction purchase, a retail/wholesale sale, a rental
## contract that ended, a service ticket or a new-car sale. Stock cars sit in `inventory` (and back bank loans);
## the rental fleet is a set of Assets (depreciation, service intervals, failures, auction on closure).

static func cfg() -> Dictionary:
	return DataDB.economy.get("automotive", {})

static func _fresh() -> Dictionary:
	var rental: Dictionary = cfg().get("rental", {})
	var prior := float(rental.get("review_prior_n", 12))
	return {"active":false, "entity":"", "week":-1, "index":1.0, "heat":1.0, "lots":{}, "stock":{}, "fleet":{}, "rentals":{},
		"seq":1, "ev_boost":0.0, "completed":0, "lost":0, "claims":0, "sold_count":0, "flip_profit":0.0, "history":[], "days":[],
		"reviews":{"sum":prior*float(rental.get("review_prior_score", 4.0)), "n":prior},
		"policy":{"daily":1.0, "weekly":1.0, "insurance":"basic", "service_days":30, "auto_service":false, "discount":0.0},
		"demand":{"start":1.0, "from":0, "until":0}, "rate_cut":0, "recall":{"until":0, "ids":[]},
		"franchise":{"status":"none", "brand":"", "deposit":0.0, "since":0, "short":0, "sold":0, "orders":{}, "visits":0, "month":-1}}

static func S() -> Dictionary:
	if not GameState.data.has("automotive"):
		GameState.data["automotive"] = _fresh()
	return GameState.data["automotive"]

static func entity() -> String: return str(S()["entity"])
static func segment_tag() -> String: return "automotive"
static func source(type := "auto", id := "") -> Dictionary: return {"type":type, "id":id, "segment":"automotive"}
static func error(text: String) -> Dictionary: return {"ok":false, "error":I18n.t(text)}
static func is_running() -> bool: return GameState.has_game() and bool(S()["active"])
static func valid() -> bool: return is_running() and Assets._valid_entity(entity())
static func auction() -> Dictionary: return cfg().get("auction", {})
static func rental() -> Dictionary: return cfg().get("rental", {})
static func dealer() -> Dictionary: return cfg().get("dealership", {})
static func _money_ok(value: float) -> bool: return is_finite(value) and value > 0

static func _pay_from(amount: float) -> String:
	return "cash" if Ledger.cash(entity()) >= amount else "accounts_payable"

# ------------------------------------------------------------------ opening and stages
static func start() -> Dictionary:
	if GameState.company_id() == "" or not GameState.flag("business_account_opened") or Acquisition.sold():
		return error("Register a company and open its bank account first.")
	if is_running():
		return error("The auto desk is already open.")
	var fee := float(cfg()["license_fee"])
	if Ledger.cash(GameState.company_id()) < fee:
		return error("Save the dealer licence fee first.")
	if entity() != "" and entity() != GameState.company_id():
		GameState.data.erase("automotive")
	S()["active"] = true
	S()["entity"] = GameState.company_id()
	GameState.set_flag("automotive_active")
	Ledger.expense(entity(), "registration", fee, I18n.t("Dealer licence"), source("licence"))
	refresh()
	GameState.timeline(I18n.t("Opened an auto desk at Aurelia Auto Auction."), "milestone")
	return {"ok":true}

static func fleet_cars() -> Array:
	var result: Array = []
	for id in S()["fleet"]:
		var item: Dictionary = Assets.S()["items"].get(id, {})
		if not item.is_empty() and item["status"] != "sold" and item["entity"] == entity():
			result.append(id)
	return result

static func stage() -> int:
	if str(S()["franchise"]["status"]) == "active": return 3
	if fleet_cars().size() >= int(cfg()["stage_fleet"]) and Living.has_lease("gateway_counter"): return 2
	return 1

static func stage_name(value := 0) -> String:
	return ["Used-car flipper", "Rental fleet operator", "Franchised dealer"][(value if value > 0 else stage()) - 1]

static func slots() -> int: return int(cfg()["lot_slots"][stage() - 1])
static func stock_count() -> int: return S()["stock"].size()
static func incoming_count() -> int:
	var count := 0
	for order in S()["franchise"]["orders"].values(): count += int(order["qty"])
	return count

# ------------------------------------------------------------------ pricing of a car
static func km_factor(km: float) -> float:
	var v: Dictionary = cfg()["value"]
	return clampf(1.0 - (km - float(v["km_start"])) / float(v["km_span"]), float(v["km_min"]), float(v["km_max"]))

static func visible_value(car: Dictionary) -> float:
	var v: Dictionary = cfg()["value"]
	var grade := float(v["floor"]) + float(car["ext"]) * float(v["ext"]) + float(car["mech"]) * float(v["mech"])
	return snappedf(float(car["base"]) * float(S()["index"]) * grade * km_factor(float(car["km"])), 10.0)

static func defect_hit(car: Dictionary) -> float:
	if str(car.get("defect", "")) == "": return 0.0
	return float(cfg()["defects"][car["defect"]]["hit"]) * (1.0 - float(car.get("fixed", 0.0)))

static func true_value(car: Dictionary) -> float:
	return snappedf(visible_value(car) * (1.0 - defect_hit(car)), 10.0)

## What a buyer can see: the true value only once the defect is known (inspected or disclosed).
static func market_value(car: Dictionary) -> float:
	return true_value(car) if bool(car.get("known", false)) else visible_value(car)

static func grade_text(value: float) -> String:
	return I18n.t("Excellent") if value >= 0.8 else I18n.t("Good") if value >= 0.6 else I18n.t("Fair") if value >= 0.4 else I18n.t("Poor")

static func _pick_defect(rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for id in cfg()["defects"]: total += float(cfg()["defects"][id]["weight"])
	var roll := rng.randf() * total
	for id in cfg()["defects"]:
		roll -= float(cfg()["defects"][id]["weight"])
		if roll <= 0: return str(id)
	return "engine"

static func _make_car() -> Dictionary:
	var rng := GameState.rng
	var models: Array = cfg()["models"]
	var model: Dictionary = models[rng.randi_range(0, models.size() - 1)]
	var id := "CAR-%d" % int(S()["seq"])
	S()["seq"] = int(S()["seq"]) + 1
	var age := rng.randi_range(3, 11)
	var car := {"id":id, "model":model["id"], "name":model["name"], "class":model["class"], "base":float(model["base"]), "age":age,
		"km":float(snappedf(rng.randf_range(12000.0, 21000.0) * age, 1000.0)), "ext":snappedf(rng.randf_range(0.3, 0.95), 0.01),
		"mech":snappedf(rng.randf_range(0.3, 0.95), 0.01), "defect":"", "fixed":0.0, "known":false, "cost":0.0, "recon":0.0,
		"status":"lot", "ready":0, "list":0.0, "listed_day":0, "new":false}
	if rng.randf() < float(auction()["defect_chance"]): car["defect"] = _pick_defect(rng)
	return car

# ------------------------------------------------------------------ weekly catalogue
static func refresh() -> void:
	if not valid(): return
	var week := int(Clock.day_index() / 7)
	if int(S()["week"]) == week: return
	S()["week"] = week
	var market: Dictionary = cfg()["market"]
	S()["index"] = clampf(float(S()["index"]) + GameState.rng.randf_range(-float(market["index_step"]), float(market["index_step"])), float(market["index_min"]), float(market["index_max"]))
	S()["heat"] = GameState.rng.randf_range(float(auction()["heat"][0]), float(auction()["heat"][1]))
	for id in S()["lots"].keys():
		var old: Dictionary = S()["lots"][id]
		if int(old["week"]) < week - 1: S()["lots"].erase(id)
		elif old["status"] == "open": old["status"] = "ended"
	var a := auction()
	for n in int(a["lots"]):
		var car := _make_car()
		var lot_id := "LOT-%d" % int(S()["seq"])
		S()["seq"] = int(S()["seq"]) + 1
		var seen := visible_value(car)
		var bidders: Array = []
		var names: Array = a["bidder_names"].duplicate()
		for b in int(a["ai_count"]):
			var ceiling := minf(seen * GameState.rng.randf_range(float(a["ai_min"]), float(a["ai_max"])) * float(S()["heat"]), seen * float(a["ai_cap"]))
			bidders.append({"id":"AI%d" % (b + 1), "name":names.pop_at(GameState.rng.randi_range(0, names.size() - 1)), "ceiling":snappedf(ceiling, 1.0),
				"eager":snappedf(GameState.rng.randf_range(float(a["eager_min"]), float(a["eager_max"])), 0.01)})
		S()["lots"][lot_id] = {"id":lot_id, "week":week, "car":car, "status":"open", "open":maxf(float(a["inc_min"]), snappedf(seen * float(a["open_ratio"]), 50.0)),
			"bid":0.0, "leader":"", "step":0, "silent":0, "inspected":false, "price":0.0, "bidders":bidders}

static func open_lots() -> Array:
	return S()["lots"].values().filter(func(l): return l["status"] == "open")

# ------------------------------------------------------------------ the auction
static func auction_day() -> bool: return Clock.weekday() == int(auction()["weekday"])
static func auction_open_now() -> bool:
	return auction_day() and Clock.hour() >= int(auction()["open_hour"]) and Clock.hour() < int(auction()["close_hour"])
static func days_to_auction() -> int: return (int(auction()["weekday"]) - Clock.weekday() + 7) % 7

static func increment(lot: Dictionary) -> float:
	return maxf(float(auction()["inc_min"]), snappedf(visible_value(lot["car"]) * float(auction()["inc_ratio"]), 50.0))

static func next_bid(lot: Dictionary) -> float:
	return float(lot["open"]) if float(lot["bid"]) <= 0.0 else float(lot["bid"]) + increment(lot)

static func buyer_fee(price: float) -> float: return snappedf(price * float(auction()["buyer_fee"]), 0.01)

static func inspect(lot_id: String, spend_time := true) -> Dictionary:
	var lot: Dictionary = S()["lots"].get(lot_id, {})
	if not valid() or lot.is_empty() or lot["status"] != "open": return error("Choose an open auction lot.")
	if bool(lot["inspected"]): return error("Jun Ito has already inspected this car.")
	var cost := float(auction()["inspection_cost"])
	if Ledger.cash(entity()) < cost: return error("Save the inspection fee first.")
	Ledger.expense(entity(), "other", cost, I18n.t("Pre-auction inspection"), source("inspection", lot_id))
	lot["inspected"] = true
	lot["car"]["known"] = true
	if spend_time: Clock.advance(int(auction()["inspection_minutes"]))
	return {"ok":true, "defect":lot["car"]["defect"], "true_value":true_value(lot["car"])}

static func auction_bid(lot_id: String) -> Dictionary:
	var lot: Dictionary = S()["lots"].get(lot_id, {})
	if not valid() or lot.is_empty() or lot["status"] != "open": return error("Choose an open auction lot.")
	if not auction_open_now(): return error("Bidding runs on auction day, Wednesdays 09:00-17:00.")
	if str(lot["leader"]) == "player": return error("You already hold the high bid.")
	if stock_count() >= slots(): return error("Your lot is full. Sell or wholesale a car first.")
	var amount := next_bid(lot)
	if Ledger.cash(entity()) < amount + buyer_fee(amount): return error("Save enough cash for the bid and the buyer fee first.")
	lot["bid"] = amount
	lot["leader"] = "player"
	lot["silent"] = 0
	return {"ok":true, "bid":amount}

## One live polling tick: the bidders may raise (bounded by each private ceiling); enough quiet ticks and the hammer falls.
static func auction_step(lot_id: String) -> Dictionary:
	var lot: Dictionary = S()["lots"].get(lot_id, {})
	if not valid() or lot.is_empty() or lot["status"] != "open": return error("Choose an open auction lot.")
	lot["step"] = int(lot["step"]) + 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s:%s:%d" % [str(GameState.data["rng"]["seed"]), lot_id, int(lot["step"])])
	var next := next_bid(lot)
	var count: int = lot["bidders"].size()
	for i in count:
		var bidder: Dictionary = lot["bidders"][(i + int(lot["step"])) % count]
		var roll := rng.randf()
		if str(lot["leader"]) != str(bidder["id"]) and next <= float(bidder["ceiling"]) and roll < float(bidder["eager"]):
			lot["bid"] = next
			lot["leader"] = bidder["id"]
			lot["silent"] = 0
			return {"ok":true, "raised":bidder["name"], "bid":next, "sold":false}
	lot["silent"] = int(lot["silent"]) + 1
	return {"ok":true, "raised":"", "bid":lot["bid"], "sold":int(lot["silent"]) >= int(auction()["silent_polls"])}

static func auction_hammer(lot_id: String) -> Dictionary:
	var lot: Dictionary = S()["lots"].get(lot_id, {})
	if not valid() or lot.is_empty() or lot["status"] != "open": return error("Choose an open auction lot.")
	var price := float(lot["bid"])
	if lot["leader"] == "":
		lot["status"] = "passed"
		return {"ok":true, "won":false, "price":0.0}
	if lot["leader"] != "player":
		lot["status"] = "lost"
		lot["price"] = price
		return {"ok":true, "won":false, "price":price}
	var cost := price + buyer_fee(price)
	if Ledger.cash(entity()) < cost or stock_count() >= slots():
		lot["status"] = "lost"
		return {"ok":true, "won":false, "price":price, "error":I18n.t("The sale fell through: not enough cash or lot space.")}
	var car: Dictionary = lot["car"].duplicate(true)
	car["cost"] = cost
	car["bought"] = Clock.now()
	car["status"] = "lot"
	S()["stock"][car["id"]] = car
	lot["status"] = "won"
	lot["price"] = price
	Ledger.post(entity(), I18n.t("Auction purchase: %s") % car["name"], [{"acct":"inventory", "dr":cost}, {"acct":"cash", "cr":cost}], source("auto_purchase", lot_id))
	GameState.inc_stat("auction_wins")
	GameState.timeline(I18n.t("Won %s at auction for %s.") % [I18n.t(car["name"]), Fmt.money0(price)], "business")
	return {"ok":true, "won":true, "price":price, "car":car["id"]}

## Bot/test helper: bid up to a ceiling, polling until the hammer falls.
static func auction_auto(lot_id: String, max_bid: float) -> Dictionary:
	var lot: Dictionary = S()["lots"].get(lot_id, {})
	if lot.is_empty() or lot["status"] != "open": return error("Choose an open auction lot.")
	for guard in 400:
		if str(lot["leader"]) != "player":
			if next_bid(lot) > max_bid or not auction_bid(lot_id)["ok"]:
				return auction_hammer(lot_id)
		var polling := true
		while polling:
			var tick := auction_step(lot_id)
			if not tick["ok"]: return tick
			if tick["raised"] != "": polling = false
			elif tick["sold"]: return auction_hammer(lot_id)
	return auction_hammer(lot_id)

# ------------------------------------------------------------------ reconditioning and selling
static func _mechanics() -> int: return Staff.count("auto_mechanic")

static func recon_cost(car: Dictionary, option: String) -> float:
	var r: Dictionary = cfg()["recon"]
	var cut := 1.0 - float(r["mechanic_cost_cut"]) * float(mini(1, _mechanics()))
	if option == "repair":
		var spec: Dictionary = cfg()["defects"].get(str(car.get("defect", "")), {})
		return snappedf(float(spec.get("repair", 0.0)) * float(car["base"]) * cut, 1.0)
	return snappedf((float(r[option]["cost"]) + float(r[option]["cost_base"]) * float(car["base"])) * cut, 1.0)

static func recon_days(option: String, car: Dictionary) -> int:
	var days := int(cfg()["recon"][option]["days"]) if option != "repair" else int(cfg()["defects"][car["defect"]]["days"])
	return maxi(1, days - (int(cfg()["recon"]["mechanic_days_saved"]) if _mechanics() > 0 else 0))

static func recon(car_id: String, option: String) -> Dictionary:
	var car: Dictionary = S()["stock"].get(car_id, {})
	if not valid() or car.is_empty() or bool(car["new"]) or car["status"] not in ["lot", "listed", "shop"] or option not in ["detail", "service", "repair"]:
		return error("Choose a used car on your lot.")
	if option == "repair":
		var spec: Dictionary = cfg()["defects"].get(str(car["defect"]), {})
		if str(car["defect"]) == "" or not bool(car["known"]) or float(spec.get("fix", 0.0)) <= float(car["fixed"]):
			return error("Inspect the car first; only a known, repairable defect can be fixed.")
	elif option == "detail" and float(car["ext"]) >= 1.0 or option == "service" and float(car["mech"]) >= 1.0:
		return error("This part of the car is already as good as it gets.")
	var cost := recon_cost(car, option)
	if Ledger.cash(entity()) < cost: return error("Save the reconditioning cost first.")
	Ledger.post(entity(), I18n.t("Reconditioning: %s") % car["name"], [{"acct":"inventory", "dr":cost}, {"acct":"cash", "cr":cost}], source("recon", car_id))
	car["cost"] = float(car["cost"]) + cost
	car["recon"] = float(car["recon"]) + cost
	var days := recon_days(option, car)
	match option:
		"detail": car["ext"] = minf(1.0, float(car["ext"]) + float(cfg()["recon"]["detail"]["gain"]))
		"service": car["mech"] = minf(1.0, float(car["mech"]) + float(cfg()["recon"]["service"]["gain"]))
		"repair": car["fixed"] = float(cfg()["defects"][car["defect"]]["fix"])
	car["status"] = "shop"
	car["list"] = 0.0
	car["ready"] = Clock.day_index() + days
	return {"ok":true, "cost":cost, "days":days}

static func sale_probability(ratio: float) -> float:
	var s: Dictionary = cfg()["sale"]
	return clampf(float(s["base"]) * exp(-float(s["k"]) * (ratio - 1.0)), float(s["min"]), float(s["max"]))

static func expected_days(ratio: float) -> int: return ceili(1.0 / sale_probability(ratio))

static func list_car(car_id: String, price: float) -> Dictionary:
	var car: Dictionary = S()["stock"].get(car_id, {})
	if not valid() or car.is_empty() or bool(car["new"]) or car["status"] not in ["lot", "listed"] or not _money_ok(price):
		return error("Choose a finished used car on your lot.")
	var ratio := price / market_value(car)
	if ratio < float(cfg()["sale"]["ratio_min"]) - 0.001 or ratio > float(cfg()["sale"]["ratio_max"]) + 0.001:
		return error("Price between 80% and 130% of the market value.")
	car["status"] = "listed"
	car["list"] = snappedf(price, 1.0)
	car["listed_day"] = Clock.day_index()
	return {"ok":true, "ratio":ratio, "days":expected_days(ratio)}

static func unlist(car_id: String) -> Dictionary:
	var car: Dictionary = S()["stock"].get(car_id, {})
	if car.is_empty() or car["status"] != "listed": return error("Choose a listed car.")
	car["status"] = "lot"
	car["list"] = 0.0
	return {"ok":true}

static func _close_sale(car: Dictionary, price: float, memo: String, type: String) -> void:
	var cost := float(car["cost"])
	Ledger.post(entity(), memo, [{"acct":"cash", "dr":price}, {"acct":"revenue", "cr":price}, {"acct":"cogs", "dr":cost}, {"acct":"inventory", "cr":cost}], source(type, str(car["id"])))
	S()["stock"].erase(car["id"])
	if not bool(car["new"]):
		S()["sold_count"] = int(S()["sold_count"]) + 1
		S()["flip_profit"] = float(S()["flip_profit"]) + price - cost
		S()["history"].append({"name":car["name"], "cost":cost, "price":price, "day":Clock.day_index(), "profit":snappedf(price - cost, 0.01)})
		if S()["history"].size() > 30: S()["history"].pop_front()

static func _sell_retail(car: Dictionary) -> void:
	var price := float(car["list"])
	_close_sale(car, price, I18n.t("Used car sold: %s") % car["name"], "auto_sale")
	GameState.inc_stat("cars_sold")
	var hidden := str(car["defect"]) != "" and not bool(car["known"])
	var chance := float(cfg()["sale"]["claim_chance"]) if hidden else 0.0
	if float(car.get("claim_risk", 0.0)) > 0: chance = float(car["claim_risk"])
	if chance > 0 and GameState.rng.randf() < chance:
		Sim.schedule(Clock.now() + int(cfg()["sale"]["claim_days"]) * Clock.DAY, "auto.claim", {"price":price, "hit":maxf(defect_hit(car), 0.1), "fine":float(car.get("claim_risk", 0.0)) > 0})

static func sell_wholesale(car_id: String) -> Dictionary:
	var car: Dictionary = S()["stock"].get(car_id, {})
	if not valid() or car.is_empty() or bool(car["new"]) or car["status"] == "shop": return error("Choose a used car that is not in the workshop.")
	var price := snappedf(true_value(car) * float(cfg()["sale"]["wholesale"]), 0.01)
	car["known"] = true
	_close_sale(car, price, I18n.t("Sold to Dockside Motors: %s") % car["name"], "auto_wholesale")
	return {"ok":true, "price":price}

# ------------------------------------------------------------------ the rental fleet
static func class_def(id: String) -> Dictionary: return rental()["classes"].get(id, {})
static func policy() -> Dictionary: return S()["policy"]

static func rate_factor() -> float:
	return float(cfg()["crisis"]["fuel_cut_rate"]) if Clock.now() < int(S()["rate_cut"]) else 1.0

static func daily_rate(cls: String) -> float:
	return snappedf(float(class_def(cls)["rate"]) * float(policy()["daily"]) * rate_factor(), 1.0)

static func weekly_rate(cls: String) -> float:
	return snappedf(float(class_def(cls)["weekly"]) * float(policy()["weekly"]) * rate_factor(), 1.0)

static func buy_block() -> String:
	if not valid(): return "Open the auto desk first."
	if not Living.has_lease("gateway_counter"): return "Lease the Gateway Car Rental counter first."
	if fleet_cars().size() >= int(rental()["fleet_max"]): return "The parking lot is full."
	return ""

static func buy_fleet(cls: String) -> Dictionary:
	var why := buy_block()
	if why != "": return error(why)
	var def := class_def(cls)
	if def.is_empty(): return error("Choose a car class.")
	var plate := "AUR-%03d" % int(S()["seq"])
	var result := Assets.buy({"entity":entity(), "name":"%s %s" % [def["name"], plate], "price":def["price"], "life_days":def["life_days"], "resale":def["resale"],
		"maintenance_cost":def["service"], "maintenance_days":int(policy()["service_days"]), "failure_chance":rental()["overdue_failure"], "segment":"automotive", "kind":"fleet", "class":cls})
	if not result["ok"]: return result
	S()["seq"] = int(S()["seq"]) + 1
	S()["fleet"][result["id"]] = {"id":result["id"], "class":cls, "plate":plate, "km":0.0, "out":0, "rentals":0, "revenue":0.0, "breakdowns":0, "rental":""}
	GameState.timeline(I18n.t("Added %s to the rental fleet.") % plate, "business")
	return {"ok":true, "id":result["id"]}

static func fleet_item(id: String) -> Dictionary: return Assets.S()["items"].get(id, {})

static func car_state(id: String) -> String:
	var item := fleet_item(id)
	var car: Dictionary = S()["fleet"].get(id, {})
	if item.is_empty() or car.is_empty() or item["status"] == "sold": return "sold"
	if item["status"] == "broken": return "broken"
	if str(car["rental"]) != "": return "rented"
	if int(car["out"]) > Clock.day_index(): return "shop"
	return "ready"

static func service_due() -> Array:
	return fleet_cars().filter(func(id): return bool(fleet_item(id).get("maintenance_due", false)) or fleet_item(id)["status"] == "broken")

static func service_cost(id: String) -> float:
	var item := fleet_item(id)
	var cut := 1.0 - float(cfg()["recon"]["mechanic_cost_cut"]) * float(mini(1, _mechanics()))
	return snappedf((float(class_def(S()["fleet"][id]["class"])["service"]) + float(rental()["service_labor"])) * cut, 1.0) if not item.is_empty() else 0.0

static func service(id: String) -> Dictionary:
	var car: Dictionary = S()["fleet"].get(id, {})
	if not valid() or car.is_empty() or car_state(id) == "sold": return error("Choose a fleet car.")
	if car_state(id) == "rented": return error("Service the car after the rental returns.")
	var item := fleet_item(id)
	item["maintenance_cost"] = service_cost(id)
	var result := Assets.maintain(id)
	if not result["ok"]: return result
	car["out"] = Clock.day_index() + 1
	return {"ok":true, "cost":item["maintenance_cost"]}

static func service_all_due() -> Dictionary:
	var done := 0
	var last := {"ok":false, "error":I18n.t("No fleet car needs service.")}
	for id in service_due():
		if car_state(id) == "rented": continue
		last = service(id)
		if last["ok"]: done += 1
		else: break
	return {"ok":done > 0, "count":done, "error":last.get("error", "")}

static func retire_value(id: String) -> float:
	var item := fleet_item(id)
	var age := float(Clock.day_index() - Clock.day_index_at(int(item["bought"]))) / float(item["life_days"])
	return snappedf(float(item["price"]) * clampf(1.0 - age * 0.55, 0.35, 0.95), 0.01)

static func retire(id: String) -> Dictionary:
	var car: Dictionary = S()["fleet"].get(id, {})
	if not valid() or car.is_empty() or car_state(id) in ["sold", "rented"]: return error("Choose a fleet car that is not on rent.")
	var item := fleet_item(id)
	var got := retire_value(id)
	var book := float(item["book"])
	var lines: Array = [{"acct":"cash", "dr":got}, {"acct":"fixed_assets", "cr":book}]
	lines.append({"acct":"other_income", "cr":got - book} if got >= book else {"acct":"exp:other", "dr":book - got})
	Ledger.post(entity(), I18n.t("Fleet car sold: %s") % car["plate"], lines, source("fleet_sale", id))
	item["status"] = "sold"
	item["book"] = 0.0
	return {"ok":true, "price":got}

static func set_policy(key: String, value: Variant) -> Dictionary:
	var p: Dictionary = policy()
	match key:
		"daily", "weekly":
			var v := float(value)
			if not is_finite(v) or v < float(rental()["price_mult_min"]) - 0.001 or v > float(rental()["price_mult_max"]) + 0.001: return error("Choose a rate between 70% and 140% of the standard rate.")
			p[key] = snappedf(v, 0.05)
		"insurance":
			if not rental()["insurance"].has(str(value)): return error("Choose an insurance cover.")
			p[key] = str(value)
		"service_days":
			if not rental()["service_days"].any(func(d): return int(d) == int(value)): return error("Choose a service interval.")
			p[key] = int(value)
			for id in fleet_cars(): fleet_item(id)["maintenance_days"] = int(value)
		"auto_service": p[key] = bool(value)
		"discount":
			var d := float(value)
			if not is_finite(d) or d < 0 or d > float(dealer()["discount_max"]) + 0.0001: return error("Choose a showroom discount between 0% and 6%.")
			p[key] = snappedf(d, 0.01)
		_: return error("Unknown fleet policy.")
	return {"ok":true}

static func monthly_premium() -> float:
	return float(rental()["insurance"][policy()["insurance"]]["premium"]) * fleet_cars().size() + float(cfg()["stock_insurance_month"]) * stock_count()

static func rating() -> float: return float(S()["reviews"]["sum"]) / maxf(1.0, float(S()["reviews"]["n"]))
static func rating_factor() -> float:
	var r: Dictionary = rental()
	return clampf(1.0 + float(r["rating_slope"]) * (rating() - 4.0), float(r["rating_min"]), float(r["rating_max"]))
static func _review(score: float, weight := 1.0) -> void:
	S()["reviews"]["sum"] = float(S()["reviews"]["sum"]) + clampf(score, 1.0, 5.0) * weight
	S()["reviews"]["n"] = float(S()["reviews"]["n"]) + weight

# ------------------------------------------------------------------ the airport and demand
static func demand_mult() -> float:
	var d: Dictionary = S()["demand"]
	if Clock.now() >= int(d["until"]): return CityFuture.demand_factor("automotive")
	var fraction := float(int(d["until"]) - Clock.now()) / maxf(1.0, float(int(d["until"]) - int(d["from"])))
	return (1.0 + (float(d["start"]) - 1.0) * clampf(fraction, 0.0, 1.0)) * CityFuture.demand_factor("automotive")

static func _set_demand(multiplier: float, days: int) -> void:
	S()["demand"] = {"start":multiplier, "from":Clock.now(), "until":Clock.now() + days * Clock.DAY}

## Hotel guests (#67): average occupied rooms over the last week, read from the hotel's own history.
static func hotel_guests() -> float:
	if not Hotel.is_running(): return 0.0
	var rows: Array = Hotel.S()["history"].slice(maxi(0, Hotel.S()["history"].size() - 7))
	if rows.is_empty(): return 0.0
	var total := 0.0
	for row in rows: total += float(row["occupied"])
	return total / rows.size()

## Charging network (#69): more open stations make EV models easier to sell (0..1 density).
static func ev_charger_density() -> float:
	if not Energy.is_running(): return 0.0
	return clampf(float(Energy.open_stations().size()) / float(cfg()["hooks"]["ev_station_ref"]), 0.0, 1.0)

static func ev_charger_mult() -> float:
	return 1.0 + float(cfg()["hooks"]["ev_charger_demand"]) * ev_charger_density()

## Energy synergy (#69): an active EV-brand franchise raises city EV adoption; Energy reads data.automotive.ev_boost.
static func update_ev_boost() -> void:
	var boost := 0.0
	if dealership_active() and bool(brand_def().get("ev", false)):
		var h: Dictionary = cfg()["hooks"]
		boost = minf(float(h["ev_boost_cap"]), float(h["ev_boost_base"]) + float(h["ev_boost_per_sale"]) * float(S()["franchise"]["sold"]))
	S()["ev_boost"] = snappedf(boost, 0.0001)

static func passengers(t := -1) -> float:
	var when := Clock.now() if t < 0 else t
	var a: Dictionary = cfg()["airport"]
	var month := int(Clock.date_at(when)["month"])
	return snappedf(float(a["pax_base"]) * float(a["season"][month - 1]) * float(a["weekday"][Clock.weekday(when)]), 1.0)

static func rental_requests(t := -1) -> float:
	var r: Dictionary = rental()
	var guests := hotel_guests() * float(cfg()["hooks"]["hotel_guest_rentals"])
	return (passengers(t) + guests) * float(r["request_rate"]) * float(r["capture"]) * demand_mult() * rating_factor()

static func _price_factor(cls: String, days: int) -> float:
	var def := class_def(cls)
	var ref := float(def["weekly"]) / 7.0 if days >= 7 else float(def["rate"])
	var price := weekly_rate(cls) / 7.0 if days >= 7 else daily_rate(cls)
	return clampf(pow(ref / maxf(1.0, price), float(rental()["elasticity"])), 0.15, 1.6)

static func utilization(window := 14) -> float:
	var days: Array = S()["days"]
	var fleet := 0.0
	var rented := 0.0
	for i in range(maxi(0, days.size() - window), days.size()):
		fleet += float(days[i]["fleet"])
		rented += float(days[i]["rented"])
	return rented / fleet if fleet > 0 else 0.0

static func _duration() -> int:
	var roll := GameState.rng.randf()
	for pair in rental()["duration"]:
		roll -= float(pair[1])
		if roll <= 0: return int(pair[0])
	return int(rental()["duration"][0][0])

static func _available(cls: String, day: int) -> String:
	for id in fleet_cars():
		if S()["fleet"][id]["class"] == cls and car_state(id) == "ready" and int(S()["fleet"][id]["out"]) <= day: return str(id)
	return ""

static func _rental_day() -> void:
	var day := Clock.day_index()
	var r: Dictionary = rental()
	# breakdowns first: a failed car cancels the trip it was on
	for id in S()["rentals"].keys():
		var contract: Dictionary = S()["rentals"][id]
		if fleet_item(contract["car"]).get("status", "") == "broken": _breakdown(contract, day)
	for id in S()["rentals"].keys():
		var contract: Dictionary = S()["rentals"][id]
		if int(contract["end"]) <= day: _return(contract, day)
	for id in fleet_cars():
		var item := fleet_item(id)
		if bool(policy()["auto_service"]) and (bool(item.get("maintenance_due", false)) or item["status"] == "broken") and str(S()["fleet"][id]["rental"]) == "" and Ledger.cash(entity()) >= service_cost(id): service(id)
	var requests := 0
	var started := 0
	for cls in r["class_weight"]:
		for pair in r["duration"]:
			var lambda: float = rental_requests() * float(r["class_weight"][cls]) * float(pair[1]) * _price_factor(cls, int(pair[0]))
			for n in GameState.poisson(lambda):
				requests += 1
				var car_id := _available(cls, day)
				if car_id == "": S()["lost"] = int(S()["lost"]) + 1; continue
				_start_rental(car_id, cls, int(pair[0]), day)
				started += 1
	S()["days"].append({"day":day, "fleet":fleet_cars().size(), "rented":S()["rentals"].size(), "requests":requests, "started":started, "lost":requests - started})
	if S()["days"].size() > 60: S()["days"].pop_front()

static func _start_rental(car_id: String, cls: String, days: int, day: int) -> void:
	var id := "RNT-%d" % int(S()["seq"])
	S()["seq"] = int(S()["seq"]) + 1
	var per_day := weekly_rate(cls) / 7.0 if days >= 7 else daily_rate(cls)
	S()["rentals"][id] = {"id":id, "car":car_id, "class":cls, "start":day, "days":days, "end":day + days, "rate":snappedf(per_day, 0.01), "ref":float(class_def(cls)["rate"])}
	S()["fleet"][car_id]["rental"] = id

static func _return(contract: Dictionary, day: int) -> void:
	var r: Dictionary = rental()
	var car: Dictionary = S()["fleet"][contract["car"]]
	var revenue := snappedf(float(contract["rate"]) * int(contract["days"]), 0.01)
	Ledger.post(entity(), I18n.t("Rental returned: %s") % car["plate"], [{"acct":"cash", "dr":revenue}, {"acct":"revenue", "cr":revenue}], source("rental", str(contract["id"])))
	Ledger.expense(entity(), "vehicle", float(r["clean_cost"]), I18n.t("Cleaning and refuelling"), source("rental", str(contract["id"])), _pay_from(float(r["clean_cost"])))
	car["km"] = float(car["km"]) + 90.0 * int(contract["days"])
	car["rentals"] = int(car["rentals"]) + 1
	car["revenue"] = float(car["revenue"]) + revenue
	car["rental"] = ""
	car["out"] = day
	var score := float(r["review_base"]) + (1.0 - float(contract["rate"]) / float(contract["ref"])) * 0.6 + GameState.rng.randf_range(-float(r["review_noise"]), float(r["review_noise"]))
	var item := fleet_item(contract["car"])
	if GameState.rng.randf() < float(r["damage_chance"]):
		_damage(contract["car"], GameState.rng.randf_range(float(r["damage_cost"][0]), float(r["damage_cost"][1])), int(r["damage_days"]), day, false)
		score = minf(score, float(r["damage_review"]))
	elif GameState.rng.randf() < float(r["accident_chance"]):
		_damage(contract["car"], float(item["price"]) * GameState.rng.randf_range(float(r["accident_ratio"][0]), float(r["accident_ratio"][1])), int(r["accident_days"]), day, true)
		score = minf(score, float(r["damage_review"]))
	_review(score)
	S()["completed"] = int(S()["completed"]) + 1
	S()["rentals"].erase(contract["id"])

static func _damage(car_id: String, cost: float, days: int, day: int, accident: bool) -> void:
	var car: Dictionary = S()["fleet"][car_id]
	cost = snappedf(cost, 1.0)
	var cover: Dictionary = rental()["insurance"][policy()["insurance"]]
	var pay := snappedf(maxf(0.0, cost - float(cover["deductible"])) * float(cover["cover"]), 0.01)
	Ledger.expense(entity(), "vehicle", cost, I18n.t("Accident repair: %s") % car["plate"] if accident else I18n.t("Rental damage repair: %s") % car["plate"], source("rental_damage", car_id), _pay_from(cost))
	if pay > 0:
		Ledger.post(entity(), I18n.t("Insurance claim received: %s") % car["plate"], [{"acct":"cash", "dr":pay}, {"acct":"other_income", "cr":pay}], source("insurance_claim", car_id))
		S()["claims"] = int(S()["claims"]) + 1
	car["out"] = day + days

static func _breakdown(contract: Dictionary, day: int) -> void:
	var r: Dictionary = rental()
	var car: Dictionary = S()["fleet"][contract["car"]]
	var used := maxi(0, day - int(contract["start"]))
	var revenue := snappedf(float(contract["rate"]) * used, 0.01)
	if revenue > 0:
		Ledger.post(entity(), I18n.t("Rental interrupted: %s") % car["plate"], [{"acct":"cash", "dr":revenue}, {"acct":"revenue", "cr":revenue}, {"acct":"refunds", "dr":revenue}, {"acct":"cash", "cr":revenue}], source("rental_breakdown", str(contract["id"])))
	Ledger.expense(entity(), "penalties", float(r["voucher"]), I18n.t("Breakdown compensation voucher"), source("rental_breakdown", str(contract["id"])), _pay_from(float(r["voucher"])))
	Ledger.expense(entity(), "vehicle", float(r["tow_cost"]), I18n.t("Roadside tow: %s") % car["plate"], source("rental_breakdown", str(contract["id"])), _pay_from(float(r["tow_cost"])))
	_review(float(r["breakdown_review"]), float(r["breakdown_weight"]))
	car["breakdowns"] = int(car["breakdowns"]) + 1
	car["rental"] = ""
	car["out"] = day + 2
	S()["rentals"].erase(contract["id"])
	S()["lost"] = int(S()["lost"]) + 1

# ------------------------------------------------------------------ the dealership
static func franchise() -> Dictionary: return S()["franchise"]
static func dealership_active() -> bool: return str(franchise()["status"]) == "active"
static func brand_def() -> Dictionary: return dealer()["brands"].get(str(franchise()["brand"]), {})

static func franchise_checks() -> Array:
	var d := dealer()
	var cheapest := 0.0
	for brand in d["brands"].values(): cheapest = maxf(cheapest, float(brand["models"][0]["msrp"]))
	return [
		{"ok":fleet_cars().size() >= int(cfg()["stage_fleet"]) and Living.has_lease("gateway_counter"), "label":"Fleet of %d cars and the rental counter", "arg":int(cfg()["stage_fleet"]), "hint":"Buy rental cars at Gateway Car Rental."},
		{"ok":int(S()["completed"]) >= int(cfg()["stage_rentals"]), "label":"%d completed rentals", "arg":int(cfg()["stage_rentals"]), "hint":"Keep the fleet on rent."},
		{"ok":Living.has_lease("gateway_showroom"), "label":"Showroom leased", "hint":"Lease the showroom at Gateway Car Rental."},
		{"ok":valid() and Ledger.cash(entity()) >= float(d["deposit"]) + float(d["min_order"]) * float(d["brands"]["meridian"]["models"][0]["msrp"]) * (1.0 - float(d["brands"]["meridian"]["margin"])), "label":"Deposit and first order in cash", "hint":"Save cash or arrange a bank loan."}]

static func sign_franchise(brand: String) -> Dictionary:
	var d := dealer()
	if not valid() or dealership_active() or not d["brands"].has(brand): return error("Choose a brand you can sign.")
	for check in franchise_checks():
		if not check["ok"]: return error("Meet every franchise requirement first.")
	var deposit := float(d["deposit"])
	Ledger.post(entity(), I18n.t("Franchise deposit: %s") % I18n.t(d["brands"][brand]["name"]), [{"acct":"deposits", "dr":deposit}, {"acct":"cash", "cr":deposit}], source("franchise", brand))
	S()["franchise"] = {"status":"active", "brand":brand, "deposit":deposit, "since":Clock.day_index(), "short":0, "sold":0, "orders":{}, "visits":0, "month":-1}
	GameState.set_flag("automotive_dealer")
	update_ev_boost()
	GameState.timeline(I18n.t("Signed the %s franchise.") % I18n.t(d["brands"][brand]["name"]), "milestone")
	return {"ok":true}

static func unit_cost(model: Dictionary) -> float:
	return snappedf(float(model["msrp"]) * (1.0 - float(brand_def()["margin"])), 1.0)

static func order_new(model_id: String, qty: int) -> Dictionary:
	if not valid() or not dealership_active(): return error("Sign a franchise first.")
	var model := {}
	for m in brand_def()["models"]:
		if m["id"] == model_id: model = m
	if model.is_empty() or qty < int(dealer()["min_order"]) or qty > 8: return error("Order at least the franchise minimum quantity.")
	if stock_count() + incoming_count() + qty > slots(): return error("The showroom does not have room for that many cars.")
	var cost := unit_cost(model) * qty
	if Ledger.cash(entity()) < cost: return error("Save enough cash for the factory order first.")
	var id := "ORD-%d" % int(S()["seq"])
	S()["seq"] = int(S()["seq"]) + 1
	Ledger.post(entity(), I18n.t("Factory order: %s") % I18n.t(model["name"]), [{"acct":"inventory_in_transit", "dr":cost}, {"acct":"cash", "cr":cost}], source("auto_order", id))
	var arrive := Clock.now() + int(dealer()["delivery_days"]) * Clock.DAY
	S()["franchise"]["orders"][id] = {"id":id, "model":model_id, "name":model["name"], "msrp":model["msrp"], "qty":qty, "cost":cost, "arrive":arrive}
	Sim.schedule(arrive, "auto.delivery", {"id":id})
	return {"ok":true, "id":id}

static func _deliver(order_id: String) -> void:
	var order: Dictionary = S()["franchise"]["orders"].get(order_id, {})
	if order.is_empty(): return
	var each := float(order["cost"]) / int(order["qty"])
	Ledger.post(entity(), I18n.t("Factory delivery: %s") % I18n.t(order["name"]), [{"acct":"inventory", "dr":order["cost"]}, {"acct":"inventory_in_transit", "cr":order["cost"]}], source("auto_order", order_id))
	for n in int(order["qty"]):
		var id := "NEW-%d" % int(S()["seq"])
		S()["seq"] = int(S()["seq"]) + 1
		S()["stock"][id] = {"id":id, "model":order["model"], "name":order["name"], "class":"new", "base":order["msrp"], "msrp":order["msrp"], "cost":each, "recon":0.0, "status":"lot", "new":true, "defect":"", "known":true, "fixed":0.0, "ext":1.0, "mech":1.0, "km":0.0, "age":0, "list":0.0, "ready":0, "listed_day":0}
	S()["franchise"]["orders"].erase(order_id)

static func new_stock(model_id := "") -> Array:
	return S()["stock"].values().filter(func(c): return bool(c["new"]) and (model_id == "" or c["model"] == model_id))

static func new_car_price(msrp: float) -> float: return snappedf(msrp * (1.0 - float(policy()["discount"])), 1.0)

static func _walk_ins() -> void:
	if not dealership_active(): return
	var d := dealer()
	var brand := brand_def()
	var season: float = cfg()["airport"]["season"][int(Clock.date()["month"]) - 1]
	var lambda := float(d["walkins"]) * float(brand["demand"]) * demand_mult() * (1.0 + (season - 1.0) * 0.5) * (ev_charger_mult() if bool(brand["ev"]) else 1.0) * (0.85 + 0.15 * rating_factor())
	var chance := clampf(float(d["buy_base"]) + float(d["buy_discount_gain"]) * float(policy()["discount"]), 0.0, 0.9)
	for n in GameState.poisson(lambda):
		var roll := GameState.rng.randf()
		var model: Dictionary = brand["models"][0]
		for m in brand["models"]:
			roll -= float(m["weight"])
			if roll <= 0: model = m; break
		if GameState.rng.randf() >= chance: continue
		var cars := new_stock(str(model["id"]))
		if cars.is_empty(): S()["lost"] = int(S()["lost"]) + 1; continue
		var car: Dictionary = cars[0]
		car["list"] = new_car_price(float(car["msrp"]))
		_close_sale(car, float(car["list"]), I18n.t("New car sold: %s") % I18n.t(car["name"]), "auto_new_sale")
		S()["franchise"]["sold"] = int(S()["franchise"]["sold"]) + 1
		GameState.inc_stat("cars_sold")

static func _after_sales() -> void:
	if not dealership_active(): return
	var d := dealer()
	var visits := GameState.poisson(float(S()["franchise"]["sold"]) * float(d["service_rate"]))
	var bays := int(d["bay_base"]) + int(d["bay_mechanic"]) * mini(1, _mechanics())
	for n in mini(visits, bays):
		var ticket := snappedf(GameState.rng.randf_range(float(d["service_ticket"][0]), float(d["service_ticket"][1])), 1.0)
		var parts := snappedf(ticket * float(d["service_cost"]), 0.01)
		Ledger.post(entity(), I18n.t("After-sales service ticket"), [{"acct":"cash", "dr":ticket}, {"acct":"revenue", "cr":ticket}, {"acct":"cogs", "dr":parts}, {"acct":"cash", "cr":parts}], source("service", ""))
		S()["franchise"]["visits"] = int(S()["franchise"]["visits"]) + 1

static func _monthly() -> void:
	var date := Clock.date()
	if int(date["day"]) != 1: return
	var key := int(date["year"]) * 12 + int(date["month"])
	if int(S()["franchise"].get("month", -1)) == key and dealership_active(): return
	if monthly_premium() > 0:
		Ledger.expense(entity(), "insurance", monthly_premium(), I18n.t("Fleet and lot insurance"), source("insurance"), _pay_from(monthly_premium()))
	if not dealership_active(): return
	S()["franchise"]["month"] = key
	var d := dealer()
	var stock_value := 0.0
	for car in new_stock(): stock_value += float(car["cost"])
	var interest := snappedf(stock_value * float(d["floorplan_month"]), 0.01)
	if interest > 0: Ledger.expense(entity(), "interest", interest, I18n.t("Floor-plan interest"), source("floorplan"), _pay_from(interest))
	var shortfall := maxi(0, int(d["min_stock"]) - new_stock().size() - incoming_count())
	if shortfall > 0:
		var fee := float(d["shortfall_fee"]) * shortfall
		Ledger.expense(entity(), "penalties", fee, I18n.t("Franchise minimum-stock shortfall"), source("franchise"), _pay_from(fee))
		S()["franchise"]["short"] = int(S()["franchise"]["short"]) + 1
		if int(S()["franchise"]["short"]) >= int(d["terminate_after"]): terminate(true)
	else:
		S()["franchise"]["short"] = 0

static func terminate(forced := false) -> Dictionary:
	if not valid() or not dealership_active(): return error("Sign a franchise first.")
	var d := dealer()
	var deposit := float(S()["franchise"]["deposit"])
	var forfeit := snappedf(deposit * float(d["deposit_forfeit"]), 0.01) if forced else 0.0
	var lines: Array = [{"acct":"cash", "dr":deposit - forfeit}, {"acct":"deposits", "cr":deposit}]
	if forfeit > 0: lines.append({"acct":"exp:penalties", "dr":forfeit})
	Ledger.post(entity(), I18n.t("Franchise deposit settled"), lines, source("franchise"))
	for car in new_stock():
		var got := snappedf(float(car["cost"]) * 0.95, 0.01)
		Ledger.post(entity(), I18n.t("New car returned to the factory: %s") % I18n.t(car["name"]), [{"acct":"cash", "dr":got}, {"acct":"exp:other", "dr":float(car["cost"]) - got}, {"acct":"inventory", "cr":car["cost"]}], source("franchise"))
		S()["stock"].erase(car["id"])
	for id in S()["franchise"]["orders"].keys():
		var order: Dictionary = S()["franchise"]["orders"][id]
		Ledger.post(entity(), I18n.t("Factory order cancelled"), [{"acct":"cash", "dr":order["cost"]}, {"acct":"inventory_in_transit", "cr":order["cost"]}], source("franchise"))
		Sim.cancel("auto.delivery", "id", id)
	S()["franchise"] = {"status":"ended", "brand":"", "deposit":0.0, "since":0, "short":0, "sold":int(S()["franchise"]["sold"]), "orders":{}, "visits":0, "month":-1}
	update_ev_boost()
	GameState.set_flag("automotive_dealer", false)
	return {"ok":true, "forfeit":forfeit}

# ------------------------------------------------------------------ crises
static func _flood_car() -> Dictionary:
	var best := {}
	for car in S()["stock"].values():
		if str(car["defect"]) == "flood" and float(car["fixed"]) < 1.0 and (best.is_empty() or bool(best["known"]) and not bool(car["known"])): best = car
	return best

static func crisis(kind: String, _retain := true) -> Dictionary:
	if not valid(): return error("Open the auto desk first.")
	var c: Dictionary = cfg()["crisis"]
	match kind:
		"flood_disclose", "flood_repair", "flood_hide":
			var car := _flood_car()
			if car.is_empty(): return {"ok":true}
			if kind == "flood_disclose":
				car["known"] = true
				car["claim_risk"] = 0.0
			elif kind == "flood_repair":
				car["known"] = true
				car["claim_risk"] = 0.0
				if car["status"] in ["lot", "listed"]:
					var spent := recon("%s" % car["id"], "repair")
					if not spent["ok"]: return spent
			else:
				car["claim_risk"] = float(c["flood_claim_chance"])
		"fuel_hold": _set_demand(float(c["fuel_demand"]), int(c["fuel_days"]))
		"fuel_cut":
			_set_demand(float(c["fuel_cut_demand"]), int(c["fuel_cut_days"]))
			S()["rate_cut"] = Clock.now() + int(c["fuel_cut_days"]) * Clock.DAY
		"claim_pay": Ledger.expense(entity(), "vehicle", float(c["claim_amount"]), I18n.t("Repair paid after an insurer dispute"), source("claim"), _pay_from(float(c["claim_amount"])))
		"claim_settle": Ledger.expense(entity(), "vehicle", float(c["claim_amount"]) * float(c["claim_settle"]), I18n.t("Insurer dispute settled at a discount"), source("claim"), _pay_from(float(c["claim_amount"])))
		"claim_fight":
			Ledger.expense(entity(), "other", float(c["claim_legal"]), I18n.t("Legal fee for an insurer dispute"), source("claim"), _pay_from(float(c["claim_legal"])))
			if GameState.rng.randf() >= float(c["claim_win"]):
				Ledger.expense(entity(), "vehicle", float(c["claim_amount"]), I18n.t("Repair paid after a lost dispute"), source("claim"), _pay_from(float(c["claim_amount"])))
		"recall_pull", "recall_run":
			var ids: Array = fleet_cars()
			ids.sort()
			ids = ids.slice(0, mini(int(c["recall_max"]), ceili(ids.size() * float(c["recall_share"]))))
			for id in ids:
				if kind == "recall_pull":
					var open_id := str(S()["fleet"][id]["rental"])
					if open_id != "":
						S()["rentals"].erase(open_id)
						S()["fleet"][id]["rental"] = ""
						S()["lost"] = int(S()["lost"]) + 1
					Ledger.expense(entity(), "vehicle", float(c["recall_labor"]), I18n.t("Recall handling: %s") % S()["fleet"][id]["plate"], source("recall", id), _pay_from(float(c["recall_labor"])))
					S()["fleet"][id]["out"] = maxi(int(S()["fleet"][id]["out"]), Clock.day_index() + int(c["recall_days"]))
			if kind == "recall_run": S()["recall"] = {"until":Clock.now() + int(c["recall_risk_days"]) * Clock.DAY, "ids":ids}
		_: return error("Unknown automotive crisis.")
	return {"ok":true}

# ------------------------------------------------------------------ clock
static func _flags() -> void:
	var has_flood := not _flood_car().is_empty()
	for pair in [["automotive_stock", stock_count() > 0], ["automotive_fleet", fleet_cars().size() > 0], ["automotive_flood", has_flood]]:
		if GameState.flag(pair[0]) != pair[1]: GameState.set_flag(pair[0], pair[1])

static func on_hour(t: int, h: int) -> void:
	if not valid(): return
	match h:
		6:
			refresh()
			for car in S()["stock"].values():
				if car["status"] == "shop" and int(car["ready"]) <= Clock.day_index(): car["status"] = "lot"
			_flags()
		8:
			_monthly()
			_recall_faults()
			_rental_day()
		10:
			var stored: int = S()["stock"].size()
			if stored > 0:
				var fee: float = float(cfg()["storage_day"]) * stored
				Ledger.expense(entity(), "vehicle", fee, I18n.t("Lot storage and preparation"), source("storage"), _pay_from(fee))
		11:
			var demand := demand_mult()
			for car in S()["stock"].values().duplicate():
				if car["status"] == "listed" and GameState.rng.randf() < sale_probability(float(car["list"]) / market_value(car)) * demand: _sell_retail(car)
		12: _walk_ins()
		15:
			_after_sales()
			update_ev_boost()
		17:
			for lot in S()["lots"].values():
				if lot["status"] != "open": continue
				if str(lot["leader"]) == "player" and auction_day(): auction_hammer(str(lot["id"]))
				elif auction_day(): lot["status"] = "ended"
	var _u := t

static func _recall_faults() -> void:
	var recall: Dictionary = S()["recall"]
	if Clock.now() >= int(recall["until"]): return
	for id in recall["ids"]:
		var item := fleet_item(id)
		if not item.is_empty() and item["status"] == "working" and GameState.rng.randf() < float(cfg()["crisis"]["recall_fault"]): item["status"] = "broken"

static func handle(kind: String, payload: Dictionary) -> void:
	if not valid(): return
	match kind:
		"auto.claim":
			var amount := snappedf(float(payload["price"]) * float(payload["hit"]), 0.01)
			Ledger.post(entity(), I18n.t("Warranty claim on a used car"), [{"acct":"refunds", "dr":amount}, {"acct":_pay_from(amount), "cr":amount}], source("warranty_claim"))
			if bool(payload.get("fine", false)):
				Ledger.expense(entity(), "penalties", float(cfg()["crisis"]["flood_fine"]), I18n.t("Consumer-protection fine for an undisclosed flood car"), source("warranty_claim"), _pay_from(float(cfg()["crisis"]["flood_fine"])))
		"auto.delivery": _deliver(str(payload.get("id", "")))

static func on_company_closed(closed: String) -> void:
	if not is_running() or entity() != closed: return
	for car in S()["stock"].values():
		var got := snappedf(float(car["cost"]) * clampf(float(cfg()["resale_stock"]), 0.4, 0.6), 0.01)
		Ledger.post(closed, I18n.t("Stock car auctioned: %s") % I18n.t(car["name"]), [{"acct":"cash", "dr":got}, {"acct":"exp:other", "dr":float(car["cost"]) - got}, {"acct":"inventory", "cr":car["cost"]}], source("liquidation"))
	S()["stock"] = {}
	for id in S()["franchise"]["orders"].keys():
		var order: Dictionary = S()["franchise"]["orders"][id]
		Ledger.post(closed, I18n.t("Factory order cancelled"), [{"acct":"cash", "dr":order["cost"]}, {"acct":"inventory_in_transit", "cr":order["cost"]}], source("liquidation"))
	if dealership_active():
		Ledger.post(closed, I18n.t("Franchise deposit settled"), [{"acct":"cash", "dr":S()["franchise"]["deposit"]}, {"acct":"deposits", "cr":S()["franchise"]["deposit"]}], source("liquidation"))
	S()["franchise"] = {"status":"ended", "brand":"", "deposit":0.0, "since":0, "short":0, "sold":0, "orders":{}, "visits":0, "month":-1}
	update_ev_boost()
	S()["rentals"] = {}
	S()["lots"] = {}
	S()["active"] = false
	for flag in ["automotive_active", "automotive_stock", "automotive_fleet", "automotive_flood", "automotive_dealer"]: GameState.set_flag(flag, false)
	Sim.cancel("auto.delivery", "", null)
	Sim.cancel("auto.claim", "", null)

## What the bank may lend against: used and new stock cars (fleet cars are already operating assets).
static func stock_cost() -> float:
	if not GameState.has_game() or not GameState.data.has("automotive") or entity() != GameState.company_id(): return 0.0
	var total := 0.0
	for car in S()["stock"].values(): total += float(car["cost"])
	return total

static func os_tab() -> Dictionary: return {"id":"automotive", "label":"Automotive", "icon":"metro", "order":8, "start_label":"Open Auto Desk", "render":AutomotiveUI.render}
static func board_detail() -> Callable: return AutomotiveUI.board
static func open_action(params: Dictionary, _source: Node) -> void: AutomotiveUI.open(str(params.get("page", "auction")))
