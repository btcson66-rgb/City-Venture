class_name TypingGame
extends MiniGame
## Do the work yourself at the keyboard: type out the code for your SaaS product, or build the spreadsheet a consulting
## client is paying for. The whole snippet is on screen; you type its key lines (at most MAX_LINES, one per round),
## the rest is already written: a short burst of real typing, not a shift at the keyboard. Accuracy decides
## how much the session gets done (`hours` in the result: 0.5×–1.25× the session's nominal hours).
## Texts: data/minigames/typing.json (code and formulas stay in English, as you would really type them).

const CHAR_W := 6.6
const LINE_H := 15.0
const MAX_LINES := 2
const MAX_CHARS := 64        # a second line is only added while the two stay this short

var lines: Array = []
var todo: Array = []          # indices of the lines the player types
var base_hours := 2.0
var li := 0                   # line being typed
var col := 0                  # next character in it
var errors := 0
var typed := 0
var _err_flash := 0.0
var view: Control


## mode: "saas" (key = SaaS idea id) or "freelance".
func _init(mode := "saas", key := "", hours := 2.0, heading := "") -> void:
	super._init()
	base_hours = hours
	icon_name = "laptop"
	var d = DataDB._read("res://data/minigames/typing.json")
	var pool: Array = []
	if typeof(d) == TYPE_DICTIONARY:
		if mode == "saas":
			pool = d.get("saas", {}).get(key, d.get("saas", {}).get("_generic", []))
		else:
			pool = d.get("freelance", [])
	if pool.is_empty():
		pool = [["print(\"hello, Aurelia\")"]]
	lines = pool[randi() % pool.size()]
	todo = pick_lines(lines)
	rounds = todo.size()
	round_time = 0.0
	title_text = heading if heading != "" else ("Coding session" if mode == "saas" else "Client work")


func intro_lines() -> Array:
	return ["Type the bright lines exactly as shown (the grey ones are already written). The next character to type is highlighted.",
		"Leading spaces are filled in for you, and a run of spaces takes one press. A wrong key gives a gentle hint; just type the right one.",
		"Accuracy decides the work completed. Take your time.",
		"Using a Chinese input method? Switch the keyboard to English input first."]


func round_name() -> String:
	return "Line %d / %d"


## The lines worth typing: skip bare brackets and blank lines, start somewhere random, stop at MAX_LINES/MAX_CHARS.
static func pick_lines(ls: Array) -> Array:
	var real: Array = []
	for i in ls.size():
		if str(ls[i]).strip_edges().length() > 3:
			real.append(i)
	if real.is_empty():
		return [0]
	var k := randi() % real.size()
	var out: Array = [real[k]]
	var chars := str(ls[real[k]]).strip_edges().length()
	while out.size() < MAX_LINES and k + 1 < real.size():
		k += 1
		chars += str(ls[real[k]]).strip_edges().length()
		if chars > MAX_CHARS:
			break
		out.append(real[k])
	return out


func build_round() -> void:
	li = int(todo[round_i])
	col = 0
	errors = 0
	typed = 0
	_skip_spaces(true)
	UIK.clear(stage)
	var bg := card(Color8(18, 22, 32), Color8(60, 72, 100))
	bg.custom_minimum_size = Vector2(580, 200)
	stage.add_child(bg)
	view = Control.new()
	view.name = "TypingView"
	view.custom_minimum_size = Vector2(566, 190)
	view.draw.connect(_draw_view)
	bg.add_child(view)
	var hint := UIK.label("Just type. (Esc leaves the session.)", 7, Art.C_DIM)
	hint.position = Vector2(4, 208)
	stage.add_child(hint)


func _cur() -> String:
	return str(lines[li]) if li < lines.size() else ""


## Skip leading indentation (at_start) or a run of spaces after the first one.
func _skip_spaces(at_start: bool) -> void:
	var s := _cur()
	if at_start:
		while col < s.length() and s[col] == " ":
			col += 1


func _input(event: InputEvent) -> void:
	if phase != "play" or not (event is InputEventKey) or not event.pressed:
		return
	var k := event as InputEventKey
	if event.is_action_pressed("pause") or event.is_action_pressed("cancel"):
		return   # MiniGame handles leaving
	var s := _cur()
	if col >= s.length():
		return
	var ch := ""
	if k.unicode > 0:
		ch = char(k.unicode)
	elif k.keycode == KEY_SPACE:
		ch = " "
	if ch == "":
		return
	get_viewport().set_input_as_handled()
	if ch == s[col]:
		col += 1
		typed += 1
		if ch == " ":
			while col < s.length() and s[col] == " ":
				col += 1
		if col >= s.length():
			_line_done()
	else:
		errors += int(not practice_only)
		_err_flash = 0.35
	view.queue_redraw()


func _line_done() -> void:
	var acc := float(typed) / maxf(1.0, float(typed + errors))
	award(acc)
	next_round()


func _process(delta: float) -> void:
	super._process(delta)
	if phase == "play":
		if _err_flash > 0.0:
			_err_flash -= delta
			if view != null and is_instance_valid(view):
				view.queue_redraw()


func _draw_view() -> void:
	var font := UIK.body_font()
	var first := maxi(0, li - 4)
	for i in range(first, mini(lines.size(), first + 11)):
		var s := str(lines[i])
		var y := 14.0 + (i - first) * LINE_H
		var mine := todo.has(i)
		for c in s.length():
			var x := 6.0 + c * CHAR_W
			var colr := Color(0.92, 0.94, 1.0) if mine else Color(0.42, 0.46, 0.56)   # to type / already written
			if mine and i < li:
				colr = Color(0.45, 0.85, 0.55)
			elif i == li:
				if c < col:
					colr = Color(0.45, 0.85, 0.55)
				elif c == col:
					view.draw_rect(Rect2(x - 1, y - 10, CHAR_W + 1, 13), Art.C_SKY)
					colr = Color(0.08, 0.08, 0.1)
				else:
					colr = Color(0.92, 0.94, 1.0)
			if s[c] != " ":
				# the body font isn't monospaced: centre each glyph in its cell so "fil" doesn't read as "f il"
				var cw := font.get_char_size(s.unicode_at(c), 10).x
				view.draw_char(font, Vector2(x + (CHAR_W - cw) / 2.0, y), s[c], 10, colr)
			elif i == li and c == col:
				view.draw_rect(Rect2(x, y + 1, CHAR_W - 1, 1), Color(0.08, 0.08, 0.1))


func extra_result() -> Dictionary:
	return {"hours": base_hours * (0.5 + 0.75 * score())}


func result_lines() -> Array:
	return [I18n.t("Work done this session: %.1f of %.1f hours' worth") % [base_hours * (0.5 + 0.75 * score()), base_hours]]
