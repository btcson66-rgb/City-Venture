extends RefCounted
## The "!" explanation badges: every glossary entry says what the idea is and why it matters, in both languages,
## and a badge turns quiet once the player has read it.

var runner


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
