class_name ExitArea
extends Area2D
## District edge: walking out travels to the neighbouring district (costs walking time).

var def: Dictionary = {}


func setup(d: Dictionary, scene: Node) -> void:
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
	# visible "way out" sign on the road at this edge
	var ws := scene as WorldScene
	var side := str(d.get("direction", "E" if ws == null or float(r[0]) > ws.size_px.x / 2.0 else "W"))
	var directions := {"N": Vector2.UP, "E": Vector2.RIGHT, "S": Vector2.DOWN, "W": Vector2.LEFT}
	var dname := I18n.t(str(DataDB.districts.get(d["to"], {}).get("name", d["to"])))
	var mark := ExitMarker.new()
	mark.name = "ExitSign_" + str(d["to"])
	mark.setup(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])), directions[side], dname)
	# Parallel north/south paths keep separate signs; stagger their boards instead of overlapping long names.
	if ws != null and side in ["N", "S"]:
		var peers: Array = ws.def.get("exits", []).filter(func(e): return e.get("direction", "") == side)
		var index := peers.find(d)
		var shift := Vector2(0, index * (32.0 if side == "N" else -84.0))
		mark.board.position += shift
		mark._label.position += shift
	add_child(mark)


func _on_enter(body: Node) -> void:
	if body is Player and not SceneRouter.transitioning:
		SceneRouter.walk_to_district(def["to"], def["spawn"], int(def.get("walk_min", 10)))
