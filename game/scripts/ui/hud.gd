class_name HUD
extends Control
## Light in-world HUD (Handoff §51): time/date, money, objective, minimap, context prompt. Nothing else.

var time_label: Label
var date_label: Label
var part_icon: TextureRect
var cash_label: Label
var co_row: HBoxContainer
var co_label: Label
var co_name: Label
var goal_label: Label
var obj_label: Label
var obj_panel: PanelContainer
var prompt_panel: PanelContainer
var prompt_label: Label
var minimap: Minimap
var phone_hint: Label
var phone_btn: Button
var quick: VBoxContainer
var money_panel: PanelContainer
var save_chip: HBoxContainer
var parcels_label: Label
var loc_label: Label
var today_label: Label
var part_label: Label
var _last_cash := {}
var _delta_t := -1
var _delta := 0.0
var welcome: BuildingWelcome
var here_button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# time card
	var tp := UIK.panel("ui/panel_glass", 5)
	tp.position = Vector2(6, 6)
	add_child(tp)
	var th := UIK.hbox(5)
	tp.add_child(th)
	part_icon = UIK.icon("sun", 16)
	th.add_child(part_icon)
	var tv := UIK.vbox(0)
	th.add_child(tv)
	date_label = UIK.label("", 7, Art.C_MUTED, true)
	tv.add_child(date_label)
	var trow := UIK.hbox(4)
	tv.add_child(trow)
	time_label = UIK.title("", 11, Art.C_WHITE, true)
	trow.add_child(time_label)
	part_label = UIK.label("", 7, Art.C_SKY, true)
	trow.add_child(part_label)
	# objective
	obj_panel = UIK.panel("ui/panel_glass", 5)
	obj_panel.position = Vector2(6, 42)
	obj_panel.custom_minimum_size = Vector2(196, 0)
	add_child(obj_panel)
	var ov := UIK.vbox(1)
	obj_panel.add_child(ov)
	var oh := UIK.hbox(3)
	ov.add_child(oh)
	oh.add_child(UIK.icon("objective", 10))
	goal_label = UIK.label("", 7, Art.C_GOLD, true)
	oh.add_child(goal_label)
	obj_label = UIK.wrap("", 8, Art.C_WHITE, 184)
	ov.add_child(obj_label)
	# money
	var mp := UIK.panel("ui/panel_glass", 5)
	mp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mp.position = Vector2(640 - 136, 6)
	mp.custom_minimum_size = Vector2(130, 0)
	add_child(mp)
	var mv := UIK.vbox(1)
	mp.add_child(mv)
	var mh := UIK.hbox(4)
	mv.add_child(mh)
	mh.add_child(UIK.icon("cash", 14))
	var ml := UIK.vbox(0)
	mh.add_child(ml)
	ml.add_child(UIK.label("PERSONAL", 6, Art.C_DIM, true))
	cash_label = UIK.title("", 11, Art.C_GREEN, true)
	ml.add_child(cash_label)
	today_label = UIK.label("", 6, Art.C_GREEN, true)
	ml.add_child(today_label)
	co_row = UIK.hbox(4)
	mv.add_child(co_row)
	co_row.add_child(UIK.icon("company", 14))
	var cl := UIK.vbox(0)
	co_row.add_child(cl)
	co_name = UIK.label("", 6, Art.C_DIM, true)
	co_name.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	cl.add_child(co_name)
	co_label = UIK.title("", 10, Art.C_GREEN, true)
	cl.add_child(co_label)
	money_panel = mp
	# quick bar: phone / map / menu as real buttons on a solid chip, so they read over any scene and can
	# be tapped (touch builds) as well as reached by key
	quick = UIK.vbox(2)
	quick.position = Vector2(640 - 136, 58)
	add_child(quick)
	var qrow := UIK.hbox(2)
	quick.add_child(qrow)
	quick.alignment = BoxContainer.ALIGNMENT_END
	qrow.alignment = BoxContainer.ALIGNMENT_END
	phone_btn = _quick_button("phone", "Phone", "Tab", func(): UIRoot.toggle_phone())
	qrow.add_child(phone_btn)
	qrow.add_child(_quick_button("map", "Map", "M", func(): UIRoot.open_map()))
	qrow.add_child(_quick_button("settings", "Menu", "Esc", func(): UIRoot.open_pause()))
	phone_hint = UIK.label("", 7, Art.C_GOLD, true)
	phone_hint.visible = false
	phone_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quick.add_child(phone_hint)
	parcels_label = UIK.label("", 7, Art.C_GOLD, true)
	parcels_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quick.add_child(parcels_label)
	# minimap
	var mmp := UIK.panel("ui/panel_glass", 3)
	mmp.position = Vector2(640 - 132, 360 - 84)
	add_child(mmp)
	minimap = Minimap.new()
	minimap.custom_minimum_size = Vector2(122, 70)
	mmp.add_child(minimap)
	loc_label = UIK.label("", 7, Art.C_WHITE, true)
	loc_label.position = Vector2(640 - 130, 360 - 96)
	add_child(loc_label)
	# prompt
	prompt_panel = UIK.panel("ui/panel", 5)
	prompt_panel.visible = false
	prompt_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	prompt_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	prompt_panel.gui_input.connect(func(ev: InputEvent):
		if (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT) or (ev is InputEventScreenTouch and ev.pressed):
			var pl := get_tree().get_first_node_in_group("player")
			if pl != null:
				pl.interact_now())
	add_child(prompt_panel)
	var ph := UIK.hbox(5)
	prompt_panel.add_child(ph)
	var key := UIK.panel("ui/prompt_key", 2)
	key.add_child(UIK.label(" E ", 7, Art.C_NAVY_800, true))
	ph.add_child(key)
	prompt_label = UIK.label("", 8, Art.C_WHITE, true)
	ph.add_child(prompt_label)
	# autosave tick (so players can trust that a refresh / crash keeps their progress)
	save_chip = UIK.hbox(2)
	save_chip.modulate.a = 0.0
	save_chip.add_child(UIK.icon("save", 8))
	save_chip.add_child(UIK.label("Saved", 6, Art.C_MUTED, true))
	add_child(save_chip)
	SaveSystem.saved.connect(_on_saved)
	EventBus.cash_changed.connect(_on_cash)
	EventBus.objective_changed.connect(refresh)
	EventBus.message_received.connect(func(_a, _b): refresh())
	welcome = BuildingWelcome.new()
	add_child(welcome)
	here_button = _quick_button("info", "What can I do here?", "I", func():
		if not UIRoot.is_blocking():
			welcome.show_card())
	here_button.name = "BuildingActivities"
	quick.add_child(here_button)


func _quick_button(icon_name: String, text: String, key: String, cb: Callable) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", UIK.flat(Color(0.05, 0.08, 0.15, 0.88), Color(0.45, 0.55, 0.75, 0.55), 1, 2))
	b.add_theme_stylebox_override("hover", UIK.flat(Color(0.1, 0.15, 0.26, 0.95), Art.C_GOLD, 1, 2))
	b.add_theme_stylebox_override("pressed", UIK.flat(Color(0.1, 0.15, 0.26, 0.95), Art.C_GOLD, 1, 2))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var h := UIK.hbox(2)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.position = Vector2(3, 2)
	b.add_child(h)
	h.add_child(UIK.icon(icon_name, 8))
	var l := UIK.label(I18n.t(text), 6, Art.C_WHITE, true)
	l.set_meta("source_text", text)
	l.name = "Text"
	h.add_child(l)
	var kc := PanelContainer.new()
	var ks := UIK.flat(Color(0.85, 0.88, 0.95, 0.9), Color(0, 0, 0, 0), 0, 1)
	ks.content_margin_left = 2
	ks.content_margin_right = 2
	ks.content_margin_top = 0
	ks.content_margin_bottom = 0
	kc.add_theme_stylebox_override("panel", ks)
	kc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var kl := UIK.label(key, 5, Art.C_NAVY_800, true)
	kl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	kc.add_child(kl)
	h.add_child(kc)
	b.pressed.connect(cb)
	_fit_quick.call_deferred(b, h)
	return b


func _fit_quick(b: Button, h: HBoxContainer) -> void:
	h.reset_size()
	b.custom_minimum_size = h.get_combined_minimum_size() + Vector2(6, 4)


func relabel() -> void:
	for b in quick.get_child(0).get_children():
		var label: Label = b.get_child(0).get_node("Text")
		label.text = I18n.t(str(label.get_meta("source_text")))
		_fit_quick.call_deferred(b, b.get_child(0))
	if here_button != null:
		var label: Label = here_button.get_child(0).get_node("Text")
		label.text = I18n.t(str(label.get_meta("source_text")))
		_fit_quick.call_deferred(here_button, here_button.get_child(0))


func set_prompt(text: String) -> void:
	prompt_panel.visible = text != ""
	prompt_label.text = text
	prompt_panel.reset_size()
	await get_tree().process_frame
	prompt_panel.position = Vector2((640 - prompt_panel.size.x) / 2.0, 360 - 34)


func _process(_d: float) -> void:
	if not visible or not GameState.has_game():
		return
	time_label.text = Clock.fmt_time()
	date_label.text = Clock.fmt_date().to_upper() + I18n.t("  ·  DAY %d") % Clock.day_index()
	var nf := Clock.night_factor()
	part_icon.texture = Art.icon("moon" if nf > 0.5 else "sun")
	part_label.text = {"morning": "Morning · Sunny", "afternoon": "Afternoon · Sunny", "evening": "Evening", "night": "Night"}.get(Clock.day_part(), "")
	if _delta_t != Clock.now():
		_delta_t = Clock.now()
		var day0 := Clock.now() - Clock.minute_of_day()
		_delta = 0.0
		for ent in (["player", GameState.business_entity()] if GameState.business_entity() != "player" else ["player"]):
			_delta += Ledger.operating_cash_since(ent, day0)
	var delta := _delta
	today_label.text = ("▲ " if delta >= 0 else "▼ ") + Fmt.money(absf(delta)) + I18n.t(" today")
	today_label.add_theme_color_override("font_color", Art.C_GREEN if delta >= 0 else Art.C_RED)
	var pc := Ledger.cash("player")
	cash_label.text = Fmt.money(pc)
	cash_label.add_theme_color_override("font_color", Art.C_GREEN if pc >= 1500 else (Art.C_GOLD if pc >= 0 else Art.C_RED))
	var be := GameState.business_entity()
	co_row.visible = be != "player"
	if be != "player":
		co_name.text = GameState.entity_name(be).to_upper()
		var cc := Ledger.cash(be)
		co_label.text = Fmt.money(cc)
		co_label.add_theme_color_override("font_color", Art.C_GREEN if cc >= 1500 else (Art.C_GOLD if cc >= 0 else Art.C_RED))
	var unread := GameState.unread_messages()
	var pending := not EventEngine.pending().is_empty()
	phone_hint.text = ((I18n.t("● %d new") % unread) if unread > 0 else "") + ((I18n.t("   ◆ decision")) if pending else "")
	phone_hint.visible = phone_hint.text != ""
	phone_btn.modulate = Color(1, 1, 1) if unread == 0 and not pending else Color(1.0, 0.92, 0.6).lerp(Color(1, 1, 1), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0))
	quick.position = Vector2(640 - 6 - quick.size.x, money_panel.position.y + money_panel.size.y + 3)
	var cc2 := Ecommerce.carried_count()
	parcels_label.text = (I18n.t("Carrying %d parcel%s") % [cc2, I18n.pl(cc2)]) if cc2 > 0 else ""
	var ws := SceneRouter.world_scene()
	here_button.visible = ws != null and ws.kind == "interior"


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_I and not UIRoot.is_blocking():
		welcome.show_card()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	if not GameState.has_game():
		return
	relabel()
	var o := StoryEngine.main_objective()
	obj_panel.visible = not o.is_empty()
	goal_label.text = I18n.t(str(o.get("goal", ""))).to_upper()
	obj_label.text = o.get("text", "")
	var ws := SceneRouter.world_scene()
	if ws != null:
		loc_label.text = (I18n.t(DataDB.districts[ws.scene_id]["name"]) if ws.kind == "district" else I18n.t(DataDB.building(ws.scene_id).get("name", ""))).to_upper()


func _on_saved(slot: int) -> void:
	if slot != SaveSystem.current_slot() or not visible:
		return
	save_chip.reset_size()
	save_chip.position = Vector2(640 - 8 - save_chip.size.x, 360 - 97)
	var tw := create_tween()
	tw.tween_property(save_chip, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.0)
	tw.tween_property(save_chip, "modulate:a", 0.0, 0.6)


func _on_cash(entity: String, delta: float) -> void:
	if not visible or absf(delta) < 0.01:
		return
	var l := UIK.title(Fmt.money(delta, true), 9, Art.C_GREEN if delta > 0 else Art.C_RED)
	l.position = Vector2(640 - 70, 40 if entity == "player" else 62)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y + 14, 1.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.2)
	tw.tween_callback(l.queue_free)
