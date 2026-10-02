class_name Macro
extends RefCounted
## Seeded, saved daily mean reversion. Era scripts remain overlays; shocks have a finite lifetime.


static func cfg() -> Dictionary:
	return DataDB.economy.get("macro", {})


static func active() -> bool:
	return GameState.has_game() and GameState.data.has("macro")


static func S() -> Dictionary:
	return GameState.data.get("macro", {})


static func initialize() -> void:
	if not GameState.has_game() or active():
		return
	var random := RandomNumberGenerator.new()
	random.seed = int(GameState.data["rng"]["seed"]) ^ 9001
	GameState.data["macro"] = {"version": 1, "rng_state": str(random.state), "day": Clock.day_index() - 1,
		"rate": float(cfg()["rate_mean"]), "index": 1.0, "inflation": 1.0, "trend": 0.0, "shock": 0.0, "shock_until": -1, "path": []}
	Rivals.initialize()


static func phase() -> String:
	var index := float(S().get("index", 1.0))
	if index >= float(cfg().get("peak", 1.08)):
		return "Peak"
	if index <= float(cfg().get("trough", 0.92)):
		return "Trough"
	return "Expansion" if float(S().get("trend", 0.0)) >= 0 else "Recession"


static func rate() -> float:
	var overlay := float(World.era().get("interest_rate", cfg().get("rate_mean", 0.025)))
	return clampf(float(S().get("rate", cfg().get("rate_mean", 0.025))) + overlay - float(cfg().get("rate_mean", 0.025)), float(cfg().get("rate_min", 0.005)), float(cfg().get("rate_max", 0.12))) if active() else overlay


static func costs() -> float:
	return float(S().get("inflation", 1.0))


static func demand(industry: String) -> float:
	if not active():
		return 1.0
	var sensitivity: Dictionary = cfg().get("industries", {}).get(industry, {"cycle": 1.0, "rate": 1.0})
	return clampf(1.0 + (float(S()["index"]) - 1.0) * float(sensitivity["cycle"]) - (rate() - float(cfg()["rate_mean"])) * float(sensitivity["rate"]), float(cfg()["demand_min"]), float(cfg()["demand_max"]))


static func on_hour(_t: int, h: int) -> void:
	# Legacy saves acquire the optional state when played, never through passive quotes or unit fixtures.
	if not active() and Clock.world_active:
		initialize()
	if not active():
		return
	advance_to(Clock.day_index())
	Rivals.on_hour(_t, h)
	if h == 8:
		CityNews.publish_day()


## Catch up every missing day using the saved private RNG, including after load/large clock jumps.
static func advance_to(day: int) -> void:
	var random := RandomNumberGenerator.new()
	random.state = int(S()["rng_state"])
	while int(S()["day"]) < day:
		var next := int(S()["day"]) + 1
		if next >= int(S()["shock_until"]):
			S()["shock"] = 0.0
		if random.randf() < float(cfg()["shock_chance"]):
			S()["shock"] = random.randf_range(-float(cfg()["shock_size"]), float(cfg()["shock_size"]))
			S()["shock_until"] = next + int(cfg()["shock_days"])
		var previous := float(S()["index"])
		S()["rate"] = clampf(float(S()["rate"]) + float(cfg()["rate_reversion"]) * (float(cfg()["rate_mean"]) - float(S()["rate"])) + random.randf_range(-float(cfg()["rate_noise"]), float(cfg()["rate_noise"])) + float(S()["shock"]) * float(cfg()["rate_shock"]), float(cfg()["rate_min"]), float(cfg()["rate_max"]))
		S()["index"] = clampf(previous + float(cfg()["cycle_reversion"]) * (1.0 - previous) + random.randf_range(-float(cfg()["cycle_noise"]), float(cfg()["cycle_noise"])) + float(S()["shock"]), float(cfg()["cycle_min"]), float(cfg()["cycle_max"]))
		S()["rate"] = clampf(snappedf(float(S()["rate"]), 0.000000001), float(cfg()["rate_min"]), float(cfg()["rate_max"]))
		S()["index"] = clampf(snappedf(float(S()["index"]), 0.000000001), float(cfg()["cycle_min"]), float(cfg()["cycle_max"]))
		S()["shock"] = snappedf(float(S()["shock"]), 0.000000001)
		S()["trend"] = snappedf(float(S()["index"]) - previous, 0.000000001)
		S()["inflation"] = clampf(float(S()["inflation"]) + float(cfg()["inflation_reversion"]) * (1.0 - float(S()["inflation"])) + (float(S()["index"]) - 1.0) * float(cfg()["inflation_cycle"]) + random.randf_range(-float(cfg()["inflation_noise"]), float(cfg()["inflation_noise"])), float(cfg()["inflation_min"]), float(cfg()["inflation_max"]))
		S()["inflation"] = snappedf(float(S()["inflation"]), 0.000000001)
		S()["day"] = next
		S()["path"].append({"day": next, "rate": S()["rate"], "index": S()["index"], "inflation": S()["inflation"]})
		while S()["path"].size() > int(cfg()["history_days"]):
			S()["path"].pop_front()
	S()["rng_state"] = str(random.state)
