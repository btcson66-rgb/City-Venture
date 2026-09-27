extends CanvasLayer
## Placeholder; replaced by the full UI root.
var dialogue_queue: Array = []
func show_chapter_card(_t: String, _s := "") -> void:
	pass
func queue_dialogue(id: String) -> void:
	dialogue_queue.append(id)
