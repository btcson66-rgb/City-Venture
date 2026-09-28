class_name StaffNPC
extends Node2D
## One of the player's employees at their desk (or the packing table) during work hours.
## Talking to them gives a one-liner that reflects their morale.

var staff_id := ""
var rig: CharacterRig
var name_tag: PanelContainer


func setup(p: Dictionary, facing := "up", pose := "sit") -> void:
	staff_id = p["id"]
	rig = CharacterRig.new()
	add_child(rig)
	rig.setup(p["appearance"], p.get("outfit", "startup_casual"))
	rig.set_dir(facing)
	rig.set_pose(pose)   # desk staff sit, the packer works the table (once the pose art exists)
	var it := Interactable.new()
	it.label = I18n.t("Talk to %s") % str(p["name"]).get_slice(" ", 0)
	it.action = "talk_staff"
	it.params = {"staff": p["id"]}
	it.radius = 26.0
	it.npc = self
	it.position = Vector2(0, 12)
	add_child(it)
	name_tag = UIK.name_tag(str(p["name"]).get_slice(" ", 0))
	name_tag.modulate.a = 0.0
	add_child(name_tag)
	_place.call_deferred()


func _place() -> void:
	name_tag.reset_size()
	name_tag.position = Vector2(-name_tag.size.x / 2.0, -52 - name_tag.size.y)


func _process(delta: float) -> void:
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	var near := pl != null and pl.global_position.distance_to(global_position) < 56.0
	name_tag.modulate.a = move_toward(name_tag.modulate.a, 1.0 if near else 0.0, delta * 5.0)


func face_toward(p: Vector2) -> void:
	rig.set_dir(CharacterRig.dir_from_vector(p - global_position, "down"))


func leave() -> void:
	queue_free()
