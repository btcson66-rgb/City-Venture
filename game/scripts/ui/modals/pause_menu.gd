class_name PauseMenu
extends Modal


func _init() -> void:
	pauses_time = true
	title_text = "Paused"
	icon_name = "settings"
	panel_size = Vector2(330, 318)


func build() -> void:
	body.add_child(UIK.button("Resume", close, "primary"))
	var sv := UIK.hbox(3)
	var sn := UIK.button("Save now", func():
		SaveSystem.autosave()
		UIRoot.toast(I18n.t("Saved (slot %d).") % SaveSystem.current_slot(), "good", "save"))
	sn.name = "SaveNow"
	sv.add_child(sn)
	sv.add_child(UIK.label(I18n.t("This game autosaves to slot %d.") % SaveSystem.current_slot(), 7, Art.C_DIM))
	sv.add_child(UIK.expand())
	var lb := UIK.button("Load a game", func():
		close()
		UIRoot.open_modal(SaveListModal.new("load")))
	lb.name = "LoadGame"
	sv.add_child(lb)
	body.add_child(sv)
	var settings := UIK.button("Settings", func(): UIRoot.open_modal(SettingsModal.new()))
	settings.name = "Settings"
	body.add_child(settings)
	var lang := UIK.hbox(4)
	lang.add_child(UIK.label("Language", 8, Art.C_MUTED))
	for l in I18n.LOCALES:
		var code: String = l[0]
		var b := UIK.button(l[1], func(): I18n.set_locale(code); UIRoot.language_changed(); rebuild(), "tab_active" if I18n.locale().begins_with(code) else "tab")
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		lang.add_child(b)
	body.add_child(lang)
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
