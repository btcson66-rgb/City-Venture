class_name NamedNPC
extends Node2D
## A named character standing at their scheduled spot. Talk to them to run their dialogue / role.

var npc_id := ""
var def: Dictionary = {}
var rig: CharacterRig
var interact: Interactable


func setup(id: String, scene: Node) -> void:
	npc_id = id
	def = DataDB.npc(id)
	rig = CharacterRig.new()
	add_child(rig)
	var tints := {}
	for k in def.get("outfit_tints", {}):
		tints[k] = Color(def["outfit_tints"][k])
	rig.setup(def.get("appearance", {}), def.get("outfit", "casual_tee"), tints)
	rig.set_dir("down")
	interact = Interactable.new()
	interact.label = "Talk to %s" % def.get("name", id)
	interact.action = "talk"
	interact.params = {"npc": id}
	interact.radius = 30.0
	interact.npc = self
	interact.position = Vector2(0, 14)
	add_child(interact)
	var name_lb := UIK.world_label(def.get("name", id), 5, Color8(250, 250, 255))
	name_lb.position = Vector2(-30, -60)
	name_lb.size = Vector2(60, 8)
	name_lb.modulate.a = 0.85
	add_child(name_lb)
	var _u := scene


func face_toward(p: Vector2) -> void:
	rig.set_dir(CharacterRig.dir_from_vector(p - global_position, "down"))


func leave() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
