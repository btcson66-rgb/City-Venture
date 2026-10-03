extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	await process_frame
	root.add_child(load("res://tests/walkthrough/media_gallery.gd").new())
