extends SceneTree
func _initialize() -> void:
	root.add_child(load("res://tests/walkthrough/trade_balance.gd").new())
