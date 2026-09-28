class_name NamedNPC
extends Node2D
## A named character standing at their scheduled spot. Talk to them to run their dialogue / role.

var npc_id := ""
var def: Dictionary = {}
var rig: CharacterRig
var interact: Interactable
var name_tag: PanelContainer


func setup(id: String, scene: Node) -> void:
	npc_id = id
	def = DataDB.npc(id)
	rig = CharacterRig.new()
	add_child(rig)
	var tints := {}
	for k in def.get("outfit_tints", {}):
		tints[k] = Color(def["outfit_tints"][k])
	rig.setup(def.get("appearance", {}), def.get("outfit", "casual_tee"), tints, id)
	rig.set_dir("down")
	interact = Interactable.new()
	interact.label = I18n.t("Talk to %s") % def.get("name", id)
	interact.action = "talk"
	interact.params = {"npc": id}
	interact.radius = 30.0
	interact.npc = self
	interact.position = Vector2(0, 14)
	add_child(interact)
	# Name chip: shown only while the player is close, so it never sits on top of wall signs.
	name_tag = UIK.name_tag(str(def.get("name", id)))
	name_tag.modulate.a = 0.0
	add_child(name_tag)
	_place_tag.call_deferred()
	var _u := scene


func _place_tag() -> void:
	if name_tag != null:
		name_tag.reset_size()
		name_tag.position = Vector2(-name_tag.size.x / 2.0, -52 - name_tag.size.y)


func _process(delta: float) -> void:
	if name_tag == null:
		return
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	var near := pl != null and pl.global_position.distance_to(global_position) < 64.0
	name_tag.modulate.a = move_toward(name_tag.modulate.a, 1.0 if near else 0.0, delta * 5.0)


func face_toward(p: Vector2) -> void:
	rig.set_dir(CharacterRig.dir_from_vector(p - global_position, "down"))


func leave() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)
