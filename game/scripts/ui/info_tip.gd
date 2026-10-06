class_name InfoTip
extends PanelContainer
## A small "!" badge next to a business idea the player may not know yet (escrow, Net 60, gross margin...).
## Hover shows what it is and why it matters for your business; a click pins the same card, for players on a
## trackpad or a touch screen. Text lives in data/help/glossary.json ({title, what, why}), so it is translated
## like everything else. A badge you haven't opened yet is gold; once read it turns quiet.

var tip_id := ""
var _mark: Label
var _pinned: PopupPanel


static func make(id: String) -> InfoTip:
	var t := InfoTip.new()
	t.tip_id = id
	return t


static func entry(id: String) -> Dictionary:
	return DataDB.glossary.get(id, {})


static func seen(id: String) -> bool:
	return GameState.has_game() and bool(GameState.data.get("tips_seen", {}).get(id, false))


static func mark_seen(id: String) -> void:
	if GameState.has_game():
		if not GameState.data.has("tips_seen"):
			GameState.data["tips_seen"] = {}
		GameState.data["tips_seen"][id] = true


func _ready() -> void:
	var e := entry(tip_id)
	if e.is_empty():
		push_warning("InfoTip: no glossary entry " + tip_id)
		visible = false
		return
	custom_minimum_size = Vector2(11, 11)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_HELP
	tooltip_text = I18n.t(str(e.get("title", tip_id)))   # non-empty so Godot asks for the custom tooltip below
	_mark = UIK.label("!", 8, Art.C_NAVY_900, true)
	_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_mark)
	_restyle()


func _restyle() -> void:
	var fresh := not seen(tip_id)
	var sb := UIK.flat(Art.C_GOLD if fresh else Art.C_NAVY_500, Art.C_WHITE if fresh else Art.C_DIM, 1, 2)
	sb.content_margin_left = 2
	sb.content_margin_right = 2
	add_theme_stylebox_override("panel", sb)
	if _mark != null:
		_mark.add_theme_color_override("font_color", Art.C_NAVY_900 if fresh else Art.C_SKY)


## The card: title, what it is, and why it matters to you.
static func card(id: String, width := 250.0) -> Control:
	var e := entry(id)
	var p := PanelContainer.new()
	var sb := UIK.flat(Color8(18, 31, 49, 245), Art.C_GOLD, 1, 3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 5
	p.add_theme_stylebox_override("panel", sb)
	var v := UIK.vbox(2)
	p.add_child(v)
	v.add_child(UIK.label(I18n.t(str(e.get("title", id))), 8, Art.C_GOLD, true))
	if str(e.get("what", "")) != "":
		v.add_child(UIK.wrap(I18n.t(str(e["what"])), 7, Art.C_WHITE, width))
	if str(e.get("why", "")) != "":
		var w := UIK.wrap(I18n.t("Why it matters: ") + I18n.t(str(e["why"])), 7, Art.C_SKY, width)
		v.add_child(w)
	return p


func _make_custom_tooltip(_for_text: String) -> Object:
	mark_seen(tip_id)
	_restyle.call_deferred()
	return card(tip_id)


func _gui_input(ev: InputEvent) -> void:
	if ev.is_action_pressed("ui_accept") or (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		accept_event()
		_pin()


## Click: keep the card open next to the badge until the player clicks elsewhere.
func _pin() -> void:
	mark_seen(tip_id)
	_restyle()
	if is_instance_valid(_pinned):
		_pinned.queue_free()
	_pinned = PopupPanel.new()
	_pinned.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	_pinned.add_child(card(tip_id))
	add_child(_pinned)
	var at := Vector2i(get_screen_position() + Vector2(size.x + 4, 0))
	_pinned.popup(Rect2i(at, Vector2i.ZERO))
	_pinned.reset_size()
	# keep it on screen
	var vr := get_viewport().get_visible_rect().size
	var ps := _pinned.size
	if at.x + ps.x > int(vr.x):
		at.x = maxi(0, int(get_screen_position().x) - ps.x - 4)
	if at.y + ps.y > int(vr.y):
		at.y = maxi(0, int(vr.y) - ps.y)
	_pinned.position = at
