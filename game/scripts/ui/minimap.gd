class_name Minimap
extends Control
## Minimal minimap (Board F): zoomed window around the player with points of interest.

const SCALE := 0.2


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true


func _process(_d: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color8(14, 24, 40))
	var ws := SceneRouter.world_scene()
	if ws == null or ws.player == null:
		return
	var center := ws.player.position
	var origin := center - size / (2.0 * SCALE)
	if ws.kind == "interior":
		var sc := minf(size.x / ws.size_px.x, size.y / ws.size_px.y) * 0.9
		var off := (size - Vector2(ws.size_px) * sc) / 2.0
		for s in ws.minimap_shapes():
			var r: Rect2 = s["rect"]
			draw_rect(Rect2(off + r.position * sc, r.size * sc), s["color"])
		for n in ws.named_npcs.values():
			if is_instance_valid(n):
				draw_circle(off + n.position * sc, 2.0, Art.C_GOLD)
		draw_circle(off + ws.player.position * sc, 2.5, Color.WHITE)
		return
	for s in ws.minimap_shapes():
		var r2: Rect2 = s["rect"]
		var rr := Rect2((r2.position - origin) * SCALE, r2.size * SCALE)
		if rr.intersects(Rect2(Vector2.ZERO, size)):
			draw_rect(rr, s["color"])
	if ws.kind == "district":
		for ex in ws.def.get("exits", []):
			var r: Array = ex["rect"]
			var edge := Vector2(float(r[0]) + float(r[2]) / 2, float(r[1]) + float(r[3]) / 2)
			var end := ((edge - origin) * SCALE).clamp(Vector2(4, 4), size - Vector2(4, 4))
			draw_line(size / 2, end, Color(0.8, 0.7, 0.25, 0.5), 1.0)
	for c in ws.get_tree().get_nodes_in_group("cars"):
		var p: Vector2 = (c.position - origin) * SCALE
		if Rect2(Vector2.ZERO, size).has_point(p):
			draw_rect(Rect2(p - Vector2(2, 1), Vector2(4, 2)), Color8(220, 220, 230))
	for poi in ws.poi:
		if poi.has("building") and not BuildingInfo.building_available(str(poi["building"])):
			continue
		var p2: Vector2 = (poi["pos"] - origin) * SCALE
		p2 = p2.clamp(Vector2(4, 4), size - Vector2(4, 4))
		var tex := Art.icon(str(poi["icon"]))
		if tex:
			if poi.has("direction"):
				draw_set_transform(p2, {"N": -PI / 2, "E": 0.0, "S": PI / 2, "W": PI}[str(poi["direction"])])
				draw_texture_rect(tex, Rect2(Vector2(-5, -5), Vector2(10, 10)), false)
				draw_set_transform(Vector2.ZERO)
			else:
				draw_texture_rect(tex, Rect2(p2 - Vector2(5, 5), Vector2(10, 10)), false)
	var pp := (center - origin) * SCALE
	draw_circle(pp, 3.0, Color8(12, 18, 30))
	draw_circle(pp, 2.2, Color.WHITE if int(Time.get_ticks_msec() / 400) % 2 == 0 else Art.C_SKY)
	draw_rect(Rect2(Vector2.ZERO, size), Art.C_NAVY_500, false, 1.0)
