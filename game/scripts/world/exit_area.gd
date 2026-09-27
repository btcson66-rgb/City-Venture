class_name ExitArea
extends Area2D
## District edge: walking out travels to the neighbouring district (costs walking time).

var def: Dictionary = {}


func setup(d: Dictionary, _scene: Node) -> void:
	def = d
	collision_layer = 0
	collision_mask = 1
	var r: Array = d["rect"]
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2(float(r[2]), float(r[3]))
	cs.shape = sh
	cs.position = Vector2(float(r[0]) + float(r[2]) / 2.0, float(r[1]) + float(r[3]) / 2.0)
	add_child(cs)
	body_entered.connect(_on_enter)


func _on_enter(body: Node) -> void:
	if body is Player and not SceneRouter.transitioning:
		SceneRouter.walk_to_district(def["to"], def["spawn"], int(def.get("walk_min", 10)))
