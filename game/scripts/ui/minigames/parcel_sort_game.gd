class_name ParcelSortGame
extends MiniGame
## A shift on PostPoint's sorting belt: send each parcel to the right district bin before it slides off the belt.
## Early parcels show the district; later ones only the postcode (1xxx Riverside, 2xxx Startup Hub, ...), and halfway
## through the shift lead takes the cheat sheet away.

const BINS := [["riverside", "Riverside", 1], ["startup_hub", "Startup Hub", 2], ["civic_center", "Civic Center", 3],
	["financial", "Financial District", 4], ["shopping_street", "Shopping Street", 5]]
const SURNAMES := ["Chen", "Okafor", "Lindqvist", "Tanaka", "Moreau", "Silva", "Novak", "Haddad", "Kim", "Patel", "Reyes", "Walsh"]

var parcel := {}
var right := 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	super._init()
	title_text = "Shift — PostPoint sorting belt"
	icon_name = "parcel"
	rounds = 14
	round_time = 6.0
	rng.seed = Clock.now() * 13 + 5


func intro_lines() -> Array:
	return ["Parcels come down the belt one at a time. Send each to its district's bin: click the bin or press 1–5.",
		"Postcodes tell you the district: 1xxx Riverside, 2xxx Startup Hub, 3xxx Civic Center, 4xxx Financial District, 5xxx Shopping Street.",
		"The first parcels show the district name. Later ones only have a postcode, and halfway through the cheat sheet goes away."]


func round_name() -> String:
	return "Parcel %d / %d"


func build_round() -> void:
	var b: Array = BINS[rng.randi_range(0, BINS.size() - 1)]
	parcel = {"bin": b[0], "code": "%d%03d" % [int(b[2]), rng.randi_range(0, 999)],
		"name": "%s. %s" % [char(65 + rng.randi_range(0, 25)), SURNAMES[rng.randi_range(0, SURNAMES.size() - 1)]],
		"show_name": round_i < 4}
	round_time = maxf(3.2, 6.0 - round_i * 0.18)   # the belt speeds up
	_layout()


func _layout() -> void:
	UIK.clear(stage)
	# the parcel on the belt
	var belt := ColorRect.new()
	belt.color = Color8(46, 50, 60)
	belt.position = Vector2(0, 96)
	belt.size = Vector2(580, 22)
	stage.add_child(belt)
	for i in 12:
		var roller := ColorRect.new()
		roller.color = Color8(70, 76, 90)
		roller.position = Vector2(8 + i * 48, 100)
		roller.size = Vector2(20, 14)
		stage.add_child(roller)
	var box := card(Color8(196, 150, 96), Color8(120, 84, 48))
	box.position = Vector2(200, 8)
	box.custom_minimum_size = Vector2(180, 86)
	stage.add_child(box)
	var bv := UIK.vbox(1)
	box.add_child(bv)
	var lab := card(Color(0.98, 0.98, 0.95), Color8(90, 90, 90))
	bv.add_child(lab)
	var lv := UIK.vbox(0)
	lab.add_child(lv)
	var nm := UIK.label(str(parcel["name"]), 8, Color8(40, 40, 40), true)
	nm.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lv.add_child(nm)
	if parcel["show_name"]:
		lv.add_child(UIK.label(_bin_name(str(parcel["bin"])).to_upper(), 9, Color8(30, 30, 30), true))
	var code := UIK.title(I18n.t("AURELIA %s") % str(parcel["code"]), 12, Color8(20, 20, 20))
	code.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	lv.add_child(code)
	# the bins
	var row := UIK.hbox(6)
	row.position = Vector2(0, 128)
	stage.add_child(row)
	for i in BINS.size():
		var b: Array = BINS[i]
		var txt := "%d  %s" % [i + 1, I18n.t(str(b[1]))]
		if round_i < rounds / 2:
			txt += "\n%dxxx" % int(b[2])
		var btn := UIK.button(txt, _drop.bind(str(b[0])), "", 110)
		btn.custom_minimum_size = Vector2(110, 52)
		btn.name = "Bin_" + str(b[0])
		row.add_child(btn)
	if round_i >= rounds / 2:
		var note := UIK.label("The shift lead took the postcode sheet. From memory now!", 7, Art.C_GOLD, true)
		note.position = Vector2(0, 190)
		stage.add_child(note)


static func _bin_name(id: String) -> String:
	for b in BINS:
		if b[0] == id:
			return I18n.t(str(b[1]))
	return id


func _drop(bin: String) -> void:
	if phase != "play":
		return
	if bin == parcel["bin"]:
		right += 1
		award(0.7 + 0.3 * time_left())
		flash("✓ " + _bin_name(bin), true)
	else:
		award(0.0)
		flash(I18n.t("✗ %s belongs in %s") % [str(parcel["code"]), _bin_name(str(parcel["bin"]))], false)
	next_round()


func round_timeout() -> void:
	flash(I18n.t("✗ %s fell off the belt") % str(parcel["code"]), false)
	award(0.0)
	next_round()


func _unhandled_key_input(event: InputEvent) -> void:
	if phase != "play" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k := int((event as InputEventKey).keycode) - KEY_1
	if k >= 0 and k < BINS.size():
		get_viewport().set_input_as_handled()
		_drop(str(BINS[k][0]))


func extra_result() -> Dictionary:
	return {"right": right}


func result_lines() -> Array:
	return [I18n.t("Parcels sorted correctly: %d / %d") % [right, rounds]]
