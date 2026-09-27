class_name CityMapModal
extends Modal
## City Map (Handoff §44): Aurelia overview with district cards. Travel happens on foot or by Metro.

var sel := ""


func _init(_travel: bool) -> void:
	title_text = "Aurelia City"
	icon_name = "map"
	panel_size = Vector2(600, 330)


func build() -> void:
	var here := ""
	var ws := SceneRouter.world_scene()
	if ws:
		here = ws.scene_id if ws.kind == "district" else DataDB.building(ws.scene_id).get("district", "")
	if sel == "":
		sel = here
	var h := UIK.hbox(8)
	body.add_child(h)
	var mapc := Control.new()
	mapc.custom_minimum_size = Vector2(400, 225)
	h.add_child(mapc)
	var img := TextureRect.new()
	img.texture = Art.tex("city_map/aurelia_map")
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.size = Vector2(400, 225)
	mapc.add_child(img)
	var lines := MetroLines.new()
	lines.size = Vector2(400, 225)
	lines.scale_f = 400.0 / 640.0
	lines.here = here
	lines.modulate.a = 0.75
	mapc.add_child(lines)
	for d in DataDB.city["districts"]:
		var p: Array = d["map_pos"]
		var pos := Vector2(float(p[0]), float(p[1])) * 400.0 / 640.0
		var b := Button.new()
		b.text = d["name"]
		b.icon = Art.icon(d.get("icon", "info"))
		b.add_theme_font_size_override("font_size", 6)
		b.focus_mode = Control.FOCUS_NONE
		b.position = pos + Vector2(-24, -20)
		b.modulate = Color(1, 1, 1, 1.0 if d["status"] == "active" else 0.62)
		if d["id"] == here:
			b.add_theme_stylebox_override("normal", UIK.tex_box("ui/button_primary", 4, 3))
		b.pressed.connect(func(): sel = d["id"]; rebuild())
		mapc.add_child(b)
	var info := UIK.vbox(3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var dd := DataDB.district_def_in_city(sel)
	info.add_child(UIK.title(dd.get("name", "—"), 11))
	info.add_child(UIK.wrap(dd.get("blurb", ""), 8, Art.C_SKY, 150))
	if dd.get("status", "") == "active":
		info.add_child(UIK.chip("OPEN IN THIS BUILD", Art.C_GREEN))
	else:
		info.add_child(UIK.chip("PLANNED · P1", Art.C_GOLD))
	if sel == here:
		info.add_child(UIK.label("You are here.", 8, Art.C_GOLD, true))
	info.add_child(UIK.sep())
	info.add_child(UIK.label("Pop. 3.2M · 62 km² · 5 Metro lines", 7, Art.C_DIM))
	info.add_child(UIK.wrap("Travel: walk between neighbouring districts, or take the Metro from any station.", 7, Art.C_MUTED, 150))
	footer.add_child(UIK.button("World map", func(): close(); UIRoot.open_modal(WorldMapModal.new())))
	footer.add_child(UIK.button("Close", close, "", 60))
