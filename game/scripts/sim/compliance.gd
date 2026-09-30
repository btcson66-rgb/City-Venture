class_name Compliance
extends RefCounted
## Year 8, the Regulation Wave (Chapter 12): compliance is an operating cost, not a one-off.
##  · KYC checks: a cross-border payment above a threshold costs a fee and a day's delay before it lands.
##  · Import licence: City Hall's permits kiosk, an annual fee. Without a valid one, imports are blocked.
##  · Monthly compliance cost: filings, checks and the person who keeps them in order (expense category `compliance`).
## Numbers: data/economy/compliance.json. The era switch is `compliance` in data/world/years.json (World.compliance()).
## State: GameState.data["compliance"].


static func S() -> Dictionary:
	if not GameState.data.has("compliance"):
		GameState.data["compliance"] = {"licence_until": 0, "licence_ready": -1}
	return GameState.data["compliance"]


static func cfg() -> Dictionary:
	return DataDB.economy.get("compliance", {})


static func active() -> bool:
	return GameState.has_game() and World.compliance()


# ================================================================ KYC on large payments
## The check a payment of `total` must clear: {fee, hours}, or {} when it is small enough (or before Year 8).
static func kyc(total: float) -> Dictionary:
	if not active():
		return {}
	var k: Dictionary = cfg().get("kyc", {})
	if total < float(k.get("threshold", 2500.0)):
		return {}
	return {"fee": snappedf(maxf(float(k.get("fee_min", 40.0)), total * float(k.get("fee_rate", 0.003))), 0.01), "hours": int(k.get("hours", 24))}


static func kyc_threshold() -> float:
	return float(cfg().get("kyc", {}).get("threshold", 2500.0))


# ================================================================ import licence
static func licence_fee() -> float:
	return float(cfg().get("import_licence", {}).get("fee", 450.0))


static func licence_until() -> int:
	return int(S().get("licence_until", 0))


static func licence_valid() -> bool:
	return licence_until() > Clock.now()


static func licence_pending() -> bool:
	return int(S().get("licence_ready", -1)) > Clock.now()


static func licence_days_left() -> int:
	return maxi(0, int(ceil(float(licence_until() - Clock.now()) / float(Clock.DAY))))


static func renew_window() -> int:
	return int(cfg().get("import_licence", {}).get("renew_window_days", 60))


## Why the licence can't be applied for (or renewed) right now ("" = it can).
static func licence_block() -> String:
	if not active():
		return "Import licences arrive with the Regulation Wave."
	if GameState.company_id() == "":
		return "Only registered companies can hold an import licence."
	if licence_pending():
		return "Being processed."
	if licence_valid() and licence_days_left() > renew_window():
		return "Already licensed."
	if Ledger.cash(GameState.business_entity()) < licence_fee():
		return I18n.t("The licence fee is %s.") % Fmt.money0(licence_fee())
	return ""


## Apply for the licence (two days at City Hall) or renew it in its last weeks (instant, another year).
static func apply_licence() -> Dictionary:
	var why := licence_block()
	if why != "":
		return {"ok": false, "error": why}
	var c: Dictionary = cfg().get("import_licence", {})
	var ent := GameState.business_entity()
	Ledger.expense(ent, "registration", licence_fee(), "Import licence — City of Aurelia", {"type": "permit"})
	if licence_valid():
		var until := licence_until() + int(c.get("days", 365)) * Clock.DAY
		_set_until(until)
		GameState.timeline(I18n.t("Renewed the import licence until %s.") % Clock.fmt_date(until), "business")
		return {"ok": true, "fee": licence_fee(), "renewed": true, "until": until}
	S()["licence_ready"] = Clock.now() + int(c.get("processing_hours", 48)) * 60
	Sim.schedule(int(S()["licence_ready"]), "cmp.licence", {})
	return {"ok": true, "fee": licence_fee(), "ready": int(S()["licence_ready"])}


static func _set_until(until: int) -> void:
	S()["licence_until"] = until
	GameState.set_flag("import_licence")
	if until - renew_window() * Clock.DAY > Clock.now():
		Sim.schedule(until - renew_window() * Clock.DAY, "cmp.remind", {"until": until})
	Sim.schedule(until, "cmp.expire", {"until": until})


## Buying from an importer needs the licence in Year 8 ("" = fine).
static func import_block(supplier_id: String) -> String:
	if not active() or not World.is_import(supplier_id) or licence_valid():
		return ""
	if licence_pending():
		return "Your import licence is still being processed."
	return "Importing needs an import licence now. Apply at the City Hall permits kiosk."


# ================================================================ monthly cost
static func monthly_cost() -> float:
	var m: Dictionary = cfg().get("monthly", {})
	return snappedf(float(m.get("base", 60.0)) + float(m.get("per_employee", 8.0)) * Staff.count(), 0.01)


## On the 1st at 09:00 a registered company in Year 8 or later pays its compliance bill.
static func on_hour(_t: int, h: int) -> void:
	if h != 9 or not active() or GameState.company_id() == "" or int(Clock.date()["day"]) != 1:
		return
	var ent := GameState.business_entity()
	Ledger.expense(ent, "compliance", monthly_cost(), I18n.t("Compliance: filings, checks and the compliance officer — %s") % Clock.month_name(int(Clock.date()["month"])), {"type": "compliance"})
	GameState.inc_stat("compliance_charges")


static func handle(kind: String, p: Dictionary) -> void:
	match kind:
		"cmp.licence":
			var ready := int(S().get("licence_ready", -1))
			if ready < 0 or ready > Clock.now():
				return
			S()["licence_ready"] = -1
			_set_until(Clock.now() + int(cfg().get("import_licence", {}).get("days", 365)) * Clock.DAY)
			GameState.add_message("ana", "Your import licence is through. It's valid for a year: renew it in the last two months, or your imports stop.")
			GameState.timeline(I18n.t("Got an import licence (valid until %s).") % Clock.fmt_date(licence_until()), "milestone")
			EventBus.notify.emit(I18n.t("Import licence granted."), "good", "civic")
		"cmp.remind":
			if int(p.get("until", 0)) == licence_until():
				GameState.add_message("ana", "Your import licence runs out in about two months. Renew it at the permits kiosk before it lapses.")
		"cmp.expire":
			if int(p.get("until", 0)) == licence_until():
				GameState.set_flag("import_licence", false)
				GameState.add_message("ana", "Your import licence has expired. No imports until it's renewed at the permits kiosk.")
		_:
			push_warning("Compliance: unknown " + kind)
