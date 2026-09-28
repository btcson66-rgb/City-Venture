class_name AmbientPerson
extends Node2D
## Seated / idle customers inside buildings so interiors feel used.

var rig: CharacterRig
var _t := 0.0
var _rng: RandomNumberGenerator


func setup(rng: RandomNumberGenerator, seat_dir := "") -> void:
	_rng = rng
	rig = CharacterRig.new()
	add_child(rig)
	var outfits := ["casual_tee", "casual_jacket", "business_suit", "office_professional", "startup_casual"]
	var outfit: String = outfits[rng.randi_range(0, outfits.size() - 1)]
	rig.setup(Art.random_appearance(rng), outfit, Art.random_outfit_tints(rng, outfit))
	rig.set_dir(seat_dir if seat_dir != "" else ["down", "left", "right", "up"][rng.randi_range(0, 3)])
	rig.set_pose("sit")   # they are placed on chairs, benches and sofas
	_t = rng.randf_range(3.0, 9.0)


func _process(delta: float) -> void:
	if rig.pose == "sit":
		return   # seated customers face their table; they don't spin on the chair
	_t -= delta
	if _t <= 0.0:
		_t = _rng.randf_range(4.0, 10.0)
		rig.set_dir(["down", "left", "right", "up"][_rng.randi_range(0, 3)])
