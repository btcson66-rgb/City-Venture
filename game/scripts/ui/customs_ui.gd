class_name CustomsUI
extends RefCounted


static func declaration(os: CompanyOS, box: VBoxContainer, region: String, listing: String) -> void:
	if not GameState.flag("customs_active") or not GlobalMarket.order_allowed(region, listing):
		return
	var p: Dictionary = Customs.prefs(GameState.company_id()).get(region + ":" + listing, {"policy": "ddu", "code": "general"})
	var row := UIK.hbox(4)
	box.add_child(row)
	for policy in ["ddp", "ddu"]:
		var b := UIK.button(policy.to_upper(), func():
			Customs.set_declaration(region, listing, policy, str(p["code"]))
			os.rebuild(), "tab_active" if p["policy"] == policy else "tab")
		b.name = "ExportPolicy_" + policy + "_" + listing
		row.add_child(b)
		row.add_child(UIK.tip(policy))
	box.add_child(UIK.wrap("DDP: you pay duty before shipping; fewer refusals. DDU: the buyer pays on arrival; refusals are more likely.", 7, Art.C_MUTED, 460))
	var codes := OptionButton.new()
	codes.name = "TariffCode_" + listing
	var keys: Array = Customs.cfg().get("codes", {}).keys()
	keys.sort()
	for i in keys.size():
		codes.add_item(I18n.t(str(Customs.cfg()["codes"][keys[i]]["name"])), i)
		if keys[i] == p["code"]:
			codes.select(i)
	codes.item_selected.connect(func(i):
		Customs.set_declaration(region, listing, str(p["policy"]), str(keys[i]))
		os.rebuild())
	box.add_child(codes)
	box.add_child(UIK.label_tip("Tariff code: choose what the product actually is; a low tax code does not change the goods.", "tariff_code", 7))
	box.add_child(UIK.label_tip("Duty is based on the region and the actual product category.", "duty", 7))


static func guide(os: CompanyOS, box: VBoxContainer) -> void:
	if not GameState.flag("customs_active"):
		return
	var b := UIK.button("Read Ines's customs guide", func():
		GameState.set_flag("customs_brief_read")
		StoryEngine.check()
		UIRoot.open_modal(Help.card("customs")))
	b.name = "ReadCustomsGuide"
	box.add_child(b)
	var results := Customs.trial_results(GameState.company_id())
	box.add_child(UIK.wrap(I18n.t("Trial: %d / %d delivered units; returns %.1f%%. Target: below 15%%.") % [results["count"], results["target"], float(results["return_rate"]) * 100], 7, Art.C_MUTED, 460))
	box.add_child(UIK.wrap("Deliveries count after a 3-day return observation period. Newly arrived parcels are still being checked.", 7, Art.C_MUTED, 460))
	if Customs.review_available() and not GameState.flag("customs_trial_passed"):
		var pause := UIK.button("Review results and pause expansion", func():
			Customs.pause_expansion()
			os.rebuild())
		pause.name = "PauseGlobalExpansion"
		box.add_child(pause)
		box.add_child(UIK.wrap("End this trial honestly without claiming the sales target. Stop new regional orders; existing parcels and foreign balances remain yours to settle.", 7, Art.C_MUTED, 460))
