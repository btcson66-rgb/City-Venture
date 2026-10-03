class_name Living
extends RefCounted
## Personal life costs (rent, living), leases, overdraft and solvency monitoring.
## Failure is never game over (Handoff §2.7): warnings + recovery options, overdraft with fees.


static func D() -> Dictionary:
	return GameState.data["living"]


static func cfg() -> Dictionary:
	return DataDB.living()


static func home() -> String:
	var id:=str(GameState.data["player"].get("home","riverside_studio"))
	return id if DataDB.properties.get(id,{}).get("kind","")=="home" else "riverside_studio"
static func home_building() -> String:return str(DataDB.properties[home()]["building"])
static func home_bed() -> String:return str(DataDB.properties[home()].get("bed","bed_side"))
static func home_rent() -> float:return 0.0 if DataDB.properties[home()].get("owner_purchase",false) else snappedf(float(DataDB.properties[home()]["monthly_rent"])*World.rent_mult(),.01)

static func daily_living() -> float:
	return float(cfg().get("reduced_daily_living", 18)) if D().get("reduced", false) else float(cfg().get("daily_living", 32))


static func on_hour(t: int, h: int) -> void:
	Housing.on_hour()
	PersonalAssets.on_hour()
	if h == 0:
		Ledger.expense("player", "living", daily_living(), "Food, transit & bills", {"type": "living"})
	if h == 9:
		var dom := int(Clock.date()["day"])
		if dom == int(cfg().get("rent_due_day_of_month", 14)):
			pay_home_rent()
		for pid in D()["leases"]:
			var ls: Dictionary = D()["leases"][pid]
			if int(ls.get("day", 0)) == dom and t - int(ls.get("since", 0)) > 20 * Clock.DAY:
				_charge_lease(pid, ls)
	if h == 23:
		for ent in _entities():
			if Ledger.cash(ent) < 0.0 and not (ent == "player" and Careers.has_perk("no_overdraft_fee")):
				Ledger.expense(ent, "bank_fees", float(cfg().get("overdraft_fee", 35)), "Overdraft fee", {"type": "fee"})
	if h >= 8 and h <= 22:
		check_solvency()


static func _entities() -> Array:
	return ["player"] + CompanyPortfolio.ids()



static func pay_home_rent() -> void:
	var rent := home_rent()   # rents rise with the era
	var before := Ledger.cash("player")
	var mname: String = Clock.month_name(int(Clock.date()["month"]))
	Ledger.expense("player", "rent_home", rent, I18n.t("Home rent — %s (%s)") % [I18n.t(DataDB.properties[home()]["name"]),mname], {"type": "rent"})
	D()["rent_history"].append({"t": Clock.now(), "amount": rent, "late": before < rent})
	if before < rent:
		Ledger.expense("player", "late_fees", float(cfg().get("late_rent_fee", 75)), "Late rent fee", {"type": "fee"})
		GameState.add_message("landlord", I18n.t("Rent bounced. I've added the $%d late fee. Please sort it out this week.") % int(cfg().get("late_rent_fee", 75)))
		EventBus.notify.emit("Rent paid into overdraft. Late fee charged.", "bad", "home")
	else:
		EventBus.notify.emit(I18n.t("Rent paid: %s") % Fmt.money0(rent), "info", "home")
	GameState.inc_stat("rent_paid")


## Which expense line a lease's rent goes to.
static func rent_category(kind: String) -> String:
	return {"office": "rent_office", "shop": "rent_shop", "warehouse": "rent_warehouse"}.get(kind, "coworking")


static func _charge_lease(pid: String, ls: Dictionary) -> void:
	var prop: Dictionary = DataDB.properties.get(pid, {})
	var cat := rent_category(str(prop.get("kind", "")))
	Ledger.expense(ls["entity"], cat, float(ls["rent"]), I18n.t("%s — monthly") % I18n.t(prop.get("name", pid)), {"type": "lease", "id": pid})


## Sign a lease. Office: deposit + first month. Co-work desk: first month.
static func lease(pid: String) -> Dictionary:
	if pid=="popup_cafe" and D()["leases"].has("popup_retail"):return {"ok":false,"error":"Pop-up Unit 5 already has a retail tenant. End that lease before opening a café."}
	var prop: Dictionary = DataDB.properties.get(pid, {})
	if prop.is_empty():
		return {"ok": false, "error": "Unknown property."}
	for r in prop.get("requires", []):
		if not Cond.eval(r):
			return {"ok": false, "error": str(prop.get("requires_text", "The landlord needs a registered company on the lease."))}
	if D()["leases"].has(pid):
		return {"ok": false, "error": "You already rent this."}
	var ent := GameState.business_entity()
	var rent := float(prop["monthly_rent"])
	var deposit := rent * float(prop.get("deposit_months", 0))
	if Ledger.cash(ent) < rent + deposit:
		return {"ok": false, "error": I18n.t("You need %s (first month%s).") % [Fmt.money0(rent + deposit), " + deposit" if deposit > 0 else ""]}
	var cat := rent_category(str(prop["kind"]))
	var lines := [{"acct": "exp:" + cat, "dr": rent}, {"acct": "cash", "cr": rent + deposit}]
	if deposit > 0:
		lines.append({"acct": "deposits", "dr": deposit})
	Ledger.post(ent, I18n.t("Lease signed: %s") % I18n.t(prop["name"]), lines, {"type": "lease", "id": pid})
	D()["leases"][pid] = {"rent": rent, "day": int(Clock.date()["day"]), "since": Clock.now(), "entity": ent}
	GameState.timeline(I18n.t("Leased %s for %s/month.") % [I18n.t(prop["name"]), Fmt.money0(rent)], "business")
	EventBus.world_refresh.emit()
	return {"ok": true}


static func has_lease(pid: String) -> bool:
	return D()["leases"].has(pid) and (D()["leases"][pid].get("entity","player")=="player" or D()["leases"][pid].get("entity","")==GameState.business_entity())


static func buy_day_pass() -> Dictionary:
	var prop: Dictionary = DataDB.properties.get("nexus_cowork_desk", {})
	var price := float(prop.get("day_pass", 15))
	Ledger.expense("player", "coworking", price, "Nexus Co-work day pass", {"type": "daypass"})
	D()["day_pass"] = Clock.day_index()
	return {"ok": true}


static func has_desk_access() -> bool:
	return has_lease("nexus_cowork_desk") or int(D().get("day_pass", -1)) == Clock.day_index() or Careers.has_perk("desk_access")


static func check_solvency() -> void:
	var th := float(cfg().get("low_cash_warning", 1500))
	for ent in _entities():
		var c := Ledger.cash(ent)
		var upcoming := 0.0
		if ent == "player":
			upcoming = home_rent() if int(Clock.date()["day"]) >= int(cfg().get("rent_due_day_of_month", 14)) - 5 and int(Clock.date()["day"]) < int(cfg().get("rent_due_day_of_month", 14)) else 0.0
		if c < th or c < upcoming:
			var key: String = "low_cash_" + ent
			if int(GameState.data["events"]["cooldowns"].get(key, 0)) > Clock.now():
				continue
			GameState.data["events"]["cooldowns"][key] = Clock.now() + 3 * Clock.DAY
			EventBus.solvency_warning.emit(ent)
			EventEngine.trigger("low_cash_warning", {"entity": ent, "entity_name": GameState.entity_name(ent) if ent != "player" else "Your personal account",
				"cash": Fmt.money0(c), "upcoming": Fmt.money0(upcoming)})


static func handle(_kind: String, _p: Dictionary) -> void:
	pass
