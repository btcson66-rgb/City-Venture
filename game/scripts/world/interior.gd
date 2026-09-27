class_name Interior
extends WorldScene
## A walkable building interior built from data/buildings/<id>.json → "interior".

const WALL_ROWS := 3

var def: Dictionary = {}
var bdef: Dictionary = {}
var stock_holder: Node2D
var company_sign: Label
var ambient: Array = []


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
	var ex := InteriorExit.new()
	ex.setup(building_id, Rect2(cx - door_w / 2.0, size_px.y - 2, door_w, 10))
	add_child(ex)
	spawns["door"] = Vector2(cx, size_px.y - 22)
	for p in def.get("props", []):
		if p["sprite"] == "company_sign":
			_add_company_sign(p)
			continue
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
	_spawn_ambient()
	update_lighting()
	refresh_named_npcs()


func _decorate_walls(wt: int, ht: int) -> void:
	# baseboard + side frame so the room reads as a diorama
	var base := ColorRect.new()
	base.color = Color8(60, 48, 40) if def.get("floor", "") in ["wood_warm", "wood_dark"] else Color8(90, 96, 110)
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
	var seats: Array = []
	for p in def.get("props", []):
		if str(p["sprite"]).contains("chair") or str(p["sprite"]).contains("bench") or str(p["sprite"]).contains("sofa"):
			seats.append(Vector2(float(p["x"]) + 8, float(p["y"]) + 20))
	seats.shuffle()
	for i in mini(n, seats.size()):
		var a := AmbientPerson.new()
		a.setup(rng)
		a.position = seats[i]
		entities.add_child(a)
		ambient.append(a)


func npc_spot(spot: String) -> Vector2:
	var s: Array = def.get("npc_spots", {}).get(spot, [size_px.x / 2.0, size_px.y / 2.0])
	return Vector2(float(s[0]), float(s[1]))


func minimap_shapes() -> Array:
	return [{"rect": Rect2(0, 0, size_px.x, WALL_ROWS * T), "color": Color8(80, 90, 110)},
		{"rect": Rect2(0, WALL_ROWS * T, size_px.x, size_px.y - WALL_ROWS * T), "color": Color8(150, 130, 110)}]
