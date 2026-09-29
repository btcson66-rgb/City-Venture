class_name SleepModal
extends Modal


func _init() -> void:
	title_text = "Bed"
	icon_name = "sleep"
	help_key = "sleep"
	panel_size = Vector2(330, 150)


func build() -> void:
	var h := Clock.hour()
	var evening := h >= 19 or h < 5
	if evening:
		body.add_child(UIK.wrap("Call it a day? You'll wake up at 7:00 AM. The game autosaves.", 9, Art.C_WHITE, 310))
		var b := UIK.button("Sleep until 7:00 AM", _sleep, "primary")
		b.name = "Sleep"
		body.add_child(b)
	else:
		# no naps: the day is for living it (work a shift, run the business); the bed is for the night
		body.add_child(UIK.wrap(I18n.t("It's %s. You're not tired yet: the bed is for the night, from 7:00 PM. Waiting for something? Work a shift or tidy up the business meanwhile.") % Clock.fmt_time(), 9, Art.C_WHITE, 310))
	footer.add_child(UIK.button("Not now", close))


func _sleep() -> void:
	visible = false
	await UIRoot.fade_out(0.5)
	var target := Clock.next_time_of_day(7 * 60)
	if target - Clock.now() > 20 * 60:
		target = Clock.at_day_time(1, 7 * 60) if Clock.hour() >= 7 else Clock.at_day_time(0, 7 * 60)
	Clock.advance_to(target)
	GameState.inc_stat("nights_slept")
	SaveSystem.autosave()
	await UIRoot.fade_in(0.6)
	UIRoot.toast(I18n.t("Good morning. %s.") % Clock.fmt_date(), "info", "sun")
	close()
