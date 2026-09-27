class_name Player
extends CharacterBody2D
## Player avatar: 8-way movement with 4-way sprites, run, contextual interaction.

const WALK_SPEED := 64.0
const RUN_SPEED := 112.0

var rig: CharacterRig
var camera: Camera2D
var facing := "down"
var focus: Node = null  # current Interactable in reach
var input_enabled := true
var moving := false


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 2
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 5)
	shape.shape = rect
	shape.position = Vector2(0, -2)
	add_child(shape)
	rig = CharacterRig.new()
	add_child(rig)
	refresh_appearance()
	camera = Camera2D.new()
	camera.position = Vector2(0, -20)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	add_child(camera)
	camera.make_current()


func refresh_appearance() -> void:
	var p: Dictionary = GameState.data["player"]
	rig.setup(p["appearance"], p.get("outfit", "startup_casual"))
	rig.set_dir(facing)


func face(d: String) -> void:
	facing = d
	rig.set_dir(d)


func can_move() -> bool:
	return input_enabled and not UIRoot.is_blocking() and not SceneRouter.transitioning


func _physics_process(_delta: float) -> void:
	var v := Vector2.ZERO
	if can_move():
		v = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var speed := RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
	velocity = v.normalized() * speed if v.length() > 0.1 else Vector2.ZERO
	moving = velocity.length() > 0.1
	if moving:
		facing = CharacterRig.dir_from_vector(v, facing)
		rig.set_dir(facing)
		rig.anim_speed = 12.0 if speed > WALK_SPEED else 8.0
	rig.set_walking(moving)
	move_and_slide()
	_update_focus()


func _update_focus() -> void:
	var best: Node = null
	var best_d := 1e9
	if can_move():
		var probe := global_position + _facing_vec() * 6.0
		for n in get_tree().get_nodes_in_group("interactable"):
			if not n.is_inside_tree() or not n.enabled:
				continue
			var d: float = probe.distance_to(n.global_position)
			if d <= n.radius and d < best_d:
				best_d = d
				best = n
	if best != focus:
		focus = best
		UIRoot.set_prompt(focus.prompt_text() if focus != null else "")


func _facing_vec() -> Vector2:
	match facing:
		"up":
			return Vector2.UP
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
	return Vector2.DOWN


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and focus != null and can_move():
		get_viewport().set_input_as_handled()
		rig.set_walking(false)
		var target: Node = focus
		UIRoot.set_prompt("")
		focus = null
		target.activate(self)
