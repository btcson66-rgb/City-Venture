class_name ProgressCelebration
extends Control
## A brief, nonblocking celebration. Receipts live in StoryEngine/Growth, never here.

var remaining := 0.0
var elapsed := 0.0
var caption: Label
var pending := ""

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption = UIK.label("", 10, Art.C_SKY, true)
	caption.name = "ProgressMoment"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.position = Vector2(210, 42)
	caption.size = Vector2(220, 40)
	add_child(caption)
	visible = false

func celebrate(text: String) -> void:
	pending = text
	# A chapter card may cover the HUD. Let its reveal finish before playing this receipt.
	if not _can_show(): return
	_show_pending()

func _can_show() -> bool:
	return get_parent().is_visible_in_tree() and is_instance_valid(UIRoot.card_layer) and UIRoot.card_layer.get_child_count() == 0

func _show_pending() -> void:
	var text := pending
	pending = ""
	caption.text = text
	modulate.a = 1.0
	elapsed = 0.0
	remaining = float(FunLoop.cfg().get("celebration_seconds", 1.2))
	visible = true
	Sound.play("success", -12)

func _process(delta: float) -> void:
	if not pending.is_empty() and _can_show(): _show_pending()
	if remaining <= 0: return
	elapsed += delta
	remaining -= delta
	modulate.a = clampf(remaining * 3, 0, 1)
	queue_redraw()
	if remaining <= 0: visible = false

func _draw() -> void:
	if remaining <= 0 or bool(Preferences.values.get("reduce_motion", false)): return
	var count := int(FunLoop.cfg().get("celebration_pieces", 16))
	for index in count:
		var start := Vector2(40 + index * 560.0 / maxi(1, count - 1), 20 + (index % 3) * 8)
		var pos := start + Vector2(sin(elapsed * 4 + index) * 12, elapsed * (35 + index % 5 * 8))
		draw_rect(Rect2(pos, Vector2(3, 5)), Art.C_SKY if index % 2 == 0 else Art.C_GREEN)
