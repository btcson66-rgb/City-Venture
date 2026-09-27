class_name Tutorial
extends Control
## New-player onboarding and goal guidance.
##  • Tutorial card: a short, ordered list of "how to play" steps (move, phone, leave a room, follow the
##    goal, use things, time, map, Company OS). Each step completes by doing it; a step the player has
##    already done completes on its own. Progress lives in the save (GameState.data["tutorial"]).
##  • Guide arrow: points at the current main objective's `target` (data/story/chapters.json). On
##    screen it bounces over the spot; off screen it sits on the screen edge with the place's name.
##    Routes through room exits, street edges and the Metro. Toggle in the pause menu (settings.cfg).

const SETTINGS := "user://settings.cfg"
const HOME := "riverside_apartment"
const STEPS := [
	{"id": "move", "title": "Moving around", "text": "Walk with WASD or the arrow keys. Hold Shift to run.", "keys": ["W", "A", "S", "D", "Shift"]},
	{"id": "phone", "title": "Your phone", "text": "Press Tab, or click Phone at the top right, to read your messages.", "keys": ["Tab"]},
	{"id": "exit", "title": "Leaving a room", "text": "Every room's exit is the glowing EXIT mat at the bottom. Walk onto it to go outside.", "keys": []},
	{"id": "follow", "title": "Follow the gold arrow", "text": "Your goal is at the top left. The gold arrow shows the way: walk into a door to go inside.", "keys": []},
	{"id": "interact", "title": "Using things", "text": "Stand next to a person or object. When a prompt appears at the bottom, press E or click it.", "keys": ["E"]},
	{"id": "time", "title": "Time and opening hours", "text": "The clock runs while you walk. Hold T to fast-forward. Shops keep opening hours; sleep in your bed to end the day.", "keys": ["T"]},
	{"id": "map", "title": "Getting around the city", "text": "Press M for the city map. Walk off the edge of a street (follow the → signs) to reach the next district, or ride the Metro.", "keys": ["M"]},
	{"id": "os", "title": "Company OS", "text": "Your business runs from any laptop: home desk, café table or co-work hot desk. Walk up to one and press E.", "keys": ["E"], "after_flag": "business_chosen"},
]

var card: PanelContainer
var head: Label
var body: Label
var keys_row: HBoxContainer
var _t := 0.0
var _step_t := 0.0
var _last_pos := Vector2.INF
var _moved := 0.0
var _completing := false
var _guide_on := true
var _target := {}          # {pos: Vector2 (world), label: String}
var _target_scene := ""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		_guide_on = bool(cfg.get_value("general", "guide", true))
	card = PanelContainer.new()
	var sb := UIK.flat(Color(0.05, 0.08, 0.15, 0.93), Art.C_GOLD, 1, 3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	card.add_theme_stylebox_override("panel", sb)
	card.custom_minimum_size = Vector2(196, 0)
	card.visible = false
	add_child(card)
	var v := UIK.vbox(2)
	card.add_child(v)
	var hr := UIK.hbox(3)
	v.add_child(hr)
	hr.add_child(UIK.icon("star", 9))
	head = UIK.label("", 7, Art.C_GOLD, true)
	head.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	head.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(head)
	var skip := UIK.button("Skip", skip_all)
	skip.name = "SkipTutorial"
	skip.add_theme_font_size_override("font_size", 6)
	skip.add_theme_stylebox_override("normal", UIK.flat(Color(0, 0, 0, 0), Color(1, 1, 1, 0.25), 1, 2))
	skip.add_theme_stylebox_override("hover", UIK.flat(Color(1, 1, 1, 0.08), Art.C_GOLD, 1, 2))
	skip.add_theme_color_override("font_color", Art.C_MUTED)
	hr.add_child(skip)
	body = UIK.wrap("", 8, Art.C_WHITE, 184)
	body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(body)
	keys_row = UIK.hbox(2)
	v.add_child(keys_row)
	EventBus.interacted.connect(func(_a, _b): _seen("interact"))


# ------------------------------------------------------------------ state
func st() -> Dictionary:
	if not GameState.has_game():
		return {}
	if not GameState.data.has("tutorial"):
		# saves from before the tutorial existed: only new-ish games get it
		var fresh: bool = str(GameState.data["story"].get("chapter", "")) in ["", "ch1_arrival"]
		GameState.data["tutorial"] = {"step": 0, "seen": {}, "off": not fresh}
	return GameState.data["tutorial"]


func _seen(what: String) -> void:
	var s := st()
	if not s.is_empty():
		s["seen"][what] = true


func is_active() -> bool:
	var s := st()
	return not s.is_empty() and not bool(s.get("off", false)) and int(s.get("step", 0)) < STEPS.size()


func skip_all() -> void:
	var s := st()
	if s.is_empty():
		return
	s["off"] = true
	card.visible = false
	UIRoot.toast(I18n.t("Tutorial skipped. You can replay it from the pause menu (Esc)."), "info", "info")


func restart() -> void:
	if not GameState.has_game():
		return
	GameState.data["tutorial"] = {"step": 0, "seen": {}, "off": false}
	_moved = 0.0
	_step_t = 0.0


static func guide_enabled() -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		return bool(cfg.get_value("general", "guide", true))
	return true


func set_guide(on: bool) -> void:
	_guide_on = on
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS)
	cfg.set_value("general", "guide", on)
	cfg.save(SETTINGS)
	queue_redraw()


# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	_t += delta
	var ws := SceneRouter.world_scene()
	var live := GameState.has_game() and UIRoot.hud.visible and ws != null and not SceneRouter.transitioning
	visible = live
	if not live:
		return
	_track(ws, delta)
	var blocked := UIRoot.is_blocking()
	# card
	if is_active():
		var i := int(st()["step"])
		var s: Dictionary = STEPS[i]
		var gated: bool = s.has("after_flag") and not GameState.flag(str(s["after_flag"]))
		card.visible = not blocked and not gated
		if not gated:
			_step_t += delta
			_show_step(i)
			if not _completing and _step_done(str(s["id"]), ws):
				_complete_step()
	else:
		card.visible = false
	var op := UIRoot.hud.obj_panel
	card.position = Vector2(6, (op.position.y + op.size.y + 4) if op.visible else 42.0)
	# guide
	_target = _resolve(ws) if _guide_on and not blocked else {}
	queue_redraw()


func _track(ws: WorldScene, _delta: float) -> void:
	if ws.player != null:
		var p := ws.player.global_position
		if _last_pos != Vector2.INF and p.distance_to(_last_pos) < 20.0:
			_moved += p.distance_to(_last_pos)
		_last_pos = p
		if _moved > 48.0:
			_seen("move")
	if UIRoot.phone.is_open:
		_seen("phone")
	if ws.kind == "district":
		_seen("exit")
		if ws.scene_id != "riverside":
			_seen("map")
	elif ws.scene_id != HOME:
		_seen("follow")
	if Clock.fast_forward:
		_seen("time")
	var tm := UIRoot.top_modal()
	if tm is CityMapModal:
		_seen("map")
	elif tm is CompanyOS:
		_seen("os")


func _step_done(id: String, _ws: WorldScene) -> bool:
	if bool(st()["seen"].get(id, false)):
		return true
	# reading-only steps move on by themselves after a while
	return id == "time" and _step_t > 14.0


func _complete_step() -> void:
	_completing = true
	head.text = "✓ " + head.text
	head.add_theme_color_override("font_color", Art.C_GREEN)
	await get_tree().create_timer(0.9).timeout
	var s := st()
	if not s.is_empty():
		s["step"] = int(s["step"]) + 1
		if int(s["step"]) >= STEPS.size():
			UIRoot.toast(I18n.t("Tutorial complete. The gold arrow keeps pointing at your goal (turn it off in the pause menu)."), "good", "check")
	head.add_theme_color_override("font_color", Art.C_GOLD)
	_step_t = 0.0
	_completing = false
	SaveSystem.autosave_if_changed()


var _shown := -1
var _shown_loc := ""


func _show_step(i: int) -> void:
	if _completing or (_shown == i and _shown_loc == I18n.locale()):
		return
	_shown = i
	_shown_loc = I18n.locale()
	var s: Dictionary = STEPS[i]
	head.text = (I18n.t("TUTORIAL %d/%d") % [mini(i + 1, STEPS.size()), STEPS.size()]) + "  ·  " + I18n.t(str(s["title"]))
	body.text = I18n.t(str(s["text"]))
	for c in keys_row.get_children():
		c.queue_free()
	for k in s["keys"]:
		var kc := PanelContainer.new()
		kc.add_theme_stylebox_override("panel", UIK.tex_box("ui/prompt_key", 2, 2))
		var kl := UIK.label(" %s " % I18n.t(str(k)), 7, Art.C_NAVY_800, true)
		kl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		kc.add_child(kl)
		keys_row.add_child(kc)
	keys_row.visible = not s["keys"].is_empty()
	_fit_card.call_deferred()


func _fit_card() -> void:
	card.reset_size()


# ------------------------------------------------------------------ guide target
func _resolve(ws: WorldScene) -> Dictionary:
	if not GameState.has_game():
		return {}
	var tgt := {}
	# the tutorial's "leave the room" step points at the exit even before the story asks
	if is_active() and str(STEPS[int(st()["step"])]["id"]) == "exit" and ws.kind == "interior":
		return _exit_of(ws)
	var o := StoryEngine.main_objective()
	tgt = o.get("target", {})
	if tgt.is_empty() or tgt.get("phone", false):
		return {}
	if tgt.has("building"):
		return _route_to_building(ws, str(tgt["building"]), str(tgt.get("action", "")))
	if tgt.has("action"):
		var near := _interactable(ws, str(tgt["action"]))
		if not near.is_empty():
			return near
		return _route_to_building(ws, _workplace(), str(tgt["action"]))
	if tgt.has("district"):
		if ws.kind == "interior":
			return _exit_of(ws)
		if ws.scene_id != str(tgt["district"]):
			return _route_to_district(ws, str(tgt["district"]))
	return {}


func _workplace() -> String:
	if GameState.company_id() != "" and Living.has_lease("suite_2b"):
		return "small_office"
	return HOME


func _exit_of(ws: WorldScene) -> Dictionary:
	var d: Vector2 = ws.spawns.get("door", Vector2(ws.size_px.x / 2.0, ws.size_px.y - 22))
	return {"pos": Vector2(d.x, ws.size_px.y - 6), "label": I18n.t("Exit")}


func _interactable(ws: WorldScene, action: String) -> Dictionary:
	var best: Node2D = null
	var bd := 1e9
	var pp: Vector2 = ws.player.global_position if ws.player != null else Vector2.ZERO
	for n in get_tree().get_nodes_in_group("interactable"):
		if n.action == action and n.enabled and ws.is_ancestor_of(n):
			var d: float = (n as Node2D).global_position.distance_to(pp)
			if d < bd:
				bd = d
				best = n
	if best == null:
		return {}
	var lb := str(best.label)
	if lb.contains("—"):
		lb = lb.get_slice("—", 0).strip_edges()
	return {"pos": best.global_position, "label": I18n.t(lb)}


func _route_to_building(ws: WorldScene, bid: String, action: String) -> Dictionary:
	if ws.kind == "interior":
		if ws.scene_id == bid:
			return _interactable(ws, action) if action != "" else {}
		return _exit_of(ws)
	var b := DataDB.building(bid)
	var district := str(b.get("district", ""))
	if district == ws.scene_id:
		var dp: Vector2 = ws.spawns.get("door_" + bid, Vector2.ZERO)
		if dp == Vector2.ZERO:
			return {}
		return {"pos": dp - Vector2(0, 20), "label": I18n.t(str(b.get("name", bid)))}
	return _route_to_district(ws, district)


func _route_to_district(ws: WorldScene, to: String) -> Dictionary:
	var hop := _next_hop(ws.scene_id, to)
	if hop != "":
		for e in DataDB.districts[ws.scene_id].get("exits", []):
			if str(e["to"]) == hop:
				var r: Array = e["rect"]
				var c := Vector2(float(r[0]) + float(r[2]) / 2.0, float(r[1]) + float(r[3]) / 2.0)
				var inward := -1.0 if float(r[0]) > ws.size_px.x / 2.0 else 1.0
				return {"pos": c + Vector2(inward * 18.0, 0), "label": "→ " + I18n.t(str(DataDB.districts[hop]["name"]))}
	# not walkable from here: the Metro
	var m := _interactable(ws, "metro")
	if not m.is_empty():
		m["label"] = I18n.t("Metro") + " → " + I18n.t(str(DataDB.districts[to]["name"]))
	return m


## First district to walk to on the way to `to` (breadth-first over street exits), or "".
static func _next_hop(from: String, to: String) -> String:
	var prev := {from: ""}
	var q: Array = [from]
	while not q.is_empty():
		var cur: String = q.pop_front()
		if cur == to:
			break
		for e in DataDB.districts.get(cur, {}).get("exits", []):
			var nx := str(e["to"])
			if not prev.has(nx):
				prev[nx] = cur
				q.append(nx)
	if not prev.has(to):
		return ""
	var step := to
	while prev[step] != from and prev[step] != "":
		step = prev[step]
	return step


# ------------------------------------------------------------------ drawing
func _draw() -> void:
	if _target.is_empty():
		return
	var xf := get_viewport().get_canvas_transform()
	var sp: Vector2 = xf * (_target["pos"] as Vector2)
	var view := Rect2(Vector2(14, 14), Vector2(640 - 28, 360 - 28))
	var gold := Color(1.0, 0.8, 0.26)
	var ink := Color(0.1, 0.07, 0.02)
	var font := UIK.bold_font()
	var label := str(_target.get("label", ""))
	if view.has_point(sp):
		var y := sp.y - 22.0 - 4.0 * absf(sin(_t * 3.2))
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		draw_arc(sp, 7.0 + pulse * 3.0, 0, TAU, 28, Color(gold, 0.35 + 0.4 * (1.0 - pulse)), 1.5)
		var pts := PackedVector2Array([Vector2(-4, -9), Vector2(4, -9), Vector2(4, -3), Vector2(8, -3), Vector2(0, 5), Vector2(-8, -3), Vector2(-4, -3)])
		var arrow := PackedVector2Array()
		for p in pts:
			arrow.append(p + Vector2(sp.x, y))
		draw_colored_polygon(arrow, gold)
		arrow.append(arrow[0])
		draw_polyline(arrow, ink, 1.0)
		if label != "":
			var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
			var lp := Vector2(sp.x - w / 2.0, y - 13)
			draw_rect(Rect2(lp + Vector2(-3, -8), Vector2(w + 6, 11)), Color(0.05, 0.08, 0.15, 0.85))
			draw_string(font, lp, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, gold)
		return
	# off screen: clamp to the edge and point outwards
	var c := Vector2(320, 180)
	var dir := (sp - c).normalized()
	var k := 1e9
	if absf(dir.x) > 0.001:
		k = minf(k, ((view.end.x if dir.x > 0 else view.position.x) - c.x) / dir.x)
	if absf(dir.y) > 0.001:
		k = minf(k, ((view.end.y if dir.y > 0 else view.position.y) - c.y) / dir.y)
	var ep := c + dir * k
	var bob := 2.0 * sin(_t * 5.0)
	ep += dir * bob
	var side := dir.orthogonal()
	var tri := PackedVector2Array([ep + dir * 8.0, ep - dir * 4.0 + side * 7.0, ep - dir * 4.0 - side * 7.0])
	draw_colored_polygon(tri, gold)
	tri.append(tri[0])
	draw_polyline(tri, ink, 1.0)
	if label != "":
		var w2 := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7).x
		var lp2 := ep - dir * 16.0 - Vector2(w2 / 2.0, -3)
		lp2.x = clampf(lp2.x, 4, 640 - 4 - w2)
		lp2.y = clampf(lp2.y, 12, 360 - 6)
		draw_rect(Rect2(lp2 + Vector2(-3, -8), Vector2(w2 + 6, 11)), Color(0.05, 0.08, 0.15, 0.85))
		draw_string(font, lp2, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 7, gold)
