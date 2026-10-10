class_name ExitMarker
extends Node2D
## One quiet roadside direction sign; arrow and translated name share bounded slots.
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
	var width := clampf(UIK.bold_font().get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 30, 64, 136)
	if dir == Vector2.RIGHT:
		board = Rect2(rect.position.x - width - 12, rect.position.y + 8, width, 28)
	elif dir == Vector2.LEFT:
		board = Rect2(rect.end.x + 12, rect.position.y + 8, width, 28)
	elif dir == Vector2.UP:
		board = Rect2(center.x - width / 2, rect.position.y - 32, width, 28)
	else:
		board = Rect2(center.x - width / 2, rect.position.y + 16 if rect.size.y == 16 else rect.position.y - 36, width, 28)
	_label = UIK.world_label(t, 8, Color8(53, 68, 69))
	_label.add_theme_font_override("font", UIK.bold_font())
	_label.add_theme_constant_override("outline_size", 0)
	_label.custom_minimum_size = Vector2.ZERO
	_label.clip_text = true
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_label.tooltip_text = t
	_label.size = Vector2(board.size.x - 28, 26)
	_label.position = board.position + Vector2(5, 1)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
func _draw() -> void:
	var post := board.get_center().x
	draw_line(Vector2(post, board.end.y), Vector2(post, board.end.y + 14), Color8(100, 109, 103), 2)
	draw_rect(board, Color8(219, 224, 202))
	draw_rect(board, Color8(111, 130, 111), false, 0.7)
	var center := board.position + Vector2(board.size.x - 12, 14)
	var points := PackedVector2Array()
	for p in [Vector2(-5,-2),Vector2(1,-2),Vector2(1,-4),Vector2(5,0),Vector2(1,4),Vector2(1,2),Vector2(-5,2)]:
		points.append(center + p.rotated(dir.angle()))
	draw_colored_polygon(points, Color8(53, 68, 69))
