class_name FeatureGate
extends RefCounted
## Presentation-only gates: never restrict simulation, saved assets, cash or story conditions.
static var _config: Array = []
static func definitions() -> Array:
	if _config.is_empty():_config = JSON.parse_string(FileAccess.get_file_as_string("res://data/ui/feature_unlocks.json"))["features"]
	return _config
static func definition(id: String) -> Dictionary:
	for item in definitions():
		if item["id"] == id:return item
	return {}
static func chapter() -> int:
	var current: String = GameState.data.get("story", {}).get("chapter", "ch1_arrival")
	return maxi(1, int(current.get_slice("_",0).trim_prefix("ch")))
static func state() -> Dictionary:
	if not GameState.data.has("feature_gates"):
		# Older builds did not record individual tabs. Preserve historical access conservatively.
		var granted := []
		for item in definitions():
			if eligible(item) or (str(item["id"]).begins_with("os_") and GameState.flag("company_os_opened")) or (str(item["id"]).begins_with("app_") and GameState.flag("phone_opened")):
				granted.append(item["id"])
		GameState.data["feature_gates"] = {"granted":granted,"seen":granted.duplicate(),"guided":granted.duplicate()}
	return GameState.data["feature_gates"]
static func used(id: String) -> bool:
	var data := GameState.data
	match id:
		"inventory", "sales":return GameState.stat("purchase_orders") > 0 or not data.get("ecommerce", {}).get("listings", {}).is_empty()
		"contracts":return not data.get("contracts", {}).is_empty()
		"negotiation":return data.get("contracts", {}).values().any(func(c):return c.get("history", []).size()>1)
		"people", "recruitment":return not data.get("staff", {}).get("employees", {}).is_empty() or not data.get("staff", {}).get("applicants", []).is_empty() or not data.get("staff", {}).get("posting", {}).is_empty()
		"finance":return not data.get("reports", {}).get("month_closes", []).is_empty()
		"group":return CompanyPortfolio.ids().size()>1 or not data.get("group_jobs", {}).get("jobs", {}).is_empty()
		"segments":return Industries.tabs().size()>2
		"overseas":return data.get("global_market", {}).get("companies", {}).values().any(func(c):return not c.get("stores", {}).is_empty()) or data.get("ecommerce", {}).get("orders", {}).values().any(func(o):return o.has("region")) or data.get("contracts", {}).values().any(func(c):return c.has("region"))
		"logistics":return bool(data.get("logistics", {}).get("van", {}).get("owned", false))
		"freelance":return Careers.freelance_active()
		"international_trade":return bool(data.get("trade", {}).get("active", false))
		"app_shoplane", "app_timeline":return used("sales")
		"app_relationships":return data.get("npcs", {}).values().any(func(n):return n.get("met", false))
		"app_leases":return not data.get("living", {}).get("leases", {}).is_empty()
		"app_tax_filing":return not data.get("governance", {}).get("filings", {}).is_empty()
		"app_legacy":return GameState.flag("legacy_invited") or GameState.flag("consolidation_started")
		"app_world":return used("overseas") or used("international_trade")
	var industry := Industries.find(id)
	if not industry.is_empty():return industry["sim_class"].is_running()
	return bool(data.get(id, {}).get("active", false)) or bool(data.get(id, {}).get("open", false)) or GameState.flag("business_"+id)
static func eligible(item: Dictionary) -> bool:
	for condition in item.get("any", []):
		var text := str(condition)
		if text == "always":return true
		if text.begins_with("chapter:"):
			if chapter() >= int(text.trim_prefix("chapter:")):return true
		elif text.begins_with("used:"):
			if used(text.trim_prefix("used:")):return true
		elif Cond.eval(text):return true
	return false
static func unlocked(id: String) -> bool:
	if GameState.flag("debug_feature_gates_all"):return true
	return id in state()["granted"] or eligible(definition(id))
static func refresh(announce := true) -> void:
	if not GameState.has_game():return
	var st := state()
	for item in definitions():
		if item["id"] not in st["granted"] and eligible(item):
			st["granted"].append(item["id"])
			if announce and not str(item["id"]).begins_with("app_"):
				EventBus.notify.emit(I18n.t("New feature: %s") % I18n.t(str(item["label"])), "info", "info")
static func preview(ids: Array) -> String:
	for id in ids:
		if not unlocked(str(id)):return str(id)
	return ""
static func is_new(id: String) -> bool:return id not in state()["seen"] and unlocked(id)
static func viewed(id: String) -> void:
	refresh(false)
	if id not in state()["seen"]:state()["seen"].append(id)
static func guide(id: String) -> void:
	if GameState.flag("debug_feature_gates_all"):return
	if id in state()["guided"] or not unlocked(id):return
	if not definition(id).is_empty():UIRoot.open_modal(FeatureIntroModal.new(id))
