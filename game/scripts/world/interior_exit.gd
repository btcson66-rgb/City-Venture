class_name InteriorExit
extends Area2D
## Door mat at the bottom of an interior: walking onto it goes back outside.

var building_id := ""


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


func _on_enter(body: Node) -> void:
	if body is Player and not SceneRouter.transitioning:
		SceneRouter.exit_building(building_id)
