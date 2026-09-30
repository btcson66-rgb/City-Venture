class_name Careers
extends RefCounted
## Careers beyond the ecommerce story line, playable side by side with it:
##  • Part-time jobs (data/jobs): hired at a workplace or on the Business Board; each 4-hour shift is
##    worked on site during opening hours (one per day), pays an hourly wage into personal cash and
##    counts towards promotions. Every job carries one real perk for the rest of the game.
##  • Freelance consulting (data/economy/freelance.json): client gigs offered each morning; accept,
##    put hours in at any laptop, deliver before the deadline, invoice, get paid on terms. Reputation
##    (0–5 stars) moves your rate and unlocks bigger gigs. Late work costs money and stars.
## All state lives in GameState.data["careers"]; money moves through the ledger.


static func C() -> Dictionary:
	if not GameState.data.has("careers"):
		var fr := cfg()
		GameState.data["careers"] = {
			"job": "", "shifts": {}, "last_shift_day": -1, "rank": {},
			"freelance": {"active": false, "rep": float(fr.get("rep_start", 3.0)), "done": 0, "late": 0, "offers": [],
				"gigs": {}, "seq": 1, "offers_day": -1},
		}
	return GameState.data["careers"]


static func cfg() -> Dictionary:
	return DataDB.economy.get("freelance", {})


# ============================================================== part-time jobs
static func current_job() -> String:
	return str(C()["job"]) if GameState.has_game() else ""


static func job_def(id: String) -> Dictionary:
	return DataDB.jobs.get(id, {})


static func shifts(id: String) -> int:
	return int(C()["shifts"].get(id, 0))


static func rank_index(id: String) -> int:
	var ranks: Array = job_def(id).get("ranks", [])
	var r := 0
	for i in ranks.size():
		if shifts(id) >= int(ranks[i]["shifts"]):
			r = i
	return r


static func rank(id: String) -> Dictionary:
	var ranks: Array = job_def(id).get("ranks", [])
	return ranks[rank_index(id)] if not ranks.is_empty() else {}


static func next_rank(id: String) -> Dictionary:
	var ranks: Array = job_def(id).get("ranks", [])
	var i := rank_index(id) + 1
	return ranks[i] if i < ranks.size() else {}


static func wage(id: String) -> float:
	return float(rank(id).get("wage", 15))


static func shift_pay(id: String) -> float:
	return wage(id) * float(job_def(id).get("shift_hours", 4))


static func hire(id: String) -> Dictionary:
	var j := job_def(id)
	if j.is_empty():
		return {"ok": false, "error": "Unknown job."}
	var prev := current_job()
	if prev == id:
		return {"ok": false, "error": "You already work here."}
	C()["job"] = id
	GameState.set_flag("has_job")
	GameState.timeline(I18n.t("Hired as %s at %s.") % [I18n.t(str(rank(id)["title"])), I18n.t(str(j["employer"]))], "career")
	GameState.add_message(str(j["boss"]), I18n.t("Welcome aboard! Shifts are 4 hours, any time we're open. Come by the staff door when you're ready."))
	return {"ok": true, "left": prev}


static func quit() -> void:
	var id := current_job()
	if id == "":
		return
	C()["job"] = ""
	GameState.timeline(I18n.t("Left the job at %s.") % I18n.t(str(job_def(id)["employer"])), "career")


static func has_perk(perk_id: String) -> bool:
	if not GameState.has_game():
		return false
	var id := current_job()
	return id != "" and str(job_def(id).get("perk", {}).get("id", "")) == perk_id


static func perk_value(perk_id: String) -> float:
	return float(job_def(current_job()).get("perk", {}).get("value", 0.0)) if has_perk(perk_id) else 0.0


## Worked a shift today (so you're tired enough to sleep early).
static func worked_today() -> bool:
	return GameState.has_game() and int(C().get("last_shift_day", -1)) == Clock.day_index()


## A shift is the job's full length, or runs until closing time when you come in late (at least MIN_SHIFT_H).
const MIN_SHIFT_H := 2


static func shift_hours_now(id: String) -> int:
	var j := job_def(id)
	var full := int(j.get("shift_hours", 4))
	var h: Dictionary = DataDB.building(str(j["building"])).get("hours", {})
	var close_m := Clock.parse_hm(str(h.get("close", "24:00")))
	return clampi((close_m - Clock.minute_of_day()) / 60, 0, full)


## Why a shift can't be worked right now ("" = it can).
static func shift_block(id: String) -> String:
	if current_job() != id:
		return "not hired here"
	if int(C()["last_shift_day"]) == Clock.day_index():
		return "already worked today"
	var j := job_def(id)
	if not SceneRouter.building_open(str(j["building"]))["open"]:
		return "closed now"
	if shift_hours_now(id) < MIN_SHIFT_H:
		return "too late for a shift today"
	return ""


## A shift at or above this score counts toward promotion.
const COUNTS_FROM := 0.4


## Pay for a shift of `hours` (default: the full shift) played at `score` (0..1): 60% of the wage is guaranteed,
## the rest is earned.
static func pay_for(id: String, score: float, hours := -1) -> float:
	var base := shift_pay(id) if hours < 0 else wage(id) * hours
	return snappedf(base * (0.6 + 0.4 * clampf(score, 0.0, 1.0)), 0.01)


## Work one shift (played as a minigame, see MiniGames): time passes, pay follows the score, tips on top, and a
## shift that went well enough counts toward promotion.
static func work_shift(id: String, score := 1.0, tips := 0.0) -> Dictionary:
	var why := shift_block(id)
	if why != "":
		return {"ok": false, "error": why}
	var j := job_def(id)
	var before := rank_index(id)
	var hours := shift_hours_now(id)
	var pay := pay_for(id, score, hours) + snappedf(tips, 0.01)
	Clock.advance(hours * 60)
	Ledger.post("player", I18n.t("Wages — %s shift at %s") % [I18n.t(str(rank(id)["title"])), I18n.t(str(j["employer"]))],
		[{"acct": "cash", "dr": pay}, {"acct": "wages", "cr": pay}], {"type": "wages", "job": id})
	var counted := score >= COUNTS_FROM
	if counted:
		C()["shifts"][id] = shifts(id) + 1
	C()["last_shift_day"] = Clock.day_index()
	GameState.inc_stat("shifts_worked")
	var lines: Array = j.get("lines", [])
	var moment: String = I18n.t(str(lines[(shifts(id) - 1) % lines.size()])) if not lines.is_empty() else ""
	var promoted := rank_index(id) > before
	if promoted:
		GameState.timeline(I18n.t("Promoted to %s at %s.") % [I18n.t(str(rank(id)["title"])), I18n.t(str(j["employer"]))], "career")
		GameState.add_message(str(j["boss"]), I18n.t("You've earned it: you're our new %s. New rate: $%d an hour.") % [I18n.t(str(rank(id)["title"])), int(wage(id))])
	return {"ok": true, "pay": pay, "hours": hours, "moment": moment, "promoted": promoted, "title": str(rank(id)["title"]), "counted": counted}


# ============================================================== freelance consulting
static func F() -> Dictionary:
	return C()["freelance"]


static func freelance_active() -> bool:
	return GameState.has_game() and bool(F().get("active", false))


static func start_freelance() -> void:
	F()["active"] = true
	GameState.set_flag("business_consulting")
	GameState.timeline(I18n.t("Started freelancing as a consultant."), "business")
	refresh_offers(true)


static func rep() -> float:
	return float(F().get("rep", 3.0))


static func hourly_rate() -> float:
	return float(cfg().get("base_rate", 30)) + (rep() - 3.0) * float(cfg().get("rate_per_star", 7))


## New offers each morning (and once when freelancing starts).
static func refresh_offers(force := false) -> void:
	var f := F()
	if not force and int(f.get("offers_day", -1)) == Clock.day_index():
		return
	f["offers_day"] = Clock.day_index()
	var n := int(cfg().get("offers_base", 3)) + (1 if rep() >= 4.0 else 0) - (1 if rep() < 2.0 else 0)
	var pool: Array = []
	for t in cfg().get("templates", []):
		if rep() >= float(t.get("min_rep", 0.0)):
			pool.append(t)
	var clients: Array = cfg().get("clients", [])
	var offers: Array = []
	for i in n:
		if pool.is_empty() or clients.is_empty():
			break
		var t: Dictionary = GameState.pick(pool)
		var h: Array = t["hours"]
		var hours := GameState.randi_range(int(h[0]), int(h[1]))
		var fee := snappedf(hours * hourly_rate() * (0.9 + GameState.randf() * 0.25), 10.0)
		var terms: Array = cfg().get("terms_days", [0, 7, 14])
		var days := int(ceil(hours / 4.0)) + GameState.randi_range(1, 3)
		offers.append({"id": "G%d" % int(f["seq"]), "template": t["id"], "title": t["title"], "client": GameState.pick(clients),
			"hours": hours, "fee": fee, "terms": int(GameState.pick(terms)), "days": days})
		f["seq"] = int(f["seq"]) + 1
	f["offers"] = offers


static func active_gigs() -> Array:
	return F()["gigs"].values().filter(func(g): return g["status"] in ["active", "late"])


static func accept(offer_id: String) -> Dictionary:
	var f := F()
	if active_gigs().size() >= int(cfg().get("max_active", 3)):
		return {"ok": false, "error": "You already have as many gigs as you can handle."}
	for o in f["offers"]:
		if o["id"] == offer_id:
			var due := Clock.at_day_time(int(o["days"]), 18 * 60)
			var g: Dictionary = o.duplicate()
			g.merge({"done": 0, "status": "active", "due": due, "accepted": Clock.now(), "entity": GameState.business_entity()})
			f["gigs"][offer_id] = g
			f["offers"].erase(o)
			GameState.inc_stat("gigs_accepted")
			return {"ok": true, "gig": g}
	return {"ok": false, "error": "That offer is gone."}


static func session_hours() -> int:
	return int(cfg().get("session_hours", 2))


## Put one work session (2 h on the clock) into a gig at a laptop. `progress` is how much of it got done (the typing
## minigame's result, 0.5x-1.25x the session); -1 = the whole session.
static func work_on(gig_id: String, progress := -1.0) -> Dictionary:
	var g: Dictionary = F()["gigs"].get(gig_id, {})
	if g.is_empty() or not g["status"] in ["active", "late"]:
		return {"ok": false, "error": "No such gig in progress."}
	var left := float(g["hours"]) - float(g["done"])
	var clock_h := mini(session_hours(), int(ceil(left)))
	var h := minf(left, float(clock_h) if progress < 0.0 else progress)
	Clock.advance(clock_h * 60)
	g["done"] = float(g["done"]) + h
	GameState.inc_stat("gig_hours", h)
	if float(g["done"]) >= float(g["hours"]) - 0.01:
		return _deliver(g)
	return {"ok": true, "delivered": false, "hours": h}


static func _deliver(g: Dictionary) -> Dictionary:
	var f := F()
	var late := Clock.now() > int(g["due"])
	var fee := float(g["fee"]) * (1.0 - (float(cfg().get("late_penalty", 0.2)) if late else 0.0))
	fee = snappedf(fee, 0.01)
	var ent := str(g.get("entity", GameState.business_entity()))
	Ledger.post(ent, I18n.t("Invoice — %s") % gig_title(g), [{"acct": "accounts_receivable", "dr": fee}, {"acct": "revenue", "cr": fee}],
		{"type": "gig_invoice", "id": g["id"]})
	g["status"] = "invoiced"
	g["invoiced"] = fee
	g["delivered_at"] = Clock.now()
	var pay_t := Clock.now() + maxi(1, int(g["terms"]) * Clock.DAY)
	Sim.schedule(pay_t, "car.gig_paid", {"id": g["id"]})
	f["done"] = int(f["done"]) + 1
	if late:
		f["late"] = int(f["late"]) + 1
		f["rep"] = clampf(rep() - 0.5, 0.0, 5.0)
	else:
		f["rep"] = clampf(rep() + 0.25, 0.0, 5.0)
	GameState.inc_stat("gigs_delivered")
	GameState.add_message("client", I18n.t("%s: Received, thanks! Invoice for %s noted.") % [str(g["client"]), Fmt.money(fee)] if not late
		else I18n.t("%s: It's late, so we've knocked 20%% off. Invoice for %s noted.") % [str(g["client"]), Fmt.money(fee)])
	return {"ok": true, "delivered": true, "fee": fee, "late": late}


static func gig_title(g: Dictionary) -> String:
	return I18n.t(str(g["title"])) % str(g["client"])


static func handle(kind: String, p: Dictionary) -> void:
	match kind:
		"car.gig_paid":
			var g: Dictionary = F()["gigs"].get(str(p.get("id", "")), {})
			if g.is_empty() or g["status"] != "invoiced":
				return
			var amt := float(g["invoiced"])
			var ent := str(g.get("entity", "player"))
			Ledger.post(ent, I18n.t("Client payment — %s") % gig_title(g), [{"acct": "cash", "dr": amt}, {"acct": "accounts_receivable", "cr": amt}],
				{"type": "gig_payment", "id": g["id"]})
			g["status"] = "paid"
			EventBus.notify.emit(I18n.t("%s paid %s.") % [str(g["client"]), Fmt.money(amt)], "good", "cash")


static func on_hour(_t: int, h: int) -> void:
	if not freelance_active():
		return
	if h == int(cfg().get("offer_hour", 8)):
		refresh_offers()
	# deadlines: late after the due time, cancelled after N more days
	var cancel_days := int(cfg().get("cancel_after_days_late", 3))
	for g in active_gigs():
		if g["status"] == "active" and Clock.now() > int(g["due"]):
			g["status"] = "late"
			EventBus.notify.emit(I18n.t("Deadline missed: %s. Deliver soon, the fee drops.") % gig_title(g), "warn", "clock")
		elif g["status"] == "late" and Clock.now() > int(g["due"]) + cancel_days * Clock.DAY:
			g["status"] = "cancelled"
			F()["rep"] = clampf(rep() - 1.0, 0.0, 5.0)
			GameState.add_message("client", I18n.t("%s: We had to cancel the project. We won't be paying for it.") % str(g["client"]))
