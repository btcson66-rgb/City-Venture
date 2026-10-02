class_name Replay
extends RefCounted
## Saved run rules and scenario state; tuning stays in difficulty/scenarios JSON. Old saves keep original rules.

const RANK_PATH := "user://challenge_history.json"
static var rank_path := RANK_PATH
static var history_error := ""


static func active() -> bool:
	return GameState.has_game() and GameState.data.has("run")


static func S() -> Dictionary:
	return GameState.data.get("run", {})


static func rules(id: String, custom := {}) -> Dictionary:
	var presets: Dictionary = DataDB.difficulty.get("presets", {})
	var out: Dictionary = presets.get(id, presets.get("standard", {})).duplicate(true)
	if id == "custom":
		for key in DataDB.difficulty.get("fields", {}):
			var field: Dictionary = DataDB.difficulty["fields"][key]
			var value: Variant = custom.get(key, out.get(key, field["min"]))
			if typeof(value) in [TYPE_FLOAT, TYPE_INT] and is_finite(float(value)):
				out[key] = snappedf(clampf(float(value), float(field["min"]), float(field["max"])), float(field["step"]))
	return out


static func number(key: String, fallback: float) -> float:
	return float(S().get("rules", {}).get(key, fallback))


static func story_enabled() -> bool:
	return bool(S().get("story", true))


static func opening_cash(setup: Dictionary) -> float:
	if not setup.has("run"):
		return float(DataDB.living().get("start_cash", 30000))
	var options: Dictionary = setup["run"]
	var scenario: Dictionary = DataDB.scenarios.get(str(options.get("scenario", "")), {})
	return float(scenario.get("initial", {}).get("cash", rules(str(options.get("difficulty", "standard")), options.get("custom", {})).get("initial_cash", 30000)))


## Monday 00:00 UTC; no server, locale or timezone dependence. Explicit time supports repeatable tests.
static func weekly(unix := -1.0) -> Dictionary:
	if unix < 0:
		unix = Time.get_unix_time_from_system()
	var week := int(floor((unix + 259200.0) / 604800.0))
	var ids: Array = DataDB.scenarios.keys()
	ids.sort()
	return {"week": str(week), "seed": (week * 7919 + 89) % 2147483647,
		"run": {"difficulty": "standard", "scenario": ids[posmod(week, ids.size())], "story": false, "week": str(week)}}


static func initialize(options: Dictionary) -> void:
	var definition: Dictionary = DataDB.scenarios.get(str(options.get("scenario", "")), {}).duplicate(true)
	GameState.data["run"] = {"version": 1, "difficulty": str(options.get("difficulty", "standard")),
		"rules": rules(str(options.get("difficulty", "standard")), options.get("custom", {})),
		"story": bool(options.get("story", true)), "scenario": definition, "week": str(options.get("week", "")),
		"started": Clock.now(), "status": "running", "result": {}, "opening_seen": false, "result_seen": false,
		"seed": int(GameState.data["rng"]["seed"]), "preferences": {}, "rent_period": "", "recorded": false, "run_id": str(GameState.data["meta"]["created_unix"])}
	var seeded := RandomNumberGenerator.new()
	seeded.seed = int(S()["seed"])
	var ids: Array = DataDB.npcs.keys()
	ids.sort()
	var choices: Array = DataDB.difficulty.get("market", {}).get("preferences", ["budget", "quality", "speed"])
	for id in ids:
		S()["preferences"][id] = choices[seeded.randi_range(0, choices.size() - 1)]
	# Preferences live in the run namespace so future NPC relationship state is not overwritten.
	_setup_scenario(definition.get("initial", {}))
	S()["starting_net_worth"] = net_worth()
	if not definition.is_empty():
		var months := int(definition.get("limit_months", 0))
		if months > 0:
			var date: Dictionary = Clock.date()
			var month := int(date["month"]) - 1 + months
			var end := {"year": int(date["year"]) + int(month / 12), "month": month % 12 + 1, "day": int(date["day"])}
			S()["deadline"] = int((Time.get_unix_time_from_datetime_dict(end) - Time.get_unix_time_from_datetime_dict(GameState.data["clock"]["start"])) / 60) + Clock.minute_of_day()
		else:
			S()["deadline"] = Clock.now() + int(definition.get("limit_days", 120)) * Clock.DAY


static func _setup_scenario(initial: Dictionary) -> void:
	if initial.has("credit"):
		Bank.B()["credit"] = int(initial["credit"])
		Bank.B()["no_loans_until"] = Clock.now() + int(initial.get("ban_days", 0)) * Clock.DAY
	if initial.has("company"):
		var registration := Company.register(str(initial["company"]), str(initial["type"]), "riverside_studio")
		assert(registration.get("ok", false))
		assert(Company.open_business_account(float(initial["capital"])).get("ok", false))
		S()["company"] = GameState.company_id()
	var entity := GameState.business_entity()
	if initial.get("cafe", false):
		GameState.data["living"]["leases"][Cafe.property_id()] = {"entity": entity, "rent": float(DataDB.properties[Cafe.property_id()]["monthly_rent"]), "day": int(Clock.date()["day"]), "since": Clock.now()}
		Cafe.S()["fit_ready"] = Clock.now()
		Cafe.S()["supplies"] = int(initial["supplies"])
		Cafe.S()["rating"] = float(initial["rating"])
		GameState.set_flag("food_permit")
		GameState.set_flag("employer_registered")
		var person := Staff._make_person("barista")
		person.merge({"salary_week": float(initial["salary"]), "skill": int(initial["skill"]), "hired": Clock.now(), "start": Clock.now(), "weeks": 0, "last_raise": Clock.now()}, true)
		Staff.S()["people"][person["id"]] = person
		Ledger.post(entity, I18n.t("Inherited café supplies: %d cups") % int(initial["supplies"]), [{"acct": "cogs", "dr": int(initial["supplies"]) * float(Cafe.item("coffee")["unit_cost"])}, {"acct": "equity", "cr": int(initial["supplies"]) * float(Cafe.item("coffee")["unit_cost"])}], {"type": "opening"})
	if initial.has("loan"):
		_open_loan(entity, float(initial["loan"]), int(initial["loan_months"]))
	if initial.get("van", false):
		assert(Logistics.buy_van().get("ok", false))
		for index in int(initial.get("contracts", 2)):
			var job := Logistics._make_job()
			Logistics.S()["jobs"][job["id"]] = job
			Logistics.accept(str(job["id"]))
	if initial.has("property"):
		Ledger.post("player", I18n.t("Inherited property — %s") % str(initial["property"]), [{"acct": "property", "dr": float(initial["property_value"])}, {"acct": "loan_payable", "cr": float(initial["mortgage"])}, {"acct": "equity", "cr": float(initial["property_value"]) - float(initial["mortgage"])}], {"type": "opening"})
		_open_loan("player", float(initial["mortgage"]), int(initial["mortgage_months"]), false, float(initial.get("mortgage_apr", Bank.apr())) + number("interest_surcharge", 0.0))
	if not story_enabled():
		for side in DataDB.story.get("side", []):
			if not bool(side.get("main", false)):
				StoryEngine.start_objective(str(side["id"]))


static func _open_loan(entity: String, principal: float, months: int, cash_received := true, fixed_rate := -1.0) -> void:
	var id := "L%d" % int(Bank.B()["seq"])
	Bank.B()["seq"] = int(Bank.B()["seq"]) + 1
	var rate := Bank.apr() if fixed_rate < 0 else fixed_rate
	Bank.B()["loans"][id] = {"id": id, "entity": entity, "amount": principal, "balance": principal, "months": months, "apr": rate,
		"payment": Bank.monthly_payment(principal, months, rate), "paid_n": 0, "missed": 0, "status": "active", "opened": Clock.now(), "next": Clock.now() + 30 * Clock.DAY}
	if cash_received:
		Ledger.post(entity, I18n.t("Inherited loan: %s") % Fmt.money(principal), [{"acct": "cash", "dr": principal}, {"acct": "loan_payable", "cr": principal}], {"type": "opening"})
	Sim.schedule(Clock.now() + 30 * Clock.DAY, "bank.payment", {"id": id})


## Stateless per-day seed: previewing a market never consumes the simulation RNG or changes future outcomes.
static func demand(key: String) -> float:
	if not active():
		return 1.0
	var seeded := RandomNumberGenerator.new()
	seeded.seed = int(S()["seed"]) ^ key.hash()
	var market: Dictionary = DataDB.difficulty.get("market", {})
	var base := seeded.randf_range(float(market.get("base_min", 0.85)), float(market.get("base_max", 1.15)))
	var preference := seeded.randf_range(float(market.get("preference_min", 0.9)), float(market.get("preference_max", 1.1)))
	# The seeded population preference mix changes price-sensitive vs service-sensitive demand.
	var budget := 0
	for value in S().get("preferences", {}).values():
		budget += int(value == "budget")
	var population: int = S().get("preferences", {}).size()
	if population > 0:
		preference = lerpf(1.0, preference, float(budget) / population)
	seeded.seed = int(S()["seed"]) ^ (key + str(Clock.day_index())).hash()
	return maxf(0.1, base * preference * (1.0 + seeded.randf_range(-1.0, 1.0) * number("demand_volatility", 0.0)))


static func net_worth() -> float:
	var total := 0.0
	for entity in GameState.data["entities"]:
		if entity != "player" and GameState.data["entities"][entity].get("kind", "") != "company":
			continue
		if entity != "player":
			total += Ledger.balance(entity, "investments")
		for account in ["cash", "marketplace_balance", "accounts_receivable", "inventory", "inventory_in_transit", "goods_out", "deposits", "property", "escrow_held", "frozen_funds", "loan_payable", "wages_payable", "accounts_payable", "deferred_revenue"]:
			total += Ledger.balance(entity, account)
	return snappedf(total, 0.01)


static func metrics() -> Dictionary:
	var revenue := 0.0
	for entity in GameState.data["entities"]:
		revenue -= Ledger.balance(entity, "revenue") + Ledger.balance(entity, "refunds")
	var rating := -1.0
	if GameState.data.has("cafe") and Cafe.ready_to_open():
		rating = float(GameState.data["cafe"]["rating"])
	elif GameState.data.get("careers", {}).get("freelance", {}).get("active", false):
		rating = float(GameState.data["careers"]["freelance"]["rep"])
	elif int(S().get("work_count", 0)) > 0:
		rating = float(S()["work_scores"]) / float(S()["work_count"]) * 5.0
	return {"revenue": revenue, "cash": Ledger.cash("player") + (Ledger.cash(GameState.company_id()) if GameState.company_id() != "" else 0.0),
		"net_worth": net_worth(), "net_worth_gain": net_worth() - float(S().get("starting_net_worth", 0)), "rating": rating,
		"runs": int(GameState.stat("van_runs")), "shifts": int(GameState.stat("shifts_worked")),
		"elapsed_days": float(Clock.now() - int(S().get("started", Clock.now()))) / Clock.DAY}


static func on_hour(_t: int, h: int) -> void:
	if not active():
		return
	var initial: Dictionary = S().get("scenario", {}).get("initial", {})
	if initial.has("property") and h == 9 and Clock.month_key() != str(S().get("rent_period", "")):
		S()["rent_period"] = Clock.month_key()
		var random := GameState.randf()
		if random >= float(initial["vacancy_chance"]):
			var rent := float(initial["rent"])
			Ledger.post("player", I18n.t("Property rent — %s") % str(initial["property"]), [{"acct": "cash", "dr": rent}, {"acct": "revenue", "cr": rent}], {"type": "property"})
		Ledger.expense("player", "other", float(initial["maintenance"]), I18n.t("Property maintenance — %s") % str(initial["property"]), {"type": "property"})
		if GameState.randf() < float(initial["repair_chance"]):
			Ledger.expense("player", "other", float(initial["repair_cost"]), I18n.t("Property repair — %s") % str(initial["property"]), {"type": "property"})
	evaluate()


static func evaluate() -> String:
	if not active() or S().get("scenario", {}).is_empty() or S().get("status", "") != "running":
		return str(S().get("status", ""))
	var values := metrics()
	var definition: Dictionary = S()["scenario"]
	var won := true
	for key in definition.get("win", {}):
		won = won and float(values.get(key, -INF)) >= float(definition["win"][key])
	var closed: bool = S().has("company") and GameState.data["entities"].get(str(S()["company"]), {}).has("closed")
	var defaulted := false
	for loan in Bank.B()["loans"].values():
		defaulted = defaulted or loan.get("status", "") == "defaulted"
	var expired := Clock.now() >= int(S().get("deadline", 9223372036854775807))
	if not closed and not defaulted and won and Clock.now() <= int(S().get("deadline", 9223372036854775807)):
		_finish("won", values)
	elif closed or defaulted or expired:
		if float(definition.get("initial", {}).get("board_capital", 0)) > 0 and GameState.company_id() != "":
			var entity := GameState.company_id()
			var amount := minf(maxf(0, Ledger.cash(entity)), float(definition["initial"]["board_capital"]))
			Ledger.post(entity, I18n.t("Board capital withdrawn: %s") % Fmt.money(amount), [{"acct": "equity", "dr": amount}, {"acct": "cash", "cr": amount}], {"type": "capital"})
		_finish("lost", metrics())
	return str(S()["status"])


static func _finish(status: String, values: Dictionary) -> void:
	S()["status"] = status
	var scoring: Dictionary = DataDB.difficulty.get("score", {})
	var score := maxi(0, roundi(float(values["net_worth"]) / float(scoring.get("wealth_divisor", 100)) - float(values["elapsed_days"]) * float(scoring.get("day_penalty", 10)) + maxf(0.0, float(values["rating"])) * float(scoring.get("rating_weight", 1000))))
	S()["result"] = values.duplicate(true)
	S()["result"]["score"] = score
	S()["result"]["status"] = status
	GameState.timeline(I18n.t("Scenario finished: %s") % I18n.t(str(S()["scenario"]["name"])), "milestone")
	record_result()
	if Clock.world_active:
		UIRoot.open_modal.call_deferred(RunCardModal.new(false))


static func history() -> Array:
	history_error = ""
	if not FileAccess.file_exists(rank_path):
		return []
	var file := FileAccess.open(rank_path, FileAccess.READ)
	if file == null or file.get_length() > 1024 * 1024:
		history_error = "unreadable"
		return []
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Array:
		history_error = "invalid"
		return []
	var valid: Array = []
	for row in parsed:
		if not row is Dictionary or not row.get("result", null) is Dictionary:
			history_error = "invalid"
			continue
		var score: Variant = row["result"].get("score", null)
		if not typeof(score) in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(score)):
			history_error = "invalid"
			continue
		valid.append(row)
	return valid


static func record_result() -> bool:
	if str(S().get("week", "")) == "" or S().get("result", {}).is_empty() or bool(S().get("recorded", false)):
		return false
	var rows := history()
	if not history_error.is_empty():
		return false
	for row in rows:
		if str(row.get("run_id", "")) == str(S().get("run_id", "")) and str(S().get("run_id", "")) != "":
			S()["recorded"] = true
			return true
	rows.append({"run_id": S().get("run_id", ""), "week": S()["week"], "seed": S()["seed"], "scenario": S()["scenario"]["id"], "name": GameState.data["player"]["name"], "result": S()["result"].duplicate(true)})
	while rows.size() > int(DataDB.difficulty.get("leaderboard_limit", 100)):
		rows.pop_front()
	var file := FileAccess.open(rank_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(rows))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	if DirAccess.rename_absolute(rank_path + ".tmp", rank_path) != OK:
		return false
	S()["recorded"] = true
	return true


static func pending_card() -> String:
	if not active() or S().get("scenario", {}).is_empty():
		return ""
	if S().get("status", "running") != "running":
		return "result" if not bool(S().get("result_seen", false)) else ""
	return "opening" if not bool(S().get("opening_seen", false)) else ""


## Restoring location restores an unread card too; it does not replay any financial settlement.
static func resume_cards() -> void:
	var pending := pending_card()
	if pending != "":
		UIRoot.open_modal(RunCardModal.new(pending == "opening"))


static func record_work_score(score: float) -> void:
	if not active():
		return
	S()["work_count"] = int(S().get("work_count", 0)) + 1
	S()["work_scores"] = float(S().get("work_scores", 0.0)) + clampf(score, 0.0, 1.0)
