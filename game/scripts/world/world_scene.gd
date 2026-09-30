class_name WorldScene
extends Node2D
## Shared builder for districts and interiors: tiles, props, collisions, interactables,
## navigation grid (used by NPCs and the walkthrough bot), day/night and NPC spawning.

const T := 16
const NAV_CELL := 8

static var _tileset: TileSet
static var _tile_index := {}

var kind := ""          # "district" | "interior"
var scene_id := ""
var size_px := Vector2i.ZERO
var ground: TileMapLayer
var back_layer: Node2D   # wall decor, floor decals (not y-sorted)
var entities: Node2D     # y-sorted world
var fx_layer: Node2D
var canvas_mod: CanvasModulate
var player: Player
var nav: AStarGrid2D
var spawns := {}
var solids: Array = []   # Rect2 list for nav
var night_sprites: Array = []   # [{node, day_tex, night_tex}]
var light_nodes: Array = []     # additive light sprites (alpha by night)
var named_npcs := {}
var poi: Array = []      # minimap points {pos, icon, label}
var timed_props: Array = []   # [{node, body, show}] props that are only out at certain times (market stalls)
var _npc_refresh_acc := 0.0


static func tileset() -> TileSet:
	if _tileset != null:
		return _tileset
	var ts := TileSet.new()
	ts.tile_size = Vector2i(T, T)
	var src := TileSetAtlasSource.new()
	src.texture = Art.tex("tiles/atlas")
	src.texture_region_size = Vector2i(T, T)
	var tiles: Dictionary = DataDB.tiles.get("tiles", {})
	for n in tiles:
		var c := Vector2i(int(tiles[n][0]), int(tiles[n][1]))
		src.create_tile(c)
		_tile_index[n] = c
	ts.add_source(src, 0)
	_tileset = ts
	return ts


func _init_layers() -> void:
	y_sort_enabled = false
	ground = TileMapLayer.new()
	ground.tile_set = tileset()
	ground.name = "Ground"
	add_child(ground)
	back_layer = Node2D.new()
	back_layer.name = "Back"
	add_child(back_layer)
	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)
	fx_layer = Node2D.new()
	fx_layer.name = "FX"
	add_child(fx_layer)
	canvas_mod = CanvasModulate.new()
	add_child(canvas_mod)


## True when the ground atlas has this tile (new tiles are added to the atlas as they are drawn).
func has_tile(tile: String) -> bool:
	if _tile_index.is_empty():
		tileset()
	return _tile_index.has(tile)


func paint(tile: String, rect: Array, step := 1) -> void:
	if not _tile_index.has(tile):
		tileset()
	var c: Vector2i = _tile_index.get(tile, Vector2i(0, 0))
	for y in range(int(rect[1]), int(rect[1]) + int(rect[3])):
		for x in range(int(rect[0]), int(rect[0]) + int(rect[2]), maxi(1, step)):
			ground.set_cell(Vector2i(x, y), 0, c)


func init_nav() -> void:
	nav = AStarGrid2D.new()
	nav.region = Rect2i(0, 0, int(ceil(size_px.x / float(NAV_CELL))), int(ceil(size_px.y / float(NAV_CELL))))
	nav.cell_size = Vector2(NAV_CELL, NAV_CELL)
	nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	nav.update()


func add_solid(r: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 2
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = r.size
	cs.shape = shape
	cs.position = r.position + r.size / 2.0
	body.add_child(cs)
	add_child(body)
	solids.append(r)
	if nav != null:
		# inflate by the player's half-width so paths keep clearance
		var g := r.grow_individual(6, 4, 6, 3)
		for cy in range(int(floor(g.position.y / NAV_CELL)), int(ceil(g.end.y / NAV_CELL))):
			for cx in range(int(floor(g.position.x / NAV_CELL)), int(ceil(g.end.x / NAV_CELL))):
				if nav.is_in_boundsv(Vector2i(cx, cy)):
					nav.set_point_solid(Vector2i(cx, cy), true)
	return body


func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if nav == null:
		return PackedVector2Array([to])
	var a := _nearest_free(Vector2i(int(from.x / NAV_CELL), int(from.y / NAV_CELL)))
	var b := _nearest_free(Vector2i(int(to.x / NAV_CELL), int(to.y / NAV_CELL)))
	var pts := nav.get_point_path(a, b)
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + Vector2(NAV_CELL / 2.0, NAV_CELL / 2.0))
	return out


func _nearest_free(c: Vector2i) -> Vector2i:
	if nav.is_in_boundsv(c) and not nav.is_point_solid(c):
		return c
	for r in range(1, 12):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var n := c + Vector2i(dx, dy)
				if nav.is_in_boundsv(n) and not nav.is_point_solid(n):
					return n
	return c


## Texture key a prop draws with: its `sprite` in this scene's folder (interiors/ or props/), else in props/, else its
## `fallback` sprite. Lets data name furniture that is still being drawn and show a stand-in until the file lands.
## "" when none exists.
func prop_key(p: Dictionary) -> String:
	var folder := "interiors/" if kind == "interior" else "props/"
	for sp in [str(p["sprite"]), str(p.get("fallback", ""))]:
		if sp == "":
			continue
		for key in [folder + sp, "props/" + sp]:
			if Art.has_tex(key):
				return key
	return ""


## Place a sprite prop whose data position is its top-left. Returns the y-sorted holder.
## Optional keys: `if` (a Cond string: the prop is only placed when it holds), `show` ({days, from, to}: out only then,
## e.g. weekend market stalls), `overhead` (drawn above people, no collision: string lights), `fallback` (stand-in
## sprite while `sprite` has no art), `unless_art` (skip once that texture exists: a stand-in detail the real art
## draws itself), `glow`, `night`, `label`, `interact`, `solid`, `tint`. A `<sprite>_lights.png` next to the sprite
## glows at night like building windows.
func add_prop(p: Dictionary, parent: Node = null) -> Node2D:
	if p.has("if") and not Cond.all([str(p["if"])]):
		return null
	if p.has("unless_art") and Art.has_tex(str(p["unless_art"])):
		return null
	var sprite_path: String = p["sprite"]
	var folder := "interiors/" if kind == "interior" else "props/"
	var key := prop_key(p)
	if key == "":
		return null
	var tex := Art.tex(key)
	var holder := Node2D.new()
	var s := Sprite2D.new()
	s.texture = tex
	# Keep placement, sorting and collision in design pixels; only the artwork
	# gains resolution. canvas_items stretching preserves this detail on screen.
	var detailed := Art.opt_tex("world_detail/" + key)
	if detailed != null:
		s.texture = detailed
		s.scale = Vector2(tex.get_size()) / Vector2(detailed.get_size())
	s.centered = false
	if p.has("tint"):
		s.modulate = Color(str(p["tint"]))   # greyscale props dyed per placement (Threadline's mannequins)
	# board-converted art may overhang its design footprint (top/left); placement uses the footprint
	var sm: Dictionary = DataDB.sprite_meta.get(key, {})
	var top := int(sm.get("top", 0))
	var left := int(sm.get("left", 0))
	var h := tex.get_height() - top
	var w := int(sm.get("dw", tex.get_width()))
	var wall: bool = p.get("wall", false)
	var floor_decal: bool = p.get("floor", false)
	var overhead: bool = p.get("overhead", false)
	if wall or floor_decal or overhead:
		holder.position = Vector2(float(p["x"]), float(p["y"]))
		s.offset = Vector2(-left, -top)
		holder.add_child(s)
		(parent if parent != null else (fx_layer if overhead else back_layer)).add_child(holder)
	else:
		holder.position = Vector2(float(p["x"]), float(p["y"]) + h)
		s.offset = Vector2(-left, -h - top)
		if kind == "interior":
			var sh := Sprite2D.new()
			sh.texture = Art.tex("effects/shadow")
			sh.scale = Vector2(maxf(0.5, w / 22.0), 1.2)
			sh.position = Vector2(w / 2.0, -1)
			sh.modulate = Color(1, 1, 1, 0.8)
			holder.add_child(sh)
		holder.add_child(s)
		(parent if parent != null else entities).add_child(holder)
	# Sprite offsets are texture pixels, unlike the logical holder position.
	s.offset /= s.scale
	if p.has("night"):
		var night_tex := Art.tex(folder + str(p["night"]))
		if detailed != null:
			var detailed_night := Art.opt_tex("world_detail/" + folder + str(p["night"]))
			if detailed_night != null:
				night_tex = detailed_night
			else:
				# A partial day/night pair must retain its original geometry.
				s.texture = tex
				s.offset *= s.scale
				s.scale = Vector2.ONE
		night_sprites.append({"node": s, "day": s.texture, "night": night_tex})
	if detailed != null and s.texture == detailed and wall and sprite_path.begins_with("window_"):
		# Taller glazing extends into the raised back wall; partial pairs fall back.
		s.scale.y *= 1.38
		s.position.y -= 16
	if Art.has_tex(key + "_lights"):
		var lt := Sprite2D.new()
		lt.texture = Art.tex(key + "_lights")
		lt.centered = false
		lt.offset = s.offset * s.scale   # the lights sheet is in design pixels, like the holder
		var lmat := CanvasItemMaterial.new()
		lmat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		lt.material = lmat
		holder.add_child(lt)
		light_nodes.append({"node": lt, "interior": false})
	if p.get("glow", false):
		var g := Sprite2D.new()
		g.texture = Art.tex("effects/glow_small" if kind == "interior" else "effects/glow_warm")
		if sm.has("glow"):
			g.position = Vector2(float(sm["glow"][0]), float(sm["glow"][1]) - (float(h) if not (wall or floor_decal) else 0.0))
		else:
			var lamp := sprite_path.contains("lamp")   # street lamps (lamp, old_lamp, harbor_lamp) glow at the head
			g.position = Vector2(w / 2.0 + (5.0 if sprite_path.begins_with("lamp") else 0.0), (8.0 if lamp else float(h) - 4.0) - (float(h) if not (wall or floor_decal) else 0.0))
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		g.material = mat
		holder.add_child(g)
		light_nodes.append({"node": g, "interior": kind == "interior"})
	# collision (default: bottom band of the sprite)
	var solid = p.get("solid", null)
	var body: StaticBody2D = null
	if not wall and not floor_decal and not overhead and not (typeof(solid) == TYPE_BOOL and solid == false):
		var r: Rect2
		if typeof(solid) == TYPE_ARRAY:
			r = Rect2(float(p["x"]) + float(solid[0]), float(p["y"]) + float(solid[1]), float(solid[2]), float(solid[3]))
		else:
			# the bottom band of the sprite, only as wide as what is drawn there (a tree's trunk, a plant's pot),
			# so the player doesn't bump into empty air beside a prop
			var band := int(clampf(h * 0.35, 4.0, 10.0))
			var fp := _footprint(key, tex, left, w, band)
			var inset := 1.0 if fp.y - fp.x > 6.0 else 0.0
			r = Rect2(float(p["x"]) + fp.x + inset, float(p["y"]) + h - band, maxf(3.0, fp.y - fp.x - 2.0 * inset), band)
		body = add_solid(r)
	if p.has("show"):
		timed_props.append({"node": holder, "body": body, "show": p["show"]})
		_apply_timed(timed_props[-1])
	if p.has("label"):
		var lb := UIK.world_label(str(p["label"]), 5)
		lb.position = Vector2(2, -h + 3)
		lb.size = Vector2(w - 4, 8)
		holder.add_child(lb)
	if p.has("interact"):
		var it: Dictionary = p["interact"]
		add_interactable(Vector2(float(p["x"]) + w / 2.0, float(p["y"]) + h + 6), str(it["label"]), str(it["action"]), it.get("params", {}), 26.0)
	return holder


static var _foot_cache := {}


## Where a sprite's bottom `band` rows are actually drawn, as [x0, x1) in footprint coordinates (0..w).
func _footprint(key: String, tex: Texture2D, left: int, w: int, band: int) -> Vector2:
	var ck := "%s|%d" % [key, band]
	if _foot_cache.has(ck):
		return _foot_cache[ck]
	var out := Vector2(0, w)
	var img := tex.get_image() if tex != null else null
	if img != null:
		if img.is_compressed():
			img.decompress()
		var x0 := w
		var x1 := -1
		for y in range(maxi(0, img.get_height() - band), img.get_height()):
			for x in range(maxi(0, left), mini(img.get_width(), left + w)):
				if img.get_pixel(x, y).a > 0.5:
					x0 = mini(x0, x - left)
					x1 = maxi(x1, x - left)
		if x1 >= x0:
			out = Vector2(x0, x1 + 1)
	_foot_cache[ck] = out
	return out


func add_interactable(pos: Vector2, label: String, action: String, params := {}, radius := 22.0) -> Interactable:
	var it := Interactable.new()
	it.position = pos
	it.label = label
	it.action = action
	it.params = params
	it.radius = radius
	it.name = "I_" + action
	add_child(it)
	return it


func spawn_player(pos: Vector2, facing := "down") -> void:
	player = Player.new()
	player.position = pos
	entities.add_child(player)
	player.face(facing)


func update_lighting() -> void:
	var nf := Clock.night_factor()
	if kind == "interior":
		canvas_mod.color = Color(1, 1, 1).lerp(Color(0.86, 0.8, 0.8), nf)
	else:
		var dusk := Color(1.0, 0.84, 0.74)
		var night := Color(0.4, 0.46, 0.72)
		if nf < 0.5:
			canvas_mod.color = Color(1, 1, 1).lerp(dusk, nf * 2.0)
		else:
			canvas_mod.color = dusk.lerp(night, (nf - 0.5) * 2.0)
	var inv := Color(1.0 / maxf(0.3, canvas_mod.color.r), 1.0 / maxf(0.3, canvas_mod.color.g), 1.0 / maxf(0.3, canvas_mod.color.b))
	for l in light_nodes:
		var n: CanvasItem = l["node"]
		if not is_instance_valid(n):
			continue
		if l.get("day_only", false):
			n.modulate = Color(1, 1, 1, 1.0 - nf)
			continue
		var a := 0.55 if l["interior"] else clampf(nf * 1.3, 0.0, 1.0)
		# warm the additive light so windows read amber, not pink-white
		n.modulate = Color(inv.r, inv.g * 0.9, inv.b * 0.62, a)
	var night := nf > 0.55
	for ns in night_sprites:
		var s: Sprite2D = ns["node"]
		if is_instance_valid(s) and ns["night"] != null:
			s.texture = ns["night"] if night else ns["day"]


func _process(delta: float) -> void:
	update_lighting()
	_npc_refresh_acc += delta
	if _npc_refresh_acc > 1.0:
		_npc_refresh_acc = 0.0
		refresh_named_npcs()
		for tp in timed_props:
			_apply_timed(tp)


## True when now falls in a {days: "all" | "sat,sun" | ..., from: "HH:MM", to: "HH:MM"} window.
static func in_window(w: Dictionary) -> bool:
	var days := str(w.get("days", "all"))
	var wd: String = Clock.WEEKDAYS[Clock.weekday()].to_lower()
	if days != "all" and not wd in days.split(","):
		return false
	var m := Clock.minute_of_day()
	return m >= Clock.parse_hm(str(w.get("from", "00:00"))) and m < Clock.parse_hm(str(w.get("to", "24:00")))


## Stalls are packed away outside their hours: hidden and walk-through (NPC paths still keep clear of the spot).
func _apply_timed(tp: Dictionary) -> void:
	var on := in_window(tp["show"])
	var n: Node2D = tp["node"]
	if is_instance_valid(n) and n.visible != on:
		n.visible = on
	var b: StaticBody2D = tp["body"]
	if b != null and is_instance_valid(b):
		b.collision_layer = 2 if on else 0


## Named NPCs present here right now according to their schedules.
func npcs_scheduled_here() -> Dictionary:
	var out := {}
	var t := Clock.now()
	var wd: String = Clock.WEEKDAYS[Clock.weekday()].to_lower()
	var m := Clock.minute_of_day()
	for nid in DataDB.npcs:
		var n: Dictionary = DataDB.npcs[nid]
		for s in n.get("schedule", []):
			if str(s.get("location", "")) != "%s:%s" % [kind, scene_id]:
				continue
			var days: String = str(s.get("days", "all"))
			if days != "all" and not wd in days.split(","):
				continue
			if s.has("if") and not Cond.all([str(s["if"])]):
				continue
			if m >= Clock.parse_hm(s["from"]) and m < Clock.parse_hm(s["to"]):
				out[nid] = s
	var _u := t
	return out


func npc_spot(spot: String) -> Vector2:
	return Vector2.ZERO


func refresh_named_npcs() -> void:
	var want := npcs_scheduled_here()
	for nid in named_npcs.keys():
		if not want.has(nid):
			var node: Node = named_npcs[nid]
			if is_instance_valid(node):
				node.leave()
			named_npcs.erase(nid)
	for nid in want:
		if named_npcs.has(nid):
			continue
		var pos := npc_spot(str(want[nid].get("spot", "")))
		var npc := NamedNPC.new()
		npc.setup(nid, self)
		npc.position = pos
		# schedule `pose`: "sit" on sofas and tables, else "idle" behind counters (shown once the pose art exists)
		var pose := str(want[nid].get("pose", "idle"))
		if pose == "sit" and has_method("seat_near"):
			var seat: Dictionary = call("seat_near", pos, 48.0)
			if not seat.is_empty():
				npc.position = seat["pos"]
				npc.rig.set_dir(str(seat["dir"]))
		npc.rig.set_pose(pose)
		entities.add_child(npc)
		named_npcs[nid] = npc


## Minimap content: [{rect, color}] + POIs. Overridden per scene type.
func minimap_shapes() -> Array:
	return []
