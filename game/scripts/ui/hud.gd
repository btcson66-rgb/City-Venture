class_name HUD
extends Control
## Light in-world HUD (Handoff §51): time/date, money, objective, minimap, context prompt. Nothing else.

var time_label: Label
var date_label: Label
var part_icon: TextureRect
var ff_label: Label
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
var parcels_label: Label
var loc_label: Label
var today_label: Label
var part_label: Label
var _last_cash := {}
var _delta_t := -1
var _delta := 0.0


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
	time_label = UIK.title("", 11)
	trow.add_child(time_label)
	part_label = UIK.label("", 7, Art.C_SKY, true)
	trow.add_child(part_label)
	ff_label = UIK.label("▶▶", 7, Art.C_GOLD, true)
	trow.add_child(ff_label)
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
	cash_label = UIK.title("", 11, Art.C_GREEN)
	ml.add_child(cash_label)
	today_label = UIK.label("", 6, Art.C_GREEN, true)
	ml.add_child(today_label)
	co_row = UIK.hbox(4)
	mv.add_child(co_row)
	co_row.add_child(UIK.icon("company", 14))
	var cl := UIK.vbox(0)
	co_row.add_child(cl)
	co_name = UIK.label("", 6, Art.C_DIM, true)
	cl.add_child(co_name)
	co_label = UIK.title("", 10, Art.C_GREEN)
	cl.add_child(co_label)
	# phone hint + parcels
	phone_hint = UIK.label("", 7, Art.C_MUTED, true)
	phone_hint.position = Vector2(640 - 132, 74)
	add_child(phone_hint)
	parcels_label = UIK.label("", 7, Art.C_GOLD, true)
	parcels_label.position = Vector2(640 - 132, 84)
	add_child(parcels_label)
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
	add_child(prompt_panel)
	var ph := UIK.hbox(5)
	prompt_panel.add_child(ph)
	var key := UIK.panel("ui/prompt_key", 2)
	key.add_child(UIK.label(" E ", 7, Art.C_NAVY_800, true))
	ph.add_child(key)
	prompt_label = UIK.label("", 8, Art.C_WHITE, true)
	ph.add_child(prompt_label)
	EventBus.cash_changed.connect(_on_cash)
	EventBus.objective_changed.connect(refresh)
	EventBus.message_received.connect(func(_a, _b): refresh())


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
	ff_label.visible = Clock.fast_forward and not Clock.is_paused()
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
	phone_hint.text = I18n.t("[Tab] Phone") + (I18n.t("  ● %d new") % unread if unread > 0 else "") + (I18n.t("   ⚑ decision") if not EventEngine.pending().is_empty() else "")
	phone_hint.add_theme_color_override("font_color", Art.C_GOLD if unread > 0 or not EventEngine.pending().is_empty() else Art.C_MUTED)
	var cc2 := Ecommerce.carried_count()
	parcels_label.text = (I18n.t("Carrying %d parcel%s") % [cc2, I18n.pl(cc2)]) if cc2 > 0 else ""


func refresh() -> void:
	if not GameState.has_game():
		return
	var o := StoryEngine.main_objective()
	obj_panel.visible = not o.is_empty()
	goal_label.text = I18n.t(str(o.get("goal", ""))).to_upper()
	obj_label.text = o.get("text", "")
	var ws := SceneRouter.world_scene()
	if ws != null:
		loc_label.text = (I18n.t(DataDB.districts[ws.scene_id]["name"]) if ws.kind == "district" else I18n.t(DataDB.building(ws.scene_id).get("name", ""))).to_upper()


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
