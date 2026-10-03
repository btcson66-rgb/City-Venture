class_name CharacterRig
extends Node2D
## Layered 32x48 character (body, face, hair, outfit, accessory). Origin = feet.
## Sheet layout: 4 frames × 3 rows (down, side, up). Left = side flipped.
## Poses: every layer may have a `<layer>_<pose>.png` sheet in the same layout. A pose is shown only when every
## layer of this character has one, so half-finished pose art never mixes with walk frames.

const FRAME_W := 32
const FRAME_H := 48
const FEET := Vector2(16, 46)
const ROWS := {"down": 0, "side": 1, "up": 2}
## frames used per pose and their speed; "carry" replaces the walk cycle, the others are for standing still.
## tools/qa/pose_check.py checks every frame listed here for gaps, loose pieces and uncovered torsos.
const POSES := {"sit": [2, 1.5], "idle": [2, 1.2], "phone": [2, 1.0], "interact": [2, 4.0], "carry": [4, 8.0]}

var dir := "down"
var walking := false
var anim_speed := 8.0
var pose := ""
var _t := 0.0
var _frame := 0
var _layers: Array[Sprite2D] = []
var _shadow: Sprite2D
var _group: CanvasGroup
static var _outline_mat: ShaderMaterial
var appearance: Dictionary = {}
var outfit := "startup_casual"
var expression := "neutral"


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


func setup(app: Dictionary, outfit_id: String, tints := {}, npc_id := "") -> void:
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
	for L in Art.character_layers(app, outfit_id, tints, npc_id):
		var s := Sprite2D.new()
		s.texture = Art.tex(L["tex"])
		s.set_meta("tex", L["tex"])
		s.hframes = 4
		s.vframes = 3
		s.centered = false
		_fit_sheet(s)
		s.modulate = L["tint"]
		s.name = L["name"]
		_group.add_child(s)
		_layers.append(s)
	var want := pose
	pose = ""
	set_pose(want)
	_apply()


## True when every layer has `<layer>_<p>` art.
func has_pose(p: String) -> bool:
	if p == "" or _layers.is_empty():
		return p == ""
	for s in _layers:
		if not Art.has_tex(str(s.get_meta("tex")) + "_" + p):
			return false
	return true


## Switch to a pose ("" = plain walk sheets). Returns false, and keeps the walk sheets, when the art isn't there.
func set_pose(p: String) -> bool:
	if p != "" and not POSES.has(p):
		return false
	var ok := has_pose(p)
	var target := p if ok else ""
	if target == pose:
		return ok
	pose = target
	for s in _layers:
		var base := str(s.get_meta("tex"))
		s.texture = Art.tex(base + "_" + pose if pose != "" else base)
		_fit_sheet(s)
	_frame = 0
	_t = 0.0
	_apply()
	return ok


func _fit_sheet(s: Sprite2D) -> void:
	# High-detail atlases keep the same logical feet anchor and walk footprint.
	if s.texture == null:   # a missing layer is already warned about by Art; draw the rest
		return
	var cell := s.texture.get_size() / Vector2(4, 3)
	s.scale = Vector2(FRAME_W, FRAME_H) / cell
	s.offset = -FEET / s.scale


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
	if w and pose != "" and pose != "carry":
		set_pose("")   # standing poses end when the character moves off
	if w != walking:
		walking = w
		if not w:
			_frame = 0
			_t = 0.0
		_apply()


func _process(delta: float) -> void:
	var frames := 4
	var speed := anim_speed
	if pose != "":
		frames = int(POSES[pose][0])
		speed = float(POSES[pose][1])
	elif not walking:
		return
	if pose == "carry" and not walking:
		return
	_t += delta * speed
	var f := int(_t) % frames
	if f != _frame:
		_frame = f
		_apply()


func _apply() -> void:
	var row: int = ROWS["side"] if dir in ["left", "right"] else ROWS.get(dir, 0)
	var idx := row * 4 + _frame
	for s in _layers:
		var base := str(s.get_meta("tex"))
		if s.name in ["eyes", "eyes_detail", "iris", "brows", "mouth"] and Art.has_tex(base + "_expressions"):
			var expression_key := base + "_expressions" + ("_" + pose if pose != "" else "")
			var face_texture := Art.tex(expression_key)
			if s.texture != face_texture:
				s.texture = face_texture
				_fit_sheet(s)
			var face_frame: int = {"neutral": 0, "happy": 1, "thinking": 2, "surprised": 3}.get(expression, 0)
			s.frame = row * 4 + face_frame
			# Facial expression frames are independent of the body's walk/breathing frames.
			s.position.y = ([0.0, -0.45, 0.0, -0.45][_frame] if pose in ["", "carry"] else 0.0 if pose == "sit" else [0.0, -0.18, 0.0, -0.18][_frame])
		elif s.name == "npc_detail" and pose != "" and Art.has_tex(base + "_" + pose + "_expressions"):
			# Optional pose-expression art uses four columns, independent of the two-frame breathing loop.
			s.texture = Art.tex(base + "_" + pose + "_expressions")
			_fit_sheet(s)
			var face_frame: int = {"neutral": 0, "happy": 1, "thinking": 2, "surprised": 3}.get(expression, 0)
			s.frame = row * 4 + face_frame
		elif s.name == "npc_detail" and pose == "":
			var face_frame: int = {"neutral": 0, "happy": 1, "thinking": 2, "surprised": 3}.get(expression, 0)
			s.frame = row * 4 + face_frame
		else:
			s.frame = idx
		s.flip_h = dir == "left"


func set_expression(value: String) -> void:
	expression = value
	_apply()


static func dir_from_vector(v: Vector2, fallback := "down") -> String:
	if v.length() < 0.01:
		return fallback
	if absf(v.x) > absf(v.y) * 1.05:
		return "right" if v.x > 0 else "left"
	return "down" if v.y > 0 else "up"
