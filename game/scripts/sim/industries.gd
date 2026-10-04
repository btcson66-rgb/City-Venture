class_name Industries
extends RefCounted
## Registry preserves the legacy hourly ordering. New modules register here instead of editing dispatch/UI.

static var _extra: Array = []

static func all(include_services := false) -> Array:
	var entries: Array = [{"id":"ecommerce", "sim_class":Ecommerce, "prefixes":["eco"], "slot":"sales"},
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
		{"id":"governance", "sim_class":Governance, "prefixes":["gov"], "slot":"business", "service":true, "actions":{"tax_filing":Governance.open_action}},
		{"id":"personal_life", "sim_class":PersonalLife,"prefixes":["life"],"slot":"business","service":true}] + _extra
	return entries if include_services else entries.filter(func(e): return not e.get("service",false))

static func register(record: Dictionary) -> bool:
	if str(record.get("id", "")) == "" or record.get("sim_class") == null:
		return false
	for method in ["on_hour", "handle", "is_running", "on_company_closed", "os_tab", "board_detail", "segment_tag"]:
		if not record["sim_class"].has_method(method): return false
	for existing in all(true):
		if existing["id"] == record["id"]:
			return false
	_extra.append(record)
	return true

static func find(id: String) -> Dictionary:
	for entry in all(true):
		if entry["id"] == id:
			return entry
	return {}

static func dispatch(kind: String, payload: Dictionary) -> bool:
	var prefix := kind.get_slice(".", 0)
	for entry in all(true):
		if prefix in entry.get("prefixes", [entry["id"]]):
			entry["sim_class"].handle(kind, payload)
			return true
	return false

static func on_hour(t: int, h: int, slot: String) -> void:
	for entry in all(true):
		if entry.get("slot", "business") == slot:
			Sim.phase = "hour:" + str(entry["id"])
			entry["sim_class"].on_hour(t, h)

static func on_company_closed(entity: String) -> void:
	for entry in all(true):
		entry["sim_class"].on_company_closed(entity)
	Jobs.on_company_closed(entity)
	Assets.on_company_closed(entity)
	Rivals.on_company_closed(entity)

static func tabs() -> Array:
	var result: Array = []
	# Keep the established tab order, irrespective of hourly routing order.
	var entries := all(true)
	entries.sort_custom(func(a,b): return int(a["sim_class"].os_tab().get("order", 100)) < int(b["sim_class"].os_tab().get("order", 100)))
	for entry in entries:
		if entry["sim_class"].is_running():
			result.append(entry["sim_class"].os_tab())
	return result

static func render_tab(tab: String, owner: Node) -> bool:
	for entry in all(true):
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
	for entry in all(true):
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
	if kind in ["contract", "order", "po", "sale", "refund", "ship", "listing", "return", "payout"]: return "ecommerce"
	for line in lines:
		if str(line["acct"]) == "exp:rent_shop": return "cafe"
		if str(line["acct"]) == "exp:rent_warehouse": return "ecommerce"
	return "shared"


static func launchers() -> Array:
	var result: Array = []
	for entry in all(true):
		var descriptor: Dictionary = entry["sim_class"].os_tab()
		if not entry["sim_class"].is_running() and descriptor.has("start_label"):
			result.append(descriptor)
	return result


## Shared market overlay for registered industries; legacy saves remain neutral.
static func market_demand(id: String) -> float:
	return Macro.demand(id) * Rivals.demand(id) if not find(id).is_empty() else 1.0

static func prepare_journal(entity: String,lines: Array,source: Dictionary) -> Array:
	for entry in all(true):
		if entry["sim_class"].has_method("prepare_journal"):lines=entry["sim_class"].prepare_journal(entity,lines,source)
	return lines
static func on_ledger(journal: Dictionary) -> void:
	for entry in all(true):
		if entry["sim_class"].has_method("on_ledger"):entry["sim_class"].on_ledger(journal)
static func on_company_registered(entity: String) -> void:
	for entry in all(true):
		if entry["sim_class"].has_method("on_company_registered"):entry["sim_class"].on_company_registered(entity)
static func on_business_transferred(entity: String) -> void:
	for entry in all(true):
		if entry["sim_class"].has_method("on_business_transferred"):entry["sim_class"].on_business_transferred(entity)
