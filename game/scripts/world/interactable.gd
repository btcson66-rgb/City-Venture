class_name Interactable
extends Node2D
## A spot in the world the player can walk up to and use. The prompt shows only in reach.

var label := ""
var action := ""
var params: Dictionary = {}
var radius := 22.0
var enabled := true
var key_hint := "E"
var npc: Node = null


func _ready() -> void:
	add_to_group("interactable")


func prompt_text() -> String:
	var t := label
	var lock := Actions.lock_reason(action, params)
	if lock != "":
		t += "  ·  " + lock
	return t


func activate(player: Node) -> void:
	if npc != null and npc.has_method("face_toward"):
		npc.face_toward(player.global_position)
	EventBus.interacted.emit(action, params.get("id", name))
	Actions.run(action, params, self)
