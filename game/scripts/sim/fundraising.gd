class_name Fundraising
extends RefCounted
## Social fundraising (#116). Angels are met at events; venture funds need an introduction and due diligence.
## A pitch deck is built only from facts read off the company's own books, so nothing can be invented.
## Money raised is equity: cash in, equity up, every holder diluted. It is never revenue (R4).
## State: GameState.data["fundraising"] (per company, see holding_groups.json) and the player-level
## GameState.data["investor_network"] (who the player has met and who introduced them).

static func cfg() -> Dictionary:
	return DataDB.economy["fundraising"]
static func inv(id: String) -> Dictionary:
	return cfg()["investors"].get(id, {})
static func error(text: String) -> Dictionary:
	return {"ok": false, "error": I18n.t(text)}
static func S() -> Dictionary:
	if not GameState.data.has("fundraising"):
		GameState.data["fundraising"] = {}
	var s: Dictionary = GameState.data["fundraising"]
	for key in {"seq": 1, "deals": {}, "rounds": [], "reports": [], "campaigns": {}, "hostile": {}, "wary": {}, "cooldowns": {}, "partnerships": {}, "pseq": 1}:
		if not s.has(key):
			var fresh = {"seq": 1, "deals": {}, "rounds": [], "reports": [], "campaigns": {}, "hostile": {}, "wary": {}, "cooldowns": {}, "partnerships": {}, "pseq": 1}[key]
			s[key] = fresh.duplicate(true) if fresh is Dictionary or fresh is Array else fresh
	return s
static func N() -> Dictionary:
	if not GameState.data.has("investor_network"):
		GameState.data["investor_network"] = {}
	var n: Dictionary = GameState.data["investor_network"]
	for key in ["met", "impression", "intro", "partners_met"]:
		if not n.has(key):
			n[key] = {}
	return n
static func has_state() -> bool:
	return GameState.data.has("fundraising")
static func deals() -> Dictionary:
	return S()["deals"]
static func get_deal(id: String) -> Dictionary:
	return S()["deals"].get(id, {})
static func name_of(id: String) -> String:
	if inv(id).has("name"):
		return I18n.t(str(inv(id)["name"]))
	return PhoneMessages.contact_name(id)
static func is_open(deal: Dictionary) -> bool:
	return str(deal.get("status", "")) in ["dd", "ready", "offered"]

# ------------------------------------------------------------------ gating
static func chapter_rank() -> int:
	var ids: Array = StoryEngine.chapters().map(func(c): return str(c["id"]))
	var rank: int = ids.find(str(StoryEngine.St().get("chapter", "")))
	for done in StoryEngine.St().get("chapters_done", []):
		rank = maxi(rank, ids.find(str(done)) + 1)
	return rank
static func base_block() -> String:
	var ent := GameState.company_id()
	if ent == "" or not GlobalMarket.live(ent) or not GameState.flag("business_account_opened"):
		return "Register a company and open its business account before raising money."
	if Acquisition.sold() or float(GameState.data.get("cap_table", {"founder": 1.0}).get("founder", 1.0)) <= 0.0:
		return "The founder shares have already been sold. There is nothing left to raise against."
	return ""
static func unlocked(id: String) -> bool:
	var kind := str(inv(id).get("kind", ""))
	if kind == "angel":
		return chapter_rank() >= int(cfg()["min_chapter_angel"]) or GameState.flag("investor_" + id) or GameState.data.get("cap_table", {}).has(id)
	return chapter_rank() >= int(cfg()["min_chapter_vc"])
static func unlock_text(id: String) -> String:
	return I18n.t("Angels open up from Chapter 5.") if str(inv(id).get("kind", "")) == "angel" else I18n.t("Venture funds open up from Chapter 7.")
static func met(id: String) -> bool:
	var npc := str(inv(id).get("npc", ""))
	return N()["met"].has(id) or (npc != "" and PersonalLife.known(npc))
## Who vouches for a venture fund: a contact who has reached Friend, or an angel who already backed the company.
static func introducer(id: String) -> String:
	for who in inv(id).get("introducers", []):
		if GameState.data.get("cap_table", {}).has(str(who)):
			return str(who)
		if DataDB.npc(str(who)).has("relationship") and PersonalLife.known(str(who)) and PersonalLife.stage(str(who)) >= 1:
			return str(who)
	return ""
static func introduced(id: String) -> bool:
	return N()["intro"].has(id)
static func open_deal_for(id: String) -> Dictionary:
	for deal in S()["deals"].values():
		if deal["investor"] == id and is_open(deal):
			return deal
	return {}
## "" when the player can start (or resume) a round with this investor, else the reason.
static func approach_block(id: String) -> String:
	if not inv(id).has("kind"):
		return "Choose an investor."
	if not open_deal_for(id).is_empty():
		return ""
	var why := base_block()
	if why != "":
		return why
	if not unlocked(id):
		return unlock_text(id)
	if not met(id):
		return "Meet this investor at a city event first."
	if str(inv(id)["kind"]) == "vc" and not introduced(id):
		return "Ask a contact for an introduction first."
	if S()["hostile"].has(id):
		return "This investor will not back you again after you overruled their board."
	if Clock.now() < int(S()["cooldowns"].get(id, 0)):
		return "This investor asked you to come back later. Check the date on the card."
	if facts().size() < int(cfg()["min_facts"]):
		return "Build a record first: a pitch needs at least two real figures from your books."
	return ""

# ------------------------------------------------------------------ introductions and events
static func request_intro(vc: String) -> Dictionary:
	if str(inv(vc).get("kind", "")) != "vc":
		return error("Choose a venture fund.")
	if introduced(vc):
		return {"ok": true, "already": true}
	var why := base_block()
	if why != "":
		return error(why)
	if not unlocked(vc):
		return error(unlock_text(vc))
	var who := introducer(vc)
	if who == "":
		return error("Nobody you know can vouch for this fund yet. Build trust with a contact, or bring an angel on board.")
	PersonalLife.work(int(cfg()["intro_minutes"]))
	Clock.advance(int(cfg()["intro_minutes"]))
	N()["intro"][vc] = {"from": who, "t": Clock.now()}
	if PersonalLife.stories().has(who):
		PersonalLife.note_kind(who, "intro")
	GameState.timeline(I18n.t("%s introduced you to %s.") % [name_of(who), name_of(vc)], "company")
	return {"ok": true, "from": who}
## Called by PersonalLife.attend. Dress decides entry, and only the opening of the conversation.
static func dress_check(event: Dictionary) -> Dictionary:
	var need := str(event.get("dress", ""))
	if need == "":
		return {"ok": true, "impression": "neutral", "need": "", "wearing": ""}
	var ranks := Wardrobe.dress_rank(Wardrobe.wearing())
	var needed := Wardrobe.rank_of(need)
	if ranks >= needed:
		return {"ok": true, "impression": "good", "need": need, "wearing": Wardrobe.dress_of(Wardrobe.wearing())}
	if bool(event.get("strict", false)):
		return {"ok": false, "error": I18n.t("The door staff turn you away: this event asks for %s dress and you are wearing %s. Change outfit in your wardrobe, or buy something at Threadline on Shopping Street.") % [dress_name(need), dress_name(Wardrobe.dress_of(Wardrobe.wearing()))], "need": need}
	return {"ok": true, "impression": "poor", "need": need, "wearing": Wardrobe.dress_of(Wardrobe.wearing())}
static func dress_name(level: String) -> String:
	for d in cfg()["dress_levels"]:
		if d["id"] == level:
			return I18n.t(str(d["label"]))
	return level
static func impression_line(who: String, impression: String) -> String:
	match impression:
		"good":
			return I18n.t("%s greets you warmly: you look the part.") % who
		"poor":
			return I18n.t("%s glances at your outfit and is cool at first, then gives you a hearing anyway.") % who
	return I18n.t("%s nods and carries on the conversation.") % who
## Returns the translated sentence listing whom the player met at the event ("" when nobody new).
static func on_event(event: Dictionary, gate: Dictionary) -> String:
	var lines: Array = []
	for id in event.get("investors", []):
		if inv(str(id)).is_empty():
			continue
		N()["met"][id] = Clock.now()
		N()["impression"][id] = str(gate.get("impression", "neutral"))
		lines.append(impression_line(name_of(str(id)), str(gate.get("impression", "neutral"))))
	for id in event.get("partners", []):
		var partner: Dictionary = cfg()["partners"].get(str(id), {})
		if partner.is_empty():
			continue
		N()["partners_met"][id] = Clock.now()
		N()["impression"][id] = str(gate.get("impression", "neutral"))
		lines.append(impression_line(I18n.t(str(partner["name"])), str(gate.get("impression", "neutral"))))
	return " ".join(lines)

# ------------------------------------------------------------------ the books: facts, value, due diligence
static func _fact(id: String, value: float, text: String) -> Dictionary:
	var def: Dictionary = cfg()["facts"][id]
	var risk: bool = str(def["category"]) == "risk"
	var strength := float(cfg()["risk_strength"]) if risk else clampf(value / maxf(0.0001, float(def["bench"])), 0.0, 1.0)
	return {"id": id, "category": str(def["category"]), "label": str(def["label"]), "value": value, "text": text, "strength": strength}
## Every figure here is read from the active company's ledger, orders and payroll. A figure that is zero is not offered.
static var _fact_cache := {}
static func facts() -> Array:
	var ent := GameState.company_id()
	if ent == "" or not GlobalMarket.live(ent):
		return []
	var key := "%s|%s|%d|%d|%d" % [ent, str(GameState.data["meta"].get("created_unix", 0)), GameState.data["ledger"]["journal"].size(), Clock.now(), Staff.count()]
	if _fact_cache.get("key", "") == key:
		return _fact_cache["rows"]
	var rows := _read_facts(ent)
	_fact_cache = {"key": key, "rows": rows}
	return rows
static func _read_facts(ent: String) -> Array:
	var out: Array = []
	var year := CapitalMarket.annual(ent)
	var before := CapitalMarket.annual(ent, 1)
	var revenue := float(year["net_revenue"])
	var previous := float(before["net_revenue"])
	if revenue > 0.0:
		out.append(_fact("revenue", revenue, Fmt.money(revenue)))
	if revenue > 0.0 and previous > 0.0 and revenue > previous:
		var growth := (revenue - previous) / previous
		out.append(_fact("growth", growth, Fmt.pct(growth)))
	var delivered := 0
	for order in Ecommerce.E()["orders"].values():
		if str(order.get("entity", ent)) == ent and str(order.get("status", "")) == "delivered":
			delivered += 1
	if delivered > 0:
		out.append(_fact("orders", float(delivered), str(delivered)))
	var profit := float(year["business_profit"])
	if profit > 0.0:
		out.append(_fact("profit", profit, Fmt.money(profit)))
	elif profit < 0.0:
		out.append(_fact("loss", -profit, Fmt.money(-profit)))
	var cash := Ledger.cash(ent)
	if cash > 0.0:
		out.append(_fact("cash", cash, Fmt.money(cash)))
	var quarter := MonthClose.compute(ent, Clock.now() - 90 * Clock.DAY, Clock.now() + 1)
	var monthly := (float(quarter["cogs"]) + float(quarter["opex_total"])) / 3.0
	if monthly > 0.0 and cash > 0.0:
		out.append(_fact("runway", cash / monthly, "%.1f" % (cash / monthly)))
	var team := Staff.count()
	if team > 0:
		out.append(_fact("team", float(team), str(team)))
	var lines := int(Growth.metric("industries"))
	if lines > 0:
		out.append(_fact("lines", float(lines), str(lines)))
	var debt := Insolvency.liabilities(ent)
	if debt > 0.0:
		out.append(_fact("debt", debt, Fmt.money(debt)))
	return out
static func fact(id: String) -> Dictionary:
	for f in facts():
		if f["id"] == id:
			return f
	return {}
static func book_value() -> float:
	return float(Acquisition.quote()["price"])
## Due diligence reads the same books. Every line is a plain pass or fail with the real figure beside it.
static func dd_findings() -> Array:
	var ent := GameState.company_id()
	var c: Dictionary = cfg()["dd"]
	var year := CapitalMarket.annual(ent)
	var revenue := float(year["net_revenue"])
	var months := float(Clock.now() - int(GameState.data["entities"].get(ent, {}).get("founded", Clock.now()))) / float(30 * Clock.DAY)
	var penalties := float(year["opex"].get("penalties", 0.0))
	return [
		{"label": I18n.t("Net revenue over the last 12 months"), "value": Fmt.money(revenue), "need": Fmt.money(float(c["revenue_min"])), "ok": revenue >= float(c["revenue_min"])},
		{"label": I18n.t("Months of trading history"), "value": "%.1f" % months, "need": str(int(c["months_min"])), "ok": months >= float(c["months_min"])},
		{"label": I18n.t("Tax and compliance record in good standing"), "value": I18n.t("Registered") if Tax.valid(ent) else I18n.t("Not in good standing"), "need": I18n.t("Registered"), "ok": Tax.valid(ent)},
		{"label": I18n.t("No unpaid penalties in the last 12 months"), "value": Fmt.money(penalties), "need": Fmt.money(0.0), "ok": penalties <= 0.0},
	]

# ------------------------------------------------------------------ rounds
static func start(id: String) -> Dictionary:
	var open := open_deal_for(id)
	if not open.is_empty():
		return {"ok": true, "id": open["id"], "resumed": true}
	var why := approach_block(id)
	if why != "":
		return error(why)
	var did := "FR-%d" % int(S()["seq"])
	S()["seq"] = int(S()["seq"]) + 1
	var kind := str(inv(id)["kind"])
	var deal := {"id": did, "investor": id, "kind": kind, "status": "ready", "created": Clock.now(), "entity": GameState.company_id(), "counters": 0, "history": []}
	if kind == "vc":
		deal["status"] = "dd"
		deal["dd"] = {"ready": Clock.now() + int(cfg()["dd_days"]) * Clock.DAY}
		GameState.add_message(id, I18n.t("Our analysts start due diligence on your books today. Expect our answer in %d days.") % int(cfg()["dd_days"]))
	S()["deals"][did] = deal
	return {"ok": true, "id": did}
## Resolves a finished due-diligence review. Never changes anything before its stated date.
static func progress_dd(deal_id: String) -> Dictionary:
	var deal := get_deal(deal_id)
	if deal.is_empty() or deal["status"] != "dd":
		return error("No due diligence is waiting on this round.")
	if Clock.now() < int(deal["dd"]["ready"]):
		return error("Due diligence is still running. Continue operating until its stated date.")
	var findings := dd_findings()
	var passed := findings.all(func(f): return f["ok"])
	deal["dd"]["findings"] = findings
	deal["dd"]["passed"] = passed
	if passed:
		deal["status"] = "ready"
		GameState.add_message(str(deal["investor"]), I18n.t("Due diligence is clear. We are ready to hear your pitch."))
	else:
		deal["status"] = "passed"
		S()["cooldowns"][deal["investor"]] = Clock.now() + int(cfg()["pitch_cooldown_days"]) * Clock.DAY
		GameState.add_message(str(deal["investor"]), I18n.t("Due diligence found gaps against our checklist. Fix them and come back after %d days.") % int(cfg()["pitch_cooldown_days"]))
	return {"ok": true, "passed": passed}
static func questions(id: String) -> Array:
	var out: Array = []
	for q in inv(id).get("probes", []):
		var def: Dictionary = cfg()["questions"].get(str(q), {})
		if not def.is_empty():
			out.append({"id": str(q), "text": str(def["text"]), "options": def["options"]})
	return out
static func wary_factor(id: String) -> float:
	return float(cfg()["wary_price_factor"]) if S()["wary"].has(id) else 1.0
static func price_estimate(id: String) -> float:
	return snappedf(maxf(book_value(), float(inv(id)["floor"])) * float(inv(id)["price_factor"]) * wary_factor(id), float(cfg()["price_step"]))
static func max_amount(id: String, pre: float) -> float:
	var cap := float(inv(id)["stake_cap"])
	return minf(float(inv(id)["max"]), snappedf(floor(pre * cap / (1.0 - cap)), 100.0))
## Cheque sizes the player can ask for: the minimum, the middle and the most the stake cap allows.
static func ask_options(id: String) -> Array:
	var lo := float(inv(id)["min"])
	var hi := max_amount(id, price_estimate(id))
	if hi < lo:
		return []
	var out: Array = [lo]
	var mid := snappedf((lo + hi) / 2.0, 5000.0)
	if mid > lo and mid < hi:
		out.append(mid)
	if hi > lo:
		out.append(hi)
	return out
static func deck_score(id: String, deck: Array) -> float:
	var weights: Array = cfg()["slot_weights"]
	var interest: Dictionary = cfg()["personalities"][str(inv(id)["personality"])]["interest"]
	var total := 0.0
	var possible := 0.0
	for i in deck.size():
		var w := float(weights[mini(i, weights.size() - 1)])
		total += w * float(deck[i]["strength"]) * float(interest.get(str(deck[i]["category"]), 0.5))
		possible += w
	return clampf(total / maxf(0.0001, possible), 0.0, 1.0)
## An answer is supported only when the deck holds a real figure of a category that backs that style of answer.
static func answer_supported(style: String, deck: Array) -> bool:
	var backing: Array = cfg()["styles"][style]["backing"]
	return deck.any(func(f): return str(f["category"]) in backing)
## The pitch itself: deck picks (fact ids) and one answer style per question. Everything is validated against the books.
static func pitch(deal_id: String, picks: Array, answers: Array, ask: float) -> Dictionary:
	var deal := get_deal(deal_id)
	if deal.is_empty() or deal["status"] != "ready":
		return error("This pitch is no longer available. Review the status of the round.")
	var id := str(deal["investor"])
	var why := base_block()
	if why != "":
		return error(why)
	if picks.size() < int(cfg()["min_facts"]) or picks.size() > int(cfg()["deck_slots"]):
		return error("Build a deck from two to four real figures.")
	var deck: Array = []
	var seen := {}
	for pid in picks:
		var f := fact(str(pid))
		if f.is_empty() or seen.has(str(pid)):
			return error("Only figures from your real books can go in the deck.")
		seen[str(pid)] = true
		deck.append(f)
	var asked := questions(id)
	if answers.size() != asked.size():
		return error("Answer each of the investor's questions.")
	for i in answers.size():
		if not cfg()["styles"].has(str(answers[i])):
			return error("Choose one of the offered answers.")
	if not ask_options(id).has(ask):
		return error("Choose one of the cheque sizes on offer.")
	var minutes := int(cfg()["pitch_minutes"])
	var score := deck_score(id, deck)
	var qa: Array = []
	var factor := 1.0
	var milestone := float(inv(id)["terms"]["milestone_growth"])
	var visions := 0
	var style_table: Dictionary = cfg()["personalities"][str(inv(id)["personality"])]["style"]
	for i in answers.size():
		var style := str(answers[i])
		var supported := answer_supported(style, deck)
		var mult := float(style_table[style]) * (1.0 if supported else float(cfg()["unsupported_factor"]))
		factor *= mult
		milestone += float(cfg()["styles"][style]["milestone_growth"])
		visions += 1 if bool(cfg()["styles"][style]["board_seat"]) else 0
		qa.append({"q": str(asked[i]["id"]), "style": style, "supported": supported, "mult": mult})
	var deck_mult := float(cfg()["deck_mult_min"]) + float(cfg()["deck_mult_span"]) * score
	deal["deck"] = deck
	deal["deck_at"] = Clock.now()
	deal["deck_score"] = score
	deal["qa"] = qa
	deal["factor"] = factor
	deal["status"] = "pitched"
	var base := maxf(book_value(), float(inv(id)["floor"]))
	var pre := snappedf(base * deck_mult * factor * float(inv(id)["price_factor"]) * wary_factor(id), float(cfg()["price_step"]))
	deal["base"] = base
	deal["books"] = book_value()
	# Time is spent whatever the answer.
	PersonalLife.work(minutes)
	Clock.advance(minutes)
	deal = get_deal(deal_id)
	if deal.is_empty() or deal["status"] != "pitched":
		return error("This pitch is no longer available. Review the status of the round.")
	if score < float(cfg()["pass_score"]):
		deal["status"] = "passed"
		deal["pass_reason"] = I18n.t("The deck did not show enough evidence for this investor's questions.")
		S()["cooldowns"][id] = Clock.now() + int(cfg()["pitch_cooldown_days"]) * Clock.DAY
		GameState.add_message(id, I18n.t("Thank you for the pitch. The deck did not give me enough evidence to put money in. Come back with a stronger record."))
		return {"ok": true, "passed": true}
	var amount := minf(ask, max_amount(id, pre))
	if amount < float(inv(id)["min"]):
		deal["status"] = "passed"
		deal["pass_reason"] = I18n.t("At this valuation the smallest cheque would take more of the company than the investor allows.")
		S()["cooldowns"][id] = Clock.now() + int(cfg()["pitch_cooldown_days"]) * Clock.DAY
		return {"ok": true, "passed": true}
	var t: Dictionary = inv(id)["terms"]
	deal["terms"] = _sheet(id, pre, amount, bool(t["board_seat"]) or visions >= 2, int(t["liq_pref"]), clampf(milestone, 0.0, 0.3), true)
	deal["status"] = "offered"
	GameState.add_message(id, I18n.t("Our term sheet is ready: %s for %s of the company. It stands for %d days.") % [Fmt.money(amount), Fmt.pct(float(deal["terms"]["stake"]), 1), int(cfg()["offer_days"])])
	return {"ok": true, "passed": false}
static func _sheet(id: String, pre: float, amount: float, board: bool, liq: int, growth: float, milestone: bool) -> Dictionary:
	return {"pre": pre, "amount": amount, "post": pre + amount, "stake": amount / (pre + amount), "board_seat": board, "liq_pref": liq,
		"milestone": milestone, "milestone_growth": growth, "strikes": int(inv(id)["terms"]["strikes"]), "legal_fee": float(inv(id).get("legal_fee", 0.0)),
		"expires": Clock.now() + int(cfg()["offer_days"]) * Clock.DAY}
## Elena's chapter-6 approach goes through the same sheet and signing path as every other round.
static func intro_offer(id: String) -> Dictionary:
	var spec: Dictionary = inv(id).get("intro_terms", {})
	if spec.is_empty():
		return error("This investor has no standing offer.")
	if GameState.company_id() == "":
		return error("Investors buy shares in a registered company.")
	var open := open_deal_for(id)
	if not open.is_empty():
		return {"ok": true, "id": open["id"], "resumed": true}
	var did := "FR-%d" % int(S()["seq"])
	S()["seq"] = int(S()["seq"]) + 1
	var amount := float(spec["amount"])
	var stake := float(spec["stake"])
	var pre := snappedf(amount / stake - amount, 1.0)
	var deal := {"id": did, "investor": id, "kind": str(inv(id)["kind"]), "status": "offered", "created": Clock.now(), "entity": GameState.company_id(), "counters": 0, "history": [], "intro": true, "deck_score": 0.5}
	deal["terms"] = _sheet(id, pre, amount, false, 0, 0.0, false)
	deal["terms"]["expires"] = Clock.now() + 30 * Clock.DAY
	S()["deals"][did] = deal
	N()["met"][id] = Clock.now()
	return {"ok": true, "id": did}
static func intro_sign(id: String) -> Dictionary:
	var made := intro_offer(id)
	if not made["ok"]:
		return made
	return sign_sheet(str(made["id"]))
static func counter_asks(deal_id: String) -> Array:
	var deal := get_deal(deal_id)
	var out: Array = []
	if deal.is_empty() or not deal.has("terms"):
		return out
	var t: Dictionary = deal["terms"]
	for key in ["valuation", "board", "liq", "milestone"]:
		var a: Dictionary = cfg()["counter_asks"][key]
		var possible := true
		match key:
			"board":
				possible = bool(t["board_seat"])
			"liq":
				possible = int(t["liq_pref"]) > 0
			"milestone":
				possible = bool(t["milestone"]) and float(t["milestone_growth"]) > 0.0
		if possible:
			out.append({"id": key, "label": str(a["label"]), "cost": int(a["cost"])})
	return out
static func flex(deal: Dictionary) -> int:
	return int(inv(str(deal["investor"]))["flex"]) + roundi(float(deal.get("deck_score", 0.0)) * 2.0)
static func counters_left(deal: Dictionary) -> int:
	return maxi(0, int(inv(str(deal["investor"]))["patience"]) - int(deal.get("counters", 0)))
## A counter-offer. The investor grants the cheapest asks it can afford and refuses the rest. Deterministic.
static func counter(deal_id: String, asks: Array) -> Dictionary:
	var deal := get_deal(deal_id)
	if deal.is_empty() or deal["status"] != "offered":
		return error("There is no term sheet to counter. Review the round status.")
	if Clock.now() > int(deal["terms"]["expires"]):
		deal["status"] = "expired"
		return error("This term sheet has expired.")
	if counters_left(deal) <= 0:
		return error("This is the investor's final offer. Sign it or walk away.")
	var valid := counter_asks(deal_id).map(func(a): return a["id"])
	var wanted: Array = []
	for a in asks:
		if str(a) in valid and not wanted.has(str(a)):
			wanted.append(str(a))
	if wanted.is_empty():
		return error("Choose at least one change to ask for.")
	wanted.sort_custom(func(a, b): return int(cfg()["counter_asks"][a]["cost"]) < int(cfg()["counter_asks"][b]["cost"]))
	var budget := flex(deal)
	var granted: Array = []
	var refused: Array = []
	var t: Dictionary = deal["terms"]
	for key in wanted:
		var cost := int(cfg()["counter_asks"][key]["cost"])
		if cost > budget:
			refused.append(key)
			continue
		budget -= cost
		granted.append(key)
		match key:
			"valuation":
				t["pre"] = snappedf(float(t["pre"]) * float(cfg()["counter_asks"]["valuation"]["mult"]), float(cfg()["price_step"]))
			"board":
				t["board_seat"] = false
			"liq":
				t["liq_pref"] = 0
			"milestone":
				t["milestone_growth"] = maxf(0.0, float(t["milestone_growth"]) + float(cfg()["counter_asks"]["milestone"]["growth"]))
	t["post"] = float(t["pre"]) + float(t["amount"])
	t["stake"] = float(t["amount"]) / float(t["post"])
	deal["counters"] = int(deal["counters"]) + 1
	deal["history"].append({"t": Clock.now(), "granted": granted, "refused": refused})
	return {"ok": true, "granted": granted, "refused": refused, "final": counters_left(deal) <= 0}
static func decline(deal_id: String) -> Dictionary:
	var deal := get_deal(deal_id)
	if deal.is_empty() or not is_open(deal):
		return error("This round is already closed.")
	deal["status"] = "declined"
	S()["cooldowns"][deal["investor"]] = Clock.now() + int(cfg()["pitch_cooldown_days"]) * Clock.DAY
	return {"ok": true}
## Cash in, equity up, every holder diluted by `stake`. One path for angels, venture funds, crowds and Elena's old offer.
static func issue_equity(holder: String, amount: float, stake: float, memo: String, source: Dictionary, extra := {}) -> Dictionary:
	var ent := GameState.company_id()
	if ent == "" or not is_finite(amount) or amount <= 0.0 or not is_finite(stake) or stake <= 0.0 or stake >= 1.0:
		return error("Investors buy shares in a registered company.")
	var cap: Dictionary = GameState.data.get("cap_table", {"founder": 1.0}).duplicate()
	var before := float(cap.get("founder", 0.0))
	Ledger.post(ent, memo, [{"acct": "cash", "dr": amount}, {"acct": "equity", "cr": amount}], source.merged({"type": "investment", "investor": holder}))
	for k in cap:
		cap[k] = float(cap[k]) * (1.0 - stake)
	cap[holder] = float(cap.get(holder, 0.0)) + stake
	GameState.data["cap_table"] = cap
	GameState.set_flag("investor_" + holder)
	var round_row := {"t": Clock.now(), "holder": holder, "amount": amount, "stake": stake, "pre": amount / stake - amount, "founder_before": before, "founder_after": float(cap.get("founder", 0.0))}
	round_row.merge(extra, true)
	S()["rounds"].append(round_row)
	GameState.timeline(I18n.t("Sold %d%% of %s for %s.") % [int(round(stake * 100)), GameState.business_display_name(), Fmt.money0(amount)], "milestone")
	return {"ok": true}
static func sign_sheet(deal_id: String) -> Dictionary:
	var deal := get_deal(deal_id)
	if deal.is_empty() or deal["status"] != "offered":
		return error("There is no term sheet to sign. Review the status of the round.")
	var ent := GameState.company_id()
	if ent == "" or not GlobalMarket.live(ent) or str(deal.get("entity", ent)) != ent:
		return error("This company is closed or unavailable. Continue with your current life.")
	var t: Dictionary = deal["terms"]
	if Clock.now() > int(t["expires"]):
		deal["status"] = "expired"
		return error("This term sheet has expired.")
	if float(GameState.data.get("cap_table", {"founder": 1.0}).get("founder", 0.0)) <= 0.0:
		return error("The founder shares have already been sold. There is nothing left to raise against.")
	var id := str(deal["investor"])
	var done := issue_equity(id, float(t["amount"]), float(t["stake"]), I18n.t("%s: equity investment (%s)") % [name_of(id), Fmt.pct(float(t["stake"]), 1)], {"deal": deal_id}, {"deal": deal_id, "kind": deal["kind"], "liq_pref": int(t["liq_pref"])})
	if not done["ok"]:
		return done
	if float(t["legal_fee"]) > 0.0:
		Ledger.expense(ent, "legal", float(t["legal_fee"]), I18n.t("Legal and filing costs for the %s round") % name_of(id), {"type": "fundraising_fee", "deal": deal_id})
	deal["status"] = "signed"
	deal["signed"] = Clock.now()
	deal["misses"] = 0
	deal["quarter"] = 0
	if bool(t["milestone"]) or (bool(deal.get("intro", false)) and bool(inv(id).get("intro_terms", {}).get("reports", false))):
		deal["reports"] = true
		var base := float(MonthClose.compute(ent, Clock.now() - 90 * Clock.DAY, Clock.now() + 1)["net_revenue"])
		deal["baseline"] = base
		deal["target"] = maxf(float(cfg()["milestone_min_target"]), base * (1.0 + float(t["milestone_growth"]))) if bool(t["milestone"]) else 0.0
		deal["next_report"] = Clock.now() + int(cfg()["quarter_days"]) * Clock.DAY
	N()["met"][id] = N()["met"].get(id, Clock.now())
	GameState.inc_stat("rounds_signed")
	return {"ok": true, "amount": float(t["amount"]), "stake": float(t["stake"])}

# ------------------------------------------------------------------ cap table and exits
static func holder_name(id: String) -> String:
	match id:
		"founder":
			return I18n.t("You (founder)")
		"crowd":
			return I18n.t("Community backers")
		"public":
			return I18n.t("Public shareholders")
		"employees":
			return I18n.t("Employees")
		"hale_group":
			return I18n.t("Hale Group")
	if inv(id).has("name"):
		return name_of(id)
	return PhoneMessages.contact_name(id)
## Rows for the cap table: [{id, name, share}] with the founder first. Older saves have only the cap_table dictionary.
static func cap_rows() -> Array:
	var cap: Dictionary = GameState.data.get("cap_table", {"founder": 1.0})
	var rows: Array = []
	for k in cap:
		if float(cap[k]) > 0.0000001:
			rows.append({"id": str(k), "name": holder_name(str(k)), "share": float(cap[k])})
	rows.sort_custom(func(a, b): return a["id"] == "founder" or (b["id"] != "founder" and float(a["share"]) > float(b["share"])))
	return rows
static func cap_total() -> float:
	var sum := 0.0
	for v in GameState.data.get("cap_table", {"founder": 1.0}).values():
		sum += float(v)
	return sum
static func rounds() -> Array:
	return S()["rounds"] if has_state() else []
static func prefs() -> Array:
	var out: Array = []
	if not has_state():
		return out
	for deal in S()["deals"].values():
		if deal["status"] == "signed" and int(deal["terms"]["liq_pref"]) > 0 and not deal.get("pref_converted", false):
			out.append(deal)
	return out
## What the founder receives when the company is sold for `price`. Preferred investors take the larger of their
## preference or their share first; everyone else shares what is left. With no preference this is price × founder share.
static func founder_proceeds(price: float) -> float:
	var cap: Dictionary = GameState.data.get("cap_table", {"founder": 1.0})
	var founder := float(cap.get("founder", 0.0))
	var plain := snappedf(price * founder, 0.01)
	var deals_with_pref := prefs()
	if deals_with_pref.is_empty() or price <= 0.0:
		return plain
	var claims := {}
	for deal in deals_with_pref:
		var holder := str(deal["investor"])
		claims[holder] = float(claims.get(holder, 0.0)) + float(deal["terms"]["amount"]) * float(deal["terms"]["liq_pref"])
	var claimed := 0.0
	for holder in claims:
		claims[holder] = maxf(float(claims[holder]), float(cap.get(holder, 0.0)) * price)
		claimed += float(claims[holder])
	var scale := minf(1.0, price / maxf(0.01, claimed))
	var left := maxf(0.0, price - claimed * scale)
	var others := 0.0
	for k in cap:
		if not claims.has(k):
			others += float(cap[k])
	if others <= 0.0 or founder <= 0.0:
		return 0.0
	return snappedf(left * founder / others, 0.01)
static func on_public_listing() -> void:
	if not has_state():
		return
	for deal in prefs():
		deal["pref_converted"] = true
	if not prefs().is_empty() or S()["deals"].values().any(func(d): return d.get("pref_converted", false)):
		GameState.timeline(I18n.t("Investor liquidation preferences converted to ordinary shares at the listing."), "company")
static func funded() -> bool:
	for k in GameState.data.get("cap_table", {"founder": 1.0}):
		if k != "founder" and float(GameState.data["cap_table"][k]) > 0.0 and (inv(str(k)).has("kind") or str(k) == "crowd"):
			return true
	return false
## A small score nudge for the life-review archetypes: how the company was funded, never a buff to play.
static func legacy_bonus(archetype: String) -> float:
	if not funded():
		return 0.0
	var b: Dictionary = cfg()["legacy_bonus"]
	var founder := float(GameState.data.get("cap_table", {"founder": 1.0}).get("founder", 1.0))
	var total := float(b["funded"].get(archetype, 0))
	if founder < 0.5:
		total += float(b["outside_majority"].get(archetype, 0))
	elif founder >= 0.8:
		total += float(b["kept_control"].get(archetype, 0))
	return total

# ------------------------------------------------------------------ quarterly reports and the board
static func milestone_target(deal: Dictionary) -> float:
	return float(deal.get("target", 0.0))
static func _report(deal: Dictionary) -> void:
	var ent := GameState.company_id()
	var end := int(deal["next_report"])
	var start := end - int(cfg()["quarter_days"]) * Clock.DAY
	var m := MonthClose.compute(ent, start, end)
	var actual := float(m["net_revenue"])
	var has_target: bool = bool(deal["terms"]["milestone"]) and float(deal.get("target", 0.0)) > 0.0
	var target := float(deal.get("target", 0.0))
	var met_it: Variant = null
	deal["quarter"] = int(deal["quarter"]) + 1
	if has_target:
		met_it = actual >= target
		if met_it:
			deal["misses"] = 0
			deal["target"] = maxf(float(cfg()["milestone_min_target"]), target * (1.0 + float(deal["terms"]["milestone_growth"])))
		else:
			deal["misses"] = int(deal["misses"]) + 1
	var row := {"deal": deal["id"], "investor": deal["investor"], "n": deal["quarter"], "at": end, "actual": actual, "target": target, "met": met_it, "profit": float(m["business_profit"])}
	S()["reports"].append(row)
	var who := str(deal["investor"])
	var text: String
	if met_it == null:
		text = I18n.t("Quarter %d report: net revenue %s. Thank you for the update.") % [int(deal["quarter"]), Fmt.money(actual)]
	elif met_it:
		text = I18n.t("Quarter %d report: net revenue %s against a %s milestone. Milestone met.") % [int(deal["quarter"]), Fmt.money(actual), Fmt.money(target)]
	else:
		text = I18n.t("Quarter %d report: net revenue %s against a %s milestone. Milestone missed.") % [int(deal["quarter"]), Fmt.money(actual), Fmt.money(target)]
	GameState.add_message(who, text)
	deal["next_report"] = end + int(cfg()["quarter_days"]) * Clock.DAY
	if met_it == false and int(deal["misses"]) >= int(deal["terms"]["strikes"]) and not str(deal.get("board", {}).get("status", "")) == "open":
		_open_board(deal, actual)
static func _open_board(deal: Dictionary, actual: float) -> void:
	deal["board"] = {"status": "open", "opened": Clock.now(), "expires": Clock.now() + int(cfg()["board_review_days"]) * Clock.DAY, "actual": actual}
	var did := str(deal["id"])
	var replies: Array = [
		{"id": "plan", "label": "Present a recovery plan", "effects": [{"op": "fund_board", "deal": did, "choice": "plan"}]},
		{"id": "advisor", "label": "Accept a board-appointed advisor", "effects": [{"op": "fund_board", "deal": did, "choice": "advisor"}]},
		{"id": "override", "label": "Overrule the board with your votes", "effects": [{"op": "fund_board", "deal": did, "choice": "override"}]}]
	GameState.add_message(str(deal["investor"]), I18n.t("The milestone has been missed. The board is calling a review: choose how you want to respond within %d days.") % int(cfg()["board_review_days"]), {"replies": replies})
	GameState.timeline(I18n.t("Investor board review opened after a missed milestone."), "company")
static func board_choices(deal: Dictionary) -> Array:
	var out: Array = []
	var founder := float(GameState.data.get("cap_table", {"founder": 1.0}).get("founder", 0.0))
	var fee := advisor_fee(deal)
	out.append({"id": "plan", "label": I18n.t("Present a recovery plan"), "detail": I18n.t("Costs %d minutes. The milestone is reset lower and the investor becomes wary of future rounds.") % int(cfg()["plan_minutes"]), "block": ""})
	out.append({"id": "advisor", "label": I18n.t("Accept a board-appointed advisor"), "detail": I18n.t("Costs %s in fees. The milestone is reset and the review closes cleanly.") % Fmt.money(fee), "block": "" if Ledger.cash(GameState.company_id()) >= fee else I18n.t("Not enough company cash for the advisor fee.")})
	out.append({"id": "override", "label": I18n.t("Overrule the board with your votes"), "detail": I18n.t("Free, but the investor will not back you again and the next miss reopens the review."), "block": "" if founder > 0.5 else I18n.t("You need more than half the votes to overrule the board.")})
	return out
static func advisor_fee(deal: Dictionary) -> float:
	return maxf(float(cfg()["advisor_min"]), snappedf(float(deal["terms"]["amount"]) * float(cfg()["advisor_share"]), 1.0))
static func board_decide(deal_id: String, choice: String) -> Dictionary:
	var deal := get_deal(deal_id)
	if deal.is_empty() or deal["status"] != "signed" or str(deal.get("board", {}).get("status", "")) != "open":
		return error("This board review is already closed.")
	var ent := GameState.company_id()
	var actual := float(deal["board"].get("actual", 0.0))
	match choice:
		"plan":
			PersonalLife.work(int(cfg()["plan_minutes"]))
			Clock.advance(int(cfg()["plan_minutes"]))
			deal["target"] = maxf(float(cfg()["milestone_min_target"]), actual * float(cfg()["plan_target_share"]))
			S()["wary"][deal["investor"]] = true
		"advisor":
			var fee := advisor_fee(deal)
			if Ledger.cash(ent) < fee:
				return error("Not enough company cash for the advisor fee. Choose the recovery plan instead.")
			Ledger.expense(ent, "other", fee, I18n.t("Board-appointed advisor fee: %s") % Fmt.money(fee), {"type": "board_advisor", "deal": deal_id})
			deal["target"] = maxf(float(cfg()["milestone_min_target"]), actual * float(cfg()["advisor_target_share"]))
		"override":
			if float(GameState.data.get("cap_table", {"founder": 1.0}).get("founder", 0.0)) <= 0.5:
				return error("You need more than half the votes to overrule the board.")
			S()["hostile"][deal["investor"]] = true
		_:
			return error("Choose how to respond to the board.")
	if choice != "override":
		deal["misses"] = 0
	deal["board"]["status"] = "resolved"
	deal["board"]["choice"] = choice
	GameState.timeline(I18n.t("Board review closed: %s.") % I18n.t({"plan": "recovery plan agreed", "advisor": "advisor appointed", "override": "board overruled"}[choice]), "company")
	return {"ok": true}

# ------------------------------------------------------------------ community round (equity crowdfunding)
static func crowd_block() -> String:
	var why := base_block()
	if why != "":
		return why
	var ent := GameState.company_id()
	if str(GameState.data["entities"].get(ent, {}).get("type", "")) == "holding":
		return "A community round needs an operating company with customers to appeal to."
	var delivered := 0
	for order in Ecommerce.E()["orders"].values():
		if str(order.get("entity", ent)) == ent and str(order.get("status", "")) == "delivered":
			delivered += 1
	if delivered <= 0 and not GameState.flag("media_active"):
		return "Community rounds suit online shops and media companies with real customers. Deliver an order or run a campaign first."
	if S()["campaigns"].values().any(func(c): return c["status"] == "running"):
		return "A campaign is already running. Wait for its result."
	return ""
static func crowd_pre() -> float:
	var c: Dictionary = cfg()["crowd"]
	return snappedf(maxf(book_value(), float(c["floor"])) * float(c["price_factor"]), float(cfg()["price_step"]))
static func crowd_max_raise() -> float:
	var c: Dictionary = cfg()["crowd"]
	var cap := float(c["stake_cap"])
	return minf(float(c["max_raise"]), snappedf(floor(crowd_pre() * cap / (1.0 - cap)), 100.0))
static func crowd_goals() -> Array:
	return cfg()["crowd"]["goals"].filter(func(g): return float(g) <= crowd_max_raise())
static func crowd_start(goal: float, promo: float, page: Array) -> Dictionary:
	var why := crowd_block()
	if why != "":
		return error(why)
	var c: Dictionary = cfg()["crowd"]
	if not crowd_goals().has(goal) or not c["promos"].has(promo):
		return error("Choose one of the campaign goals and promotion budgets.")
	if page.is_empty() or page.size() > int(c["page_facts"]):
		return error("Build the campaign page from one to three real figures.")
	var chosen: Array = []
	for pid in page:
		var f := fact(str(pid))
		if f.is_empty():
			return error("Only figures from your real books can go on the campaign page.")
		chosen.append(f)
	var ent := GameState.company_id()
	if Ledger.cash(ent) < promo:
		return error("Keep enough company cash to pay for the promotion.")
	Ledger.expense(ent, "advertising", promo, I18n.t("Community round promotion: %s") % Fmt.money(promo), {"type": "crowd_promo"})
	var strength := 0.0
	for f in chosen:
		strength += float(f["strength"])
	strength /= float(chosen.size())
	var delivered := 0
	for order in Ecommerce.E()["orders"].values():
		if str(order.get("entity", ent)) == ent and str(order.get("status", "")) == "delivered":
			delivered += 1
	var expected := promo * float(c["reach"]) * (0.6 + 0.6 * strength) + delivered * float(c["order_pledge"])
	var cid := "CF-%d" % int(S()["seq"])
	S()["seq"] = int(S()["seq"]) + 1
	S()["campaigns"][cid] = {"id": cid, "goal": goal, "promo": promo, "page": chosen, "status": "running", "started": Clock.now(), "ends": Clock.now() + int(c["days"]) * Clock.DAY, "expected": expected}
	return {"ok": true, "id": cid}
## Resolves a finished campaign: all-or-nothing against its goal. Success issues equity to the crowd; failure raises nothing.
static func crowd_resolve(cid: String) -> Dictionary:
	var camp: Dictionary = S()["campaigns"].get(cid, {})
	if camp.is_empty() or camp["status"] != "running":
		return error("This campaign has already finished.")
	if Clock.now() < int(camp["ends"]):
		return error("The campaign is still running. Continue operating until its stated date.")
	var c: Dictionary = cfg()["crowd"]
	var pledged := snappedf(float(camp["expected"]) * (1.0 - float(c["variance"]) + 2.0 * float(c["variance"]) * GameState.randf()), 1.0)
	camp["pledged"] = pledged
	camp["backers"] = int(ceil(pledged / float(c["ticket"])))
	if pledged < float(camp["goal"]) or base_block() != "":
		camp["status"] = "failed"
		GameState.add_message("investor", I18n.t("Your community round raised %s of its %s goal, so every pledge was returned.") % [Fmt.money(pledged), Fmt.money(float(camp["goal"]))])
		return {"ok": true, "success": false}
	var raised := minf(pledged, crowd_max_raise())
	var stake := raised / (crowd_pre() + raised)
	var done := issue_equity("crowd", raised, stake, I18n.t("Community round: %d backers") % int(camp["backers"]), {"campaign": cid}, {"kind": "crowd", "campaign": cid})
	if not done["ok"]:
		camp["status"] = "failed"
		return done
	var fee := snappedf(raised * float(c["fee"]), 0.01)
	Ledger.expense(GameState.company_id(), "platform_fees", fee, I18n.t("Community round platform fee: %s") % Fmt.money(fee), {"type": "crowd_fee", "campaign": cid})
	camp["status"] = "funded"
	camp["raised"] = raised
	camp["stake"] = stake
	return {"ok": true, "success": true, "raised": raised}

# ------------------------------------------------------------------ hourly work
static func on_hour(_t: int, _h: int) -> void:
	if not has_state() or not GlobalMarket.live(GameState.company_id()):
		return
	var s := S()
	for deal in s["deals"].values():
		match str(deal["status"]):
			"dd":
				if Clock.now() >= int(deal["dd"]["ready"]):
					progress_dd(str(deal["id"]))
			"offered":
				if Clock.now() > int(deal["terms"]["expires"]):
					deal["status"] = "expired"
					GameState.add_message(str(deal["investor"]), I18n.t("The term sheet has lapsed. We can talk again after you pitch anew."))
			"signed":
				var guard := 0
				while bool(deal.get("reports", false)) and Clock.now() >= int(deal["next_report"]) and guard < int(cfg()["report_catchup"]):
					guard += 1
					_report(deal)
				var board: Dictionary = deal.get("board", {})
				if str(board.get("status", "")) == "open" and Clock.now() >= int(board["expires"]):
					var fee := advisor_fee(deal)
					board_decide(str(deal["id"]), "advisor" if Ledger.cash(GameState.company_id()) >= fee else "plan")
	for camp in s["campaigns"].values():
		if camp["status"] == "running" and Clock.now() >= int(camp["ends"]):
			crowd_resolve(str(camp["id"]))
	Partnerships.on_hour()
static func handle(_kind: String, _payload: Dictionary) -> void:
	pass
static func on_company_closed(entity: String) -> void:
	if not has_state() or entity != GameState.company_id():
		return
	for deal in S()["deals"].values():
		if is_open(deal):
			deal["status"] = "closed"
	for camp in S()["campaigns"].values():
		if camp["status"] == "running":
			camp["status"] = "closed"
	Partnerships.on_company_closed()
static func on_job_paid(job: Dictionary) -> void:
	Partnerships.on_job_paid(job)
static func is_running() -> bool:
	return false
static func segment_tag() -> String:
	return "shared"
static func os_tab() -> Dictionary:
	return {}
static func board_detail() -> Callable:
	return func(_a, _b): pass
