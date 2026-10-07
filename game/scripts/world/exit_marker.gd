class_name ExitMarker
extends Node2D
## Fixed, bounded direction board. Text and vector arrow have separate slots.
var rect := Rect2()
var dir := Vector2.DOWN
var text := ""
var _label: Label
var board := Rect2()
func setup(r: Rect2, d: Vector2, t: String) -> void:
	rect = r
	dir = d
	text = t
	z_index = 5
	var center := rect.get_center()
	if dir == Vector2.RIGHT:
		board = Rect2(rect.position.x - 128, rect.position.y - 30, 120, 22)
	elif dir == Vector2.LEFT:
		board = Rect2(rect.end.x + 8, rect.position.y - 30, 120, 22)
	elif dir == Vector2.UP:
		board = Rect2(center.x - 30, rect.end.y + 20, 60, 22)
	else:
		board = Rect2(center.x - 30, rect.position.y - 28, 60, 22)
	_label = UIK.world_label(t, 6, Art.C_WHITE)
	_label.add_theme_font_override("font", UIK.bold_font())
	_label.add_theme_constant_override("outline_size", 0)
	_label.custom_minimum_size = Vector2.ZERO
	_label.clip_text = true
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.tooltip_text = t
	board.size.y = 28
	_label.size = Vector2(board.size.x - 28, 24)
	_label.position = board.position + Vector2(5 if dir == Vector2.RIGHT else 23, 2)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
func _draw() -> void:
	draw_rect(board, Color(0.035, 0.08, 0.14, 0.96))
	draw_rect(board, Color(0.36, 0.57, 0.72), false, 0.7)
	var center := board.position + Vector2(108 if dir == Vector2.RIGHT else 11, 14)
	var angle := dir.angle()
	var points := PackedVector2Array()
	for p in [Vector2(-6,-2), Vector2(1,-2), Vector2(1,-5), Vector2(6,0), Vector2(1,5), Vector2(1,2), Vector2(-6,2)]:
		points.append(center + p.rotated(angle))
	draw_colored_polygon(points, Art.C_WHITE)
