class_name Assets
extends RefCounted
## Owned/rented operating assets. Expensed legacy vans retain their original purchase and auction journals.

static func S() -> Dictionary:
	if not GameState.data.has("operating_assets"):
		GameState.data["operating_assets"] = {"items":{}, "seq":1}
	return GameState.data["operating_assets"]

static func cfg() -> Dictionary:
	return DataDB.economy.get("industries", {}).get("assets", {})

static func _valid_entity(entity: String) -> bool:
	return GameState.data["entities"].has(entity) and not GameState.data["entities"][entity].has("closed")

static func acquire(spec: Dictionary, rent := false) -> Dictionary:
	var entity := str(spec.get("entity", GameState.business_entity()))
	var price := float(spec.get("price", 0))
	var deposit := float(spec.get("deposit", 0)) if rent else 0.0
	var cost := price+deposit
	if not _valid_entity(entity) or price <= 0 or not is_finite(cost) or deposit < 0 or int(spec.get("life_days", 0)) <= 0 or (rent and int(spec.get("rent_days", 30)) <= 0) or Ledger.cash(entity) < cost:
		return {"ok":false, "error":I18n.t("Check asset cost, useful life and available cash.")}
	var id := "ASSET-%d" % int(S()["seq"])
	S()["seq"] = int(S()["seq"])+1
	var item := spec.duplicate(true)
	item.merge({"id":id, "entity":entity, "rented":rent, "bought":Clock.now(), "book":0.0 if rent else price,
		"price":price, "deposit":deposit, "status":"working", "segment":spec.get("segment", "shared"),
		"maintenance_day":Clock.day_index(), "depreciation_day":Clock.day_index(),
		"next_rent":Clock.now()+int(spec.get("rent_days", 30))*Clock.DAY}, true)
	S()["items"][id] = item
	var lines := [{"acct":"exp:asset_rent" if rent else "fixed_assets", "dr":price}, {"acct":"cash", "cr":cost}]
	if deposit > 0: lines.append({"acct":"deposits", "dr":deposit})
	Ledger.post(entity, I18n.t("Operating asset: %s") % id, lines, {"type":"asset", "id":id, "segment":item["segment"]})
	return {"ok":true, "id":id}

static func buy(spec: Dictionary) -> Dictionary: return acquire(spec, false)
static func rent(spec: Dictionary) -> Dictionary: return acquire(spec, true)

static func register_expensed_van() -> void:
	if not Logistics.has_van(): return
	var van: Dictionary = Logistics.S()["van"]
	var id := "legacy_van_"+str(van.get("entity", ""))
	if S()["items"].has(id) and S()["items"][id]["status"] != "sold": return
	S()["items"][id] = {"id":id, "entity":van["entity"], "segment":"logistics", "legacy_expensed":true,
		"rented":false, "price":float(Logistics.van_cfg().get("price", 9800)), "book":0.0, "status":"working", "bought":van["bought"]}

static func auction_expensed_van(entity: String) -> float:
	register_expensed_van()
	var id := "legacy_van_"+entity
	var item: Dictionary = S()["items"].get(id, {})
	if item.is_empty() or item["status"] == "sold": return 0.0
	var got := snappedf(float(item["price"])*clampf(float(Logistics.van_cfg().get("resale", 0.55)), 0.4, 0.6), 0.01)
	Ledger.post(entity, I18n.t("Van sold at auction"), [{"acct":"cash", "dr":got}, {"acct":"other_income", "cr":got}], {"type":"liquidation", "segment":"logistics"})
	item["status"] = "sold"
	return got

static func maintain(id: String) -> Dictionary:
	var item: Dictionary = S()["items"].get(id, {})
	var cost := float(item.get("maintenance_cost", cfg().get("maintenance_cost", 50)))
	if item.is_empty() or item["status"] == "sold" or not _valid_entity(item["entity"]) or cost < 0 or not is_finite(cost) or Ledger.cash(item["entity"]) < cost:
		return {"ok":false, "error":I18n.t("No serviceable asset or insufficient cash.")}
	Ledger.expense(item["entity"], "maintenance", cost, I18n.t("Asset maintenance: %s") % id, {"type":"asset", "segment":item["segment"]})
	item["status"] = "working"
	item["maintenance_day"] = Clock.day_index()
	item["maintenance_due"] = false
	return {"ok":true}

static func on_hour(t: int, h: int) -> void:
	register_expensed_van()
	if h != int(cfg().get("service_hour", 7)): return
	for item in S()["items"].values():
		if item.get("legacy_expensed", false) or item["status"] == "sold" or not _valid_entity(item["entity"]): continue
		var day := Clock.day_index()
		if day <= int(item["depreciation_day"]): continue
		var elapsed := day-int(item["depreciation_day"])
		item["depreciation_day"] = day
		if not item["rented"] and float(item["book"]) > 0:
			var dep := minf(float(item["book"]), snappedf(float(item["price"])/int(item["life_days"])*elapsed, 0.01))
			if day-Clock.day_index_at(int(item["bought"])) >= int(item["life_days"]): dep = float(item["book"])
			item["book"] = snappedf(float(item["book"])-dep, 0.01)
			if dep > 0: Ledger.post(item["entity"], I18n.t("Asset depreciation: %s") % item["id"], [{"acct":"exp:depreciation", "dr":dep}, {"acct":"fixed_assets", "cr":dep}], {"type":"asset", "segment":item["segment"]})
		if item["rented"] and t >= int(item["next_rent"]):
			Ledger.expense(item["entity"], "asset_rent", item["price"], I18n.t("Asset rent: %s") % item["id"], {"type":"asset", "segment":item["segment"]}, "cash" if Ledger.cash(item["entity"]) >= float(item["price"]) else "accounts_payable")
			item["next_rent"] = t+int(item.get("rent_days", 30))*Clock.DAY
		if day-int(item["maintenance_day"]) >= int(item.get("maintenance_days", cfg().get("maintenance_days", 30))):
			item["maintenance_due"] = true
			var chance := clampf(float(item.get("failure_chance", cfg().get("failure_chance", 0.02))), 0, 1)
			if chance > 0 and GameState.rng.randf() < chance: item["status"] = "broken"

static func on_company_closed(entity: String) -> void:
	for item in S()["items"].values():
		if item["entity"] != entity or item["status"] == "sold" or item.get("legacy_expensed", false): continue
		var lines: Array = []
		if item["rented"]:
			var deposit := float(item["deposit"])
			lines = [{"acct":"cash", "dr":deposit}, {"acct":"deposits", "cr":deposit}]
		else:
			var got := snappedf(float(item["price"])*clampf(float(item.get("resale", cfg().get("resale", 0.5))), 0.4, 0.6), 0.01)
			var book := float(item["book"])
			lines = [{"acct":"cash", "dr":got}, {"acct":"fixed_assets", "cr":book}]
			lines.append({"acct":"other_income", "cr":got-book} if got >= book else {"acct":"exp:other", "dr":book-got})
		Ledger.post(entity, I18n.t("Asset auction/lease return: %s") % item["id"], lines, {"type":"asset", "segment":item["segment"]})
		item["status"] = "sold"
		item["book"] = 0.0
