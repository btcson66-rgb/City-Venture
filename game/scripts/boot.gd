extends Node
## Entry point. `-- --bot=<name>` runs a scripted walkthrough (tests/walkthrough).


func _ready() -> void:
	call_deferred("_start")


func _start() -> void:
	I18n.init()
	var errs := DataDB.validate()
	for e in errs:
		push_error("Data: " + str(e))
	var bot := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--bot="):
			bot = a.substr(6)
	if bot == "stress":
		var stress = load("res://tests/walkthrough/stress.gd").new()
		get_tree().root.add_child(stress)
		return
	if bot != "":
		var script: GDScript = load("res://tests/walkthrough/bot.gd")
		var b = script.new()
		b.name = "Bot"
		b.mode = bot
		get_tree().root.add_child(b)
	SceneRouter.go_menu()
