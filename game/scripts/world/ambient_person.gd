class_name AmbientPerson
extends Node2D
## Seated / idle customers inside buildings so interiors feel used.

var rig: CharacterRig
var _t := 0.0
var _rng: RandomNumberGenerator


func setup(rng: RandomNumberGenerator) -> void:
	_rng = rng
	rig = CharacterRig.new()
	add_child(rig)
	var outfits := ["casual_tee", "casual_jacket", "business_suit", "office_professional", "startup_casual"]
	rig.setup(Art.random_appearance(rng), outfits[rng.randi_range(0, outfits.size() - 1)], Art.random_outfit_tints(rng))
	rig.set_dir(["down", "left", "right", "up"][rng.randi_range(0, 3)])
	_t = rng.randf_range(3.0, 9.0)


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = _rng.randf_range(4.0, 10.0)
		rig.set_dir(["down", "left", "right", "up"][_rng.randi_range(0, 3)])
