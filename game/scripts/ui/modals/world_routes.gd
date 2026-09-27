class_name WorldRoutes
extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var s := 400.0 / 640.0
	var a: Array = DataDB.regions["aurelia"]["map_pos"]
	var home := Vector2(float(a[0]), float(a[1])) * s
	for rid in DataDB.regions:
		if rid == "aurelia":
			continue
		var p: Array = DataDB.regions[rid]["map_pos"]
		var q := Vector2(float(p[0]), float(p[1])) * s
		var mid := (home + q) / 2.0 + Vector2(0, -18)
		var prev := home
		for i in range(1, 21):
			var t := i / 20.0
			var pt := home.lerp(mid, t).lerp(mid.lerp(q, t), t)
			if i % 2 == 0:
				draw_line(prev, pt, Color(1, 1, 1, 0.55), 1.0)
			prev = pt
	draw_circle(home, 4, Art.C_GOLD)
