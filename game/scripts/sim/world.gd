class_name World
extends RefCounted
## The city's economic era (data/world/years.json). Story chapters move the era forward (Chapter 7 → Year 3 Supply
## Shock, 8 → Year 4 Green Shift, 9 → Year 5 Clearing Crisis); the calendar itself keeps running day by day.
## Every macro number the simulation reads comes from here, so an era is data, not code.


static func year() -> int:
	return int(GameState.data.get("world", {}).get("year", 1)) if GameState.has_game() else 1


static func era() -> Dictionary:
	return DataDB.year_def(year())


static func _num(key: String, fallback: float) -> float:
	return float(era().get(key, fallback))


static func shipping_index() -> float:
	return _num("shipping_index", 1.0)


static func is_import(supplier_id: String) -> bool:
	return str(DataDB.supplier(supplier_id).get("region", "aurelia")) != "aurelia"


## Local suppliers feel the era a little, importers a lot. A supplier with `shock_exempt` (a local co-op making things
## in the city) is not affected at all.
static func cost_mult(supplier_id: String) -> float:
	if bool(DataDB.supplier(supplier_id).get("shock_exempt", false)):
		return 1.0
	return _num("import_cost_mult" if is_import(supplier_id) else "cost_mult", 1.0)


static func lead_mult(supplier_id: String) -> float:
	if bool(DataDB.supplier(supplier_id).get("shock_exempt", false)):
		return 1.0
	return _num("import_lead_mult" if is_import(supplier_id) else "lead_mult", 1.0)


static func rent_mult() -> float:
	return _num("rent_mult", 1.0)


## Per-parcel levy on plastic padding (Year 4 Clean Packaging Act); recycled packaging doesn't pay it.
static func packaging_levy() -> float:
	return _num("packaging_levy", 0.0)


static func eco_demand_mult() -> float:
	return _num("eco_demand_mult", 1.0)


## Year 5: paying a supplier abroad takes days to clear before anything ships.
static func cross_border_delay() -> bool:
	return bool(era().get("cross_border_delay", false))


## A supplier is on the market in this era (Verdant Supply opens in Year 4; Aurelia Makers once unlocked).
static func supplier_available(supplier_id: String) -> bool:
	var s := DataDB.supplier(supplier_id)
	if year() < int(s.get("from_year", 1)):
		return false
	var f := str(s.get("requires_flag", ""))
	return f == "" or GameState.flag(f)


## Move the city into a new era: the news, the timeline and a toast say so.
static func set_year(y: int) -> void:
	if y <= year():
		return
	GameState.data["world"]["year"] = y
	var d := DataDB.year_def(y)
	GameState.timeline(I18n.t("A new era in Aurelia: Year %d — %s.") % [y, I18n.t(str(d.get("name", "")))], "world")
	EventBus.notify.emit(I18n.t("Year %d — %s. Check the news board.") % [y, I18n.t(str(d.get("name", "")))], "info", "info")
