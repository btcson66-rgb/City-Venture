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
var accessibility_scroll: ScrollContainer


func _ready() -> void:
	add_to_group("accessible_modal")
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	# full-screen management screens get an almost opaque backing so the world doesn't show through
	dim.color = Color(0.03, 0.06, 0.12, maxf(dim_alpha, 0.88) if panel_size.x >= 560.0 else dim_alpha)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	panel = UIK.panel("ui/panel", 8)
	panel.custom_minimum_size = Vector2.ZERO
	panel.size = panel_size
	_fit_panel()
	get_viewport().size_changed.connect(_fit_panel)
	Preferences.changed.connect(_fit_panel)   # UI scale and font changes; no per-frame refit
	add_child(panel)
	var outer := UIK.vbox(5)
	panel.add_child(outer)
	header = UIK.hbox(5)
	outer.add_child(header)
	if icon_name != "":
		header.add_child(UIK.icon(icon_name, 16))
	var t := UIK.title(title_text, 12)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.clip_text = true
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
	accessibility_scroll = ScrollContainer.new()
	accessibility_scroll.name = "AccessibleContent"
	accessibility_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(accessibility_scroll)
	body = UIK.vbox(4)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	accessibility_scroll.add_child(body)
	footer = UIK.hbox(6)
	footer.alignment = BoxContainer.ALIGNMENT_END
	var footer_scroll := ScrollContainer.new()
	footer_scroll.name = "FooterActions"
	footer_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	footer_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_scroll.add_child(footer)
	outer.add_child(footer_scroll)
	build()
	_built = true
	_fit_panel.call_deferred()
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
	_fit_panel()
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


## Viewport coordinates change with UI scale. Content can grow inside the scroll, never the panel.
func _fit_panel() -> void:
	if not is_instance_valid(panel):
		return
	var available := get_viewport_rect().size
	var desired := Vector2(panel_size.x, panel_size.y if panel_size.y > 0.0 else 280.0)
	if InputAccess.touch_mode:
		desired.y = maxf(desired.y, minf(900.0, available.y * 0.78))
	var target := desired.min((available - Vector2(16, 16)).max(Vector2(100, 80)))
	if panel.size != target:
		panel.size = target
	var spot := (available - panel.size) / 2.0
	if panel.position != spot:
		panel.position = spot


## Some modals resize their own panel after building (decision cards, pinned footers); the guarded fit puts it back
## without touching the layout when nothing changed.
func _process(_delta: float) -> void:
	_fit_panel()


func close() -> void:
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if closable and (event.is_action_pressed("pause") or event.is_action_pressed("cancel")):
		get_viewport().set_input_as_handled()
		close()


func set_title(t: String) -> void:
	title_text = t
