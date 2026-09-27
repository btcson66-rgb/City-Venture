class_name ExitMarker
extends Node2D
## Always-visible way-out sign: a pulsing outline on the exit spot, chevrons pointing the way out and a
## label ("EXIT" on a room's door mat, "Startup Hub →" at a street's edge). New players could not tell
## that walking onto the mat leaves a room; this makes every exit read at a glance.

var rect := Rect2()
var dir := Vector2.DOWN
var text := ""
var _t := 0.0
var _label: Label


func setup(r: Rect2, d: Vector2, t: String) -> void:
	rect = r
	dir = d
	text = t
	z_index = 5
	_label = UIK.world_label(t, 6, Color(1.0, 0.86, 0.42))
	_label.add_theme_font_override("font", UIK.bold_font())
	_label.add_theme_constant_override("outline_size", 3)
	var w := 90.0
	_label.size = Vector2(w, 9)
	var c := rect.get_center()
	if dir == Vector2.DOWN:
		_label.position = Vector2(c.x - w / 2.0, rect.position.y - 16)
	elif dir == Vector2.RIGHT:
		_label.position = Vector2(rect.position.x - w - 4, c.y - 34)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	else:
		_label.position = Vector2(rect.end.x + 4, c.y - 34)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	add_child(_label)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(_t * 3.5)
	var gold := Color(1.0, 0.82, 0.3)
	if dir == Vector2.DOWN:
		draw_rect(rect.grow(1), Color(gold, 0.18 + 0.2 * pulse), true)
		draw_rect(rect.grow(1), Color(gold, 0.55 + 0.35 * pulse), false, 1.0)
		var c := rect.get_center()
		for i in 2:
			var y := rect.position.y - 7.0 + i * 3.0 + 2.0 * pulse
			draw_polyline(PackedVector2Array([Vector2(c.x - 4, y), Vector2(c.x, y + 3), Vector2(c.x + 4, y)]), Color(gold, 0.6 + 0.4 * pulse), 1.0)
		return
	# street edge: a column of chevrons on the road, pointing off the map
	var cx := rect.position.x - 10.0 if dir == Vector2.RIGHT else rect.end.x + 10.0
	var cy := rect.get_center().y
	for row in [-1, 0, 1]:
		var y0: float = cy + row * 26.0
		for i in 3:
			var ph := fmod(_t * 1.6 + i * 0.33, 1.0)
			var x := cx + dir.x * (i * 5.0 + 3.0 * pulse)
			var a := 0.25 + 0.6 * (1.0 - absf(ph - 0.5) * 2.0)
			draw_polyline(PackedVector2Array([Vector2(x - dir.x * 3, y0 - 5), Vector2(x + dir.x * 2, y0), Vector2(x - dir.x * 3, y0 + 5)]), Color(gold, a), 1.5)
