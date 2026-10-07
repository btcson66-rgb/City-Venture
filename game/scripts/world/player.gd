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
var click_route := PackedVector2Array()
var _stuck_seconds := 0.0


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 2
	# top-down: no floors or ceilings, slide along everything
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	wall_min_slide_angle = 0.0
	safe_margin = 0.5
	# a flat capsule for the feet: rounded ends glide past corners where a box would catch
	var shape := CollisionShape2D.new()
	var cap := CapsuleShape2D.new()
	cap.radius = 2.5
	cap.height = 10.0
	shape.shape = cap
	shape.rotation = PI / 2.0
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
	if v.length() > 0.1:
		click_route.clear()
	elif can_move() and not click_route.is_empty():
		while not click_route.is_empty() and global_position.distance_to(click_route[0]) <= 2.0:
			click_route.remove_at(0)
		if not click_route.is_empty():
			v = global_position.direction_to(click_route[0])
	elif not can_move():
		click_route.clear()
	var speed := RUN_SPEED if Input.is_action_pressed("run") else WALK_SPEED
	speed *= TrafficSafety.speed_multiplier()
	velocity = v.normalized() * speed if v.length() > 0.1 else Vector2.ZERO
	moving = velocity.length() > 0.1
	if moving:
		facing = CharacterRig.dir_from_vector(v, facing)
		rig.set_dir(facing)
	var before := global_position
	move_and_slide()
	if moving and global_position.distance_to(before) < speed * _delta * 0.25:
		_corner_slide(v, speed * _delta)
	if not click_route.is_empty() and global_position.distance_to(before) < 0.1:
		_stuck_seconds += _delta
		if _stuck_seconds > 1.0:
			click_route.clear()
	else:
		_stuck_seconds = 0.0
	var travelled := global_position.distance_to(before)
	moving = travelled > 0.01
	rig.anim_speed = clampf(travelled / maxf(_delta, 0.001) / 8.0, 0.0, 16.0)
	rig.set_walking(moving)
	PersonalLife.movement(travelled)
	_update_focus()


const CORNER_REACH := 7.0


## Pushing straight into the edge of a doorway, a table corner or a gap between props: if a few pixels to one side
## the way is clear, slide over to it instead of stopping dead.
func _corner_slide(v: Vector2, step: float) -> void:
	var dir := Vector2.ZERO
	if absf(v.x) > absf(v.y) * 2.0:
		dir = Vector2(signf(v.x), 0)
	elif absf(v.y) > absf(v.x) * 2.0:
		dir = Vector2(0, signf(v.y))
	if dir == Vector2.ZERO:
		return
	var side := Vector2(absf(dir.y), absf(dir.x))
	for d in range(1, int(CORNER_REACH) + 1):
		for sgn in [-1.0, 1.0]:
			var off: Vector2 = side * float(d) * sgn
			if not test_move(global_transform, off) and not test_move(global_transform.translated(off), dir * 2.0):
				move_and_collide(side * sgn * minf(float(d), step))
				return


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
	if event.is_action_pressed("company_os_hint") and can_move():
		get_viewport().set_input_as_handled()
		if focus != null and focus.action == "open_company_os":
			interact_now()
		else:
			UIRoot.toast("Walk to a laptop or work desk, then use Company OS.", "info", "laptop")
		return
	if (event.is_action_pressed("interact") or event.is_action_pressed("confirm")) and focus != null and can_move():
		get_viewport().set_input_as_handled()
		interact_now()


## Use whatever is in reach (the E key, or a click/tap on the on-screen prompt).
func interact_now() -> void:
	if focus == null or not can_move():
		return
	rig.set_walking(false)
	var target: Node = focus
	UIRoot.set_prompt("")
	focus = null
	target.activate(self)


func walk_to(target: Vector2) -> bool:
	if not can_move():
		return false
	click_route = ClickPath.plan(SceneRouter.world_scene(), global_position, target)
	_stuck_seconds = 0.0
	if click_route.is_empty():
		UIRoot.toast("No walking route. Tap another spot on the ground.", "info", "map")
	return not click_route.is_empty()
