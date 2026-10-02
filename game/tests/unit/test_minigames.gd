extends RefCounted
## Hands-on work: shifts pay by how they went, photos and packing quality follow the product, every help key exists,
## and time can't be skipped.

var runner


func test_shift_pay_follows_the_score() -> void:
	var full := Careers.shift_pay("barista")
	runner.check(absf(Careers.pay_for("barista", 1.0) - full) < 0.01, "a perfect shift pays the full wage")
	runner.check(absf(Careers.pay_for("barista", 0.0) - full * 0.6) < 0.01, "60% is guaranteed")


func test_a_bad_shift_pays_less_and_does_not_count_toward_promotion() -> void:
	Careers.hire("barista")
	while not (Clock.hour() == 9):
		Clock.advance(60)
	var r := Careers.work_shift("barista", 0.2, 0.0)
	runner.check(r["ok"], "shift worked")
	runner.check(not r["counted"], "a 20% shift doesn't count toward promotion")
	runner.eq(Careers.shifts("barista"), 0, "no promotion progress")
	Clock.advance(24 * 60)
	while not (Clock.hour() == 9):
		Clock.advance(60)
	var cash := Ledger.cash("player")
	var r2 := Careers.work_shift("barista", 1.0, 3.0)
	runner.check(r2["counted"], "a good shift counts")
	runner.check(absf(Ledger.cash("player") - cash - (Careers.shift_pay("barista") + 3.0)) < 0.01, "full pay plus tips")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_your_own_photos_move_demand() -> void:
	var l := {"photo": "self", "photo_q": 1.0}
	runner.check(absf(Ecommerce.photo_factor(l) - 1.1) < 0.001, "a great shoot beats the default")
	l["photo_q"] = 0.0
	runner.check(absf(Ecommerce.photo_factor(l) - 0.7) < 0.001, "a bad one costs sales")
	runner.check(Ecommerce.photo_factor({"photo": "studio"}) > 1.1, "studio photos stay the best")


func test_photo_shoot_rates_the_setup() -> void:
	var g := PhotoShootGame.new("desk_lamp")
	g.backdrop = "wood"
	g.light = "window"
	g.zoom = 5.0
	g.pos = PhotoShootGame.FRAME / 2.0 - Vector2(40, 40)
	var good: float = g.rate(1.0)["score"]
	runner.check(good >= 0.85, "suitable backdrop, soft light, well framed, sharp (%.2f)" % good)
	g.light = "ceiling"
	g.pos = Vector2(-60, 20)
	var bad: float = g.rate(0.2)["score"]
	runner.check(bad < 0.5, "harsh light, cut off, blurry (%.2f)" % bad)
	g.free()


func test_pack_quality_follows_the_order() -> void:
	var loc := "riverside_studio"
	Ecommerce._add_stock(loc, "phone_stand", 5, 2.0, 0.0)
	var o := {"id": "T1", "product": "phone_stand", "qty": 1, "status": "placed", "location": loc, "entity": "player", "customer": "Rin Tanaka",
		"unit_price": 14.0, "placed": Clock.now()}
	GameState.data["ecommerce"]["orders"]["T1"] = o
	var n := Ecommerce.pack_orders(loc, -1, {"T1": {"q": 0.4, "label_ok": false}})
	runner.eq(n, 1, "packed")
	runner.check(absf(float(o["pack_q"]) - 0.4) < 0.001, "pack quality kept on the order")
	runner.check(not bool(o["label_ok"]), "wrong label kept on the order")


func test_barista_orders_follow_the_house_rules() -> void:
	var g := BaristaGame.new()
	for i in 60:
		g.rng.seed = i
		g.round_i = 0
		g.stage = Control.new()
		g.build_round()
		runner.check(g.order_text().contains(BaristaGame._name(BaristaGame.SHOTS, str(g.want["shots"]))), "every ticket states its shot count, including flat white")
		if g.want["drink"] == "americano":
			runner.check(g.want["milk"] == "none", "americano without milk")
		if g.want["drink"] == "flat_white":
			runner.check(g.want["shots"] == "2", "flat white is a double")
		g.stage.free()
	g.free()


func test_teller_counts_the_fewest_notes() -> void:
	runner.eq(TellerCashGame.fewest(187), 7, "$187 = 100 + 50 + 20 + 10 + 5 + 1 + 1")
	runner.eq(TellerCashGame.fewest(40), 2, "$40 = 20 + 20")


func test_typing_output_scales_with_the_score() -> void:
	var g := TypingGame.new("saas", "salon_booking", 2.0)
	runner.check(g.lines.size() >= 2, "a snippet on screen")
	runner.check(g.rounds >= 1 and g.rounds <= TypingGame.MAX_LINES, "only a couple of lines to type (%d)" % g.rounds)
	for i in 40:
		var pick := TypingGame.pick_lines(g.lines)
		var n := 0
		for k in pick:
			n += str(g.lines[k]).strip_edges().length()
		runner.check(pick.size() == 1 or n <= TypingGame.MAX_CHARS, "short enough to stay a game (%d chars)" % n)
	g.points = float(g.rounds)
	runner.check(absf(float(g.extra_result()["hours"]) - 2.5) < 0.01, "perfect typing: 1.25x the session")
	g.points = 0.0
	runner.check(absf(float(g.extra_result()["hours"]) - 1.0) < 0.01, "worst case: half the session")
	g.free()


func test_every_screen_help_key_has_a_card() -> void:
	for f in DirAccess.get_files_at("res://scripts/ui/modals"):
		if not f.ends_with(".gd"):
			continue
		var src := FileAccess.get_file_as_string("res://scripts/ui/modals/" + f)
		var i := src.find("help_key = \"")
		while i >= 0:
			var key := src.substr(i + 12, src.find("\"", i + 12) - i - 12)
			if not key.ends_with("_"):   # "os_" + tab: the Company OS tabs are checked below
				runner.check(Help.has(key), "%s: help card '%s' exists" % [f, key])
			i = src.find("help_key = \"", i + 1)
	for t in ["overview", "operations", "sales", "inventory", "finance", "people", "contracts", "freelance", "saas"]:
		runner.check(Help.has("os_" + t), "Company OS tab %s has a help card" % t)


func test_tutorial_steps_are_well_formed() -> void:
	var ids := {}
	for s in Tutorial.STEPS:
		runner.check(str(s.get("title", "")) != "" and str(s.get("text", "")) != "", "%s has a title and instructions" % s["id"])
		runner.check(str(s.get("done", "")) != "", "%s knows when it's done" % s["id"])
		runner.check(not ids.has(s["id"]), "%s is unique" % s["id"])
		ids[s["id"]] = true
		var tg: Dictionary = s.get("target", {})
		if tg.has("building"):
			runner.check(DataDB.buildings.has(tg["building"]), "%s points at a real building" % s["id"])
		if s.has("hints"):
			runner.eq(s["hints"].size(), s.get("ui", []).size(), "%s has one coach line per highlighted button" % s["id"])
	runner.eq(Tutorial.coach_hint(Tutorial.STEPS[8], 2), "Open Operations", "the coach names the button it frames")
	var tut := Tutorial.new()
	runner.check(tut.is_active(), "a new game starts the guided first venture")
	runner.check(not tut.step_done(Tutorial.STEPS[8]), "buying stock isn't done at the start")
	tut.free()


func test_no_way_to_skip_time() -> void:
	runner.check(not ("fast_forward" in Clock), "the clock has no fast-forward")
	runner.check(not InputMap.has_action("fast_forward"), "no fast-forward key")


func test_the_guided_first_venture_has_no_waits() -> void:
	GameState.data["tutorial"] = {"step": 8, "seen": {}, "off": false, "v": Tutorial.VERSION}
	runner.check(Tutorial.first_venture_active(), "a new player is on the guided first venture")
	var r := Ecommerce.buy("tradelink_wholesale", "phone_stand", 80)
	runner.check(r["ok"], "first stock bought")
	runner.eq(int(GameState.stat("stock_received")), 1, "and delivered on the spot")
	# the first parcel crosses town in minutes, not days
	var loc := Ecommerce.default_stock_location()
	var o := {"id": "F1", "product": "phone_stand", "qty": 1, "status": "carried", "location": loc, "entity": "player",
		"customer": "Rin T.", "unit_price": 14.0, "placed": Clock.now(), "ship": {"method": "economy", "cost": 4.0, "mode": "dropoff"}}
	GameState.data["ecommerce"]["orders"]["F1"] = o
	Ecommerce._ship(o)
	runner.check(int(o["ship"]["eta"]) - Clock.now() <= 40, "the first delivery is quick")
	# after the guided venture, stock takes its normal time again
	GameState.data["tutorial"]["step"] = Tutorial.STEPS.size()
	runner.check(not Tutorial.first_venture_active(), "the guided venture is over")
	var r2 := Ecommerce.buy("tradelink_wholesale", "phone_stand", 80)
	runner.check(int(r2["eta"]) - Clock.now() >= 12 * 60, "later stock takes its time")
	runner.eq(int(GameState.stat("stock_received")), 1, "not delivered yet")


func test_a_continued_first_venture_never_waits_on_stock() -> void:
	# an older save: stock bought under the old rules (two days away), tutorial from a previous version
	Ecommerce.buy("tradelink_wholesale", "phone_stand", 80)
	GameState.data["tutorial"] = {"step": 11, "seen": {}, "off": false, "v": 2}
	var tut := Tutorial.new()
	runner.eq(str(tut.current()["id"]), "buy", "a returning player resumes at buying stock, not back at reception")
	tut.st()["step"] = Tutorial._index("shoot")
	runner.eq(int(GameState.stat("stock_received")), 0, "the old order is still on the road")
	tut._rush_stock(3.0)
	runner.eq(int(GameState.stat("stock_received")), 1, "it turns up early instead of making them wait")
	runner.check(GameState.data["messages"].any(func(m): return m["from"] == "ken"), "with a note from the supplier")
	tut.free()


func test_you_can_sleep_after_a_shift() -> void:
	GameState.data["tutorial"] = {"step": 99, "seen": {}, "off": true, "v": Tutorial.VERSION}
	while Clock.hour() != 14:
		Clock.advance(30)
	runner.check(not SleepModal.can_sleep(), "not at 2 PM on a day off")
	Careers.hire("barista")
	while Clock.hour() != 9:
		Clock.advance(60)
	Careers.work_shift("barista", 1.0)
	runner.check(SleepModal.can_sleep(), "but yes after a shift (%s)" % Clock.fmt_time())
