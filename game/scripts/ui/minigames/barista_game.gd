class_name BaristaGame
extends MiniGame
## A shift behind Bloom Coffee's counter: read each customer's order, build the drink (cup, drink, milk, shots) and
## serve it before their patience runs out. Correct, quick drinks earn tips.

const SIZES := [["S", "Small cup"], ["M", "Medium cup"], ["L", "Large cup"]]
const DRINKS := [["americano", "Americano"], ["latte", "Latte"], ["flat_white", "Flat white"], ["cappuccino", "Cappuccino"], ["mocha", "Mocha"]]
const MILKS := [["none", "No milk"], ["whole", "Whole milk"], ["oat", "Oat milk"]]
const SHOTS := [["1", "Single shot"], ["2", "Double shot"]]
const NAMES := ["Mia", "Leo", "Sam", "Ava", "Noah", "Iris", "Theo", "June", "Omar", "Rin", "Kai", "Nora"]

var want := {}
var got := {}
var tips := 0.0
var served_right := 0
var rng := RandomNumberGenerator.new()
var cup: CupView


func _init() -> void:
	super._init()
	title_text = "Shift — Bloom Coffee counter"
	icon_name = "coffee"
	rounds = 6
	round_time = 24.0
	rng.seed = Clock.now() * 7 + 11


func intro_lines() -> Array:
	return ["Each customer reads out an order. Build it: cup size, drink, milk and shots.",
		"Press Serve before their patience runs out. Correct drinks served quickly earn tips.",
		"House rules: an Americano never takes milk, and a flat white is always a double shot."]


func round_name() -> String:
	return "Customer %d / %d"


func build_round() -> void:
	var d: String = DRINKS[rng.randi_range(0, DRINKS.size() - 1)][0]
	want = {"size": SIZES[rng.randi_range(0, 2)][0], "drink": d,
		"milk": "none" if d == "americano" else ["whole", "oat"][rng.randi_range(0, 1)],
		"shots": "2" if d == "flat_white" else ["1", "2"][rng.randi_range(0, 1)],
		"who": NAMES[rng.randi_range(0, NAMES.size() - 1)]}
	got = {"size": "", "drink": "", "milk": "", "shots": ""}
	_layout()


static func _name(list: Array, id: String) -> String:
	for o in list:
		if o[0] == id:
			return I18n.t(str(o[1]))
	return ""


## Read like an order ticket: "Latte, Large cup, Oat milk, Double shot".
func order_text() -> String:
	var t := _name(DRINKS, want["drink"]) + I18n.t(", ") + _name(SIZES, want["size"])
	if want["milk"] != "none":
		t += I18n.t(", ") + _name(MILKS, want["milk"])
	if want["shots"] == "2" and want["drink"] != "flat_white":
		t += I18n.t(", ") + _name(SHOTS, "2")
	return t


func _layout() -> void:
	UIK.clear(stage)
	var h := UIK.hbox(10)
	h.size = stage.custom_minimum_size
	stage.add_child(h)
	# the customer and the cup being built
	var left := UIK.vbox(4)
	left.custom_minimum_size = Vector2(190, 0)
	h.add_child(left)
	var bubble := card(Color(0.96, 0.94, 0.88), Color(0.55, 0.45, 0.32))
	var bv := UIK.vbox(2)
	bubble.add_child(bv)
	var who := UIK.label(str(want["who"]), 8, Color8(110, 80, 50), true)
	who.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	bv.add_child(who)
	var ot := UIK.wrap("“%s”" % order_text(), 10, Color8(40, 30, 24), 170)
	ot.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	bv.add_child(ot)
	left.add_child(bubble)
	cup = CupView.new()
	cup.custom_minimum_size = Vector2(190, 120)
	cup.spec = got
	left.add_child(cup)
	# the machine
	var right := UIK.vbox(5)
	h.add_child(right)
	right.add_child(choice_row("Cup", SIZES, got["size"], _pick.bind("size"), "Size"))
	right.add_child(choice_row("Drink", DRINKS.slice(0, 3), got["drink"], _pick.bind("drink"), "Drink"))
	right.add_child(choice_row("", DRINKS.slice(3), got["drink"], _pick.bind("drink"), "Drink"))
	right.add_child(choice_row("Milk", MILKS, got["milk"], _pick.bind("milk"), "Milk"))
	right.add_child(choice_row("Espresso", SHOTS, got["shots"], _pick.bind("shots"), "Shots"))
	var serve := UIK.button("Serve", _serve, "primary", 120)
	serve.name = "Serve"
	serve.disabled = got.values().has("")
	right.add_child(serve)


func _pick(val: String, field: String) -> void:
	got[field] = val
	_layout()


func _serve() -> void:
	var right := 0
	for k in ["size", "drink", "milk", "shots"]:
		if got[k] == want[k]:
			right += 1
	var p := right / 4.0
	award(p)
	if right == 4:
		served_right += 1
		var tip := 2.0 if time_left() > 0.5 else 0.5
		tips += tip
		flash(I18n.t("✓ %s is happy (+%s tip)") % [str(want["who"]), Fmt.money(tip)], true)
	else:
		flash(I18n.t("✗ Not quite: %s wanted %s") % [str(want["who"]), order_text()], false)
	next_round()


func round_timeout() -> void:
	flash(I18n.t("✗ %s gave up waiting") % str(want["who"]), false)
	award(0.0)
	next_round()


func extra_result() -> Dictionary:
	return {"tips": tips, "right": served_right}


func result_lines() -> Array:
	return [I18n.t("Drinks served exactly right: %d / %d") % [served_right, rounds], I18n.t("Tips: %s") % Fmt.money(tips)]


## A cup filled in layers as the drink is built.
class CupView:
	extends Control
	var spec := {}

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var scale_h := {"S": 46.0, "M": 58.0, "L": 72.0}
		var h: float = scale_h.get(str(spec.get("size", "")), 58.0)
		var w := h * 0.72
		var base := Vector2(size.x / 2.0, size.y - 8)
		var r := Rect2(base.x - w / 2.0, base.y - h, w, h)
		var dash := str(spec.get("size", "")) == ""
		draw_rect(Rect2(r.position.x - 3, base.y - 2, w + 6, 4), Color(0.85, 0.85, 0.88))   # saucer
		# contents from the bottom up
		var y := base.y
		var shots := int(str(spec.get("shots", "0")) if str(spec.get("shots", "")) != "" else "0")
		var drink := str(spec.get("drink", ""))
		var esp := Color8(92, 52, 30) if drink != "mocha" else Color8(70, 38, 26)
		for i in shots:
			var bh := h * 0.14
			draw_rect(Rect2(r.position.x + 2, y - bh, w - 4, bh), esp)
			y -= bh
		if drink == "americano":
			var bh2 := h * 0.4
			draw_rect(Rect2(r.position.x + 2, y - bh2, w - 4, bh2), Color8(120, 74, 44))
			y -= bh2
		var milk := str(spec.get("milk", ""))
		if milk in ["whole", "oat"] and drink != "americano":
			var bh3 := h * (0.32 if drink == "cappuccino" else 0.46)
			draw_rect(Rect2(r.position.x + 2, y - bh3, w - 4, bh3), Color8(246, 236, 220) if milk == "whole" else Color8(226, 206, 170))
			y -= bh3
			var foam := {"cappuccino": 0.2, "latte": 0.07, "flat_white": 0.03, "mocha": 0.08}
			var fh := h * float(foam.get(drink, 0.05))
			draw_rect(Rect2(r.position.x + 2, y - fh, w - 4, fh), Color(1, 1, 1))
			if drink == "mocha":
				draw_circle(Vector2(base.x, y - fh / 2.0), 3.0, Color8(90, 50, 30))
		# the cup itself
		var col := Color(0.93, 0.93, 0.96, 0.9) if not dash else Color(1, 1, 1, 0.35)
		draw_rect(r, col, false, 2.0)
		draw_arc(Vector2(r.end.x + 5, base.y - h * 0.55), h * 0.16, -PI / 2, PI / 2, 12, col, 2.0)
