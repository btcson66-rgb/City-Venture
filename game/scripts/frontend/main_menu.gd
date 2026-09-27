class_name MainMenu
extends Control
## Title screen: New Game / Continue / Quit.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UIK.theme()
	add_child(Skyline.new())
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.06, 0.12, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var shadow := UIK.title("CITY VENTURE", 40, Color8(20, 40, 90))
	shadow.position = Vector2(42, 34)
	add_child(shadow)
	var t := UIK.title("CITY VENTURE", 40, Color8(236, 242, 255))
	t.position = Vector2(40, 31)
	add_child(t)
	var tag := UIK.title("BUILD  ·  LIVE  ·  CONNECT  ·  GROW", 10, Art.C_SKY)
	tag.position = Vector2(44, 84)
	add_child(tag)
	var sub := UIK.label("A business-simulation RPG in a living, modern city.", 9, Art.C_WHITE)
	sub.position = Vector2(44, 100)
	add_child(sub)
	var box := UIK.vbox(5)
	box.position = Vector2(44, 132)
	box.custom_minimum_size = Vector2(150, 0)
	add_child(box)
	var ng := UIK.button("New Game", func(): SceneRouter.go_creator(), "primary", 150)
	ng.name = "NewGame"
	box.add_child(ng)
	var slot := SaveSystem.latest_slot()
	var cont := UIK.button("Continue", func(): SaveSystem.load_and_enter(slot), "", 150)
	cont.name = "Continue"
	cont.disabled = slot < 0
	box.add_child(cont)
	if slot >= 0:
		var sm := SaveSystem.summary(slot)
		box.add_child(UIK.label("%s · %s · Day %d" % [sm.get("name", ""), sm.get("company", ""), int(sm.get("day", 0))], 7, Art.C_MUTED))
	box.add_child(UIK.button("Quit", func(): get_tree().quit(), "", 150))
	var ver := UIK.label("VERTICAL SLICE 001 · placeholder pixel art · %s" % ProjectSettings.get_setting("application/config/version", ""), 7, Art.C_DIM)
	ver.position = Vector2(8, 346)
	add_child(ver)
