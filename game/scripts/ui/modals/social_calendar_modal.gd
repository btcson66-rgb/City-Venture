class_name SocialCalendarModal
extends Modal
var notice := ""
func _init() -> void:
	title_text="City social calendar";help_key="personal_life";icon_name="calendar";panel_size=Vector2(535,290)
func build() -> void:
	if notice!="":body.add_child(UIK.wrap(notice,9,Art.C_SKY,505))
	var list := UIK.vbox(7);body.add_child(UIK.scroll(list,Vector2(500,220)))
	var primary := false
	for event in PersonalLife.cfg()["events"].values():
		list.add_child(UIK.title(event["title"],10))
		list.add_child(UIK.wrap(I18n.t("Monthly day %d · %02d:00–%02d:00 · %d minutes · %s")%[int(event["day"]),int(event["hour"]),int(event["end_hour"]),int(event["minutes"]),Fmt.money(float(event["cost"]))],8,Art.C_WHITE,475))
		var available := PersonalLife.event_available(event)
		list.add_child(UIK.wrap("✓ "+I18n.t("Open — attend now or keep your plans.") if available else "✗ "+I18n.t("Closed or already attended — return on the next monthly date."),8,Art.C_WHITE,475))
		var gate := Fundraising.dress_check(event)
		if str(event.get("dress",""))!="":
			var line := I18n.t("Dress code: %s. You are wearing: %s.")%[Fundraising.dress_name(str(event["dress"])),Fundraising.dress_name(Wardrobe.dress_of(Wardrobe.wearing()))]
			if not gate["ok"]:line+=" "+I18n.t("The door will turn you away.")
			elif gate["impression"]=="poor":line+=" "+I18n.t("You may attend, but first impressions will be cooler.")
			list.add_child(UIK.wrap(("✓ " if gate["ok"] and gate["impression"]!="poor" else "✗ ")+line,8,Art.C_WHITE if gate["ok"] else Art.C_GOLD,475))
			if not gate["ok"] or gate["impression"]=="poor":
				var wardrobe := UIK.button("Open my wardrobe",func():UIRoot.open_modal(WardrobeModal.new()))
				wardrobe.name="SocialWardrobe_"+str(event["id"]);list.add_child(wardrobe)
		if available:
			var b := UIK.button("Attend",func():
				var result := PersonalLife.attend(event["id"])
				notice=I18n.t(result["info"]) if result["ok"] else result["error"]
				rebuild(),"primary" if not primary else "")
			b.name="Social_"+str(event["id"]);list.add_child(b);primary=true
	footer.add_child(UIK.button("Keep my plans",close))
