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
func test_first_use_hint_is_quiet_skippable_and_never_pauses() -> void:
	reset()
	Help.auto = false
	var screen := CompanyOS.new("home_laptop")
	UIRoot.open_modal(screen)
	await runner.get_tree().process_frame
	var cash := Ledger.cash("player")
	var paused := Clock.is_paused()
	var intro := FeatureIntroModal.show_in(screen, "os_operations")
	await runner.get_tree().process_frame
	runner.check(intro != null and is_instance_valid(intro), "hint appears inside the open screen")
	runner.check(UIRoot.top_modal() == screen, "hint is not a modal: bots still see the real screen")
	runner.eq(Clock.is_paused(), paused, "the hint never pauses the clock")
	runner.check("os_operations" in FeatureGate.state()["guided"], "shown once per feature")
	runner.check(screen.find_child("FeaturePracticeNext", true, false) != null and screen.find_child("FeaturePracticeSkip", true, false) != null, "stable names for next and skip")
	screen.find_child("FeaturePracticeNext", true, false).pressed.emit()
	await runner.get_tree().process_frame
	screen.find_child("FeaturePracticeSkip", true, false).pressed.emit()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	runner.check(screen.find_child("FeaturePracticeSkip", true, false) == null, "skip closes it")
	FeatureIntroModal.show_in(screen, "os_operations")
	await runner.get_tree().process_frame
	FeatureIntroModal.dismiss_all(runner.get_tree())
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	runner.check(screen.find_child("FeaturePracticeSkip", true, false) == null, "bots can dismiss it in one call")
	runner.eq(Ledger.cash("player"), cash, "no financial effect")
	UIRoot.close_all()
	runner.check(Ledger.check_balanced(), "balanced")
func test_unknown_ids_fail_open_and_every_os_id_is_configured() -> void:
	reset()
	runner.check(FeatureGate.unlocked("os_not_in_config") and FeatureGate.unlocked("app_new_thing"), "unknown ids fail open")
	runner.eq(FeatureGate.preview(["os_not_in_config"]), "", "an unknown id is never a teaser")
	var ids := {}
	for item in FeatureGate.definitions():ids[item["id"]] = true
	for tab in CompanyOS.TABS:runner.check(ids.has("os_" + str(tab[0])), "Company OS tab configured: " + str(tab[0]))
	for entry in Industries.all(true):
		var descriptor: Dictionary = entry["sim_class"].os_tab()
		if descriptor.is_empty():continue
		runner.check(ids.has("os_" + str(descriptor["id"])), "industry tab/launcher configured: " + str(descriptor["id"]))
	for descriptor in Industries.tabs() + Industries.launchers():runner.check(ids.has("os_" + str(descriptor["id"])), "live tab/launcher configured: " + str(descriptor["id"]))
	for app in ["messages","bank","tasks","map","shoplane","timeline","leases","relationships","tax_filing","news","guide","opportunities","save","close","legacy","world"]:
		runner.check(ids.has("app_" + app), "phone app configured: " + app)
func _chapter(n: int) -> void:
	GameState.data["story"]["chapter"] = str(StoryEngine.chapters()[n - 1]["id"])
func test_every_used_branch_with_real_game_state() -> void:
	reset()
	_chapter(1)
	var seen := {}
	for item in FeatureGate.definitions():
		for condition in item["any"]:
			if str(condition).begins_with("used:"):seen[str(condition).trim_prefix("used:")] = false
	for id in seen:runner.check(not FeatureGate.used(id), "unused on day one: " + id)
	Company.register("Gate Trading", "ecommerce", "22 Founders Lane")
	Company.open_business_account(20000)
	var entity := GameState.company_id()
	runner.check(not FeatureGate.used("app_tax_filing"), "no return yet: no tax app")
	runner.check(not FeatureGate.used("group") and not FeatureGate.used("segments") and not FeatureGate.used("finance"), "single quiet company")
	runner.check(Ecommerce.buy("tradelink_wholesale", "water_bottle", 60)["ok"], "real purchase")
	Clock.advance(3 * Clock.DAY)
	for id in ["inventory", "sales", "app_shoplane", "app_timeline"]:runner.check(FeatureGate.used(id), "real purchase order opens " + id)
	var offer := Contracts.create_offer({"buyer":"harbor_point_fitness","product":"water_bottle","qty":60,"unit_price":21.0,"payment_terms_days":30,"delivery_days":14})
	runner.check(FeatureGate.used("contracts") and not FeatureGate.used("negotiation"), "an offer is a contract, not yet a negotiation")
	runner.check(Contracts.accept(offer)["ok"], "real acceptance")
	runner.check(FeatureGate.used("negotiation"), "accepted offer has a history")
	runner.check(not FeatureGate.used("app_leases"), "no lease yet")
	runner.check(Staff.register_employer()["ok"], "real employer registration")
	var role := ""
	for candidate in Staff.cfg().get("roles", {}):
		if Staff.hire_block(str(candidate)) == "":
			role = str(candidate)
			break
	runner.check(role != "", "some role can be advertised")
	if role != "":
		runner.check(Staff.post_job(role)["ok"], "real job ad")
		for id in ["people", "recruitment"]:runner.check(FeatureGate.used(id), "a job ad opens " + id)
	runner.check(not FeatureGate.used("logistics") and not FeatureGate.used("freelance"), "not yet")
	Ledger.post(entity, "QA capital", [{"acct":"cash","dr":50000},{"acct":"equity","cr":50000}], {"type":"test_fixture"})
	var van := Logistics.buy_van()
	runner.check(bool(van.get("ok", false)) == FeatureGate.used("logistics"), "van purchase and gate agree")
	Careers.start_freelance()
	runner.check(FeatureGate.used("freelance"), "freelance started")
	Clock.advance(70 * Clock.DAY)
	MonthClose.run(int(Clock.date()["year"]), int(Clock.date()["month"]))
	runner.check(FeatureGate.used("finance"), "month close opens detailed accounts")
	runner.check(not Tax.returns(entity).is_empty() and FeatureGate.used("app_tax_filing"), "any real return shows the tax app")
	Ledger.post("player", "QA personal capital", [{"acct":"cash","dr":20000},{"acct":"equity","cr":20000}], {"type":"test_fixture"})
	runner.check(Company.register("Gate Second", "ecommerce", "Suite 2B").get("ok", false), "second company")
	runner.check(CompanyPortfolio.ids().size() > 1 and FeatureGate.used("group"), "second company opens group")
	runner.check(FeatureGate.used("segments") == (Industries.tabs().size() > 2), "segments follow real running industries")
	runner.check(not FeatureGate.used("app_relationships"), "nobody met")
	GameState.data["npcs"]["maya"] = {"met": true}
	runner.check(FeatureGate.used("app_relationships"), "met a contact")
	runner.check(Living.lease("nexus_cowork_desk").get("ok", false) == false or FeatureGate.used("app_leases"), "a real lease opens the leases app")
	runner.check(Living.lease("suite_2b").get("ok", false) == false or FeatureGate.used("app_leases"), "any real lease opens the leases app")
	runner.check(not FeatureGate.used("app_legacy") and not FeatureGate.used("app_world"), "late apps hidden")
	GameState.set_flag("legacy_invited")
	runner.check(FeatureGate.used("app_legacy"), "legacy invitation")
	runner.check(Ledger.check_balanced(), "gate inference never changes the books")
func test_group_job_branch() -> void:
	reset()
	Company.register("Group Gate", "ecommerce", "22 Founders Lane")
	Company.open_business_account(15000)
	runner.check(not FeatureGate.used("group"), "no group yet")
	var def_id := str(DataDB.quests.keys()[0])
	runner.check(GroupJobs.offer(def_id) != "", "a real group job is offered")
	runner.check(not GroupJobs.offered().is_empty() and FeatureGate.used("group"), "an offered group job opens the group tab")
	GameState.data["story"]["chapter"] = "ch1_arrival"
	runner.check(FeatureGate.unlocked("os_group"), "gate unlocks os_group for the offer")
func test_overseas_and_world_branches() -> void:
	reset()
	runner.check(not FeatureGate.used("overseas") and not FeatureGate.used("app_world"), "no overseas yet")
	var fixture = load("res://tests/unit/test_global.gd").new()
	fixture.runner = runner
	fixture._setup()
	runner.check(FeatureGate.used("overseas") and FeatureGate.used("app_world"), "an overseas store opens overseas and world")
	runner.check(Ledger.check_balanced(), "books balanced")
func test_trade_branch() -> void:
	reset()
	runner.check(not FeatureGate.used("international_trade"), "trade not started")
	var trade = load("res://tests/unit/test_trade_execution.gd").new()
	trade.runner = runner
	trade.setup()
	runner.check(FeatureGate.used("international_trade") and FeatureGate.used("app_world"), "running trade opens trade and world")
	runner.check(Ledger.check_balanced(), "books balanced")
func test_default_branch_uses_industry_running_or_business_flag() -> void:
	reset()
	runner.check(not FeatureGate.used("hotel") and not FeatureGate.used("governance"), "closed industries are unused")
	runner.check(not FeatureGate.used("market"), "no market use yet")
	GameState.set_flag("business_market")
	runner.check(FeatureGate.used("market"), "business flag counts as use")
	GameState.set_flag("business_market", false)
	GameState.data["market"] = {"active": true}
	runner.check(FeatureGate.used("market"), "an active data section counts as use")
func test_group_notification_go_never_lands_on_a_hidden_tab() -> void:
	reset()
	Help.auto = false
	_chapter(1)
	runner.check(not FeatureGate.unlocked("os_contracts") and not FeatureGate.unlocked("os_group"), "tabs hidden at chapter one")
	for target in [{"kind":"company","tab":"contracts","id":"X"},{"kind":"company","tab":"group"},{"kind":"company","tab":"governance"},{"kind":"company","tab":"operations"},{"kind":"company","tab":"finance"}]:
		var screen := PhoneMessages.destination({"target":target})
		runner.check(screen != null and FeatureGate.unlocked("os_" + str(target["tab"])), "Go unlocks " + str(target["tab"]))
		if screen != null:screen.free()
func test_teaser_is_nearest_unlock_not_config_order() -> void:
	reset()
	_chapter(1)
	runner.eq(FeatureGate.preview(["os_group", "os_segments", "os_contracts", "os_people"]), "os_people", "lowest chapter requirement wins")
	runner.eq(FeatureGate.preview(["os_group", "os_segments", "os_contracts"]), "os_contracts", "config order does not decide")
	_chapter(4)
	runner.eq(FeatureGate.preview(["os_group", "os_segments", "os_contracts"]), "os_segments", "unlocked entries are skipped")
	Help.auto = false
	UIRoot.open_modal(CompanyOS.new("home_laptop"))
	await runner.get_tree().process_frame
	runner.eq(UIRoot.top_modal().find_children("FeaturePreview", "Button", true, false).size(), 1, "one teaser in Company OS")
	UIRoot.close_all()
