class_name District
extends WorldScene
## A walkable city district built entirely from data/districts/<id>.json.

const BASE_Y := 320.0   # building fronts meet the north sidewalk here

var def: Dictionary = {}
var building_nodes := {}
var sign_labels := {}
var cars: Array = []
var peds: Array = []
var _ped_rng := RandomNumberGenerator.new()
var _density_acc := 0.0


func build(district_id: String) -> void:
	kind = "district"
	scene_id = district_id
	def = DataDB.districts[district_id]
	size_px = Vector2i(int(def["size_tiles"][0]) * T, int(def["size_tiles"][1]) * T)
	_init_layers()
	init_nav()
	for g in def.get("ground", []):
		paint(g["type"], g["rect"], int(g.get("step", 1)))
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
		_add_building(bd["exterior"]["sprite"], float(bd["exterior"]["x"]), bid, bd)
	for f in def.get("fillers", []):
		_add_building(f["sprite"], float(f["x"]), "", {})
	for p in def.get("props", []):
		add_prop(p)
	# metro entrance
	var m: Dictionary = def.get("metro", {})
	if not m.is_empty():
		var mp := {"sprite": "metro_entrance", "x": m["x"], "y": m["y"], "solid": [6, 20, 68, 34]}
		var holder := _add_metro(mp)
		add_interactable(Vector2(float(m["x"]) + 40, float(m["y"]) + 66), "Metro — %s Station" % def["name"], "metro", {"station": m["station"]}, 26.0)
		poi.append({"pos": Vector2(float(m["x"]) + 40, float(m["y"]) + 60), "icon": "metro", "label": "Metro"})
		var _u := holder
	# exits
	for ex in def.get("exits", []):
		var area := ExitArea.new()
		area.setup(ex, self)
		add_child(area)
		var r: Array = ex["rect"]
		poi.append({"pos": Vector2(float(r[0]) + float(r[2]) / 2.0, float(r[1]) + float(r[3]) / 2.0), "icon": "arrow_right", "label": DataDB.districts[ex["to"]]["name"]})
	for k in def.get("spawns", {}):
		var s: Array = def["spawns"][k]
		spawns[k] = Vector2(float(s[0]), float(s[1]))
	_ped_rng.seed = hash(district_id) + Clock.day_index()
	_spawn_traffic()
	_spawn_pedestrians(true)
	update_lighting()
	refresh_named_npcs()


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
	# sign text
	var sg = meta.get("sign", null)
	var text: String = str(bd.get("exterior", {}).get("sign", meta.get("sign_text", "")))
	if bid == "small_office" and GameState.company_id() != "" and Living.has_lease("suite_2b"):
		text = GameState.entity_name(GameState.company_id()).to_upper() + " · 2B"
	if typeof(sg) == TYPE_ARRAY and text != "":
		var lb := UIK.world_label(text, 7 if float(sg[3]) >= 9 else 5, Color8(250, 244, 226))
		lb.position = Vector2(float(sg[0]), float(sg[1]) - h + 2 + (0.0 if float(sg[3]) >= 9 else -1.0))
		lb.size = Vector2(float(sg[2]), float(sg[3]))
		holder.add_child(lb)
		if bid != "":
			sign_labels[bid] = lb
	# door → interior
	if bid != "":
		var door: Array = meta.get("door", [w / 2 - 10, h - 34, 20, 30])
		var dx := x + float(door[0]) + float(door[2]) / 2.0
		var trig := DoorTrigger.new()
		trig.setup(bid, Rect2(dx - float(door[2]) / 2.0 + 2, BASE_Y - 1, float(door[2]) - 4, 9))
		add_child(trig)
		spawns["door_" + bid] = Vector2(dx, BASE_Y + 22)
		var icon := "home" if bd.get("type", "") == "home" else ("coffee" if bd.get("type", "") == "cafe" else ("bank" if bd.get("type", "") == "bank" else ("civic" if bd.get("type", "") == "civic" else ("parcel" if bd.get("type", "") == "parcel" else "company"))))
		poi.append({"pos": Vector2(dx, BASE_Y), "icon": icon, "label": bd.get("name", bid), "building": bid})


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


func _process(delta: float) -> void:
	super._process(delta)
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
			"water", "water_alt", "water_edge":
				col = Color8(56, 110, 170)
			"sidewalk", "plaza", "plaza_alt", "boards":
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
