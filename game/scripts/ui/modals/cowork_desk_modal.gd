class_name CoworkDeskModal
extends Modal


func _init() -> void:
	title_text = "Nexus Co-work — Reception"
	icon_name = "people"
	panel_size = Vector2(360, 190)


func build() -> void:
	if not Actions.npc_present("priya"):
		body.add_child(UIK.wrap("Reception is unstaffed. Self-service kiosk:", 8, Art.C_MUTED, 340))
	body.add_child(UIK.kv("Day pass (desk + wifi, today)", "$15.00", Art.C_WHITE))
	body.add_child(UIK.kv("Hot desk — monthly", "$350.00", Art.C_WHITE))
	if Living.has_lease("nexus_cowork_desk"):
		body.add_child(UIK.label("You have a monthly desk.", 8, Art.C_GREEN, true))
	elif Living.has_desk_access():
		body.add_child(UIK.label("Your day pass is active today.", 8, Art.C_GREEN, true))
	else:
		var d := UIK.button("Buy a day pass ($15)", _day, "primary")
		d.name = "DayPass"
		body.add_child(d)
		var m := UIK.button("Monthly hot desk ($350)", _month)
		m.name = "MonthlyDesk"
		body.add_child(m)
	footer.add_child(UIK.button("Close", close))
	if not GameState.flag("met_priya") and Actions.npc_present("priya"):
		call_deferred("_greet")


func _greet() -> void:
	close()
	UIRoot.play_dialogue("priya_first", func(): UIRoot.open_modal(CoworkDeskModal.new()))


func _day() -> void:
	Living.buy_day_pass()
	UIRoot.toast("Day pass active. Grab any hot desk.", "good", "check")
	rebuild()


func _month() -> void:
	var r := Living.lease("nexus_cowork_desk")
	if not r["ok"]:
		UIRoot.toast(r["error"], "bad", "warning")
		return
	GameState.set_flag("workspace_chosen")
	rebuild()
