extends Node
## Device preferences, separate from every company's save. Unknown cfg sections survive each write.

signal changed
const PATH := "user://settings.cfg"
const DEFAULTS := {"master": 1.0, "music": 0.8, "sfx": 0.9, "ambience": 0.8,
	"window_mode": 0, "ui_scale": 1.0, "font_size": 1, "color_mode": 0,
	"reduce_motion": false, "subtitle_seconds": 0.0, "notification_seconds": 4.2,
	"autosave_seconds": 15.0, "default_speed": 1.5, "tutorial_hints": true}
const BINDINGS := {"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN], "run": [KEY_SHIFT],
	"interact": [KEY_E, KEY_SPACE], "phone": [KEY_TAB, KEY_P], "map": [KEY_M],
	"company_os_hint": [KEY_C], "building_activities": [KEY_I], "pause": [KEY_ESCAPE], "fast_forward": [KEY_F],
	"confirm": [KEY_ENTER], "cancel": [KEY_BACKSPACE], "bug_report": [KEY_F12], "undo": [KEY_U],
	"pick_1": [KEY_1], "pick_2": [KEY_2], "pick_3": [KEY_3], "pick_4": [KEY_4], "pick_5": [KEY_5],
	"pick_6": [KEY_6], "pick_7": [KEY_7], "pick_8": [KEY_8], "pick_9": [KEY_9]}
var values: Dictionary = DEFAULTS.duplicate()
var bindings: Dictionary = BINDINGS.duplicate(true)
var path := PATH
var filter_material: ShaderMaterial
var _last_font := 1.0


func _ready() -> void:
	load_settings()
	apply_input()
	get_tree().node_added.connect(_node_added)
	apply.call_deferred()
	Clock.speed = float(values["default_speed"])


func load_settings() -> void:
	values = DEFAULTS.duplicate()
	bindings = BINDINGS.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for key in DEFAULTS:
		var legacy: Variant = cfg.get_value("audio", key, DEFAULTS[key]) if key in ["music", "sfx"] else DEFAULTS[key]
		values[key] = validated(key, cfg.get_value("preferences", key, legacy))
	# Reject malformed or conflicting persisted assignments, retaining a complete usable default map.
	var candidate: Dictionary = BINDINGS.duplicate(true)
	for action in BINDINGS:
		var keys: Variant = cfg.get_value("bindings", action, BINDINGS[action])
		if not keys is Array or keys.is_empty():
			return
		for key in keys:
			if not key is int or key <= 0 or key > 0x7fffffff:
				return
		candidate[action] = keys
	var seen := {}
	for action in candidate:
		for key in candidate[action]:
			if seen.has(key):
				return
			seen[key] = true
	bindings = candidate


func validated(key: String, value: Variant) -> Variant:
	var base: Variant = DEFAULTS[key]
	if base is bool:
		return value if value is bool else base
	if not (value is int or value is float) or not is_finite(float(value)):
		return base
	match key:
		"master", "music", "sfx", "ambience": return clampf(float(value), 0.0, 1.0)
		"ui_scale": return clampf(float(value), 0.8, 1.5)
		"font_size", "color_mode": return clampi(int(value), 0, 3)
		"window_mode": return clampi(int(value), 0, 2)
		"subtitle_seconds": return clampf(float(value), 0.0, 30.0)
		"notification_seconds": return clampf(float(value), 2.0, 30.0)
		"autosave_seconds": return clampf(float(value), 5.0, 120.0)
		"default_speed": return clampf(float(value), 0.5, 3.0)
	return base


func save_settings() -> Error:
	var cfg := ConfigFile.new()
	cfg.load(path)
	for key in values:
		cfg.set_value("preferences", key, values[key])
	for action in bindings:
		cfg.set_value("bindings", action, bindings[action])
	# Keep the old Sound API and old pause-menu builds compatible with this cfg.
	for key in ["music", "sfx"]:
		cfg.set_value("audio", key, values[key])
	return cfg.save(path)


func set_value(key: String, value: Variant) -> Error:
	if not DEFAULTS.has(key):
		return ERR_INVALID_PARAMETER
	values[key] = validated(key, value)
	var result := save_settings()
	apply()
	changed.emit()
	return result


func conflict(action: String, key: int) -> String:
	for other in bindings:
		if other != action and key in bindings[other]:
			return other
	return ""


func rebind(action: String, key: int) -> Error:
	if not bindings.has(action) or key <= 0 or not conflict(action, key).is_empty():
		return ERR_INVALID_PARAMETER
	bindings[action] = [key]
	apply_input()
	changed.emit()
	return save_settings()


func reset_bindings() -> Error:
	bindings = BINDINGS.duplicate(true)
	apply_input()
	changed.emit()
	return save_settings()


func apply_input() -> void:
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for key in bindings[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for pair in [["ui_accept", "confirm"], ["ui_cancel", "cancel"]]:
		InputMap.action_erase_events(pair[0])
		for event in InputMap.action_get_events(pair[1]):
			InputMap.action_add_event(pair[0], event)

	var access := get_tree().root.get_node_or_null("InputAccess") if is_inside_tree() else null
	if access != null:
		access.install_controller()


func font_factor() -> float:
	return [0.85, 1.0, 1.25, 1.5][int(values["font_size"])]


func _node_added(node: Node) -> void:
	_style_id.call_deferred(node.get_instance_id())


func _style_id(id: int) -> void:
	var node: Variant = instance_from_id(id)
	if is_instance_valid(node):
		_style(node)


func _style(node: Node) -> void:
	if not is_instance_valid(node):
		return
	if node is Control:
		var control := node as Control
		if not control.has_meta("preferences_font_base"):
			control.set_meta("preferences_font_base", control.get_theme_font_size("font_size") if control.has_theme_font_size_override("font_size") else 8)
		control.add_theme_font_size_override("font_size", maxi(6, roundi(float(control.get_meta("preferences_font_base")) * font_factor())))
	if node is Camera2D:
		(node as Camera2D).position_smoothing_enabled = not bool(values["reduce_motion"])
	for child in node.get_children():
		_style(child)


func apply() -> void:
	for bus in ["Master", "Music", "SFX", "Ambience"]:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
		var volume := float(values[bus.to_lower()])
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))
		AudioServer.set_bus_mute(index, volume <= 0.0)
	Sound.music_volume = float(values["music"])
	Sound.sfx_volume = float(values["sfx"])
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if int(values["window_mode"]) == 1 else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, int(values["window_mode"]) == 2)
	var themed := UIK.theme()
	themed.default_font_size = maxi(6, roundi(8.0 * font_factor()))
	for type_name in ['Button', 'PopupMenu', 'OptionButton']:
		themed.set_font_size("font_size", type_name, maxi(6, roundi(8.0 * font_factor())))
	get_tree().root.content_scale_factor = float(values["ui_scale"])
	if not is_equal_approx(_last_font, font_factor()):
		_last_font = font_factor()
		_style(get_tree().root)
	if filter_material == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		add_child(layer)
		var filter := ColorRect.new()
		filter.set_anchors_preset(Control.PRESET_FULL_RECT)
		filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
		filter_material = ShaderMaterial.new()
		filter_material.shader = load("res://shaders/accessibility.gdshader")
		filter.material = filter_material
		layer.add_child(filter)
	filter_material.set_shader_parameter("mode", int(values["color_mode"]))


## Some inherited modals animate in their own _process; fit them without changing those implementations.
func _process(_delta: float) -> void:
	for modal in get_tree().get_nodes_in_group("accessible_modal"):
		modal._fit_panel()


func key_caption(action: String) -> String:
	return OS.get_keycode_string(int(bindings[action][0]))
