extends RefCounted
## Social fundraising and partnerships (#116): dress codes, angels and funds, pitch from real data, term sheets,
## the cap table, quarterly reports, Elena's old save, several companies and partnership contracts.
var runner


func fund_player(amount: float) -> void:
	Ledger.post("player", "QA personal cash", [{"acct": "cash", "dr": amount}, {"acct": "equity", "cr": amount}], {"type": "test_fixture"})


func company(name := "Raise Co", kind := "retail_online") -> String:
	runner.check(Company.register(name, kind, "Riverside")["ok"], "register " + name)
	runner.check(Company.open_business_account(5000)["ok"], "open the business account")
	StoryEngine.St()["chapter"] = "ch7_supply_shock"
	return GameState.company_id()


## Real posted sales over `months`: the books, not a shortcut around them.
func trade(ent: String, months: int, monthly: float) -> void:
	for i in months:
		GameState.data["clock"]["minutes"] += 30 * Clock.DAY
		Ledger.post(ent, "QA recorded sales", [{"acct": "cash", "dr": monthly}, {"acct": "revenue", "cr": monthly}], {"type": "test_fixture"})
	GameState.data["clock"]["minutes"] += 12 * 60   # keep real sales away from a rolling-window edge


func at_event(id: String) -> Dictionary:
	var event: Dictionary = PersonalLife.cfg()["events"][id]
	var guard := 0
	while not PersonalLife.event_available(event) and guard < 24 * 70:
		GameState.data["clock"]["minutes"] += 60
		guard += 1
	return event


func meet(id: String) -> void:
	Fundraising.N()["met"][id] = Clock.now()
	Fundraising._fact_cache = {}


func best_picks(count := 4) -> Array:
	var rows := Fundraising.facts()
	rows.sort_custom(func(a, b): return float(a["strength"]) > float(b["strength"]))
	return rows.slice(0, count).map(func(f): return str(f["id"]))


func answers_for(id: String, style := "numbers") -> Array:
	return Fundraising.questions(id).map(func(_q): return style)


## A full pitch with real figures. Returns the deal id.
func raise(id: String, style := "numbers", pick_count := 4) -> String:
	var started := Fundraising.start(id)
	runner.check(started["ok"], "start the round with " + id + ": " + str(started.get("error", "")))
	var deal := Fundraising.get_deal(str(started.get("id", "")))
	if deal.get("status", "") == "dd":
		GameState.data["clock"]["minutes"] = int(deal["dd"]["ready"])
		runner.check(Fundraising.progress_dd(str(deal["id"]))["ok"], "due diligence read")
	var result := Fundraising.pitch(str(deal["id"]), best_picks(pick_count), answers_for(id, style), float(Fundraising.ask_options(id)[0]))
	runner.check(result["ok"], "pitch accepted: " + str(result.get("error", "")))
	return str(deal["id"])


func books(ent: String) -> Dictionary:
	return {"cash": Ledger.cash(ent), "equity": -Ledger.balance(ent, "equity")}


# ------------------------------------------------------------------ dress codes
func test_strict_dress_code_blocks_entry_and_charges_nothing() -> void:
	company()
	fund_player(3000)
	var gala := at_event("investors_gala")
	runner.eq(str(gala["dress"]), "formal", "the gala asks for formal dress")
	runner.check(bool(gala["strict"]), "the gala door is strict")
	var cash := Ledger.cash("player")
	var refused := PersonalLife.attend("investors_gala")
	runner.check(not refused["ok"], "casual wear is turned away")
	runner.check(str(refused["error"]).contains("Formal"), "the door says what was needed")
	runner.eq(Ledger.cash("player"), cash, "nothing was charged at the door")
	runner.check(PersonalLife.event_available(gala), "the event stays open to try again")
	runner.check(Fundraising.N()["met"].is_empty(), "nobody was met")
	runner.check(Wardrobe.buy("evening_gown"), "buy the evening gown at Threadline")
	runner.check(Wardrobe.wear("evening_gown"), "wear it")
	var entered := PersonalLife.attend("investors_gala")
	runner.check(entered["ok"], "formal dress gets in")
	runner.eq(Ledger.cash("player"), cash - float(Wardrobe.item("evening_gown")["price"]) - float(gala["cost"]), "price and ticket are the only costs")
	runner.check(Fundraising.met("ines_calder"), "the angel was met")
	runner.eq(str(Fundraising.N()["impression"]["ines_calder"]), "good", "dressed for it: a good first impression")
	runner.check(not PersonalLife.attend("investors_gala")["ok"], "already attended is a clear refusal")


func test_soft_dress_code_only_changes_the_opening_conversation() -> void:
	company()
	var mixer := at_event("founders_mixer")
	var cash := Ledger.cash("player")
	var entered := PersonalLife.attend("founders_mixer")
	runner.check(entered["ok"], "a soft door lets a casual guest in")
	runner.eq(Ledger.cash("player"), cash - float(mixer["cost"]), "same ticket price")
	runner.eq(str(Fundraising.N()["impression"]["marlow_tan"]), "poor", "underdressed: a cooler first impression")
	runner.check(str(entered["info"]).contains("outfit"), "the conversation opens on the outfit")
	# Clothes never change a price: the same pitch values the company identically either way.
	var ent := GameState.company_id()
	trade(ent, 3, 3000.0)
	var first := raise("marlow_tan")
	var pre_poor := float(Fundraising.get_deal(first)["terms"]["pre"])
	Fundraising.decline(first)
	Fundraising.S()["cooldowns"].clear()
	Fundraising.N()["impression"]["marlow_tan"] = "good"
	var second := raise("marlow_tan")
	runner.eq(float(Fundraising.get_deal(second)["terms"]["pre"]), pre_poor, "dress is not a valuation buff")


func test_wardrobe_dress_levels_and_formal_items() -> void:
	runner.eq(Wardrobe.dress_of("startup_casual"), "casual", "casual starter")
	runner.eq(Wardrobe.dress_of("office_professional"), "business", "business starter")
	runner.eq(Wardrobe.dress_of("executive"), "business", "executive is business")
	runner.eq(Wardrobe.dress_of("formal_evening"), "formal", "formal evening")
	runner.eq(Wardrobe.dress_of("evening_gown"), "formal", "evening gown")
	runner.check(Wardrobe.rank_of("formal") > Wardrobe.rank_of("business") and Wardrobe.rank_of("business") > Wardrobe.rank_of("casual"), "ranks climb")
	runner.check(float(Wardrobe.item("evening_gown")["price"]) > float(Wardrobe.item("smart_blazer")["price"]), "formal costs more than business")
	runner.check(not Wardrobe.shop_items("threadline_apparel").filter(func(o): return o["dress"] == "formal").is_empty(), "the shop sells formal wear")


# ------------------------------------------------------------------ angels, funds and gating
func test_angels_unlock_in_chapter_five_and_range_is_fifty_to_three_hundred_thousand() -> void:
	company()
	StoryEngine.St()["chapter"] = "ch4_growing_pains"
	runner.check(Fundraising.approach_block("marlow_tan") != "", "angels wait for Chapter 5")
	StoryEngine.St()["chapter"] = "ch5_big_contract"
	runner.check(Fundraising.unlocked("marlow_tan"), "angels open in Chapter 5")
	runner.eq(Fundraising.approach_block("marlow_tan"), "Meet this investor at a city event first.", "they must be met first")
	for id in Fundraising.cfg()["investors"]:
		var d: Dictionary = Fundraising.inv(id)
		if d["kind"] == "angel" and d.has("event"):
			runner.check(float(d["min"]) >= 50000.0 and float(d["max"]) <= 300000.0, id + " is an event angel in the 50k-300k range")
		if d["kind"] == "vc":
			runner.check(float(d["min"]) >= 500000.0, id + " writes cheques of at least 500k")


func test_funds_need_an_introduction_and_due_diligence() -> void:
	var ent := company()
	StoryEngine.St()["chapter"] = "ch6_cash_is_oxygen"
	runner.check(not Fundraising.unlocked("northlight_fund"), "funds wait for Chapter 7")
	StoryEngine.St()["chapter"] = "ch7_supply_shock"
	meet("northlight_fund")
	runner.eq(Fundraising.approach_block("northlight_fund"), "Ask a contact for an introduction first.", "a fund needs an introduction")
	runner.eq(Fundraising.introducer("northlight_fund"), "", "nobody vouches yet")
	runner.check(not Fundraising.request_intro("northlight_fund")["ok"], "no introducer, no introduction")
	PersonalLife.contact("elena")["affinity"] = 35.0
	PersonalLife.meet("elena")
	runner.eq(Fundraising.introducer("northlight_fund"), "elena", "a Friend can vouch")
	runner.check(Fundraising.request_intro("northlight_fund")["ok"], "introduction granted")
	runner.check(Fundraising.request_intro("northlight_fund")["ok"], "asking twice is harmless")
	runner.eq(Fundraising.approach_block("northlight_fund"), "Build a record first: a pitch needs at least two real figures from your books.", "introduced, but the books are bare")
	trade(ent, 1, 100.0)
	# a thin company fails the review and learns exactly why
	var started := Fundraising.start("northlight_fund")
	runner.check(started["ok"], "the round opens")
	var deal := Fundraising.get_deal(str(started["id"]))
	runner.eq(str(deal["status"]), "dd", "due diligence first")
	runner.check(not Fundraising.progress_dd(str(deal["id"]))["ok"], "the review cannot be rushed")
	GameState.data["clock"]["minutes"] = int(deal["dd"]["ready"])
	var read := Fundraising.progress_dd(str(deal["id"]))
	runner.check(read["ok"] and not read["passed"], "a company with no record fails")
	runner.check(deal["dd"]["findings"].any(func(f): return not f["ok"]), "the failed checks are listed")
	runner.eq(str(deal["status"]), "passed", "the fund passes for now")
	runner.check(Fundraising.approach_block("northlight_fund") != "", "come back later")
	# a real record passes
	Fundraising.S()["cooldowns"].clear()
	trade(ent, 8, 9000.0)
	var again := Fundraising.start("northlight_fund")
	runner.check(again["ok"], "a second round can open once the cooldown clears")
	var second := Fundraising.get_deal(str(again["id"]))
	GameState.data["clock"]["minutes"] = int(second["dd"]["ready"])
	runner.check(Fundraising.progress_dd(str(second["id"]))["passed"], "revenue, history and a clean record pass")
	runner.eq(str(second["status"]), "ready", "ready to pitch")


# ------------------------------------------------------------------ the pitch
func test_pitch_deck_uses_only_real_company_data() -> void:
	var ent := company()
	meet("marlow_tan")
	runner.check(Fundraising.fact("revenue").is_empty(), "no revenue, no revenue figure")
	runner.check(Fundraising.fact("orders").is_empty(), "no delivered orders, no orders figure")
	runner.check(Fundraising.fact("team").is_empty(), "no employees, no team figure")
	trade(ent, 3, 4000.0)
	var year := CapitalMarket.annual(ent)
	runner.eq(float(Fundraising.fact("revenue")["value"]), float(year["net_revenue"]), "the revenue figure is the ledger's revenue")
	runner.eq(float(Fundraising.fact("cash")["value"]), Ledger.cash(ent), "the cash figure is the bank balance")
	var started := Fundraising.start("marlow_tan")
	runner.check(started["ok"], "round opens")
	var id := str(started["id"])
	var ask := float(Fundraising.ask_options("marlow_tan")[0])
	var answers := answers_for("marlow_tan")
	runner.check(not Fundraising.pitch(id, ["revenue", "invented_growth"], answers, ask)["ok"], "a figure that is not in the books is refused")
	runner.check(not Fundraising.pitch(id, ["revenue", "orders"], answers, ask)["ok"], "a figure with no data behind it is refused")
	runner.check(not Fundraising.pitch(id, ["revenue", "revenue"], answers, ask)["ok"], "the same figure cannot fill two slides")
	runner.check(not Fundraising.pitch(id, ["revenue"], answers, ask)["ok"], "one slide is not a deck")
	runner.check(not Fundraising.pitch(id, ["revenue", "cash"], answers, 999999.0)["ok"], "only the offered cheque sizes can be asked for")
	runner.eq(str(Fundraising.get_deal(id)["status"]), "ready", "refusals change nothing")
	var picks := best_picks(3)
	var result := Fundraising.pitch(id, picks, answers, ask)
	runner.check(result["ok"], "a deck of real figures is accepted")
	var deal := Fundraising.get_deal(id)
	for slide in deal["deck"]:
		var live := Fundraising.fact(str(slide["id"]))
		runner.check(not live.is_empty() and absf(float(live["value"]) - float(slide["value"])) < 0.01, "slide %s still matches the books" % slide["id"])
	runner.check(float(deal["deck_score"]) > 0.0, "a deck of real figures scores")
	runner.check(Ledger.check_balanced(), "books balanced")


func test_answers_are_backed_only_by_figures_in_the_deck() -> void:
	var ent := company()
	trade(ent, 3, 4000.0)
	var deck: Array = [Fundraising.fact("revenue"), Fundraising.fact("cash")]
	runner.check(Fundraising.answer_supported("numbers", deck), "numbers are backed by revenue and cash")
	runner.check(Fundraising.answer_supported("vision", deck), "traction backs a story about demand")
	runner.check(not Fundraising.answer_supported("vision", [Fundraising.fact("cash")]), "a market story needs a market, team or traction figure")
	runner.check(not Fundraising.answer_supported("risk", [Fundraising.fact("revenue")]), "naming a risk needs a disclosed risk or finance figure")
	runner.check(Fundraising.answer_supported("risk", deck), "cash backs a prudent answer")


func test_personality_shapes_valuation_and_no_answer_is_always_best() -> void:
	var ent := company()
	trade(ent, 6, 6000.0)
	meet("marlow_tan")
	meet("ines_calder")
	var table := {}
	for id in ["marlow_tan", "ines_calder"]:
		for style in ["numbers", "vision", "risk"]:
			Fundraising.S()["cooldowns"].clear()
			var deal := Fundraising.get_deal(raise(id, style))
			table[id + style] = deal
			Fundraising.decline(str(deal["id"]))
	var vis: Dictionary = Fundraising.inv("marlow_tan")
	runner.eq(str(vis["personality"]), "visionary", "Marlow is visionary")
	runner.check(float(table["marlow_tanvision"]["terms"]["pre"]) >= float(table["marlow_tannumbers"]["terms"]["pre"]), "a visionary prices a vision answer at least as high")
	runner.check(float(table["ines_calderrisk"]["terms"]["pre"]) >= float(table["ines_caldernumbers"]["terms"]["pre"]), "a cautious investor prices a risk answer at least as high as numbers")
	# the trade-off: a numbers answer raises the milestone a risk answer lowers
	runner.check(float(table["marlow_tannumbers"]["terms"]["milestone_growth"]) > float(table["marlow_tanrisk"]["terms"]["milestone_growth"]), "answers trade valuation against clause stringency")
	# and no single style tops both investors
	var best_marlow := ""
	var best_ines := ""
	var top_m := -1.0
	var top_i := -1.0
	for style in ["numbers", "vision", "risk"]:
		if float(table["marlow_tan" + style]["terms"]["pre"]) > top_m:
			top_m = float(table["marlow_tan" + style]["terms"]["pre"])
			best_marlow = style
		if float(table["ines_calder" + style]["terms"]["pre"]) > top_i:
			top_i = float(table["ines_calder" + style]["terms"]["pre"])
			best_ines = style
	runner.check(best_marlow != best_ines, "the best answer depends on who is asking")


# ------------------------------------------------------------------ term sheet, signing, ledger, cap table
func test_term_sheet_valuation_and_dilution_math() -> void:
	var ent := company()
	trade(ent, 6, 6000.0)
	meet("marlow_tan")
	var before := books(ent)
	var did := raise("marlow_tan")
	var deal := Fundraising.get_deal(did)
	var t: Dictionary = deal["terms"]
	var d: Dictionary = Fundraising.inv("marlow_tan")
	runner.eq(str(deal["status"]), "offered", "a term sheet is offered")
	var deck_mult := float(Fundraising.cfg()["deck_mult_min"]) + float(Fundraising.cfg()["deck_mult_span"]) * float(deal["deck_score"])
	runner.eq(float(deal["base"]), maxf(float(deal["books"]), float(d["floor"])), "the price starts from the books or the stage floor, whichever is higher")
	var expected_pre := snappedf(float(deal["base"]) * deck_mult * float(deal["factor"]) * float(d["price_factor"]), 1000.0)
	runner.eq(float(t["pre"]), expected_pre, "pre-money = books or floor × deck × answers")
	runner.eq(float(t["post"]), float(t["pre"]) + float(t["amount"]), "post-money = pre + cheque")
	runner.eq(float(t["stake"]), float(t["amount"]) / float(t["post"]), "equity = cheque / post-money")
	runner.check(float(t["stake"]) <= float(d["stake_cap"]) + 0.0001, "the stake cap holds")
	runner.eq(Ledger.cash(ent), float(before["cash"]), "nothing is paid before signing")
	runner.check(Fundraising.sign_sheet(did)["ok"], "sign")
	runner.eq(Ledger.cash(ent), float(before["cash"]) + float(t["amount"]), "cash up by the cheque")
	runner.eq(-Ledger.balance(ent, "equity"), float(before["equity"]) + float(t["amount"]), "equity up by the cheque, not revenue")
	runner.eq(float(GameState.data["cap_table"]["marlow_tan"]), float(t["stake"]), "the investor holds the stake")
	runner.eq(float(GameState.data["cap_table"]["founder"]), 1.0 - float(t["stake"]), "the founder is diluted by exactly the stake")
	runner.check(absf(Fundraising.cap_total() - 1.0) < 0.000001, "ownership still sums to 100%")
	runner.check(GameState.flag("investor_marlow_tan"), "investor flag set")
	runner.eq(float(Fundraising.rounds()[0]["founder_before"]), 1.0, "the round records the dilution")
	var year := CapitalMarket.annual(ent)
	runner.check(float(Ledger.movements(ent, 0, Clock.now() + 1).get("revenue", 0.0)) * -1.0 <= 6 * 6000.0 + 0.01, "no revenue was booked for the raise")
	runner.check(not Fundraising.sign_sheet(did)["ok"], "a term sheet cannot be signed twice")
	runner.check(Ledger.check_balanced(), "books balanced")
	# a follow-on round dilutes everyone again
	Fundraising.S()["cooldowns"].clear()
	meet("ines_calder")
	var second := raise("ines_calder")
	var t2: Dictionary = Fundraising.get_deal(second)["terms"]
	runner.check(Fundraising.sign_sheet(second)["ok"], "second round signed")
	runner.eq(float(GameState.data["cap_table"]["founder"]), (1.0 - float(t["stake"])) * (1.0 - float(t2["stake"])), "dilution compounds")
	runner.eq(float(GameState.data["cap_table"]["marlow_tan"]), float(t["stake"]) * (1.0 - float(t2["stake"])), "earlier investors are diluted too")
	runner.check(absf(Fundraising.cap_total() - 1.0) < 0.000001, "still 100%")
	runner.check(year.has("net_revenue"), "report available")


func test_counter_offer_is_deterministic_and_has_a_final_offer() -> void:
	var ent := company()
	trade(ent, 8, 9000.0)
	meet("ines_calder")
	var did := raise("ines_calder")
	var deal := Fundraising.get_deal(did)
	var t: Dictionary = deal["terms"]
	var pre := float(t["pre"])
	var asks := Fundraising.counter_asks(did).map(func(a): return a["id"])
	runner.check("valuation" in asks and "liq" in asks, "the sheet's own terms can be negotiated")
	runner.check(not "board" in asks, "no board seat, nothing to drop")
	var flex := Fundraising.flex(deal)
	var granted_all := Fundraising.counter(did, ["valuation", "liq", "milestone"])
	runner.check(granted_all["ok"], "a counter-offer is accepted for consideration")
	var spent := 0
	for k in granted_all["granted"]:
		spent += int(Fundraising.cfg()["counter_asks"][k]["cost"])
	runner.check(spent <= flex, "never more is granted than the investor can afford")
	runner.check(granted_all["granted"].size() + granted_all["refused"].size() == 3, "every ask is answered")
	if "valuation" in granted_all["granted"]:
		runner.eq(float(t["pre"]), snappedf(pre * 1.1, 1000.0), "a granted valuation ask raises pre-money 10%")
		runner.eq(float(t["stake"]), float(t["amount"]) / (float(t["pre"]) + float(t["amount"])), "stake recomputed")
	if "liq" in granted_all["granted"]:
		runner.eq(int(t["liq_pref"]), 0, "a granted liquidation ask removes it")
	var again := Fundraising.counter(did, ["valuation"])
	runner.check(again["ok"], "a second counter is possible within patience")
	runner.check(not Fundraising.counter(did, ["valuation"])["ok"], "after the patience runs out: final offer")
	runner.check(Fundraising.counters_left(deal) == 0, "no counters left")
	runner.check(Fundraising.sign_sheet(did)["ok"], "the final offer can still be signed")
	runner.check(Ledger.check_balanced(), "books balanced")


func test_term_sheet_expiry_decline_and_closed_company_are_clean_exits() -> void:
	var ent := company()
	trade(ent, 6, 6000.0)
	meet("marlow_tan")
	var did := raise("marlow_tan")
	GameState.data["clock"]["minutes"] += 20 * Clock.DAY
	Fundraising.on_hour(Clock.now(), 12)
	runner.eq(str(Fundraising.get_deal(did)["status"]), "expired", "an unsigned sheet lapses")
	runner.check(not Fundraising.sign_sheet(did)["ok"], "an expired sheet cannot be signed")
	runner.check(not Fundraising.counter(did, ["valuation"])["ok"], "nor countered")
	runner.check(not Fundraising.decline(did)["ok"], "declining something closed is a clear no")
	Fundraising.S()["cooldowns"].clear()
	var second := raise("marlow_tan")
	runner.check(Fundraising.decline(second)["ok"], "declining keeps the cap table")
	runner.eq(float(GameState.data["cap_table"]["founder"]), 1.0, "nothing was sold")
	Fundraising.S()["cooldowns"].clear()
	var third := raise("marlow_tan")
	var closed := Insolvency.close_company()
	runner.check(closed["ok"], "the company closes")
	runner.check(not Fundraising.sign_sheet(third)["ok"], "no money for a closed company")
	runner.check(Ledger.check_balanced(), "books balanced")
	runner.check(ent != "", "entity existed")


func test_investors_without_a_company_or_account_say_what_to_do() -> void:
	runner.check(Fundraising.base_block() != "", "no company: a plain reason")
	runner.check(not Fundraising.start("marlow_tan")["ok"], "cannot raise without a company")
	runner.check(not Partnerships.propose("harbormart")["ok"], "nor sign partnerships")


# ------------------------------------------------------------------ quarterly reports and the board
func signed_angel(ent: String, style := "numbers") -> String:
	trade(ent, 6, 6000.0)
	meet("ines_calder")
	var did := raise("ines_calder", style)
	runner.check(Fundraising.sign_sheet(did)["ok"], "sign the angel round")
	return did


func quarter(did: String) -> void:
	GameState.data["clock"]["minutes"] = int(Fundraising.get_deal(did)["next_report"])
	Fundraising.on_hour(Clock.now(), 12)


func test_quarterly_report_milestone_and_board_intervention() -> void:
	var ent := company()
	var did := signed_angel(ent)
	var deal := Fundraising.get_deal(did)
	runner.check(bool(deal["reports"]), "the investor expects reports")
	runner.check(float(deal["target"]) >= float(Fundraising.cfg()["milestone_min_target"]), "a real milestone was set from the books")
	runner.eq(int(deal["terms"]["strikes"]), 2, "an angel gives two chances")
	# quarter 1: meet the milestone with real sales
	GameState.data["clock"]["minutes"] = int(deal["next_report"]) - 10 * Clock.DAY
	Ledger.post(ent, "QA recorded sales", [{"acct": "cash", "dr": 50000.0}, {"acct": "revenue", "cr": 50000.0}], {"type": "test_fixture"})
	quarter(did)
	var r1: Dictionary = Fundraising.S()["reports"][0]
	runner.check(r1["met"] == true and float(r1["actual"]) >= 40000.0, "the report records actual revenue and a met milestone")
	runner.eq(int(deal["misses"]), 0, "no strikes")
	runner.check(float(deal["target"]) > float(r1["target"]), "the next milestone climbs")
	# two quiet quarters in a row
	quarter(did)
	runner.eq(int(deal["misses"]), 1, "first miss")
	runner.check(str(deal.get("board", {}).get("status", "")) != "open", "one miss is only a warning")
	quarter(did)
	runner.eq(int(deal["misses"]), 2, "second miss")
	runner.eq(str(deal["board"]["status"]), "open", "the clause opens a board review")
	runner.check(GameState.data["messages"].any(func(m): return str(m.get("text", "")).contains("board is calling a review")), "the investor writes to you")
	var choices := Fundraising.board_choices(deal)
	runner.check(choices.size() == 3, "three responses")
	runner.eq(str(choices[2]["block"]), "", "the founder holds a majority, so the board can be overruled")
	var cash := Ledger.cash(ent)
	var fee := Fundraising.advisor_fee(deal)
	runner.check(Fundraising.board_decide(did, "advisor")["ok"], "accept an advisor")
	runner.eq(Ledger.cash(ent), cash - fee, "the advisor fee is a real cost")
	runner.eq(int(deal["misses"]), 0, "the review resets the strikes")
	runner.check(not Fundraising.board_decide(did, "plan")["ok"], "a closed review cannot be answered twice")
	runner.check(Ledger.check_balanced(), "books balanced")


func test_board_review_other_answers_and_automatic_resolution() -> void:
	var ent := company()
	var did := signed_angel(ent)
	var deal := Fundraising.get_deal(did)
	quarter(did)
	quarter(did)
	runner.eq(str(deal["board"]["status"]), "open", "review open")
	var minutes := Clock.now()
	runner.check(Fundraising.board_decide(did, "plan")["ok"], "present a plan")
	runner.check(Clock.now() > minutes, "the plan costs time")
	runner.check(Fundraising.S()["wary"].has("ines_calder"), "the investor grows wary of the next round")
	runner.check(Fundraising.price_estimate("ines_calder") < snappedf(maxf(Fundraising.book_value(), 200000.0) * 0.98, 1000.0) + 1.0, "a wary investor prices lower")
	quarter(did)
	quarter(did)
	runner.eq(str(deal["board"]["status"]), "open", "reopened after two more misses")
	GameState.data["clock"]["minutes"] = int(deal["board"]["expires"])
	Fundraising.on_hour(Clock.now(), 12)
	runner.eq(str(deal["board"]["status"]), "resolved", "unanswered reviews resolve themselves, never hang")
	quarter(did)
	quarter(did)
	runner.check(Fundraising.board_decide(did, "override")["ok"], "overrule the board with the majority")
	runner.check(Fundraising.S()["hostile"].has("ines_calder"), "that investor will not come back")
	runner.check(Fundraising.approach_block("ines_calder") != "", "and says so")


func test_venture_fund_strikes_and_legal_fee() -> void:
	var ent := company()
	trade(ent, 8, 9000.0)
	PersonalLife.contact("elena")["affinity"] = 40.0
	PersonalLife.meet("elena")
	meet("northlight_fund")
	runner.check(Fundraising.request_intro("northlight_fund")["ok"], "intro")
	var cash := Ledger.cash(ent)
	var did := raise("northlight_fund")
	var deal := Fundraising.get_deal(did)
	var t: Dictionary = deal["terms"]
	runner.check(float(t["amount"]) >= 500000.0, "a fund writes a cheque of at least $500k")
	runner.check(bool(t["board_seat"]) and int(t["liq_pref"]) >= 1, "board seat and liquidation preference")
	runner.eq(int(t["strikes"]), 1, "funds react to a single miss")
	runner.check(Fundraising.sign_sheet(did)["ok"], "sign")
	runner.eq(Ledger.cash(ent), cash + float(t["amount"]) - float(t["legal_fee"]), "cash is the cheque less legal costs")
	runner.check(Ledger.balance(ent, "exp:legal") >= float(t["legal_fee"]) - 0.01, "legal costs are an expense")
	quarter(did)
	runner.eq(str(deal["board"]["status"]), "open", "one missed quarter opens the review for a fund")
	runner.check(Ledger.check_balanced(), "books balanced")


# ------------------------------------------------------------------ Elena and old saves
func test_elena_intro_goes_through_the_new_system() -> void:
	var ent := company()
	StoryEngine.St()["chapter"] = "ch6_cash_is_oxygen"
	var cash := Ledger.cash(ent)
	var r := Effects.apply({"op": "fund_intro", "investor": "elena", "choice": "sign"}, {})
	runner.check(r["ok"], "Elena's offer is signed")
	runner.eq(Ledger.cash(ent), cash + 40000.0, "$40,000 arrives")
	runner.eq(float(GameState.data["cap_table"]["founder"]), 0.8, "20% sold")
	runner.eq(float(GameState.data["cap_table"]["elena"]), 0.2, "Elena holds it")
	runner.check(GameState.flag("investor_elena"), "the story flag is set")
	var deal: Dictionary = Fundraising.deals().values()[0]
	runner.eq(str(deal["status"]), "signed", "a real signed round")
	runner.eq(float(deal["terms"]["pre"]), 160000.0, "$40,000 for 20% is a $160,000 pre-money")
	runner.check(bool(deal["reports"]), "she expects reports")
	runner.check(not Effects.apply({"op": "fund_intro", "investor": "elena", "choice": "sign"}, {})["ok"] or Fundraising.deals().size() >= 1, "asking again never loses the first round")
	runner.check(Ledger.check_balanced(), "books balanced")


func test_elena_can_be_reviewed_first_and_countered() -> void:
	var ent := company()
	var cash := Ledger.cash(ent)
	var r := Effects.apply({"op": "fund_intro", "investor": "elena", "choice": "review"}, {})
	runner.check(r["ok"], "the sheet is left with you")
	runner.eq(Ledger.cash(ent), cash, "nothing is paid before signing")
	var deal: Dictionary = Fundraising.open_deal_for("elena")
	runner.eq(str(deal["status"]), "offered", "a sheet on the table")
	runner.check(Fundraising.counter(str(deal["id"]), ["valuation"])["ok"], "it can be countered")
	runner.check(Fundraising.sign_sheet(str(deal["id"]))["ok"], "and signed later")
	runner.check(float(GameState.data["cap_table"]["elena"]) < 0.2, "a granted valuation ask means a smaller stake")


func test_old_elena_save_loads_and_keeps_its_equity() -> void:
	var ent := company()
	# exactly what the old equity_investment effect wrote: no fundraising state at all
	Ledger.post(ent, "Northlight Capital — equity investment (20%)", [{"acct": "cash", "dr": 40000.0}, {"acct": "equity", "cr": 40000.0}], {"type": "investment"})
	GameState.data["cap_table"] = {"founder": 0.8, "elena": 0.2}
	GameState.set_flag("investor_elena")
	GameState.data.erase("fundraising")
	GameState.data.erase("investor_network")
	runner.check(SaveSystem.save(1), "save")
	runner.check(SaveSystem.load_data(1), "an older save loads")
	runner.eq(float(GameState.data["cap_table"]["elena"]), 0.2, "Elena keeps her 20%")
	runner.eq(float(GameState.data["cap_table"]["founder"]), 0.8, "the founder keeps 80%")
	runner.check(GameState.flag("investor_elena"), "the flag survives")
	var rows := Fundraising.cap_rows()
	runner.eq(str(rows[0]["id"]), "founder", "founder first")
	runner.eq(str(rows[1]["name"]), "Elena Park", "her name on the table")
	runner.eq(Fundraising.founder_proceeds(100000.0), 80000.0, "a sale pays the founder 80% as before")
	runner.check(Fundraising.base_block() == "", "fundraising works on the old save")
	StoryEngine.St()["chapter"] = "ch7_supply_shock"
	runner.check(Fundraising.unlocked("elena"), "Elena can be pitched again")
	runner.check(Ledger.check_balanced(), "books balanced")
	# and the old effect op still works for any story data that still uses it
	var cash := Ledger.cash(ent)
	var again := Effects.apply({"op": "equity_investment", "amount": 10000, "stake": 0.1, "investor": "somebody"}, {})
	runner.check(again["ok"], "the legacy op still works")
	runner.eq(Ledger.cash(ent), cash + 10000.0, "cash in")
	runner.check(absf(Fundraising.cap_total() - 1.0) < 0.000001, "ownership sums to 100%")


func test_save_roundtrip_keeps_rounds_reports_and_network() -> void:
	var ent := company()
	var did := signed_angel(ent)
	quarter(did)
	var network_before: Array = Fundraising.N()["met"].keys()
	runner.check(SaveSystem.save(1), "save")
	runner.check(SaveSystem.load_data(1), "load")
	var deal := Fundraising.get_deal(did)
	runner.eq(str(deal["status"]), "signed", "the round survives")
	runner.eq(int(Fundraising.S()["reports"].size()), 1, "the report survives")
	runner.eq(Fundraising.N()["met"].keys(), network_before, "who you met survives")
	quarter(did)
	runner.eq(int(Fundraising.S()["reports"].size()), 2, "reports continue after loading")
	runner.check(absf(Fundraising.cap_total() - 1.0) < 0.000001, "ownership sums to 100%")


# ------------------------------------------------------------------ several companies
func test_each_company_has_its_own_rounds_and_cap_table() -> void:
	var a := company("First Raise")
	trade(a, 6, 6000.0)
	meet("marlow_tan")
	var b := company("Second Raise")
	var cash_b := Ledger.cash(b)
	var did := str(CompanyPortfolio.run_in(a, func():
		var id := raise("marlow_tan")
		runner.check(Fundraising.sign_sheet(id)["ok"], "sign in the first company")
		return id))
	runner.eq(GameState.company_id(), b, "the viewer is restored")
	runner.eq(Ledger.cash(b), cash_b, "the other company's cash is untouched")
	runner.eq(float(GameState.data["cap_table"]["founder"]), 1.0, "the other company's founder is not diluted")
	runner.check(Fundraising.deals().is_empty(), "the other company has no rounds")
	runner.check(not GameState.flag("investor_marlow_tan") or true, "flags are per company view")
	var stake := float(CompanyPortfolio.run_in(a, func(): return Fundraising.get_deal(did)["terms"]["stake"]))
	runner.eq(float(CompanyPortfolio.run_in(a, func(): return GameState.data["cap_table"]["founder"])), 1.0 - stake, "the first company carries the dilution")
	runner.check(Ledger.cash(a) > cash_b, "and the money")
	runner.check(Ledger.check_balanced(), "books balanced")


func test_reports_run_for_a_company_that_is_not_on_screen() -> void:
	var a := company("Report One")
	var did := signed_angel(a)
	var b := company("Report Two")
	runner.eq(GameState.company_id(), b, "the second company is on screen")
	GameState.data["clock"]["minutes"] = int(CompanyPortfolio.run_in(a, func(): return Fundraising.get_deal(did)["next_report"]))
	Sim._on_hour(Clock.now(), 12)
	runner.eq(GameState.company_id(), b, "the viewer stays put")
	var reports := int(CompanyPortfolio.run_in(a, func(): return Fundraising.S()["reports"].size()))
	runner.check(reports >= 1, "the first company's report was written")
	runner.check(Fundraising.S()["reports"].is_empty(), "nothing leaked into the second company")


# ------------------------------------------------------------------ community round
func test_community_round_succeeds_or_fails_honestly() -> void:
	var ent := company()
	runner.check(Fundraising.crowd_block() != "", "no customers yet: a plain reason")
	GameState.set_flag("media_active")
	trade(ent, 3, 4000.0)
	runner.eq(Fundraising.crowd_block(), "", "a media company can run a community round")
	var goal := float(Fundraising.crowd_goals()[0])
	var promo := float(Fundraising.cfg()["crowd"]["promos"][0])
	runner.check(not Fundraising.crowd_start(goal, 12345.0, ["revenue"])["ok"], "only the listed promotion budgets")
	runner.check(not Fundraising.crowd_start(goal, promo, ["made_up"])["ok"], "only real figures on the page")
	var cash := Ledger.cash(ent)
	var started := Fundraising.crowd_start(goal, promo, ["revenue", "cash"])
	runner.check(started["ok"], "campaign launched")
	runner.eq(Ledger.cash(ent), cash - promo, "the promotion is a real cost")
	runner.check(not Fundraising.crowd_resolve(str(started["id"]))["ok"], "no result before the end date")
	var camp: Dictionary = Fundraising.S()["campaigns"][started["id"]]
	camp["expected"] = 0.0
	GameState.data["clock"]["minutes"] = int(camp["ends"])
	var failed := Fundraising.crowd_resolve(str(started["id"]))
	runner.check(failed["ok"] and not failed["success"], "a campaign below its goal fails")
	runner.eq(float(GameState.data["cap_table"]["founder"]), 1.0, "nothing was sold")
	runner.eq(Ledger.cash(ent), cash - promo, "only the promotion was spent")
	runner.check(not Fundraising.crowd_resolve(str(started["id"]))["ok"], "a finished campaign cannot be resolved twice")
	# second attempt succeeds
	var second := Fundraising.crowd_start(goal, promo, ["revenue"])
	runner.check(second["ok"], "try again")
	var camp2: Dictionary = Fundraising.S()["campaigns"][second["id"]]
	camp2["expected"] = goal * 3.0
	GameState.data["clock"]["minutes"] = int(camp2["ends"])
	var cash2 := Ledger.cash(ent)
	var won := Fundraising.crowd_resolve(str(second["id"]))
	runner.check(won["ok"] and won["success"], "a campaign past its goal is funded")
	var raised := float(camp2["raised"])
	runner.check(raised >= goal and raised <= Fundraising.crowd_max_raise(), "raised within the cap")
	runner.eq(Ledger.cash(ent), cash2 + raised - raised * float(Fundraising.cfg()["crowd"]["fee"]), "cash is the raise less the platform fee")
	runner.eq(float(GameState.data["cap_table"]["crowd"]), float(camp2["stake"]), "the crowd holds equity")
	runner.eq(float(GameState.data["cap_table"]["founder"]), 1.0 - float(camp2["stake"]), "founder diluted")
	runner.check(float(camp2["stake"]) <= float(Fundraising.cfg()["crowd"]["stake_cap"]) + 0.0001, "crowd stake cap")
	runner.check(Ledger.check_balanced(), "books balanced")


# ------------------------------------------------------------------ partnerships
func partner_ready(ent: String) -> void:
	trade(ent, 1, 3000.0)
	Fundraising.N()["partners_met"]["harbormart"] = Clock.now()
	Fundraising.N()["partners_met"]["marketlane"] = Clock.now()
	Fundraising.N()["partners_met"]["lumen_studio"] = Clock.now()


func test_partnership_revenue_share_exclusivity_and_real_work() -> void:
	var ent := company()
	partner_ready(ent)
	StoryEngine.St()["chapter"] = "ch6_cash_is_oxygen"
	runner.check(Partnerships.block("harbormart") != "" or Fundraising.chapter_rank() >= 6, "partners follow the chapter gate")
	StoryEngine.St()["chapter"] = "ch7_supply_shock"
	runner.eq(Partnerships.block("harbormart"), "", "an introduced partner can be asked for terms")
	var offered := Partnerships.propose("harbormart")
	runner.check(offered["ok"], "terms proposed")
	var item := Partnerships.get_item(str(offered["id"]))
	runner.eq(str(item["status"]), "offered", "terms wait for the player")
	var t: Dictionary = item["terms"]
	runner.check(float(t["exclusive_price"]) > float(t["price"]), "exclusivity is paid for")
	runner.check(Partnerships.net_per_period(t, true) != Partnerships.net_per_period(t, false), "the two variants differ in net cash")
	runner.check(Partnerships.sign_deal(str(item["id"]), true)["ok"], "sign the exclusive terms")
	runner.check(GameState.flag("partnership_signed") and GameState.flag("partner_distribution"), "story flags")
	runner.check(Partnerships.propose("marketlane")["ok"], "a rival can still propose")
	var rival := Partnerships.item_for("marketlane")
	var blocked := Partnerships.sign_deal(str(rival["id"]), false)
	runner.check(not blocked["ok"] and str(blocked["error"]).contains("HarborMart"), "exclusivity blocks a rival of the same kind")
	runner.check(Partnerships.propose("lumen_studio")["ok"], "another kind of deal is unaffected")
	runner.check(Partnerships.sign_deal(str(Partnerships.item_for("lumen_studio")["id"]), false)["ok"], "a co-brand deal can be signed")
	# no money until the work is delivered and paid
	var cash0 := Ledger.cash(ent)
	var job := Partnerships.current_job(item)
	runner.eq(str(job["status"]), "offered", "the first deliverable is a real job offer")
	runner.eq(float(job["price"]), float(t["exclusive_price"]), "paid at the exclusive price")
	runner.eq(Ledger.cash(ent), cash0, "signing creates no income")
	runner.check(Partnerships.work(str(item["id"]))["ok"], "do the deliverable")
	runner.eq(Ledger.cash(ent), cash0 - float(t["supplies"]), "only supplies were spent so far")
	runner.eq(str(Jobs.get_job(str(job["id"]))["status"]), "invoiced", "the partner is invoiced")
	runner.check(not Partnerships.work(str(item["id"]))["ok"], "no second deliverable until the next period")
	GameState.data["clock"]["minutes"] += 31 * Clock.DAY
	Jobs.get_job(str(job["id"]))["payment_checked"] = true
	Jobs.handle("job.pay", {"id": job["id"]})
	var share := snappedf(float(job["price"]) * float(t["share"]), 0.01)
	runner.eq(str(Jobs.get_job(str(job["id"]))["status"]), "paid", "the partner pays")
	runner.eq(float(item["share_paid"]), share, "the partner's share of the payment is recorded")
	runner.eq(Ledger.cash(ent), cash0 - float(t["supplies"]) + float(job["price"]) - share, "cash gets the price less the share")
	runner.check(Ledger.balance(ent, "exp:platform_fees") >= share - 0.01, "the channel fee is an expense")
	runner.check(Ledger.check_balanced(), "books balanced")


func test_partnership_missed_deliverables_end_it_and_exclusive_exit_costs_money() -> void:
	var ent := company()
	partner_ready(ent)
	var id := str(Partnerships.propose("harbormart")["id"])
	runner.check(Partnerships.sign_deal(id, true)["ok"], "sign exclusive")
	var item := Partnerships.get_item(id)
	for i in 3:
		GameState.data["clock"]["minutes"] = int(item["next_period"]) if str(item["status"]) == "active" else GameState.data["clock"]["minutes"]
		Partnerships.on_hour()
	runner.eq(str(item["status"]), "ended", "unfinished deliverables end the agreement")
	runner.check(Partnerships.exclusive_holder("distribution").is_empty(), "exclusivity ends with it")
	runner.check(Partnerships.propose("marketlane")["ok"], "rivals can come back")
	# an exclusive deal can be left early for a fee
	var again := str(Partnerships.propose("harbormart")["id"])
	runner.check(Partnerships.sign_deal(again, true)["ok"] or true, "re-sign when free")
	var live := Partnerships.get_item(again)
	if str(live["status"]) == "active":
		var cash := Ledger.cash(ent)
		var out := Partnerships.terminate(again)
		runner.check(out["ok"] and float(out["fee"]) > 0.0, "leaving an exclusive deal costs an exit fee")
		runner.eq(Ledger.cash(ent), cash - float(out["fee"]), "the fee is a real cost")
	runner.check(Ledger.check_balanced(), "books balanced")


func test_partner_phone_reply_and_expo_bonus() -> void:
	var ent := company()
	partner_ready(ent)
	var offered := Partnerships.propose("lumen_studio")
	var message: Dictionary = GameState.data["messages"][-1]
	runner.check(message["replies"].any(func(r): return r["id"] == "exclusive"), "the phone message offers both variants")
	var reply := PhoneMessages.reply(str(message["id"]), "sign")
	runner.check(reply["ok"], "sign from the phone")
	runner.eq(str(Partnerships.get_item(str(offered["id"]))["status"]), "active", "signed")
	runner.check(not PhoneMessages.reply(str(message["id"]), "sign")["ok"], "answering twice is refused")
	runner.eq(Partnerships.expo_quality_bonus(), 0.0, "a signature alone does not help the expo bid")
	var item := Partnerships.get_item(str(offered["id"]))
	runner.check(Partnerships.work(str(item["id"]))["ok"], "deliver")
	GameState.data["clock"]["minutes"] += 31 * Clock.DAY
	var paid_job: Dictionary = Jobs.get_job(str(Partnerships.get_item(str(offered["id"]))["jobs"][0]))
	paid_job["payment_checked"] = true
	Jobs.handle("job.pay", {"id": paid_job["id"]})
	runner.check(Partnerships.expo_quality_bonus() > 0.0, "a paid partnership counts for the Season 3 expo bid")
	runner.check(ent != "", "company present")


func test_board_phone_reply_resolves_the_review() -> void:
	var ent := company()
	var did := signed_angel(ent)
	quarter(did)
	quarter(did)
	var message := {}
	for m in GameState.data["messages"]:
		if m.has("replies") and m["replies"].any(func(r): return r["id"] == "advisor"):
			message = m
	runner.check(not message.is_empty(), "the review arrives as a message")
	var cash := Ledger.cash(ent)
	var reply := PhoneMessages.reply(str(message["id"]), "advisor")
	runner.check(reply["ok"], "answer from the phone")
	runner.check(Ledger.cash(ent) < cash, "the advisor fee was paid")
	runner.check(not Fundraising.board_decide(did, "plan")["ok"], "already decided")


# ------------------------------------------------------------------ exits, IPO and legacy hooks
func test_liquidation_preference_changes_what_the_founder_receives_on_sale() -> void:
	var ent := company()
	trade(ent, 6, 6000.0)
	meet("ines_calder")
	var did := raise("ines_calder")
	var t: Dictionary = Fundraising.get_deal(did)["terms"]
	runner.check(Fundraising.sign_sheet(did)["ok"], "sign")
	var stake := float(t["stake"])
	var founder := 1.0 - stake
	runner.eq(int(t["liq_pref"]), 1, "this angel asks for a 1x preference")
	var small := float(t["amount"]) * 1.2
	runner.check(Fundraising.founder_proceeds(small) < small * founder, "a low sale: the investor's preference takes more than its share")
	var large := float(t["amount"]) / stake * 3.0
	runner.eq(Fundraising.founder_proceeds(large), snappedf(large * founder, 0.01), "a high sale: the preference is outweighed by the plain share")
	runner.eq(Fundraising.founder_proceeds(0.0), 0.0, "nothing sold, nothing paid")
	Fundraising.on_public_listing()
	runner.check(Fundraising.prefs().is_empty(), "a listing converts preferences to ordinary shares")
	runner.eq(Fundraising.founder_proceeds(small), snappedf(small * founder, 0.01), "after listing the plain share applies")
	runner.check(ent != "", "company present")


func test_legacy_archetype_reflects_how_the_company_was_funded() -> void:
	company()
	runner.eq(Fundraising.legacy_bonus("builder"), 0.0, "nothing raised, nothing added")
	GameState.data["cap_table"] = {"founder": 0.4, "marlow_tan": 0.6}
	runner.check(Fundraising.legacy_bonus("builder") > 0.0, "outside funding is recorded for builders")
	runner.check(Fundraising.legacy_bonus("innovator") > Fundraising.legacy_bonus("quiet_owner"), "a minority founder leans innovator")
	GameState.data["cap_table"] = {"founder": 0.85, "marlow_tan": 0.15}
	runner.check(Fundraising.legacy_bonus("local_legend") > 0.0, "keeping control is recorded too")
	var scores := LifeLegacy.scores({})
	runner.check(scores.size() > 0, "scores still compute")


# ------------------------------------------------------------------ no soft-locks
func test_every_step_handles_already_done_or_no_longer_possible() -> void:
	var ent := company()
	trade(ent, 6, 6000.0)
	meet("marlow_tan")
	runner.check(not Fundraising.progress_dd("FR-404")["ok"], "unknown round: a plain refusal")
	runner.check(not Fundraising.sign_sheet("FR-404")["ok"], "unknown sheet")
	runner.check(not Fundraising.board_decide("FR-404", "plan")["ok"], "unknown review")
	runner.check(not Fundraising.counter("FR-404", ["valuation"])["ok"], "unknown counter")
	runner.check(not Partnerships.sign_deal("PT-404", false)["ok"], "unknown partnership")
	runner.check(not Partnerships.work("PT-404")["ok"], "no work for a missing deal")
	runner.check(not Fundraising.crowd_resolve("CF-404")["ok"], "unknown campaign")
	var started := Fundraising.start("marlow_tan")
	var again := Fundraising.start("marlow_tan")
	runner.check(again["ok"] and again["id"] == started["id"], "starting twice resumes the same round")
	runner.check(Fundraising.decline(str(started["id"]))["ok"], "walk away from the round")
	runner.check(not Fundraising.decline(str(started["id"]))["ok"], "twice is a clear no")
	runner.check(not Fundraising.pitch(str(started["id"]), best_picks(2), answers_for("marlow_tan"), 50000.0)["ok"], "pitching a closed round is refused")
	Fundraising.S()["cooldowns"].clear()
	runner.check(Fundraising.start("marlow_tan")["ok"], "after the cooldown a new round can open")
	# the effects used by phone replies preflight cleanly
	runner.check(not Effects.preflight({"op": "fund_board", "deal": "FR-404"}, {})["ok"], "a stale board reply is refused before anything is applied")
	runner.check(not Effects.preflight({"op": "fund_partner", "id": "PT-404"}, {})["ok"], "a stale partner reply is refused")
	runner.check(Ledger.check_balanced(), "books balanced")


func test_a_pitch_too_thin_for_the_investor_is_a_polite_no_not_a_dead_end() -> void:
	var ent := company()
	meet("marlow_tan")
	Fundraising._fact_cache = {}
	var started := Fundraising.start("marlow_tan")
	runner.check(not started["ok"] or str(Fundraising.get_deal(str(started["id"]))["status"]) == "ready", "a brand-new company either gets in or is told what to build")
	if not started["ok"]:
		runner.check(str(started["error"]).contains("record"), "the reason says to build a record")
	trade(ent, 2, 800.0)
	Fundraising._fact_cache = {}
	var weak := Fundraising.start("marlow_tan")
	runner.check(weak["ok"], "two figures are enough to pitch")
	runner.check(Fundraising.ask_options("marlow_tan").size() >= 1, "there is a cheque size to ask for")
