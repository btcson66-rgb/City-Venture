class_name PackGame
extends MiniGame
## Pack orders by hand at the packing table: pick a box that fits, pad it, tape the three seams, and stick on the label
## that matches the order. Up to five orders are packed by hand per session; any more are packed the same way once you
## have the rhythm. Pack quality follows each order: poor padding arrives damaged (returns), a wrong label arrives late.

const BOXES := [["small", "Small box"], ["medium", "Medium box"], ["large", "Large box"]]
const PAD_ZONE := [0.6, 0.85]
const DISTRICTS := ["Riverside", "Startup Hub", "Civic Center", "Financial District", "Shopping Street", "Harbor"]
const HAND_MAX := 5

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
	icon_name = "parcel"
	total_orders = order_list.size()
	orders = order_list.slice(0, HAND_MAX)
	rounds = maxi(1, orders.size())
	round_time = 0.0
	rng.seed = Clock.now() * 29 + 1


func intro_lines() -> Array:
	var l := ["Pack each order by hand, in four steps: a box that fits, padding, tape on all three seams, and the right label.",
		"Padding should reach the green zone. Too little and things arrive broken; that means returns and bad reviews.",
		"Check the label against the order: the wrong one sends the parcel to the wrong address and it arrives late."]
	if total_orders > HAND_MAX:
		l.append(I18n.t("You pack %d by hand; the other %d get packed the same way once you have the rhythm.") % [HAND_MAX, total_orders - HAND_MAX])
	return l


func round_name() -> String:
	return "Order %d / %d"


func _order() -> Dictionary:
	return orders[round_i]


func need_box() -> String:
	var sc := str(DataDB.product(str(_order()["product"])).get("ship_class", "small"))
	return "medium" if sc == "medium" else ("large" if sc == "large" else "small")


func build_round() -> void:
	box = ""
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
	stage.add_child(h)
	var left := UIK.vbox(4)
	left.custom_minimum_size = Vector2(250, 0)
	h.add_child(left)
	var slip := card(Color(0.98, 0.97, 0.93), Color8(150, 140, 120))
	var sv := UIK.vbox(1)
	slip.add_child(sv)
	sv.add_child(UIK.label(I18n.t("ORDER %s") % str(o["id"]), 7, Color8(90, 80, 60), true))
	var it := UIK.label(I18n.t(str(DataDB.product(str(o["product"]))["name"])) + " × %d" % int(o.get("qty", 1)), 9, Color8(30, 30, 30), true)
	it.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	sv.add_child(it)
	var to := UIK.label(I18n.t("Ship to: %s") % str(labels.filter(func(l): return l["ok"])[0]["text"]), 8, Color8(50, 50, 50))
	to.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	sv.add_child(to)
	left.add_child(slip)
	var view := BoxView.new()
	view.custom_minimum_size = Vector2(250, 130)
	view.game = self
	left.add_child(view)
	var seam_row := UIK.hbox(4)
	for i in 3:
		var sb := UIK.button(I18n.t("Tape seam %d") % (i + 1) + (" ✓" if seams[i] else ""), _tape.bind(i), "tab_active" if seams[i] else "tab")
		sb.name = "Seam_%d" % i
		sb.disabled = box == "" or seams[i]
		seam_row.add_child(sb)
	left.add_child(seam_row)
	# steps
	var right := UIK.vbox(5)
	h.add_child(right)
	right.add_child(choice_row("1  Box", BOXES, box, _box, "Box"))
	var pr := UIK.hbox(4)
	var pl := UIK.label("2  Padding", 8, Art.C_MUTED, true)
	pl.custom_minimum_size = Vector2(70, 0)
	pr.add_child(pl)
	var pb := UIK.button("Add bubble wrap", _pad, "", 130)
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
	var done := UIK.button("Seal & next", _seal, "primary", 150)
	done.name = "Seal"
	done.disabled = box == "" or label < 0 or seams.has(false)
	right.add_child(done)


func _box(b: String) -> void:
	var order := ["small", "medium", "large"]
	if order.find(b) < order.find(need_box()):
		flash("✗ It doesn't fit. Try a bigger box.", false)
		return
	box = b
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
	quality[str(_order()["id"])] = {"q": q, "label_ok": label_ok}
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
		out.append(I18n.t("The other %d orders are packed at the same standard.") % (total_orders - orders.size()))
	return out


func autoplay(q := 0.9) -> void:
	for o in orders:
		quality[str(o["id"])] = {"q": q, "label_ok": q >= 0.5}
	super.autoplay(q)


## The open box with its padding and tape.
class BoxView:
	extends Control
	var game

	func _draw() -> void:
		var sizes := {"small": Vector2(80, 50), "medium": Vector2(110, 64), "large": Vector2(140, 80)}
		if game.box == "":
			draw_string(UIK.body_font(), Vector2(40, 70), I18n.t("Pick a box to start"), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Art.C_DIM)
			return
		var s: Vector2 = sizes[game.box]
		var r := Rect2(Vector2((size.x - s.x) / 2.0, size.y - s.y - 8), s)
		draw_rect(r, Color8(196, 150, 96))
		var inner := r.grow(-5)
		draw_rect(inner, Color8(150, 110, 66))
		var ph := inner.size.y * minf(game.pad, 1.0)
		draw_rect(Rect2(inner.position.x, inner.end.y - ph, inner.size.x, ph), Color(0.85, 0.92, 1.0, 0.85))
		var tex := Art.opt_tex(DataDB.product_icon(str(game._order()["product"])))
		if tex != null:
			draw_texture_rect(tex, Rect2(r.get_center() - Vector2(16, 20), Vector2(32, 32)), false)
		for i in 3:
			if game.seams[i]:
				var x := r.position.x + r.size.x * (0.2 + 0.3 * i)
				draw_rect(Rect2(x - 4, r.position.y - 2, 8, r.size.y + 4), Color(0.85, 0.7, 0.4, 0.8))
		if game.label >= 0:
			draw_rect(Rect2(r.end.x - 34, r.end.y - 22, 30, 18), Color(0.98, 0.98, 0.95))
