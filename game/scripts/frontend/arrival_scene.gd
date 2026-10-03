class_name ArrivalScene
extends Control
## Arrival (Handoff §4): the train crosses into Aurelia at dusk; the phone shows balance and rent.

var t := 0.0
var train: Control
var title: Label
var phone: PanelContainer
var lines: VBoxContainer
var hint: Label
var done := false
var stage := 0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UIK.theme()
	add_child(Backdrop.make("backdrops/arrival", 1.0e9))
	var bridge := ColorRect.new()
	bridge.color = Color8(26, 28, 44)
	bridge.position = Vector2(0, 280)
	bridge.size = Vector2(640, 8)
	add_child(bridge)
	for x in range(0, 640, 48):
		var p := ColorRect.new()
		p.color = Color8(22, 24, 38)
		p.position = Vector2(x, 288)
		p.size = Vector2(6, 40)
		add_child(p)
	train = Control.new()
	train.position = Vector2(-420, 236)
	add_child(train)
	for i in 3:
		var car := TextureRect.new()
		car.texture = Art.tex("vehicles/metro_train")
		car.position = Vector2(i * 126, 4)
		train.add_child(car)
	title = UIK.title("AURELIA CITY", 30, Color8(240, 244, 255))
	title.position = Vector2(0, 60)
	title.size = Vector2(640, 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.modulate.a = 0.0
	add_child(title)
	var sub := UIK.label("Population 3.2 million. One more, as of today.", 9, Art.C_SKY)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(0, 98)
	sub.size = Vector2(640, 14)
	title.add_child(sub)
	sub.position = Vector2(0, 38)
	phone = UIK.panel("ui/panel", 10)
	phone.position = Vector2(220, 70)
	phone.custom_minimum_size = Vector2(200, 150)
	phone.modulate.a = 0.0
	add_child(phone)
	var pv := UIK.vbox(4)
	phone.add_child(pv)
	var hh := UIK.hbox(4)
	hh.add_child(UIK.icon("bank", 14))
	hh.add_child(UIK.label("NEXUS BANK", 8, Art.C_MUTED, true))
	pv.add_child(hh)
	pv.add_child(UIK.label("BANK BALANCE", 7, Art.C_DIM, true))
	pv.add_child(UIK.title(Fmt.money0(float(DataDB.living().get("start_cash", 30000))), 20, Art.C_GREEN))
	pv.add_child(UIK.sep())
	pv.add_child(UIK.label("RENT DUE IN 14 DAYS", 7, Art.C_DIM, true))
	pv.add_child(UIK.title(Fmt.money0(float(DataDB.living().get("home_rent", 1250))), 14, Art.C_GOLD))
	pv.add_child(UIK.label("Riverside Tower · Unit 7C", 7, Art.C_MUTED))
	lines = UIK.vbox(2)
	lines.position = Vector2(0, 300)
	lines.custom_minimum_size = Vector2(640, 0)
	add_child(lines)
	hint = UIK.label("E / click to skip", 7, Art.C_DIM)
	hint.position = Vector2(560, 346)
	add_child(hint)


func _line(text: String) -> void:
	var l := UIK.label(text, 9, Art.C_WHITE)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(640, 12)
	l.modulate.a = 0.0
	lines.add_child(l)
	create_tween().tween_property(l, "modulate:a", 1.0, 0.6)


func _process(delta: float) -> void:
	t += delta
	train.position.x += 95.0 * delta
	if stage == 0 and t > 1.2:
		stage = 1
		create_tween().tween_property(title, "modulate:a", 1.0, 1.0)
	if stage == 1 and t > 4.2:
		stage = 2
		create_tween().tween_property(title, "modulate:a", 0.0, 0.6)
		create_tween().tween_property(phone, "modulate:a", 1.0, 0.6)
	if stage == 2 and t > 5.4:
		stage = 3
		_line("You quit your job. You have savings, a laptop, a phone — and a lease.")
	if stage == 3 and t > 7.4:
		stage = 4
		_line("Riverside District. Your first place in the city.")
	if stage == 4 and t > 10.0:
		_finish()


func _finish() -> void:
	if done:
		return
	done = true
	SceneRouter.begin_world()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") or (event is InputEventMouseButton and event.pressed):
		if stage < 4 and t > 1.0:
			t = maxf(t, [0, 4.3, 5.5, 7.5, 10.1][stage])
		else:
			_finish()
