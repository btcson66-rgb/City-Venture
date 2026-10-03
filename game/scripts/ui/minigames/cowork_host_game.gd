class_name CoworkHostGame
extends MiniGame
## A shift at Nexus Co-work's front desk: check each visitor against today's bookings. Members on the list get checked
## in, walk-ins (and anyone who says they booked but isn't on the list) buy a day pass, and meeting guests get their
## host called down.

const FIRST := ["Lena", "Eli", "Jonas", "Mara", "Theo", "Priti", "Oskar", "Yuki", "Sofia", "Ade", "Ines", "Ravi", "Hana", "Luca"]
const LAST := ["Park", "Moss", "Reed", "Varga", "Blake", "Shah", "Lund", "Ito", "Costa", "Bello", "Duarte", "Nair", "Sato", "Ricci"]
const HOSTS := ["Priya", "Tom", "Ken", "Elena"]

var service_stage := "visitor"
var visitor_quality := 0.0
var rooms := {"A_9": "Elena", "B_10": "Ken"}

var bookings: Array = []      # [{name, plan}]
var visitors: Array = []      # [{name, says, answer}]
var right := 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	super._init()
	title_text = "Shift — Nexus Co-work front desk"
	icon_name = "people"
	rounds = 7
	round_time = 22.0
	rng.seed = Clock.now() * 17 + 3
	_plan_day()


func intro_lines() -> Array:
	return ["Visitors come to the desk one by one. Today's bookings are on your clipboard.",
		"On the list? Check them in. Not on the list, or asking to work here today? Sell a day pass ($15).",
		"Here to meet someone? Call their host down. Careful: some people say they booked when they didn't."]


func round_name() -> String:
	return "Visitor %d / %d"


func _person() -> String:
	return "%s %s" % [FIRST[rng.randi_range(0, FIRST.size() - 1)], LAST[rng.randi_range(0, LAST.size() - 1)]]


func _plan_day() -> void:
	var used := {}
	while bookings.size() < 6:
		var n := _person()
		if not used.has(n):
			used[n] = true
			bookings.append({"name": n, "plan": ["Desk plan", "Day pass (paid online)"][rng.randi_range(0, 1)]})
	var kinds := ["member", "member", "member", "walkin", "claim", "meeting", "meeting"]
	kinds.shuffle()
	for k in kinds:
		match k:
			"member":
				var b: Dictionary = bookings[rng.randi_range(0, bookings.size() - 1)]
				visitors.append({"name": b["name"], "says": I18n.t("Morning! %s, I booked for today.") % b["name"], "answer": "checkin"})
			"walkin":
				var n2 := _person()
				visitors.append({"name": n2, "says": I18n.t("Hi, can I work here today? I'm %s.") % n2, "answer": "daypass"})
			"claim":
				var n3 := _person()
				while used.has(n3):
					n3 = _person()
				visitors.append({"name": n3, "says": I18n.t("%s, I have a desk plan. Pretty sure.") % n3, "answer": "daypass"})
			"meeting":
				var n4 := _person()
				var host: String = HOSTS[rng.randi_range(0, HOSTS.size() - 1)]
				visitors.append({"name": n4, "says": I18n.t("Hello, I'm %s. I'm here to meet %s.") % [n4, host], "answer": "host"})


func build_round() -> void:
	service_stage = "visitor"
	_layout()

func _layout() -> void:
	if service_stage == "room":
		UIK.clear(stage)
		var room_panel := UIK.vbox(8)
		stage.add_child(room_panel)
		room_panel.add_child(UIK.wrap("The visitor also needs a one-hour meeting room. Resolve the booking conflict.", 10, Art.C_WHITE, 540))
		var hour := 9 + round_i / 2
		for slot in ["A_%d" % hour, "A_%d" % (hour + 1), "B_%d" % hour, "B_%d" % (hour + 1)]:
			room_panel.add_child(UIK.label(I18n.t("Room %s · %02d:00–%02d:00 · %s") % [slot.split("_")[0], int(slot.split("_")[1]), int(slot.split("_")[1]) + 1, I18n.t("Occupied" if rooms.has(slot) else "Available")], 9))
			var choose := UIK.button("Reserve this slot", _room.bind(slot))
			choose.name = "Room_" + slot
			room_panel.add_child(choose)
		return
	UIK.clear(stage)
	var h := UIK.hbox(12)
	stage.add_child(h)
	# clipboard
	var clip := card(Color(0.96, 0.95, 0.9), Color8(120, 110, 90))
	clip.custom_minimum_size = Vector2(230, 200)
	h.add_child(clip)
	var cv := UIK.vbox(2)
	clip.add_child(cv)
	cv.add_child(UIK.label("TODAY'S BOOKINGS", 7, Color8(90, 80, 60), true))
	for b in bookings:
		var row := UIK.hbox(4)
		var nm := UIK.label(str(b["name"]), 8, Color8(30, 30, 30), true)
		nm.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		nm.custom_minimum_size = Vector2(100, 0)
		row.add_child(nm)
		row.add_child(UIK.label(str(b["plan"]), 7, Color8(80, 80, 80)))
		cv.add_child(row)
	# the visitor
	var v: Dictionary = visitors[round_i]
	var right_col := UIK.vbox(8)
	h.add_child(right_col)
	var bubble := card(Color(0.1, 0.16, 0.28), Art.C_SKY)
	bubble.custom_minimum_size = Vector2(320, 0)
	var said := UIK.wrap("“%s”" % str(v["says"]), 10, Art.C_WHITE, 300)
	said.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	bubble.add_child(said)
	right_col.add_child(bubble)
	for a in [["checkin", "Check in"], ["daypass", "Sell a day pass ($15)"], ["host", "Call their host"]]:
		var b2 := UIK.button(str(a[1]), _answer.bind(str(a[0])), "", 220)
		b2.name = "Desk_" + str(a[0])
		right_col.add_child(b2)


func _answer(a: String) -> void:
	if phase != "play":
		return
	var v: Dictionary = visitors[round_i]
	visitor_quality = 1.0 if a == v["answer"] else 0.0
	service_stage = "room"
	_layout()

func _room(slot: String) -> void:
	if service_stage != "room": return
	if rooms.has(slot):
		flash("✗ Already booked. Offer a free room or another hour.", false)
		return
	rooms[slot] = visitors[round_i]["name"]
	var quality := visitor_quality * 0.6 + 0.4
	if quality >= 0.99: right += 1
	award(quality)
	next_round()


func round_timeout() -> void:
	flash("✗ The queue is getting long", false)
	award(0.0)
	next_round()


func extra_result() -> Dictionary:
	return {"right": right}


func result_lines() -> Array:
	return [I18n.t("Visitors handled correctly: %d / %d") % [right, rounds]]
