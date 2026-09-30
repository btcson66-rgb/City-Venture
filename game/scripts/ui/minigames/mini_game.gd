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


func _build_intro() -> void:
	var v := UIK.vbox(5)
	body.add_child(v)
	v.add_child(UIK.label("HOW IT WORKS", 7, Art.C_DIM, true))
	for line in intro_lines():
		var row := UIK.hbox(4)
		row.add_child(UIK.label("•", 9, Art.C_GOLD, true))
		row.add_child(UIK.wrap(I18n.t(str(line)), 9, Art.C_WHITE, 540))
		v.add_child(row)
	var go := UIK.button("Start", start, "primary", 110)
	go.name = "StartGame"
	footer.add_child(UIK.button("Not now", abort))
	footer.add_child(go)


func start() -> void:
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
	_timer_bar.visible = round_time > 0.0
	top.add_child(_timer_bar)
	stage = Control.new()
	stage.custom_minimum_size = Vector2(580, 236)
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(stage)
	var leave := UIK.button("Leave early", abort)
	leave.name = "LeaveGame"
	footer.add_child(leave)
	_round_t = 0.0
	_update_status()
	build_round()


func _update_status() -> void:
	if status == null or not is_instance_valid(status):
		return
	status.text = (I18n.t(round_name()) % [mini(round_i + 1, rounds), rounds]) + "   ·   " + I18n.t("Score %d%%") % int(round(score_so_far() * 100.0))


func score_so_far() -> float:
	return points / maxf(1.0, float(round_i)) if round_i > 0 else 0.0


func score() -> float:
	return clampf(points / maxf(1.0, float(rounds)), 0.0, 1.0)


## Points for the current round (0..1).
func award(p: float) -> void:
	points += clampf(p, 0.0, 1.0)


func next_round() -> void:
	round_i += 1
	_round_t = 0.0
	if round_i >= rounds:
		phase = "results"
		rebuild()
		return
	UIK.clear(stage)
	_update_status()
	build_round()


func time_left() -> float:
	return 1.0 if round_time <= 0.0 else clampf(1.0 - _round_t / round_time, 0.0, 1.0)


func _process(delta: float) -> void:
	if phase != "play" or round_time <= 0.0:
		return
	_round_t += delta
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
	v.add_child(UIK.title("★".repeat(stars) + "☆".repeat(3 - stars), 20, Art.C_GOLD))
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
	if _done_sent:
		return
	_done_sent = true
	finished.emit(r)
	if on_done.is_valid():
		on_done.call(r)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
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
	var l := UIK.label(I18n.t(text), 11, Art.C_GREEN if good else Art.C_RED, true)   # already-translated text passes through
	l.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	l.position = panel.position + Vector2(14, panel_size.y - 26)
	l.z_index = 5
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.5)
	tw.tween_callback(l.queue_free)
