class_name HUD
extends Control
## Light in-world HUD: time/date, money, objective, minimap, context prompt, energy and stress.

var time_label: Label
var vitality_label: Label
var date_label: Label
var part_icon: TextureRect
var cash_label: Label
var personal_label: Label
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
var action_hint: Label
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
var safety_button: Button
var goal_progress: ProgressBar
var goal_count: Label
var next_event_button: Button
var celebration: ProgressCelebration


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	safety_button = UIK.button("Use crosswalks for safer crossing", func(): UIRoot.open_modal(TrafficModal.new("accident")))
	safety_button.position = Vector2(220,330)
	safety_button.custom_minimum_size = Vector2(120,24)
	add_child(safety_button)
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
	var health := UIK.hbox(3)
	tv.add_child(health)
	vitality_label=UIK.label("",7,Art.C_SKY)
	health.add_child(vitality_label)
	health.add_child(UIK.tip("personal_energy"))
	health.add_child(UIK.tip("personal_stress"))
	# objective
	obj_panel = UIK.panel("ui/panel_glass", 5)
	obj_panel.position = Vector2(6, 55)
	obj_panel.custom_minimum_size = Vector2(196, 0)
	add_child(obj_panel)
	var ov := UIK.vbox(1)
	obj_panel.add_child(ov)
	var oh := UIK.hbox(3)
	ov.add_child(oh)
	oh.add_child(UIK.icon("objective", 10))
	goal_label = UIK.label("", 7, Art.C_SKY, true)
	oh.add_child(goal_label)
	obj_label = UIK.wrap("", 8, Art.C_WHITE, 184)
	ov.add_child(obj_label)
	goal_progress = ProgressBar.new()
	goal_progress.name = "ShortGoalProgress"
	goal_progress.show_percentage = false
	goal_progress.custom_minimum_size = Vector2(184, 4)
	goal_progress.add_theme_stylebox_override("background", UIK.flat(Art.C_DIM))
	goal_progress.add_theme_stylebox_override("fill", UIK.flat(Art.C_SKY))
	ov.add_child(goal_progress)
	goal_count = UIK.label("", 7, Art.C_SKY)
	ov.add_child(goal_count)
	next_event_button = UIK.button("Skip to next event", func():
		if not UIRoot.is_blocking(): FunLoop.skip_next()
		refresh())
	next_event_button.name = "SkipNextEvent"
	ov.add_child(next_event_button)
	ov.add_child(UIK.tip("short_goals"))
	celebration = ProgressCelebration.new()
	add_child(celebration)
	EventBus.progress_moment.connect(func(text, _receipt): celebration.celebrate(text))
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
	personal_label = UIK.label("PERSONAL", 6, Art.C_DIM, true)
	ml.add_child(personal_label)
	cash_label = UIK.title("", 11, Art.C_GREEN, true)
	ml.add_child(cash_label)
	today_label = UIK.label("", 6, Art.C_GREEN, true)
	today_label.add_theme_font_override("font", UIK.num_font())
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
	phone_btn = _quick_button("phone", "Phone", "phone", func(): UIRoot.toggle_phone())
	qrow.add_child(phone_btn)
	qrow.add_child(_quick_button("map", "Map", "map", func(): UIRoot.open_map()))
	qrow.add_child(_quick_button("settings", "Menu", "pause", func(): UIRoot.open_pause()))
	phone_hint = UIK.label("", 7, Art.C_SKY, true)
	phone_hint.visible = false
	phone_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quick.add_child(phone_hint)
	# F8: gold is reserved for things that need the player to act (a decision, an unpaid bill, an injury).
	action_hint = UIK.label("", 7, Art.C_GOLD, true)
	action_hint.visible = false
	action_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	quick.add_child(action_hint)
	parcels_label = UIK.label("", 7, Art.C_SKY, true)
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
	var prompt_key := UIK.label(" " + Preferences.key_caption("interact") + " ", 7, Art.C_NAVY_800, true)
	key.add_child(prompt_key)
	Preferences.changed.connect(func(): prompt_key.text = " " + Preferences.key_caption("interact") + " ")
	ph.add_child(key)
	prompt_label = UIK.label("", 8, Art.C_WHITE, true)
	ph.add_child(prompt_label)
	# autosave tick (so players can trust that a refresh / crash keeps their progress)
	save_chip = UIK.hbox(2)
	save_chip.modulate.a = 0.0
	save_chip.add_child(UIK.icon("save", 8))
	save_chip.add_child(UIK.label(I18n.t("Saved"), 6, Art.C_MUTED, true))
	add_child(save_chip)
	SaveSystem.saved.connect(_on_saved)
	EventBus.cash_changed.connect(_on_cash)
	EventBus.objective_changed.connect(refresh)
	Clock.minute_tick.connect(func(_t):
		if visible and Clock.world_active:
			_refresh_objective_hours()
			_refresh_safety())
	EventBus.message_received.connect(func(_a, _b): refresh())
	welcome = BuildingWelcome.new()
	add_child(welcome)
	here_button = _quick_button("info", "What can I do here?", "building_activities", func():
		if not UIRoot.is_blocking():
			welcome.show_card())
	here_button.name = "BuildingActivities"
	quick.add_child(here_button)


func _quick_button(icon_name: String, text: String, key: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = "HUD_" + key
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", UIK.flat(Color(0.05, 0.08, 0.15, 0.88), Color(0.45, 0.55, 0.75, 0.55), 1, 2))
	b.add_theme_stylebox_override("hover", UIK.flat(Color(0.1, 0.15, 0.26, 0.95), Art.C_SKY, 1, 2))
	b.add_theme_stylebox_override("pressed", UIK.flat(Color(0.1, 0.15, 0.26, 0.95), Art.C_SKY, 1, 2))
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
	var kl := UIK.label(Preferences.key_caption(key), 5, Art.C_NAVY_800, true)
	kl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	kc.add_child(kl)
	Preferences.changed.connect(func(): kl.text = Preferences.key_caption(key); _fit_quick.call_deferred(b, h))
	h.add_child(kc)
	b.pressed.connect(cb)
	_fit_quick.call_deferred(b, h)
	return b


func _fit_quick(b: Button, h: HBoxContainer) -> void:
	h.reset_size()
	b.custom_minimum_size = (h.get_combined_minimum_size() + Vector2(6, 4)).max(InputAccess.TARGET if InputAccess.touch_mode else Vector2(24, 18))


func relabel() -> void:
	personal_label.text = I18n.t("PERSONAL")
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
	prompt_panel.position = Vector2((get_viewport_rect().size.x - prompt_panel.size.x) / 2.0, get_viewport_rect().size.y - prompt_panel.size.y - 8)


func _process(_d: float) -> void:
	if not visible or not GameState.has_game():
		return
	vitality_label.text=I18n.t("Energy %d%% · stress %d%%")%[roundi(PersonalLife.energy()),roundi(PersonalLife.S()["stress"])]
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
	today_label.text = ("▲ " if delta >= 0 else "▼ ") + Fmt.money0(absf(delta)) + I18n.t(" today")
	today_label.add_theme_color_override("font_color", Art.C_GREEN if delta >= 0 else Art.C_RED)
	var pc := Ledger.cash("player")
	cash_label.text = Fmt.money0(pc)
	cash_label.add_theme_color_override("font_color", Art.C_GREEN if pc >= 1500 else (Art.C_SKY if pc >= 0 else Art.C_RED))
	var be := GameState.business_entity()
	co_row.visible = be != "player"
	if be != "player":
		co_name.text = GameState.entity_name(be).to_upper()
		var cc := Ledger.cash(be)
		co_label.text = Fmt.money0(cc)
		co_label.add_theme_color_override("font_color", Art.C_GREEN if cc >= 1500 else (Art.C_SKY if cc >= 0 else Art.C_RED))
	var unread := GameState.unread_messages()
	var pending := not EventEngine.pending().is_empty()
	var bills := unpaid_bill_count()
	phone_hint.text = (I18n.t("● %d new") % unread) if unread > 0 else ""
	phone_hint.visible = phone_hint.text != ""
	var needs: Array[String] = []
	if pending: needs.append(I18n.t("◆ decision"))
	if bills > 0: needs.append(I18n.t("● %d bill(s) due") % bills)
	action_hint.text = "   ".join(needs)
	action_hint.visible = action_hint.text != ""
	phone_btn.modulate = Color(1, 1, 1) if not pending else Art.C_GOLD.lerp(Color(1, 1, 1), 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0))
	quick.position = Vector2(get_viewport_rect().size.x - 6 - quick.size.x, money_panel.position.y + money_panel.size.y + 3)
	money_panel.position.x = maxf(6.0, get_viewport_rect().size.x - money_panel.size.x - 6.0)
	minimap.get_parent().visible = not InputAccess.touch_mode or get_viewport_rect().size.x >= 600
	obj_panel.visible = not InputAccess.touch_mode and not StoryEngine.main_objective().is_empty()
	var cc2 := Ecommerce.carried_count()
	parcels_label.text = (I18n.t("Carrying %d parcel%s") % [cc2, I18n.pl(cc2)]) if cc2 > 0 else ""
	var ws := SceneRouter.world_scene()
	here_button.visible = ws != null and ws.kind == "interior"


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("building_activities") and not event.is_echo() and not UIRoot.is_blocking():
		welcome.show_card()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	if not GameState.has_game():
		return
	relabel()
	var o := StoryEngine.main_objective()
	obj_panel.visible = not o.is_empty()
	goal_label.text = I18n.t(str(o.get("goal", ""))).to_upper()
	_refresh_objective_hours()
	_refresh_safety()
	var ws := SceneRouter.world_scene()
	if ws != null:
		loc_label.text = (I18n.t(DataDB.districts[ws.scene_id]["name"]) if ws.kind == "district" else I18n.t(DataDB.building(ws.scene_id).get("name", ""))).to_upper()


## The safety button shows only while an injury, medical bill or claim needs attention; refreshed on signals, not per frame.
func _refresh_safety() -> void:
	if safety_button == null or not GameState.has_game(): return
	var ws := SceneRouter.world_scene()
	var count := safety_count() if TrafficSafety.needs_attention() else 0
	safety_button.visible = ws != null and ws.kind == "district" and count > 0
	if safety_button.visible:
		var health := TrafficSafety.S()
		safety_button.text = I18n.t("Health · %d") % count
		safety_button.add_theme_color_override("font_color", Art.C_GOLD)   # an injury or bill that needs the player
		safety_button.tooltip_text = I18n.t("Injury: %s") % TrafficSafety.severity_label(str(health["injury"])) if health["injury"] != "none" else I18n.t("Medical bill or claim open")


## Open medical bills / claims, and at least one while an injury is untreated. 0 means nothing to act on.
static func safety_count() -> int:
	var health := TrafficSafety.S()
	var pending := 0
	for accident in health["accidents"]:
		if float(accident.get("debt", 0)) > 0 or (accident.get("counterparty_fault", false) and accident.get("treated", false) and not accident.get("settled", false)): pending += 1
	return maxi(1, pending) if health["injury"] != "none" else pending


## Bills the assistant has parked for the player (or their company) to pay.
static func unpaid_bill_count() -> int:
	if not GameState.data.has("assistant"): return 0
	var n := 0
	for item in AssistantPolicy.S().get("bills", []):
		if not item["paid"] and item["entity"] in ["player", GameState.company_id()]: n += 1
	return n


var _hours_key := ""
var _hours_text := ""
var _hours_until := -1


## The opening-hours line only changes when a door opens or closes, so it is cached until that minute (or the objective changes).
func _refresh_objective_hours() -> void:
	var o := StoryEngine.main_objective()
	var progress := FunLoop.progress()
	goal_progress.max_value = float(progress.get("max", 1))
	goal_progress.value = float(progress.get("value", 0))
	goal_count.text = str(progress.get("text", ""))
	var next := FunLoop.next_event()
	next_event_button.visible = next > Clock.now()
	if next_event_button.visible: next_event_button.tooltip_text = Clock.fmt_short(next)
	obj_label.text = o.get("text", "")
	var key := "%s|%s|%s" % [str(o.get("target", "")), I18n.locale(), str(Clock.day_index())]
	if key != _hours_key or _hours_until < 0 or Clock.now() >= _hours_until:
		_hours_key = key
		_hours_text = DestinationHours.target_text(o)
		var t := DestinationHours.target(o)
		var state: Dictionary = DestinationHours.status(str(t["building"]), str(t.get("npc", ""))) if t.has("building") else {}
		var boundary := int(state.get("close", -1)) if state.get("open", false) else int(state.get("next", -1))
		_hours_until = boundary if boundary > Clock.now() else Clock.now() + Clock.DAY - Clock.minute_of_day()
	if _hours_text != "": obj_label.text += "\n" + _hours_text


func _on_saved(slot: int) -> void:
	if slot != SaveSystem.current_slot() or not visible:
		return
	(save_chip.get_child(1) as Label).text = I18n.t("Saved")
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
	# Large property payments must stay inside the viewport as well as ordinary small cash deltas.
	l.position = Vector2(640 - 6 - l.get_combined_minimum_size().x, 40 if entity == "player" else 62)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y + 14, 1.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.2)
	tw.tween_callback(l.queue_free)
