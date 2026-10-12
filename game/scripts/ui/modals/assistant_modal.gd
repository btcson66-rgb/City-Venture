class_name AssistantModal
extends Modal
## A named teammate, hired by choice; financial and automation permissions live in AssistantPolicy.

var welcome := false
var more := false

func _init() -> void:
	title_text = "Maya · Your assistant" if AssistantPolicy.hired() else "Meet Maya"
	icon_name = "people"
	panel_size = Vector2(620 if InputAccess.touch_mode else 440, 300)
	pauses_time = true
	help_key = "assistant"

func build() -> void:
	var row := UIK.hbox(8)
	var portrait := PortraitView.new()
	portrait.name = "AssistantPortrait"
	portrait.custom_minimum_size = Vector2(64, 64)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var person := DataDB.npc("maya")
	var tints := {}
	for key in person.get("outfit_tints", {}):tints[key] = Color(person["outfit_tints"][key])
	portrait.setup_character(person["appearance"], person.get("outfit", "casual_tee"), tints, "maya")
	portrait.set_expr("happy" if welcome else "neutral")
	row.add_child(portrait)
	var intro := UIK.vbox(3)
	intro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var greeting := UIK.title("Maya joined your team!" if welcome else "Maya", 11, Art.C_SKY)
	greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_child(greeting)
	intro.add_child(UIK.wrap("You choose the next adventure. I'll handle the boxes.", 8, Art.C_WHITE, 0))
	row.add_child(intro)
	body.add_child(row)
	if welcome and not bool(Preferences.values.get("reduce_motion", false)):
		portrait.pivot_offset = Vector2(32, 32)
		var bounce := portrait.create_tween()
		bounce.tween_property(portrait, "scale", Vector2(1.06, 1.06), .15)
		bounce.tween_property(portrait, "scale", Vector2.ONE, .3).set_trans(Tween.TRANS_BACK)
	welcome = false
	var cfg := AssistantPolicy.cfg()
	if not AssistantPolicy.hired():
		body.add_child(UIK.wrap("Choose which chores I handle after we team up.", 8, Art.C_MUTED, 0))
		body.add_child(UIK.wrap(I18n.t("Join: %s · Weekly: %s · First week included") % [Fmt.money(float(cfg["hire_fee"])), Fmt.money(float(cfg["weekly_fee"]))], 8, Art.C_WHITE, 0))
		var hire := UIK.button(I18n.t("Hire Maya · %s") % Fmt.money(float(cfg["hire_fee"])), func():
			var result := AssistantPolicy.hire()
			if result["ok"]:welcome = true;rebuild()
			else:UIRoot.toast(I18n.t(str(result["error"])), "warn", "info"), "primary")
		hire.name = "AssistantHire"
		hire.disabled = not AssistantPolicy.eligible() or Ledger.cash("player") < float(cfg["hire_fee"])
		body.add_child(hire)
		if not AssistantPolicy.eligible():body.add_child(UIK.wrap("Ship your first parcel before hiring Maya.", 8, Art.C_MUTED, 0))
		elif hire.disabled:body.add_child(UIK.wrap(I18n.t("Keep %s in your personal account to hire Maya.") % Fmt.money(float(cfg["hire_fee"])), 8, Art.C_MUTED, 0))
		AssistantPolicy.bills_ui(body)
	else:
		body.add_child(UIK.wrap(I18n.t("Weekly: %s · Covered until %s") % [Fmt.money(float(cfg["weekly_fee"])), Clock.fmt_short(int(AssistantPolicy.S()["paid_until"]))], 8, Art.C_MUTED, 0))
		if AssistantPolicy.S().get("paused", false):
			body.add_child(UIK.wrap("Chores are paused. Manual controls still work; no unpaid fees build up.", 8, Art.C_MUTED, 0))
			var resume := UIK.button("Resume Maya's help", func():AssistantPolicy.renew_due(Clock.now());rebuild(), "primary")
			resume.name = "AssistantResume"
			resume.disabled = Ledger.cash("player") < float(cfg["weekly_fee"])
			body.add_child(resume)
		AssistantPolicy.master(body)
		var all := body.find_child("AssistantAll", true, false) as CheckBox
		all.text = I18n.t("All listed chores")
		for id in AssistantPolicy.TASKS:
			if AssistantPolicy.available(str(id)):
				AssistantPolicy.toggle(body, str(id))
				var choice := body.get_child(body.get_child_count() - 1) as CheckBox
				choice.tooltip_text = choice.text
				choice.text = I18n.t(str(AssistantPolicy.TASKS[id]))
		AssistantPolicy.bills_ui(body)
		var advanced := UIK.button("More ways to team up", func():more = not more;rebuild())
		advanced.name = "AssistantMore"
		body.add_child(advanced)
		if more:
			if int(AssistantPolicy.S().get("level", 1)) < 2:
				body.add_child(UIK.wrap("Unlock more chores as your businesses grow. This adds services, not performance bonuses.", 8, Art.C_MUTED, 0))
				var upgrade := UIK.button(I18n.t("More chores · %s") % Fmt.money(float(cfg["upgrade_fee"])), func():
					var result := AssistantPolicy.upgrade()
					if not result["ok"]:UIRoot.toast(I18n.t(str(result["error"])), "warn", "info")
					rebuild())
				upgrade.name = "AssistantUpgrade"
				upgrade.disabled = Ledger.cash("player") < float(cfg["upgrade_fee"])
				body.add_child(upgrade)
			else:body.add_child(UIK.label("Every chore is already unlocked.", 8, Art.C_MUTED))
			body.add_child(UIK.wrap(I18n.t("Preferences stay saved. Hiring again costs %s.") % Fmt.money(float(cfg["hire_fee"])), 8, Art.C_MUTED, 0))
			var dismiss := UIK.button("Dismiss Maya", func():AssistantPolicy.dismiss();more = false;rebuild())
			dismiss.name = "AssistantDismiss"
			body.add_child(dismiss)
	var done := UIK.button("Done", close)
	done.name = "AssistantDone"
	footer.add_child(done)
