class_name WorldMapModal
extends Modal
## World Map (Handoff §43). Present in the slice for structure; overseas play is Planned (P2) and says so.

var sel := "aurelia"


func _init() -> void:
	title_text = "World Map"
	icon_name = "world"
	panel_size = Vector2(610, 335)


func build() -> void:
	var h := UIK.hbox(8)
	body.add_child(h)
	var mapc := Control.new()
	mapc.custom_minimum_size = Vector2(400, 225)
	h.add_child(mapc)
	var img := TextureRect.new()
	img.texture = Art.tex("world_map/world_map")
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_SCALE
	img.size = Vector2(400, 225)
	mapc.add_child(img)
	var routes := WorldRoutes.new()
	routes.size = Vector2(400, 225)
	mapc.add_child(routes)
	for rid in DataDB.regions:
		var r: Dictionary = DataDB.regions[rid]
		var p: Array = r["map_pos"]
		var pos := Vector2(float(p[0]), float(p[1])) * 400.0 / 640.0
		var b := Button.new()
		b.text = r["name"]
		b.add_theme_font_size_override("font_size", 6)
		b.focus_mode = Control.FOCUS_NONE
		b.position = pos + Vector2(-18, -18)
		if rid == "aurelia":
			b.add_theme_stylebox_override("normal", UIK.tex_box("ui/button_primary", 4, 3))
		b.pressed.connect(func(): sel = rid; rebuild())
		mapc.add_child(b)
	var r2: Dictionary = DataDB.regions[sel]
	var info := UIK.vbox(3)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	info.add_child(UIK.title(r2["name"], 12))
	info.add_child(UIK.label(r2["archetype"], 8, Art.C_SKY, true))
	info.add_child(UIK.wrap("Industries: " + ", ".join(r2["industries"]), 7, Art.C_WHITE, 160))
	if not r2["strengths"].is_empty():
		info.add_child(UIK.wrap("+ " + ", ".join(r2["strengths"]), 7, Art.C_GREEN, 160))
	if not r2["risks"].is_empty():
		info.add_child(UIK.wrap("− " + ", ".join(r2["risks"]), 7, Art.C_RED, 160))
	if sel != "aurelia":
		info.add_child(UIK.kv("Flight", "%dh" % int(r2["flight_hours_from_aurelia"]), Art.C_WHITE, 7))
		info.add_child(UIK.kv("Shipping", "%dd" % int(r2["shipping_days_from_aurelia"]), Art.C_WHITE, 7))
		info.add_child(UIK.wrap("Entry: " + str(r2["entry_requirement"]), 7, Art.C_MUTED, 160))
		info.add_child(UIK.chip("OVERSEAS · PLANNED P2", Art.C_GOLD))
	else:
		info.add_child(UIK.chip("YOUR HOME MARKET", Art.C_GREEN))
	footer.add_child(UIK.button("Close", close, "", 60))
