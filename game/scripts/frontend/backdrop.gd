class_name Backdrop
extends Control
## Full-screen illustrated backdrop (converted from the concept boards) with a slow horizontal pan.

var tex_path := ""
var period := 70.0
var _img: TextureRect
var _t := 0.0


static func make(path: String, pan_period := 70.0) -> Backdrop:
	var b := Backdrop.new()
	b.tex_path = path
	b.period = pan_period
	return b


func _ready() -> void:
	position = Vector2.ZERO
	size = Vector2(640, 360)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_img = TextureRect.new()
	_img.texture = Art.tex(tex_path)
	_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_img)
	if period <= 0.0:
		_img.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		set_process(false)


func _process(delta: float) -> void:
	if _img.texture == null or period <= 0.0:
		return
	_t += delta
	var over := maxf(0.0, _img.texture.get_width() - 640.0)
	_img.position.x = -round(over * (0.5 - 0.5 * cos(TAU * _t / period)))
