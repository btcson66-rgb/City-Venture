class_name CharacterRig
extends Node2D
## Layered 32x48 character (body, face, hair, outfit, accessory). Origin = feet.
## Sheet layout: 4 frames × 3 rows (down, side, up). Left = side flipped.

const FRAME_W := 32
const FRAME_H := 48
const FEET := Vector2(16, 46)
const ROWS := {"down": 0, "side": 1, "up": 2}

var dir := "down"
var walking := false
var anim_speed := 8.0
var _t := 0.0
var _frame := 0
var _layers: Array[Sprite2D] = []
var _shadow: Sprite2D
var _group: CanvasGroup
static var _outline_mat: ShaderMaterial
var appearance: Dictionary = {}
var outfit := "startup_casual"


func _ready() -> void:
	if _shadow == null:
		_make_shadow()
	if _group != null:
		_outline_material()


func _make_shadow() -> void:
	_shadow = Sprite2D.new()
	_shadow.texture = Art.tex("effects/shadow")
	_shadow.position = Vector2(0, -1)
	_shadow.modulate = Color(1, 1, 1, 0.9)
	_shadow.z_index = -1
	add_child(_shadow)
	move_child(_shadow, 0)


func setup(app: Dictionary, outfit_id: String, tints := {}) -> void:
	appearance = app
	outfit = outfit_id
	for l in _layers:
		l.queue_free()
	_layers.clear()
	if _shadow == null:
		_make_shadow()
	if _group == null:
		# layers render into one group so the outline hugs the whole silhouette, not each layer
		_group = CanvasGroup.new()
		_group.name = "Body"
		_group.fit_margin = 3.0
		_group.clear_margin = 3.0
		_group.material = _outline_material()
		add_child(_group)
	for L in Art.character_layers(app, outfit_id, tints):
		var s := Sprite2D.new()
		s.texture = Art.tex(L["tex"])
		s.hframes = 4
		s.vframes = 3
		s.centered = false
		s.offset = -FEET
		s.modulate = L["tint"]
		s.name = L["name"]
		_group.add_child(s)
		_layers.append(s)
	_apply()


func _outline_material() -> ShaderMaterial:
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = load("res://shaders/char_outline.gdshader")
	if is_inside_tree():
		var sc := get_viewport().get_final_transform().get_scale().x
		_outline_mat.set_shader_parameter("px_scale", maxf(1.0, roundf(sc)))
	return _outline_mat


func set_dir(d: String) -> void:
	if d != dir:
		dir = d
		_apply()


func set_walking(w: bool) -> void:
	if w != walking:
		walking = w
		if not w:
			_frame = 0
			_t = 0.0
		_apply()


func _process(delta: float) -> void:
	if walking:
		_t += delta * anim_speed
		var f := int(_t) % 4
		if f != _frame:
			_frame = f
			_apply()


func _apply() -> void:
	var row: int = ROWS["side"] if dir in ["left", "right"] else ROWS.get(dir, 0)
	var idx := row * 4 + _frame
	for s in _layers:
		s.frame = idx
		s.flip_h = dir == "left"


static func dir_from_vector(v: Vector2, fallback := "down") -> String:
	if v.length() < 0.01:
		return fallback
	if absf(v.x) > absf(v.y) * 1.05:
		return "right" if v.x > 0 else "left"
	return "down" if v.y > 0 else "up"
