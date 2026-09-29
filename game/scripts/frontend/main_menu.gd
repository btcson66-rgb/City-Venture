class_name MainMenu
extends Control
## Title screen: New Game / Continue / Quit.


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UIK.theme()
	add_child(Backdrop.make("backdrops/menu"))
	# navy wash on the left third so the title and buttons read over the street scene
	var g := Gradient.new()
	g.set_color(0, Color(0.035, 0.07, 0.15, 0.92))
	g.set_color(1, Color(0.035, 0.07, 0.15, 0.0))
	g.add_point(0.45, Color(0.035, 0.07, 0.15, 0.72))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.width = 64
	gt.height = 4
	var shade := TextureRect.new()
	shade.texture = gt
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.position = Vector2.ZERO
	shade.size = Vector2(380, 360)
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
	# a new game always gets its own save slot: it never overwrites the game you were playing
	var ng := UIK.button("New Game", _new_game, "primary", 150)
	ng.name = "NewGame"
	box.add_child(ng)
	var slot := SaveSystem.latest_slot()
	var cont := UIK.button("Continue", func(): SaveSystem.load_and_enter(slot), "", 150)
	cont.name = "Continue"
	cont.disabled = slot < 0
	box.add_child(cont)
	if slot >= 0:
		var sm := SaveSystem.summary(slot)
		var last := UIK.label(I18n.t("%s · %s · Day %d") % [sm.get("name", ""), sm.get("company", ""), int(sm.get("day", 0))], 7, Art.C_MUTED)
		last.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		box.add_child(last)
	var saves := SaveSystem.save_list().size()
	var lg := UIK.button(I18n.t("Load game (%d)") % saves, func(): UIRoot.open_modal(SaveListModal.new("load")), "", 150)
	lg.name = "LoadGame"
	lg.disabled = saves == 0
	box.add_child(lg)
	box.add_child(UIK.button("Quit", func(): get_tree().quit(), "", 150))
	var ver := UIK.label(I18n.t("VERTICAL SLICE 001 · art converted from concept boards · %s") % ProjectSettings.get_setting("application/config/version", ""), 7, Art.C_DIM)
	ver.position = Vector2(8, 346)
	add_child(ver)
	# in a browser F12 opens the developer tools, so web testers report from the pause menu
	var hint := UIK.label("Test build: Esc → Report a problem." if OS.has_feature("web") else "Test build: press F12 any time to report a problem.", 7, Art.C_SKY)
	hint.position = Vector2(8, 334)
	add_child(hint)
	# language: English / 繁體中文 / 简体中文 (saved in user://settings.cfg)
	var lang := UIK.hbox(4)
	lang.position = Vector2(466, 330)
	add_child(lang)
	lang.add_child(UIK.icon("world", 12))
	for l in I18n.LOCALES:
		var code: String = l[0]
		var b := UIK.button(l[1], func(): I18n.set_locale(code); SceneRouter.go_menu(), "tab_active" if I18n.locale().begins_with(code) else "tab")
		b.name = "Lang_" + code
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		lang.add_child(b)


func _new_game() -> void:
	if SaveSystem.free_slot() >= 0:
		SaveSystem.next_slot = -1
		SceneRouter.go_creator()
	else:
		UIRoot.open_modal(SaveListModal.new("replace"))
