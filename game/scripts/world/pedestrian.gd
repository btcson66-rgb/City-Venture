class_name Pedestrian
extends Node2D
## Ambient city life: walks the sidewalks, pauses to check a phone, turns around at the ends.

var rig: CharacterRig
var scene: Node
var path: Dictionary
var dir := 1
var speed := 36.0
var pause_t := 0.0
var _rng: RandomNumberGenerator
var _retiring := false


func setup(s: Node, p: Dictionary, rng: RandomNumberGenerator, initial: bool) -> void:
	scene = s
	path = p
	_rng = rng
	rig = CharacterRig.new()
	add_child(rig)
	var outfits := ["casual_tee", "casual_tee", "casual_jacket", "casual_jacket", "business_suit", "office_professional", "startup_casual", "home"]
	var app := Art.random_appearance(rng)
	var of: String = outfits[rng.randi_range(0, outfits.size() - 1)]
	rig.setup(app, of, Art.random_outfit_tints(rng, of))
	dir = 1 if rng.randf() < 0.5 else -1
	speed = rng.randf_range(28.0, 44.0)
	var x0 := float(p["x0"])
	var x1 := float(p["x1"])
	position = Vector2(rng.randf_range(x0, x1) if initial else (x0 if dir > 0 else x1), float(p["y"]) + rng.randf_range(-3, 3))
	rig.set_dir("right" if dir > 0 else "left")
	rig.set_walking(true)
	if not initial:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


func retire() -> void:
	_retiring = true
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_callback(queue_free)


func _process(delta: float) -> void:
	if pause_t > 0.0:
		pause_t -= delta
		if pause_t <= 0.0:
			rig.set_walking(true)
			rig.set_dir("right" if dir > 0 else "left")
		return
	position.x += dir * speed * delta
	if _rng.randf() < delta * 0.04:
		pause_t = _rng.randf_range(1.5, 4.0)
		rig.set_walking(false)
		rig.set_dir("down")
	if position.x > float(path["x1"]):
		dir = -1
		rig.set_dir("left")
	elif position.x < float(path["x0"]):
		dir = 1
		rig.set_dir("right")
