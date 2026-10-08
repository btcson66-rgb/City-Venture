extends Node
## Touch layout, controller focus and gestures. No business or story state is persisted here.

const TARGET := Vector2(44, 44)
var touch_mode := false:
	set(value):
		var entering := value and not touch_mode
		touch_mode = value
		if entering and is_inside_tree():
			_enter_touch_mode()
var controller_mode := false
var fingers := {}
var starts := {}
var _pinch_distance := 0.0
var _surface: Control
var _hold: WeakRef
var _hold_time := 0.0
var _dragged := false
var _scroll_button: WeakRef
var _multi_touch := false
var overlay: CanvasLayer
var interact: Button
var rotate: PanelContainer
var _targets: Array[WeakRef] = []
var _locale := ""
var _dirty := true
var _focus_moved := false
var _since_rebuild := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	install_controller()
	get_tree().node_added.connect(func(node):
		_dirty = true
		_prepare_id.call_deferred(node.get_instance_id()))
	get_tree().node_removed.connect(func(_node): _dirty = true)
	get_viewport().gui_focus_changed.connect(func(_control): _focus_moved = true)
	get_viewport().size_changed.connect(func():
		if touch_mode: Preferences.apply.call_deferred())
	_prepare(get_tree().root, true)
	_make_overlay()
	if OS.has_feature("web"):
		_hook_web()


func install_controller() -> void:
	var buttons := {"interact": JOY_BUTTON_A, "confirm": JOY_BUTTON_A, "ui_accept": JOY_BUTTON_A,
		"cancel": JOY_BUTTON_B, "ui_cancel": JOY_BUTTON_B, "phone": JOY_BUTTON_Y,
		"company_os_hint": JOY_BUTTON_X, "pause": JOY_BUTTON_START,
		"ui_left": JOY_BUTTON_DPAD_LEFT, "ui_right": JOY_BUTTON_DPAD_RIGHT,
		"ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN,
		"map": JOY_BUTTON_BACK, "run": JOY_BUTTON_LEFT_STICK, "fast_forward": JOY_BUTTON_RIGHT_SHOULDER,
		"undo": JOY_BUTTON_LEFT_SHOULDER, "building_activities": JOY_BUTTON_RIGHT_STICK}
	for action in buttons:
		if not InputMap.has_action(action):
			continue
		var event := InputEventJoypadButton.new()
		event.button_index = buttons[action]
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)
	for row in [["move_left", JOY_AXIS_LEFT_X, -1.0], ["move_right", JOY_AXIS_LEFT_X, 1.0],
		["move_up", JOY_AXIS_LEFT_Y, -1.0], ["move_down", JOY_AXIS_LEFT_Y, 1.0],
		# Triggers pick the first two choices; every other choice is a focusable button reached with the D-pad and A.
		["pick_1", JOY_AXIS_TRIGGER_LEFT, 1.0], ["pick_2", JOY_AXIS_TRIGGER_RIGHT, 1.0]]:
		var event := InputEventJoypadMotion.new()
		event.axis = row[1]
		event.axis_value = row[2]
		if InputMap.has_action(row[0]) and not InputMap.action_has_event(row[0], event):
			InputMap.action_add_event(row[0], event)
		if InputMap.has_action(row[0]):
			InputMap.action_set_deadzone(row[0], 0.2)


func _prepare_id(id: int) -> void:
	var node: Variant = instance_from_id(id)
	if is_instance_valid(node):
		_prepare(node)


## Every added node fires its own node_added, so only the first sweep walks a whole tree.
func _prepare(node: Node, recurse := false) -> void:
	if node is BaseButton or node is LineEdit or node is HSlider or node is SpinBox or node is InfoTip:
		var control := node as Control
		if touch_mode:
			control.custom_minimum_size = control.custom_minimum_size.max(TARGET)
			if control is OptionButton:
				control.get_popup().add_theme_constant_override("v_separation", 32)
		control.focus_mode = Control.FOCUS_ALL
		if not control.has_meta("input_access_ready"):
			control.set_meta("input_access_ready", true)
			_targets.append(weakref(control))
			control.add_theme_stylebox_override("focus", UIK.flat(Color(0, 0, 0, 0), Art.C_GOLD, 2, 2))
	if recurse:
		for child in node.get_children():
			_prepare(child, true)


## The 44x44 touch minimum applies only once a touch is seen.
func _enter_touch_mode() -> void:
	var live: Array[WeakRef] = []
	for reference in _targets:
		var control: Variant = reference.get_ref()
		if is_instance_valid(control):
			control.custom_minimum_size = control.custom_minimum_size.max(TARGET)
			if control is OptionButton:
				control.get_popup().add_theme_constant_override("v_separation", 32)
			live.append(reference)
	_targets = live


func _make_overlay() -> void:
	overlay = CanvasLayer.new()
	overlay.layer = 30
	add_child(overlay)
	interact = UIK.button("Interact", func():
		var player := get_tree().get_first_node_in_group("player") as Player
		if player != null:
			player.interact_now(), "primary")
	interact.theme = UIK.theme()
	interact.name = "TouchInteract"
	overlay.add_child(interact)
	interact.custom_minimum_size = Vector2(96, 48)
	interact.visible = false
	rotate = UIK.panel("ui/panel", 8)
	rotate.theme = UIK.theme()
	rotate.name = "RotateDevice"
	overlay.add_child(rotate)
	rotate.add_child(UIK.wrap("Please rotate your device to landscape.", 14, Art.C_WHITE, 250))
	rotate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(rotate.get_child(0) as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	rotate.visible = false


func _active_surface() -> Control:
	var modals := UIRoot.modal_layer.get_children()
	if not modals.is_empty():
		return modals[-1] as Control
	if UIRoot.phone.is_open:
		return UIRoot.phone
	if UIRoot.dialogue.active:
		return UIRoot.dialogue
	return SceneRouter.current as Control


func _focusable(node: Node, list: Array[Control]) -> void:
	if node is Control and node.is_visible_in_tree() and node.focus_mode == Control.FOCUS_ALL:
		if not node is BaseButton or not node.disabled:
			list.append(node)
	for child in node.get_children():
		_focusable(child, list)


## Explicit wrapping neighbors keep every enabled control reachable, including scrollable footer actions.
func focus_surface(surface: Control, first := true) -> Array[Control]:
	var list: Array[Control] = []
	if not is_instance_valid(surface):
		return list
	_focusable(surface, list)
	for index in list.size():
		var previous: Control = list[posmod(index - 1, list.size())]
		var following: Control = list[(index + 1) % list.size()]
		var item: Control = list[index]
		item.focus_neighbor_top = item.get_path_to(previous)
		item.focus_neighbor_left = item.get_path_to(previous)
		item.focus_neighbor_bottom = item.get_path_to(following)
		item.focus_neighbor_right = item.get_path_to(following)
		item.focus_next = item.get_path_to(following)
		item.focus_previous = item.get_path_to(previous)
	if first and not list.is_empty():
		var primary: Control = list[0]
		for item in list:
			if bool(item.get_meta("primary_action", false)):
				primary = item
				break
		primary.grab_focus()
	return list


func _process(delta: float) -> void:
	var surface := _active_surface()
	if controller_mode:
		_since_rebuild += delta
		# Rebuild the focus list only when the tree or the top modal changed (1 s fallback for visibility flips).
		if _dirty or surface != _surface or _since_rebuild > 1.0:
			var focus := get_viewport().gui_get_focus_owner()
			var changed := surface != _surface or not is_instance_valid(focus) or (surface != null and not surface.is_ancestor_of(focus))
			focus_surface(surface, changed)
			if surface == null and focus != null:
				focus.release_focus()
			_dirty = false
			_since_rebuild = 0.0
		if _focus_moved:
			_focus_moved = false
			var focused := get_viewport().gui_get_focus_owner()
			var ancestor: Node = focused.get_parent() if focused != null else null
			while ancestor != null:
				if ancestor is ScrollContainer:
					ancestor.ensure_control_visible(focused)
				ancestor = ancestor.get_parent()
	_surface = surface
	if _locale != I18n.locale():
		_locale = I18n.locale()
		interact.text = I18n.t("Interact")
		(rotate.get_child(0) as Label).text = I18n.t("Please rotate your device to landscape.")
	var viewport := get_viewport().get_visible_rect().size
	var player := get_tree().get_first_node_in_group("player") as Player
	interact.visible = touch_mode and player != null and player.can_move() and player.focus != null
	interact.position = viewport - interact.size - Vector2(12, 12)
	var physical := DisplayServer.window_get_size()
	rotate.visible = touch_mode and physical.y > physical.x and player != null and surface == null
	rotate.position = Vector2(96 if OS.has_feature("web") else 8, viewport.y - rotate.size.y - 8)
	if _hold != null and not _dragged:
		_hold_time += delta
		if _hold_time >= 0.6:
			var control: Variant = _hold.get_ref()
			_hold = null
			if is_instance_valid(control):
				if control is InfoTip:
					control._pin()
				elif not control.tooltip_text.is_empty():
					UIRoot.open_modal(InfoModal.make("Help", "info", [control.tooltip_text]))


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		controller_mode = true
		if event is InputEventJoypadButton:
			_dirty = true
	if event is InputEventScreenTouch:
		touch_mode = true
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		controller_mode = false
		if event.pressed:
			if fingers.is_empty():
				_multi_touch = false
			fingers[event.index] = event.position
			starts[event.index] = event.position
			if fingers.size() == 1: _dragged = false
			_hold_time = 0.0
			var control := _hit(_active_surface(), event.position)
			var button := control
			while button != null and not button is BaseButton: button = button.get_parent() as Control
			if fingers.size() == 1:
				_scroll_button = weakref(button) if button is BaseButton and not button.disabled else null
			while control != null and not control is InfoTip and control.tooltip_text.is_empty():
				control = control.get_parent() as Control
			_hold = weakref(control) if control != null else null
		else:
			fingers.erase(event.index)
			_hold = null
			if _dragged:
				get_viewport().set_input_as_handled()
				if fingers.is_empty(): _restore_scroll_button.call_deferred()
		if fingers.size() == 2:
			_multi_touch = true
			_hold = null
			var points: Array = fingers.values()
			_pinch_distance = points[0].distance_to(points[1])
	if event is InputEventScreenDrag:
		fingers[event.index] = event.position
		if starts.has(event.index) and event.position.distance_to(starts[event.index]) > 8.0:
			_dragged = true
			var button: Variant = _scroll_button.get_ref() if _scroll_button != null else null
			if is_instance_valid(button): button.disabled = true # Cancels its pending release action.
		if fingers.size() == 2:
			var points: Array = fingers.values()
			var distance: float = points[0].distance_to(points[1])
			if _pinch_distance > 0.0:
				if _active_surface() != null and _active_surface().find_child("TouchMap", true, false) != null:
					_zoom_map(distance / _pinch_distance)
				else:
					_scroll_at(event.position, event.relative / 2.0)
			_pinch_distance = distance
			_hold = null
		else:
			_scroll_at(event.position, event.relative)
		if _active_surface() != null:
			get_viewport().set_input_as_handled()


func _restore_scroll_button() -> void:
	var button: Variant = _scroll_button.get_ref() if _scroll_button != null else null
	if is_instance_valid(button): button.disabled = false
	_scroll_button = null


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed:
		var start: Vector2 = starts.get(event.index, event.position)
		starts.erase(event.index)
		if _multi_touch or not fingers.is_empty() or _dragged or start.distance_to(event.position) > 8.0:
			return
		var hovered := get_viewport().gui_get_hovered_control()
		if hovered != null and hovered.mouse_filter != Control.MOUSE_FILTER_IGNORE:
			return
		var player := get_tree().get_first_node_in_group("player") as Player
		if player != null and player.can_move():
			_walk_touch(player, player.get_canvas_transform().affine_inverse() * event.position)
			get_viewport().set_input_as_handled()


## Door mats sit just inside the conservative navigation-grid clearance. Finish a
## door tap at the mat's outer edge using normal move_and_slide, never teleport.
func _walk_touch(player: Player, target: Vector2) -> void:
	var world := SceneRouter.world_scene()
	var door_goal := Vector2.INF
	if world != null and world.kind == "district":
		for node in world.get_children():
			if node is DoorTrigger:
				var collision := node.get_child(0) as CollisionShape2D
				var shape := collision.shape as RectangleShape2D
				var rect := Rect2(node.position + collision.position - shape.size / 2.0, shape.size)
				if rect.grow(12).has_point(target):
					door_goal = Vector2(rect.get_center().x, rect.end.y)
					break
	if player.walk_to(door_goal if door_goal != Vector2.INF else target) and door_goal != Vector2.INF:
		player.click_route.append(door_goal)

func _scroll_at(point: Vector2, relative: Vector2) -> void:
	var surface := _active_surface()
	if surface == null:
		return
	var scrolls: Array[ScrollContainer] = []
	_collect_scrolls(surface, scrolls)
	for index in range(scrolls.size() - 1, -1, -1):
		var scroll := scrolls[index]
		if scroll.get_global_rect().has_point(point):
			scroll.scroll_vertical -= roundi(relative.y)
			scroll.scroll_horizontal -= roundi(relative.x)
			break


func _collect_scrolls(node: Node, list: Array[ScrollContainer]) -> void:
	if node is ScrollContainer:
		list.append(node)
	for child in node.get_children():
		_collect_scrolls(child, list)


func _zoom_map(ratio: float) -> void:
	if not is_finite(ratio) or ratio <= 0.0:
		return
	var surface := _active_surface()
	if surface == null:
		return
	var map := surface.find_child("TouchMap", true, false) as Control
	if map != null:
		var zoom := clampf(map.scale.x * ratio, 0.75, 2.5)
		map.scale = Vector2(zoom, zoom)
		map.get_parent().custom_minimum_size = Vector2(map.get_meta("map_base_size")) * zoom


func _hook_web() -> void:
	# Establish touch geometry before the first tap, rather than move its target during dispatch.
	# Only a coarse primary pointer (phone, tablet) means touch; a touchscreen laptop with a mouse keeps the desktop layout.
	if bool(JavaScriptBridge.eval('(navigator.maxTouchPoints > 0) && (window.matchMedia(`(pointer: coarse)`).matches || !window.matchMedia(`(hover: hover)`).matches)', true)):
		touch_mode = true
		get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		Preferences.apply.call_deferred()
	JavaScriptBridge.eval("""
		const canvas = document.getElementById('canvas');
		if (canvas) {
			canvas.style.touchAction = 'none';
			canvas.addEventListener('touchmove', e => e.preventDefault(), {passive:false});
		}
		document.documentElement.style.overscrollBehavior = 'none';
		document.body.style.overflow = 'hidden';
	""")


func _hit(node: Node, point: Vector2) -> Control:
	if not is_instance_valid(node):
		return null
	if node is Control:
		if not node.is_visible_in_tree() or (node.clip_contents and not node.get_global_rect().has_point(point)):
			return null
	var children := node.get_children()
	children.reverse()
	for child in children:
		var hit := _hit(child, point)
		if hit != null:
			return hit
	if node is Control and node.mouse_filter != Control.MOUSE_FILTER_IGNORE and node.get_global_rect().has_point(point):
		return node
	return null
