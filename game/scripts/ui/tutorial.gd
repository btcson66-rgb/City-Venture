class_name Tutorial
extends Control
## The guided first venture: a new player is walked through one whole business loop, step by step, before being set
## free. Arrival → coffee → co-work → pick e-commerce → buy stock → take a part-time job and work a shift while the
## stock travels → sleep → shoot photos and list → first order → pack it by hand → ship it → get paid.
##  • Card (top left): what to do now and how. A step completes by doing it; steps already done are skipped.
##  • Gold arrow (in the world): where to go. On screen it bounces over the spot; off screen it sits on the screen edge
##    with the place's name. Routes through room exits, street edges and the Metro. Toggle in the pause menu.
##  • Coach (over any open screen): a pulsing frame around the exact button to press, with a one-line hint.
## Progress lives in the save (GameState.data["tutorial"]). Every other screen explains itself with Help (the ? button).

const SETTINGS := "user://settings.cfg"
const HOME := "riverside_apartment"
const VERSION := 3
## id · title · text (how to do it) · then, on their own line (not player text, so tools/i18n_extract.py skips it):
## done (Cond, or seen:<x>) · target (world arrow; omitted = the story objective's, {} = none) · ui (buttons to highlight
## on open screens, in order; "name*" = prefix, "hud:phone" = the Phone button) · then keys, and the coach's line for the
## highlighted button: "hints" (one per ui entry) or a single "hint".
const STEPS := [
	{"id": "move", "title": "Moving around",
		"text": "Walk with WASD or the arrow keys. Hold Shift to run.",
		"done": "seen:move", "target": {},
		"keys": ["W", "A", "S", "D", "Shift"]},
	{"id": "phone", "title": "Your phone",
		"text": "Your phone is buzzing. Press Tab (or click Phone, top right) and read Maya's message.",
		"done": "flag:maya_intro_done", "target": {}, "ui": ["Thread_maya", "App_messages", "hud:phone"],
		"keys": ["Tab"], "hints": ["Read Maya's message", "Open Messages", "Open your phone"]},
	{"id": "exit", "title": "Going outside",
		"text": "Walk onto the glowing EXIT mat at the bottom of the room to go outside.",
		"done": "visited:riverside", "target": {"exit": true},
		"keys": []},
	{"id": "coffee", "title": "Your first coffee",
		"text": "Follow the gold arrow to Bloom Coffee and walk in through the door. At the counter, press E to order.",
		"done": "flag:bought_coffee_bloom_coffee",
		"target": {"building": "bloom_coffee", "action": "buy_item"},
		"keys": ["E"]},
	{"id": "east", "title": "To Startup Hub",
		"text": "Walk east along the street (→). Past the end of Riverside is Startup Hub, where founders work.",
		"done": "visited:startup_hub", "target": {"district": "startup_hub"},
		"keys": []},
	{"id": "cowork", "title": "A place to work",
		"text": "Go into Nexus Co-work. At reception, press E and buy a Day Pass ($15): it lets you use a desk and its computer today.",
		"done": "desk_access || flag:business_chosen || stat:purchase_orders>=1", "target": {"building": "nexus_cowork", "action": "cowork_desk"}, "ui": ["DayPass"],
		"keys": ["E"], "hint": "Buy a Day Pass"},
	{"id": "board", "title": "Choose a business",
		"text": "Walk to the Business Board and press E. Choose E-commerce: you buy products wholesale and sell them online.",
		"done": "flag:business_chosen", "target": {"building": "nexus_cowork", "action": "business_board"}, "ui": ["StartEcommerce", "Biz_ecommerce", "Page_business"],
		"keys": ["E"], "hints": ["Start this business", "Pick E-commerce", "Open Businesses"]},
	{"id": "os", "title": "Your business computer",
		"text": "Open Company OS at your laptop at home, or at a hot desk while your co-work pass is valid. Everything about your business happens here.",
		"done": "seen:os", "target": {"os": true},
		"keys": ["E"]},
	{"id": "buy", "title": "Buy your first stock",
		"text": "In Company OS open Operations and press Buy next to a product. Start small: phone stands are cheap and sell steadily. Your first order is delivered right away; after that, stock takes a couple of days.",
		"done": "stat:purchase_orders>=1", "target": {"os": true}, "ui": ["Buy_tradelink_wholesale_phone_stand", "Buy_*", "Tab_operations"],
		"keys": [], "hints": ["Buy phone stands", "Buy this product", "Open Operations"]},
	{"id": "shoot", "title": "Photograph and list",
		"text": "Your stock is here. In Company OS go to Sales and press 'Shoot photos myself & list': set up the shot and take the photo yourself. Better photos sell more.",
		"done": "has_listed", "target": {"os": true}, "ui": ["StartGame", "ListSelf_*", "Tab_sales"],
		"keys": [], "hints": ["Start the shoot", "Shoot the photos yourself", "Open Sales"]},
	{"id": "order", "title": "Your first order",
		"text": "Your listing is live on ShopLane. Your first order comes in within a few minutes, and your phone will buzz. Head home meanwhile: your packing table is there.",
		"done": "stat:orders_placed>=1", "target": {"building": HOME, "action": "pack_orders"},
		"keys": []},
	{"id": "pack", "title": "Pack the order",
		"text": "You have an order! Go to your packing table at home and press E. Pack it by hand: box, padding, tape, label.",
		"done": "stat:orders_packed>=1", "target": {"building": HOME, "action": "pack_orders"}, "ui": ["StartGame", "Pack"],
		"keys": ["E"], "hints": ["Start packing", "Pack the order"]},
	{"id": "ship", "title": "Send it off",
		"text": "At the packing table, choose how it leaves: book the courier (it collects from home) or carry it to PostPoint yourself (cheaper, costs your time).",
		"done": "stat:orders_shipped>=1 || carrying_parcels", "target": {"building": HOME, "action": "pack_orders"}, "ui": ["CourierEconomy", "Carry"],
		"keys": [], "hints": ["Courier collects it (or carry it)", "Carry it to PostPoint"]},
	{"id": "dropoff", "title": "Drop it at PostPoint",
		"text": "You're carrying the parcel. Walk to PostPoint in Riverside and hand it over at the counter.",
		"done": "stat:orders_shipped>=1", "target": {"building": "postpoint_riverside", "action": "dropoff_parcels"}, "ui": ["DropEconomy"],
		"keys": ["E"], "hint": "Hand it in"},
	{"id": "paid", "title": "Getting paid",
		"text": "It's on its way. This first delivery takes a few minutes; later ones take 1–3 days. When it arrives, the sale lands in your ShopLane balance, and ShopLane pays out to your bank every week (Company OS → Finance). Meanwhile, walk over to Bloom Coffee: you'll pick up a job there next.",
		"done": "stat:orders_delivered>=1", "target": {"building": "bloom_coffee", "action": "work_shift"},
		"keys": []},
	{"id": "job", "title": "Earn on the side",
		"text": "Your first sale is done! Money comes in faster with a part-time job too. Bloom Coffee is hiring: go to its staff door, press E and take the barista job. (More jobs are on the Business Board.)",
		"done": "has_job || flag:has_job || stat:shifts_worked>=1", "target": {"building": "bloom_coffee", "action": "work_shift"}, "ui": ["ApplyJob", "Job_barista"],
		"keys": ["E"], "hints": ["Take the job", "Barista: see the job"]},
	{"id": "shift", "title": "Work a shift",
		"text": "Press E at the staff door and start a shift. You do the work yourself: the better it goes, the more you earn. Came in late? The shift runs until closing time. Less than 2 hours left? Sleep, and work tomorrow.",
		"done": "stat:shifts_worked>=1", "target": {"job": true}, "ui": ["StartGame", "WorkShift"],
		"keys": ["E"], "hints": ["Start working", "Start the shift"]},
	{"id": "sleep", "title": "End the day",
		"text": "After a shift you're tired: go home and sleep in your bed (any time after work, or from 7 PM). Overnight your listing keeps selling and deliveries keep moving. Tomorrow, the city is yours.",
		"done": "stat:nights_slept>=1", "target": {"building": HOME, "action": "sleep"}, "ui": ["Sleep"],
		"keys": [], "hint": "Sleep until morning"},
]

var card: PanelContainer
var head: Label
var body: Label
var keys_row: HBoxContainer
var _t := 0.0
var _step_t := 0.0
var _last_pos := Vector2.INF
var _moved := 0.0
var _completing := false
var _guide_on := true
var _target := {}          # {pos: Vector2 (world), label: String}
var _guide: Control
var _coach: Control         # drawn on UIRoot.coach_layer, above open screens
var _coach_rect := Rect2()
var _coach_hint := ""
var _coach_step := ""        # "FIRST VENTURE 9/18 · Buy your first stock", above the hint
var _coach_i := -1          # which of the step's ui entries was found
var _coach_target: Control
var _nudged := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		_guide_on = bool(cfg.get_value("general", "guide", true))
	card = PanelContainer.new()
	var sb := UIK.flat(Color(0.05, 0.08, 0.15, 0.95), Art.C_GOLD, 1, 3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(214, 0)
	card.visible = false
	add_child(card)
	var v := UIK.vbox(2)
	card.add_child(v)
	var hr := UIK.hbox(3)
	v.add_child(hr)
	hr.add_child(UIK.icon("star", 9))
	head = UIK.label("", 7, Art.C_GOLD, true)
	head.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(head)
	var skip := UIK.button("Skip", skip_all)
	skip.name = "SkipTutorial"
	skip.add_theme_font_size_override("font_size", 6)
	skip.add_theme_stylebox_override("normal", UIK.flat(Color(0, 0, 0, 0), Color(1, 1, 1, 0.25), 1, 2))
	skip.add_theme_stylebox_override("hover", UIK.flat(Color(1, 1, 1, 0.08), Art.C_GOLD, 1, 2))
	skip.add_theme_color_override("font_color", Art.C_MUTED)
	hr.add_child(skip)
	body = UIK.wrap("", 8, Art.C_WHITE, 202)
	body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(body)
	keys_row = UIK.hbox(2)
	v.add_child(keys_row)
	# the guide arrow draws above the card, so a target behind the card still shows its label
	_guide = Control.new()
	_guide.set_anchors_preset(Control.PRESET_FULL_RECT)
	_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_guide)
	_guide.draw.connect(_draw_guide)
	EventBus.interacted.connect(func(_a, _b): _seen("interact"))


# ------------------------------------------------------------------ state
func st() -> Dictionary:
	if not GameState.has_game():
		return {}
	var t: Dictionary = GameState.data.get("tutorial", {})
	if t.is_empty():
		# saves from before the tutorial existed: only new-ish games get it
		var fresh: bool = str(GameState.data["story"].get("chapter", "")) in ["", "ch1_arrival"]
		t = {"step": 0, "seen": {}, "off": not fresh, "v": VERSION}
		GameState.data["tutorial"] = t
	elif int(t.get("v", 1)) < VERSION:
		# an older script: restart on this one (it skips whatever is already done), unless this player already got a
		# first order delivered: they've been through the loop, so don't walk them through it again
		# Resume after "buy" when stock was already bought: earlier steps like the day pass only hold for one day and
		# would otherwise send a returning player back to reception.
		if GameState.stat("orders_delivered") >= 1:
			t["step"] = STEPS.size()
		else:
			t["step"] = _index("buy") if GameState.stat("purchase_orders") >= 1 else 0
		t["v"] = VERSION
	return t


func _seen(what: String) -> void:
	var s := st()
	if not s.is_empty():
		s["seen"][what] = true


## True while a new player is on the guided first venture. The simulation uses it to skip the waits a first-timer
## can't do anything about: the first stock arrives at once, the first order comes minutes after listing, the courier
## is quick and the first parcel is delivered within the hour.
static func first_venture_active() -> bool:
	if not GameState.has_game():
		return false
	var t: Dictionary = GameState.data.get("tutorial", {})
	return not t.is_empty() and not bool(t.get("off", false)) and int(t.get("step", 0)) < STEPS.size() \
		and int(t.get("v", 1)) >= VERSION


func is_active() -> bool:
	var s := st()
	return not s.is_empty() and not bool(s.get("off", false)) and int(s.get("step", 0)) < STEPS.size()


func current() -> Dictionary:
	return STEPS[int(st()["step"])] if is_active() else {}


func skip_all() -> void:
	var s := st()
	if s.is_empty():
		return
	s["off"] = true
	card.visible = false
	UIRoot.toast(I18n.t("Tutorial skipped. You can replay it from the pause menu (Esc)."), "info", "info")


func restart() -> void:
	if not GameState.has_game():
		return
	GameState.data["tutorial"] = {"step": 0, "seen": {}, "off": false, "v": VERSION}
	_moved = 0.0
	_step_t = 0.0


static func guide_enabled() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		return bool(cfg.get_value("general", "guide", true))
	return true


func set_guide(on: bool) -> void:
	_guide_on = on
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("general", "guide", on)
	cfg.save(SETTINGS)
	_guide.queue_redraw()


# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	_t += delta
	if _coach == null and UIRoot.coach_layer != null:
		_coach = Control.new()
		_coach.set_anchors_preset(Control.PRESET_FULL_RECT)
		_coach.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIRoot.coach_layer.add_child(_coach)
		_coach.draw.connect(_draw_coach)
	var ws := SceneRouter.world_scene()
	var live := GameState.has_game() and UIRoot.hud.visible and ws != null and not SceneRouter.transitioning
	visible = live
	if _coach != null:
		_coach.visible = live
	if not live:
		return
	_track(ws, delta)
	var blocked := UIRoot.is_blocking()
	# Steps already done before this one ever showed (a continued save, work done early) are skipped silently. A step
	# the player finishes while it's on screen still gets its green ✓ below.
	if not _completing and _step_t < 0.2 and skip_completed():
		_graduate()
	if is_active():
		var s := current()
		card.visible = not blocked
		_step_t += delta
		_show_step(int(st()["step"]))
		if not _completing and step_done(s):
			_complete_step(_step_t < 0.2)
		elif s["id"] == "phone":
			_nudge_maya()
		elif s["id"] == "order":
			_first_order()
		_rush_stock(delta)
	else:
		card.visible = false
	var op := UIRoot.hud.obj_panel
	card.position = Vector2(6, (op.position.y + op.size.y + 4) if op.visible else 42.0)
	# the world arrow, and the coach on open screens
	_target = _resolve(ws) if _guide_on and not blocked else {}
	_guide.queue_redraw()
	_update_coach()


func _track(ws: WorldScene, _delta: float) -> void:
	if ws.player != null:
		var p := ws.player.global_position
		if _last_pos != Vector2.INF and p.distance_to(_last_pos) < 20.0:
			_moved += p.distance_to(_last_pos)
		_last_pos = p
		if _moved > 48.0:
			_seen("move")
	if UIRoot.phone.is_open:
		_seen("phone")
	if ws.kind == "district":
		_seen("exit")
	var tm := UIRoot.top_modal()
	if tm is CityMapModal:
		_seen("map")
	elif tm is CompanyOS:
		_seen("os")


func step_done(s: Dictionary) -> bool:
	var d := str(s.get("done", ""))
	if d.begins_with("seen:"):
		return bool(st()["seen"].get(d.substr(5), false))
	return d != "" and Cond.eval(d)


## Drain completed steps before drawing a card/arrow, including when entering a continued save.
## Returns true only on the transition to graduation (callers may show the final help card).
func skip_completed() -> bool:
	var was_active := is_active()
	while is_active() and step_done(current()):
		st()["step"] = int(st()["step"]) + 1
		_step_t = 0.0
	return was_active and not is_active()


func _complete_step(instant := false) -> void:
	_completing = true
	if not instant:
		head.text = "✓ " + head.text
		head.add_theme_color_override("font_color", Art.C_GREEN)
		await get_tree().create_timer(0.9).timeout
	var s := st()
	if not s.is_empty():
		s["step"] = int(s["step"]) + 1
		skip_completed()
		if int(s["step"]) >= STEPS.size():
			_graduate()
	head.add_theme_color_override("font_color", Art.C_GOLD)
	_step_t = 0.0
	_completing = false
	SaveSystem.autosave_if_changed()


## The phone step needs a message to read. A game continued after Maya's messages were already opened (or quit halfway
## through her call) has nothing new to show, so she texts again: a fresh unread message the player can open.
func _nudge_maya() -> void:
	if _step_t < 3.0 or UIRoot.phone.is_open or UIRoot.dialogue.active or UIRoot.is_blocking():
		return
	var unread: bool = GameState.data["messages"].any(func(m): return m["from"] == "maya" and not m.get("read", false))
	if unread or _nudged:
		return
	_nudged = true     # once per session: enough to put a fresh message on the phone
	GameState.add_message("maya", "Hey, did you get my messages? Call me when you can.")


var _rush_t := 0.0


## The guided first venture never waits on a truck: stock still in transit once the player has moved past buying it
## (bought before this rule, or a continued save) shows up after a moment, with a note from the supplier.
func _rush_stock(delta: float) -> void:
	if not first_venture_active() or int(st()["step"]) <= _index("buy") or Ecommerce.total_units() > 0:
		_rush_t = 0.0
		return
	var late: Array = Ecommerce.E()["purchase_orders"].values().filter(func(po): return po["status"] == "in_transit")
	if late.is_empty():
		return
	_rush_t += delta
	if _rush_t < 2.5:
		return
	_rush_t = 0.0
	for po in late:
		var contact := str(DataDB.supplier(po["supplier"]).get("contact_npc", ""))
		if contact != "":
			GameState.add_message(contact, "Good news: a van was in your area, so your order came early.")
		po["eta"] = Clock.now()
		Ecommerce._h_po_arrive({"po": po["id"]})


static func _index(id: String) -> int:
	for i in STEPS.size():
		if STEPS[i]["id"] == id:
			return i
	return -1


## The guided first order comes in a few minutes after the first listing goes live (normally orders follow demand).
func _first_order() -> void:
	if GameState.stat("orders_placed") >= 1:
		return
	if GameState.data["schedule"].any(func(e): return e["kind"] == "eco.order_place"):
		return
	for l in Ecommerce.E()["listings"].values():
		if l.get("active", false):
			_seen("first_order")
			Sim.schedule(Clock.now() + GameState.randi_range(8, 15), "eco.order_place", {"listing": l["id"]})
			return


## The whole loop is done: say so, and show what else there is.
func _graduate() -> void:
	UIRoot.open_modal(InfoModal.first_venture())


var _shown := -1
var _shown_loc := ""
var _shown_txt := ""


func _show_step(i: int) -> void:
	if _completing:
		return
	var txt := I18n.t(step_text(STEPS[i]))
	if _shown == i and _shown_loc == I18n.locale() and _shown_txt == txt:
		return
	_shown = i
	_shown_loc = I18n.locale()
	_shown_txt = txt
	var s: Dictionary = STEPS[i]
	head.text = (I18n.t("FIRST VENTURE %d/%d") % [mini(i + 1, STEPS.size()), STEPS.size()]) + "  ·  " + I18n.t(str(s["title"]))
	body.text = txt
	for c in keys_row.get_children():
		c.queue_free()
	for k in s.get("keys", []):
		var kc := PanelContainer.new()
		kc.add_theme_stylebox_override("panel", UIK.tex_box("ui/prompt_key", 2, 2))
		var kl := UIK.label(" %s " % I18n.t(str(k)), 7, Art.C_NAVY_800, true)
		kl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		kc.add_child(kl)
		keys_row.add_child(kc)
	keys_row.visible = not s.get("keys", []).is_empty()
	_fit_card.call_deferred()


## A step's instructions, fitted to the moment: a shift that can't happen today says so and sends you to bed.
static func step_text(s: Dictionary) -> String:
	if s["id"] == "shift" and Careers.current_job() == "":
		return "You left your job before working a shift. Take a job again at Bloom Coffee's staff door, then work a shift."
	if s["id"] == "order" and GameState.stat("listings_active") < 1:
		return "Your listing is no longer active. Open Company OS → Sales and list a product again; buy stock in Operations if you ran out."
	if s["id"] == "shift" and Careers.current_job() != "":
		var why := Careers.shift_block(Careers.current_job())
		if why in ["too late for a shift today", "closed now"]:
			return "Too late for a shift today: the workplace closes soon. Go home and sleep (you can, after 4 PM on your first day), and work a shift tomorrow morning."
	return str(s["text"])


func _fit_card() -> void:
	card.reset_size()


# ------------------------------------------------------------------ coach: the button to press on an open screen
func _update_coach() -> void:
	_coach_rect = Rect2()
	_coach_hint = ""
	_coach_step = ""
	if is_active() and _guide_on:
		var s := current()
		var c := _find_ui(s.get("ui", []))
		if c != null:
			if c != _coach_target:
				_coach_target = c
				_scroll_to(c)
			_coach_rect = c.get_global_rect()
			_coach_hint = I18n.t(coach_hint(s, _coach_i))
			# an open screen hides the card, so the bubble says which step this is
			_coach_step = (I18n.t("FIRST VENTURE %d/%d") % [int(st()["step"]) + 1, STEPS.size()]) + "  ·  " + I18n.t(str(s["title"]))
	if _coach != null:
		_coach.queue_redraw()


## The coach's line for the step's i-th highlighted button.
static func coach_hint(s: Dictionary, i: int) -> String:
	var hs: Array = s.get("hints", [])
	if i >= 0 and i < hs.size():
		return str(hs[i])
	return str(s.get("hint", s["title"]))


## A highlighted button inside a scrolling list is scrolled into view once.
func _scroll_to(c: Control) -> void:
	var p := c.get_parent()
	while p != null and not (p is ScrollContainer):
		p = p.get_parent()
	if p is ScrollContainer:
		(p as ScrollContainer).ensure_control_visible.call_deferred(c)


func _find_ui(names: Array) -> Control:
	var roots: Array = []
	var tm := UIRoot.top_modal()
	if tm != null:
		roots.append(tm)
	elif UIRoot.phone.is_open:
		roots.append(UIRoot.phone)
	for i in names.size():
		var name := str(names[i])
		_coach_i = i
		if name == "hud:phone":
			if roots.is_empty() and not UIRoot.dialogue.active and UIRoot.hud.phone_btn != null:
				return UIRoot.hud.phone_btn
			continue
		for r in roots:
			var c := _find_named(r, name)
			if c != null:
				return c
	_coach_i = -1
	return null


func _find_named(root: Node, name: String) -> Control:
	var prefix := name.ends_with("*")
	var key := name.trim_suffix("*")
	for c in root.find_children("*", "Control", true, false):
		var cn := str(c.name)
		if (cn.begins_with(key) if prefix else cn == key) and (c as Control).is_visible_in_tree():
			if c is BaseButton and (c as BaseButton).disabled:
				continue
			return c
	return null


func _draw_coach() -> void:
	if _coach_rect.size == Vector2.ZERO:
		return
	var gold := Color(1.0, 0.8, 0.26)
	var pulse := 0.5 + 0.5 * sin(_t * 5.0)
	var r := _coach_rect.grow(2.0 + pulse * 2.0)
	_coach.draw_rect(r, Color(gold, 0.9), false, 2.0)
	_coach.draw_rect(r.grow(2.0), Color(gold, 0.25 + 0.3 * pulse), false, 1.0)
	# a hint bubble with an arrow, below the button (or above it near the bottom of the screen):
	# the step on a small line, then what this button does
	var font := UIK.bold_font()
	var small := UIK.body_font()
	var w1 := small.get_string_size(_coach_step, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x if _coach_step != "" else 0.0
	var w := maxf(font.get_string_size(_coach_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x, w1)
	var h := 22.0 if _coach_step != "" else 13.0
	# buttons in the lower half get the bubble above them: toasts sit just under an open screen's footer
	var below := r.get_center().y < 200.0 or r.position.y - 10.0 - h < 4.0
	var bob := 2.0 * sin(_t * 6.0)
	var tip := Vector2(r.get_center().x, (r.end.y + 3 + bob) if below else (r.position.y - 3 - bob))
	var dirv := 1.0 if below else -1.0
	var tri := PackedVector2Array([tip, tip + Vector2(-5, 7 * dirv), tip + Vector2(5, 7 * dirv)])
	_coach.draw_colored_polygon(tri, gold)
	var pill := Rect2(Vector2(clampf(tip.x - w / 2.0 - 5, 4, 636 - w - 10), tip.y + (7 * dirv if below else -7 - h)), Vector2(w + 10, h))
	_coach.draw_rect(pill, gold)
	var y := pill.position.y
	if _coach_step != "":
		_coach.draw_string(small, Vector2(pill.position.x + 5, y + 8), _coach_step, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0.3, 0.2, 0.04))
		y += 9
	_coach.draw_string(font, Vector2(pill.position.x + 5, y + 10), _coach_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.1, 0.07, 0.02))


# ------------------------------------------------------------------ guide target
func _resolve(ws: WorldScene) -> Dictionary:
	if not GameState.has_game():
		return {}
	var tgt := {}
	var s := current()
	if not s.is_empty() and s.has("target"):
		tgt = s["target"]
		if tgt.is_empty():
			return {}
		if tgt.get("exit", false):
			return _exit_of(ws) if ws.kind == "interior" else {}
		if tgt.get("job", false):
			var jid := Careers.current_job()
			if jid == "":
				return _route_to_building(ws, "bloom_coffee", "work_shift")
			tgt = {"building": str(Careers.job_def(jid)["building"]), "action": "work_shift"}
			if Careers.shift_block(jid) in ["too late for a shift today", "closed now", "already worked today"]:
				tgt = {"building": HOME, "action": "sleep"}   # nothing to do there today: go home and sleep
		if tgt.get("os", false):
			# the nearest Company OS: one in this room, the co-work desk while a pass is valid, or the laptop at home
			var here := _interactable(ws, "open_company_os")
			if not here.is_empty():
				return here
			tgt = {"building": "nexus_cowork" if Living.has_desk_access() else HOME, "action": "open_company_os"}
	else:
		var o := StoryEngine.main_objective()
		tgt = o.get("target", {})
	if s.get("id", "") == "order" and GameState.stat("listings_active") < 1:
		tgt = {"building": _workplace(), "action": "open_company_os"}
	if tgt.is_empty() or tgt.get("phone", false):
		return {}
	if tgt.has("building"):
		return _route_to_building(ws, str(tgt["building"]), str(tgt.get("action", "")))
	if tgt.has("action"):
		var near := _interactable(ws, str(tgt["action"]))
		if not near.is_empty():
			return near
		return _route_to_building(ws, _workplace(), str(tgt["action"]))
	if tgt.has("district"):
		if ws.kind == "interior":
			return _exit_of(ws)
		if ws.scene_id != str(tgt["district"]):
			return _route_to_district(ws, str(tgt["district"]))
	return {}


func _workplace() -> String:
	if GameState.company_id() != "" and Living.has_lease("suite_2b"):
		return "small_office"
	return HOME


func _exit_of(ws: WorldScene) -> Dictionary:
	var d: Vector2 = ws.spawns.get("door", Vector2(ws.size_px.x / 2.0, ws.size_px.y - 22))
	return {"pos": Vector2(d.x, ws.size_px.y - 6), "label": I18n.t("Exit")}


func _interactable(ws: WorldScene, action: String) -> Dictionary:
	var best: Node2D = null
	var bd := 1e9
	var pp: Vector2 = ws.player.global_position if ws.player != null else Vector2.ZERO
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.action == action and n.enabled and ws.is_ancestor_of(n):
			if action == "open_company_os" and Actions.lock_reason(action, n.params) != "":
				continue   # an expired pass/ended lease is not a usable terminal
			var d: float = (n as Node2D).global_position.distance_to(pp)
			if d < bd:
				bd = d
				best = n
	if best == null:
		return {}
	# "Reception — desks & day passes": translate the whole label, then keep the part before the dash
	var lb := I18n.t(str(best.label))
	for dash in ["——", "—"]:
		if lb.contains(dash):
			lb = lb.get_slice(dash, 0).strip_edges()
			break
	return {"pos": best.global_position, "label": lb}


func _route_to_building(ws: WorldScene, bid: String, action: String) -> Dictionary:
	if ws.kind == "interior":
		if ws.scene_id == bid:
			return _interactable(ws, action) if action != "" else {}
		return _exit_of(ws)
	var b := DataDB.building(bid)
	var district := str(b.get("district", ""))
	if district == ws.scene_id:
		var dp: Vector2 = ws.spawns.get("door_" + bid, Vector2.ZERO)
		if dp == Vector2.ZERO:
			return {}
		return {"pos": dp - Vector2(0, 20), "label": I18n.t(str(b.get("name", bid)))}
	return _route_to_district(ws, district)


func _route_to_district(ws: WorldScene, to: String) -> Dictionary:
	var hop := _next_hop(ws.scene_id, to)
	if hop != "":
		for e in DataDB.districts[ws.scene_id].get("exits", []):
			if str(e["to"]) == hop:
				var r: Array = e["rect"]
				var c := Vector2(float(r[0]) + float(r[2]) / 2.0, float(r[1]) + float(r[3]) / 2.0)
				var inward := -1.0 if float(r[0]) > ws.size_px.x / 2.0 else 1.0
				return {"pos": c + Vector2(inward * 18.0, 0), "label": "→ " + I18n.t(str(DataDB.districts[hop]["name"]))}
	# not walkable from here: the Metro
	var m := _interactable(ws, "metro")
	if not m.is_empty():
		m["label"] = I18n.t("Metro") + " → " + I18n.t(str(DataDB.districts[to]["name"]))
	return m


## First district to walk to on the way to `to` (breadth-first over street exits), or "".
static func _next_hop(from: String, to: String) -> String:
	var prev := {from: ""}
	var q: Array = [from]
	while not q.is_empty():
		var cur: String = q.pop_front()
		if cur == to:
			break
		for e in DataDB.districts.get(cur, {}).get("exits", []):
			var nx := str(e["to"])
			if not prev.has(nx):
				prev[nx] = cur
				q.append(nx)
	if not prev.has(to):
		return ""
	var step := to
	while prev[step] != from and prev[step] != "":
		step = prev[step]
	return step


# ------------------------------------------------------------------ drawing
func _draw_guide() -> void:
	if _target.is_empty():
		return
	var xf := get_viewport().get_canvas_transform()
	var sp: Vector2 = xf * (_target["pos"] as Vector2)
	var view := Rect2(Vector2(16, 16), Vector2(640 - 32, 360 - 32))
	var gold := Color(1.0, 0.8, 0.26)
	var ink := Color(0.1, 0.07, 0.02)
	var font := UIK.bold_font()
	var label := str(_target.get("label", ""))
	if view.has_point(sp):
		var y := sp.y - 30.0 - 6.0 * absf(sin(_t * 3.2))
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		# a pulsing ring on the spot, and a big bouncing arrow over it
		_guide.draw_arc(sp, 9.0 + pulse * 5.0, 0, TAU, 32, Color(gold, 0.45 + 0.45 * (1.0 - pulse)), 2.0)
		_guide.draw_arc(sp, 4.0, 0, TAU, 16, Color(gold, 0.9), 2.0)
		var art := Art.opt_tex("effects/guide_arrow")   # 64x16: four 16x16 frames, once the art exists
		if art != null:
			var f := int(_t * 6.0) % 4
			_guide.draw_texture_rect_region(art, Rect2(sp.x - 14, y - 18, 28, 28), Rect2(f * 16, 0, 16, 16))
		else:
			var pts := PackedVector2Array([Vector2(-6, -16), Vector2(6, -16), Vector2(6, -6), Vector2(13, -6), Vector2(0, 9), Vector2(-13, -6), Vector2(-6, -6)])
			var arrow := PackedVector2Array()
			for p in pts:
				arrow.append(p + Vector2(sp.x, y))
			_guide.draw_colored_polygon(arrow, gold)
			arrow.append(arrow[0])
			_guide.draw_polyline(arrow, ink, 1.5)
		if label != "":
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			var lp := Vector2(sp.x - w / 2.0, y - 22)
			_guide.draw_rect(Rect2(lp + Vector2(-4, -9), Vector2(w + 8, 13)), gold)
			_guide.draw_string(font, lp + Vector2(0, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
		return
	# off screen: clamp to the edge and point outwards
	var c := Vector2(320, 180)
	var dir := (sp - c).normalized()
	var k := 1e9
	if absf(dir.x) > 0.001:
		k = minf(k, ((view.end.x if dir.x > 0 else view.position.x) - c.x) / dir.x)
	if absf(dir.y) > 0.001:
		k = minf(k, ((view.end.y if dir.y > 0 else view.position.y) - c.y) / dir.y)
	var ep := c + dir * k
	var bob := 3.0 * sin(_t * 5.0)
	ep += dir * bob
	var side := dir.orthogonal()
	var tri := PackedVector2Array([ep + dir * 12.0, ep - dir * 6.0 + side * 10.0, ep - dir * 6.0 - side * 10.0])
	_guide.draw_colored_polygon(tri, gold)
	tri.append(tri[0])
	_guide.draw_polyline(tri, ink, 1.5)
	if label != "":
		var w2 := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
		var lp2 := ep - dir * 22.0 - Vector2(w2 / 2.0, -3)
		lp2.x = clampf(lp2.x, 6, 640 - 6 - w2)
		lp2.y = clampf(lp2.y, 14, 360 - 8)
		_guide.draw_rect(Rect2(lp2 + Vector2(-4, -9), Vector2(w2 + 8, 13)), gold)
		_guide.draw_string(font, lp2 + Vector2(0, 1), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, ink)
