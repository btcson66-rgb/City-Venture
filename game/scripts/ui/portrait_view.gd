class_name PortraitView
extends Control
## 64×64 layered portrait with expression frames (neutral, happy, thinking, surprised).

const EXPR := {"neutral": 0, "happy": 1, "thinking": 2, "surprised": 3}

var _rects: Array = []
var _layers: Array = []
var expr := "neutral"
var icon_mode := ""


func setup_character(app: Dictionary, outfit: String, tints := {}, npc_id := "") -> void:
	icon_mode = ""
	_clear()
	_layers = Art.portrait_layers(app, outfit, tints, npc_id)
	for L in _layers:
		var r := TextureRect.new()
		r.set_anchors_preset(Control.PRESET_FULL_RECT)
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		r.modulate = L["tint"]
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		_rects.append(r)
	set_expr(expr)


## Icon avatar for contacts without a face. A company logo (logos/<logo>.png, 32x32) wins when it exists.
func setup_icon(name: String, logo := "") -> void:
	_clear()
	icon_mode = name
	var bg := ColorRect.new()
	bg.color = Art.C_NAVY_600
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_rects.append(bg)
	var r := TextureRect.new()
	var lt := Art.opt_tex("logos/" + logo) if logo != "" else null
	r.texture = lt if lt != null else Art.icon(name)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var m := 6 if lt != null else 12
	r.offset_left = m
	r.offset_top = m
	r.offset_right = -m
	r.offset_bottom = -m
	add_child(r)
	_rects.append(r)


func _clear() -> void:
	for r in _rects:
		r.queue_free()
	_rects.clear()
	_layers.clear()


func set_expr(e: String) -> void:
	expr = e
	var f: int = EXPR.get(e, 0)
	for i in _layers.size():
		var L: Dictionary = _layers[i]
		var t := Art.tex(L["tex"])
		if t == null:
			continue
		if int(L["frames"]) > 1:
			var at := AtlasTexture.new()
			at.atlas = t
			at.region = Rect2(f * 64, 0, 64, 64)
			_rects[i].texture = at
		else:
			_rects[i].texture = t
