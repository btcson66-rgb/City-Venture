class_name CityMapModal
extends Modal
## City Map (Handoff §44): the isometric Aurelia map from concept board F, with crisp in-game district
## labels laid over the board's own label spots. Travel happens on foot or by Metro.

const MAP_BOX := Rect2(14, 155, 976, 650)   # board-F crop the map texture was made from
const MAP_SIZE := Vector2(458, 305)

var sel := ""
var here := ""
var _t := 0.0
var _pin: Control


func _init(_travel: bool) -> void:
	title_text = "Aurelia City"
	icon_name = "map"
	help_key = "city_map"
	panel_size = Vector2(632, 352)


static func board_to_map(p: Vector2) -> Vector2:
	return (p - MAP_BOX.position) * (MAP_SIZE.x / MAP_BOX.size.x)


static func board_rect(r: Array) -> Rect2:
	var a := board_to_map(Vector2(float(r[0]), float(r[1])))
	var b := board_to_map(Vector2(float(r[2]), float(r[3])))
	return Rect2(a, b - a)


func build() -> void:
	var ws := SceneRouter.world_scene()
	if ws:
		here = ws.scene_id if ws.kind == "district" else DataDB.building(ws.scene_id).get("district", "")
	if sel == "":
		sel = here if here != "" else "riverside"
	if not BuildingInfo.district_open(sel):
		sel = "riverside"
	footer.visible = false
	var h := UIK.hbox(8)
	body.add_child(h)
	var map_frame := Control.new()
	map_frame.custom_minimum_size = MAP_SIZE
	var mapc := Control.new()
	mapc.name = "TouchMap"
	mapc.set_meta("map_base_size", MAP_SIZE)
	map_frame.add_child(mapc)
	mapc.custom_minimum_size = MAP_SIZE
	mapc.clip_contents = true
	h.add_child(map_frame)
	var img := TextureRect.new()
	img.texture = Art.tex("city_map/board")
	img.size = MAP_SIZE
	mapc.add_child(img)
	# legend over the board's stats box
	var ex: Dictionary = DataDB.city.get("board_extra", {})
	if ex.has("legend"):
		var lr := board_rect(ex["legend"])
		var lg := PanelContainer.new()
		lg.add_theme_stylebox_override("panel", UIK.flat(Color(0.04, 0.07, 0.14, 0.94), Color8(70, 96, 150), 1))
		lg.position = lr.position
		lg.custom_minimum_size = lr.size
		var lv := UIK.vbox(1)
		lg.add_child(lv)
		lv.add_child(UIK.label("LEGEND", 6, Art.C_DIM, true))
		lv.add_child(UIK.label("● Open in this build", 6, Art.C_GREEN))
		lv.add_child(UIK.label("◆ You are here", 6, Art.C_WHITE))
		mapc.add_child(lg)
	if ex.has("metro"):
		var m: Dictionary = ex["metro"]
		mapc.add_child(_label_card(board_rect(m["label"]), str(m["name"]), str(m["sub"]), "metro", Color8(74, 140, 232), false, Callable()))
	for d in DataDB.city["districts"]:
		if not d.has("board"):
			continue
		var bd: Dictionary = d["board"]
		if not BuildingInfo.district_open(str(d["id"])):
			continue
		var sub := "You are here" if d["id"] == here else "Open"
		var did: String = d["id"]
		var card := _label_card(board_rect(bd["label"]), d["name"], sub, d.get("icon", "info"), Color(bd.get("accent", "#4a8ce8")), did == sel,
				func(): sel = did; rebuild())
		card.name = "District_" + did
		mapc.add_child(card)
	if GameState.data.get("real_estate_landmark",{}).get("completed",false):
		var residential := DataDB.district_def_in_city("residential")
		var pin: Array=residential["board"]["pin"]
		var landmark := TextureButton.new()
		landmark.name="Landmark_lot7"
		landmark.texture_normal=Art.icon("home")
		landmark.position=board_to_map(Vector2(float(pin[0]),float(pin[1])))+Vector2(-6,-14)
		landmark.tooltip_text=str(GameState.data["real_estate_landmark"]["name"])
		landmark.pressed.connect(func():sel="residential";rebuild())
		mapc.add_child(landmark)
	# "you are here" marker
	var hd := DataDB.district_def_in_city(here)
	if hd.has("board"):
		_pin = Control.new()
		_pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_pin.position = board_to_map(Vector2(float(hd["board"]["pin"][0]), float(hd["board"]["pin"][1])))
		_pin.draw.connect(_draw_pin)
		mapc.add_child(_pin)
	# info column
	var info := UIK.vbox(3)
	info.custom_minimum_size = Vector2(150, 0)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var dd := DataDB.district_def_in_city(sel)
	var pic := TextureRect.new()
	pic.texture = Art.tex("city_map/i_" + sel)
	pic.custom_minimum_size = Vector2(144, 90)
	info.add_child(pic)
	info.add_child(UIK.title(dd.get("name", "—"), 11))
	info.add_child(UIK.wrap(dd.get("blurb", ""), 7, Art.C_SKY, 146))
	if sel=="residential" and GameState.data.get("real_estate_landmark",{}).get("completed",false):
		info.add_child(UIK.wrap(str(GameState.data["real_estate_landmark"]["name"]),7,Art.C_GOLD,146))
	info.add_child(UIK.chip("Open", Art.C_GREEN))
	if sel == here:
		info.add_child(UIK.label("You are here.", 7, Art.C_GOLD, true))
	info.add_child(UIK.sep())
	info.add_child(UIK.wrap("Population: 3.2 million people · 62 km² · 5 Metro lines", 6, Art.C_DIM, 146))
	info.add_child(UIK.wrap("Walk between neighbouring districts, or take the Metro from any station.", 6, Art.C_MUTED, 146))
	var sp := Control.new()
	sp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(sp)
	var row := UIK.hbox(4)
	info.add_child(row)
	if BuildingInfo.world_travel_available():
		var world := UIK.button("World map", func(): close(); UIRoot.open_modal(WorldMapModal.new()), "", 70)
		world.name = "WorldMap"
		row.add_child(world)
	row.add_child(UIK.button("Close", close, "", 60))


func _label_card(r: Rect2, title: String, sub: String, icon: String, accent: Color, selected: bool, on_press: Callable) -> Control:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.position = r.position
	b.custom_minimum_size = r.size
	b.size = r.size
	var bg := Color(0.04, 0.07, 0.14, 1.0)
	b.add_theme_stylebox_override("normal", UIK.flat(bg, Art.C_GOLD if selected else accent, 1, 2))
	b.add_theme_stylebox_override("hover", UIK.flat(Color(0.08, 0.13, 0.24, 1.0), Art.C_GOLD, 1, 2))
	b.add_theme_stylebox_override("pressed", UIK.flat(bg, Art.C_GOLD, 1, 2))
	if on_press.is_valid():
		b.pressed.connect(on_press)
	else:
		b.disabled = true
		b.add_theme_stylebox_override("disabled", UIK.flat(bg, accent, 1, 2))
	var hb := UIK.hbox(3)
	hb.position = Vector2(3, 2)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	var ic := UIK.icon(icon, 10)
	ic.modulate = accent.lightened(0.2)
	hb.add_child(ic)
	var v := UIK.vbox(0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(v)
	var t := UIK.label(title, 7, Art.C_WHITE, true)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(t)
	var s := UIK.label(sub, 6, Art.C_GOLD if sub == "You are here" else (Art.C_GREEN if sub == "Open" else Art.C_MUTED))
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(s)
	UIK.fit_card.call_deferred(b, hb, r, Vector2(6, 4))
	return b


func _draw_pin() -> void:
	var bob := sin(_t * 4.0) * 1.5
	var c := Vector2(0, -6 + bob)
	_pin.draw_circle(Vector2(0, 0), 4.0 + 1.5 * (0.5 + 0.5 * sin(_t * 3.0)), Color(1, 0.8, 0.3, 0.35))
	_pin.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -5), c + Vector2(4, 0), c + Vector2(0, 5), c + Vector2(-4, 0)]), Art.C_GOLD)
	_pin.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -3), c + Vector2(2, 0), c + Vector2(0, 3), c + Vector2(-2, 0)]), Color.WHITE)


func _process(delta: float) -> void:
	_t += delta
	if _pin != null:
		_pin.queue_redraw()
