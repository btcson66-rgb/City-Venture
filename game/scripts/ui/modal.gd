class_name Modal
extends Control
## Base for contextual management UI opened from in-world interactions. World time keeps running unless
## `pauses_time` is set.

signal closed

var title_text := ""
var icon_name := ""
var panel_size := Vector2(420, 250)
var closable := true
var dim_alpha := 0.55
var help_key := ""           # data/help/help.json: shown the first time, and behind the ? button (Help)
## Life goes on while you use a screen (Company OS, the bank, a shop): the clock keeps running. Screens that are
## about stopping to read or decide (pause menu, help cards, decisions, reports, minigames that apply their own
## time) set this to stop it.
var pauses_time := false
var panel: PanelContainer
var body: VBoxContainer
var header: HBoxContainer
var footer: HBoxContainer
var _built := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	# full-screen management screens get an almost opaque backing so the world doesn't show through
	dim.color = Color(0.03, 0.06, 0.12, maxf(dim_alpha, 0.88) if panel_size.x >= 560.0 else dim_alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = UIK.panel("ui/panel", 8)
	panel.custom_minimum_size = panel_size
	panel.size = panel_size
	panel.position = (Vector2(640, 360) - panel_size) / 2.0
	add_child(panel)
	var outer := UIK.vbox(5)
	panel.add_child(outer)
	header = UIK.hbox(5)
	outer.add_child(header)
	if icon_name != "":
		header.add_child(UIK.icon(icon_name, 16))
	var t := UIK.title(title_text, 12)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(t)
	if help_key != "":
		var hb := UIK.button("?", func(): Help.open(help_key))
		hb.name = "Help"
		hb.custom_minimum_size = Vector2(18, 16)
		header.add_child(hb)
	if closable:
		var x := UIK.button("×", close)
		x.name = "Close"
		x.custom_minimum_size = Vector2(18, 16)
		header.add_child(x)
	outer.add_child(UIK.sep())
	body = UIK.vbox(4)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(body)
	footer = UIK.hbox(6)
	footer.alignment = BoxContainer.ALIGNMENT_END
	outer.add_child(footer)
	build()
	_built = true
	if help_key != "":
		Help.show_once.call_deferred(help_key)


## Override: fill `body` and `footer`.
func build() -> void:
	pass


## Rebuild the contents in place. Scroll lists keep their position, so pressing "+" on a row halfway down a list
## doesn't throw you back to the top; set `reset_scroll` first when the content changes entirely (a new tab).
func rebuild() -> void:
	var keep: Array = [] if reset_scroll else _scroll_values(body)
	reset_scroll = false
	UIK.clear(body)
	UIK.clear(footer)
	build()
	if not keep.is_empty():
		_restore_scroll.call_deferred(keep)


var reset_scroll := false


static func _scrolls(n: Node, out: Array) -> Array:
	for c in n.get_children():
		if c is ScrollContainer:
			out.append(c)
		_scrolls(c, out)
	return out


func _scroll_values(n: Node) -> Array:
	return _scrolls(n, []).map(func(sc): return sc.scroll_vertical)


func _restore_scroll(keep: Array) -> void:
	await get_tree().process_frame   # the new rows need a layout pass before the scroll range is right
	var now := _scrolls(body, [])
	for i in mini(keep.size(), now.size()):
		if is_instance_valid(now[i]):
			now[i].scroll_vertical = int(keep[i])


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if closable and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		close()


func set_title(t: String) -> void:
	title_text = t
