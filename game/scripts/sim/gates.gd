class_name Gates
extends RefCounted
## What stands between the player and each industry (#71): capital, licence, location, and which industry to open first.
## Texts and the "suggested after" order live in data/synergies.json; the checks read the real game state.


static func entity() -> String:
	return GameState.business_entity()


static func capital(id: String) -> Dictionary:
	var need := float(DataDB.businesses.get(id, {}).get("starting_capital_min", 0))
	var have := Ledger.cash(entity())
	return {"ok": have >= need, "need": need, "have": have}


static func licence_ok(id: String) -> bool:
	match id:
		"cafe": return Cafe.permitted()
		"real_estate": return Compliance.permit_valid("brokerage")
		"automotive": return Automotive.is_running()
	return true


static func location_ok(id: String) -> bool:
	match id:
		"cafe": return Cafe.leased()
		"logistics": return Logistics.has_van()
		"manufacturing": return Living.has_lease("unit12_factory")
		"real_estate": return Living.has_lease("realty_office")
		"media": return Living.has_lease("loft_office")
		"hotel": return GameState.visited("the_aster") or Hotel.is_running()
		"energy": return Living.has_lease(str(Energy.cfg().get("warehouse", {}).get("property", "")))
	return true


## Rows for the Business Board: [{label, ok, text, next}].
static func rows(id: String) -> Array:
	var data: Dictionary = DataDB.synergies.get("gates", {}).get(id, {})
	var running := GameState.flag("business_chosen") if id == "ecommerce" else InternalSupply.running(id)
	var cap := capital(id)
	var out: Array = []
	out.append({"label": "Capital", "ok": running or bool(cap["ok"]),
		"text": I18n.t("%s needed, you have %s") % [Fmt.money0(float(cap["need"])), Fmt.money0(float(cap["have"]))],
		"next": I18n.t("Earn or borrow the difference first.")})
	out.append({"label": "Licence", "ok": running or licence_ok(id), "text": I18n.t(str(data.get("licence", "None."))),
		"next": I18n.t("Get the licence at City Hall.")})
	out.append({"label": "Location", "ok": running or location_ok(id), "text": I18n.t(str(data.get("location", ""))),
		"next": I18n.t("Visit or lease the location.")})
	return out


## Industries to open before this one, as [{id, name, ok}] (ok = already running).
static func suggested_after(id: String) -> Array:
	var out: Array = []
	for other in DataDB.synergies.get("gates", {}).get(id, {}).get("after", []):
		out.append({"id": other, "name": InternalSupply.industry_name(other), "ok": InternalSupply.running(other) and (other != "ecommerce" or GameState.flag("business_chosen"))})
	return out


## The first thing still blocking this industry ("" when every gate is open).
static func next_step(id: String) -> String:
	for row in rows(id):
		if not row["ok"]:
			return str(row["next"])
	return ""
