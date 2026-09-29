class_name TellerCashGame
extends MiniGame
## A shift at a Nexus Bank teller window: count out each customer's withdrawal exactly, using as few notes as you can.

const NOTES := [100, 50, 20, 10, 5, 1]

var amount := 0
var tray: Array = []
var right := 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	super._init()
	title_text = "Shift — Nexus Bank teller window"
	icon_name = "bank"
	rounds = 6
	round_time = 32.0
	rng.seed = Clock.now() * 23 + 9


func intro_lines() -> Array:
	return ["Each customer asks for a cash withdrawal. Click notes into the tray until it adds up exactly.",
		"Hand it over when the total matches. Exact with the fewest notes is best; a wrong amount is a till error.",
		"Undo takes the last note back."]


func round_name() -> String:
	return "Customer %d / %d"


func build_round() -> void:
	amount = rng.randi_range(12, 90) if round_i < 2 else rng.randi_range(60, 480)
	tray = []
	_layout()


func total() -> int:
	var t := 0
	for n in tray:
		t += int(n)
	return t


static func fewest(a: int) -> int:
	var n := 0
	for d in NOTES:
		n += a / d
		a = a % d
	return n


func _layout() -> void:
	UIK.clear(stage)
	var v := UIK.vbox(8)
	stage.add_child(v)
	var ask := card(Color(0.1, 0.16, 0.28), Art.C_SKY)
	var al := UIK.title(I18n.t("“I'd like to withdraw %s, please.”") % Fmt.money0(amount), 13, Art.C_WHITE)
	al.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	ask.add_child(al)
	v.add_child(ask)
	var notes := UIK.hbox(5)
	v.add_child(notes)
	for d in NOTES:
		var b := UIK.button("$%d" % d, _add.bind(d), "", 76)
		b.custom_minimum_size = Vector2(76, 34)
		b.name = "Note_%d" % d
		notes.add_child(b)
	var tray_card := card(Color(0.06, 0.1, 0.16), Color(0.3, 0.42, 0.62))
	tray_card.custom_minimum_size = Vector2(560, 44)
	var tl := UIK.wrap(I18n.t("Tray: ") + (" + ".join(tray.map(func(n): return "$%d" % n)) if not tray.is_empty() else "—"), 9, Art.C_WHITE, 540)
	tl.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	tray_card.add_child(tl)
	v.add_child(tray_card)
	var t := total()
	var col := Art.C_GREEN if t == amount else (Art.C_RED if t > amount else Art.C_GOLD)
	var tot := UIK.title(I18n.t("Counted: %s of %s") % [Fmt.money0(t), Fmt.money0(amount)], 12, col)
	tot.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	v.add_child(tot)
	var acts := UIK.hbox(6)
	v.add_child(acts)
	var u := UIK.button("Undo", _undo, "", 90)
	u.name = "Undo"
	u.disabled = tray.is_empty()
	acts.add_child(u)
	var hand := UIK.button("Hand it over", _hand, "primary", 150)
	hand.name = "HandOver"
	hand.disabled = tray.is_empty()
	acts.add_child(hand)


func _add(d: int) -> void:
	tray.append(d)
	_layout()


func _undo() -> void:
	if not tray.is_empty():
		tray.pop_back()
	_layout()


func _hand() -> void:
	if total() == amount:
		right += 1
		var best := tray.size() <= fewest(amount)
		award(1.0 if best else 0.8)
		flash(I18n.t("✓ Exact") + ("" if best else I18n.t(" (fewer notes would be tidier)")), true)
	else:
		award(0.0)
		flash(I18n.t("✗ Till error: you handed over %s") % Fmt.money0(total()), false)
	next_round()


func round_timeout() -> void:
	flash("✗ The customer asked for the manager", false)
	award(0.0)
	next_round()


func extra_result() -> Dictionary:
	return {"right": right}


func result_lines() -> Array:
	return [I18n.t("Withdrawals counted exactly: %d / %d") % [right, rounds]]
