class_name UIK
extends RefCounted
## UI kit: Neo-Civic theme (pixel 9-slice panels, Pixelify titles, Inter body) and widget factories.
## Base resolution is 640×360; sizes here are in base pixels.

static var _theme: Theme
static var _body_font: FontVariation
static var _bold_font: FontVariation
static var _title_font: FontVariation


static func body_font() -> Font:
	if _body_font == null:
		_body_font = FontVariation.new()
		_body_font.base_font = Art.font_body
		_body_font.variation_opentype = {"wght": 520}
	return _body_font


static func bold_font() -> Font:
	if _bold_font == null:
		_bold_font = FontVariation.new()
		_bold_font.base_font = Art.font_body
		_bold_font.variation_opentype = {"wght": 700}
	return _bold_font


static func title_font() -> Font:
	if _title_font == null:
		_title_font = FontVariation.new()
		_title_font.base_font = Art.font_title
		_title_font.variation_opentype = {"wght": 600}
	return _title_font


static func tex_box(path: String, margin := 6, content := 5) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = Art.tex(path)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	sb.content_margin_left = content
	sb.content_margin_right = content
	sb.content_margin_top = content - 1
	sb.content_margin_bottom = content - 1
	return sb


static func flat(bg: Color, border := Color(0, 0, 0, 0), bw := 0, radius := 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	return sb


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 8
	t.set_color("font_color", "Label", Art.C_WHITE)
	t.set_stylebox("panel", "Panel", tex_box("ui/panel", 6, 6))
	t.set_stylebox("panel", "PanelContainer", tex_box("ui/panel", 6, 6))
	for st in [["normal", "ui/button"], ["hover", "ui/button_hover"], ["pressed", "ui/button_pressed"], ["disabled", "ui/button_disabled"], ["focus", "ui/button_hover"]]:
		var sb: StyleBox = tex_box(st[1], 4, 5)
		sb.content_margin_top = 2
		sb.content_margin_bottom = 3
		if st[0] == "focus":
			sb = StyleBoxEmpty.new()
		t.set_stylebox(st[0], "Button", sb)
	t.set_color("font_color", "Button", Art.C_WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Art.C_SKY)
	t.set_color("font_disabled_color", "Button", Art.C_DIM)
	t.set_font("font", "Button", bold_font())
	t.set_font_size("font_size", "Button", 8)
	t.set_stylebox("normal", "LineEdit", tex_box("ui/field", 4, 5))
	t.set_stylebox("focus", "LineEdit", tex_box("ui/field", 4, 5))
	t.set_color("font_color", "LineEdit", Art.C_WHITE)
	t.set_color("caret_color", "LineEdit", Art.C_SKY)
	t.set_stylebox("background", "ProgressBar", tex_box("ui/bar_bg", 2, 1))
	t.set_stylebox("fill", "ProgressBar", tex_box("ui/bar_fill", 2, 1))
	t.set_stylebox("panel", "TooltipPanel", tex_box("ui/tooltip", 4, 4))
	t.set_color("font_color", "TooltipLabel", Art.C_NAVY_800)
	var sbar := flat(Color8(20, 30, 48), Color8(20, 30, 48))
	var grab := flat(Art.C_NAVY_500, Art.C_NAVY_500)
	grab.content_margin_left = 2
	grab.content_margin_right = 2
	for w in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", w, sbar)
		t.set_stylebox("grabber", w, grab)
		t.set_stylebox("grabber_highlight", w, flat(Art.C_BLUE_DARK))
		t.set_stylebox("grabber_pressed", w, flat(Art.C_BLUE))
	t.set_stylebox("normal", "OptionButton", tex_box("ui/button", 4, 5))
	t.set_stylebox("hover", "OptionButton", tex_box("ui/button_hover", 4, 5))
	t.set_stylebox("pressed", "OptionButton", tex_box("ui/button_pressed", 4, 5))
	t.set_stylebox("panel", "PopupMenu", tex_box("ui/panel", 6, 4))
	t.set_stylebox("hover", "PopupMenu", flat(Art.C_BLUE_DARK))
	t.set_font_size("font_size", "PopupMenu", 8)
	t.set_constant("separation", "HBoxContainer", 4)
	t.set_constant("separation", "VBoxContainer", 3)
	t.set_stylebox("separator", "HSeparator", flat(Art.C_NAVY_500))
	t.set_constant("separation", "HSeparator", 4)
	t.set_stylebox("panel", "PanelContainer", tex_box("ui/panel", 6, 6))
	_theme = t
	return t


# ---------------------------------------------------------------- factories
static func label(text: String, size := 8, color := Art.C_WHITE, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold:
		l.add_theme_font_override("font", bold_font())
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func title(text: String, size := 12, color := Art.C_WHITE) -> Label:
	var l := label(text, size, color)
	l.add_theme_font_override("font", title_font())
	return l


static func wrap(text: String, size := 8, color := Art.C_WHITE, width := 200.0) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	return l


## Crisp text placed in the world (signs, name tags).
## Make a purely informational widget (toast, card) transparent to the mouse, children included,
## so it can never swallow a click meant for the UI underneath.
static func ignore_mouse(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		ignore_mouse(c)


static func world_label(text: String, size := 6, color := Color(1, 1, 1)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", title_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color8(12, 18, 30))
	l.add_theme_constant_override("outline_size", 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.clip_text = false
	return l


static func button(text: String, cb: Callable = Callable(), style := "", min_w := 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	if min_w > 0:
		b.custom_minimum_size = Vector2(min_w, 0)
	if style == "primary":
		b.add_theme_stylebox_override("normal", tex_box("ui/button_primary", 4, 5))
		b.add_theme_stylebox_override("hover", tex_box("ui/button_primary_hover", 4, 5))
	elif style == "danger":
		b.add_theme_stylebox_override("normal", tex_box("ui/button_danger", 4, 5))
	elif style == "tab":
		b.add_theme_stylebox_override("normal", tex_box("ui/tab", 4, 5))
	elif style == "tab_active":
		b.add_theme_stylebox_override("normal", tex_box("ui/tab_active", 4, 5))
		b.add_theme_stylebox_override("hover", tex_box("ui/tab_active", 4, 5))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func icon(name: String, size := 16) -> TextureRect:
	var r := TextureRect.new()
	r.texture = Art.icon(name)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func panel(style := "ui/panel", margin := 6) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", tex_box(style, 6, margin))
	return p


static func hbox(sep := 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep := 3) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func spacer(w := 0.0, h := 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(w, h)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func expand() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func sep() -> HSeparator:
	return HSeparator.new()


static func money_color(v: float) -> Color:
	return Art.C_GREEN if v > 0.005 else (Art.C_RED if v < -0.005 else Art.C_MUTED)


## "Label ....... value" row used in finance tables.
static func kv(k: String, v: String, vcolor := Art.C_WHITE, size := 8, bold := false) -> HBoxContainer:
	var h := hbox(4)
	var kl := label(k, size, Art.C_MUTED if not bold else Art.C_WHITE, bold)
	kl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(kl)
	var vl := label(v, size, vcolor, bold)
	vl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(vl)
	return h


static func scroll(child: Control, min_size := Vector2(100, 100)) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.custom_minimum_size = min_size
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func chip(text: String, col: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := flat(col.darkened(0.55), col, 1, 0)
	sb.content_margin_left = 3
	sb.content_margin_right = 3
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	p.add_theme_stylebox_override("panel", sb)
	p.add_child(label(text, 7, col.lightened(0.3), true))
	return p


static func card(inner: Control, style := "ui/card") -> PanelContainer:
	var p := panel(style, 5)
	p.add_child(inner)
	return p


static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()
