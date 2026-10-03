class_name BaristaGame
extends MiniGame
## A shift behind Bloom Coffee's counter: read each customer's order, build the drink (cup, drink, milk, shots) and
## serve it before their patience runs out. Correct, quick drinks earn tips.

const SIZES := [["S", "Small cup"], ["M", "Medium cup"], ["L", "Large cup"]]
const DRINKS := [["americano", "Americano"], ["latte", "Latte"], ["flat_white", "Flat white"], ["cappuccino", "Cappuccino"], ["mocha", "Mocha"]]
const MILKS := [["none", "No milk"], ["whole", "Whole milk"], ["oat", "Oat milk"]]
const SHOTS := [["1", "Single shot"], ["2", "Double shot"]]
const NAMES := ["Mia", "Leo", "Sam", "Ava", "Noah", "Iris", "Theo", "June", "Omar", "Rin", "Kai", "Nora"]

var queue: Array = []
var next_ticket := 0
var selected := 0
var tables := {1: "", 2: ""}
var completed_stations := {"order": 0, "make": 0, "deliver": 0, "clean": 0}

var want := {}
var got := {}
var tips := 0.0
var served_right := 0
var rng := RandomNumberGenerator.new()
var cup: CupView
var own_counter := false      # your own café: no tips for you, but good service lifts the café's rating


func _init() -> void:
	super._init()
	title_text = "Shift — Bloom Coffee counter"
	help_key = "work_stations"
	icon_name = "coffee"
	rounds = 6
	round_time = 0.0
	panel_size = Vector2(620, 340)
	rng.seed = Clock.now() * 7 + 11


func intro_lines() -> Array:
	return ["Manage the queue: confirm or recommend, make each drink, deliver to the ticket's counter or table, then clean.",
		"Dirty tables cannot seat another guest. Waiting guests lose patience; choose who to serve first.",
		"Complete service determines tips and the manager's review. Keep cup, milk and espresso shot counts correct."]


func round_name() -> String:
	return "Customer %d / %d"


func build_round() -> void:
	while queue.size() < int(FreelanceWorkflow.cfg()["barista_queue"]) and next_ticket < rounds:
		var d: String = DRINKS[rng.randi_range(0, DRINKS.size() - 1)][0]
		var ticket := {"size": SIZES[rng.randi_range(0, 2)][0], "drink": d,
			"milk": "none" if d == "americano" else ["whole", "oat"][rng.randi_range(0, 1)],
			"shots": "2" if d == "flat_white" else ["1", "2"][rng.randi_range(0, 1)],
			"who": NAMES[rng.randi_range(0, NAMES.size() - 1)], "id": next_ticket + 1,
			"destination": next_ticket % 3, "station": "order", "age": 0.0, "quality": 0.0,
			"got": {"size": "", "drink": "", "milk": "", "shots": ""}}
		next_ticket += 1
		queue.append(ticket)
	selected = 0
	_select_customer(0)

func _select_customer(index: int) -> void:
	if index < 0 or index >= queue.size(): return
	selected = index
	want = queue[index]
	got = want["got"]
	if float(want["age"]) > float(FreelanceWorkflow.cfg()["barista_patience"]): round_timeout(); return
	_layout()

func _confirm(recommend := false) -> void:
	if want["station"] != "order": return
	var table := int(want["destination"])
	if table > 0 and str(tables[table]) != "":
		flash("✗ This table is occupied or dirty. Serve another guest or clean it.", false)
		return
	if recommend and str(got.get("drink", "")) != str(want["drink"]):
		flash("✗ Confirm the guest's preferred drink before recommending.", false)
		return
	if table > 0: tables[table] = str(want["id"])
	want["station"] = "make"
	completed_stations["order"] += 1
	_layout()

func _process(dt: float) -> void:
	if phase != "play": return
	for index in queue.size():
		var customer: Dictionary = queue[index]
		customer["age"] = float(customer["age"]) + dt
		var button := stage.find_child("Guest_%d" % index, true, false)
		if button is Button:
			var remaining := maxi(0, roundi(float(FreelanceWorkflow.cfg()["barista_patience"]) - float(customer["age"])))
			button.text = I18n.t("Guest %d · %d s") % [int(customer["id"]), remaining]
	if not queue.is_empty() and float(want["age"]) > float(FreelanceWorkflow.cfg()["barista_patience"]): round_timeout()

func _deliver(destination: int) -> void:
	if want["station"] != "deliver": return
	var correct := destination == int(want["destination"])
	want["quality"] = float(want["quality"]) * (1.0 if correct else 0.5)
	completed_stations["deliver"] += int(correct)
	want["station"] = "clean"
	if int(want["destination"]) > 0: tables[int(want["destination"])] = "dirty"
	flash("✓ Delivered. Clean the table for the next guest." if correct else "✗ Wrong table. Recover the order and clean up.", correct)
	_layout()

func _clean_dirty_table(table: int) -> void:
	if tables.get(table, "") != "dirty": return
	tables[table] = ""
	completed_stations["clean"] += 1
	for customer in queue:
		if int(customer["destination"]) == table and customer["station"] == "clean": customer["cleaned"] = true
	if int(want["destination"]) == table and want["station"] == "clean": _clean()
	else: _layout()

func _clean() -> void:
	if want["station"] != "clean": return
	if not want.get("cleaned", false):
		if int(want["destination"]) > 0: tables[int(want["destination"])] = ""
		completed_stations["clean"] += 1
		want["cleaned"] = true
	var quality := float(want["quality"])
	award(quality)
	if quality >= 1.0:
		served_right += 1
		var tip := float(FreelanceWorkflow.cfg()["barista_tip_fast"] if float(want["age"]) < float(FreelanceWorkflow.cfg()["barista_patience"]) * 0.5 else FreelanceWorkflow.cfg()["barista_tip_slow"])
		if not own_counter: tips += tip
		flash(I18n.t("✓ %s enjoyed the service.") % str(want["who"]) if own_counter else I18n.t("✓ %s is happy (+%s tip)") % [str(want["who"]), Fmt.money(tip)], true)
	queue.remove_at(selected)
	next_round()


static func _name(list: Array, id: String) -> String:
	for o in list:
		if o[0] == id:
			return I18n.t(str(o[1]))
	return ""


## Read like an order ticket: "Latte, Large cup, Oat milk, Double shot".
func order_text() -> String:
	var sep := "、" if I18n.locale().begins_with("zh") else ", "
	var t := _name(DRINKS, want["drink"]) + sep + _name(SIZES, want["size"])
	if want["milk"] != "none":
		t += sep + _name(MILKS, want["milk"])
	t += sep + _name(SHOTS, str(want["shots"]))
	return t


func _layout() -> void:
	UIK.clear(stage)
	var h := UIK.hbox(10)
	h.size = stage.custom_minimum_size
	var layout := UIK.vbox(3)
	stage.add_child(layout)
	var queue_row := UIK.hbox(4)
	layout.add_child(queue_row)
	for index in queue.size():
		var ticket: Dictionary = queue[index]
		var customer_button := UIK.button(I18n.t("Guest %d · %d s") % [int(ticket["id"]), maxi(0, roundi(float(FreelanceWorkflow.cfg()["barista_patience"]) - float(ticket["age"])))], _select_customer.bind(index), "tab_active" if selected == index else "tab")
		customer_button.name = "Guest_%d" % index
		queue_row.add_child(customer_button)
	layout.add_child(h)
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
	var ot := UIK.wrap(("「%s」" if I18n.locale().begins_with("zh") else "“%s”") % order_text(), 10, Color8(40, 30, 24), 170)
	ot.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	bv.add_child(ot)
	left.add_child(bubble)
	cup = CupView.new()
	cup.custom_minimum_size = Vector2(190, 85)
	cup.spec = got
	left.add_child(cup)
	left.add_child(UIK.label(I18n.t("Order %d · %s") % [int(want["id"]), I18n.t("Pickup counter") if int(want["destination"]) == 0 else I18n.t("Table %d") % int(want["destination"])], 8, Art.C_SKY))
	for table in tables:
		left.add_child(UIK.label(I18n.t("Table %d: %s") % [int(table), I18n.t("Clean" if tables[table] == "" else ("Dirty — clean before seating" if tables[table] == "dirty" else "Occupied"))], 8, Art.C_MUTED))
		if tables[table] == "dirty":
			var cleanup := UIK.button(I18n.t("Clean table %d") % int(table), _clean_dirty_table.bind(int(table)))
			cleanup.name = "CleanDirtyTable_%d" % int(table)
			left.add_child(cleanup)
	# the machine
	var right := UIK.vbox(5)
	h.add_child(right)
	var confirm := UIK.button("Confirm order", _confirm, "primary" if want["station"] == "order" else "")
	confirm.name = "ConfirmOrder"
	confirm.disabled = want["station"] != "order"
	right.add_child(confirm)
	var recommend := UIK.button("Recommend the selected drink", _confirm.bind(true))
	recommend.name = "RecommendDrink"
	recommend.disabled = want["station"] != "order"
	right.add_child(recommend)
	right.add_child(choice_row("Cup", SIZES, got["size"], _pick.bind("size"), "Size"))
	right.add_child(choice_row("Drink", DRINKS.slice(0, 3), got["drink"], _pick.bind("drink"), "Drink"))
	right.add_child(choice_row("", DRINKS.slice(3), got["drink"], _pick.bind("drink"), "Drink"))
	right.add_child(choice_row("Milk", MILKS, got["milk"], _pick.bind("milk"), "Milk"))
	right.add_child(choice_row("Espresso", SHOTS, got["shots"], _pick.bind("shots"), "Shots"))
	var serve := UIK.button("Serve", _serve, "primary" if want["station"] == "make" else "", 120)
	serve.name = "Serve"
	serve.disabled = want["station"] != "make" or got.values().has("")
	right.add_child(serve)
	var destinations := UIK.hbox(4)
	for destination in 3:
		var deliver_button := UIK.button("Pickup counter" if destination == 0 else I18n.t("Table %d") % destination, _deliver.bind(destination))
		deliver_button.name = "Deliver_%d" % destination
		deliver_button.disabled = want["station"] != "deliver"
		destinations.add_child(deliver_button)
	right.add_child(destinations)
	var clean := UIK.button("Clean table / counter", _clean, "primary" if want["station"] == "clean" else "")
	clean.name = "CleanTable"
	clean.disabled = want["station"] != "clean"
	left.add_child(clean)


func _pick(val: String, field: String) -> void:
	if phase != "play" or want["station"] not in ["order", "make"]: return
	got[field] = val
	_layout()


func _serve() -> void:
	if want["station"] != "make": return
	var correct := 0
	for key in ["size", "drink", "milk", "shots"]:
		if got[key] == want[key]: correct += 1
	want["quality"] = correct / 4.0
	completed_stations["make"] += int(correct == 4)
	want["station"] = "deliver"
	_layout()

func round_timeout() -> void:
	if queue.is_empty(): return
	flash(I18n.t("✗ %s gave up waiting") % str(want["who"]), false)
	if int(want["destination"]) > 0 and tables[int(want["destination"])] == str(want["id"]): tables[int(want["destination"])] = ""
	queue.remove_at(selected)
	award(0.0)
	next_round()


func extra_result() -> Dictionary:
	return {"tips": tips, "right": served_right, "stations": completed_stations, "manager_rating": score()}


func result_lines() -> Array:
	if own_counter:
		return [I18n.t("Drinks served exactly right: %d / %d") % [served_right, rounds], I18n.t("Service: %d%%") % int(round(score() * 100))]
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
