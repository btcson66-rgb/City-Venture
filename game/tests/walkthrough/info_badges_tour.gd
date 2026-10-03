extends RefCounted
## Isolated screenshots of every existing screen changed by the glossary ticket.
var bot
func _init(b) -> void: bot = b

func _tips(n: Node) -> Array:
	var found: Array = []
	if n is InfoTip and n.is_visible_in_tree(): found.append(n)
	for child in n.get_children(): found.append_array(_tips(child))
	return found

func _screen(modal: Modal, label: String, opened := false) -> void:
	UIRoot.close_all()
	UIRoot.open_modal(modal)
	await bot.wait(0.4)
	await bot.shot("badges_" + label)
	# Every changed panel must remain within the viewport at both locale font sizes.
	var rect := modal.panel.get_global_rect()
	bot.expect(rect.position.x >= 0 and rect.position.y >= 0 and rect.end.x <= 641 and rect.end.y <= 361,
		"panel fits: " + label)
	if opened:
		var badges := _tips(modal)
		bot.expect(not badges.is_empty(), "badge available: " + label)
		if not badges.is_empty():
			await bot.click(badges[0])
			await bot.wait(0.3)
			await bot.shot("badges_" + label + "_card")
			if is_instance_valid(badges[0]._pinned): badges[0]._pinned.hide()
	await bot.key_action("ui_cancel")

func run() -> void:
	GameState.new_game({"name": "Badge Tour", "seed": 25})
	GameState.data["tutorial"] = {"off": true}
	UIRoot._suppress_decisions = true
	SceneRouter._enter("interior", "riverside_apartment", "door", "down")
	await bot.wait(0.6)
	Clock.push_pause("badge_tour")
	await _screen(PermitsModal.new(), "permits_new", true)
	await _screen(LoanModal.new(), "loan_prerequisites", true)
	await _screen(PackShipModal.new("riverside_studio"), "packing_empty")
	var imported := SaveSystem.import_text(FileAccess.get_file_as_string("res://tests/fixtures/saves/0.1.8-test8.1.cvsave"))
	bot.expect(imported["ok"], "genuine previous-version save imports for screenshots")
	bot.expect(SaveSystem.load_data(int(imported["slot"])), "previous-version state loads")
	# No fictional income or ledger entries: these are genuinely played historical books.
	for tab in ["overview", "finance", "sales", "operations", "inventory", "people", "contracts", "freelance", "saas"]:
		var screen := CompanyOS.new("home_laptop")
		screen.tab = tab
		await _screen(screen, "os_" + tab, tab in ["overview", "sales", "operations"])
	await _screen(BankModal.new(), "bank", true)
	await _screen(LoanModal.new(true), "loan_books")
	await _screen(PackShipModal.new("riverside_studio"), "packing_stock", true)
	var rep := {"label": Clock.fmt_date(), "period": "", "entities": {}}
	for entity in ["player", GameState.business_entity()]: rep["entities"][entity] = MonthClose.current(entity)
	await _screen(MonthCloseModal.new(rep), "month_close", true)
	var inst := EventEngine.trigger("escrow_offer", {})
	if not inst.is_empty(): await _screen(DecisionModal.new(inst), "decision", true)
	# Explicit future-era fixture only for the conditional permit view; no money is fabricated.
	GameState.data["world"]["year"] = 8
	await _screen(PermitsModal.new(), "permits_year8", true)
	UIRoot.close_all()
	Clock.pop_pause("badge_tour")
	bot.expect(Ledger.check_balanced(), "badge reading keeps historical books balanced")
