extends RefCounted

var runner


func _grid() -> WorldScene:
	var world := WorldScene.new()
	world.size_px = Vector2i(160, 160)
	world.init_nav()
	return world


func test_click_path_uses_clearance_grid_and_exact_free_destination() -> void:
	var world := _grid()
	world.add_solid(Rect2(64, 0, 16, 112))
	var target := Vector2(134, 28)
	var path := ClickPath.plan(world, Vector2(20, 28), target)
	runner.check(not path.is_empty(), "route around wall exists")
	runner.eq(path[-1], target, "ends at the free tap position")
	var went_around := false
	for point in path:
		var cell := Vector2i(floori(point.x / world.NAV_CELL), floori(point.y / world.NAV_CELL))
		runner.check(not world.nav.is_point_solid(cell), "all route cells retain player clearance")
		went_around = went_around or point.y >= 120
	runner.check(went_around, "does not walk through the wall")
	world.free()


func test_unreachable_or_outside_taps_are_safe() -> void:
	var world := _grid()
	world.add_solid(Rect2(64, 0, 16, 160))
	runner.check(ClickPath.plan(world, Vector2(20, 28), Vector2(134, 28)).is_empty(), "disconnected area rejected")
	var route := ClickPath.plan(world, Vector2(20, 28), Vector2(-500, -500))
	for point in route:
		runner.check(point.x >= 0 and point.y >= 0, "out of bounds tap is clamped")
	runner.check(ClickPath.plan(null, Vector2.ZERO, Vector2.ONE).is_empty(), "no scene, no path")
	world.free()


func test_controller_map_survives_keyboard_changes_without_duplicates() -> void:
	Preferences.apply_input()
	var before := InputMap.action_get_events("interact").size()
	InputAccess.install_controller()
	runner.eq(InputMap.action_get_events("interact").size(), before, "controller installation idempotent")
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	runner.check(InputMap.event_is_action(event, "interact"), "A interacts")
	event.button_index = JOY_BUTTON_B
	runner.check(InputMap.event_is_action(event, "cancel"), "B returns")
	event.button_index = JOY_BUTTON_Y
	runner.check(InputMap.event_is_action(event, "phone"), "Y opens phone")
	event.button_index = JOY_BUTTON_X
	runner.check(InputMap.event_is_action(event, "company_os_hint"), "X opens terminal")


func test_touch_targets_and_primary_focus_neighbors() -> void:
	var surface := VBoxContainer.new()
	runner.get_tree().root.add_child(surface)
	var secondary := UIK.button("Other", func(): pass)
	var primary := UIK.button("Next", func(): pass, "primary")
	var field := LineEdit.new()
	surface.add_child(secondary)
	surface.add_child(primary)
	surface.add_child(field)
	InputAccess._prepare(surface)
	var controls := InputAccess.focus_surface(surface)
	runner.eq(controls.size(), 3, "all interactive widgets included")
	runner.eq(primary.get_viewport().gui_get_focus_owner(), primary, "first focus is next action")
	for control in controls:
		runner.check(control.custom_minimum_size.x >= 44 and control.custom_minimum_size.y >= 44, "44 logical pixels")
		runner.check(control.has_node(control.focus_neighbor_bottom), "D-pad down neighbor exists")
		runner.check(control.has_node(control.focus_neighbor_top), "D-pad up neighbor exists")
	surface.free()


func test_map_gesture_limits_and_invalid_ratios() -> void:
	var modal := Modal.new()
	modal.help_key = ""
	UIRoot.modal_layer.add_child(modal)
	var frame := Control.new()
	var map := Control.new()
	map.name = "TouchMap"
	map.set_meta("map_base_size", Vector2(100, 80))
	frame.add_child(map)
	modal.add_child(frame)
	InputAccess._zoom_map(100.0)
	runner.eq(map.scale, Vector2(2.5, 2.5), "large pinch has an upper limit")
	runner.eq(frame.custom_minimum_size, Vector2(250, 200), "scroll extent follows zoom")
	InputAccess._zoom_map(0.01)
	runner.eq(map.scale, Vector2(0.75, 0.75), "small pinch keeps readable map")
	InputAccess._zoom_map(NAN)
	InputAccess._zoom_map(-1.0)
	runner.eq(map.scale, Vector2(0.75, 0.75), "invalid gesture leaves the map usable")
	modal.free()
