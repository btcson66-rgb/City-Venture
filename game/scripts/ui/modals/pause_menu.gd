class_name PauseMenu
extends Modal


func _init() -> void:
	title_text = "Paused"
	icon_name = "settings"
	panel_size = Vector2(260, 220)


func build() -> void:
	body.add_child(UIK.button("Resume", close, "primary"))
	for s in [1, 2, 3]:
		body.add_child(UIK.button("Save to slot %d" % s, func():
			SaveSystem.save(s)
			UIRoot.toast("Saved to slot %d." % s, "good", "save")))
	var lb := UIK.button("Load last save", func():
		var s := SaveSystem.latest_slot()
		if s >= 0:
			close()
			SaveSystem.load_and_enter(s))
	body.add_child(lb)
	var sp := UIK.hbox(4)
	sp.add_child(UIK.label("Day length", 8, Art.C_MUTED))
	for opt in [[1.0, "Slow"], [1.5, "Normal"], [2.5, "Fast"]]:
		sp.add_child(UIK.button(opt[1], func(): Clock.speed = opt[0]; rebuild(), "tab_active" if is_equal_approx(Clock.speed, opt[0]) else "tab"))
	body.add_child(sp)
	body.add_child(UIK.label("Hold T to fast-forward time in the world.", 7, Art.C_DIM))
	body.add_child(UIK.button("Quit to title", func():
		close()
		SceneRouter.go_menu()))
