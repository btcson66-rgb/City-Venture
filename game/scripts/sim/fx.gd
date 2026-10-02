class_name FX
extends RefCounted
## Quotes are home dollars per foreign unit. Foreign assets keep their historical book value until conversion.


static func cfg() -> Dictionary:
	return DataDB.economy.get("fx", {})


static func S() -> Dictionary:
	if not GameState.data.has("fx"):
		var rng := RandomNumberGenerator.new()
		rng.seed = int(GameState.data["rng"]["seed"]) + int(cfg().get("seed_offset", 30030))
		GameState.data["fx"] = {"rates": {}, "history": {}, "last_day": Clock.day_index(), "rng": str(rng.state), "shocks": []}
	var s: Dictionary = GameState.data["fx"]
	for ccy in cfg().get("currencies", {}):
		if not s["rates"].has(ccy):
			s["rates"][ccy] = float(cfg()["currencies"][ccy]["start_rate"])
			s["history"][ccy] = [{"day": int(s["last_day"]), "rate": s["rates"][ccy]}]
	return s


static func rate(ccy: String) -> float:
	if ccy == str(cfg().get("home_currency", "AUD")):
		return 1.0
	return float(S()["rates"].get(ccy, 0.0))


static func to_home(amount: float, ccy: String) -> float:
	if amount <= 0.0 or not is_finite(amount):
		return 0.0
	var spread := 0.0 if ccy == str(cfg().get("home_currency", "AUD")) else float(cfg().get("bank_spread", 0.015))
	return snappedf(amount * rate(ccy) * (1.0 - spread), 0.01)


static func history(ccy: String, days: int) -> Array:
	if days <= 0:
		return []
	return S()["history"].get(ccy, []).filter(func(p): return int(p["day"]) > Clock.day_index() - days).duplicate(true)


## Temporary shocks expire by day; later currency-crisis stories use this without permanent multipliers.
static func add_shock(ccy: String, volatility: float, days: int) -> bool:
	if rate(ccy) <= 0.0 or volatility <= 0.0 or not is_finite(volatility) or days <= 0:
		return false
	S()["shocks"].append({"ccy": ccy, "volatility": volatility, "until": Clock.day_index() + days})
	return true


static func on_day(day: int) -> void:
	var s := S()
	var rng := RandomNumberGenerator.new()
	rng.seed = int(GameState.data["rng"]["seed"]) + int(cfg().get("seed_offset", 30030))
	rng.state = int(s["rng"])
	var currencies: Array = s["rates"].keys()
	currencies.sort()
	while int(s["last_day"]) < day:
		var next := int(s["last_day"]) + 1
		s["shocks"] = s["shocks"].filter(func(x): return int(x["until"]) >= next)
		for ccy in currencies:
			var start := float(cfg()["currencies"][ccy]["start_rate"])
			var v := float(cfg().get("daily_volatility", 0.006))
			v *= float(cfg().get("era_volatility", {}).get(str(World.year()), 1.0))
			for shock in s["shocks"]:
				if shock["ccy"] == ccy:
					v *= float(shock["volatility"])
			var old := float(s["rates"][ccy])
			var pull := (start - old) * float(cfg().get("mean_reversion", 0.03))
			s["rates"][ccy] = snappedf(clampf(old + pull + old * rng.randf_range(-v, v),
				start * float(cfg().get("min_factor", 0.5)), start * float(cfg().get("max_factor", 2.0))), 0.000001)
			s["history"][ccy].append({"day": next, "rate": s["rates"][ccy]})
			while s["history"][ccy].size() > int(cfg().get("history_days", 365)):
				s["history"][ccy].pop_front()
		s["last_day"] = next
	s["rng"] = str(rng.state)
