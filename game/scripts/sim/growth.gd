class_name Growth
extends RefCounted
## Optional goals and achievement receipts share existing ledger, milestone and timeline sources.

static func S() -> Dictionary:
	if not GameState.data.has("growth"):
		GameState.data["growth"] = {"completed": {}, "achievements": {}, "active": [], "company": "", "reviewed": {}, "pending": [], "cash_seq": 0, "cash_history": {}, "overdrawn": false}
	return GameState.data["growth"]

static func enabled() -> bool:
	return GameState.flag("legacy_cards_viewed") or (GameState.flag("story_complete") and not GameState.flag("legacy_invited"))

static func definitions(kind := "goals") -> Array:
	return DataDB.story.get(kind, [])

## Journal-derived metrics read each entry once (entries are append-only); a new or shorter journal restarts the scan.
static var _journal_ref: Array = []
static var _journal_index := 0
static var _earned := 0.0
static var _segments: Dictionary = {}

static func _scan_journal() -> void:
	var journal: Array = GameState.data["ledger"]["journal"]
	if not is_same(journal, _journal_ref) or journal.size() < _journal_index:
		_journal_ref = journal
		_journal_index = 0
		_earned = 0.0
		_segments = {}
	var entities: Dictionary = GameState.data["entities"]
	var counted := {}   # entity -> whether its revenue counts, resolved once per scan instead of once per entry
	while _journal_index < journal.size():
		var entry: Dictionary = journal[_journal_index]
		_journal_index += 1
		var company := str(entry["entity"])
		if not counted.has(company):
			counted[company] = company == "player" or entities.get(company, {}).get("kind", "") == "company"
		var counts: bool = counted[company]
		for line in entry["lines"]:
			if line["acct"] != "revenue": continue
			if counts: _earned += float(line.get("cr", 0)) - float(line.get("dr", 0))
			if float(line.get("cr", 0)) > 0:
				if not _segments.has(company): _segments[company] = {}
				_segments[company][entry.get("source", {}).get("segment", "")] = true

static func metric(source: String) -> float:
	var ent := GameState.company_id()
	match source:
		"earned_revenue":
			_scan_journal()
			return maxf(0, _earned)
		"registered": return 1.0 if GlobalMarket.live(ent) else 0.0
		"staff": return float(Staff.count()) if GlobalMarket.live(ent) else 0.0
		"industries":
			if not GlobalMarket.live(ent): return 0.0
			_scan_journal()
			var sources: Dictionary = _segments.get(ent, {})
			var count := 0
			for entry in Industries.all():
				if sources.has(entry["id"]) and entry["sim_class"].is_running(): count += 1
			return float(count)
		"cafe_rating": return float(Cafe.S()["rating"]) if Cafe.is_running() and GameState.stat("cafe_customers") > 0 else 0.0
		"foreign_stores":
			if not GlobalMarket.live(ent): return 0.0
			var count := 0
			for r in GlobalMarket.company()["stores"]:
				for l in Ecommerce.E()["listings"].values():
					if GlobalMarket.order_allowed(str(r), str(l["id"])):
						count += 1
						break
			return float(count)
		"foreign_deliveries":
			var delivered := 0
			for o in Ecommerce.foreign_orders():
				if o.has("delivered") and o.get("region", "home") != "home" and not o.get("status", "") in ["refunded", "refused"]: delivered += 1
			return float(delivered)
		"debt_free":
			var borrowed := false
			for loan in Bank.B()["loans"].values():
				if loan.get("entity", "") != ent: continue
				if loan.get("status", "") == "closed": borrowed = true
				elif float(loan.get("balance", 0)) > 0: return 0.0
			return 1.0 if borrowed else 0.0
		"annual_revenue":
			return float(MonthClose.compute(ent, maxi(0, Clock.now() - 365 * Clock.DAY), Clock.now() + 1)["net_revenue"]) if GlobalMarket.live(ent) else 0.0
		"profit_months": return float(profit_streak(ent))
		"negotiation":
			for c in GameState.data["contracts"].values():
				for h in c.get("history", []):
					if h.get("by", "") == c.get("buyer", "") and h.get("text", "") == "Deal. Send it over.": return 1.0
			return 0.0
		"never_overdrawn": return 0.0 if S()["overdrawn"] else float(Clock.now() / Clock.DAY)
	if source.begins_with("ending:"):
		return 1.0 if GameState.data.get("legacy_story", {}).get("ending", "") == source.substr(7) else 0.0
	if source.begins_with("flag:"): return 1.0 if GameState.flag(source.substr(5)) else 0.0
	return SynergyMetrics.value(source)

static func profit_streak(ent: String) -> int:
	var periods := {}
	for report in GameState.data["reports"]["month_closes"]:
		if report.get("entities", {}).has(ent): periods[report["period"]] = report
	var keys := periods.keys()
	keys.sort()
	var count := 0
	var previous := -1
	for period in keys:
		var serial := int(str(period).left(4)) * 12 + int(str(period).right(2))
		if previous >= 0 and serial != previous + 1: count = 0
		count = count + 1 if float(periods[period]["entities"][ent]["business_profit"]) > float(DataDB.economy.get("growth", {}).get("monthly_profit", 5000)) else 0
		previous = serial
	return count

static func observe_cash() -> void:
	var journal: Array = GameState.data["ledger"]["journal"]
	var state := S()
	var seen := int(state["cash_seq"])
	var start := 0
	for i in range(journal.size() - 1, -1, -1):
		if int(journal[i]["n"]) <= seen:
			start = i + 1
			break
	if start >= journal.size():
		return
	var entities: Dictionary = GameState.data["entities"]
	var history: Dictionary = state["cash_history"]
	var counted := {}
	for i in range(start, journal.size()):
		var entry: Dictionary = journal[i]
		var ent := str(entry["entity"])
		if not counted.has(ent):
			counted[ent] = ent == "player" or entities.get(ent, {}).get("kind", "") == "company"
		if counted[ent]:
			history[ent] = float(history.get(ent, 0)) + Ledger.entry_cash(entry)
			if float(history[ent]) < -0.01: state["overdrawn"] = true
		state["cash_seq"] = int(entry["n"])

static func met(d: Dictionary) -> bool:
	return metric(str(d["metric"])) >= float(d["value"])

static func record(d: Dictionary, kind: String, quiet := false) -> void:
	var id := str(d["id"])
	var receipts: Dictionary = S()["completed" if kind == "goals" else "achievements"]
	if receipts.has(id): return
	receipts[id] = {"t": Clock.now(), "entity": GameState.company_id()}
	GameState.timeline(I18n.t("Reached: %s") % I18n.t(str(d["title"])), "milestone")
	if kind == "goals":
		S()["pending"].append(id)
		GameState.add_message("maya", I18n.t("You reached %s. Choose the next goal that fits your business; the reward is the progress you actually made.") % I18n.t(str(d["title"])))
	if not quiet: EventBus.notify.emit(I18n.t("Reached: %s") % I18n.t(str(d["title"])), "good", "star")

static func check(quiet := false) -> void:
	if not GameState.has_game(): return
	observe_cash()
	for d in definitions("achievements"):
		if not S()["achievements"].has(d["id"]) and met(d): record(d, "achievements", quiet)
	if not enabled(): return
	var ent := GameState.company_id()
	if S()["company"] != ent:
		S()["company"] = ent
		S()["active"].clear()
		S()["reviewed"].clear()
	StoryEngine.St()["active"].erase("goal_growth")
	for d in definitions():
		if not S()["completed"].has(d["id"]) and met(d): record(d, "goals", quiet)
	var active: Array = []
	for d in definitions():
		if S()["completed"].has(d["id"]) or S()["reviewed"].has(d["id"]): continue
		if d.get("company", false) and not GlobalMarket.live(ent): continue
		if d["metric"] == "stat:founders_mentored" and GameState.data.get("legacy_story", {}).get("ending", "") != "mentor": continue
		active.append(d["id"])
		if active.size() >= 3: break
	S()["active"] = active

static func review(id: String) -> void:
	if id in S()["active"]:
		S()["reviewed"][id] = Clock.now()
		GameState.timeline("Set aside an optional growth goal. No completion was claimed.", "story")
		check()
