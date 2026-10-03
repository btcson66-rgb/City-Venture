class_name CompanyVan
extends Node2D
## The same layered side view in the yard and route screen. Only body is tinted.

const BOARD := Rect2(7, 8, 34, 10)


## Pure sizing rule; measured width at 8px scales linearly. Overflow at 5px is clipped.
static func name_font_size(width_at_eight: float, board_width: float) -> int:
	for px in range(8, 4, -1):
		if maxf(0.0, width_at_eight) * px / 8.0 <= maxf(0.0, board_width):
			return px
	return 5


func _ready() -> void:
	EventBus.world_refresh.connect(queue_redraw)


func _draw() -> void:
	if not Logistics.has_van():
		return
	var body_key := "vehicles/van_player_side_body" if Art.has_tex("vehicles/van_player_side_body") else "vehicles/van_side_body"
	var detail_key := "vehicles/van_player_side_detail" if Art.has_tex("vehicles/van_player_side_detail") else "vehicles/van_side_detail"
	var body := Art.opt_tex(body_key)
	var detail := Art.opt_tex(detail_key)
	if body != null:
		draw_texture_rect(body, Rect2(0, 0, 72, 36), false, Logistics.body_color())
	if detail != null:
		draw_texture_rect(detail, Rect2(0, 0, 72, 36), false)
	var company := GameState.entity_name(Logistics.entity())
	var font := UIK.bold_font()
	var px := name_font_size(font.get_string_size(company, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, BOARD.size.x)
	# A pathological name still fits its painted board; actual text remains in Company OS.
	while company.length() > 1 and font.get_string_size(company, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x > BOARD.size.x:
		company = company.left(company.length() - 2) + "…"
	var width := font.get_string_size(company, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	draw_string(font, BOARD.position + Vector2((BOARD.size.x - width) / 2.0, (BOARD.size.y + px) / 2.0 - 1), company, HORIZONTAL_ALIGNMENT_LEFT, BOARD.size.x, px, Color8(27, 37, 48))
