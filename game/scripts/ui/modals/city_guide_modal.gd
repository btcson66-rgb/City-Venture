class_name CityGuideModal
extends Modal
## Phone destinations are generated from current building/district data, including future active content.


func _init() -> void:
	title_text = "City Guide"
	icon_name = "map"
	help_key = "city_guide"
	panel_size = Vector2(570, 320)
	pauses_time = true


func build() -> void:
	var list := UIK.vbox(5)
	body.add_child(UIK.scroll(list, Vector2(548, 245)))
	for group in BuildingInfo.guide_groups():
		list.add_child(UIK.label(group["name"], 9, Art.C_GOLD, true))
		if not group["open"]:
			list.add_child(UIK.label("Not open yet", 7, Art.C_DIM))
			continue
		for bid in group["buildings"]:
			var card := UIK.panel("ui/card", 4)
			card.name = "GuideBuilding_" + bid
			list.add_child(card)
			var v := UIK.vbox(2)
			card.add_child(v)
			var row := UIK.hbox(6)
			v.add_child(row)
			row.add_child(UIK.label(I18n.t(str(DataDB.building(bid)["name"])) + " — " + BuildingInfo.category(bid), 8, Art.C_WHITE, true))
			row.add_child(UIK.expand())
			var route := UIK.button("Take me there", _guide.bind(bid))
			route.name = "GuideTo_" + bid
			row.add_child(route)
			v.add_child(UIK.wrap(BuildingInfo.guide_tags(bid) + " · " + BuildingInfo.status(bid), 7, Art.C_SKY, 520))
			v.add_child(UIK.wrap(BuildingInfo.hours(bid), 7, Art.C_MUTED, 520))
			v.add_child(UIK.wrap(I18n.t(group["name"]) + " · " + BuildingInfo.station(bid), 7, Art.C_MUTED, 520))
			if not SceneRouter.building_open(bid)["open"]:
				v.add_child(UIK.wrap("The arrow guides you to the door; wait until opening hours to enter.", 7, Art.C_DIM, 520))
	var done := UIK.button("Close", close)
	done.name = "CloseCityGuide"
	footer.add_child(done)


func _guide(bid: String) -> void:
	UIRoot.tutorial.guide_to_building(bid)
	close()
	UIRoot.toast(I18n.t("Follow the gold arrow to %s.") % I18n.t(str(DataDB.building(bid)["name"])), "info", "map")
