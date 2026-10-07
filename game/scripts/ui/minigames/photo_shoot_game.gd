class_name PhotoShootGame
extends MiniGame
## Shoot your own product photos for a listing. Set up the table (backdrop, light, a styling prop), drag the product
## into place, zoom until it fills the frame nicely, then press the shutter when the focus needle is in the green.
## Three shots; the best one goes on the listing. Photo quality moves demand (Ecommerce.lambda_day, photo_q).

const BACKDROPS := [["white", "White sweep"], ["wood", "Wood desk"], ["pastel", "Pastel card"], ["dark", "Dark slate"]]
const LIGHTS := [["window", "Window light"], ["ring", "Ring light"], ["ceiling", "Ceiling lamp"]]
const STYLING := [["none", "Nothing"], ["plant", "Small plant"], ["notebook", "Notebook"]]
## What suits each product (backdrops, styling prop). Anything else still works, just less well.
const SUITS := {"wireless_earbuds": [["white", "dark"], "notebook"], "water_bottle": [["pastel", "white"], "plant"],
	"desk_lamp": [["wood", "dark"], "notebook"], "phone_stand": [["wood", "white"], "plant"], "solar_lamp": [["wood", "white"], "plant"]}
const FRAME := Vector2(300, 196)

var product := ""
var backdrop := "white"
var light := "window"
var styling := "none"
var zoom := 4.0
var pos := Vector2(120, 70)          # product top-left inside the frame
var shots: Array = []                 # [{score, parts}]
var _needle := 0.0
var _dragging := false
var frame_box: Control
var product_rect: TextureRect
var needle_bar: Control


func _init(product_id := "wireless_earbuds") -> void:
	super._init()
	product = product_id
	title_text = I18n.t("Photo shoot — %s") % I18n.t(str(DataDB.product(product_id).get("name", product_id)))
	icon_name = "star"
	rounds = 3
	round_time = 0.0


func intro_lines() -> Array:
	return ["Set up the shot: pick a backdrop, the light and an optional styling prop.",
		"Drag the product into the frame and zoom so it fills about a third of the picture. Keep it inside the edges.",
		"Press the shutter when the focus needle is in the green. You get three shots; the best one goes on your listing.",
		"Soft light and a backdrop that suits the product sell better. Better photos, more orders."]


func round_name() -> String:
	return "Shot %d / %d"


## The listing gets the best shot, not the average.
func score() -> float:
	var best := 0.0
	for s in shots:
		best = maxf(best, float(s["score"]))
	return best


func score_so_far() -> float:
	return score()


func build_round() -> void:
	UIK.clear(stage)
	var h := UIK.hbox(10)
	stage.add_child(h)
	# viewfinder
	frame_box = Control.new()
	frame_box.name = "PhotoFrame"
	frame_box.custom_minimum_size = FRAME
	frame_box.clip_contents = true
	frame_box.mouse_filter = Control.MOUSE_FILTER_PASS
	frame_box.draw.connect(_draw_frame)
	frame_box.gui_input.connect(_frame_input)
	h.add_child(frame_box)
	product_rect = TextureRect.new()
	product_rect.texture = Art.tex(DataDB.product_icon(product))
	product_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	product_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	product_rect.stretch_mode = TextureRect.STRETCH_SCALE
	product_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame_box.add_child(product_rect)
	_place_product()
	var overlay := Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay.bind(overlay))
	frame_box.add_child(overlay)
	# controls
	var c := UIK.vbox(4)
	h.add_child(c)
	c.add_child(choice_row("Backdrop", BACKDROPS.slice(0, 2), backdrop, _choose.bind("backdrop"), "Backdrop", 0))
	c.add_child(choice_row("", BACKDROPS.slice(2), backdrop, _choose.bind("backdrop"), "Backdrop", 0))
	c.add_child(choice_row("Lighting", LIGHTS.slice(0, 2), light, _choose.bind("light"), "Light"))
	c.add_child(choice_row("", LIGHTS.slice(2), light, _choose.bind("light"), "Light"))
	c.add_child(choice_row("Styling", STYLING, styling, _choose.bind("styling"), "Styling"))
	var zr := UIK.hbox(3)
	var zl := UIK.label("Zoom", 8, Art.C_MUTED, true)
	zl.custom_minimum_size = Vector2(70, 0)
	zr.add_child(zl)
	var zm := UIK.button("−", _zoom.bind(-0.5), "", 26)
	zm.name = "ZoomOut"
	zr.add_child(zm)
	var zp := UIK.button("+", _zoom.bind(0.5), "", 26)
	zp.name = "ZoomIn"
	zr.add_child(zp)
	zr.add_child(UIK.label(I18n.t("Drag the product in the frame"), 7, Art.C_DIM))
	c.add_child(zr)
	var fr := UIK.hbox(4)
	var fl := UIK.label("Focus", 8, Art.C_MUTED, true)
	fl.custom_minimum_size = Vector2(70, 0)
	fr.add_child(fl)
	needle_bar = Control.new()
	needle_bar.custom_minimum_size = Vector2(150, 12)
	needle_bar.draw.connect(_draw_needle)
	fr.add_child(needle_bar)
	c.add_child(fr)
	var shoot := UIK.button("◉  Shutter", _shoot, "primary", 150)
	shoot.name = "Shutter"
	c.add_child(shoot)
	for i in shots.size():
		var s: Dictionary = shots[i]
		var l := UIK.label(I18n.t("Shot %d: %d%%  %s") % [i + 1, int(round(float(s["score"]) * 100.0)), str(s["note"])], 7, Art.C_SKY)
		l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		c.add_child(l)


func _choose(val: String, what: String) -> void:
	set(what, val)
	build_round()


func _zoom(d: float) -> void:
	var c := pos + Vector2(8, 8) * zoom
	zoom = clampf(zoom + d, 1.5, 9.0)
	pos = c - Vector2(8, 8) * zoom
	_place_product()


func _place_product() -> void:
	if product_rect == null or not is_instance_valid(product_rect):
		return
	product_rect.size = Vector2(16, 16) * zoom
	product_rect.position = pos.round()
	if frame_box != null:
		frame_box.queue_redraw()


func _frame_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = (e as InputEventMouseButton).pressed
	elif e is InputEventMouseMotion and _dragging:
		pos += (e as InputEventMouseMotion).relative
		pos = pos.clamp(-Vector2(16, 16) * zoom * 0.8, FRAME - Vector2(16, 16) * zoom * 0.2)
		_place_product()
	elif e is InputEventMouseButton and (e as InputEventMouseButton).pressed:
		var mb := (e as InputEventMouseButton).button_index
		if mb == MOUSE_BUTTON_WHEEL_UP:
			_zoom(0.5)
		elif mb == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom(-0.5)


func _process(delta: float) -> void:
	super._process(delta)
	_needle += delta * PersonalLife.response_speed()
	if needle_bar != null and is_instance_valid(needle_bar):
		needle_bar.queue_redraw()


func needle() -> float:
	return 0.5 if practice_only else 0.5 + 0.5 * sin(_needle * 2.6)


# ------------------------------------------------------------------ drawing
func _backdrop_colors() -> Array:
	match backdrop:
		"wood":
			return [Color8(214, 196, 170), Color8(150, 104, 64)]
		"pastel":
			return [Color8(250, 214, 222), Color8(236, 196, 206)]
		"dark":
			return [Color8(46, 50, 60), Color8(30, 32, 40)]
	return [Color8(248, 248, 246), Color8(232, 232, 230)]


func _draw_frame() -> void:
	var cols := _backdrop_colors()
	var table_y := FRAME.y * 0.62
	frame_box.draw_rect(Rect2(Vector2.ZERO, Vector2(FRAME.x, table_y)), cols[0])
	frame_box.draw_rect(Rect2(Vector2(0, table_y), Vector2(FRAME.x, FRAME.y - table_y)), cols[1])
	if backdrop == "wood":
		for i in 6:
			frame_box.draw_line(Vector2(0, table_y + 8 + i * 12), Vector2(FRAME.x, table_y + 6 + i * 12), Color8(130, 88, 52), 1.0)
	# styling prop behind the product
	if styling == "plant":
		frame_box.draw_rect(Rect2(FRAME.x - 58, table_y - 12, 22, 20), Color8(196, 120, 80))
		frame_box.draw_circle(Vector2(FRAME.x - 47, table_y - 22), 14, Color8(80, 140, 80))
	elif styling == "notebook":
		frame_box.draw_rect(Rect2(20, table_y + 18, 70, 46), Color8(40, 60, 110))
		frame_box.draw_rect(Rect2(24, table_y + 20, 62, 42), Color8(230, 232, 236), false, 1.0)
	# the product's shadow on the table
	var pr := Rect2(pos, Vector2(16, 16) * zoom)
	var hard := light == "ceiling"
	frame_box.draw_rect(Rect2(pr.position.x + (0 if hard else 6), pr.end.y - 3, pr.size.x, 5 if hard else 8),
		Color(0, 0, 0, 0.55 if hard else 0.18))


func _draw_overlay(o: Control) -> void:
	# light
	match light:
		"ceiling":
			o.draw_rect(Rect2(Vector2.ZERO, FRAME), Color(0.1, 0.08, 0.02, 0.28))
			o.draw_circle(Vector2(FRAME.x / 2.0, -30), 90, Color(1, 0.95, 0.7, 0.18))
		"ring":
			o.draw_arc(pos + Vector2(8, 8) * zoom, 8 * zoom + 10, 0, TAU, 40, Color(1, 1, 1, 0.22), 6.0)
		_:
			for i in 8:
				o.draw_rect(Rect2(Vector2(i * 12, 0), Vector2(12, FRAME.y)), Color(1, 0.98, 0.9, 0.12 - i * 0.014))
	# rule-of-thirds guides and the frame
	var g := Color(1, 1, 1, 0.35)
	for i in [1, 2]:
		o.draw_line(Vector2(FRAME.x * i / 3.0, 0), Vector2(FRAME.x * i / 3.0, FRAME.y), g, 1.0)
		o.draw_line(Vector2(0, FRAME.y * i / 3.0), Vector2(FRAME.x, FRAME.y * i / 3.0), g, 1.0)
	o.draw_rect(Rect2(Vector2(1, 1), FRAME - Vector2(2, 2)), Color(0.1, 0.1, 0.12), false, 2.0)


func _draw_needle() -> void:
	var w := needle_bar.size.x
	needle_bar.draw_rect(Rect2(0, 3, w, 6), Color8(60, 66, 80))
	needle_bar.draw_rect(Rect2(w * 0.4, 3, w * 0.2, 6), Art.C_GREEN)
	var x := w * needle()
	needle_bar.draw_rect(Rect2(x - 1.5, 0, 3, 12), Art.C_GOLD)


# ------------------------------------------------------------------ scoring
## Score the current setup with a given focus accuracy (0..1). Returns {score, note}.
func rate(focus: float) -> Dictionary:
	var pr := Rect2(pos, Vector2(16, 16) * zoom)
	var inside := Rect2(Vector2(4, 4), FRAME - Vector2(8, 8)).encloses(pr)
	var fill := (pr.size.x * pr.size.y) / (FRAME.x * FRAME.y)
	var framing := 0.0
	if inside:
		framing = 1.0 if fill >= 0.12 and fill <= 0.4 else (0.35 + 0.65 * clampf(fill / 0.12, 0.0, 1.0) if fill < 0.12 else clampf(1.0 - (fill - 0.4) * 2.0, 0.3, 1.0))
	var c := pr.get_center() / FRAME
	var best_d := 1.0
	for p in [Vector2(0.5, 0.5), Vector2(1 / 3.0, 1 / 3.0), Vector2(2 / 3.0, 1 / 3.0), Vector2(1 / 3.0, 2 / 3.0), Vector2(2 / 3.0, 2 / 3.0)]:
		best_d = minf(best_d, c.distance_to(p))
	var comp := clampf(1.0 - best_d / 0.25, 0.0, 1.0)
	var suits: Array = SUITS.get(product, [["white"], "none"])
	var bd := 1.0 if backdrop in suits[0] else (0.4 if backdrop == "dark" else 0.7)
	var li := {"window": 1.0, "ring": 0.9, "ceiling": 0.35}.get(light, 0.6) as float
	var s := framing * 0.35 + comp * 0.1 + bd * 0.2 + li * 0.2 + focus * 0.15
	if styling != "none":
		s += 0.05 if styling == suits[1] else -0.03
	var notes := []
	if not inside:
		notes.append(I18n.t("cut off at the edge"))
	elif fill < 0.12:
		notes.append(I18n.t("too small in the frame"))
	elif fill > 0.4:
		notes.append(I18n.t("too tight"))
	if li < 0.5:
		notes.append(I18n.t("harsh light"))
	if bd < 0.8:
		notes.append(I18n.t("backdrop doesn't suit it"))
	if focus < 0.6:
		notes.append(I18n.t("a bit blurry"))
	return {"score": clampf(s, 0.0, 1.0), "note": ", ".join(notes) if not notes.is_empty() else I18n.t("looks great")}


func _shoot() -> void:
	if phase != "play":
		return
	var focus := clampf(1.0 - absf(needle() - 0.5) * 2.2, 0.0, 1.0)
	var r := rate(focus)
	shots.append(r)
	award(float(r["score"]))
	flash(I18n.t("Click! %d%% (%s)") % [int(round(float(r["score"]) * 100.0)), str(r["note"])], float(r["score"]) >= 0.6)
	next_round()


func result_lines() -> Array:
	var out := []
	for i in shots.size():
		out.append(I18n.t("Shot %d: %d%% (%s)") % [i + 1, int(round(float(shots[i]["score"]) * 100.0)), str(shots[i]["note"])])
	out.append(I18n.t("The best shot goes on your listing. Photo quality affects how many people buy."))
	return out


func verdict(s: float) -> String:
	if s >= 0.8:
		return "A photo that sells."
	if s >= 0.55:
		return "Decent. Customers will click."
	return "Amateur-looking. It will cost you some sales; you can reshoot later."


func autoplay(quality := 0.9) -> void:
	shots = [{"score": clampf(quality, 0.0, 1.0), "note": "autoplay"}]
	super.autoplay(quality)
