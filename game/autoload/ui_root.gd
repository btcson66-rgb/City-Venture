extends CanvasLayer
## Screen-space UI root: HUD, dialogue, phone, modal stack, toasts, chapter cards, fades.

var root: Control
var hud: HUD
var dialogue: DialogueBox
var phone: PhoneUI
var modal_layer: Control
var toast_box: VBoxContainer
var card_layer: Control
var fade: ColorRect
var dialogue_queue: Array = []
var _pending_reports: Array = []
var _hud_wanted := false
var _suppress_decisions := false


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIK.theme()
	add_child(root)
	hud = HUD.new()
	root.add_child(hud)
	hud.visible = false
	dialogue = DialogueBox.new()
	root.add_child(dialogue)
	phone = PhoneUI.new()
	root.add_child(phone)
	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(modal_layer)
	toast_box = UIK.vbox(3)
	toast_box.position = Vector2(170, 8)
	toast_box.custom_minimum_size = Vector2(300, 0)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_box)
	card_layer = Control.new()
	card_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	card_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(card_layer)
	fade = ColorRect.new()
	fade.color = Color8(8, 14, 26)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	root.add_child(fade)
	EventBus.notify.connect(func(t, k, i): toast(t, k, i))
	EventBus.month_closed.connect(func(r): _pending_reports.append(r))
	EventBus.message_received.connect(_on_message)


# ------------------------------------------------------------------ state
func is_blocking() -> bool:
	return dialogue.active or phone.is_open or modal_layer.get_child_count() > 0


func set_hud_visible(v: bool) -> void:
	_hud_wanted = v
	hud.visible = v
	if v:
		hud.refresh()


func on_scene_changed(_scene: Node) -> void:
	hud.refresh()
	set_prompt("")


func set_prompt(text: String) -> void:
	hud.set_prompt(text)


func close_all() -> void:
	for m in modal_layer.get_children():
		m.queue_free()
	if phone.is_open:
		phone.close()
	Clock.pop_pause("modal")


# ------------------------------------------------------------------ modals
func open_modal(m: Control) -> void:
	modal_layer.add_child(m)
	Clock.push_pause("modal")
	hud.set_prompt("")
	if m.has_signal("closed"):
		m.closed.connect(_on_modal_closed, CONNECT_DEFERRED)


func _on_modal_closed() -> void:
	await get_tree().process_frame
	var live := 0
	for c in modal_layer.get_children():
		if not c.is_queued_for_deletion():
			live += 1
	if live == 0:
		Clock.pop_pause("modal")
	hud.refresh()


func top_modal() -> Control:
	var n := modal_layer.get_child_count()
	return modal_layer.get_child(n - 1) if n > 0 else null


# ------------------------------------------------------------------ dialogue
func queue_dialogue(id: String) -> void:
	dialogue_queue.append(id)


func play_dialogue(id: String, done := Callable()) -> void:
	dialogue.play(id, done)


func _process(_delta: float) -> void:
	# toasts sit at the top in the world; while a management screen is open they drop to the bottom
	# edge so they never cover a modal's title bar
	var ty := 8.0 if modal_layer.get_child_count() == 0 else 352.0 - toast_box.size.y
	toast_box.position.y = lerpf(toast_box.position.y, ty, 0.35)
	if not GameState.has_game() or not _hud_wanted or SceneRouter.transitioning:
		return
	if Input.is_action_pressed("fast_forward") and not is_blocking():
		Clock.fast_forward = true
	else:
		Clock.fast_forward = false
	if is_blocking():
		return
	if not dialogue_queue.is_empty():
		play_dialogue(dialogue_queue.pop_front())
		return
	if not _pending_reports.is_empty():
		open_modal(MonthCloseModal.new(_pending_reports.pop_front()))
		return
	if not _suppress_decisions and not EventEngine.pending().is_empty():
		var inst := EventEngine.next_pending()
		# phone decisions surface a moment after the buzz, so the world keeps its rhythm
		if Clock.now() - int(inst.get("t", 0)) >= 2 or DataDB.events.get(inst["id"], {}).get("presentation", {}).get("channel", "") == "modal":
			open_modal(DecisionModal.new(inst))


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.has_game() or not _hud_wanted or SceneRouter.transitioning:
		return
	if event.is_action_pressed("phone") and not dialogue.active and modal_layer.get_child_count() == 0:
		get_viewport().set_input_as_handled()
		if phone.is_open:
			phone.close()
		else:
			phone.open()
	elif event.is_action_pressed("map") and not is_blocking():
		get_viewport().set_input_as_handled()
		open_modal(CityMapModal.new(false))
	elif event.is_action_pressed("pause") and not is_blocking():
		get_viewport().set_input_as_handled()
		open_modal(PauseMenu.new())


func _on_message(from_id: String, text: String) -> void:
	if not _hud_wanted:
		return
	var n: String = DataDB.npc(from_id).get("name", from_id)
	toast("%s: %s" % [n, text.left(70) + ("…" if text.length() > 70 else "")], "msg", "mail")


# ------------------------------------------------------------------ toasts & cards
func toast(text: String, kind := "info", icon := "info") -> void:
	if not is_inside_tree():
		return
	var col := Art.C_WHITE
	match kind:
		"good":
			col = Art.C_GREEN
		"bad":
			col = Art.C_RED
		"warn":
			col = Art.C_GOLD
		"msg":
			col = Art.C_SKY
	var p := UIK.panel("ui/panel", 4)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := UIK.hbox(4)
	p.add_child(h)
	h.add_child(UIK.icon(icon, 12))
	var l := UIK.wrap(text, 8, col, 270)
	h.add_child(l)
	toast_box.add_child(p)
	while toast_box.get_child_count() > 4:
		var old := toast_box.get_child(0)
		toast_box.remove_child(old)
		old.queue_free()
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.2)
	tw.tween_interval(4.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.5)
	tw.tween_callback(p.queue_free)


func show_chapter_card(title: String, subtitle := "") -> void:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var band := ColorRect.new()
	band.color = Color(0.03, 0.07, 0.14, 0.85)
	band.position = Vector2(0, 130)
	band.size = Vector2(640, 70)
	c.add_child(band)
	var gold := ColorRect.new()
	gold.color = Art.C_GOLD
	gold.position = Vector2(220, 136)
	gold.size = Vector2(200, 1)
	c.add_child(gold)
	var t := UIK.title(title, 18, Art.C_WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.position = Vector2(0, 142)
	t.size = Vector2(640, 24)
	c.add_child(t)
	var s := UIK.label(subtitle, 9, Art.C_SKY)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.position = Vector2(0, 170)
	s.size = Vector2(640, 14)
	c.add_child(s)
	card_layer.add_child(c)
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.5)
	tw.tween_interval(2.6)
	tw.tween_property(c, "modulate:a", 0.0, 0.8)
	tw.tween_callback(c.queue_free)


## First-visit establishing card (art converted from the concept boards), bottom-left, non-blocking.
func show_location_card(kind: String, id: String) -> void:
	var tex: Texture2D = null
	if ResourceLoader.exists("res://assets/cards/%s.png" % id):
		tex = Art.tex("cards/" + id)
	var title := id
	var sub := ""
	if kind == "district":
		var dd := DataDB.district_def_in_city(id)
		title = str(dd.get("name", id))
		sub = str(dd.get("blurb", ""))
	else:
		var b := DataDB.building(id)
		title = str(b.get("name", id))
		var did := str(b.get("district", ""))
		var hrs: Dictionary = b.get("hours", {})
		var open_s := str(hrs.get("open", ""))
		sub = str(DataDB.districts.get(did, {}).get("name", ""))
		if open_s != "" and open_s != "00:00":
			sub += "  ·  Open %s–%s" % [open_s, str(hrs.get("close", ""))]
		if tex == null and ResourceLoader.exists("res://assets/cards/%s.png" % did):
			tex = Art.tex("cards/" + did)
	for old in get_tree().get_nodes_in_group("location_card"):
		old.queue_free()
	var p := UIK.panel("ui/panel_glass", 4)
	p.name = "LocationCard"
	p.add_to_group("location_card")
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := UIK.vbox(2)
	p.add_child(v)
	if tex != null:
		var img := TextureRect.new()
		img.texture = tex
		img.custom_minimum_size = Vector2(192, 108)
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(img)
	v.add_child(UIK.label("NEW LOCATION", 6, Art.C_GOLD, true))
	v.add_child(UIK.title(title, 11))
	if sub != "":
		v.add_child(UIK.wrap(sub, 7, Art.C_SKY, 192))
	# below modals: a management screen opened right away should cover it
	root.add_child(p)
	root.move_child(p, modal_layer.get_index())
	p.reset_size()
	await get_tree().process_frame
	if not is_instance_valid(p):
		return
	var y := 360.0 - 8.0 - p.size.y
	p.position = Vector2(-p.size.x - 10, y)
	var tw := p.create_tween()
	tw.tween_property(p, "position:x", 6.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(5.0)
	tw.tween_property(p, "position:x", -p.size.x - 10, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_callback(p.queue_free)


func fade_out(t := 0.3) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, t)
	await tw.finished


func fade_in(t := 0.3) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 0.0, t)
	await tw.finished


func show_decision(inst: Dictionary) -> void:
	open_modal(DecisionModal.new(inst))
