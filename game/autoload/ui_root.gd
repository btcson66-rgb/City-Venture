extends CanvasLayer
## Screen-space UI root: HUD, dialogue, phone, modal stack, toasts, chapter cards, fades.

var root: Control
var hud: HUD
var tutorial: Tutorial
var coach_layer: Control
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
	tutorial = Tutorial.new()
	root.add_child(tutorial)
	dialogue = DialogueBox.new()
	root.add_child(dialogue)
	phone = PhoneUI.new()
	root.add_child(phone)
	modal_layer = Control.new()
	modal_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(modal_layer)
	# the tutorial's coach draws here: above the phone and any open screen, so it can point at the button to press
	coach_layer = Control.new()
	coach_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	coach_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(coach_layer)
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


## Time stops only while a screen that asks for it (Modal.pauses_time) is open; everything else lets the day run on.
func _update_modal_pause() -> void:
	var stop := false
	for c in modal_layer.get_children():
		if not c.is_queued_for_deletion() and bool(c.get("pauses_time")):
			stop = true
	if stop:
		Clock.push_pause("modal")
	else:
		Clock.pop_pause("modal")


# ------------------------------------------------------------------ modals
func open_modal(m: Control) -> void:
	modal_layer.add_child(m)
	_update_modal_pause()
	hud.set_prompt("")
	if m.has_signal("closed"):
		m.closed.connect(_on_modal_closed, CONNECT_DEFERRED)


func _on_modal_closed() -> void:
	await get_tree().process_frame
	_update_modal_pause()
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
	# toasts sit at the top in the world. With a screen open, only the newest one shows, tucked under
	# the panel when there is room, so it never stacks over choices or report lines.
	var tm := top_modal()
	var n := toast_box.get_child_count()
	for i in n:
		(toast_box.get_child(i) as Control).visible = tm == null or i == n - 1
	var ty := 8.0
	if tm != null:
		var th := toast_box.get_combined_minimum_size().y
		var pb := 352.0
		var md := tm as Modal
		if md != null and md.panel != null:
			pb = md.panel.position.y + md.panel.size.y
		ty = pb + 3.0 if pb + 3.0 + th <= 358.0 else 358.0 - th
	toast_box.position.y = lerpf(toast_box.position.y, ty, 0.35)
	# a first-visit card never sits on top of a conversation or a management screen
	var busy := dialogue.active or modal_layer.get_child_count() > 0 or phone.is_open
	for c in get_tree().get_nodes_in_group("location_card"):
		c.visible = not busy
	if not GameState.has_game() or not _hud_wanted or SceneRouter.transitioning:
		return
	if is_blocking():
		return
	if not dialogue_queue.is_empty():
		play_dialogue(dialogue_queue.pop_front())
		return
	if Insolvency.active():
		var open := false
		for m in modal_layer.get_children():
			if m is InsolvencyModal:
				open = true
		if not open:
			open_modal(InsolvencyModal.new())
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
	if event.is_action_pressed("bug_report"):
		get_viewport().set_input_as_handled()
		report_problem()
		return
	if not GameState.has_game() or not _hud_wanted or SceneRouter.transitioning:
		return
	if event.is_action_pressed("phone") and not dialogue.active and modal_layer.get_child_count() == 0:
		get_viewport().set_input_as_handled()
		toggle_phone()
	elif event.is_action_pressed("map") and not is_blocking():
		get_viewport().set_input_as_handled()
		open_map()
	elif event.is_action_pressed("pause") and not is_blocking():
		get_viewport().set_input_as_handled()
		open_pause()


## Part-time job shift: fade out, four hours pass, wages paid, fade in with what happened.
## A shift is played: the job's minigame opens, and its score sets the pay (see Careers.work_shift).
func work_shift_flow(job_id: String) -> void:
	var g := MiniGames.for_job(job_id)
	if g == null:
		_finish_shift(job_id, {"score": 1.0})
		return
	MiniGames.play(g, func(res: Dictionary):
		if res.get("aborted", false):
			toast("You left before the shift was done. No pay, and no time lost.", "warn", "clock")
			return
		_finish_shift(job_id, res))


func _finish_shift(job_id: String, res: Dictionary) -> void:
	await fade_out(0.35)
	var r := Careers.work_shift(job_id, float(res.get("score", 1.0)), float(res.get("tips", 0.0)))
	await fade_in(0.35)
	if not r["ok"]:
		toast(I18n.t(str(r["error"])), "warn", "lock")
		return
	toast(str(r["moment"]), "info", "clock")
	toast(I18n.t("Shift done: +%s (wages and tips).") % Fmt.money0(r["pay"]), "good", "cash")
	if not r.get("counted", true):
		toast("A rough shift: it doesn't count toward your next promotion.", "warn", "people")
	if r["promoted"]:
		show_chapter_card(I18n.t("PROMOTED"), I18n.t(str(r["title"])))
	SaveSystem.autosave_if_changed()


## Shared by the keys and the HUD quick-bar buttons.
func toggle_phone() -> void:
	if dialogue.active or modal_layer.get_child_count() > 0 or SceneRouter.transitioning:
		return
	if phone.is_open:
		phone.close()
	else:
		phone.open()


func open_map() -> void:
	if not is_blocking() and not SceneRouter.transitioning:
		open_modal(CityMapModal.new(false))


func open_pause() -> void:
	if not is_blocking() and not SceneRouter.transitioning:
		open_modal(PauseMenu.new())


func _on_message(from_id: String, text: String) -> void:
	if not _hud_wanted:
		return
	var n: String = I18n.t(DataDB.npc(from_id).get("name", from_id))
	text = I18n.t(text)
	toast(("%s：%s" if I18n.is_zh() else "%s: %s") % [n, text.left(70) + ("…" if text.length() > 70 else "")], "msg", "mail")


# ------------------------------------------------------------------ toasts & cards
## Every toast shown (the bots log the red ones, so a refused action names its reason).
signal toasted(text: String, kind: String)


func toast(text: String, kind := "info", icon := "info") -> void:
	if not is_inside_tree():
		return
	toasted.emit(text, kind)
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
	UIK.ignore_mouse(p)
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


## Title band across the screen. `art` (a 640x360 illustration, e.g. backdrops/chapter_3) fills the screen
## behind the band when that file exists.
func show_chapter_card(title: String, subtitle := "", art := "") -> void:
	var c := Control.new()
	c.name = "ChapterCard"
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pic := Art.opt_tex(art) if art != "" else null
	if pic != null:
		var bg := TextureRect.new()
		bg.name = "Art"
		bg.texture = pic
		bg.position = Vector2.ZERO
		bg.size = Vector2(640, 360)
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		c.add_child(bg)
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
	UIK.ignore_mouse(c)
	card_layer.add_child(c)
	c.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(c, "modulate:a", 1.0, 0.5)
	tw.tween_interval(3.6 if pic != null else 2.6)
	tw.tween_property(c, "modulate:a", 0.0, 0.8)
	tw.tween_callback(c.queue_free)


## Tester bug report (F12). Works on the menu and in game.
func report_problem() -> void:
	var path: String = await BugReport.capture(get_tree())
	toast(I18n.t("Problem report saved (screenshot + save + log). Send this folder to whoever invited you to test: %s") % path, "good", "info")


## First-visit establishing card (art converted from the concept boards), bottom-left, non-blocking.
func show_location_card(kind: String, id: String) -> void:
	if kind == "interior":
		return   # The live, dismissible BuildingWelcome supplies the room's name, hours and activities.
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
		sub = str(I18n.t(DataDB.districts.get(did, {}).get("name", "")))
		if open_s != "" and open_s != "00:00":
			sub += I18n.t("  ·  Open %s–%s") % [open_s, str(hrs.get("close", ""))]
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
	UIK.ignore_mouse(p)
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


## Rebuild text that was formatted at build time (objective, location) after a language switch.
func language_changed() -> void:
	hud.refresh()
	hud.relabel()
	title_refresh_all()


func title_refresh_all() -> void:
	for m in modal_layer.get_children():
		if m is Modal and not m is PauseMenu:
			(m as Modal).rebuild()


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
