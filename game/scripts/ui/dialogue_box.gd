class_name DialogueBox
extends Control
## Short, natural lines with portraits and choices (kickoff §31). Phone chats show a phone badge.

signal finished(conversation_id: String)

var conv: Dictionary = {}
var conv_id := ""
var lines: Array = []
var idx := 0
var on_done: Callable
var panel: PanelContainer
var portrait: PortraitView
var name_label: Label
var text_label: Label
var choice_box: VBoxContainer
var hint: Label
var phone_badge: TextureRect
var _typing := 0.0
var _full := ""
var active := false
var _waiting_choice := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	panel = UIK.panel("ui/panel", 7)
	panel.position = Vector2(40, 262)
	panel.size = Vector2(560, 90)
	panel.custom_minimum_size = Vector2(560, 90)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(_on_panel_input)
	add_child(panel)
	var h := UIK.hbox(8)
	panel.add_child(h)
	var pf := Control.new()
	pf.custom_minimum_size = Vector2(66, 66)
	pf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(pf)
	var frame_bg := ColorRect.new()
	frame_bg.color = Color8(38, 56, 88)
	frame_bg.size = Vector2(66, 66)
	frame_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pf.add_child(frame_bg)
	portrait = PortraitView.new()
	portrait.position = Vector2(1, 1)
	portrait.size = Vector2(64, 64)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pf.add_child(portrait)
	var v := UIK.vbox(2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var nh := UIK.hbox(4)
	v.add_child(nh)
	phone_badge = UIK.icon("phone", 12)
	nh.add_child(phone_badge)
	name_label = UIK.title("", 11, Art.C_GOLD)
	nh.add_child(name_label)
	text_label = UIK.wrap("", 9, Art.C_WHITE, 440)
	v.add_child(text_label)
	choice_box = UIK.vbox(2)
	v.add_child(choice_box)
	hint = UIK.label("E / click ▸", 7, Art.C_DIM)
	hint.position = Vector2(540, 338)
	add_child(hint)


func play(id: String, done := Callable()) -> void:
	conv = DataDB.dialogue.get(id, {})
	if conv.is_empty():
		push_warning("Dialogue missing: " + id)
		if done.is_valid():
			done.call()
		return
	conv_id = id
	on_done = done
	active = true
	visible = true
	Clock.push_pause("dialogue")
	phone_badge.visible = conv.get("channel", "") == "phone"
	_goto("start")


func _goto(node: String) -> void:
	lines = conv.get("nodes", {}).get(node, [])
	idx = 0
	_show()


func _show() -> void:
	UIK.clear(choice_box)
	_waiting_choice = false
	if idx >= lines.size():
		_end()
		return
	var L: Dictionary = lines[idx]
	if L.has("goto"):
		_goto(L["goto"])
		return
	var who: String = L.get("who", "")
	_set_speaker(who, L.get("expr", "neutral"))
	if L.has("choices"):
		_waiting_choice = true
		text_label.text = ""
		_full = ""
		for c in L["choices"]:
			var b := UIK.button("▸ " + EventEngine.fill(c["text"], {}), _choose.bind(c))
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.name = "Choice"
			choice_box.add_child(b)
		hint.visible = false
		return
	_full = EventEngine.fill(str(L.get("text", "")), {})
	text_label.text = _full
	text_label.visible_characters = 0
	_typing = 0.0
	hint.visible = true


func _set_speaker(who: String, expr: String) -> void:
	if who == "player":
		var p: Dictionary = GameState.data["player"]
		name_label.text = p["name"]
		portrait.setup_character(p["appearance"], p.get("outfit", "startup_casual"))
	else:
		var d := DataDB.npc(who)
		name_label.text = d.get("name", who.capitalize())
		if d.has("appearance"):
			var tints := {}
			for k in d.get("outfit_tints", {}):
				tints[k] = Color(d["outfit_tints"][k])
			portrait.setup_character(d["appearance"], d.get("outfit", "casual_tee"), tints)
		else:
			portrait.setup_icon({"shoplane": "orders", "bank": "bank", "landlord": "home", "customer": "people"}.get(who, "info"))
	portrait.set_expr(expr)


func _choose(c: Dictionary) -> void:
	if c.has("set"):
		GameState.set_flag(c["set"])
	if c.has("next"):
		_goto(c["next"])
	else:
		idx += 1
		_show()


func advance() -> void:
	if not active or _waiting_choice:
		return
	if text_label.visible_characters >= 0 and text_label.visible_characters < _full.length():
		text_label.visible_characters = -1
		return
	idx += 1
	_show()


func _end() -> void:
	active = false
	visible = false
	Clock.pop_pause("dialogue")
	for a in conv.get("on_end", []):
		StoryEngine.run_actions([a])
	var id := conv_id
	var cb := on_done
	on_done = Callable()
	EventBus.dialogue_finished.emit(id)
	finished.emit(id)
	if cb.is_valid():
		cb.call()


func _process(delta: float) -> void:
	if active and not _waiting_choice and text_label.visible_characters >= 0:
		_typing += delta * 55.0
		text_label.visible_characters = int(_typing)
		if text_label.visible_characters >= _full.length():
			text_label.visible_characters = -1


func _on_panel_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		advance()


func _unhandled_input(event: InputEvent) -> void:
	if active and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		advance()
