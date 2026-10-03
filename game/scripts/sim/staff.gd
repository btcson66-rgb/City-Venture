class_name Staff
extends RefCounted
## Employees (P1 "People"). A registered company that is also a registered employer can post a job,
## pick from applicants, and pay a weekly payroll every Friday 17:00. Staff do real work during
## weekday hours: packers pack and book the courier at the office, support settles returns, marketers
## raise demand, developers add SaaS dev hours. Morale moves with pay, workload and raises; people
## quit when it bottoms out. A missed payroll becomes wages owed (a liability) and hurts morale.
## State: GameState.data["staff"]. Money: exp:payroll, exp:recruiting, wages_payable.


static func S() -> Dictionary:
	if not GameState.data.has("staff"):
		GameState.data["staff"] = {"people": {}, "applicants": [], "posting": {}, "seq": 1, "payrolls": 0, "missed": 0}
	return GameState.data["staff"]


static func cfg() -> Dictionary:
	return DataDB.economy.get("staff", {})


static func role_def(role: String) -> Dictionary:
	return cfg().get("roles", {}).get(role, {})


static func entity() -> String:
	return GameState.business_entity()


static func people() -> Array:
	return S()["people"].values() if GameState.has_game() else []


static func count(role := "") -> int:
	return people().filter(func(p): return role == "" or p["role"] == role).size()


static func weekly_payroll() -> float:
	var s := 0.0
	for p in people():
		s += float(p["salary_week"])
	return s


static func wages_owed() -> float:
	return -Ledger.balance(entity(), "wages_payable")


# ------------------------------------------------------------------ employer & hiring
static func employer_registered() -> bool:
	return GameState.flag("employer_registered")


static func register_employer() -> Dictionary:
	if GameState.company_id() == "":
		return {"ok": false, "error": "Register a company first."}
	if employer_registered():
		return {"ok": false, "error": "Already registered as an employer."}
	var fee := float(cfg().get("employer_registration_fee", 150))
	var ent := entity()
	if Ledger.cash(ent) < fee:
		return {"ok": false, "error": I18n.t("The employer registration fee is %s.") % Fmt.money0(fee)}
	Ledger.expense(ent, "registration", fee, I18n.t("Employer registration — %s") % GameState.business_display_name(), {"type": "registration"})
	GameState.set_flag("employer_registered")
	GameState.timeline(I18n.t("%s registered as an employer.") % GameState.business_display_name(), "business")
	return {"ok": true, "fee": fee}


## Why a job can't be posted right now ("" = it can).
static func hire_block(role := "") -> String:
	if GameState.company_id() == "":
		return "register a company first"
	if not GameState.flag("business_account_opened"):
		return "open a business bank account first"
	if not employer_registered():
		return "register as an employer at City Hall"
	if count() >= (int(Hotel.cfg().get("business", {}).get("max_staff", 12)) if Hotel.is_running() else int(cfg().get("max_staff", 6))):
		return "the team is full"
	if role != "" and bool(role_def(role).get("needs_office", false)) and not Living.has_lease("suite_2b"):
		return "needs an office (lease Suite 2B)"
	if role != "" and str(role_def(role).get("needs_lease", "")) != "" and not Living.has_lease(str(role_def(role)["needs_lease"])):
		return str(role_def(role).get("needs_text", "needs a workplace"))
	if role != "" and str(role_def(role).get("needs_flag", "")) != "" and not GameState.flag(str(role_def(role)["needs_flag"])):
		return str(role_def(role).get("needs_text", "needs a workplace"))   # e.g. drivers need the van
	return ""


static func post_job(role: String) -> Dictionary:
	var why := hire_block(role)
	if why != "":
		return {"ok": false, "error": why}
	if not S()["posting"].is_empty():
		return {"ok": false, "error": "You already have a job ad running."}
	var fee := float(cfg().get("job_ad_fee", 40))
	Ledger.expense(entity(), "recruiting", fee, I18n.t("Job ad — %s") % I18n.t(str(role_def(role)["name"])), {"type": "recruiting"})
	S()["posting"] = {"role": role, "t": Clock.now()}
	S()["applicants"] = []
	GameState.inc_stat("jobs_posted")
	Sim.schedule(Clock.now() + int(cfg().get("applicant_delay_hours", 18)) * 60, "stf.applicants", {"role": role})
	return {"ok": true, "fee": fee}


static func _make_person(role: String) -> Dictionary:
	var c := cfg()
	var sal: Array = role_def(role).get("salary_week", [500, 700])
	var skill := GameState.randi_range(1, 5)
	# better people ask for more: salary spreads across the role's band by skill, with some noise
	var t := (skill - 1) / 4.0
	var salary := snappedf(lerpf(float(sal[0]), float(sal[1]), clampf(t + (GameState.randf() - 0.5) * 0.3, 0.0, 1.0)), 5.0)
	var traits: Array = c.get("traits", [])
	var ap := GameState.default_appearance()
	var opts := DataDB.character
	for pair in [["presentation", "presentations"], ["face", "face_shapes"], ["hair", "hairstyles"], ["hair_color", "hair_colors"],
			["skin", "skin_tones"], ["eye_shape", "eye_shapes"], ["eye_color", "eye_colors"], ["brows", "eyebrows"], ["mouth", "mouths"]]:
		var arr: Array = opts.get(pair[1], [])
		if not arr.is_empty():
			ap[pair[0]] = str(GameState.pick(arr)["id"])
	ap["accessory"] = "glasses_round" if GameState.randf() < 0.25 else "none"
	var id := "E%d" % int(S()["seq"])
	S()["seq"] = int(S()["seq"]) + 1
	return {"id": id, "name": "%s %s" % [GameState.pick(c.get("first_names", ["Alex"])), GameState.pick(c.get("last_names", ["Lee"]))],
		"role": role, "skill": skill, "salary_week": salary, "trait": str(GameState.pick(traits)["id"]) if not traits.is_empty() else "",
		"appearance": ap, "outfit": "office_professional" if role in ["support", "developer"] else ("logistics_site" if role == "driver" else "startup_casual"),
		"morale": int(c.get("morale_start", 70))}


static func hire(applicant_id: String) -> Dictionary:
	var a := {}
	for x in S()["applicants"]:
		if x["id"] == applicant_id:
			a = x
	if a.is_empty():
		return {"ok": false, "error": "That applicant has moved on."}
	var why := hire_block(a["role"])
	if why != "":
		return {"ok": false, "error": why}
	var p: Dictionary = a.duplicate(true)
	p["hired"] = Clock.now()
	p["start"] = Clock.at_day_time(1, int(cfg().get("work_hours", [9, 17])[0]) * 60)
	p["weeks"] = 0
	p["last_raise"] = Clock.now()
	S()["people"][p["id"]] = p
	S()["applicants"] = []
	S()["posting"] = {}
	GameState.inc_stat("hires")
	GameState.timeline(I18n.t("Hired %s as %s.") % [p["name"], I18n.t(str(role_def(p["role"])["name"]))], "business")
	EventBus.world_refresh.emit()
	return {"ok": true, "person": p}


static func let_go(pid: String) -> Dictionary:
	var p: Dictionary = S()["people"].get(pid, {})
	if p.is_empty():
		return {"ok": false, "error": "No such employee."}
	var sev := float(p["salary_week"]) * float(cfg().get("severance_weeks", 1))
	Ledger.expense(entity(), "payroll", sev, I18n.t("Severance — %s") % p["name"], {"type": "payroll"})
	S()["people"].erase(pid)
	for o in people():
		o["morale"] = clampi(int(o["morale"]) - 5, 0, 100)
	GameState.timeline(I18n.t("Let %s go.") % p["name"], "business")
	EventBus.world_refresh.emit()
	return {"ok": true, "severance": sev}


static func give_raise(pid: String) -> Dictionary:
	var p: Dictionary = S()["people"].get(pid, {})
	if p.is_empty():
		return {"ok": false, "error": "No such employee."}
	p["salary_week"] = snappedf(float(p["salary_week"]) * 1.08, 5.0)
	p["morale"] = clampi(int(p["morale"]) + 18, 0, 100)
	p["last_raise"] = Clock.now()
	return {"ok": true, "salary_week": p["salary_week"]}


static func is_working(p: Dictionary, t := -1) -> bool:
	if t < 0:
		t = Clock.now()
	if t < int(p.get("start", 0)):
		return false
	var rd := role_def(str(p.get("role", "")))
	var wd := Clock.weekday(t)
	var h := int((t % Clock.DAY) / 60)
	var wh: Array = rd.get("work_hours", cfg().get("work_hours", [9, 17]))
	if h < int(wh[0]) or h >= int(wh[1]):
		return false
	for d in rd.get("work_days", [1, 2, 3, 4, 5]):
		if int(d) == wd:   # JSON numbers are floats: compare as ints
			return true
	return false


## Where someone in this role works: an office desk at Suite 2B unless the role says otherwise (baristas: the café).
static func workplace(role: String) -> String:
	return str(role_def(role).get("workplace", "suite_2b"))


static func output(p: Dictionary) -> float:
	return _output(p)


static func _output(p: Dictionary) -> float:
	return (0.6 + 0.2 * int(p["skill"])) * (1.3 if p.get("trait", "") == "fast" else 1.0) * (0.7 if int(p["morale"]) < 35 else 1.0)


# ------------------------------------------------------------------ effects on the business
## Extra demand from marketing staff (multiplies every listing's daily demand).
static func demand_boost() -> float:
	var b := 0.0
	for p in people():
		if p["role"] == "marketer" and Clock.now() >= int(p.get("start", 0)):
			b += 0.06 * _output(p)
	return minf(b, 0.45)


static func support_agent() -> Dictionary:
	for p in people():
		if p["role"] == "support" and Clock.now() >= int(p.get("start", 0)):
			return p
	return {}


## Dev hours per workday from developers (used by the SaaS module).
static func dev_hours_per_day() -> float:
	var h := 0.0
	for p in people():
		if p["role"] == "developer" and Clock.now() >= int(p.get("start", 0)):
			h += 6.0 * _output(p)
	return h


## Support settles a return so the player doesn't have to (replace if in stock, otherwise refund).
static func auto_resolve_return(order_id: String) -> bool:
	var agent := support_agent()
	if agent.is_empty():
		return false
	var o: Dictionary = Ecommerce.E()["orders"].get(order_id, {})
	if o.is_empty():
		return false
	var choice := "replace" if Ecommerce.best_location(o["product"]) != "" else "refund"
	var r := Ecommerce.resolve_return(order_id, choice)
	if not r["ok"]:
		r = Ecommerce.resolve_return(order_id, "refund")
	if r["ok"]:
		GameState.inc_stat("returns_by_staff")
		EventBus.notify.emit(I18n.t("%s (support) handled a return on %s: %s.") % [agent["name"], order_id,
			I18n.t("sent a replacement") if choice == "replace" else I18n.t("gave a refund")], "info", "people")
	return r["ok"]


# ------------------------------------------------------------------ clock
static func on_hour(t: int, h: int) -> void:
	if not GameState.data.has("staff") or S()["people"].is_empty():
		return
	var wd := Clock.weekday(t)
	if wd == int(cfg().get("payroll_weekday", 5)) and h == int(cfg().get("payroll_hour", 17)):
		run_payroll()
	var workers := people().filter(func(p): return is_working(p, t - 60))
	for p in workers:
		if p["role"] == "packer":
			_pack_hour(p, h)


static func _pack_hour(p: Dictionary, h: int) -> void:
	var loc := str(p.get("workplace", "suite_2b"))
	if not Living.has_lease(loc):
		return
	var cap := int(round(4.0 * _output(p)))
	var n := Ecommerce.pack_orders(loc, cap, {}, int(p["skill"]))
	if n > 0:
		GameState.inc_stat("orders_packed_by_staff", n)
	if h == 16 and not Ecommerce.orders_with(["packed"], loc).is_empty():
		var r := Ecommerce.courier_pickup(loc, "economy")
		if r.get("ok", false):
			EventBus.notify.emit(I18n.t("%s booked the courier: %d parcels (%s).") % [p["name"], int(r["count"]), Fmt.money0(r["cost"])], "info", "parcel")
	# a backlog the packer can't clear wears them down
	if Ecommerce.orders_with(["placed"], loc).size() > cap * 4:
		p["morale"] = clampi(int(p["morale"]) - 1, 0, 100)


## Friday payroll. Pays this week plus anything owed; if cash can't cover it, the week is accrued as
## wages owed and morale falls.
static func run_payroll() -> Dictionary:
	var ent := entity()
	var due := 0.0
	for p in people():
		if Clock.now() >= int(p.get("start", 0)):
			due += float(p["salary_week"])
	if due <= 0.0:
		return {"ok": true, "paid": 0.0}
	var owed := wages_owed()
	var total := due + owed
	var st := S()
	if Ledger.cash(ent) >= total:
		var lines := [{"acct": "exp:payroll", "dr": due}, {"acct": "cash", "cr": total}]
		if owed > 0.0:
			lines.append({"acct": "wages_payable", "dr": owed})
		Ledger.post(ent, I18n.t("Payroll — %d people") % count(), lines, {"type": "payroll"})
		st["payrolls"] = int(st["payrolls"]) + 1
		st["missed_run"] = 0
		GameState.inc_stat("payrolls_run")
		for p in people():
			p["weeks"] = int(p.get("weeks", 0)) + 1
			var up := 3 if owed <= 0.0 else 8
			if p.get("trait", "") == "ambitious" and Clock.now() - int(p.get("last_raise", 0)) > 60 * Clock.DAY:
				up = -6
			p["morale"] = clampi(int(p["morale"]) + up, 0, 90)
			if p.get("trait", "") == "friendly":
				for o in people():
					o["morale"] = clampi(int(o["morale"]) + 1, 0, 90)
		EventBus.notify.emit(I18n.t("Payroll paid: %s.") % Fmt.money0(total), "info", "cash")
		_check_quits()
		return {"ok": true, "paid": total}
	Ledger.post(ent, I18n.t("Payroll owed (not paid) — %d people") % count(), [{"acct": "exp:payroll", "dr": due}, {"acct": "wages_payable", "cr": due}],
		{"type": "payroll_missed"})
	st["missed"] = int(st["missed"]) + 1
	st["missed_run"] = int(st.get("missed_run", 0)) + 1
	GameState.inc_stat("payrolls_missed")
	for p in people():
		var hit := 35 if p.get("trait", "") != "reliable" else 18
		p["morale"] = clampi(int(p["morale"]) - hit, 0, 100)
	EventBus.notify.emit(I18n.t("Payroll bounced: not enough cash for %s. Your team is owed %s.") % [Fmt.money0(total), Fmt.money0(wages_owed())], "bad", "warning")
	_check_quits()
	Insolvency.check_payroll(ent)
	return {"ok": false, "owed": wages_owed()}


static func _check_quits() -> void:
	for p in people():
		if int(p["morale"]) < 25 and GameState.randf() < 0.5:
			_quit(p)


static func _quit(p: Dictionary) -> void:
	S()["people"].erase(p["id"])
	GameState.inc_stat("resignations")
	GameState.add_message("jobs_board", I18n.t("%s resigned from %s.") % [p["name"], GameState.business_display_name()])
	EventBus.notify.emit(I18n.t("%s quit.") % p["name"], "bad", "people")
	GameState.timeline(I18n.t("%s resigned.") % p["name"], "business")
	EventBus.world_refresh.emit()


static func handle(kind: String, p: Dictionary) -> void:
	match kind:
		"stf.applicants":
			var role := str(p.get("role", ""))
			if S()["posting"].get("role", "") != role:
				return
			var list: Array = []
			for i in int(cfg().get("applicants", 3)):
				list.append(_make_person(role))
			S()["applicants"] = list
			GameState.add_message("jobs_board", I18n.t("%d people applied for %s. Review them in Company OS → People.") % [list.size(), I18n.t(str(role_def(role)["name"]))])
			EventBus.world_refresh.emit()
