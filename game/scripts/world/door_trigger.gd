class_name DoorTrigger
extends Area2D
## Walking into a building's front door enters its interior (if open).

var building_id := ""
var _cool := 0.0
var _hint: PanelContainer
var _hint_label: Label
var _center := Vector2.ZERO


func setup(bid: String, r: Rect2) -> void:
	building_id = bid
	collision_layer = 0
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	cs.position = r.position + r.size / 2.0
	add_child(cs)
	body_entered.connect(_on_enter)
	# "walk in to enter" chip that appears when the player comes close to the door
	_center = r.get_center()
	_hint = UIK.name_tag("")
	_hint.z_index = 20
	_hint_label = _hint.get_child(0) as Label
	_hint.modulate.a = 0.0
	add_child(_hint)


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	var near := pl != null and pl.global_position.distance_to(global_position + _center) < 44.0 and BuildingInfo.building_available(building_id)
	if near:
		var st := SceneRouter.building_open(building_id)
		_hint_label.text = "▲ " + BuildingInfo.door_text(building_id)
		_hint_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.42) if st["open"] else Color(1.0, 0.55, 0.5))
		_hint.reset_size()
		_hint.position = _center + Vector2(-_hint.size.x / 2.0, -46)
	_hint.modulate.a = move_toward(_hint.modulate.a, 1.0 if near else 0.0, delta * 5.0)


func _on_enter(body: Node) -> void:
	if not BuildingInfo.building_available(building_id):
		return
	if not body is Player or _cool > 0.0 or SceneRouter.transitioning:
		return
	var p := body as Player
	if p.velocity.y > 1.0:
		return
	_cool = 1.2
	SceneRouter.enter_building(building_id)
