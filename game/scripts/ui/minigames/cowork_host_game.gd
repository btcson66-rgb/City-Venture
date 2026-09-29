class_name CoworkHostGame
extends MiniGame
## A shift at Nexus Co-work's front desk: check each visitor against today's bookings. Members on the list get checked
## in, walk-ins (and anyone who says they booked but isn't on the list) buy a day pass, and meeting guests get their
## host called down.

const FIRST := ["Lena", "Eli", "Jonas", "Mara", "Theo", "Priti", "Oskar", "Yuki", "Sofia", "Ade", "Ines", "Ravi", "Hana", "Luca"]
const LAST := ["Park", "Moss", "Reed", "Varga", "Blake", "Shah", "Lund", "Ito", "Costa", "Bello", "Duarte", "Nair", "Sato", "Ricci"]
const HOSTS := ["Priya", "Tom", "Ken", "Elena"]

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
	if a == v["answer"]:
		right += 1
		award(0.75 + 0.25 * time_left())
		flash(I18n.t("✓ %s is sorted") % str(v["name"]), true)
	else:
		award(0.0)
		var why := {"checkin": "they were on the list: check them in", "daypass": "they weren't on the list: sell a day pass",
			"host": "they came for a meeting: call the host"}
		flash(I18n.t("✗ No: %s") % I18n.t(why[str(v["answer"])]), false)
	next_round()


func round_timeout() -> void:
	flash("✗ The queue is getting long", false)
	award(0.0)
	next_round()


func extra_result() -> Dictionary:
	return {"right": right}


func result_lines() -> Array:
	return [I18n.t("Visitors handled correctly: %d / %d") % [right, rounds]]
