extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	await process_frame
	root.add_child(load("res://tests/walkthrough/cafe_balance.gd").new())
