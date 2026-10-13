class_name AdReel
extends RefCounted
## Three ~60 s promotional cuts made from real game screens, recorded with Movie Maker:
##   godot --path game --rendering-driver opengl3 --resolution 1280x720 --write-movie out/f.png --fixed-fps 30 \
##     -- --bot=ad --ad=tycoon|city|choices --lang=zh_TW
## The bot logs AD_START frame=N / AD_END frame=M; tools/media/make_ads.sh trims, scores and encodes.
##   tycoon  — from $30,000 and a part-time shift to a tower with your name on it (progression fantasy)
##   city    — a city that lives day and night: districts, people, jobs that play like games (exploration)
##   choices — the big contract, payroll, the bank or an investor, a pitch, a rescue (decisions)

const FIXTURE := "res://tests/walkthrough/fixtures/trailer_state.json"
const SLOT := 9
const W := 640.0
const H := 360.0

var bot
var which := "tycoon"
var zh := false
var layer: CanvasLayer
var root: Control
var cap: Control
var black: ColorRect

# en, zh_TW
const TEXT := {
	# shared
	"genre": ["Pixel-art business-life RPG", "像素風 · 創業人生 RPG"],
	"cta": ["Now in beta", "搶先體驗測試中"],
	"langs": ["English · 繁體中文 · 简体中文", "繁體中文 · 简体中文 · English"],
	# tycoon
	"t_hook": ["$30,000.", "口袋只有 $30,000。"],
	"t_hook2": ["How far can you go?", "你能在這座城市走多遠？"],
	"t_arrive": ["New city. New life.", "新城市，新人生。"],
	"t_job": ["Pull espresso for your first paycheck", "先去咖啡店打工，賺第一桶金"],
	"t_stock": ["Buy wholesale. List it. Sell it.", "進貨、上架、開賣"],
	"t_pack": ["Orders pour in — pack them yourself", "訂單湧進來！親手打包出貨"],
	"t_company": ["Make it official", "登記成立你的公司"],
	"t_team": ["Hire a team", "招兵買馬，組一支團隊"],
	"t_factory": ["Open a factory", "開一間工廠"],
	"t_hotel": ["Run a boutique hotel", "經營精品旅館"],
	"t_street": ["Rent a studio by the river", "在河畔租下第一間小套房"],
	"t_line": ["Your own production line", "擁有自己的生產線"],
	"t_lobby": ["Guests check in. Reviews roll in.", "客人入住，好評湧進來"],
	"t_build": ["Then build a tower", "最後——蓋一棟大樓"],
	"t_done": ["With your name on it", "上面寫著你的名字"],
	"t_end": ["From one coffee to a skyline", "從一杯咖啡，到一整片天際線"],
	# city
	"c_hook": ["This city never sleeps", "這座城市，24 小時都醒著"],
	"c_walk": ["Walk anywhere. Run everywhere.", "想去哪就去哪"],
	"c_districts": ["Eleven districts to explore", "11 個街區等你探索"],
	"c_people": ["Everyone has a story", "每個人都有自己的故事"],
	"c_jobs": ["Jobs that play like mini-games", "打工？其實是小遊戲"],
	"c_barista": ["Barista", "咖啡師"], "c_parcel": ["Parcel sorter", "包裹分揀"],
	"c_teller": ["Bank teller", "銀行櫃員"], "c_photo": ["Product shoot", "商品攝影"],
	"c_style": ["Dress the part", "換上你的風格"],
	"c_night": ["And when the lights come on…", "等到夜晚燈亮起……"],
	"c_map": ["Your city. Your rules.", "你的城市，你說了算"],
	"c_end": ["A city that lives — with you in it", "一座活著的城市，等你搬進來"],
	# choices
	"x_hook": ["Profit up. Cash gone?", "明明賺了錢，現金卻見底？"],
	"x_hook2": ["Every choice counts.", "每一個決定都算數。"],
	"x_contract": ["800 lamps. Net 60. Take it?", "800 盞燈的大單，接不接？"],
	"x_hire": ["Who do you hire?", "要請誰來幫你？"],
	"x_team": ["Your team goes to work", "你的團隊開工了"],
	"x_bank": ["Borrow from the bank…", "向銀行借錢……"],
	"x_investor": ["…or give up a slice to an investor?", "……還是讓出股份給投資人？"],
	"x_pitch": ["Win the client with the right idea", "用對的創意，贏下客戶"],
	"x_reno": ["Flip a flat. Pick the style.", "買下老公寓，決定翻新風格"],
	"x_fail": ["Went bankrupt? Not game over.", "破產了？還不是 Game Over"],
	"x_ship": ["Can your warehouse keep up?", "訂單爆量，倉庫跟得上嗎？"],
	"x_money": ["Where does the money come from?", "資金從哪裡來？"],
	"x_close": ["Close the month in the black", "撐過去，月結轉虧為盈"],
	"x_end": ["No right answer. Only your story.", "沒有標準答案，只有你的故事"],
}


func _init(b) -> void:
	bot = b
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ad="):
			which = a.substr(5)


func t(key: String) -> String:
	return TEXT[key][1 if zh else 0]


func run() -> void:
	zh = I18n.is_zh()
	MiniGames.auto = -1.0   # the mini-games are played by hand on camera
	_build_overlay()
	UIRoot.set_hud_visible(false)
	await bot.frames(2)
	bot.log_line("AD_START frame=%d ad=%s" % [Engine.get_frames_drawn(), which])
	match which:
		"city":
			await _city()
		"choices":
			await _choices()
		_:
			await _tycoon()
	await _end_card(which)
	bot.log_line("AD_END frame=%d" % Engine.get_frames_drawn())


# ------------------------------------------------------------------ state helpers
func _quiet() -> void:
	UIRoot._suppress_decisions = true
	if GameState.has_game():
		EventEngine.S()["queue"].clear()
	UIRoot.dialogue_queue.clear()
	UIRoot._pending_reports.clear()
	for c in UIRoot.toast_box.get_children():
		c.queue_free()
	UIRoot.toast_box.visible = false
	Help.auto = false
	for c in UIRoot.card_layer.get_children():   # chapter cards and celebrations would cover the shot
		c.queue_free()


func _fresh(name: String, seed: int) -> void:
	GameState.new_game({"name": name, "seed": seed})
	GameState.data["tutorial"] = {"off": true, "seen": {}, "step": 99, "v": 99}
	_quiet()


func _load_fixture() -> void:
	DirAccess.make_dir_recursive_absolute(SaveSystem.DIR)
	var f := FileAccess.open(SaveSystem._path(SLOT), FileAccess.WRITE)
	f.store_string(FileAccess.get_file_as_string(FIXTURE))
	f.close()
	SaveSystem.load_data(SLOT)
	_quiet()


func _equity(amount: int, memo: String) -> void:
	Ledger.post(GameState.company_id(), memo, [{"acct": "cash", "dr": amount}, {"acct": "equity", "cr": amount}])


func _close_modals() -> void:
	UIRoot.close_all()
	for o in UIRoot.modal_layer.get_children():
		if o is Modal:
			o.close()


## Opens a modal and drops anything (help card, intro) that stacked on top of it.
func _modal(m: Control) -> void:
	UIRoot.open_modal(m)
	await bot.frames(2)
	if UIRoot.top_modal() != null and UIRoot.top_modal() != m:
		UIRoot.top_modal().close()
	await bot.frames(1)


func _hold_world() -> void:
	Clock.world_active = false


## Push in on the game UI (UIRoot is a CanvasLayer) so a screen reads on a phone, with a slow drift.
var _ztw: Tween
func _zoom(focus: Vector2, z: float, drift := 0.05, dur := 3.0) -> void:
	if _ztw != null and _ztw.is_valid():
		_ztw.kill()
	var at := func(zz: float) -> void:
		var off := Vector2(W / 2.0, H / 2.0) - focus * zz
		off.x = clampf(off.x, W - W * zz, 0.0)
		off.y = clampf(off.y, H - H * zz, 0.0)
		UIRoot.scale = Vector2(zz, zz)
		UIRoot.offset = off
	at.call(z)
	_ztw = black.create_tween()
	_ztw.tween_method(at, z, z + drift, dur)


## Push in on the top modal's panel, wherever it sits.
func _zoom_modal(z: float, dy := 0.0) -> void:
	var m = UIRoot.top_modal()
	var focus := Vector2(W / 2.0, H / 2.0)
	if m is Modal and is_instance_valid(m.panel):
		var r: Rect2 = m.panel.get_global_rect()
		focus = r.get_center()
		z = clampf(minf(z, (W - 12.0) / maxf(r.size.x, 1.0)), 1.0, z)   # never crop the panel's sides
	_zoom(focus + Vector2(0, dy), z, 0.03 if z > 1.05 else 0.0)


func _unzoom() -> void:
	if _ztw != null and _ztw.is_valid():
		_ztw.kill()
	UIRoot.scale = Vector2.ONE
	UIRoot.offset = Vector2.ZERO


## Press a named button without a pointer (works while the UI is zoomed).
func _press(name: String, timeout_s := 1.0) -> bool:
	var ok: bool = await bot.until(func(): return bot.button_named(name) != null, timeout_s)
	if not ok:
		bot.log_line("  (ad) no button " + name)
		return false
	var b: Button = bot.button_named(name)
	if b.disabled:
		return false
	b.pressed.emit()
	await bot.frames(2)
	return true


# ------------------------------------------------------------------ overlay
func _build_overlay() -> void:
	layer = CanvasLayer.new()
	layer.layer = 50
	bot.get_tree().root.add_child(layer)
	root = Control.new()
	root.size = Vector2(W, H)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIK.theme()
	layer.add_child(root)
	black = ColorRect.new()
	black.color = Color8(6, 10, 20)
	black.size = Vector2(W, H)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(black)


func _cut_to(setup: Callable, flash := false) -> void:
	_clear_caption()
	black.visible = true
	black.color = Color8(236, 242, 255) if flash else Color8(6, 10, 20)
	var tw := black.create_tween()
	tw.tween_property(black, "modulate:a", 1.0, 0.08 if flash else 0.1)
	await tw.finished
	_unzoom()
	await setup.call()
	UIRoot.set_hud_visible(false)
	for c in UIRoot.toast_box.get_children():
		c.queue_free()
	await bot.frames(2)
	var tw2 := black.create_tween()
	tw2.tween_property(black, "modulate:a", 0.0, 0.22 if flash else 0.14)


func _clear_caption() -> void:
	if cap != null and is_instance_valid(cap):
		cap.queue_free()
	cap = null


func _lbl(text: String, size: int, color: Color, title := true) -> Label:
	var l: Label = UIK.title(text, size, color) if title else UIK.label(text, size, color, true)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.09, 1.0))
	l.add_theme_constant_override("outline_size", 4)
	return l


## Ad caption: a big line with a gold rule, popping in over a soft band. pos "bottom" | "top" | "center".
func _say(key: String, pos := "bottom", sub_key := "") -> void:
	_clear_caption()
	cap = Control.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.size = Vector2(W, H)
	root.add_child(cap)
	root.move_child(cap, 0)
	var big := 22 if zh else 18
	var band_h := 64.0 if sub_key == "" else 82.0
	var y := H - band_h if pos == "bottom" else (0.0 if pos == "top" else (H - band_h) / 2.0)
	var g := Gradient.new()
	var c0 := Color(0.02, 0.04, 0.10, 0.0)
	var c1 := Color(0.02, 0.04, 0.10, 0.88)
	if pos == "center":
		g.set_color(0, c0)
		g.set_color(1, c0)
		g.add_point(0.5, c1)
	else:
		g.set_color(0, c0 if pos == "bottom" else c1)
		g.set_color(1, c1 if pos == "bottom" else c0)
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
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.position = Vector2(0, y - (20.0 if pos == "bottom" else 0.0))
	bg.size = Vector2(W, band_h + 20.0)
	cap.add_child(bg)
	var line := _lbl(t(key), big, Art.C_WHITE)
	line.size = Vector2(W, big + 10)
	var ly := y + (14.0 if pos != "top" else 10.0)
	line.position = Vector2(0, ly)
	line.pivot_offset = Vector2(W / 2.0, (big + 10) / 2.0)
	cap.add_child(line)
	var rule := ColorRect.new()
	rule.color = Art.C_GOLD
	rule.size = Vector2(0, 2)
	rule.position = Vector2(W / 2.0, ly + big + 12)
	cap.add_child(rule)
	if sub_key != "":
		var sub := _lbl(t(sub_key), 13 if zh else 11, Art.C_GOLD)
		sub.size = Vector2(W, 18)
		sub.position = Vector2(0, ly + big + 18)
		cap.add_child(sub)
	line.scale = Vector2(1.18, 1.18)
	cap.modulate.a = 0.0
	var tw := cap.create_tween()
	tw.tween_property(cap, "modulate:a", 1.0, 0.16)
	tw.parallel().tween_property(line, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(rule, "size:x", 120.0, 0.3)
	tw.parallel().tween_property(rule, "position:x", W / 2.0 - 60.0, 0.3)


## A small corner tag (used for the mini-game montage).
func _tag(key: String) -> void:
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UIK.flat(Art.C_GOLD, Color(0, 0, 0, 0), 0, 2))
	var l := UIK.label("  %s  " % t(key), 10, Art.C_NAVY_900, true)
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	chip.add_child(l)
	chip.position = Vector2(20, 18)
	if cap == null or not is_instance_valid(cap):
		cap = Control.new()
		cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cap.size = Vector2(W, H)
		root.add_child(cap)
		root.move_child(cap, 0)
	cap.add_child(chip)


## Full-screen statement over black (hooks).
func _card(key: String, sub_key := "", hold := 1.6) -> void:
	_clear_caption()
	black.color = Color8(6, 10, 20)
	black.visible = true
	black.modulate.a = 1.0
	cap = Control.new()
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.size = Vector2(W, H)
	root.add_child(cap)   # above the black
	var big := 30 if zh else 26
	var l := _lbl(t(key), big, Art.C_WHITE)
	l.size = Vector2(W, big + 12)
	l.position = Vector2(0, 150 - (14 if sub_key != "" else 0))
	l.pivot_offset = Vector2(W / 2.0, (big + 12) / 2.0)
	cap.add_child(l)
	var s: Label = null
	if sub_key != "":
		s = _lbl(t(sub_key), 16 if zh else 14, Art.C_GOLD)
		s.size = Vector2(W, 22)
		s.position = Vector2(0, 150 + big)
		s.modulate.a = 0.0
		cap.add_child(s)
	l.scale = Vector2(1.3, 1.3)
	l.modulate.a = 0.0
	var tw := cap.create_tween()
	tw.tween_property(l, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(l, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if s != null:
		tw.tween_interval(0.45)
		tw.tween_property(s, "modulate:a", 1.0, 0.25)
	await bot.wait(hold)
	cap.queue_free()
	cap = null


## Animated money counter, top-right (the tycoon cut).
var _money: Label
func _money_show(from: float, to: float, dur: float) -> void:
	if _money == null or not is_instance_valid(_money):
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UIK.flat(Color(0.02, 0.04, 0.10, 0.85), Art.C_GOLD, 1, 3))
		p.position = Vector2(470, 14)
		p.custom_minimum_size = Vector2(156, 26)
		_money = _lbl("", 15, Art.C_GOLD)
		p.add_child(_money)
		root.add_child(p)
		root.move_child(p, 0)
	var tw := _money.create_tween()
	tw.tween_method(func(v: float): _money.text = "$" + _fmt(int(v)), from, to, dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)


func _money_hide() -> void:
	if _money != null and is_instance_valid(_money):
		_money.get_parent().queue_free()
	_money = null


func _fmt(n: int) -> String:
	var s := str(abs(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if n < 0 else "") + s + out


# ------------------------------------------------------------------ world helpers
func _walk(dir: String, secs: float, run := true) -> void:
	Input.action_press("move_" + dir)
	if run:
		Input.action_press("run")
	await bot.wait(secs)
	Input.action_release("run")
	Input.action_release("move_" + dir)


func _street(district: String, x: float, hour: int) -> void:
	Clock.advance_to(Clock.next_time_of_day(hour * 60))
	_quiet()
	GameState.mark_visited(district)
	SceneRouter._enter("district", district, "metro", "right", Vector2(x, 352))
	await bot.frames(2)
	_quiet()


func _inside(building: String, pos := Vector2(-1, -1)) -> void:
	GameState.mark_visited(building)
	SceneRouter._enter("interior", building, "door", "up", pos)
	await bot.frames(2)
	_quiet()


func _mg_open(g: MiniGame) -> MiniGame:
	g.mark_tutorial_seen()   # the first-time practice is covered by its own tour
	MiniGames.play(g, func(_r): pass)
	await bot.frames(2)
	if UIRoot.top_modal() != g and UIRoot.top_modal() is MiniGame:
		UIRoot.top_modal().close()
		await bot.frames(1)
	if g.phase != "play":
		g.start()
	await bot.frames(2)
	return g


func _mg_close(g: MiniGame) -> void:
	if is_instance_valid(g):
		g.close()
	_close_modals()


# ================================================================== AD 1: tycoon
func _tycoon() -> void:
	_fresh("Ad Tycoon", 7101)
	await _card("t_hook", "t_hook2", 2.4)
	# arrival
	await _cut_to(func():
		SceneRouter._set_scene(ArrivalScene.new())
		await bot.frames(1))
	_say("t_arrive", "bottom")
	_money_show(0, 30000, 1.2)
	await bot.wait(2.6)
	await _cut_to(func():
		await _street("riverside", 200, 8))
	_say("t_street", "bottom")
	await _walk("right", 2.8)
	# part-time barista shift, played on camera
	await _cut_to(func():
		await _inside("bloom_coffee")
		await bot.wait(0.1))
	var b: BaristaGame = await _mg_open(BaristaGame.new())
	_zoom_modal(1.3)
	_say("t_job", "bottom")
	await bot.wait(0.3)
	await _press("ConfirmOrder")
	for f in [["Size", b.want["size"]], ["Drink", b.want["drink"]], ["Milk", b.want["milk"]], ["Shots", b.want["shots"]]]:
		await _press("%s_%s" % [f[0], f[1]])
		await bot.wait(0.22)
	await _press("Serve")
	await bot.wait(0.25)
	await _press("Deliver_%d" % int(b.want["destination"]))
	_money_show(30000, 30180, 0.6)
	await bot.wait(0.8)
	_mg_close(b)
	# the e-commerce business from the fixture company
	_load_fixture()
	while Clock.hour() < 14:
		Clock.advance(30)
	while Ecommerce.orders_with(["placed"]).size() < 3 and Clock.hour() < 18:
		Clock.advance(20)
	_quiet()
	var pack_loc := "riverside_studio"
	var counts := {}
	for o in Ecommerce.orders_with(["placed"]):
		counts[o["location"]] = int(counts.get(o["location"], 0)) + 1
	for loc in counts:
		if int(counts[loc]) > int(counts.get(pack_loc, 0)):
			pack_loc = loc
	await _cut_to(func():
		await _inside("small_office")
		await _modal(CompanyOS.new("office"))
		await bot.click_named("Tab_operations", 1.0))
	_say("t_stock", "bottom")
	await bot.wait(0.8)
	await bot.click_named("Buy_tradelink_wholesale_water_bottle", 1.0)
	await bot.wait(0.8)
	await bot.click_named("Tab_sales", 1.0)
	_money_show(30180, 41250, 1.4)
	await bot.wait(1.6)
	# pack by hand: the packing-table mini-game
	await _cut_to(func():
		_close_modals()
		await _inside("riverside_apartment")
		await bot.wait(0.05))
	var orders := []
	for i in 3:
		orders.append({"id": "O10%d" % i, "product": ["wireless_earbuds", "desk_lamp", "water_bottle"][i], "qty": 1, "customer": "Rin Tanaka"})
	var pk: PackGame = await _mg_open(PackGame.new(orders))
	_zoom_modal(1.3)
	_say("t_pack", "bottom")
	await bot.wait(0.2)
	await _press("Box_" + pk.need_box())
	await bot.wait(0.15)
	for place in Packing.plan(pk._order(), pk.box):
		await _press("PackItem_%d" % int(place["item"]))
		if place["rotated"]:
			await _press("RotateItem")
		await _press("Grid_%d_%d" % [int(place["x"]), int(place["y"])])
		await bot.wait(0.2)
	for i in 3:
		await _press("Pad")
		await bot.wait(0.08)
	for i in 3:
		await _press("Seam_%d" % i)
		await bot.wait(0.08)
	_money_show(41250, 58900, 1.2)
	await bot.wait(0.8)
	_mg_close(pk)
	# registered company
	await _cut_to(func():
		_close_modals()
		await _inside("city_hall")
		var rm := RegistrationModal.new()
		rm.done = true
		await _modal(rm), true)
	_say("t_company", "top")
	await bot.wait(2.4)
	# staff at work
	Staff.register_employer()
	for role in ["packer", "developer", "marketer"]:
		Staff.post_job(role)
		Clock.advance(19 * 60)
		Staff.hire(Staff.S()["applicants"][0]["id"])
	while not (Clock.weekday() >= 1 and Clock.weekday() <= 5 and Clock.hour() == 11):
		Clock.advance(60)
	_quiet()
	await _cut_to(func():
		_close_modals()
		await _inside("small_office")
		await bot.wait(0.2))
	_say("t_team", "bottom")
	_money_show(58900, 126400, 1.6)
	await bot.wait(2.6)
	# factory
	_fresh("Ad Factory", 7102)
	Company.register("Riverlight Works", "manufacturing", "Unit 12")
	Company.open_business_account(25000)
	Clock.advance_to(Clock.at_day_time(1, 9 * 60))
	_quiet()
	await _cut_to(func():
		await _street("industrial", 360, 9))
	_say("t_factory", "bottom")
	_money_show(126400, 482000, 1.4)
	await _walk("right", 2.4)
	Living.lease("unit12_factory")
	Manufacturing.start()
	_quiet()
	await _cut_to(func():
		await _inside("unit12_factory")
		_hold_world())
	_say("t_line", "bottom")
	await bot.wait(1.6)
	await _cut_to(func():
		await _modal(ManufacturingUI.new())
		_zoom_modal(1.3))
	await bot.wait(1.8)
	_close_modals()
	# hotel at night
	_fresh("Ad Hotel", 7103)
	Company.register("Aster Hospitality", "hotel", "The Aster")
	Company.open_business_account(25000)
	_equity(400000, "Ad hotel equity")
	GameState.mark_visited("the_aster")
	Hotel.start("own")
	_quiet()
	await _cut_to(func():
		await _street("luxury_heights", 220, 21))
	_say("t_hotel", "bottom")
	_money_show(482000, 1250000, 1.4)
	await _walk("right", 2.4, false)
	Clock.advance_to(Clock.next_time_of_day(10 * 60))
	_quiet()
	await _cut_to(func():
		await _inside("the_aster")
		_hold_world())
	_say("t_lobby", "bottom")
	await bot.wait(1.6)
	await _cut_to(func():
		var hu := HotelUI.new()
		hu.page = "board"
		await _modal(hu)
		_zoom_modal(1.3))
	await bot.wait(1.8)
	_close_modals()
	# real estate: the construction site, then the tower
	_fresh("Ad Tower", 7104)
	Company.register("Harlow Development", "real_estate", "Harlow")
	Company.open_business_account(25000)
	_equity(2500000, "Ad development equity")
	Compliance.apply_permit("brokerage")
	Clock.advance(3 * Clock.DAY)
	Living.lease("realty_office")
	RealEstate.start()
	RealEstate.buy("maple_1", .2, 25)
	Compliance.apply_permit("building")
	Clock.advance(7 * Clock.DAY)
	RealEstate.develop("small", "Venture Tower" if not zh else "創業大樓")
	Clock.advance_to(Clock.next_time_of_day(10 * 60))
	_quiet()
	await _cut_to(func():
		GameState.mark_visited("residential")
		SceneRouter._enter("district", "residential", "metro", "", Vector2(1340, 352))
		await bot.frames(2)
		_hold_world())
	_say("t_build", "bottom")
	await bot.wait(2.6)
	Clock.advance_to(int(RealEstate.S()["project"]["due"]) + Clock.DAY)
	Clock.advance_to(Clock.next_time_of_day(19 * 60))
	_quiet()
	await _cut_to(func():
		_close_modals()
		GameState.mark_visited("residential")
		SceneRouter._enter("district", "residential", "metro", "", Vector2(1340, 352))
		await bot.frames(2)
		_quiet()
		_hold_world(), true)
	_say("t_done", "bottom")
	_money_show(1250000, 3600000, 1.6)
	await bot.wait(3.6)
	_money_hide()


# ================================================================== AD 2: city
func _city() -> void:
	_fresh("Ad City", 7201)
	Clock.advance_to(Clock.at_day_time(1, 16 * 60))
	_quiet()
	# hook: a day turning into night on the riverside, in seconds
	await _cut_to(func():
		await _street("riverside", 420, 17))
	_say("c_hook", "center")
	for i in 90:
		Clock.advance(3)
		await bot.frames(1)
	await bot.wait(0.6)
	Clock.advance_to(Clock.at_day_time(1, 9 * 60))
	_quiet()
	await _cut_to(func():
		await _street("riverside", 200, 9))
	_say("c_walk", "bottom")
	await _walk("right", 3.0)
	# district montage
	_clear_caption()
	var stops := [["shopping_street", 10], ["old_town", 12], ["harbor", 15], ["airport", 13], ["university", 11], ["civic_center", 16], ["financial", 18]]
	var first := true
	for s in stops:
		await _cut_to(func():
			await _street(s[0], 300, s[1]))
		if first:
			_say("c_districts", "bottom")
			first = false
		await _walk("right", 1.6)
	# people
	await _cut_to(func():
		await _inside("bloom_coffee", Vector2(150, 150)))
	_say("c_people", "top")
	await bot.walk_to(Vector2(108, 112), 6.0, 3.0, false)
	var ws := SceneRouter.world_scene()
	if ws != null and ws.player != null:
		ws.player.face("up")
	Actions.run("talk", {"npc": "jun"})
	await bot.wait(2.2)
	UIRoot.dialogue.active = false
	UIRoot.dialogue.visible = false
	# mini-game montage: four jobs, two seconds each, pushed in so they read on a phone
	await _cut_to(func():
		_clear_caption()
		await bot.frames(1))
	await _card("c_jobs", "", 1.3)
	var b: BaristaGame = await _mg_open(BaristaGame.new())
	_zoom_modal(1.35)
	black.modulate.a = 0.0
	_tag("c_barista")
	await _press("ConfirmOrder")
	for f in [["Size", b.want["size"]], ["Drink", b.want["drink"]], ["Milk", b.want["milk"]], ["Shots", b.want["shots"]]]:
		await _press("%s_%s" % [f[0], f[1]])
		await bot.wait(0.2)
	await _press("Serve")
	await bot.wait(0.35)
	_mg_close(b)
	_clear_caption()
	var ps: ParcelSortGame = await _mg_open(ParcelSortGame.new())
	_zoom_modal(1.35)
	_tag("c_parcel")
	for i in 3:
		await bot.wait(0.35)
		if bot.button_named("Damage_quarantine") != null:
			await _press("Damage_quarantine")
			await bot.wait(0.2)
		if is_instance_valid(ps) and ps.phase == "play":
			await _press("Bin_" + str(ps.parcel["bin"]))
	await bot.wait(0.3)
	_mg_close(ps)
	_clear_caption()
	var tc: TellerCashGame = await _mg_open(TellerCashGame.new())
	_zoom_modal(1.35)
	_tag("c_teller")
	var left := tc.amount
	for d in TellerCashGame.NOTES:
		while left >= d:
			await _press("Note_%d" % d)
			await bot.wait(0.12)
			left -= d
	await bot.wait(0.35)
	_mg_close(tc)
	_clear_caption()
	var ph: PhotoShootGame = await _mg_open(PhotoShootGame.new("desk_lamp"))
	_zoom_modal(1.35)
	_tag("c_photo")
	await bot.wait(0.3)
	await _press("Backdrop_wood")
	await bot.wait(0.4)
	await _press("ZoomIn")
	await bot.wait(0.3)
	await _press("ZoomIn")
	await bot.wait(0.6)
	_mg_close(ph)
	_unzoom()
	# style
	await _cut_to(func():
		_clear_caption()
		await _inside("threadline_apparel")
		await _modal(ClothingShopModal.new()))
	_say("c_style", "top")
	await bot.wait(2.4)
	# night
	await _cut_to(func():
		_close_modals()
		await _street("luxury_heights", 1000, 21))
	_say("c_night", "bottom")
	await _walk("left", 2.6, false)
	await _cut_to(func():
		await _street("university", 640, 22))
	await bot.wait(2.0)
	await _cut_to(func():
		await _street("harbor", 500, 22))
	await _walk("right", 2.0, false)
	# city map
	await _cut_to(func():
		var map := CityMapModal.new(false)
		map.sel = "riverside"
		await _modal(map))
	_say("c_map", "bottom")
	await bot.wait(2.6)
	_close_modals()


# ================================================================== AD 3: choices
func _choices() -> void:
	_load_fixture()
	while Clock.hour() != 10:
		Clock.advance(60)
	_quiet()
	await _card("x_hook", "x_hook2", 2.6)
	# the big contract: Crestline's flagship, then the offer
	await _cut_to(func():
		await _street("financial", 300, 17))
	_say("x_money", "bottom")
	await _walk("right", 2.6)
	await _cut_to(func():
		await _inside("small_office")
		var inst := EventEngine.trigger("crestline_big_offer", {})
		await _modal(DecisionModal.new(inst))
		_zoom_modal(1.45))
	_say("x_contract", "bottom")
	await bot.wait(3.2)
	await _cut_to(func():
		_close_modals()
		await _street("harbor", 700, 11))
	_say("x_ship", "bottom")
	await _walk("right", 2.8)
	# hiring
	Staff.register_employer()
	for role in ["packer", "developer", "marketer"]:
		Staff.post_job(role)
		Clock.advance(19 * 60)
	_quiet()
	await _cut_to(func():
		_close_modals()
		await _modal(CompanyOS.new("office"))
		await _press("Tab_people")
		_zoom_modal(1.5))
	_say("x_hire", "bottom")
	await bot.wait(2.4)
	for i in 3:
		if not Staff.S()["applicants"].is_empty():
			Staff.hire(Staff.S()["applicants"][0]["id"])
	while not (Clock.weekday() >= 1 and Clock.weekday() <= 5 and Clock.hour() == 11):
		Clock.advance(60)
	_quiet()
	await _cut_to(func():
		_close_modals()
		await _inside("small_office")
		_unzoom())
	_say("x_team", "bottom")
	await bot.wait(2.6)
	# money: the bank or an investor
	await _cut_to(func():
		await _inside("nexus_bank"))
	await bot.wait(1.8)
	await _cut_to(func():
		await _modal(LoanModal.new(true))
		_zoom_modal(1.4))
	_say("x_bank", "bottom")
	await bot.wait(2.4)
	await _cut_to(func():
		_close_modals()
		await _modal(FundraisingModal.new())
		_zoom_modal(1.4))
	_say("x_investor", "bottom")
	await bot.wait(2.6)
	# month close
	var reps: Array = GameState.data["reports"]["month_closes"]
	await _cut_to(func():
		_close_modals()
		await _inside("small_office")
		if not reps.is_empty():
			await _modal(MonthCloseModal.new(reps[-1]))
		_zoom_modal(1.5), true)
	_say("x_close", "bottom")
	await bot.wait(2.8)
	# a creative pitch (media agency)
	_fresh("Ad Media", 7301)
	Company.register("Loft Creative", "media", "The Loft")
	Company.open_business_account(25000)
	_equity(175000, "Ad media equity")
	Living.lease("loft_office")
	Media.start()
	Clock.advance_to(Clock.next_time_of_day(21 * 60))
	_quiet()
	await _cut_to(func():
		_close_modals()
		await _street("university", 1090, 21))
	await _walk("left", 2.0, false)
	var open_briefs: Array = Media.S()["briefs"].values().filter(func(x): return x["status"] == "open")
	if not open_briefs.is_empty():
		var brief: Dictionary = open_briefs[0]
		var creative := CreativePitch.new(brief)
		creative.mark_tutorial_seen()
		await _cut_to(func():
			await _inside("the_loft")
			await _modal(creative)
			creative.start()
			await bot.frames(2)
			_zoom_modal(1.4))
		_say("x_pitch", "bottom")
		await bot.wait(0.9)
		for i in 3:
			creative.choose(int(brief["preferences"][i]))
			await bot.wait(0.6)
		await bot.wait(0.9)
	# flip a flat
	_fresh("Ad Flip", 7302)
	Company.register("Harlow Homes", "real_estate", "Harlow")
	Company.open_business_account(25000)
	_equity(2500000, "Ad development equity")
	Compliance.apply_permit("brokerage")
	Clock.advance(3 * Clock.DAY)
	Living.lease("realty_office")
	RealEstate.start()
	RealEstate.buy("maple_1", .2, 25)
	Clock.advance_to(Clock.next_time_of_day(10 * 60))
	_quiet()
	await _cut_to(func():
		_close_modals()
		await _inside("maple_court"))
	await bot.wait(1.2)
	await _cut_to(func():
		var re := RealEstateUI.new()
		re.page = "properties"
		await _modal(re)
		_zoom_modal(1.4))
	_say("x_reno", "bottom")
	await bot.wait(2.4)
	# a rescue, not a game over
	_load_fixture()
	await _cut_to(func():
		_close_modals()
		await _inside("small_office")
		Insolvency.begin(GameState.company_id(), "連續三次發不出薪水" if zh else "three payrolls in a row went unpaid")
		await bot.frames(3)
		if not (UIRoot.top_modal() is InsolvencyModal):
			await _modal(InsolvencyModal.new())
		for c in UIRoot.toast_box.get_children():
			c.queue_free()
		_zoom_modal(1.4))
	_say("x_fail", "bottom")
	await bot.wait(3.0)
	_close_modals()


# ------------------------------------------------------------------ end card
func _end_card(ad: String) -> void:
	var line_key: String = {"tycoon": "t_end", "city": "c_end", "choices": "x_end"}.get(ad, "t_end")
	await _cut_to(func():
		_close_modals()
		_clear_caption()
		var c := Control.new()
		c.size = Vector2(W, H)
		c.theme = UIK.theme()
		c.add_child(Backdrop.make("backdrops/arrival" if ad != "city" else "backdrops/menu", 1.0e9))
		var shade := ColorRect.new()
		shade.color = Color(0.03, 0.06, 0.13, 0.6)
		shade.size = Vector2(W, H)
		c.add_child(shade)
		SceneRouter._set_scene(c)
		UIRoot.set_hud_visible(false)
		await bot.frames(1))
	cap = Control.new()
	cap.size = Vector2(W, H)
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cap)
	root.move_child(cap, 0)
	var line := _lbl(t(line_key), 17 if zh else 15, Art.C_WHITE)
	line.size = Vector2(W, 24)
	line.position = Vector2(0, 70)
	cap.add_child(line)
	var ic := TextureRect.new()
	ic.texture = Art.tex("ui/app_icon")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.size = Vector2(48, 48)
	ic.position = Vector2(296, 108)
	cap.add_child(ic)
	var ti := _lbl("CITY VENTURE", 36, Color8(236, 242, 255))
	ti.size = Vector2(W, 46)
	ti.position = Vector2(0, 160)
	ti.pivot_offset = Vector2(W / 2.0, 23)
	cap.add_child(ti)
	var gn := _lbl(t("genre"), 11, Art.C_SKY, false)
	gn.size = Vector2(W, 14)
	gn.position = Vector2(0, 208)
	cap.add_child(gn)
	var chip := PanelContainer.new()
	chip.add_theme_stylebox_override("panel", UIK.flat(Art.C_GOLD, Color(0, 0, 0, 0), 0, 3))
	var cl := UIK.label("   %s   " % t("cta"), 13, Art.C_NAVY_900, true)
	cl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	chip.add_child(cl)
	cap.add_child(chip)
	var lg := _lbl(t("langs"), 9, Art.C_WHITE, false)
	lg.size = Vector2(W, 12)
	lg.position = Vector2(0, 300)
	cap.add_child(lg)
	await bot.frames(1)
	chip.reset_size()
	await bot.frames(1)
	chip.position = Vector2((W - chip.size.x) / 2.0, 240)
	for n in [line, ic, ti, gn, chip, lg]:
		n.modulate.a = 0.0
	ti.scale = Vector2(1.25, 1.25)
	var tw := cap.create_tween()
	tw.tween_property(line, "modulate:a", 1.0, 0.3)
	tw.tween_property(ic, "modulate:a", 1.0, 0.2)
	tw.tween_property(ti, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(ti, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(gn, "modulate:a", 1.0, 0.2)
	tw.tween_property(chip, "modulate:a", 1.0, 0.25)
	tw.parallel().tween_property(lg, "modulate:a", 1.0, 0.25)
	await bot.wait(4.2)
	var tw2 := black.create_tween()
	black.color = Color8(6, 10, 20)
	tw2.tween_property(black, "modulate:a", 1.0, 0.5)
	await tw2.finished
