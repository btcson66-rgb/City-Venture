extends "res://tests/walkthrough/bot.gd"
func _run() -> void:
	await wait(1.0)
	await load("D:/cv164_capture_tour.gd").new(self).run()
	_finish()
