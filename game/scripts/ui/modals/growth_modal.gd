class_name GrowthModal
extends Modal
var page := "goals"

func _init(initial := "goals") -> void:
	page = initial
	title_text = "Growth and achievements"
	icon_name = "star"
	help_key = "growth"
	panel_size = Vector2(500, 340)
	pauses_time = true

func build() -> void:
	Growth.check(true)
	var tabs := UIK.hbox(4)
	for key in ["goals", "achievements", "timeline"]:
		var tab := UIK.button({"goals": "Growth goals", "achievements": "Achievements", "timeline": "The journey so far"}[key], func(): page = key; rebuild(), "tab_active" if page == key else "tab")
		tab.name = "GrowthTab_" + key
		tabs.add_child(tab)
	body.add_child(tabs)
	var box := UIK.vbox(5)
	body.add_child(UIK.scroll(box, Vector2(468, 220)))
	match page:
		"goals": goals(box)
		"achievements": achievements(box)
		"timeline": timeline(box)
	var back := UIK.button("Back to playing", close, "" if page == "goals" and not Growth.S()["pending"].is_empty() else "primary")
	back.name = "GrowthReturn"
	body.add_child(back)

func goals(box: VBoxContainer) -> void:
	if not Growth.enabled():
		box.add_child(UIK.wrap("Finish the main story to start optional growth goals. Achievements already track your progress.", 8, Art.C_MUTED, 452))
		return
	var pending: Array = Growth.S()["pending"]
	if not pending.is_empty():
		var d: Dictionary = Growth.definitions().filter(func(g): return g["id"] == pending[0])[0]
		box.add_child(UIK.label("✓ " + I18n.t(str(d["title"])), 10, Art.C_SKY, true))
		box.add_child(UIK.wrap("A real milestone, without a cash grant. Maya has sent you a message.", 8, Art.C_WHITE, 452))
		var card := UIK.button("Put the card in your timeline", func(): pending.pop_front(); rebuild(), "primary")
		card.name = "GrowthAcknowledge"
		box.add_child(card)
	box.add_child(UIK.label_tip("Three goals at a time", "growth_goals", 9, Art.C_SKY))
	for id in Growth.S()["active"]:
		var d: Dictionary = Growth.definitions().filter(func(g): return g["id"] == id)[0]
		box.add_child(UIK.label(I18n.t(str(d["title"])), 9, Art.C_SKY, true))
		box.add_child(UIK.wrap("✗ " + I18n.t(str(d["hint"])), 8, Art.C_WHITE, 452))
		if d["unit"] != "condition":
			var have := Growth.metric(d["metric"])
			var value := Fmt.money0(have) if d["unit"] == "home dollars" else (("%.1f" % have) if d["unit"] == "Rating" else str(int(have)))
			var target := Fmt.money0(d["value"]) if d["unit"] == "home dollars" else (("%.1f" % float(d["value"])) if d["unit"] == "Rating" else str(int(d["value"])))
			box.add_child(UIK.wrap(I18n.t("%s / %s %s") % [value, target, I18n.t(str(d["unit"]))], 7, Art.C_MUTED, 452))
		var skip := UIK.button("Set this goal aside", func(): Growth.review(id); rebuild())
		skip.name = "GrowthReview_" + id
		box.add_child(skip)
	if Growth.S()["active"].is_empty():
		box.add_child(UIK.wrap("No remaining goal suits this run. Keep playing, reopen goals you set aside, or start a company; completed goals stay recorded.", 8, Art.C_WHITE, 452))
	if not Growth.S()["reviewed"].is_empty():
		var restore := UIK.button("Reconsider goals set aside", func(): Growth.S()["reviewed"].clear(); Growth.check(); rebuild())
		restore.name = "GrowthRestore"
		box.add_child(restore)

func achievements(box: VBoxContainer) -> void:
	box.add_child(UIK.label_tip("Main-story achievements", "growth_goals", 9, Art.C_SKY))
	for d in Growth.definitions("achievements"):
		if Growth.S()["achievements"].has(d["id"]):
			box.add_child(UIK.wrap("✓ %s · %s" % [I18n.t(str(d["title"])), Clock.fmt_short(int(Growth.S()["achievements"][d["id"]]["t"]))], 8, Art.C_GREEN, 452))
		else:
			box.add_child(UIK.wrap("✗ " + I18n.t(str(d["hint"])), 8, Art.C_MUTED, 452))
	box.add_child(UIK.label("Industry milestones", 9, Art.C_SKY))
	for d in Milestones.list():
		box.add_child(UIK.wrap(("✓ " + I18n.t(str(d["name"]))) if Milestones.unlocked(d["id"]) else ("✗ " + I18n.t(str(d["desc"]))), 7, Art.C_MUTED, 452))

func timeline(box: VBoxContainer) -> void:
	var rows: Array = GameState.data["timeline"]
	for i in range(rows.size() - 1, -1, -1):
		box.add_child(UIK.label(Clock.fmt_short(int(rows[i]["t"])), 7, Art.C_SKY))
		box.add_child(UIK.wrap(str(rows[i]["text"]), 8, Art.C_WHITE, 452))
