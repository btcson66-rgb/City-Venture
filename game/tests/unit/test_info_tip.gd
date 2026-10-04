extends RefCounted
## The "!" explanation badges: every glossary entry says what the idea is and why it matters, in both languages,
## and a badge turns quiet once the player has read it.

var runner


func test_next_action_and_purchase_gate_are_read_only() -> void:
	var screen := CompanyOS.new("home_laptop")
	var journal: int = GameState.data["ledger"]["journal"].size()
	runner.eq(screen._next_style(false), "", "blocked actions are secondary")
	runner.eq(screen._next_style(true), "primary", "first feasible action is primary")
	runner.eq(screen._next_style(true), "", "later actions are secondary")
	runner.check(not screen._buy_possible("tradelink_wholesale", "water_bottle", 1, "riverside_studio"), "below MOQ cannot buy")
	runner.check(not screen._buy_possible("missing", "water_bottle", 60, "riverside_studio"), "missing supplier cannot buy")
	runner.eq(GameState.data["ledger"]["journal"].size(), journal, "display checks never post money")
	screen.free()


func test_glossary_entries_are_complete() -> void:
	runner.check(DataDB.glossary.size() >= 15, "glossary loaded (%d entries)" % DataDB.glossary.size())
	for id in DataDB.glossary:
		var e: Dictionary = DataDB.glossary[id]
		for k in ["title", "what", "why"]:
			runner.check(str(e.get(k, "")) != "", "%s has %s" % [id, k])


func test_badge_remembers_being_read() -> void:
	runner.check(not InfoTip.seen("escrow"), "unread at the start")
	var t := UIK.tip("escrow")
	runner.eq(t.tip_id, "escrow", "badge made for escrow")
	var c := InfoTip.card("escrow")
	runner.check(c.get_child(0).get_child_count() == 3, "card shows title, what and why")
	InfoTip.mark_seen("escrow")
	runner.check(InfoTip.seen("escrow"), "read once, remembered")
	c.free()
	t.free()


func _scripts(path: String) -> Array:
	var result: Array = []
	var dir := DirAccess.open(path)
	for folder in dir.get_directories(): result.append_array(_scripts(path + "/" + folder))
	for file in dir.get_files():
		if file.ends_with(".gd"): result.append(path + "/" + file)
	return result


func test_literal_badge_references_and_event_choices_exist() -> void:
	var pattern := RegEx.create_from_string('UIK\\.tip\\(\\s*"([^"]+)"')
	for path in _scripts("res://scripts"):
		for found in pattern.search_all(FileAccess.get_file_as_string(path)):
			runner.check(DataDB.glossary.has(found.get_string(1)), path + ": " + found.get_string(1))
	for event in DataDB.events.values():
		for choice in event.get("choices", []):
			if choice.has("tip"): runner.check(DataDB.glossary.has(choice["tip"]), "event choice glossary exists")


func _badges(node: Node) -> Array:
	var result: Array = []
	if node is InfoTip: result.append(node.tip_id)
	for child in node.get_children(): result.append_array(_badges(child))
	return result


func test_empty_company_tabs_keep_their_explanations() -> void:
	var previous := Help.auto
	Help.auto = false
	var expected := {
		"overview": ["cash_vs_profit", "accounts_receivable"],
		"finance": ["cash_forecast", "gross_margin", "opex"],
		"sales": ["marketplace_fee", "payout_schedule", "ads_cpc", "price_elasticity", "product_photo"],
		"operations": ["moq", "lead_time", "supplier_terms", "packaging_levy", "shipping_index", "settlement_wire", "letter_of_credit", "digital_dollars"],
		"inventory": ["avg_cost", "defect_rate"],
		"people": ["payroll", "morale", "employer_registration"],
		"contracts": ["net_terms", "upfront", "late_penalty", "early_payment"],
		"freelance": ["net_terms", "accounts_receivable"],
		"saas": ["mrr", "churn", "server_costs"]}
	for tab in expected:
		UIRoot.close_all()
		var screen := CompanyOS.new("home_laptop")
		screen.tab = tab
		UIRoot.open_modal(screen)
		var ids := _badges(screen)
		for id in expected[tab]: runner.check(id in ids, tab + " explains " + id)
	UIRoot.close_all()
	Help.auto = previous


func test_permits_banking_and_empty_packing_have_badges() -> void:
	var previous := Help.auto
	Help.auto = false
	for pair in [[PermitsModal.new(), ["company_registration", "employer_registration", "import_licence", "food_licence"]],
		[BankModal.new(), ["overdraft", "credit_history"]], [LoanModal.new(), ["interest_rate", "credit_history"]],
		[PackShipModal.new("riverside_studio"), ["courier_tiers"]]]:
		UIRoot.close_all()
		UIRoot.open_modal(pair[0])
		for id in pair[1]: runner.check(id in _badges(pair[0]), "screen explains " + id)
		if pair[0] is PackShipModal:
			runner.check(pair[0].find_child("Pack", true, false).disabled, "empty packing cannot be the next action")
	UIRoot.close_all()
	Help.auto = previous


func test_english_historical_ledger_displays_in_traditional_chinese() -> void:
	I18n.init()
	var locale := I18n.locale()
	I18n.set_locale("zh_TW", false)
	var han := RegEx.create_from_string("[\\x{3400}-\\x{9fff}]")
	for filename in ["0.1.5-test5", "0.1.6-test6", "0.1.7-test7", "0.1.8-test8.1"]:
		var source := FileAccess.get_file_as_string("res://tests/fixtures/saves/" + filename + ".cvsave")
		var saved: Dictionary = JSON.parse_string(source)["data"]
		for entry in saved["ledger"]["journal"]:
			var memo := str(entry["memo"])
			var shown := SavedText.display(memo)
			runner.check(han.search(shown) != null, filename + " localized memo: " + memo)
			runner.eq(entry["memo"], memo, "display never rewrites historical books")
	runner.eq(SavedText.display("Metro fare to Civic Center"), I18n.t("Metro fare to %s") % I18n.t("Civic Center"), "known template substitutes translated destination")
	I18n.set_locale("en", false)
	runner.eq(SavedText.display("Capital injected into Riverlight Goods"), "Capital injected into Riverlight Goods", "English source remains intact")
	I18n.set_locale(locale, false)
