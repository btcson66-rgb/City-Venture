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
var _phase := 0.0
var _marker_offset := Vector2.ZERO
static var _settings_loaded := false
static var _markers_on := true


func _ready() -> void:
	add_to_group("interactable")
	z_index = 40
	_phase = float(get_index()) * 0.7
	_stagger.call_deferred()


static func markers_enabled() -> bool:
	if not _settings_loaded:
		var cfg := ConfigFile.new()
		if cfg.load("user://settings.cfg") == OK:
			_markers_on = bool(cfg.get_value("general", "interaction_markers", true))
		_settings_loaded = true
	return _markers_on


static func set_markers(on: bool) -> void:
	markers_enabled()
	_markers_on = on
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	cfg.set_value("general", "interaction_markers", on)
	cfg.save("user://settings.cfg")


var _was_drawn := false


## Offset only the visual chip, never the interaction position or radius.
func _stagger() -> void:
	var neighbours: Array[Interactable] = []
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.get_parent() == get_parent() and n.global_position.distance_to(global_position) < 36.0:
			neighbours.append(n)
	if neighbours.size() > 1:
		_marker_offset = Vector2((neighbours.find(self) - (neighbours.size() - 1) / 2.0) * 22.0, -neighbours.find(self) * 16.0)


func _process(delta: float) -> void:
	if not enabled or not markers_enabled():
		if _was_drawn:             # clear the chip once, then stop redrawing every frame
			_was_drawn = false
			queue_redraw()
		return
	_was_drawn = true
	_phase += delta * 2.0
	queue_redraw()


func _draw() -> void:
	if not enabled or not markers_enabled():
		return
	var pl := get_tree().get_first_node_in_group("player") as Node2D
	if pl == null:
		return
	var distance := global_position.distance_to(pl.global_position)
	var locked := Actions.lock_reason(action, params) != ""
	var alpha := lerpf(0.25, 0.95, clampf(1.0 - distance / 100.0, 0, 1))
	if action == "look":
		alpha *= 0.6
	var size := 8.0 if action == "look" else 12.0
	var pos := Vector2(-size / 2, -30.0 if npc == null else -62.0) + _marker_offset + Vector2(0, sin(_phase) * 1.5)
	var tint := Color(0.55, 0.58, 0.65, alpha) if locked else Color(1, 1, 1, alpha)
	var tex := Art.icon(BuildingInfo.icon_for(action, params))
	if tex != null:
		draw_style_box(UIK.flat(Color(0.03, 0.07, 0.13, alpha * 0.85), Color(0, 0, 0, 0), 0, 2), Rect2(pos - Vector2(2, 2), Vector2(size + 4, size + 4)))
		draw_texture_rect(tex, Rect2(pos, Vector2(size, size)), false, tint)
	if locked:
		draw_texture_rect(Art.icon("lock"), Rect2(pos + Vector2(size - 4, size - 4), Vector2(7, 7)), false, Color(1, 1, 1, alpha))
	if distance <= 64.0:
		var text := BuildingInfo.action_label(label, action, params)
		if text.length() > 38:
			text = text.left(37) + "…"
		var font := UIK.body_font()
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		var at := pos + Vector2(size / 2 - width / 2, -6)
		draw_style_box(UIK.flat(Color(0.03, 0.07, 0.13, 0.9), Color(0, 0, 0, 0), 0, 2), Rect2(at + Vector2(-2, -7), Vector2(width + 4, 10)))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Art.C_MUTED if locked else Art.C_WHITE)


func prompt_text() -> String:
	var t := BuildingInfo.action_label(label, action, params)
	var lock := Actions.lock_reason(action, params)
	if lock != "":
		t += "  ·  " + I18n.t(lock)
	return t


func activate(player: Node) -> void:
	if npc != null and npc.has_method("face_toward"):
		npc.face_toward(player.global_position)
	EventBus.interacted.emit(action, params.get("id", name))
	Actions.run(action, params, self)
