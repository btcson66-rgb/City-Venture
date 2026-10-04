extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	await process_frame
	root.add_child(load("res://tests/walkthrough/real_estate_balance.gd").new())
