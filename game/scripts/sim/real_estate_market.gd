class_name RealEstateMarket
extends RefCounted
## Market values are disclosed separately from historical book cost; they are never cash income.
static func S() -> Dictionary:
	var state := RealEstate.S()
	if not state.has("market"): state["market"] = {"index":1.0,"rate_shift":0.0,"month":-1,"last_rate":Bank.base_rate()}
	return state["market"]
static func rate() -> float: return Bank.base_rate()+float(S()["rate_shift"])
static func index() -> float: return float(S()["index"])
static func update() -> void:
	var month := Clock.day_index()/30
	if int(S()["month"]) == month: return
	S()["month"] = month
	var config := RealEstate.cfg()
	var walk := GameState.rng.randf_range(-float(config["market_walk"]), float(config["market_walk"]))
	var change := (rate()-float(S()["last_rate"]))*float(config["rate_impact"])
	S()["index"] = clampf(index()*(1+walk-change), float(config["market_min"]), float(config["market_max"]))
	S()["last_rate"] = rate()
static func value(property: Dictionary) -> float: return snappedf(float(property["base_price"])*index()*(1+float(property.get("uplift",0))),.01)
