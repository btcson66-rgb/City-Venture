class_name BuildingWelcome
extends PanelContainer
## Dismissible, nonblocking room summary beneath the objective. Counts live in saves; marker settings do not.

var remaining := 0.0
var building_id := ""
var text: Label
var head: Label
var schedule: Label
var _last_minute := -1


func _ready() -> void:
	self.name = "BuildingWelcome"
	add_theme_stylebox_override("panel", UIK.flat(Color(0.04, 0.08, 0.14, 0.95), Art.C_SKY, 1, 5))
	custom_minimum_size = Vector2(220, 0)
	visible = false
	var v := UIK.vbox(3)
	add_child(v)
	var h := UIK.hbox(3)
	v.add_child(h)
	head = UIK.label("", 8, Art.C_GOLD, true)
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.clip_text = true
	h.add_child(head)
	var dismiss := UIK.button("×", hide_card)
	dismiss.name = "DismissBuildingWelcome"
	h.add_child(dismiss)
	schedule = UIK.wrap("", 7, Art.C_MUTED, 208)
	v.add_child(schedule)
	text = UIK.wrap("", 7, Art.C_WHITE, 208)
	v.add_child(UIK.scroll(text, Vector2(208, 56)))
	EventBus.location_entered.connect(_entered)


func _entered(kind: String, id: String) -> void:
	hide_card()
	building_id = id if kind == "interior" else ""
	if kind != "interior": return
	var visits := BuildingInfo.record_entry(id)
	# The card introduces a place on the first visits; later, it still appears when the doors are about to close.
	if visits <= 2 or closes_soon(id):
		show_card()


static func closes_soon(id: String) -> bool:
	var close := int(DestinationHours.status(id)["close"])
	return close >= 0 and close - Clock.now() <= 60


func show_card() -> void:
	var ws := SceneRouter.world_scene()
	if ws == null or ws.kind != "interior":
		return
	building_id = ws.scene_id
	remaining = 4.0
	_last_minute = -1
	modulate.a = 0.0
	_refresh()


func hide_card() -> void:
	remaining = 0.0
	visible = false


func _refresh() -> void:
	var ws := SceneRouter.world_scene()
	head.text = I18n.t(str(DataDB.building(building_id).get("name", building_id)))
	schedule.text = BuildingInfo.hours(building_id) + " · " + BuildingInfo.status(building_id)
	text.text = BuildingInfo.welcome(building_id, ws)
	_last_minute = Clock.now()


func _process(delta: float) -> void:
	if remaining <= 0:
		return
	var ws := SceneRouter.world_scene()
	if ws == null or ws.kind != "interior" or ws.scene_id != building_id:
		hide_card()
		return
	visible = not UIRoot.is_blocking() and not SceneRouter.transitioning and UIRoot.hud.visible
	if not visible:
		return
	if _last_minute != Clock.now():
		_refresh()
	var op := UIRoot.hud.obj_panel
	position = Vector2(6, op.position.y + op.size.y + 4 if op.visible else 42.0)
	remaining = maxf(0.0, remaining - delta)
	modulate.a = minf(modulate.a + delta * 5.0, minf(1.0, remaining * 4.0))
	if remaining <= 0:
		hide_card()
