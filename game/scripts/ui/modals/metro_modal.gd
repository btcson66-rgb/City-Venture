class_name MetroModal
extends Modal
## Metro stub: pick a station, pay the fare, time passes.

var from := ""


func _init(station: String) -> void:
	from = station
	title_text = I18n.t("Aurelia Metro — %s") % I18n.t(DataDB.districts.get(station, {}).get("name", station))
	icon_name = "metro"
	help_key = "metro"
	panel_size = Vector2(460, 260)


func _minutes(to: String) -> int:
	var tm: Dictionary = DataDB.city["metro"]["travel_min"]
	if tm.has(from + ">" + to):
		return int(tm[from + ">" + to])
	if tm.has(to + ">" + from):
		return int(tm[to + ">" + from])
	return 15


func build() -> void:
	var h := UIK.hbox(8)
	body.add_child(h)
	var mapc := Control.new()
	mapc.custom_minimum_size = Vector2(220, 124)
	h.add_child(mapc)
	var img := TextureRect.new()
	img.texture = Art.tex("city_map/aurelia_map")
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.size = Vector2(220, 124)
	img.modulate = Color(0.7, 0.75, 0.85)
	mapc.add_child(img)
	var lines := MetroLines.new()
	lines.size = Vector2(220, 124)
	lines.scale_f = 220.0 / 640.0
	lines.here = from
	mapc.add_child(lines)
	var v := UIK.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UIK.label(I18n.t("DESTINATIONS · fare %s") % Fmt.money0(float(DataDB.city["metro"]["fare"])), 7, Art.C_DIM, true))
	for d in DataDB.city["districts"]:
		if d["id"] == from:
			continue
		if not BuildingInfo.district_open(str(d["id"])):
			continue
		var b := UIK.button(I18n.t("%s  ·  %d min") % [I18n.t(d["name"]), _minutes(d["id"])], _go.bind(d["id"]))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.name = "Go_" + d["id"]
		v.add_child(b)
	v.add_child(UIK.sep())
	footer.add_child(UIK.button("Cancel", close))


func _go(to: String) -> void:
	close()
	SceneRouter.metro_travel(to, _minutes(to), float(DataDB.city["metro"]["fare"]))
