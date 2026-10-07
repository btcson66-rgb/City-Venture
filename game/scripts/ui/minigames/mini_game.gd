class_name MiniGame
extends Modal
## Hands-on work. A short playable task stands in for hours of in-game work: a shift behind the counter, a photo
## shoot, packing an order, writing code. World time is paused while it runs (like every Modal); the caller applies
## the in-game time and the result afterwards through `on_done(result)`.
##
## Flow: intro card (what the job is, how to play) → rounds → results card (score, what it means) → on_done.
## Subclasses override `intro_lines()`, `build_round()` (fill `stage` for round `round_i`), `result_lines()`, and
## call `award(points)` then `next_round()`; `points` per round are 0..1, so `score()` is 0..1.
## Leaving early (Esc or the Leave button) calls on_done with {"aborted": true}.

signal finished(result: Dictionary)

## Practice uses a separate copy of the game. Closing it never reaches the real-work callback.
var practice_only := false
var practice_step := 0
var practice_target: Control
var _practice_overlay: Control
var _practice_hint: Label
var _practice_pending := false
var _practice_open := false
var _practice_data := {}

var rounds := 6
var round_i := 0
var points := 0.0
var phase := "intro"          # intro | play | results
var on_done: Callable
var stage: Control            # the play area for the current round
var status: Label             # "Order 3 / 6 · 82%"
var round_time := 0.0         # seconds allowed per round (0 = untimed)
var _round_t := 0.0
var _timer_bar: ProgressBar
var _done_sent := false


func _init() -> void:
	pauses_time = true
	panel_size = Vector2(600, 322)
	icon_name = "clock"


func _ready() -> void:
	help_key = "" # Guided practice replaces the first-open prose card.
	_practice_data = tutorial_data()
	super._ready()
	var layout_driver := WorkLayoutDriver.new()
	layout_driver.game = self
	add_child(layout_driver)
	var replay := UIK.button("?", replay_practice)
	replay.name = "PracticeHelp"
	replay.custom_minimum_size = Vector2(24, 24)
	header.add_child(replay)
	if not practice_only and not tutorial_seen() and MiniGames.auto < 0.0:
		replay_practice.call_deferred()


func tutorial_id() -> String:
	return get_script().resource_path.get_file().get_basename()


func tutorial_data() -> Dictionary:
	var all_data: Dictionary = DataDB._read("res://data/help/minigame_tutorials.json")
	return all_data.get(tutorial_id(), {})


func tutorial_seen() -> bool:
	return bool(GameState.data.get("minigame_tutorials_seen", {}).get(tutorial_key(), false))


func tutorial_key() -> String:
	return tutorial_id() + ":" + str(get("kind")) if self is ConsultingGame else tutorial_id()


func mark_tutorial_seen() -> void:
	if not GameState.data.has("minigame_tutorials_seen"):
		GameState.data["minigame_tutorials_seen"] = {}
	GameState.data["minigame_tutorials_seen"][tutorial_key()] = true


## Constructor inputs are copied, including nested order/request dictionaries; no world snapshot rollback.
func practice_copy() -> MiniGame:
	var copy: MiniGame
	if self is AuctionGame: copy = AuctionGame.new(get("lot_id"))
	elif self is PitchGame: copy = PitchGame.new(get("deal_id"))
	elif self is CreativePitch: copy = CreativePitch.new(get("brief").duplicate(true))
	elif self is PersonalRequestGame: copy = PersonalRequestGame.new(get("request").duplicate(true))
	elif self is PackGame: copy = PackGame.new(get("orders").duplicate(true))
	elif self is RouteGame: copy = RouteGame.new(get("job").duplicate(true))
	elif self is ConsultingGame: copy = ConsultingGame.new(get("kind"))
	elif self is PhotoShootGame: copy = PhotoShootGame.new(get("product"))
	else: copy = get_script().new()
	if self is TypingGame:
		copy.set("lines", get("lines").duplicate(true))
		copy.set("todo", get("todo").duplicate(true))
		copy.rounds = rounds
	copy.practice_only = true
	return copy


func replay_practice() -> void:
	if practice_only or _practice_open: return
	_practice_open = true
	visible = false
	set_process(false)
	set_process_input(false)
	set_process_unhandled_input(false)
	set_process_unhandled_key_input(false)
	var copy := practice_copy()
	copy.closed.connect(_resume_work.bind(copy))
	UIRoot.open_modal(copy)


func _resume_work(copy: MiniGame) -> void:
	_practice_open = false
	visible = true
	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)
	set_process_unhandled_key_input(true)
	if phase == "intro":
		if copy.phase == "practice_ready": start()
		else: rebuild()


func skip_practice() -> void:
	mark_tutorial_seen()
	close()


func practice_complete() -> void:
	if phase != "play": return
	mark_tutorial_seen()
	phase = "practice_ready"
	practice_target = null
	if is_instance_valid(_practice_overlay): _practice_overlay.queue_free()
	rebuild()


# ------------------------------------------------------------------ to override
func intro_lines() -> Array:
	return []


func build_round() -> void:
	pass


## Called when a timed round runs out (default: no points).
func round_timeout() -> void:
	award(0.0)
	next_round()


func result_lines() -> Array:
	return []


## Round label, e.g. "Customer %d / %d".
func round_name() -> String:
	return "Round %d / %d"


# ------------------------------------------------------------------ flow
func build() -> void:
	match phase:
		"intro":
			_build_intro()
		"play":
			_build_play()
		"results":
			_build_results()
		"practice_ready":
			body.add_child(UIK.wrap("Ready! Start work", 13, Art.C_GREEN, 540))
			var go := UIK.button("Start work", close, "primary", 110)
			go.name = "StartFormalWork"
			footer.add_child(go)


func _build_intro() -> void:
	var d := tutorial_data()
	var v := UIK.vbox(5)
	body.add_child(v)
	if practice_only and self is BaristaGame:
		v.add_child(UIK.wrap("Manager: Let's try one order together. Take your time.", 9, Art.C_SKY, 540))
	v.add_child(UIK.wrap(I18n.t(str(d.get("goal", ""))), 10, Art.C_WHITE, 540))
	v.add_child(UIK.label(I18n.t(str(d.get("controls", ""))), 9, Art.C_SKY))
	v.add_child(UIK.wrap(I18n.t(str(d.get("good", ""))), 9, Art.C_MUTED, 540))
	if practice_only:
		v.add_child(UIK.label("Practice: no timer, score or pay changes.", 8, Art.C_DIM))
	var go := UIK.button("Begin practice" if practice_only else "Start", start, "primary", 110)
	go.name = "StartGame"
	if practice_only:
		var skip := UIK.button("Skip tutorial", skip_practice)
		skip.name = "SkipPractice"
		footer.add_child(skip)
	else:
		footer.add_child(UIK.button("Not now", abort))
		var replay := UIK.button("Practice again", replay_practice)
		replay.name = "ReplayPractice"
		footer.add_child(replay)
	footer.add_child(go)


func start() -> void:
	if not practice_only and not tutorial_seen() and MiniGames.auto < 0.0:
		replay_practice()
		return
	phase = "play"
	round_i = 0
	points = 0.0
	rebuild()


func _build_play() -> void:
	var top := UIK.hbox(6)
	body.add_child(top)
	status = UIK.label("", 8, Art.C_SKY, true)
	status.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(status)
	_timer_bar = ProgressBar.new()
	_timer_bar.custom_minimum_size = Vector2(150, 7)
	_timer_bar.show_percentage = false
	_timer_bar.max_value = 1.0
	_timer_bar.value = 1.0
	_timer_bar.visible = round_time > 0.0 and not practice_only
	top.add_child(_timer_bar)
	if practice_only:
		_practice_hint = UIK.wrap("", 10, Art.C_SKY, 540)
		body.add_child(_practice_hint)
	stage = Control.new()
	stage.custom_minimum_size = Vector2(580, 236)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var work_scroll := ScrollContainer.new()
	work_scroll.name = "WorkStageScroll"
	work_scroll.custom_minimum_size = Vector2(580, 170)
	work_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	work_scroll.add_child(stage)
	body.add_child(work_scroll)
	var leave := UIK.button("Skip tutorial" if practice_only else "Leave early", skip_practice if practice_only else abort)
	leave.name = "LeaveGame"
	footer.add_child(leave)
	_round_t = 0.0
	_update_status()
	build_round()
	if practice_only:
		_practice_overlay = PracticePointer.new()
		_practice_overlay.set("game", self)
		add_child(_practice_overlay)
		_practice_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_practice_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_practice_overlay.z_index = 20
		var guide := PracticeDriver.new()
		guide.set("game", self)
		add_child(guide)


func _update_status() -> void:
	if status == null or not is_instance_valid(status):
		return
	if practice_only:
		status.text = I18n.t("Practice — take your time")
		return
	status.text = (I18n.t(round_name()) % [mini(round_i + 1, rounds), rounds]) + "   ·   " + I18n.t("Score %d%%") % int(round(score_so_far() * 100.0))


func score_so_far() -> float:
	return points / maxf(1.0, float(round_i)) if round_i > 0 else 0.0


func score() -> float:
	return clampf(points / maxf(1.0, float(rounds)), 0.0, 1.0)


## Points for the current round (0..1).
func award(p: float) -> void:
	if practice_only: return
	points += clampf(p, 0.0, 1.0)


func next_round() -> void:
	round_i += 1
	_round_t = 0.0
	if round_i >= rounds:
		if practice_only: return
		phase = "results"
		rebuild()
		return
	UIK.clear(stage)
	_update_status()
	build_round()


func time_left() -> float:
	return 1.0 if practice_only or round_time <= 0.0 else clampf(1.0 - _round_t / round_time, 0.0, 1.0)


func _process(delta: float) -> void:
	if practice_only or phase != "play" or round_time <= 0.0:
		return
	_round_t += delta * PersonalLife.response_speed()
	if _timer_bar != null and is_instance_valid(_timer_bar):
		_timer_bar.value = time_left()
	if _round_t >= round_time:
		_round_t = 0.0
		round_timeout()


func _build_results() -> void:
	var s := score()
	var v := UIK.vbox(5)
	body.add_child(v)
	var stars := 1 + int(s >= 0.5) + int(s >= 0.8)
	v.add_child(UIK.title("★".repeat(stars) + "☆".repeat(3 - stars), 20, Art.C_SKY))
	v.add_child(UIK.title(I18n.t("Score %d%%") % int(round(s * 100.0)), 14, Art.C_WHITE))
	v.add_child(UIK.wrap(I18n.t(verdict(s)), 9, Art.C_SKY, 540))
	v.add_child(UIK.sep())
	for line in result_lines():
		v.add_child(UIK.wrap(str(line), 9, Art.C_WHITE, 540))
	var ok := UIK.button("Continue", _finish, "primary", 110)
	ok.name = "FinishGame"
	footer.add_child(ok)


func verdict(s: float) -> String:
	if s >= 0.8:
		return "Excellent work."
	if s >= 0.5:
		return "Solid. A few slips."
	if s >= 0.25:
		return "Rough going. Practice makes it easier."
	return "That went badly. It counts for little."


## Extra fields for the caller (tips earned, dev hours...).
func extra_result() -> Dictionary:
	return {}


func _finish() -> void:
	if practice_only: return
	var r := {"score": score()}
	r.merge(extra_result())
	_send(r)
	close()


func abort() -> void:
	_send({"aborted": true, "score": 0.0})
	close()


## The header's × leaves early too, so the caller always hears back.
func close() -> void:
	_send({"aborted": true, "score": 0.0})
	super.close()


func _send(r: Dictionary) -> void:
	if practice_only or _done_sent:
		return
	_done_sent = true
	if not r.get("aborted",false) and not self is PersonalRequestGame:
		PersonalLife.work(int(PersonalLife.cfg()["minigame_work_minutes"]))
	finished.emit(r)
	if on_done.is_valid():
		on_done.call(r)


func _unhandled_input(event: InputEvent) -> void:
	if (event.is_action_pressed("pause") or event.is_action_pressed("cancel")):
		get_viewport().set_input_as_handled()
		if phase == "results":
			_finish()
		else:
			abort()


## Test/bot hook: finish at a given quality without playing.
func autoplay(quality := 0.9) -> void:
	rounds = maxi(1, rounds)
	round_i = rounds
	points = clampf(quality, 0.0, 1.0) * rounds
	_finish()


# ------------------------------------------------------------------ helpers for subclasses
## A flat card for the play area.
static func card(bg := Color(0.07, 0.11, 0.2, 0.95), border := Color(0.3, 0.42, 0.62)) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UIK.flat(bg, border, 1, 3)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	return p


## A row of toggle buttons; `on_pick(value)` when one is pressed. Returns the row (buttons are named prefix_value).
static func choice_row(label: String, options: Array, current: String, on_pick: Callable, prefix: String, w := 0.0) -> HBoxContainer:
	var h := UIK.hbox(3)
	var l := UIK.label(label, 8, Art.C_MUTED, true)
	l.custom_minimum_size = Vector2(70, 0)
	h.add_child(l)
	for o in options:
		var val := str(o[0])
		var b := UIK.button(str(o[1]), on_pick.bind(val), "tab_active" if val == current else "tab", w)
		b.name = prefix + "_" + val
		h.add_child(b)
	return h


## Flash a short line at the bottom of the panel ("✓ Correct", "✗ Wrong box"); survives the next round's rebuild.
func flash(text: String, good: bool) -> void:
	var l := UIK.label(I18n.t(text), 11, Art.C_GREEN if good else (Art.C_SKY if practice_only else Art.C_RED), true)   # already-translated text passes through
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.position = panel.position + Vector2(14, panel_size.y - 26)
	l.z_index = 5
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tw.tween_callback(l.queue_free)


## A child keeps the guide active even when a minigame overrides _process.
class WorkLayoutDriver:
	extends Node
	var game
	func _process(_delta: float) -> void:
		if game.phase != "play" or not is_instance_valid(game.stage): return
		var wanted := Vector2(580, 236)
		for child in game.stage.get_children():
			if child is Container:
				wanted = wanted.max(child.position + child.get_combined_minimum_size())
		if game.stage.custom_minimum_size != wanted:
			game.stage.custom_minimum_size = wanted


class PracticeDriver:
	extends Node
	var game
	func _process(_delta: float) -> void:
		game.practice_refresh()


class PracticePointer:
	extends Control
	var game
	func _process(_delta: float) -> void: queue_redraw()
	func _draw() -> void:
		if not is_instance_valid(game.practice_target): return
		var rect: Rect2 = game.practice_target.get_global_rect()
		var inverse := get_global_transform().affine_inverse()
		rect = Rect2(inverse * rect.position, rect.size)
		draw_rect(rect.grow(3), Art.C_SKY, false, 2)
		var tip := rect.position + Vector2(-8, rect.size.y / 2)
		draw_line(tip - Vector2(12, 0), tip, Art.C_SKY, 2)
		draw_line(tip - Vector2(5, 4), tip, Art.C_SKY, 2)
		draw_line(tip - Vector2(5, -4), tip, Art.C_SKY, 2)


func practice_refresh() -> void:
	if not practice_only or phase != "play" or _practice_pending: return
	var steps: Array = _practice_data.get("steps", [])
	if practice_step >= steps.size(): practice_complete(); return
	var step: Dictionary = steps[practice_step]
	if step.get("condition", "") == "line_typed" and round_i > 0:
		practice_step += 1
		return
	var target_name := MinigamePracticeTargets.resolve(self, str(step["target"]))
	if target_name == "": practice_step += 1; return
	var target := find_child(target_name, true, false) as Control
	if not is_instance_valid(target):
		_practice_hint.text = I18n.t("Practice is unavailable here. Skip to return to work.")
		return
	_practice_hint.text = I18n.t(str(step["text"]))
	if target != practice_target:
		practice_target = target
		if target is BaseButton:
			target.pressed.connect(_practice_pressed.bind(practice_step, str(step["target"])), CONNECT_ONE_SHOT)
		elif step.get("condition", "") == "dragged":
			target.gui_input.connect(_practice_dragged)
		accessibility_scroll.ensure_control_visible(target)
		var work_scroll := stage.get_parent() as ScrollContainer
		if work_scroll.is_ancestor_of(target): work_scroll.ensure_control_visible.call_deferred(target)
		for sc in _scrolls(stage, []):
			if sc.is_ancestor_of(target): sc.ensure_control_visible(target)
	_lock_practice(stage, target)
	_lock_practice(footer, target)


func _lock_practice(node: Node, target: Control) -> void:
	for child in node.get_children():
		if child is BaseButton:
			child.disabled = child != target and child.name != "LeaveGame"
			child.modulate.a = 1.0 if not child.disabled else 0.35
		elif child is Control and child.name == "PhotoFrame":
			child.mouse_filter = Control.MOUSE_FILTER_PASS if child == target else Control.MOUSE_FILTER_IGNORE
		_lock_practice(child, target)


func _practice_dragged(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		_practice_pressed(practice_step, "PhotoFrame")


func _practice_pressed(index: int, selector: String) -> void:
	if index != practice_step or _practice_pending: return
	_practice_pending = true
	_practice_advance.call_deferred(selector)


func _practice_advance(selector: String) -> void:
	_practice_pending = false
	practice_target = null
	if phase != "play": return
	if selector == "$note" and call("total") < int(get("amount")): return
	if selector == "Pad" and float(get("pad")) < PackGame.PAD_ZONE[0]: return
	if selector == "$grid" and get("placements").size() < Packing.pieces(call("_order")).size():
		practice_step = 1
		return
	if selector == "$stop" and get("order").size() < get("stops").size(): return
	if selector == "$fact" and round_i < int(get("deck_n")): return
	if selector == "$pitch_answer" and round_i < rounds: return
	if selector == "$consult" and get("kind") == "operations" and round_i == 0: return
	practice_step += 1
