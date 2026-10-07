extends RefCounted
var runner
func reset() -> void:
	GameState.set_flag("debug_feature_gates_all", false)
	GameState.data["feature_gates"] = {"granted":[],"seen":[],"guided":[]}
func test_every_gate_definition_and_chapter_condition() -> void:
	reset()
	for item in FeatureGate.definitions():
		runner.check(not item["label"].is_empty() and not item["any"].is_empty(), "gate has label and conditions: "+item["id"])
		for condition in item["any"]:
			if str(condition).begins_with("chapter:"):
				var threshold := int(str(condition).trim_prefix("chapter:"))
				GameState.data["story"]["chapter"] = str(StoryEngine.chapters()[threshold-1]["id"])
				runner.check(FeatureGate.eligible(item), "chapter unlock: "+item["id"])
	GameState.data["story"]["chapter"] = "ch1_arrival"
	runner.check(not FeatureGate.unlocked("overseas") and not FeatureGate.unlocked("os_group"), "late features hidden on day one")
	GameState.inc_stat("purchase_orders")
	runner.check(FeatureGate.unlocked("os_sales") and FeatureGate.unlocked("os_inventory"), "first stock unlocks selling and stock detail")
func test_preview_new_marker_and_monotonic_grant() -> void:
	reset()
	var ids: Array = ["os_overview","os_sales","os_group","overseas"]
	runner.eq(FeatureGate.preview(ids), "os_sales", "one earliest locked preview")
	GameState.set_flag("business_chosen")
	FeatureGate.refresh(false)
	runner.check(FeatureGate.is_new("os_sales"), "unlock has new marker")
	FeatureGate.viewed("os_sales")
	runner.check(not FeatureGate.is_new("os_sales"), "view clears marker")
	GameState.set_flag("business_chosen", false)
	runner.check(FeatureGate.unlocked("os_sales"), "already used feature never vanishes")
func test_legacy_progress_assets_and_access_preserved() -> void:
	reset()
	GameState.data.erase("feature_gates")
	GameState.set_flag("company_os_opened")
	GameState.set_flag("phone_opened")
	runner.check(FeatureGate.unlocked("os_group") and FeatureGate.unlocked("app_leases"), "unrecorded historical screen access preserved conservatively")
	runner.check(not FeatureGate.is_new("os_group"), "old access does not spam unlock toast")
	GameState.data.erase("feature_gates")
	GameState.set_flag("company_os_opened", false)
	GameState.set_flag("phone_opened", false)
	GameState.data["logistics"] = {"van":{"owned":true}}
	runner.check(FeatureGate.unlocked("os_logistics"), "existing first van preserves logistics")
	runner.check(Ledger.check_balanced(), "gate inference cannot create revenue")
func test_unlock_announces_once_and_only_real_progress() -> void:
	reset()
	FeatureGate.refresh(false)
	var notices := []
	var listener := func(text, _kind, _icon):notices.append(text)
	EventBus.notify.connect(listener)
	GameState.data["story"]["chapter"] = "ch13_first_order_abroad"
	FeatureGate.refresh()
	var count: int = notices.size()
	FeatureGate.refresh()
	runner.check(count > 0 and FeatureGate.unlocked("overseas"), "progress unlocks and announces new feature")
	runner.eq(notices.size(), count, "unlock announces once")
	EventBus.notify.disconnect(listener)
func test_locked_nodes_absent_and_one_preview() -> void:
	reset()
	Help.auto = false
	UIRoot.open_modal(CompanyOS.new("home_laptop"))
	await runner.get_tree().process_frame
	var screen := UIRoot.top_modal()
	for id in ["overview","finance","operations"]:runner.check(screen.find_child("Tab_"+id,true,false)!=null, "day-one tab "+id)
	for id in ["sales","people","contracts","group","market","segments"]:runner.check(screen.find_child("Tab_"+id,true,false)==null, "locked node absent: "+id)
	runner.eq(screen.find_children("FeaturePreview","Button",true,false).size(), 1, "one disabled preview")
	runner.check(screen.find_child("FeaturePreview",true,false).disabled, "preview cannot be clicked")
	UIRoot.close_all()
func test_practice_skip_replay_and_cash_unchanged() -> void:
	reset()
	var cash := Ledger.cash("player")
	var guide := FeatureIntroModal.new("os_operations")
	UIRoot.open_modal(guide)
	await runner.get_tree().process_frame
	guide.find_child("FeaturePracticeNext",true,false).pressed.emit()
	runner.eq(guide.step, 1, "two-step untimed practice")
	guide.find_child("FeaturePracticeNext",true,false).pressed.emit()
	runner.check("os_operations" in FeatureGate.state()["guided"], "completed practice receipt")
	runner.eq(Ledger.cash("player"), cash, "practice has no financial effects")
	UIRoot.open_modal(FeatureIntroModal.new("os_operations"))
	await runner.get_tree().process_frame
	UIRoot.top_modal().find_child("FeaturePracticeSkip",true,false).pressed.emit()
	runner.check(Ledger.check_balanced(), "skip and replay balanced")
