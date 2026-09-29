class_name Saas
extends RefCounted
## SaaS: a software product sold by subscription. Plays nothing like ecommerce: no stock, no parcels.
##  1. Pick an idea, then put development hours in (founder sessions at a laptop + developers on staff).
##  2. Launch at the MVP. Every day: signups (price elasticity × product quality × marketing × word of
##     mouth, capped by the market), churn (fewer features and no support = more churn), subscription
##     revenue booked daily through a card processor (3% fee), server costs that grow with users.
##  3. After launch, dev hours ship features (every 80 h): quality up, churn down.
## State: GameState.data["saas"]; money: revenue, exp:platform_fees, exp:servers, exp:advertising.


static func S() -> Dictionary:
	if not GameState.data.has("saas"):
		GameState.data["saas"] = {"active": false, "idea": "", "dev_done": 0.0, "launched": -1, "price": 0.0, "subs": 0,
			"features": 0, "feature_progress": 0.0, "ads_per_day": 0.0, "signups": 0, "churned": 0, "days": [], "entity": ""}
	return GameState.data["saas"]


static func cfg() -> Dictionary:
	return DataDB.economy.get("saas", {})


static func ideas() -> Array:
	return cfg().get("ideas", [])


static func idea() -> Dictionary:
	for i in ideas():
		if i["id"] == S()["idea"]:
			return i
	return {}


static func active() -> bool:
	return GameState.has_game() and bool(S().get("active", false))


static func launched() -> bool:
	return active() and int(S()["launched"]) >= 0


static func entity() -> String:
	return GameState.business_entity()


static func start(idea_id: String) -> Dictionary:
	if active():
		return {"ok": false, "error": "You're already building a product."}
	var ok := false
	for i in ideas():
		if i["id"] == idea_id:
			ok = true
	if not ok:
		return {"ok": false, "error": "Unknown idea."}
	var s := S()
	s["active"] = true
	s["idea"] = idea_id
	s["price"] = float(idea()["ref_price"])
	GameState.set_flag("business_saas")
	GameState.timeline(I18n.t("Started building %s, a SaaS product.") % str(idea()["name"]), "business")
	return {"ok": true}


static func dev_needed() -> float:
	return float(idea().get("dev_hours", 120))


## Put development hours in (founder at a laptop, or the dev team each workday).
## Add development hours. A founder session also passes time on the clock: `clock_hours` (the session length), or
## `hours` when not given; the typing minigame decides how many hours of work the session produced.
static func add_dev(hours: float, by_founder := false, clock_hours := -1.0) -> Dictionary:
	if not active():
		return {"ok": false, "error": "No product yet."}
	var s := S()
	if by_founder:
		Clock.advance(int(round((clock_hours if clock_hours >= 0.0 else hours) * 60)))
		GameState.inc_stat("saas_founder_hours", hours)
	if not launched():
		s["dev_done"] = minf(dev_needed(), float(s["dev_done"]) + hours)
		return {"ok": true, "mvp_ready": float(s["dev_done"]) >= dev_needed()}
	s["feature_progress"] = float(s["feature_progress"]) + hours
	var shipped := ""
	var fh := float(cfg().get("feature_hours", 80))
	while float(s["feature_progress"]) >= fh:
		s["feature_progress"] = float(s["feature_progress"]) - fh
		var names: Array = cfg().get("features", [])
		shipped = str(names[int(s["features"]) % names.size()]) if not names.is_empty() else "Update"
		s["features"] = int(s["features"]) + 1
		GameState.inc_stat("saas_features")
		GameState.timeline(I18n.t("%s shipped: %s.") % [str(idea()["name"]), I18n.t(shipped)], "business")
		EventBus.notify.emit(I18n.t("%s shipped a new feature: %s.") % [str(idea()["name"]), I18n.t(shipped)], "good", "laptop")
	return {"ok": true, "shipped": shipped}


static func launch() -> Dictionary:
	var s := S()
	if not active() or launched():
		return {"ok": false, "error": "Nothing to launch."}
	if float(s["dev_done"]) < dev_needed():
		return {"ok": false, "error": I18n.t("The MVP needs %d more dev hours.") % int(ceil(dev_needed() - float(s["dev_done"])))}
	s["launched"] = Clock.now()
	s["entity"] = entity()
	GameState.set_flag("saas_launched")
	GameState.timeline(I18n.t("Launched %s at %s/month.") % [str(idea()["name"]), Fmt.money0(float(s["price"]))], "milestone")
	return {"ok": true}


static func set_price(p: float) -> void:
	S()["price"] = clampf(snappedf(p, 1.0), 3.0, 199.0)


static func set_ads(per_day: float) -> void:
	S()["ads_per_day"] = clampf(per_day, 0.0, 500.0)


static func quality() -> float:
	return minf(1.6, 0.75 + 0.1 * int(S()["features"]))


static func monthly_churn() -> float:
	var c := float(idea().get("base_churn", 0.07)) * (1.25 - 0.07 * int(S()["features"]))
	if not Staff.support_agent().is_empty():
		c *= 0.75
	return clampf(c, 0.015, 0.25)


static func mrr() -> float:
	return int(S()["subs"]) * float(S()["price"])


## Expected signups per day at today's settings.
static func signup_rate() -> float:
	var i := idea()
	if i.is_empty():
		return 0.0
	var s := S()
	var pf := clampf(pow(float(i["ref_price"]) / maxf(1.0, float(s["price"])), float(i["elasticity"])), 0.05, 3.0)
	var b := float(s["ads_per_day"])
	var ads := 0.0 if b <= 0.0 else float(cfg().get("ad_max_boost", 1.0)) * b / (b + float(cfg().get("ad_half_budget", 20)))
	var wom := minf(1.0, int(s["subs"]) / 150.0)
	var room := clampf(1.0 - int(s["subs"]) / float(i.get("market", 1000)), 0.0, 1.0)
	return float(i["base_signups"]) * pf * quality() * (1.0 + ads + Staff.demand_boost()) * (1.0 + wom) * room


static func on_hour(_t: int, h: int) -> void:
	if not active():
		return
	if h == 17 and Clock.weekday() >= 1 and Clock.weekday() <= 5:
		var dh := Staff.dev_hours_per_day()
		if dh > 0.0:
			add_dev(dh)
	if h == 0 and launched():
		_day()


static func _day() -> void:
	var s := S()
	var ent := str(s.get("entity", entity()))
	if ent == "" or not GameState.data["entities"].has(ent):
		ent = entity()
		s["entity"] = ent
	var new := GameState.poisson(signup_rate())
	var lost := 0
	var p_churn := monthly_churn() / 30.0
	for i in int(s["subs"]):
		if GameState.randf() < p_churn:
			lost += 1
	s["subs"] = maxi(0, int(s["subs"]) + new - lost)
	s["signups"] = int(s["signups"]) + new
	s["churned"] = int(s["churned"]) + lost
	var gross := snappedf(int(s["subs"]) * float(s["price"]) / 30.0, 0.01)
	if gross > 0.0:
		var fee := snappedf(gross * float(cfg().get("processor_fee", 0.03)), 0.01)
		Ledger.post(ent, I18n.t("%s subscriptions — %d users") % [str(idea()["name"]), int(s["subs"])],
			[{"acct": "cash", "dr": gross - fee}, {"acct": "exp:platform_fees", "dr": fee}, {"acct": "revenue", "cr": gross}], {"type": "saas"})
	var servers := snappedf((float(cfg().get("server_base_month", 40)) + float(cfg().get("server_per_user_month", 0.35)) * int(s["subs"])) / 30.0, 0.01)
	Ledger.expense(ent, "servers", servers, I18n.t("%s servers") % str(idea()["name"]), {"type": "saas"})
	if float(s["ads_per_day"]) > 0.0:
		Ledger.expense(ent, "advertising", float(s["ads_per_day"]), I18n.t("%s ads") % str(idea()["name"]), {"type": "saas"})
	var days: Array = s["days"]
	days.append({"t": Clock.now(), "subs": int(s["subs"]), "new": new, "lost": lost})
	while days.size() > 60:
		days.pop_front()
	GameState.data["stats"]["saas_subs"] = float(s["subs"])
	GameState.data["stats"]["saas_mrr"] = mrr()


static func last_days(n: int, key: String) -> int:
	var t := 0
	var days: Array = S()["days"]
	for i in range(maxi(0, days.size() - n), days.size()):
		t += int(days[i][key])
	return t
