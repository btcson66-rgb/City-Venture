class_name PauseMenu
extends Modal


func _init() -> void:
	title_text = "Paused"
	icon_name = "settings"
	panel_size = Vector2(330, 318)


func build() -> void:
	body.add_child(UIK.button("Resume", close, "primary"))
	var sv := UIK.hbox(3)
	sv.add_child(UIK.label("Save to slot", 8, Art.C_MUTED))
	for s in [1, 2, 3]:
		var b := UIK.button(str(s), func():
			SaveSystem.save(s)
			UIRoot.toast(I18n.t("Saved to slot %d.") % s, "good", "save"))
		b.name = "SaveSlot_%d" % s
		b.custom_minimum_size = Vector2(28, 0)
		sv.add_child(b)
	sv.add_child(UIK.expand())
	var lb := UIK.button("Load last save", func():
		var s := SaveSystem.latest_slot()
		if s >= 0:
			close()
			SaveSystem.load_and_enter(s))
	sv.add_child(lb)
	body.add_child(sv)
	var sp := UIK.hbox(4)
	sp.add_child(UIK.label("Day length", 8, Art.C_MUTED))
	for opt in [[1.0, "Slow"], [1.5, "Normal"]]:
		sp.add_child(UIK.button(opt[1], func(): Clock.speed = opt[0]; rebuild(), "tab_active" if is_equal_approx(Clock.speed, opt[0]) else "tab"))
	body.add_child(sp)
	body.add_child(UIK.label("Time only moves forward by living it: working a shift, or sleeping at night.", 7, Art.C_DIM))
	var lang := UIK.hbox(4)
	lang.add_child(UIK.label("Language", 8, Art.C_MUTED))
	for l in I18n.LOCALES:
		var code: String = l[0]
		var b := UIK.button(l[1], func(): I18n.set_locale(code); UIRoot.language_changed(); rebuild(), "tab_active" if I18n.locale().begins_with(code) else "tab")
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		lang.add_child(b)
	body.add_child(lang)
	for row in [["Music", "music"], ["Sound effects", "sfx"]]:
		var ah := UIK.hbox(3)
		ah.add_child(UIK.label(row[0], 8, Art.C_MUTED))
		var cur: float = Sound.music_volume if row[1] == "music" else Sound.sfx_volume
		for lv in [[0.0, "Off"], [0.4, "Low"], [0.8, "Mid"], [1.0, "High"]]:
			var key: String = row[1]
			var b := UIK.button(lv[1], func():
				if key == "music":
					Sound.set_volumes(lv[0], Sound.sfx_volume)
				else:
					Sound.set_volumes(Sound.music_volume, lv[0])
				rebuild(), "tab_active" if absf(cur - float(lv[0])) < 0.05 else "tab")
			b.name = "Vol_%s_%d" % [key, int(float(lv[0]) * 100)]
			ah.add_child(b)
		body.add_child(ah)
	var help := UIK.hbox(4)
	help.add_child(UIK.label("Guide arrow", 8, Art.C_MUTED))
	var on := Tutorial.guide_enabled()
	help.add_child(UIK.button("On", func(): UIRoot.tutorial.set_guide(true); rebuild(), "tab_active" if on else "tab"))
	help.add_child(UIK.button("Off", func(): UIRoot.tutorial.set_guide(false); rebuild(), "tab" if on else "tab_active"))
	help.add_child(UIK.button("Replay tutorial", func():
		UIRoot.tutorial.restart()
		close()))
	body.add_child(help)
	body.add_child(UIK.button("Report a problem (F12)", func():
		close()
		UIRoot.report_problem()))
	body.add_child(UIK.button("Quit to title", func():
		close()
		SceneRouter.go_menu()))
