class_name Car
extends Node2D
## Ambient traffic: drives along a lane, brakes for people in front, loops around the district.

const TYPES := ["sedan", "sedan", "compact", "compact", "taxi", "van", "bus"]
const COLORS := [Color8(236, 238, 242), Color8(60, 64, 76), Color8(200, 72, 64), Color8(70, 110, 180), Color8(160, 168, 180),
	Color8(40, 44, 54), Color8(230, 200, 120), Color8(90, 140, 110)]

var lane_y := 0.0
var dir := 1
var speed := 70.0
var cur_speed := 70.0
var scene: Node
var body: Sprite2D
var detail: Sprite2D
var head: Sprite2D
var length := 64.0
var _rng: RandomNumberGenerator


func setup(s: Node, y: float, d: int, rng: RandomNumberGenerator) -> void:
	scene = s
	lane_y = y
	dir = d
	_rng = rng
	position.y = y
	_pick_look()


func _pick_look() -> void:
	for c in get_children():
		c.queue_free()
	var choices: Array = scene.def.get("traffic_types", TYPES)
	if choices.is_empty(): choices = TYPES
	var t: String = choices[_rng.randi_range(0, choices.size() - 1)]
	body = Sprite2D.new()
	body.texture = Art.tex("vehicles/%s_side_body" % t)
	detail = Sprite2D.new()
	detail.texture = Art.tex("vehicles/%s_side_detail" % t)
	for s in [body, detail]:
		s.centered = false
		var key := "vehicles/%s_side_%s" % [t, "body" if s == body else "detail"]
		Art.fit_world_sprite(s, key, Vector2(-s.texture.get_width() / 2.0, -s.texture.get_height()))
		s.flip_h = dir < 0
		add_child(s)
	match t:
		"taxi":
			body.modulate = Color8(240, 196, 70)
		"bus":
			body.modulate = Color8(236, 240, 246)
		"van":
			body.modulate = [Color8(236, 238, 242), Color8(224, 132, 64)][_rng.randi_range(0, 1)]
		_:
			body.modulate = COLORS[_rng.randi_range(0, COLORS.size() - 1)]
	length = float(body.texture.get_width()) * body.scale.x
	speed = _rng.randf_range(55.0, 85.0) * (0.8 if t == "bus" else 1.0)
	cur_speed = speed
	head = Sprite2D.new()
	head.texture = Art.tex("effects/glow_small")
	head.position = Vector2(dir * length / 2.0, -10)
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	head.material = mat
	add_child(head)


func _blocked(player: Node2D) -> bool:
	var front := position.x + dir * length / 2.0
	if player != null:
		var pp: Vector2 = player.global_position
		if absf(pp.y - lane_y) < 16 and (pp.x - front) * dir > -4 and (pp.x - front) * dir < 34:
			return true
	for c in get_tree().get_nodes_in_group("cars"):
		if c != self and c.lane_y == lane_y:
			var gap: float = (c.position.x - position.x) * dir
			if gap > 0 and gap < (length + c.length) / 2.0 + 14:
				return true
	return false


func _ready() -> void:
	add_to_group("cars")


func _process(delta: float) -> void:
	if Clock.is_paused() and UIRoot.is_blocking():
		return
	var player: Node2D = null
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty(): player = players[0]
	# The lane test is cheap and decides whether any crosswalk or contact logic can matter at all.
	var in_lane := player != null and absf(player.global_position.y - lane_y) < maxf(float(TrafficSafety.cfg()["green_lane_margin_px"]), float(TrafficSafety.cfg()["contact_half_height_px"]))
	var protected := false
	if in_lane:
		var pp: Vector2 = player.global_position
		if absf(pp.y - lane_y) < float(TrafficSafety.cfg()["green_lane_margin_px"]) and TrafficSafety.protected_crossing(scene.scene_id, pp):
			var gap: float = (pp.x - position.x) * dir
			if gap > -length / 2.0 and gap < length / 2.0 + cur_speed * cur_speed / (2.0 * float(TrafficSafety.cfg()["brake_px_s2"])) + float(TrafficSafety.cfg()["green_stop_padding_px"]): protected = true
	var previous_center := position.x
	var impact_speed := cur_speed
	var target := 0.0 if protected or _blocked(player) else speed
	cur_speed = move_toward(cur_speed, target, float(TrafficSafety.cfg()["brake_px_s2"]) * delta)
	if protected: cur_speed = 0.0
	position.x += dir * cur_speed * delta
	var current_center := position.x
	if in_lane:
		var margin := float(TrafficSafety.cfg()["contact_margin_px"])
		var pp: Vector2 = player.global_position
		if absf(pp.y - lane_y) < float(TrafficSafety.cfg()["contact_half_height_px"]) and pp.x >= minf(previous_center, current_center) - length / 2.0 - margin and pp.x <= maxf(previous_center, current_center) + length / 2.0 + margin and impact_speed > 0:
			var result := TrafficSafety.hit(impact_speed, scene.scene_id, pp)
			if result["ok"]:
				cur_speed = 0.0
				UIRoot.open_modal.call_deferred(TrafficModal.new("accident"))
	var w: float = scene.size_px.x
	if dir > 0 and position.x > w + 80:
		position.x = -80 - _rng.randf() * 200
		_pick_look()
	elif dir < 0 and position.x < -80:
		position.x = w + 80 + _rng.randf() * 200
		_pick_look()
	if head:
		head.modulate.a = Clock.night_factor() * 0.9
