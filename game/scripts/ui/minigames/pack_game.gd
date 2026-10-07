class_name PackGame
extends MiniGame
## Pack orders by hand at the packing table: pick a box that fits, pad it, tape the three seams, and stick on the label
## that matches the order. Up to five orders are packed by hand per session; any more are packed the same way once you
## have the rhythm. Pack quality follows each order: poor padding arrives damaged (returns), a wrong label arrives late.

const BOXES := [["small", "Small box"], ["medium", "Medium box"], ["large", "Large box"]]
const PAD_ZONE := [0.6, 0.85]
const DISTRICTS := ["Riverside", "Startup Hub", "Civic Center", "Financial District", "Shopping Street", "Harbor"]
const HAND_MAX := 5

var placements: Array = []
var selected := 0
var rotated := false

var orders: Array = []        # the orders being packed by hand
var total_orders := 0
var box := ""
var pad := 0.0
var seams := [false, false, false]
var label := -1
var labels: Array = []        # [{text, ok}]
var quality := {}             # order id → {q, label_ok}
var rng := RandomNumberGenerator.new()


func _init(order_list: Array = []) -> void:
	super._init()
	title_text = "Packing table"
	help_key = "packing"
	panel_size = Vector2(620, 340)
	icon_name = "parcel"
	total_orders = order_list.size()
	orders = order_list.slice(0, HAND_MAX)
	rounds = maxi(1, orders.size())
	round_time = 0.0
	rng.seed = Clock.now() * 29 + 1


func intro_lines() -> Array:
	var l := ["Select an item, rotate it if needed, then click a free grid cell. Every item must fit before sealing.",
		"Larger boxes cost more in materials and dimensional postage. Fragile goods need padding.",
		"Pack each order by hand, in four steps: a box that fits, padding, tape on all three seams, and the right label.",
		"Padding should reach the green zone. Too little and things arrive broken; that means returns and bad reviews.",
		"Check the label against the order: the wrong one sends the parcel to the wrong address and it arrives late."]
	if total_orders > HAND_MAX:
		l.append(I18n.t("You pack %d by hand; the other %d use the skilled automatic packing policy.") % [HAND_MAX, total_orders - HAND_MAX])
	return l


func round_name() -> String:
	return "Order %d / %d"


func _order() -> Dictionary:
	return orders[round_i]


func need_box() -> String:
	return Packing.smallest(_order())


func build_round() -> void:
	# A plain Control cannot report its children's height to the modal scroll.
	var old_stage := stage
	stage = UIK.vbox(4)
	stage.name = "PackingStage"
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	old_stage.get_parent().add_child(stage)
	old_stage.get_parent().move_child(stage, old_stage.get_index())
	old_stage.queue_free()
	box = ""
	placements = []
	selected = 0
	rotated = false
	pad = 0.0
	seams = [false, false, false]
	label = -1
	var o := _order()
	if not o.has("district"):
		o["district"] = DISTRICTS[rng.randi_range(0, 3)]   # where the customer lives (kept on the order)
	var right := "%s · %s" % [str(o["customer"]), I18n.t(str(o["district"]))]
	labels = [{"text": right, "ok": true}]
	while labels.size() < 3:
		var decoy := "%s · %s" % [str(o["customer"]) if rng.randf() < 0.5 else _other_name(str(o["customer"])), I18n.t(DISTRICTS[rng.randi_range(0, DISTRICTS.size() - 1)])]
		if not labels.any(func(l): return l["text"] == decoy):
			labels.append({"text": decoy, "ok": false})
	labels.shuffle()
	_layout()


func _other_name(n: String) -> String:
	var parts := n.split(" ")
	var firsts := ["Alex", "Sam", "Jo", "Kim", "Lee", "Max", "Ren", "Val"]
	return "%s %s" % [firsts[rng.randi_range(0, firsts.size() - 1)], parts[-1] if parts.size() > 1 else n]


func _layout() -> void:
	UIK.clear(stage)
	var o := _order()
	var h := UIK.hbox(12)
	h.name = "PackingColumns"
	stage.add_child(h)
	var left := UIK.vbox(4)
	left.custom_minimum_size = Vector2(250, 0)
	h.add_child(left)
	var slip := card(Color(0.98, 0.97, 0.93), Color8(150, 140, 120))
	var sv := UIK.vbox(1)
	slip.add_child(sv)
	sv.add_child(UIK.label(I18n.t("ORDER %s") % str(o["id"]), 7, Color8(90, 80, 60), true))
	var it := UIK.wrap(Packing.summary(o), 8, Color8(30, 30, 30), 250)
	it.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	sv.add_child(it)
	var to := UIK.label(I18n.t("Ship to: %s") % str(labels.filter(func(l): return l["ok"])[0]["text"]), 8, Color8(50, 50, 50))
	to.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	sv.add_child(to)
	sv.add_child(UIK.label_tip("Grid packing and postage", "grid_packing", 8, Color8(30,30,30)))
	left.add_child(slip)
	var view := BoxView.new()
	view.custom_minimum_size = Vector2(250, 112)
	view.game = self
	view.name = "PackingGrid"
	left.add_child(view)
	var seam_row := UIK.hbox(4)
	for i in 3:
		var sb := UIK.button(I18n.t("Tape seam %d") % (i + 1) + (" ✓" if seams[i] else ""), _tape.bind(i), "tab_active" if seams[i] else "tab")
		sb.name = "Seam_%d" % i
		sb.disabled = box == "" or seams[i]
		seam_row.add_child(sb)
	left.add_child(seam_row)
	# steps
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(310, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	h.add_child(scroll)
	var right := UIK.vbox(5)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(right)
	right.add_child(choice_row("1  Box", BOXES, box, _box, "Box"))
	if box != "":
		right.add_child(UIK.wrap(I18n.t("This box: materials %s · economy postage %s") % [Fmt.money(Packing.material(o, box, pad) + Ecommerce.packaging_extra()), Fmt.money(Packing.postage(o, box, "economy"))], 8, Art.C_SKY, 300))
		right.add_child(UIK.label(I18n.t("Placed %d/%d · damage risk %d%%") % [placements.size(), Packing.pieces(o).size(), roundi(Packing.damage(o, pad) * 100)], 8, Art.C_MUTED))
	var pr := UIK.hbox(4)
	var pl := UIK.label("2  Padding", 8, Art.C_MUTED, true)
	pl.custom_minimum_size = Vector2(60, 0)
	pr.add_child(pl)
	var pb := UIK.button("Add bubble wrap", _pad, "", 115)
	pb.name = "Pad"
	pb.disabled = box == ""
	pr.add_child(pb)
	var gauge := Control.new()
	gauge.custom_minimum_size = Vector2(100, 12)
	gauge.draw.connect(func():
		gauge.draw_rect(Rect2(0, 2, 100, 8), Color8(60, 66, 80))
		gauge.draw_rect(Rect2(PAD_ZONE[0] * 100, 2, (PAD_ZONE[1] - PAD_ZONE[0]) * 100, 8), Color(Art.C_GREEN, 0.5))
		gauge.draw_rect(Rect2(0, 3, minf(pad, 1.0) * 100, 6), Art.C_SKY))
	pr.add_child(gauge)
	right.add_child(pr)
	right.add_child(UIK.label("3  Tape all three seams (buttons under the box)", 8, Art.C_MUTED, true))
	right.add_child(UIK.label("4  Label", 8, Art.C_MUTED, true))
	for i in labels.size():
		var lb := UIK.button(str(labels[i]["text"]), _label.bind(i), "tab_active" if label == i else "tab", 260)
		lb.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		lb.name = "Label_%d" % i
		lb.disabled = box == ""
		right.add_child(lb)
	if box != "":
		var controls := UIK.hbox(4)
		var rotate_button := UIK.button("Rotate item", _rotate)
		rotate_button.name = "RotateItem"
		controls.add_child(rotate_button)
		var reset_button := UIK.button("Clear box", _clear_box)
		reset_button.name = "ClearBox"
		controls.add_child(reset_button)
		right.add_child(controls)
		for index in Packing.pieces(o).size():
			var piece: Dictionary = Packing.pieces(o)[index]
			var chosen := UIK.button("%d · %s %s" % [index + 1, I18n.t(DataDB.product(piece["product"])["name"]), "✓" if placements.any(func(p): return p["item"] == index) else "✗"], _select.bind(index), "tab_active" if selected == index else "tab")
			chosen.name = "PackItem_%d" % index
			right.add_child(chosen)

		if placements.size() < Packing.pieces(o).size(): right.add_child(UIK.wrap("✗ Select an item, rotate if needed, then click a free grid cell.", 8, Art.C_MUTED, 300))
	var done := UIK.button("Seal & next", _seal, "primary", 150)
	done.name = "Seal"
	done.disabled = box == "" or label < 0 or seams.has(false) or placements.size() != Packing.pieces(o).size()
	left.add_child(done)


func _box(b: String) -> void:
	var order := ["small", "medium", "large"]
	if order.find(b) < order.find(need_box()):
		flash("✗ It doesn't fit. Try a bigger box.", false)
		return
	box = b
	placements = []
	_layout()


func _pad() -> void:
	pad = minf(1.1, pad + 0.15)
	_layout()


func _tape(i: int) -> void:
	seams[i] = true
	_layout()


func _label(i: int) -> void:
	label = i
	_layout()


func _seal() -> void:
	if box == "" or label < 0 or seams.has(false) or placements.size() != Packing.pieces(_order()).size(): return
	var q := 0.0
	q += 0.25 if box == need_box() else 0.1
	if pad >= PAD_ZONE[0] and pad <= PAD_ZONE[1]:
		q += 0.3
	elif pad > PAD_ZONE[1]:
		q += 0.2   # overstuffed: safe, wasteful
	else:
		q += 0.3 * pad / PAD_ZONE[0]
	q += 0.15 if not seams.has(false) else 0.0
	var label_ok: bool = labels[label]["ok"]
	q += 0.3 if label_ok else 0.0
	quality[str(_order()["id"])] = {"q": q, "label_ok": label_ok, "box": box, "padding": pad, "placements": placements.duplicate(true)}
	award(q)
	var notes := []
	if box != need_box():
		notes.append(I18n.t("box too big"))
	if pad < PAD_ZONE[0]:
		notes.append(I18n.t("not enough padding"))
	if not label_ok:
		notes.append(I18n.t("wrong label!"))
	flash(("✓ " + I18n.t("Packed well")) if notes.is_empty() else ("△ " + ", ".join(notes)), notes.is_empty())
	next_round()


func extra_result() -> Dictionary:
	return {"quality": quality}


func result_lines() -> Array:
	var out := [I18n.t("Orders packed by hand: %d") % orders.size()]
	var bad := quality.values().filter(func(v): return not v["label_ok"]).size()
	if bad > 0:
		out.append(I18n.t("%d parcel(s) have the wrong label and will arrive late.") % bad)
	if total_orders > orders.size():
		out.append(I18n.t("The other %d orders use skilled automatic packing.") % (total_orders - orders.size()))
	return out


func autoplay(q := 0.9) -> void:
	for o in orders:
		quality[str(o["id"])] = Packing.auto_pack(o, 5)
		quality[str(o["id"])]["q"] = q
		quality[str(o["id"])]["label_ok"] = q >= 0.5
	super.autoplay(q)


func _select(index: int) -> void:
	selected = index
	_layout()

func _rotate() -> void:
	rotated = not rotated
	_layout()

func _clear_box() -> void:
	placements = []
	_layout()

func _place(x: int, y: int) -> void:
	var trial := placements.filter(func(p): return p["item"] != selected)
	trial.append({"item": selected, "x": x, "y": y, "rotated": rotated})
	if not Packing.placement_ok(_order(), box, trial):
		flash("✗ It doesn't fit. Rotate it or choose a free cell.", false)
		return
	placements = trial
	for index in Packing.pieces(_order()).size():
		if not placements.any(func(p): return p["item"] == index): selected = index; break
	_layout()

## Clickable item grid, using existing product icons; no art dependency.
class BoxView:
	extends Control
	var game
	const CELL := 24

	func _ready() -> void:
		if game.box == "": return
		var grid: Array = Packing.boxes()[game.box]["grid"]
		for y in int(grid[1]):
			for x in int(grid[0]):
				var cell := Button.new()
				cell.name = "Grid_%d_%d" % [x, y]
				cell.position = Vector2(x * CELL, y * CELL)
				cell.size = Vector2(CELL, CELL)
				for style in ["normal", "hover", "pressed", "focus"]: cell.add_theme_stylebox_override(style, StyleBoxEmpty.new())
				cell.pressed.connect(game._place.bind(x, y))
				add_child(cell)

	func _gui_input(event: InputEvent) -> void:
		if game.box == "" or not event is InputEventMouseButton: return
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			game._place(int(event.position.x / CELL), int(event.position.y / CELL))
			accept_event()

	func _draw() -> void:
		if game.box == "":
			draw_string(UIK.body_font(), Vector2(12, 70), I18n.t("Pick a box to start"), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Art.C_DIM)
			return
		var grid: Array = Packing.boxes()[game.box]["grid"]
		for y in int(grid[1]):
			for x in int(grid[0]):
				draw_rect(Rect2(x * CELL, y * CELL, CELL - 1, CELL - 1), Color8(150, 110, 66))
		for place in game.placements:
			var piece: Dictionary = Packing.pieces(game._order())[int(place["item"])]
			var dim: Array = piece["size"]
			var w := int(dim[1] if place["rotated"] else dim[0])
			var h := int(dim[0] if place["rotated"] else dim[1])
			var rect := Rect2(int(place["x"]) * CELL, int(place["y"]) * CELL, w * CELL - 2, h * CELL - 2)
			draw_rect(rect, Art.C_SKY)
			var tex := Art.opt_tex(DataDB.product_icon(piece["product"]))
			if tex != null: draw_texture_rect(tex, rect.grow(-2), false)
			draw_string(UIK.body_font(), rect.position + Vector2(2, 10), str(int(place["item"]) + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color.BLACK)
