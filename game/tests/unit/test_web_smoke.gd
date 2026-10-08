extends RefCounted
var runner

func test_release_browser_probe_parses() -> void:
	# This opt-in script is loaded only in Web releases; editor import alone does not compile it.
	var script: GDScript = load("res://scripts/qa/web_smoke_probe.gd")
	runner.check(script.can_instantiate(), "release-only browser probe compiles")
	if script.can_instantiate():
		var probe: Node = script.new()
		probe.free()

func test_interior_decoration_does_not_swallow_touch_navigation() -> void:
	GameState.new_game({"name": "Touch regression", "seed": 167})
	var room := Interior.new()
	room.build("riverside_apartment")
	_check_decoration(room)
	room.free()

func _check_decoration(node: Node) -> void:
	if node is ColorRect:
		runner.eq(node.mouse_filter, Control.MOUSE_FILTER_IGNORE, "world decoration passes touch to navigation")
	for child in node.get_children():
		_check_decoration(child)