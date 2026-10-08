extends Node
## Opt-in, read-only browser diagnostics. No callbacks, state setters or gameplay shortcuts.
var elapsed := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 0.15:
		return
	elapsed = 0.0
	var controls: Array = []
	var popups: Array = []
	var surface := InputAccess._active_surface()
	_collect(surface if surface != null else get_tree().root, controls, popups)
	var viewport := get_viewport().get_visible_rect().size
	var data := {"controls": controls, "popups": popups, "viewport": [viewport.x, viewport.y],
		"scene": SceneRouter.current.get_script().get_global_name() if SceneRouter.current != null else "",
		"locale": I18n.locale(), "font_size": Preferences.values["font_size"],
		"touch": InputAccess.touch_mode, "phone": UIRoot.phone.is_open, "actions": []}
	var world := SceneRouter.world_scene()
	if world != null:
		data["world"] = world.scene_id
		var player := world.player
		var point := player.get_global_transform_with_canvas().origin
		data["player"] = [point.x, point.y]
		data["can_move"] = player.can_move()
		data["route"] = str(player.click_route)
		var hovered := get_viewport().gui_get_hovered_control()
		data["hovered"] = str(hovered.get_path()) if hovered != null else ""
		data["focus"] = player.focus.action if player.focus != null else ""
		data["doors"] = []
		for node in world.get_children():
			if node is DoorTrigger or node is InteriorExit:
				var collision := node.get_child(0) as CollisionShape2D
				var location: Vector2 = node.get_global_transform_with_canvas() * collision.position
				data["doors"].append({"building": node.building_id, "exit": node is InteriorExit,
					"point": [location.x, location.y]})
		for node in get_tree().get_nodes_in_group("interactable"):
			if node.is_inside_tree() and node.enabled:
				var location: Vector2 = node.get_global_transform_with_canvas().origin
				data["actions"].append({"action": node.action, "params": node.params,
					"point": [location.x, location.y], "radius": node.radius})
	if GameState.has_game():
		data["bank_open"] = SceneRouter.building_open("nexus_bank")["open"]
		data["time"] = Clock.now()
		data["name"] = GameState.data["player"].get("name", "")
		data["cash"] = Ledger.cash("player")
		data["shifts"] = int(GameState.data.get("careers", {}).get("shifts", {}).get("barista", 0))
		data["slot"] = SaveSystem.current_slot()
		data["balanced"] = Ledger.check_balanced()
		data["messages"] = GameState.data.get("messages", [])
	var modal := UIRoot.top_modal()
	data["modal"] = modal.get_script().get_global_name() if modal != null else ""
	if modal is BaristaGame:
		data["mini"] = {"phase": modal.phase, "practice": modal.practice_only,
			"target": str(modal.practice_target.name) if is_instance_valid(modal.practice_target) else "",
			"step": modal.practice_step, "want": modal.want, "points": modal.points}
	var transform := get_viewport().get_final_transform()
	data["transform"] = [transform.x.x, transform.y.y, transform.origin.x, transform.origin.y]
	JavaScriptBridge.eval('window.cvSmoke=' + JSON.stringify(data), true)

func _collect(node: Node, controls: Array, popups: Array) -> void:
	if node is OptionButton:
		_collect(node.get_popup(), controls, popups)
	if node is PopupMenu and node.visible:
		var items: Array = []
		for index in node.item_count:
			items.append(node.get_item_text(index))
		popups.append({"rect": [node.position.x, node.position.y, node.size.x, node.size.y], "items": items})
	if node is Control and node.is_visible_in_tree() and (node is Button or node is LineEdit):
		var rectangle: Rect2 = node.get_global_rect()
		var visible: Rect2 = rectangle.intersection(get_viewport().get_visible_rect())
		var scroll := Rect2()
		var scrolls: Array = []
		var parent := node.get_parent()
		while parent != null:
			if parent is Control and parent.clip_contents:
				visible = visible.intersection(parent.get_global_rect())
			if parent is ScrollContainer:
				var bounds: Rect2 = parent.get_global_rect()
				scrolls.append([bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y])
				if scroll.size == Vector2.ZERO: scroll = bounds
			parent = parent.get_parent()
		controls.append({"name": str(node.name), "text": node.text,
			"disabled": node.disabled if node is BaseButton else not node.editable,
			"rect": [rectangle.position.x, rectangle.position.y, rectangle.size.x, rectangle.size.y],
			"scrolls": scrolls, "visible": [visible.position.x, visible.position.y, visible.size.x, visible.size.y],
			"scroll": [scroll.position.x, scroll.position.y, scroll.size.x, scroll.size.y]})
	for child in node.get_children():
		_collect(child, controls, popups)
