class_name RouteGame
extends MiniGame
## Plan a delivery run: a top-down map of Aurelia with the depot at Pier 7 and 4–6 numbered stops. Click the stops in the
## order you want to drive them; the route is drawn as you go and closes back at the depot. Score = the best possible
## route divided by yours (found by trying every order), so a perfect plan scores 100%. The result carries the order,
## the kilometres, the time on the road and the fuel used; Logistics.drive() pays the run from it.
## Map art: minigames/route_map (580×236, no text) when it exists, otherwise a plain map with the river, bridges and roads.

const ROUTE_COLOR := Color8(226, 180, 82)

var job: Dictionary = {}
var stops: Array = []            # place ids, in the order the client's manifest lists them
var order: Array = []            # indices into `stops`, in the order the player picked them
var best := {}                   # {order, px}: the shortest round trip
var stats := {}                  # Logistics.route_stats of the finished route
var view: RouteView
var stop_btns: Array = []
var undo_btn: Button
var clear_btn: Button
var drive_btn: Button


func _init(j := {}) -> void:
	super._init()
	job = j.duplicate(true)
	if job.is_empty() or (job.get("stops", []) as Array).is_empty():
		job = {"id": "R0", "client": "Local client", "stops": ["lantern_books", "threadline", "city_hall", "nexus_bank", "bloom_coffee"], "by": 0}
	stops = job["stops"]
	best = Logistics.best_order(stops)
	title_text = "Plan the route"
	icon_name = "map"
	help_key = "route_game"
	rounds = 1
	round_time = 0.0


func intro_lines() -> Array:
	return ["The van leaves the depot at Pier 7, calls at every stop once and comes back. Click the stops in the order you want to drive them.",
		"The river can only be crossed at a bridge. Undo takes the last stop back; the route is drawn as you go.",
		"Your score is the shortest possible route divided by yours. A shorter route means less fuel, less time on the road and a little more pay."]


func _update_status() -> void:
	if status == null or not is_instance_valid(status):
		return
	var pts := Logistics.route_points(stops, order)
	var px := 0.0
	for i in range(1, pts.size()):
		px += (pts[i - 1] as Vector2).distance_to(pts[i])
	if order.size() < stops.size():
		status.text = I18n.t("Stops planned %d / %d  ·  route so far %.1f km") % [order.size(), stops.size(), Logistics.to_km(px)]
	else:
		status.text = I18n.t("All %d stops planned  ·  round trip %.1f km") % [stops.size(), Logistics.to_km(Logistics.route_px(stops, order))]


func build_round() -> void:
	order = []
	stop_btns = []
	UIK.clear(stage)
	view = RouteView.new()
	view.game = self
	view.custom_minimum_size = Logistics.map_size()
	view.size = Logistics.map_size()
	stage.add_child(view)
	for i in stops.size():
		var p := Logistics.place_pos(str(stops[i]))
		var b := Button.new()
		b.name = "Stop_%d" % (i + 1)
		b.flat = true
		b.focus_mode = Control.FOCUS_NONE
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, StyleBoxEmpty.new())   # the marker is drawn by the map (number and colour follow the plan)
		b.custom_minimum_size = Vector2(20, 20)
		b.size = Vector2(20, 20)
		b.position = p - Vector2(10, 10)
		b.tooltip_text = Logistics.place_name(str(stops[i]))
		b.pressed.connect(_pick.bind(i))
		b.mouse_entered.connect(view.queue_redraw)
		b.mouse_exited.connect(view.queue_redraw)
		view.add_child(b)
		stop_btns.append(b)
	undo_btn = UIK.button("Undo", _undo)
	undo_btn.name = "Undo"
	footer.add_child(undo_btn)
	clear_btn = UIK.button("Clear", _clear)
	clear_btn.name = "ClearRoute"
	footer.add_child(clear_btn)
	drive_btn = UIK.button("Drive the route", _drive, "primary", 130)
	drive_btn.name = "DriveRoute"
	footer.add_child(drive_btn)
	_refresh()


func _pick(i: int) -> void:
	if phase != "play":
		return
	if order.has(i):
		if int(order[order.size() - 1]) == i:
			_undo()   # clicking the last stop again takes it back
		return
	order.append(i)
	_refresh()


func _undo() -> void:
	if phase != "play" or order.is_empty():
		return
	order.pop_back()
	_refresh()


func _clear() -> void:
	if phase != "play":
		return
	order = []
	_refresh()


func _refresh() -> void:
	if drive_btn != null:
		drive_btn.disabled = order.size() < stops.size()
	if undo_btn != null:
		undo_btn.disabled = order.is_empty()
	if clear_btn != null:
		clear_btn.disabled = order.is_empty()
	_update_status()
	if view != null:
		view.queue_redraw()


func _drive() -> void:
	if phase != "play" or order.size() < stops.size():
		return
	stats = Logistics.route_stats(stops, order)
	award(float(stats["score"]))
	next_round()


func score() -> float:
	return float(stats.get("score", 0.0)) if not stats.is_empty() else super.score()


func verdict(s: float) -> String:
	if s >= 0.98:
		return "The shortest way there is. Textbook."
	if s >= 0.85:
		return "A tidy route. A stop or two out of order."
	if s >= 0.65:
		return "It works, but you drove some of it twice."
	return "You took the scenic route. The fuel gauge noticed."


func result_lines() -> Array:
	if stats.is_empty():
		return []
	var lines: Array = [I18n.t("Your route: %.1f km. The shortest possible: %.1f km.") % [float(stats["km"]), float(stats["best_km"])],
		I18n.t("Time on the road: %s") % Fmt.duration_min(int(stats["minutes"])),
		I18n.t("Fuel used: %.1f L (%s)") % [float(stats["fuel_l"]), Fmt.money0(float(stats["fuel_cost"]))]]
	if int(job.get("by", 0)) > 0:
		lines.append(I18n.t("Back at the depot around %s. Deadline: %s.") % [Clock.fmt_short(Clock.now() + int(stats["minutes"])), Clock.fmt_short(int(job["by"]))])
	return lines


func extra_result() -> Dictionary:
	return {"order": order.duplicate(), "km": stats.get("km", 0.0), "best_km": stats.get("best_km", 0.0), "minutes": stats.get("minutes", 0),
		"fuel_l": stats.get("fuel_l", 0.0), "fuel_cost": stats.get("fuel_cost", 0.0)}


## Test/bot hook: play a route whose score is as close as possible to `quality` (every order is tried).
func autoplay(quality := 0.9) -> void:
	var n := stops.size()
	var pick: Array = best["order"]
	var gap := INF
	for perm in _perms(n):
		var sc := float(best["px"]) / maxf(0.001, Logistics.route_px(stops, perm))
		if absf(sc - quality) < gap:
			gap = absf(sc - quality)
			pick = perm
	order = pick.duplicate()
	stats = Logistics.route_stats(stops, order)
	rounds = 1
	round_i = rounds
	points = float(stats["score"])
	_finish()


static func _perms(n: int) -> Array:
	if n <= 1:
		return [range(n)]
	var out: Array = []
	for rest in _perms(n - 1):
		for pos in range(n):
			var p: Array = (rest as Array).duplicate()
			p.insert(pos, n - 1)
			out.append(p)
	return out


func _unhandled_key_input(event: InputEvent) -> void:
	if phase != "play" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := int((event as InputEventKey).keycode)
	if k >= KEY_1 and k <= KEY_9 and k - KEY_1 < stops.size():
		get_viewport().set_input_as_handled()
		_pick(k - KEY_1)
	elif k == KEY_BACKSPACE:
		get_viewport().set_input_as_handled()
		_undo()


## The map: art if it exists, else land, districts, river, bridges and roads; then the route and the stop labels.
class RouteView:
	extends Control
	var game: RouteGame

	func _ready() -> void:
		clip_contents = true

	func _draw() -> void:
		var sz := size
		var art := Art.opt_tex("minigames/route_map")
		if art != null:
			draw_texture_rect(art, Rect2(Vector2.ZERO, sz), false)
		else:
			_plain_map(sz)
		_draw_route()
		_draw_marks()

	func _plain_map(sz: Vector2) -> void:
		draw_rect(Rect2(Vector2.ZERO, sz), Color8(52, 74, 70))
		for x in range(0, int(sz.x), 29):
			draw_line(Vector2(x, 0), Vector2(x, sz.y), Color(1, 1, 1, 0.05), 1.0)
		for y in range(0, int(sz.y), 29):
			draw_line(Vector2(0, y), Vector2(sz.x, y), Color(1, 1, 1, 0.05), 1.0)
		# districts as soft patches round their places
		var groups := {}
		for p in Logistics.places():
			var d := str(p["district"])
			groups[d] = (groups.get(d, []) as Array) + [Vector2(float(p["x"]), float(p["y"]))]
		for d in groups:
			var pts: Array = groups[d]
			var c := Vector2.ZERO
			for pt in pts:
				c += pt
			c /= pts.size()
			var col := Color(str(DataDB.district_def_in_city(str(d)).get("board", {}).get("accent", "#8a93a6")))
			draw_circle(c, 44.0, Color(col.r, col.g, col.b, 0.16))
		# water: the bay at the depot's coast and the river running down to it
		var water := Color8(58, 112, 176)
		draw_colored_polygon(PackedVector2Array([Vector2(0, 208), Vector2(44, 214), Vector2(96, 226), Vector2(128, 236), Vector2(0, 236)]), water)
		var river := PackedVector2Array(Logistics.river())
		if river.size() >= 2:
			draw_polyline(river, water, 15.0)
			draw_polyline(river, Color8(86, 142, 204), 7.0)
		# roads: a spanning network over the depot and every place (so the whole city is connected), plus each place's two
		# nearest neighbours; a road across the river goes over a bridge
		var nodes: Array = [Logistics.depot()]
		for p in Logistics.places():
			nodes.append(Vector2(float(p["x"]), float(p["y"])))
		var edges: Array = []
		for i in nodes.size():
			for j in range(i + 1, nodes.size()):
				edges.append([Logistics.leg_px(nodes[i], nodes[j]), i, j])
		edges.sort_custom(func(a, b): return a[0] < b[0])
		var group: Array = range(nodes.size())
		var roads := {}
		for e in edges:
			var ga: int = group[int(e[1])]
			var gb: int = group[int(e[2])]
			if ga != gb:
				roads["%d-%d" % [int(e[1]), int(e[2])]] = true
				for k in group.size():
					if group[k] == gb:
						group[k] = ga
		for i in nodes.size():
			var near: Array = edges.filter(func(e): return int(e[1]) == i or int(e[2]) == i)
			for k in mini(2, near.size()):
				roads["%d-%d" % [int(near[k][1]), int(near[k][2])]] = true
		for key in roads:
			var ij: PackedStringArray = (key as String).split("-")
			draw_polyline(PackedVector2Array(Logistics.leg(nodes[int(ij[0])], nodes[int(ij[1])])), Color8(104, 112, 130), 3.0)
		for br in Logistics.bridges():
			draw_rect(Rect2(br - Vector2(9, 4), Vector2(18, 8)), Color8(196, 200, 210))
			draw_rect(Rect2(br - Vector2(9, 4), Vector2(18, 8)), Color8(60, 66, 84), false, 1.0)

	func _draw_route() -> void:
		if game == null or game.order.is_empty():
			return
		var pts := Logistics.route_points(game.stops, game.order)
		if game.order.size() < game.stops.size():
			# only the part driven so far: drop the closing leg back to the depot
			var cur := Logistics.place_pos(str(game.stops[int(game.order[game.order.size() - 1])]))
			var back := Logistics.leg(cur, Logistics.depot()).size() - 1
			pts = pts.slice(0, pts.size() - back)
		draw_polyline(PackedVector2Array(pts), Color8(20, 26, 44), 5.0)
		draw_polyline(PackedVector2Array(pts), RouteGame.ROUTE_COLOR, 3.0)
		# little arrows on every leg
		for i in range(1, pts.size()):
			var a: Vector2 = pts[i - 1]
			var b: Vector2 = pts[i]
			if a.distance_to(b) < 30.0:
				continue
			var mid := a.lerp(b, 0.5)
			var dir := (b - a).normalized()
			var side := Vector2(-dir.y, dir.x)
			draw_colored_polygon(PackedVector2Array([mid + dir * 5.0, mid - dir * 3.0 + side * 4.0, mid - dir * 3.0 - side * 4.0]), Color8(20, 26, 44))

	func _draw_marks() -> void:
		if game == null:
			return
		var font := UIK.bold_font()
		# the depot
		var d := Logistics.depot()
		draw_rect(Rect2(d - Vector2(9, 9), Vector2(18, 18)), Color8(226, 180, 82))
		draw_rect(Rect2(d - Vector2(9, 9), Vector2(18, 18)), Color8(20, 26, 44), false, 1.0)
		draw_rect(Rect2(d - Vector2(5, 1), Vector2(10, 6)), Color8(20, 26, 44))
		draw_colored_polygon(PackedVector2Array([d + Vector2(-6, -1), d + Vector2(0, -6), d + Vector2(6, -1)]), Color8(20, 26, 44))
		_text(font, d + Vector2(13, 3), I18n.t(str(Logistics.map_cfg().get("depot", {}).get("name", "Depot"))), Art.C_GOLD)
		for i in game.stops.size():
			var p := Logistics.place_pos(str(game.stops[i]))
			var done := game.order.has(i)
			var hot: bool = game.stop_btns.size() > i and (game.stop_btns[i] as Button).is_hovered()
			draw_circle(p, 10.0, Color8(20, 26, 44))
			draw_circle(p, 9.0, Color8(250, 246, 226) if hot else (Color8(250, 246, 226) if done else Art.C_SKY))
			draw_circle(p, 7.5, RouteGame.ROUTE_COLOR if done else Color8(24, 38, 66))
			var num := str(i + 1)
			var nf := UIK.num_font()
			var nw := nf.get_string_size(num, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x
			draw_string(nf, p + Vector2(-nw / 2.0, 3.5), num, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color8(13, 27, 43) if done else Art.C_WHITE)
			var label := Logistics.place_name(str(game.stops[i]))
			var right := p.x < size.x - 120.0
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
			_text(font, p + Vector2(13 if right else -13 - w, 3), label, Art.C_WHITE)
			var at := game.order.find(i)
			if at >= 0:
				var c := p + Vector2(9, -9)
				draw_circle(c, 6.0, Color8(20, 26, 44))
				draw_circle(c, 5.0, Color8(111, 207, 128))
				draw_string(UIK.num_font(), c + Vector2(-2.5, 3.2), str(at + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color8(13, 27, 43))

	func _text(font: Font, at: Vector2, t: String, col: Color) -> void:
		draw_string_outline(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, 3, Color8(12, 18, 30))
		draw_string(font, at, t, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, col)
