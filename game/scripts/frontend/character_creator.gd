class_name CharacterCreator
extends Control
## Character creation (Handoff §36, Board B). Everything here is cosmetic: no stats, no bonuses.

var app: Dictionary
var outfit := "startup_casual"
var name_edit: LineEdit
var tab := "body"
var stage: Node2D
var rig: CharacterRig
var portrait: PortraitView
var dir_idx := 0
var expr_idx := 0
var views_rigs: Array = []
var _scroll_content: Control
var options_box: VBoxContainer
var tab_box: HBoxContainer
const DIRS := ["down", "right", "up", "left"]
const EXPRS := ["neutral", "happy", "thinking", "surprised"]


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	size = get_viewport_rect().size
	theme = UIK.theme()
	app = GameState.default_appearance()
	var bg := ColorRect.new()
	bg.color = Art.C_NAVY_900
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# preview: Board H wardrobe room behind a Board A-style FRONT / SIDE / BACK sheet
	var room := TextureRect.new()
	room.texture = Art.tex("backdrops/wardrobe")
	room.position = Vector2(14, 44)
	room.size = Vector2(200, 250)
	room.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	room.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(room)
	var wash := ColorRect.new()
	wash.color = Color(0.03, 0.06, 0.13, 0.5)
	wash.position = room.position
	wash.size = room.size
	add_child(wash)
	var floor_band := ColorRect.new()
	floor_band.color = Color(0.03, 0.06, 0.13, 0.55)
	floor_band.position = Vector2(14, 230)
	floor_band.size = Vector2(200, 64)
	add_child(floor_band)
	add_child(_at(UIK.title("CREATE YOUR CHARACTER", 14), Vector2(14, 12)))
	add_child(_at(UIK.label("Looks only. Your business choices decide everything else.", 8, Art.C_SKY), Vector2(230, 18)))
	stage = Node2D.new()
	stage.position = Vector2(0, 0)
	add_child(stage)
	var views := [["down", "FRONT"], ["right", "SIDE"], ["up", "BACK"]]
	for i in views.size():
		var holder := Node2D.new()
		holder.position = Vector2(50 + i * 64, 284)
		holder.scale = Vector2(2, 2)
		stage.add_child(holder)
		var r := CharacterRig.new()
		r.name = "View_" + views[i][1]
		holder.add_child(r)
		views_rigs.append([r, views[i][0]])
		var lb := UIK.label(views[i][1], 6, Art.C_SKY, true)
		lb.position = Vector2(18 + i * 64, 285)
		lb.size = Vector2(64, 8)
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(lb)
	rig = views_rigs[0][0]
	var pf := UIK.panel("ui/panel_glass", 2)
	pf.position = Vector2(56, 48)
	add_child(pf)
	portrait = PortraitView.new()
	portrait.custom_minimum_size = Vector2(112, 112)
	portrait.size = Vector2(112, 112)
	pf.add_child(portrait)
	var rot := UIK.hbox(3)
	rot.position = Vector2(56, 166)
	rot.add_child(UIK.button("Expression ▶", func(): expr_idx = (expr_idx + 1) % 4; _refresh(), "", 116))
	add_child(rot)
	add_child(_at(UIK.label("NAME", 7, Art.C_DIM, true), Vector2(14, 300)))
	name_edit = LineEdit.new()
	name_edit.text = "Alex Chen"
	name_edit.max_length = 20
	name_edit.position = Vector2(14, 310)
	name_edit.size = Vector2(200, 18)
	name_edit.name = "NameEdit"
	add_child(name_edit)
	var right := UIK.panel("ui/panel", 8)
	right.position = Vector2(228, 40)
	right.size = Vector2(400, 272)
	right.custom_minimum_size = Vector2(400, 272)
	add_child(right)
	var rv := UIK.vbox(5)
	right.add_child(rv)
	tab_box = UIK.hbox(3)
	rv.add_child(tab_box)
	rv.add_child(UIK.sep())
	options_box = UIK.vbox(5)
	rv.add_child(options_box)
	var bottom := UIK.hbox(6)
	bottom.position = Vector2(228, 322)
	add_child(bottom)
	bottom.add_child(UIK.button("Randomize", _randomize, "", 100))
	bottom.add_child(UIK.button("Back", func(): SceneRouter.go_menu(), "", 70))
	var go := UIK.button("Start in Aurelia  →", _start, "primary", 200)
	go.name = "Start"
	bottom.add_child(go)
	_refresh()
	# Touch targets enlarge option rows: both axes remain reachable on narrow mobile viewports.
	var children := get_children()
	var scroll := ScrollContainer.new()
	scroll.name = "CharacterScroll"
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scroll)
	_scroll_content = Control.new()
	_scroll_content.custom_minimum_size = Vector2(640, 390)
	scroll.add_child(_scroll_content)
	for child in children:
		child.reparent(_scroll_content)


func _process(_delta: float) -> void:
	size = get_viewport_rect().size
	if _scroll_content == null:
		return
	var extent := Vector2(640, 390)
	for child in _scroll_content.get_children():
		if child is Control and child.anchor_right == 0 and child.anchor_bottom == 0:
			extent = extent.max(child.position + child.size + Vector2(8, 8))
	_scroll_content.custom_minimum_size = extent


func _at(c: Control, p: Vector2) -> Control:
	c.position = p
	return c


func _refresh() -> void:
	for vr in views_rigs:
		vr[0].setup(app, outfit)
		vr[0].set_dir(vr[1])
		vr[0].set_expression(EXPRS[expr_idx])
	portrait.setup_character(app, outfit)
	portrait.set_expr(EXPRS[expr_idx])
	UIK.clear(tab_box)
	for t in [["body", "Body"], ["face", "Face"], ["hair", "Hair"], ["outfit", "Outfit"]]:
		var b := UIK.button(t[1], func(): tab = t[0]; _refresh(), "tab_active" if tab == t[0] else "tab", 80)
		b.name = "Tab_" + t[0]
		tab_box.add_child(b)
	UIK.clear(options_box)
	match tab:
		"body":
			_cycle("Presentation", "presentations", "presentation")
			_swatches("Skin tone", "skin_tones", "skin")
			options_box.add_child(UIK.wrap("Masculine, feminine or neutral changes the body shape only. There are no ability differences.", 7, Art.C_DIM, 380))
		"face":
			_cycle("Face shape", "face_shapes", "face")
			_cycle("Eye shape", "eye_shapes", "eye_shape")
			_swatches("Eye colour", "eye_colors", "eye_color")
			_cycle("Eyebrows", "eyebrows", "brows")
			_cycle("Mouth", "mouths", "mouth")
		"hair":
			_cycle("Hairstyle", "hairstyles", "hair")
			_swatches("Hair colour", "hair_colors", "hair_color")
		"outfit":
			var h := UIK.hbox(4)
			h.add_child(_lbl("Outfit"))
			for o in DataDB.character.get("outfits", []):
				h.add_child(UIK.button(o["name"], func(): outfit = o["id"]; _refresh(), "tab_active" if outfit == o["id"] else "tab"))
			options_box.add_child(h)
			_cycle("Accessory", "accessories", "accessory")
			options_box.add_child(UIK.wrap("Visit Threadline on Shopping Street to browse the outfits available now.", 7, Art.C_DIM, 380))


func _lbl(t: String) -> Label:
	var l := UIK.label(t, 8, Art.C_MUTED, true)
	l.custom_minimum_size = Vector2(90, 0)
	return l


func _cycle(title: String, group: String, key: String) -> void:
	var opts: Array = DataDB.character.get(group, [])
	var idx := 0
	for i in opts.size():
		if opts[i]["id"] == app.get(key, ""):
			idx = i
	var h := UIK.hbox(4)
	h.add_child(_lbl(title))
	h.add_child(UIK.button("◀", func(): app[key] = opts[(idx + opts.size() - 1) % opts.size()]["id"]; _refresh()))
	var v := UIK.label(opts[idx]["name"], 9, Art.C_WHITE, true)
	v.custom_minimum_size = Vector2(110, 0)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(v)
	var nb := UIK.button("▶", func(): app[key] = opts[(idx + 1) % opts.size()]["id"]; _refresh())
	nb.name = "Next_" + key
	h.add_child(nb)
	options_box.add_child(h)


func _swatches(title: String, group: String, key: String) -> void:
	var h := UIK.hbox(3)
	h.add_child(_lbl(title))
	for o in DataDB.character.get(group, []):
		var b := Button.new()
		b.custom_minimum_size = Vector2(18, 18)
		b.focus_mode = Control.FOCUS_NONE
		var sb := UIK.flat(Color(o["color"]), Color.WHITE if app.get(key, "") == o["id"] else Art.C_NAVY_500, 2 if app.get(key, "") == o["id"] else 1)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", UIK.flat(Color(o["color"]).lightened(0.15), Color.WHITE, 1))
		b.tooltip_text = o["name"]
		b.pressed.connect(func(): app[key] = o["id"]; _refresh())
		h.add_child(b)
	options_box.add_child(h)


func _randomize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	app = Art.random_appearance(rng)
	outfit = ["startup_casual", "office_professional", "home"][rng.randi_range(0, 2)]
	_refresh()


func _start() -> void:
	var n := name_edit.text.strip_edges()
	if n == "":
		n = "Alex Chen"
	SceneRouter.go_arrival({"name": n, "appearance": app.duplicate(), "outfit": outfit})
