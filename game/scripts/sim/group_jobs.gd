class_name GroupJobs
extends RefCounted
## Multi-industry mega-jobs (#71). NPC clients post big orders in data/quests/*.json that need at least two of your
## industries. Each part has a share of the reward and a measurable target (a stat or save counter, counted from the
## day you accept). Finished parts pay their share into that industry's segment; at the deadline a partly done job pays
## the finished shares. A part you cannot or will not deliver yourself can be subcontracted for a fixed fee, so no job
## can soft-lock a player who runs only two of the three industries. State: GameState.data["synergy"]["jobs"].


static func S() -> Dictionary:
	var root: Dictionary = InternalSupply.S()
	if not root.has("jobs"):
		root["jobs"] = {"items": {}, "seq": 1, "last_offer": {}}
	return root["jobs"]


static func defs() -> Dictionary:
	return DataDB.quests


static func get_job(id: String) -> Dictionary:
	return S()["items"].get(id, {})


static func _def(job: Dictionary) -> Dictionary:
	return defs().get(str(job.get("def", "")), {})


static func error(text: String) -> Dictionary:
	return {"ok": false, "error": I18n.t(text)}


static func offered() -> Array:
	return S()["items"].values().filter(func(j): return j["status"] == "offered")


static func active() -> Array:
	return S()["items"].values().filter(func(j): return j["status"] == "active")


static func finished() -> Array:
	return S()["items"].values().filter(func(j): return j["status"] in ["completed", "partial", "failed"])


static func running_parts(def: Dictionary) -> int:
	var n := 0
	var seen := {}
	for part in def["parts"]:
		if not seen.has(part["industry"]) and InternalSupply.running(part["industry"]):
			n += 1
		seen[part["industry"]] = true
	return n


## Posts an offer for definition `def_id`. Returns the job id, or "" when it cannot be offered.
static func offer(def_id: String) -> String:
	var def: Dictionary = defs().get(def_id, {})
	if def.is_empty() or GameState.company_id() == "":
		return ""
	for job in S()["items"].values():
		if job["def"] == def_id and job["status"] in ["offered", "active"]:
			return ""
	var id := "GJ-%d" % int(S()["seq"])
	S()["seq"] = int(S()["seq"]) + 1
	S()["items"][id] = {"id": id, "def": def_id, "status": "offered", "offered": Clock.now(), "expires": Clock.now() + int(def["offer_days"]) * Clock.DAY,
		"deadline": 0, "base": {}, "sub": {}, "paid": 0.0, "fees": 0.0, "entity": GameState.business_entity()}
	S()["last_offer"][def_id] = Clock.now()
	GameState.add_message(str(def.get("npc", "")), I18n.t("A shared order is ready to review."), {"target":{"kind":"company", "tab":"group"}})

	EventBus.notify.emit(I18n.t("New group job: %s") % I18n.t(str(def["title"])), "info", "contracts")
	return id


static func accept(id: String) -> Dictionary:
	var job := get_job(id)
	if job.is_empty() or job["status"] != "offered" or Clock.now() > int(job["expires"]):
		return error("This group job is no longer on offer.")
	var def := _def(job)
	job["status"] = "active"
	job["deadline"] = Clock.now() + int(def["deadline_days"]) * Clock.DAY
	job["entity"] = GameState.business_entity()
	for part in def["parts"]:
		job["base"][part["id"]] = SynergyMetrics.value(str(part["metric"]))
	GameState.timeline(I18n.t("Accepted group job: %s") % I18n.t(str(def["title"])), "business")
	return {"ok": true}


static func part_state(job: Dictionary, part: Dictionary) -> Dictionary:
	var sub := bool(job["sub"].get(part["id"], false))
	var have := 0.0
	if job["status"] == "active" or job["status"] in ["completed", "partial", "failed"]:
		have = maxf(0.0, SynergyMetrics.value(str(part["metric"])) - float(job["base"].get(part["id"], 0.0))) if job["status"] == "active" else float(job.get("have", {}).get(part["id"], 0.0))
	var target := float(part["target"])
	var done := sub or have >= target
	return {"have": minf(have, target), "target": target, "done": done, "sub": sub}


static func all_done(job: Dictionary) -> bool:
	for part in _def(job)["parts"]:
		if not part_state(job, part)["done"]:
			return false
	return true


## Reward earned if the job closed right now.
static func earned(job: Dictionary) -> float:
	var total := 0.0
	for part in _def(job)["parts"]:
		if part_state(job, part)["done"]:
			total += float(part["share"])
	return snappedf(float(_def(job)["reward"]) * minf(1.0, total), 0.01)


static func subcontract(id: String, part_id: String) -> Dictionary:
	var job := get_job(id)
	if job.is_empty() or job["status"] != "active":
		return error("Accept the group job first.")
	var part := {}
	for p in _def(job)["parts"]:
		if p["id"] == part_id:
			part = p
	if part.is_empty() or part_state(job, part)["done"]:
		return error("Choose a part that is still open.")
	var fee := float(part["subcontract"])
	var ent := str(job["entity"])
	if Ledger.cash(ent) < fee:
		return error("Not enough cash for the subcontractor's fee.")
	Ledger.post(ent, I18n.t("Subcontractor for group job %s: %s") % [id, I18n.t(str(part["label"]))],
		[{"acct": "cogs", "dr": fee}, {"acct": "cash", "cr": fee}], {"type": "group_job_sub", "id": id, "segment": str(part["industry"])})
	job["sub"][part_id] = true
	job["fees"] = snappedf(float(job["fees"]) + fee, 0.01)
	if all_done(job):
		settle(id)
	return {"ok": true, "fee": fee}


## Closes an active job: pays finished parts into their industries' segments.
static func settle(id: String) -> Dictionary:
	var job := get_job(id)
	if job.is_empty() or job["status"] != "active":
		return error("This group job is not running.")
	var def := _def(job)
	job["have"] = {}
	var done_parts: Array = []
	for part in def["parts"]:
		var st := part_state(job, part)
		job["have"][part["id"]] = st["have"]
		if st["done"]:
			done_parts.append(part)
	var total := earned(job)
	var paid := 0.0
	for i in range(done_parts.size()):
		var part: Dictionary = done_parts[i]
		var amount := snappedf(float(def["reward"]) * float(part["share"]), 0.01)
		if i == done_parts.size() - 1:
			amount = snappedf(total - paid, 0.01)
		if amount > 0:
			Ledger.post(str(job["entity"]), I18n.t("Group job %s: %s") % [id, I18n.t(str(part["label"]))],
				[{"acct": "cash", "dr": amount}, {"acct": "revenue", "cr": amount}], {"type": "group_job", "id": id, "segment": str(part["industry"])})
			paid = snappedf(paid + amount, 0.01)
	job["paid"] = paid
	job["closed"] = Clock.now()
	job["status"] = "completed" if done_parts.size() == def["parts"].size() else ("partial" if not done_parts.is_empty() else "failed")
	GameState.inc_stat("group_jobs_" + str(job["status"]))
	GameState.timeline(I18n.t("Group job %s closed (%s): paid %s.") % [I18n.t(str(def["title"])), I18n.t(str(job["status"])), Fmt.money0(paid)], "milestone")
	EventBus.notify.emit(I18n.t("Group job %s: paid %s.") % [I18n.t(str(def["title"])), Fmt.money0(paid)], "good" if job["status"] == "completed" else "warn", "contracts")
	return {"ok": true, "paid": paid, "status": job["status"]}


## Closes every active job that is finished or past its deadline.
static func check_all() -> int:
	var n := 0
	for job in active():
		if all_done(job) or Clock.now() >= int(job["deadline"]):
			if settle(job["id"])["ok"]:
				n += 1
	return n


## What to do next on a job: the first open part's hint, translated.
static func next_step(job: Dictionary) -> String:
	if job["status"] == "offered":
		return I18n.t("Accept it to start the clock.")
	for part in _def(job).get("parts", []):
		if not part_state(job, part)["done"]:
			return I18n.t(str(part["hint"]))
	return I18n.t("Everything is done; the client pays on closing.")


static func on_hour(_t: int, h: int) -> void:
	if not GameState.has_game():
		return
	if h == 0:
		for job in offered():
			if Clock.now() > int(job["expires"]):
				job["status"] = "expired"
	check_all()
	if h == 9 and GameState.company_id() != "":
		_roll_offers()


static func _roll_offers() -> void:
	for def_id in defs():
		var def: Dictionary = defs()[def_id]
		if Clock.day_index() < int(def["earliest_day"]) or running_parts(def) < int(def["min_running"]):
			continue
		if Clock.now() - int(S()["last_offer"].get(def_id, -100000000)) < int(def["cooldown_days"]) * Clock.DAY:
			continue
		if GameState.rng.randf() < float(def["chance"]):
			offer(def_id)
			return
