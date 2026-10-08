extends SceneTree
func _initialize() -> void:call_deferred("run")
func run() -> void:
	await process_frame
	load("res://scripts/ui/i18n.gd").init()
	root.add_child(load("D:/cv164_before_bot.gd").new())
