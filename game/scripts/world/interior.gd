class_name Interior
extends WorldScene
## A walkable building interior built from data/buildings/<id>.json → "interior".

const WALL_ROWS := 3

var def: Dictionary = {}
var bdef: Dictionary = {}
var stock_holder: Node2D
var company_sign: Label
var ambient: Array = []
var staff_nodes := {}


func build(building_id: String) -> void:
	kind = "interior"
	scene_id = building_id
	bdef = DataDB.buildings[building_id]
	def = bdef["interior"]
	var wt := int(def["size"][0])
	var ht := int(def["size"][1])
	size_px = Vector2i(wt * T, ht * T)
	_init_layers()
	init_nav()
	# backdrop
	var bg := ColorRect.new()
	bg.color = Color8(10, 18, 30)
	bg.position = Vector2(-640, -400)
	bg.size = Vector2(size_px.x + 1280, size_px.y + 800)
	bg.z_index = -10
	add_child(bg)
	move_child(bg, 0)
	paint("wall_" + str(def.get("wall", "plaster_warm")), [0, 0, wt, WALL_ROWS])
	paint("floor_" + str(def.get("floor", "wood_warm")), [0, WALL_ROWS, wt, ht - WALL_ROWS])
	_continuous_floor()
	_decorate_walls(wt, ht)
	# collisions: walls + edges, with a door gap at the bottom centre
	var door_w := 32.0
	var cx := size_px.x / 2.0
	add_solid(Rect2(0, 0, size_px.x, WALL_ROWS * T + 4))
	add_solid(Rect2(-8, 0, 12, size_px.y))
	add_solid(Rect2(size_px.x - 4, 0, 12, size_px.y))
	add_solid(Rect2(0, size_px.y - 3, cx - door_w / 2.0, 12))
	add_solid(Rect2(cx + door_w / 2.0, size_px.y - 3, size_px.x, 12))
	add_prop({"sprite": "door_mat", "x": cx - 16, "y": size_px.y - 10, "floor": true})
	var mark := ExitMarker.new()
	mark.setup(Rect2(cx - 16, size_px.y - 10, 32, 9), Vector2.DOWN, I18n.t("EXIT"))
	back_layer.add_child(mark)
	var ex := InteriorExit.new()
	ex.setup(building_id, Rect2(cx - door_w / 2.0, size_px.y - 2, door_w, 10))
	add_child(ex)
	spawns["door"] = Vector2(cx, size_px.y - 22)
	for p in def.get("props", []):
		if p["sprite"] == "company_sign":
			_add_company_sign(p)
			continue
		if p.has("night"):
			_light_spill(float(p["x"]), 52.0)
		add_prop(p)
	for it in def.get("interactables", []):
		var a: Array = it["at"]
		var params: Dictionary = it.get("params", {}).duplicate()
		params["id"] = it["id"]
		params["building"] = building_id
		add_interactable(Vector2(float(a[0]), float(a[1])), str(it["label"]), str(it["action"]), params, float(it.get("r", 22)))
	if def.has("stock_display"):
		stock_holder = Node2D.new()
		entities.add_child(stock_holder)
		refresh_stock()
		EventBus.po_arrived.connect(func(_x): refresh_stock())
		EventBus.order_packed.connect(func(_x): refresh_stock())
	update_lighting()
	refresh_named_npcs()
	_spawn_ambient()   # after the named NPCs and staff, so customers don't take their seats


## Large non-repeating floor image over the tile grid when one exists for this material.
func _continuous_floor() -> void:
	var path := "res://assets/interiors/floor_%s.png" % str(def.get("floor", "wood_warm"))
	if not ResourceLoader.exists(path):
		return
	var fs := Sprite2D.new()
	fs.texture = load(path)
	fs.centered = false
	fs.region_enabled = true
	fs.region_rect = Rect2(0, 0, size_px.x, size_px.y - WALL_ROWS * T)
	fs.position = Vector2(0, WALL_ROWS * T)
	back_layer.add_child(fs)
	back_layer.move_child(fs, 0)


func _decorate_walls(wt: int, ht: int) -> void:
	var W := wt * T
	var wall_kind: String = def.get("wall", "plaster_warm")
	# wainscot: lower wall panel with a trim line (not on brick / glass walls)
	if wall_kind in ["plaster_warm", "white_modern", "marble_wall", "navy_panel"]:
		var wc := Color8(150, 110, 76) if wall_kind == "plaster_warm" else (Color8(206, 200, 190) if wall_kind == "white_modern" else Color8(190, 180, 164))
		if wall_kind == "navy_panel":
			wc = Color8(30, 42, 68)
		var wain := ColorRect.new()
		wain.color = wc
		wain.position = Vector2(0, WALL_ROWS * T - 16)
		wain.size = Vector2(W, 14)
		back_layer.add_child(wain)
		for x in range(0, W, 24):
			var pl := ColorRect.new()
			pl.color = wc.darkened(0.12)
			pl.position = Vector2(x + 3, WALL_ROWS * T - 13)
			pl.size = Vector2(18, 9)
			back_layer.add_child(pl)
		var tr := ColorRect.new()
		tr.color = wc.lightened(0.25)
		tr.position = Vector2(0, WALL_ROWS * T - 17)
		tr.size = Vector2(W, 1)
		back_layer.add_child(tr)
	# crown moulding
	var crown := ColorRect.new()
	crown.color = Color(1, 1, 1, 0.18)
	crown.position = Vector2(0, 2)
	crown.size = Vector2(W, 1)
	back_layer.add_child(crown)
	# floor ambient occlusion along the wall base
	var g := Gradient.new()
	g.set_color(0, Color(0.05, 0.06, 0.1, 0.32))
	g.set_color(1, Color(0.05, 0.06, 0.1, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 4
	gt.height = 14
	gt.fill_to = Vector2(0, 1)
	var ao := Sprite2D.new()
	ao.texture = gt
	ao.centered = false
	ao.position = Vector2(0, WALL_ROWS * T)
	ao.scale = Vector2(W / 4.0, 1)
	back_layer.add_child(ao)
	# baseboard + side frame so the room reads as a diorama
	var base := ColorRect.new()
	base.color = Color8(60, 48, 40) if def.get("floor", "") in ["wood_warm", "wood_dark", "wood_cafe"] else Color8(90, 96, 110)
	base.position = Vector2(0, WALL_ROWS * T - 2)
	base.size = Vector2(wt * T, 2)
	back_layer.add_child(base)
	var trim := ColorRect.new()
	trim.color = Color(1, 1, 1, 0.12)
	trim.position = Vector2(0, 0)
	trim.size = Vector2(wt * T, 1)
	back_layer.add_child(trim)
	for side in [0, 1]:
		var fr := ColorRect.new()
		fr.color = Color8(22, 30, 46)
		fr.position = Vector2(-4 if side == 0 else wt * T, 0)
		fr.size = Vector2(4, ht * T + 4)
		add_child(fr)
	var bottom := ColorRect.new()
	bottom.color = Color8(22, 30, 46)
	bottom.position = Vector2(-4, ht * T)
	bottom.size = Vector2(wt * T / 2.0 - 16 + 4, 4)
	add_child(bottom)
	var bottom2 := ColorRect.new()
	bottom2.color = Color8(22, 30, 46)
	bottom2.position = Vector2(wt * T / 2.0 + 16, ht * T)
	bottom2.size = Vector2(wt * T / 2.0 - 16 + 4, 4)
	add_child(bottom2)


func _light_spill(x: float, w: float) -> void:
	var poly := Polygon2D.new()
	var y0 := float(WALL_ROWS * T)
	var beam := PackedVector2Array([Vector2(x + 4, y0), Vector2(x + w - 4, y0), Vector2(x + w + 22, y0 + 46), Vector2(x + 18, y0 + 46)])
	# a beam from a window near the right wall must not spill past the room's edge
	var room := PackedVector2Array([Vector2(0, y0), Vector2(size_px.x, y0), Vector2(size_px.x, size_px.y), Vector2(0, size_px.y)])
	var clipped := Geometry2D.intersect_polygons(beam, room)
	if clipped.is_empty():
		return
	poly.polygon = clipped[0]
	poly.color = Color(1.0, 0.96, 0.84, 0.13)
	back_layer.add_child(poly)
	light_nodes.append({"node": poly, "interior": true, "day_only": true})


func _add_company_sign(p: Dictionary) -> void:
	var panel := Panel.new()
	panel.add_theme_stylebox_override("panel", UIK.flat(Color8(34, 44, 66), Color8(226, 180, 82), 1))
	panel.position = Vector2(float(p["x"]), float(p["y"]))
	panel.size = Vector2(96, 28)
	back_layer.add_child(panel)
	company_sign = UIK.world_label("", 7, Color8(250, 236, 200))
	company_sign.position = Vector2(2, 3)
	company_sign.size = Vector2(92, 22)
	company_sign.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(company_sign)
	refresh_company_sign()
	EventBus.world_refresh.connect(refresh_company_sign)


## Employees at work in this room (offices with `staff_spots`, and only while the lease is yours).
func refresh_named_npcs() -> void:
	super.refresh_named_npcs()
	var spots: Dictionary = def.get("staff_spots", {})
	if spots.is_empty():
		return
	var want := {}
	if Living.has_lease(str(def.get("property", ""))):
		var used := {"packer": 0, "desk": 0}
		for p in Staff.people():
			if not Staff.is_working(p):
				continue
			var kind := "packer" if p["role"] == "packer" and spots.has("packer") else "desk"
			var list: Array = spots.get(kind, [])
			if int(used[kind]) >= list.size():
				continue
			var at: Array = list[int(used[kind])]
			used[kind] = int(used[kind]) + 1
			# the packer should use "interact"; its side-view art still shows the bare torso (wiki 90, R3 fixes)
			want[p["id"]] = {"p": p, "pos": Vector2(float(at[0]), float(at[1])), "face": "left" if kind == "packer" else "up",
				"pose": "idle" if kind == "packer" else "sit"}
			if kind == "desk":
				var seat := seat_near(want[p["id"]]["pos"], 24.0)
				if seat.is_empty() or _seat_claimed(seat["pos"], want):
					want[p["id"]]["pose"] = "idle"   # more staff than office chairs: they work standing, never sit on air
				else:
					want[p["id"]]["pos"] = seat["pos"]
					want[p["id"]]["face"] = seat["dir"]
	for sid in staff_nodes.keys():
		if not want.has(sid):
			if is_instance_valid(staff_nodes[sid]):
				staff_nodes[sid].leave()
			staff_nodes.erase(sid)
	for sid in want:
		if staff_nodes.has(sid):
			continue
		var n := StaffNPC.new()
		n.setup(want[sid]["p"], want[sid]["face"], want[sid]["pose"])
		n.position = want[sid]["pos"]
		entities.add_child(n)
		staff_nodes[sid] = n


func refresh_company_sign() -> void:
	if company_sign == null or not is_instance_valid(company_sign):
		return
	var prop: String = def.get("property", "")
	if GameState.company_id() != "" and Living.has_lease(prop):
		company_sign.text = GameState.entity_name(GameState.company_id()).to_upper()
	else:
		company_sign.text = "SUITE 2B\nAVAILABLE"


func refresh_stock() -> void:
	if stock_holder == null or not is_instance_valid(stock_holder):
		return
	for c in stock_holder.get_children():
		c.queue_free()
	var sd: Dictionary = def["stock_display"]
	var units := Ecommerce.total_units_at(str(sd["location"]))
	var boxes := mini(20, int(ceil(units / 10.0)))
	var cols := int(sd.get("cols", 5))
	var tex := Art.tex("interiors/box")
	for i in boxes:
		var col := i % cols
		var layer := int(i / cols)
		var s := Sprite2D.new()
		s.texture = tex
		s.centered = false
		s.position = Vector2(float(sd["x"]) + col * 12 - layer * 2, float(sd["y"]) - layer * 9 + (col % 2) * 2)
		s.z_index = layer
		stock_holder.add_child(s)
	stock_holder.position = Vector2.ZERO


func _spawn_ambient() -> void:
	var n := 0
	match str(bdef.get("type", "")):
		"cafe":
			n = 3
		"coworking":
			n = 5
		"bank":
			n = 2
		"civic":
			n = 3
		"parcel":
			n = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(scene_id) + Clock.day_index() * 31 + Clock.hour()
	if Clock.hour() < 8 or Clock.hour() >= 21:
		n = mini(n, 1)
	var free: Array = seats().filter(func(s): return not s["staff"] and not _seat_taken(s["pos"]))
	# deterministic shuffle so a revisit in the same hour shows the same customers
	for i in range(free.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = free[i]
		free[i] = free[j]
		free[j] = tmp
	for i in mini(n, free.size()):
		var a := AmbientPerson.new()
		a.setup(rng, str(free[i]["dir"]))
		a.position = free[i]["pos"]
		entities.add_child(a)
		ambient.append(a)


## Where people sit: every chair, stool, bench and sofa, as {pos, dir}. `pos` is the sitter's feet, centred on the
## seat and just in front of it so they draw over the furniture; chairs face the nearest table or desk, benches
## and sofas face the room.
func seats() -> Array:
	var tables: Array = []
	for p in def.get("props", []):
		var s := str(p["sprite"])
		if not p.get("wall", false) and (s.contains("table") or s.contains("desk") or s.contains("counter")):
			tables.append(_prop_rect(p))
	var out: Array = []
	for p in def.get("props", []):
		var s := str(p["sprite"])
		if p.get("wall", false) or not (s.contains("chair") or s.contains("bench") or s.contains("sofa") or s == "stool"):
			continue
		var r := _prop_rect(p)
		var face := "down"
		var staff := false
		if not (s.contains("sofa") or s.contains("bench")):
			face = _face_toward_nearest(r, tables)
			staff = face == "down"   # a chair behind a desk, facing the room: the banker's, not a customer's
		out.append({"pos": Vector2(roundf(r.get_center().x), r.end.y + 1.0), "dir": face, "sprite": s, "staff": staff})
	return out


## Nearest seat within `radius` of `at`, or {} (named NPCs and staff with a sitting pose snap onto it).
func seat_near(at: Vector2, radius: float) -> Dictionary:
	var best := {}
	var bd := radius
	for s in seats():
		var d: float = (s["pos"] as Vector2).distance_to(at)
		if d <= bd:
			bd = d
			best = s
	return best


func _seat_claimed(pos: Vector2, want: Dictionary) -> bool:
	for w in want.values():
		if w.get("pose", "") == "sit" and (w["pos"] as Vector2).distance_to(pos) < 1.0:
			return true
	return false


func _seat_taken(pos: Vector2) -> bool:
	for n in named_npcs.values() + staff_nodes.values():
		if is_instance_valid(n) and (n as Node2D).position.distance_to(pos) < 6.0:
			return true
	return false


## A prop's footprint in room pixels (sprite_meta overhang excluded), matching add_prop's placement.
func _prop_rect(p: Dictionary) -> Rect2:
	var key := "interiors/" + str(p["sprite"])
	var tex := Art.tex(key)
	var sm: Dictionary = DataDB.sprite_meta.get(key, {})
	var w := float(sm.get("dw", tex.get_width() if tex != null else 16))
	var h := float((tex.get_height() if tex != null else 16) - int(sm.get("top", 0)))
	return Rect2(float(p["x"]), float(p["y"]), w, h)


func _face_toward_nearest(r: Rect2, tables: Array) -> String:
	var c := r.get_center()
	var best: Rect2
	var bd := 64.0
	for t in tables:
		var d := (t as Rect2).get_center().distance_to(c)
		if d < bd:
			bd = d
			best = t
	if bd >= 64.0:
		return "down"
	var v := best.get_center() - c
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0 else "left"
	return "down" if v.y > 0 else "up"


func npc_spot(spot: String) -> Vector2:
	var s: Array = def.get("npc_spots", {}).get(spot, [size_px.x / 2.0, size_px.y / 2.0])
	return Vector2(float(s[0]), float(s[1]))


func minimap_shapes() -> Array:
	return [{"rect": Rect2(0, 0, size_px.x, WALL_ROWS * T), "color": Color8(80, 90, 110)},
		{"rect": Rect2(0, WALL_ROWS * T, size_px.x, size_px.y - WALL_ROWS * T), "color": Color8(150, 130, 110)}]
