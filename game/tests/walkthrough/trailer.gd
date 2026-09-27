class_name Trailer
extends RefCounted
## ~30 s trailer / first-play tutorial, recorded with Movie Maker:
##   godot --path game --write-movie out/frame.png --fixed-fps 30 -- --bot=trailer --lang=zh_TW
## Plays real game screens (a saved end-of-June company from the walkthrough) and overlays
## numbered tutorial captions + key hints. tools/make_trailer.sh trims, adds music and encodes.

const FIXTURE := "res://tests/walkthrough/fixtures/trailer_state.json"
const SLOT := 9

var bot
var layer: CanvasLayer
var root: Control
var cap: Control
var black: ColorRect
var zh := false
var pack_loc := "riverside_studio"

# en, zh_TW
const TEXT := {
	"tagline": ["Start a company from nothing, in a city that lives.", "在一座活的城市，從零開始創業。"],
	"genre": ["Pixel-art business-life RPG", "像素風 · 經營 · 人生 RPG"],
	"arrive": ["Arrive in Aurelia with $30,000 and a lease.", "帶著 $30,000 和一紙租約，搬進奧瑞莉亞市。"],
	"s1": ["EXPLORE", "探索"], "s1m": ["Walk a city that runs on its own clock.", "自由走動，城市有自己的日夜節奏。"],
	"s2": ["INTERACT", "互動"], "s2m": ["Walk up to people and things, press E.", "走到人或物品旁邊，按 E 互動。"],
	"s3": ["STOCK UP", "進貨"], "s3m": ["Sit at a desk, open Company OS, buy wholesale.", "坐到辦公桌前打開 Company OS，向供應商進貨。"],
	"s4": ["SELL", "上架"], "s4m": ["List your products. Set the price. Orders come in.", "拍照上架、訂價格，訂單就會進來。"],
	"s5": ["SHIP", "出貨"], "s5m": ["Pack, ship, and get paid.", "打包、出貨，錢就進來了。"],
	"s6": ["GO OFFICIAL", "成立公司"], "s6m": ["Register your company at City Hall.", "到市政廳登記，成立你自己的公司。"],
	"s7": ["MONTH CLOSE", "月結"], "s7m": ["Profit isn't cash. Your books show you why.", "賺了錢，不代表有現金。帳本會告訴你為什麼。"],
	"s8": ["CAREERS", "職涯"], "s8m": ["Take a part-time job, freelance, or both.", "兼職打工、自由接案，或兩個都做。"],
	"end": ["Now in playtest", "測試版開放中"],
	"move": ["Move", "移動"], "run": ["Run", "跑步"], "use": ["Interact", "互動"], "phone": ["Phone", "手機"],
	"map": ["Map", "地圖"], "report": ["Report a bug", "回報問題"], "desk": ["at a desk", "在辦公桌"],
	"langs": ["English · 繁體中文 · 简体中文", "繁體中文 · 简体中文 · English"],
}


func _init(b) -> void:
	bot = b


func t(key: String) -> String:
	return TEXT[key][1 if zh else 0]


func run() -> void:
	zh = I18n.is_zh()
	_prepare_state()
	_build_overlay()
	UIRoot.set_hud_visible(false)
	await bot.frames(2)
	bot.log_line("TRAILER_START frame=%d" % Engine.get_frames_drawn())
	await _title()
	await _arrival()
	await _explore()
	await _interact()
	await _stock_and_sell()
	await _ship()
	await _register()
	await _careers()
	await _month_close()
	await _end_card()
	bot.log_line("TRAILER_END frame=%d" % Engine.get_frames_drawn())


# ------------------------------------------------------------------ state
func _prepare_state() -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)
	var src := FileAccess.get_file_as_string(FIXTURE)
	var f := FileAccess.open(SaveSystem._path(SLOT), FileAccess.WRITE)
	f.store_string(src)
	f.close()
	SaveSystem.load_data(SLOT)
	# early afternoon, so the street is busy and orders have come in since the morning
	while Clock.hour() < 14:
		Clock.advance(30)
	# make sure there are orders waiting at the packing table for the shipping shot
	while Ecommerce.orders_with(["placed"]).size() < 3 and Clock.hour() < 18:
		Clock.advance(20)
	var counts := {}
	for o in Ecommerce.orders_with(["placed"]):
		counts[o["location"]] = int(counts.get(o["location"], 0)) + 1
	for loc in counts:
		if int(counts[loc]) > int(counts.get(pack_loc, 0)):
			pack_loc = loc
	bot.log_line("trailer: %d placed orders, packing at %s" % [Ecommerce.orders_with(["placed"]).size(), pack_loc])
	EventEngine.S()["queue"].clear()   # no decision pop-ups mid-trailer
	UIRoot.dialogue_queue.clear()
	UIRoot._pending_reports.clear()
	UIRoot._suppress_decisions = true
	for c in UIRoot.toast_box.get_children():
		c.queue_free()
	UIRoot.toast_box.visible = false   # the captions carry the message; toasts only in the shipping shot


# ------------------------------------------------------------------ overlay
func _build_overlay() -> void:
	layer = CanvasLayer.new()
	layer.layer = 50
	bot.get_tree().root.add_child(layer)
	root = Control.new()
	root.position = Vector2.ZERO
	root.size = Vector2(640, 360)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIK.theme()
	layer.add_child(root)
	black = ColorRect.new()
	black.color = Color8(6, 10, 20)
	black.size = Vector2(640, 360)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(black)


func _cut_to(scene_setup: Callable) -> void:
	var tw := black.create_tween()
	black.visible = true
	tw.tween_property(black, "modulate:a", 1.0, 0.12)
	await tw.finished
	await scene_setup.call()
	UIRoot.set_hud_visible(false)
	await bot.frames(2)
	var tw2 := black.create_tween()
	tw2.tween_property(black, "modulate:a", 0.0, 0.16)


func _clear_caption() -> void:
	if cap != null and is_instance_valid(cap):
		cap.queue_free()
	cap = null


## Numbered tutorial caption. pos "bottom" = lower-third band; "top" = compact card over a screen's header.
func _caption(n: int, step_key: String, main_key: String, keys: Array = [], pos := "bottom") -> void:
	_clear_caption()
	cap = Control.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.size = Vector2(640, 360)
	root.add_child(cap)
	root.move_child(cap, 0)
	var band := Control.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.add_child(band)
	var h := 58.0
	var y := 360.0 - h if pos == "bottom" else 4.0
	if pos == "bottom":
		var g := Gradient.new()
		g.set_color(0, Color(0.03, 0.06, 0.13, 0.0))
		g.set_color(1, Color(0.03, 0.06, 0.13, 0.94))
		g.add_point(0.35, Color(0.03, 0.06, 0.13, 0.82))
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(0, 1)
		gt.width = 4
		gt.height = 32
		var bg := TextureRect.new()
		bg.texture = gt
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.position = Vector2(0, y - 26)
		bg.size = Vector2(640, h + 26)
		band.add_child(bg)
	else:
		var card := Panel.new()
		card.add_theme_stylebox_override("panel", UIK.flat(Color(0.03, 0.06, 0.13, 0.95), Art.C_GOLD, 1, 3))
		card.position = Vector2(118, y)
		card.size = Vector2(404, h - 6)
		band.add_child(card)
	var x0 := 28.0 if pos == "bottom" else 130.0
	var yy := y + (6.0 if pos == "bottom" else 5.0)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UIK.flat(Art.C_GOLD, Color(0, 0, 0, 0), 0, 2))
	chip.position = Vector2(x0, yy)
	var cl := UIK.label("%d  %s" % [n, t(step_key)], 7, Art.C_NAVY_900, true)
	cl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	chip.add_child(cl)
	band.add_child(chip)
	var main := UIK.title(t(main_key), 13 if zh else 12, Art.C_WHITE)
	main.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	main.position = Vector2(x0, yy + 15)
	band.add_child(main)
	# key hints on the right
	var kx := 612.0 if pos == "bottom" else 512.0
	for i in range(keys.size() - 1, -1, -1):
		var k: Array = keys[i]
		var box := UIK.hbox(3)
		var key := UIK.panel("ui/prompt_key", 2)
		var kl := UIK.label(" %s " % k[0], 8, Art.C_NAVY_800, true)
		kl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		key.add_child(kl)
		box.add_child(key)
		var dl := UIK.label(t(k[1]), 7, Art.C_SKY, true)
		dl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		box.add_child(dl)
		band.add_child(box)
		box.reset_size()
		await bot.frames(1)
		kx -= box.size.x
		box.position = Vector2(kx, yy + (1.0 if pos == "bottom" else 0.0))
		kx -= 10.0
	cap.modulate.a = 0.0
	cap.create_tween().tween_property(cap, "modulate:a", 1.0, 0.2)


# ------------------------------------------------------------------ shots
func _title() -> void:
	var c := Control.new()
	c.size = Vector2(640, 360)
	c.theme = UIK.theme()
	c.add_child(Backdrop.make("backdrops/menu", 16.0))
	var shade := ColorRect.new()
	shade.color = Color(0.03, 0.06, 0.13, 0.55)
	shade.size = Vector2(640, 360)
	c.add_child(shade)
	var ti := UIK.title("CITY VENTURE", 44, Color8(236, 242, 255))
	ti.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	ti.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ti.size = Vector2(640, 56)
	ti.position = Vector2(0, 120)
	c.add_child(ti)
	var rule := ColorRect.new()
	rule.color = Art.C_GOLD
	rule.size = Vector2(0, 1)
	rule.position = Vector2(320, 178)
	c.add_child(rule)
	var tg := UIK.title(t("tagline"), 16 if zh else 13, Art.C_WHITE)
	tg.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tg.size = Vector2(640, 20)
	tg.position = Vector2(0, 186)
	c.add_child(tg)
	var gn := UIK.label(t("genre"), 9, Art.C_GOLD, true)
	gn.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	gn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gn.size = Vector2(640, 12)
	gn.position = Vector2(0, 216)
	c.add_child(gn)
	SceneRouter._set_scene(c)
	for n in [ti, tg, gn]:
		n.modulate.a = 0.0
	var tw := c.create_tween()
	tw.tween_property(black, "modulate:a", 0.0, 0.35)
	tw.tween_property(ti, "modulate:a", 1.0, 0.45)
	tw.parallel().tween_property(rule, "size:x", 220.0, 0.5)
	tw.parallel().tween_property(rule, "position:x", 210.0, 0.5)
	tw.tween_property(tg, "modulate:a", 1.0, 0.35)
	tw.tween_property(gn, "modulate:a", 1.0, 0.3)
	await bot.wait(2.6)


func _arrival() -> void:
	await _cut_to(func():
		SceneRouter._set_scene(ArrivalScene.new())
		await bot.frames(1))
	var lab := UIK.title(t("arrive"), 13 if zh else 12, Art.C_WHITE)
	lab.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_clear_caption()
	cap = Control.new()
	cap.size = Vector2(640, 360)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cap)
	root.move_child(cap, 0)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lab.size = Vector2(640, 20)
	lab.position = Vector2(0, 318)
	cap.add_child(lab)
	cap.modulate.a = 0.0
	cap.create_tween().tween_property(cap, "modulate:a", 1.0, 0.3)
	await bot.wait(2.8)


func _explore() -> void:
	await _cut_to(func():
		SceneRouter._enter("district", "riverside", "door_bloom_coffee", "right")
		await bot.frames(1))
	await _caption(1, "s1", "s1m", [["W A S D", "move"], ["Shift", "run"]])
	Input.action_press("move_right")
	await bot.wait(1.0)
	Input.action_press("run")
	await bot.wait(2.0)
	Input.action_release("run")
	Input.action_release("move_right")


func _interact() -> void:
	await _cut_to(func():
		_clear_caption()
		SceneRouter._enter("interior", "bloom_coffee", "door", "up", Vector2(150, 150))
		await bot.frames(1))
	await _caption(2, "s2", "s2m", [["E", "use"], ["Tab", "phone"]], "top")
	# Jun stands behind the counter: walk up to its front edge, face him and talk
	await bot.walk_to(Vector2(108, 112), 6.0, 4.0, false)
	var ws := SceneRouter.world_scene()
	if ws != null and ws.player != null:
		ws.player.face("up")
	await bot.wait(0.3)
	Actions.run("talk", {"npc": "jun"})
	await bot.wait(2.2)
	var dlg = UIRoot.dialogue
	dlg.active = false
	dlg.visible = false


func _stock_and_sell() -> void:
	await _cut_to(func():
		_clear_caption()
		SceneRouter._enter("interior", "small_office", "door", "up")
		await bot.frames(2)
		UIRoot.set_hud_visible(false)
		UIRoot.open_modal(CompanyOS.new("office"))
		await bot.frames(2)
		await bot.click_named("Tab_operations", 1.0))
	await _caption(3, "s3", "s3m", [["E", "desk"]], "top")
	await bot.wait(1.0)
	await bot.click_named("Buy_tradelink_wholesale_water_bottle", 1.0)
	await bot.wait(1.1)
	await bot.click_named("Tab_sales", 1.0)
	await _caption(4, "s4", "s4m", [], "top")
	await bot.wait(2.2)


func _ship() -> void:
	await _cut_to(func():
		UIRoot.close_all()
		_clear_caption()
		SceneRouter._enter("interior", "small_office" if pack_loc == "suite_2b" else "riverside_apartment", "door", "up")
		await bot.frames(2)
		UIRoot.set_hud_visible(false)
		UIRoot.open_modal(PackShipModal.new(pack_loc))
		await bot.frames(2))
	await _caption(5, "s5", "s5m", [], "top")
	for c in UIRoot.toast_box.get_children():
		c.queue_free()
	UIRoot.toast_box.visible = true
	await bot.wait(0.7)
	await bot.click_named("Pack", 1.0)
	await bot.wait(0.6)
	await bot.click_named("CourierExpress", 1.0)
	await bot.wait(1.2)


func _register() -> void:
	await _cut_to(func():
		UIRoot.close_all()
		UIRoot.toast_box.visible = false
		_clear_caption()
		SceneRouter._enter("interior", "city_hall", "door", "up")
		await bot.frames(2)
		UIRoot.set_hud_visible(false)
		var rm := RegistrationModal.new()
		rm.done = true   # show the certificate view of the company registered in the fixture
		UIRoot.open_modal(rm)
		await bot.frames(2))
	await _caption(6, "s6", "s6m", [], "top")
	await bot.wait(2.4)


func _careers() -> void:
	await _cut_to(func():
		UIRoot.close_all()
		_clear_caption()
		SceneRouter._enter("interior", "nexus_cowork", "door", "up")
		await bot.frames(2)
		UIRoot.set_hud_visible(false)
		var bb := BusinessBoard.new()
		bb.page = "jobs"
		UIRoot.open_modal(bb)
		await bot.frames(2))
	await _caption(7, "s8", "s8m", [], "top")
	await bot.wait(2.4)


func _month_close() -> void:
	var reps: Array = GameState.data["reports"]["month_closes"]
	await _cut_to(func():
		UIRoot.close_all()
		_clear_caption()
		SceneRouter._enter("interior", "small_office", "door", "up")
		await bot.frames(2)
		UIRoot.set_hud_visible(false)
		if not reps.is_empty():
			UIRoot.open_modal(MonthCloseModal.new(reps[-1]))
		await bot.frames(2))
	await _caption(8, "s7", "s7m", [], "top")
	await bot.wait(2.8)


func _end_card() -> void:
	await _cut_to(func():
		UIRoot.close_all()
		_clear_caption()
		var c := Control.new()
		c.size = Vector2(640, 360)
		c.theme = UIK.theme()
		c.add_child(Backdrop.make("backdrops/arrival", 1.0e9))
		var shade := ColorRect.new()
		shade.color = Color(0.03, 0.06, 0.13, 0.62)
		shade.size = Vector2(640, 360)
		c.add_child(shade)
		var ic := TextureRect.new()
		ic.texture = Art.tex("ui/app_icon")
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.size = Vector2(56, 56)
		ic.position = Vector2(292, 58)
		c.add_child(ic)
		var ti := UIK.title("CITY VENTURE", 34, Color8(236, 242, 255))
		ti.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		ti.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ti.size = Vector2(640, 44)
		ti.position = Vector2(0, 122)
		c.add_child(ti)
		var st := UIK.title("%s  ·  v%s" % [t("end"), str(ProjectSettings.get_setting("application/config/version", ""))], 12, Art.C_GOLD)
		st.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		st.size = Vector2(640, 18)
		st.position = Vector2(0, 170)
		c.add_child(st)
		var row := UIK.hbox(12)
		for k in [["WASD", "move"], ["E", "use"], ["Tab", "phone"], ["M", "map"], ["F12", "report"]]:
			var box := UIK.hbox(3)
			var key := UIK.panel("ui/prompt_key", 2)
			var kl := UIK.label(" %s " % k[0], 8, Art.C_NAVY_800, true)
			kl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			key.add_child(kl)
			box.add_child(key)
			var dl := UIK.label(t(k[1]), 8, Art.C_WHITE, true)
			dl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
			box.add_child(dl)
			row.add_child(box)
		c.add_child(row)
		var lg := UIK.label(t("langs"), 8, Art.C_SKY, true)
		lg.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		lg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lg.size = Vector2(640, 12)
		lg.position = Vector2(0, 262)
		c.add_child(lg)
		SceneRouter._set_scene(c)
		UIRoot.set_hud_visible(false)
		await bot.frames(1)
		row.reset_size()
		await bot.frames(1)
		row.position = Vector2((640 - row.size.x) / 2.0, 214))
	await bot.wait(3.0)
	var tw := black.create_tween()
	tw.tween_property(black, "modulate:a", 1.0, 0.4)
	await tw.finished
