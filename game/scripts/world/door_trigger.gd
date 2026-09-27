class_name DoorTrigger
extends Area2D
## Walking into a building's front door enters its interior (if open).

var building_id := ""
var _cool := 0.0


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


func _process(delta: float) -> void:
	_cool = maxf(0.0, _cool - delta)


func _on_enter(body: Node) -> void:
	if not body is Player or _cool > 0.0 or SceneRouter.transitioning:
		return
	var p := body as Player
	if p.velocity.y > 1.0:
		return
	_cool = 1.2
	SceneRouter.enter_building(building_id)
