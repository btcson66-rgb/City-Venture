class_name MetroLines
extends Control
## Draws metro lines and station markers from data/city/aurelia.json over the city map.

var scale_f := 1.0
var here := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _pos(id: String) -> Vector2:
	var d := DataDB.district_def_in_city(id)
	var p: Array = d.get("map_pos", [0, 0])
	return Vector2(float(p[0]), float(p[1])) * scale_f


func _draw() -> void:
	for ln in DataDB.city["metro"]["lines"]:
		var col := Color(ln["color"])
		var st: Array = ln["stations"]
		for i in st.size() - 1:
			draw_line(_pos(st[i]), _pos(st[i + 1]), col, 2.0)
	for d in DataDB.city["districts"]:
		var p := _pos(d["id"])
		var active: bool = d["status"] == "active"
		draw_circle(p, 3.5 if active else 2.5, Color.WHITE if active else Color(0.6, 0.65, 0.75))
		draw_circle(p, 2.0 if active else 1.5, Art.C_NAVY_700)
		if d["id"] == here:
			draw_arc(p, 6.0, 0, TAU, 16, Art.C_GOLD, 1.5)
