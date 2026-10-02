class_name WorldMapModal
extends Modal
## World Map (Handoff §43) on the concept-board-E world art, with in-game region labels over the
## board's label spots. Overseas play is Planned (P2) and says so.

const MAP_BOX := Rect2(12, 150, 928, 395)   # board-E crop the map texture was made from
const MAP_SIZE := Vector2(600, 255)

var sel := "aurelia"
var _t := 0.0
var _home: Control


func _init() -> void:
	title_text = "World Map"
	icon_name = "world"
	panel_size = Vector2(632, 352)


static func b2m(p: Vector2) -> Vector2:
	return (p - MAP_BOX.position) * (MAP_SIZE.x / MAP_BOX.size.x)


func build() -> void:
	footer.visible = false
	var map_frame := Control.new()
	map_frame.custom_minimum_size = MAP_SIZE
	var mapc := Control.new()
	mapc.name = "TouchMap"
	mapc.set_meta("map_base_size", MAP_SIZE)
	map_frame.add_child(mapc)
	mapc.custom_minimum_size = MAP_SIZE
	mapc.clip_contents = true
	mapc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(map_frame)
	var img := TextureRect.new()
	img.texture = Art.tex("world_map/board")
	img.size = MAP_SIZE
	mapc.add_child(img)
	for rid in DataDB.regions:
		var r: Dictionary = DataDB.regions[rid]
		if not r.has("board"):
			continue
		var lb: Array = r["board"]["label"]
		var a := b2m(Vector2(float(lb[0]), float(lb[1])))
		var z := b2m(Vector2(float(lb[2]), float(lb[3])))
		var home: bool = rid == "aurelia"
		var b := Button.new()
		b.name = "Region_" + rid
		b.focus_mode = Control.FOCUS_NONE
		b.position = a
		b.custom_minimum_size = z - a
		b.size = z - a
		var accent := Art.C_GOLD if home or rid == sel else Color8(90, 130, 200)
		var bg := Color(0.04, 0.07, 0.14, 1.0)
		b.add_theme_stylebox_override("normal", UIK.flat(bg, accent, 1, 2))
		b.add_theme_stylebox_override("hover", UIK.flat(Color(0.08, 0.13, 0.24, 1.0), Art.C_GOLD, 1, 2))
		b.add_theme_stylebox_override("pressed", UIK.flat(bg, Art.C_GOLD, 1, 2))
		b.pressed.connect(func(): sel = rid; rebuild())
		mapc.add_child(b)
		var hb := UIK.hbox(3)
		hb.position = Vector2(2, 2)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(hb)
		if not home:
			var th := TextureRect.new()
			th.texture = Art.tex("world_map/r_" + rid)
			th.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			th.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
			th.custom_minimum_size = Vector2(minf(36.0, b.size.y - 4), b.size.y - 4)
			th.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(th)
		var v := UIK.vbox(0)
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(v)
		var tl := UIK.label(I18n.t(r["name"]).to_upper(), 7, Art.C_GOLD if home else Art.C_WHITE, true)
		tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(tl)
		var st := UIK.label("Your home market" if home else str(r["archetype"]), 6, Art.C_SKY)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(st)
		UIK.fit_card.call_deferred(b, hb, Rect2(a, z - a), Vector2(4, 4))
		if home:
			_home = Control.new()
			_home.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var pin: Array = r["board"]["pin"]
			_home.position = b2m(Vector2(float(pin[0]), float(pin[1])))
			_home.draw.connect(_draw_home)
			mapc.add_child(_home)
	# selected-region strip
	var r2: Dictionary = DataDB.regions[sel]
	var row := UIK.hbox(6)
	body.add_child(row)
	var pv := TextureRect.new()
	pv.texture = Art.tex("world_map/r_" + sel)
	pv.custom_minimum_size = Vector2(64, 40)
	row.add_child(pv)
	var c1 := UIK.vbox(0)
	c1.custom_minimum_size = Vector2(130, 0)
	row.add_child(c1)
	c1.add_child(UIK.title(r2["name"], 11))
	c1.add_child(UIK.label(r2["archetype"], 7, Art.C_SKY, true))
	if sel == "aurelia":
		c1.add_child(UIK.chip("YOUR HOME MARKET", Art.C_GREEN))
	else:
		c1.add_child(UIK.chip("OVERSEAS · PLANNED P2", Art.C_GOLD))
	var c2 := UIK.vbox(0)
	c2.custom_minimum_size = Vector2(210, 0)
	row.add_child(c2)
	c2.add_child(UIK.wrap(I18n.t("Industries: ") + I18n.join(r2["industries"]), 6, Art.C_WHITE, 206))
	if not r2["strengths"].is_empty():
		c2.add_child(UIK.wrap("+ " + I18n.join(r2["strengths"]), 6, Art.C_GREEN, 206))
	if not r2["risks"].is_empty():
		c2.add_child(UIK.wrap("− " + I18n.join(r2["risks"]), 6, Art.C_RED, 206))
	var c3 := UIK.vbox(1)
	c3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(c3)
	if sel != "aurelia":
		c3.add_child(UIK.kv("Flight", "%dh" % int(r2["flight_hours_from_aurelia"]), Art.C_WHITE, 7))
		c3.add_child(UIK.kv("Shipping", "%dd" % int(r2["shipping_days_from_aurelia"]), Art.C_WHITE, 7))
	var brow := UIK.hbox(4)
	c3.add_child(brow)
	brow.add_child(UIK.button("City map", func(): close(); UIRoot.open_modal(CityMapModal.new(false)), "", 56))
	brow.add_child(UIK.button("Close", close, "", 44))


func _draw_home() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 3.0)
	_home.draw_circle(Vector2.ZERO, 5.0 + pulse * 3.0, Color(1, 0.8, 0.3, 0.25 + 0.2 * pulse))
	var pts := PackedVector2Array()
	for i in 10:
		var ang := -PI / 2.0 + i * TAU / 10.0
		pts.append(Vector2(cos(ang), sin(ang)) * (5.0 if i % 2 == 0 else 2.2))
	_home.draw_colored_polygon(pts, Art.C_GOLD)


func _process(delta: float) -> void:
	_t += delta
	if _home != null:
		_home.queue_redraw()
