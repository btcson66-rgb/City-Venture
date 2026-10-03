class_name District
extends WorldScene
## A walkable city district built entirely from data/districts/<id>.json.

const BASE_Y := 320.0   # building fronts meet the north sidewalk here
const POI_ICONS := {"home": "home", "cafe": "coffee", "restaurant": "coffee", "bank": "bank", "civic": "civic", "parcel": "parcel",
	"retail": "shop", "retail_space": "shop", "own_cafe": "coffee", "lettings": "home", "flat_to_let": "home",
	"warehouse": "inventory", "van_dealer": "company", "gym": "people", "customs": "civic", "hotel": "sleep"}

var def: Dictionary = {}
var building_nodes := {}
var sign_labels := {}
var cars: Array = []
var peds: Array = []
var _ped_rng := RandomNumberGenerator.new()
var _density_acc := 0.0
var sky_layer: CanvasLayer
var _lot_rendered := ""
var sky_day: Sprite2D
var sky_dusk: Sprite2D
var sky_night: Sprite2D
var sparkles: Array[Sprite2D] = []
var _sparkle_t := 0.0
const SKY_PARALLAX := 0.55


func build(district_id: String) -> void:
	kind = "district"
	scene_id = district_id
	def = DataDB.districts[district_id]
	if district_id=="residential":
		_lot_rendered=JSON.stringify(RealEstate.lot_definition(DataDB.buildings["lot7"])["exterior"])
		EventBus.world_refresh.connect(_refresh_lot7)
	size_px = Vector2i(int(def["size_tiles"][0]) * T, int(def["size_tiles"][1]) * T)
	_init_layers()
	init_nav()
	for g in def.get("ground", []):
		var tile := str(g["type"])
		if g.has("fallback") and not has_tile(tile):
			tile = str(g["fallback"])   # a ground tile still being drawn (Old Town cobbles, Harbor quay)
		paint(tile, g["rect"], int(g.get("step", 1)))
	_build_sky()
	_add_water_sparkles()
	# north edge: building fronts / back of the block are not walkable
	var b: Dictionary = def.get("bounds", {"top": 322, "bottom": size_px.y - 8})
	add_solid(Rect2(0, 0, size_px.x, float(b["top"]) - 2.0))
	add_solid(Rect2(0, float(b["bottom"]), size_px.x, size_px.y - float(b["bottom"])))
	var has_west := false
	var has_east := false
	for ex in def.get("exits", []):
		if float(ex["rect"][0]) < 20:
			has_west = true
		else:
			has_east = true
	if not has_west:
		add_solid(Rect2(-8, 0, 10, size_px.y))
	else:
		add_solid(Rect2(-8, 0, 8, size_px.y))
	add_solid(Rect2(size_px.x - (0 if has_east else 2), 0, 10, size_px.y))
	# buildings
	for bid in def.get("buildings", []):
		var bd: Dictionary = DataDB.buildings[bid]
		if bid=="lot7":bd=RealEstate.lot_definition(bd)
		_add_building(facade(bd["exterior"]), float(bd["exterior"]["x"]), bid, bd)
	for f in def.get("fillers", []):
		_add_building(facade(f), float(f["x"]), "", {})
	for p in def.get("props", []):
		add_prop(p)
	for p in Energy.street_props(district_id):   # chargers the player built stand on the pavement
		add_prop(p)
	# metro entrance
	var m: Dictionary = def.get("metro", {})
	if not m.is_empty():
		var mp := {"sprite": "metro_entrance", "x": m["x"], "y": m["y"], "solid": [6, 20, 68, 34]}
		var holder := _add_metro(mp)
		add_interactable(Vector2(float(m["x"]) + 40, float(m["y"]) + 66), I18n.t("Metro — %s Station") % I18n.t(def["name"]), "metro", {"station": m["station"]}, 26.0)
		poi.append({"pos": Vector2(float(m["x"]) + 40, float(m["y"]) + 60), "icon": "metro", "label": "Metro"})
		var _u := holder
	# exits
	for ex in def.get("exits", []):
		var area := ExitArea.new()
		area.setup(ex, self)
		add_child(area)
		var r: Array = ex["rect"]
		poi.append({"pos": Vector2(float(r[0]) + float(r[2]) / 2.0, float(r[1]) + float(r[3]) / 2.0), "icon": "arrow_right", "label": I18n.t(DataDB.districts[ex["to"]]["name"])})
	for k in def.get("spawns", {}):
		var s: Array = def["spawns"][k]
		spawns[k] = Vector2(float(s[0]), float(s[1]))
	_ped_rng.seed = hash(district_id) + Clock.day_index()
	_spawn_traffic()
	_spawn_pedestrians(true)
	update_lighting()
	refresh_named_npcs()


## The facade to draw: the named sprite, or its `fallback` while the new facade is still being drawn.
static func facade(d: Dictionary) -> String:
	var sp := str(d.get("sprite", ""))
	if d.has("fallback") and not Art.has_tex("buildings/" + sp):
		return str(d["fallback"])
	return sp


## Rebuild only when a construction transition changes the rendered facade.
func _refresh_lot7() -> void:
	if JSON.stringify(RealEstate.lot_definition(DataDB.buildings["lot7"])["exterior"])!=_lot_rendered:
		call_deferred("_reload_lot7")
func _reload_lot7() -> void:
	if is_instance_valid(player) and SceneRouter.world_scene()==self:
		SceneRouter._enter("district","residential","metro","",player.position)

## Keep a translated sign within the painted board, including long player names.
func _fit_sign(lb: Label, board: Rect2) -> void:
	if not is_instance_valid(lb):
		return
	var fs := lb.get_theme_font_size("font_size")
	while lb.get_minimum_size().x > board.size.x + 2.0 and fs > 5:
		fs -= 1
		lb.add_theme_font_override("font", (UIK.num_font() if UIK.has_digit(lb.text) else UIK.title_font()) if fs >= 7 else UIK.bold_font())
		lb.add_theme_font_size_override("font_size", fs)
	var need := lb.get_minimum_size()
	var sz := Vector2(maxf(board.size.x, need.x), maxf(board.size.y, need.y))
	lb.size = sz
	lb.position = board.position + (board.size - sz) / 2.0


func _add_building(sprite: String, x: float, bid: String, bd: Dictionary) -> void:
	var meta: Dictionary = DataDB.buildings_meta.get(sprite, {})
	var tex := Art.tex("buildings/" + sprite)
	if tex == null:
		return
	var h := tex.get_height()
	var w := tex.get_width()
	var holder := Node2D.new()
	holder.position = Vector2(x, BASE_Y + 2)
	holder.name = "B_" + (bid if bid != "" else sprite)
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(0, -h + 2)
	holder.add_child(s)
	var lt := Sprite2D.new()
	lt.texture = Art.tex("buildings/" + sprite + "_lights")
	lt.centered = false
	lt.offset = s.offset
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	lt.material = mat
	holder.add_child(lt)
	light_nodes.append({"node": lt, "interior": false})
	entities.add_child(holder)
	building_nodes[bid if bid != "" else sprite + str(x)] = holder
	# soft contact shadow the facade casts onto the sidewalk
	var sh := Sprite2D.new()
	sh.texture = _shadow_tex()
	sh.centered = false
	sh.position = Vector2(x, BASE_Y + 1)
	sh.scale = Vector2(float(w) / 4.0, 1.0)
	back_layer.add_child(sh)
	# sign text
	var sg = meta.get("sign", null)
	var text: String = str(bd.get("exterior", {}).get("sign", meta.get("sign_text", "")))
	if bid == "small_office" and GameState.company_id() != "" and Living.has_lease("suite_2b"):
		text = GameState.entity_name(GameState.company_id()).to_upper() + " · 2B"
	if bid == "corner_cafe_unit" and Cafe.leased():
		text = Cafe.display_name().to_upper()   # your café's name over the door
	if typeof(sg) == TYPE_ARRAY and text != "":
		text = I18n.t(text)   # generic signs translate (RIVERSIDE TOWER → 河濱大樓); brand names stay as painted
		var lb := UIK.world_label(text, 8 if float(sg[3]) >= 10 and float(sg[2]) >= 70 else (7 if float(sg[3]) >= 9 else 5), Color8(250, 244, 226))
		var board := Rect2(float(sg[0]), float(sg[1]) - h + 2, float(sg[2]), float(sg[3]))
		lb.position = board.position
		lb.size = board.size   # a Label won't go below its minimum size, so keep the board rect separately
		holder.add_child(lb)
		_fit_sign.call_deferred(lb, board)   # after translation, which changes the width
		if bid != "":
			sign_labels[bid] = lb
	# door → interior
	if bid != "":
		var door_meta = meta.get("door")   # scenery sprites used as fallbacks have "door": null
		var door: Array = door_meta if door_meta is Array else [w / 2 - 10, h - 34, 20, 30]
		var dx := x + float(door[0]) + float(door[2]) / 2.0
		spawns["door_" + bid] = Vector2(dx, BASE_Y + 22)
		if not BuildingInfo.building_enterable(bid):
			return
		var trig := DoorTrigger.new()
		trig.setup(bid, Rect2(dx - float(door[2]) / 2.0 + 2, BASE_Y - 1, float(door[2]) - 4, 9))
		add_child(trig)
		var icon: String = POI_ICONS.get(str(bd.get("type", "")), "company")
		poi.append({"pos": Vector2(dx, BASE_Y), "icon": icon, "label": I18n.t(bd.get("name", bid)), "building": bid})


static var _shadow: Texture2D


static func _shadow_tex() -> Texture2D:
	if _shadow == null:
		var g := Gradient.new()
		g.set_color(0, Color(0.06, 0.09, 0.16, 0.34))
		g.set_color(1, Color(0.06, 0.09, 0.16, 0.0))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.width = 4
		gt.height = 12
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
		_shadow = gt
	return _shadow


func _add_metro(mp: Dictionary) -> Node2D:
	var tex := Art.tex("buildings/metro_entrance")
	var holder := Node2D.new()
	var h := tex.get_height()
	holder.position = Vector2(float(mp["x"]), float(mp["y"]) + h)
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(0, -h)
	holder.add_child(s)
	var lt := Sprite2D.new()
	lt.texture = Art.tex("buildings/metro_entrance_lights")
	lt.centered = false
	lt.offset = s.offset
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	lt.material = mat
	holder.add_child(lt)
	light_nodes.append({"node": lt, "interior": false})
	entities.add_child(holder)
	var sol: Array = mp["solid"]
	add_solid(Rect2(float(mp["x"]) + float(sol[0]), float(mp["y"]) + float(sol[1]), float(sol[2]), float(sol[3])))
	return holder


func _spawn_traffic() -> void:
	for lane in def.get("traffic", []):
		var n := int(round(float(lane.get("density", 0.8)) * size_px.x / 420.0))
		for i in n:
			var car := Car.new()
			car.setup(self, float(lane["y"]), int(lane["dir"]), _ped_rng)
			car.position.x = (float(i) + _ped_rng.randf() * 0.6) * size_px.x / maxf(1, n)
			entities.add_child(car)
			cars.append(car)


func target_ped_count() -> int:
	var dens: Dictionary = def.get("ambient_density", {})
	return int(dens.get(Clock.day_part(), 6))


func _spawn_pedestrians(initial: bool) -> void:
	var paths: Array = def.get("ped_paths", [])
	if paths.is_empty():
		return
	while peds.size() < target_ped_count():
		var p := Pedestrian.new()
		var path: Dictionary = paths[_ped_rng.randi_range(0, paths.size() - 1)]
		p.setup(self, path, _ped_rng, initial)
		entities.add_child(p)
		peds.append(p)


## Sky + distant skyline (converted from the concept boards' skyline banners) behind the block.
## Lives on its own CanvasLayer so the world's day/night CanvasModulate doesn't flatten it; it is
## tinted and cross-faded to the night skyline here instead, with a slow parallax.
func _build_sky() -> void:
	var rows := int(BASE_Y / T)
	for y in rows:
		for x in range(0, int(def["size_tiles"][0])):
			ground.erase_cell(Vector2i(x, y))
	sky_layer = CanvasLayer.new()
	sky_layer.layer = -1
	sky_layer.follow_viewport_enabled = true
	add_child(sky_layer)
	sky_day = Sprite2D.new()
	sky_day.texture = _sky_tex("day")
	sky_dusk = Sprite2D.new()
	sky_dusk.texture = _sky_tex("dusk")
	sky_night = Sprite2D.new()
	sky_night.texture = _sky_tex("night")
	for sp in [sky_day, sky_dusk, sky_night]:
		sp.centered = false
		if sp.texture != null:
			sp.position = Vector2(0, BASE_Y + 2 - sp.texture.get_height())
		sky_layer.add_child(sp)   # added even without art so nothing is left orphaned
	_update_sky()


## A district's own skyline (backdrops/skyline_<district>_<part>) wins over the shared one; dusk is optional.
func _sky_tex(part: String) -> Texture2D:
	var own := Art.opt_tex("backdrops/skyline_%s_%s" % [str(def.get("id", "")), part])
	if own != null:
		return own
	return Art.opt_tex("backdrops/skyline_dusk") if part == "dusk" else Art.tex("backdrops/skyline_" + part)


func _update_sky() -> void:
	if sky_day == null or not is_inside_tree():
		return
	var cam_left := -get_viewport().get_canvas_transform().origin.x
	for sp in [sky_day, sky_dusk, sky_night]:
		sp.position.x = cam_left * SKY_PARALLAX
	var nf := Clock.night_factor()
	sky_day.modulate = Color(1, 1, 1).lerp(Color(1.0, 0.78, 0.66), clampf(nf * 2.0, 0.0, 1.0))
	sky_dusk.modulate.a = clampf(nf / 0.4, 0.0, 1.0)   # day → dusk, then night fades in over it
	sky_night.modulate.a = clampf((nf - 0.35) / 0.4, 0.0, 1.0)


## Glints on open water (effects/water_sparkle: 4 frames of 16x8). Each flashes through its frames, then rests, on its
## own clock; softer at night.
func _add_water_sparkles() -> void:
	var tex := Art.opt_tex("effects/water_sparkle")
	if tex == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(scene_id + "_water")
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	for g in def.get("ground", []):
		if not str(g["type"]) in ["water", "water_alt", "water_harbor"]:
			continue
		var r: Array = g["rect"]
		var area := Rect2(float(r[0]) * T, float(r[1]) * T, float(r[2]) * T, float(r[3]) * T)
		for i in int(area.size.x * area.size.y / 9000.0):
			var s := Sprite2D.new()
			s.texture = tex
			s.hframes = 4
			s.material = mat
			s.position = (area.position + Vector2(rng.randf() * area.size.x, rng.randf() * area.size.y)).round()
			s.set_meta("phase", rng.randf() * 12.0)
			s.visible = false
			back_layer.add_child(s)
			sparkles.append(s)


func _update_sparkles(delta: float) -> void:
	if sparkles.is_empty():
		return
	_sparkle_t += delta
	var a := lerpf(0.9, 0.45, Clock.night_factor())
	for s in sparkles:
		var step := int(_sparkle_t * 7.0 + float(s.get_meta("phase"))) % 12   # 4 frames lit, 8 dark
		s.visible = step < 4
		if s.visible:
			s.frame = step
			s.modulate.a = a


func _process(delta: float) -> void:
	super._process(delta)
	_update_sky()
	_update_sparkles(delta)
	_density_acc += delta
	if _density_acc > 3.0:
		_density_acc = 0.0
		peds = peds.filter(func(p): return is_instance_valid(p))
		var want := target_ped_count()
		if peds.size() < want:
			_spawn_pedestrians(false)
		elif peds.size() > want + 2:
			peds[0].retire()
			peds.remove_at(0)


func npc_spot(spot: String) -> Vector2:
	var s: Array = def.get("npc_spots", {}).get(spot, [size_px.x / 2.0, 360.0])
	return Vector2(float(s[0]), float(s[1]))


func minimap_shapes() -> Array:
	var shapes: Array = []
	for g in def.get("ground", []):
		var col := Color8(80, 86, 98)
		match str(g["type"]):
			"grass", "grass_flowers", "garden":
				col = Color8(88, 130, 72)
			"water", "water_alt", "water_edge", "water_harbor":
				col = Color8(56, 110, 170)
			"sidewalk", "plaza", "plaza_alt", "boards", "quay_concrete", "quay_edge":
				col = Color8(170, 164, 150)
			"road", "road_dash_h", "curb_top", "curb_bottom", "crosswalk_h":
				col = Color8(70, 74, 86)
		var r: Array = g["rect"]
		shapes.append({"rect": Rect2(float(r[0]) * T, float(r[1]) * T, float(r[2]) * T, float(r[3]) * T), "color": col})
	for k in building_nodes:
		var n: Node2D = building_nodes[k]
		var s: Sprite2D = n.get_child(0)
		var w := float(s.texture.get_width())
		var col2 := Color8(120, 150, 200) if not k.begins_with("B_") and DataDB.buildings.has(k) else Color8(96, 104, 124)
		if DataDB.buildings.has(k):
			col2 = Color8(210, 190, 130)
		shapes.append({"rect": Rect2(n.position.x, BASE_Y - 60, w, 58), "color": col2})
	return shapes
