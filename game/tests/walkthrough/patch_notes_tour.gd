class_name PatchNotesTour
extends RefCounted
var bot
func _init(b) -> void: bot = b

func run() -> void:
	await Walkthrough.new(bot)._new_game()
	await bot.until(func(): return UIRoot.card_layer.find_child("ChapterCard", false, false) == null, 8.0)
	GameState.data["tutorial"]["off"] = true
	UIRoot._suppress_decisions = true
	bot.expect(bot.get_tree().root.find_child("PatchNotesModal", true, false) == null, "new game has no release notice")
	var text := FileAccess.get_file_as_string("res://tests/fixtures/saves/0.1.5-test5.cvsave")
	SaveSystem._atomic_write(SaveSystem._path(6), text)
	bot.expect(SaveSystem.load_and_enter(6), "genuine old save enters city")
	bot.expect(await bot.until(func(): return bot.get_tree().root.find_child("PatchNotesModal", true, false) != null, 5.0), "older game shows update card after entering")
	await bot.wait(0.5)
	await bot.shot("patch_notes_old_save")
	var card = bot.get_tree().root.find_child("PatchNotesModal", true, false)
	bot.expect(card.lines.any(func(line): return str(line).contains("0.1.6-test6")), "newer releases included")
	bot.expect(not card.lines.any(func(line): return str(line).contains("0.1.5-test5")), "seen release excluded")
	for version in DataDB.patch_notes:
		if PatchNotes.compare(str(version), str(ProjectSettings.get_setting("application/config/version"))) > 0:
			bot.expect(not card.lines.any(func(line): return str(line).contains(str(version))), "future release excluded")
	var scrolls: Array = card.find_children("*", "ScrollContainer", true, false)
	if not scrolls.is_empty():
		scrolls[0].scroll_vertical = 10000
		await bot.wait(0.4)
	await bot.shot("patch_notes_scrolled")
	await bot.click_named("Help", 2.0)
	await bot.wait(0.4)
	await bot.shot("patch_notes_help")
	UIRoot.top_modal().close()
	await bot.wait(0.3)
	await bot.click_named("ContinueUpdatedGame", 2.0)
	await bot.wait(0.3)
	bot.expect(GameState.data["meta"]["version"] == str(ProjectSettings.get_setting("application/config/version")), "read notice records current version")
	bot.expect(SaveSystem.load_and_enter(6), "acknowledged game reloads")
	await bot.wait(1.0)
	bot.expect(bot.get_tree().root.find_child("PatchNotesModal", true, false) == null, "acknowledged notice does not repeat")
	bot.expect(Ledger.check_balanced(), "release notice preserves ledger")
	await bot.shot("patch_notes_continued")
