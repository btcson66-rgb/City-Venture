extends RefCounted
var runner

func test_read_and_unread_information_is_neutral_and_touchable() -> void:
	var id: String = str(DataDB.glossary.keys()[0])
	var tip := InfoTip.make(id)
	UIRoot.add_child(tip)
	await runner.get_tree().process_frame
	for read in [false, true]:
		GameState.data["tips_seen"] = {id: read}
		tip._restyle()
		runner.check(tip.get_theme_stylebox("panel") is StyleBoxEmpty, "information badge has no coloured fill")
		runner.check(tip._mark.get_theme_color("font_color") != Art.C_GOLD, "read and unread glyph is not gold")
		runner.check(tip.custom_minimum_size.x >= 24 and tip.custom_minimum_size.y >= 24, "small glyph keeps 24px input area")
		runner.eq(tip._mark.text, "i", "quiet information glyph")
	tip._pin()
	runner.check(InfoTip.seen(id), "click still marks glossary entry read")
	tip.queue_free()
	await runner.get_tree().process_frame
	runner.check(Ledger.check_balanced(), "reading never affects books")

func test_safety_hint_is_hidden_when_nothing_requires_action() -> void:
	var hud: HUD = UIRoot.hud
	hud._refresh_safety()
	runner.check(not hud.safety_button.visible, "healthy player has no safety badge")
