class_name Industries
extends RefCounted
## Registry preserves the legacy hourly ordering. New modules register here instead of editing dispatch/UI.

static var _extra: Array = []

static func all() -> Array:
	return [{"id":"ecommerce", "sim_class":Ecommerce, "prefixes":["eco"], "slot":"sales"},
		{"id":"consulting", "sim_class":Careers, "prefixes":["car"], "slot":"careers"},
		{"id":"saas", "sim_class":Saas, "prefixes":["saas"], "slot":"business"},
		{"id":"cafe", "sim_class":Cafe, "prefixes":["cafe"], "slot":"business"},
		{"id":"logistics", "sim_class":Logistics, "prefixes":["log"], "slot":"business"},
		{"id":"manufacturing", "sim_class":Manufacturing, "prefixes":["mfg"], "slot":"business", "actions":{"manufacturing_open":Manufacturing.open_action}},
		{"id":"real_estate", "sim_class":RealEstate, "prefixes":["re"], "slot":"business", "actions":{"real_estate_open":RealEstate.open_action}},
		{"id":"media", "sim_class":Media, "prefixes":["media"], "slot":"business", "actions":{"media_open":Media.open_action}},
		{"id":"hotel", "sim_class":Hotel, "prefixes":["hotel"], "slot":"business", "actions":{"hotel_open":Hotel.open_action}},
		{"id":"energy", "sim_class":Energy, "prefixes":["energy"], "slot":"business", "actions":{"energy_open":Energy.open_action, "energy_subsidy":Energy.subsidy_action}},
		{"id":"automotive", "sim_class":Automotive, "prefixes":["auto"], "slot":"business", "actions":{"automotive_open":Automotive.open_action}},
		{"id":"international_trade", "sim_class":TradeIndustry, "prefixes":["trade"], "slot":"business", "actions":{"trade_open":TradeIndustry.open_action}}] + _extra

static func register(record: Dictionary) -> bool:
	if str(record.get("id", "")) == "" or record.get("sim_class") == null:
		return false
	for method in ["on_hour", "handle", "is_running", "on_company_closed", "os_tab", "board_detail", "segment_tag"]:
		if not record["sim_class"].has_method(method): return false
	for existing in all():
		if existing["id"] == record["id"]:
			return false
	_extra.append(record)
	return true

static func find(id: String) -> Dictionary:
	for entry in all():
		if entry["id"] == id:
			return entry
	return {}

static func dispatch(kind: String, payload: Dictionary) -> bool:
	var prefix := kind.get_slice(".", 0)
	for entry in all():
		if prefix in entry.get("prefixes", [entry["id"]]):
			entry["sim_class"].handle(kind, payload)
			return true
	return false

static func on_hour(t: int, h: int, slot: String) -> void:
	for entry in all():
		if entry.get("slot", "business") == slot:
			Sim.phase = "hour:" + str(entry["id"])
			entry["sim_class"].on_hour(t, h)

static func on_company_closed(entity: String) -> void:
	for entry in all():
		entry["sim_class"].on_company_closed(entity)
	Jobs.on_company_closed(entity)
	Assets.on_company_closed(entity)

static func tabs() -> Array:
	var result: Array = []
	# Keep the established tab order, irrespective of hourly routing order.
	var entries := all()
	entries.sort_custom(func(a,b): return int(a["sim_class"].os_tab().get("order", 100)) < int(b["sim_class"].os_tab().get("order", 100)))
	for entry in entries:
		if entry["sim_class"].is_running():
			result.append(entry["sim_class"].os_tab())
	return result

static func render_tab(tab: String, owner: Node) -> bool:
	for entry in all():
		var descriptor: Dictionary = entry["sim_class"].os_tab()
		if descriptor.get("id", "") == tab:
			if descriptor.has("render"):
				descriptor["render"].call(owner)
			else:
				owner.call(str(descriptor["method"]))
			return true
	return false

static func board_detail(id: String, details: Control, board: Node) -> bool:
	var entry := find(id)
	if entry.is_empty():
		return false
	entry["sim_class"].board_detail().call(details, board)
	return true

static func run_action(action: String, params: Dictionary, source: Node) -> bool:
	for entry in all():
		var actions: Dictionary = entry.get("actions", {})
		if actions.has(action):
			actions[action].call(params, source)
			return true
	return false

static func infer_segment(source: Dictionary, lines: Array) -> String:
	var kind := str(source.get("type", ""))
	if kind == "lease":
		var property: Dictionary = DataDB.properties.get(str(source.get("id", "")), {})
		if property.has("segment"): return str(property["segment"])
	if kind in ["cafe", "permit"]: return "cafe"
	if kind == "saas": return "saas"
	if kind.begins_with("gig_"): return "consulting"
	if kind in ["vehicle", "insurance", "logistics"]: return "logistics"
	if kind in ["contract", "order", "po", "sale", "refund", "ship", "listing", "return", "payout", "global_delivery", "global_payout", "global_conversion", "global_refund", "forward", "warehouse", "partners"]: return "ecommerce"
	for line in lines:
		if str(line["acct"]) == "exp:rent_shop": return "cafe"
		if str(line["acct"]) == "exp:rent_warehouse": return "ecommerce"
	return "shared"


static func launchers() -> Array:
	var result: Array = []
	for entry in all():
		var descriptor: Dictionary = entry["sim_class"].os_tab()
		if not entry["sim_class"].is_running() and descriptor.has("start_label"):
			result.append(descriptor)
	return result
