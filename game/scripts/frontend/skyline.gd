class_name Skyline
extends Control
## Animated dusk/night skyline backdrop built from the building facades (menu + arrival).

var t := 0.0
var cars: Array = []
var night := 0.75
var ground_y := 300.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var grad := Gradient.new()
	grad.set_color(0, Color8(24, 30, 72))
	grad.add_point(0.55, Color8(92, 70, 128))
	grad.set_color(1, Color8(238, 150, 110))
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 128
	var sky := TextureRect.new()
	sky.texture = gt
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	sky.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sky.stretch_mode = TextureRect.STRETCH_SCALE
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var stars := Control.new()
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stars)
	for i in 40:
		var s := ColorRect.new()
		s.color = Color(1, 1, 1, rng.randf_range(0.3, 0.9))
		s.size = Vector2(1, 1)
		s.position = Vector2(rng.randf_range(0, 640), rng.randf_range(0, 150))
		stars.add_child(s)
	# far row (darker, smaller) then near row
	_row(["finance_tower", "glass_tower", "office_slab", "glass_tower", "finance_tower", "office_slab", "glass_tower"], 0.5, ground_y - 36, Color(0.35, 0.38, 0.6), rng)
	_row(["riverside_tower", "bloom_block", "nexus_cowork", "glass_tower", "horizon_labs", "nexus_bank", "apartment_mid", "office_slab"], 0.75, ground_y, Color(0.55, 0.58, 0.8), rng)
	var road := ColorRect.new()
	road.color = Color8(30, 34, 50)
	road.position = Vector2(0, ground_y)
	road.size = Vector2(640, 360 - ground_y)
	add_child(road)
	var lane := ColorRect.new()
	lane.color = Color8(200, 180, 120, 120)
	lane.position = Vector2(0, ground_y + 22)
	lane.size = Vector2(640, 1)
	add_child(lane)
	for i in 5:
		var c := TextureRect.new()
		c.texture = Art.tex("vehicles/sedan_side_body" if i % 2 == 0 else "vehicles/compact_side_body")
		c.modulate = [Color8(230, 230, 236), Color8(200, 72, 64), Color8(70, 110, 180), Color8(240, 196, 70), Color8(60, 64, 76)][i] * Color(0.7, 0.72, 0.9)
		c.position = Vector2(i * 150 + rng.randf_range(0, 60), ground_y + (4 if i % 2 == 0 else 26))
		c.flip_h = i % 2 == 1
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var d := TextureRect.new()
		d.texture = Art.tex("vehicles/sedan_side_detail" if i % 2 == 0 else "vehicles/compact_side_detail")
		d.flip_h = c.flip_h
		c.add_child(d)
		add_child(c)
		cars.append(c)


func _row(ids: Array, sc: float, base: float, tint: Color, rng: RandomNumberGenerator) -> void:
	var x := -20.0
	while x < 660:
		var id: String = ids[rng.randi_range(0, ids.size() - 1)]
		var tex := Art.tex("buildings/" + id)
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.size = Vector2(tex.get_width(), tex.get_height()) * sc
		r.position = Vector2(x, base - r.size.y)
		r.modulate = tint
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		var l := TextureRect.new()
		l.texture = Art.tex("buildings/" + id + "_lights")
		l.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		l.stretch_mode = TextureRect.STRETCH_SCALE
		l.size = r.size
		l.position = r.position
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		l.material = mat
		l.modulate = Color(1, 1, 1, night)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(l)
		x += r.size.x + rng.randf_range(-4, 6)


func _process(delta: float) -> void:
	t += delta
	for i in cars.size():
		var c: TextureRect = cars[i]
		c.position.x += (30.0 if not c.flip_h else -26.0) * delta
		if c.position.x > 680:
			c.position.x = -80
		elif c.position.x < -90:
			c.position.x = 670
