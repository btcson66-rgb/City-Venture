class_name FundraisingModal
extends Modal
## Fundraising and partners (#116): investors, cap table, quarterly reports, partnership contracts and the community round.

var tab := "investors"
var selected := ""
var notice := ""
var ask := 0.0
var counter_picks: Array = []
var partner_sel := ""
var crowd_goal := 0.0
var crowd_promo := 0.0
var crowd_page: Array = []


func _init(start_tab := "investors") -> void:
	calm_profile = "fundraising"
	tab = start_tab
	title_text = "Fundraising and partners"
	icon_name = "finance"
	help_key = "fundraising"
	panel_size = Vector2(560, 345)
	pauses_time = true


func _act(box: Control, text: String, id: String, fn: Callable, primary := false) -> Button:
	var b := UIK.button(text, fn, "primary" if primary else "")
	b.name = id
	box.add_child(b)
	return b


func _say(result: Dictionary, ok_text := "") -> void:
	notice = ok_text if result.get("ok", false) else str(result.get("error", ""))
	rebuild()


func build() -> void:
	if notice != "":
		body.add_child(UIK.wrap(notice, 8, Art.C_SKY, 530))
	var row := UIK.hbox(3)
	body.add_child(row)
	for t in [["investors", "Investors"], ["cap", "Cap table"], ["reports", "Reports"], ["partners", "Partners"], ["community", "Community"]]:
		var b := UIK.button(t[1], func():
			tab = t[0]
			selected = ""
			partner_sel = ""
			notice = ""
			rebuild(), "tab_active" if tab == t[0] else "tab")
		b.name = "Tab_" + t[0]
		row.add_child(b)
	var box := UIK.vbox(5)
	body.add_child(UIK.scroll(box, Vector2(530, 218)))
	match tab:
		"cap":
			_cap(box)
		"reports":
			_reports(box)
		"partners":
			_partners(box)
		"community":
			_community(box)
		_:
			if selected == "":
				_investor_list(box)
			else:
				_investor(box)
	footer.add_child(UIK.button("Close", close))


# ------------------------------------------------------------------ investors
func _status_text(id: String) -> String:
	var deal := Fundraising.open_deal_for(id)
	if not deal.is_empty():
		return I18n.t({"dd": "Due diligence running", "ready": "Ready to pitch", "offered": "Term sheet on the table"}[str(deal["status"])])
	var why := Fundraising.approach_block(id)
	return I18n.t(why) if why != "" else I18n.t("Ready to approach")


func _investor_list(box: VBoxContainer) -> void:
	var why := Fundraising.base_block()
	if why != "":
		box.add_child(UIK.wrap("✗ " + I18n.t(why), 8, Art.C_MUTED, 520))
	box.add_child(UIK.wrap("Money from investors is equity, not sales income. Every round gives away part of the company, and angels and funds expect reports in return.", 8, Art.C_MUTED, 520))
	for id in Fundraising.cfg()["investors"]:
		var d: Dictionary = Fundraising.inv(id)
		var kind := I18n.t("Angel") if d["kind"] == "angel" else I18n.t("Venture fund")
		box.add_child(UIK.title("%s · %s" % [Fundraising.name_of(id), kind], 10, Art.C_SKY))
		box.add_child(UIK.wrap(I18n.t(str(d["blurb"])), 8, Art.C_WHITE, 520))
		box.add_child(UIK.wrap("%s · %s–%s · %s" % [I18n.t(str(Fundraising.cfg()["personalities"][d["personality"]]["label"])), Fmt.money0(float(d["min"])), Fmt.money0(float(d["max"])), _status_text(id)], 8, Art.C_SKY, 520))
		_act(box, "Open", "Investor_" + id, func():
			selected = id
			notice = ""
			counter_picks = []
			ask = 0.0
			rebuild())


func _terms_box(box: VBoxContainer, deal: Dictionary) -> void:
	var t: Dictionary = deal["terms"]
	var cap: Dictionary = GameState.data.get("cap_table", {"founder": 1.0})
	var founder := float(cap.get("founder", 1.0))
	box.add_child(UIK.kv("Valuation before the money (pre-money)", Fmt.money(float(t["pre"]))))
	box.add_child(UIK.kv("Investment", Fmt.money(float(t["amount"])), Art.C_GREEN))
	box.add_child(UIK.kv("Valuation after the money (post-money)", Fmt.money(float(t["post"]))))
	box.add_child(UIK.kv("Equity sold", Fmt.pct(float(t["stake"]), 1)))
	box.add_child(UIK.kv("Your share after the round", "%s → %s" % [Fmt.pct(founder, 1), Fmt.pct(founder * (1.0 - float(t["stake"])), 1)]))
	box.add_child(UIK.kv("Board seat", I18n.t("Yes") if t["board_seat"] else I18n.t("No")))
	var pref := I18n.t("None") if int(t["liq_pref"]) == 0 else I18n.t("%dx the investment is repaid first if the company is sold") % int(t["liq_pref"])
	box.add_child(UIK.kv("Liquidation preference", pref))
	if bool(t["milestone"]):
		box.add_child(UIK.kv("Quarterly revenue milestone", I18n.t("Grow %s every quarter") % Fmt.pct(float(t["milestone_growth"]))))
		box.add_child(UIK.wrap(I18n.t("Missing it %d time(s) in a row opens a board review.") % int(t["strikes"]), 8, Art.C_MUTED, 520))
	else:
		box.add_child(UIK.kv("Quarterly revenue milestone", I18n.t("None; reports only")))
	if float(t["legal_fee"]) > 0.0:
		box.add_child(UIK.kv("Legal and filing costs paid at signing", Fmt.money(float(t["legal_fee"]))))
	box.add_child(UIK.kv("Offer stands until", Clock.fmt_short(int(t["expires"]))))


func _investor(box: VBoxContainer) -> void:
	var id := selected
	var d: Dictionary = Fundraising.inv(id)
	var deal := Fundraising.open_deal_for(id)
	var done: Dictionary = {}
	if deal.is_empty():
		for candidate in Fundraising.deals().values():
			if candidate["investor"] == id and (done.is_empty() or int(candidate["created"]) > int(done["created"])):
				done = candidate
	box.add_child(UIK.title("%s · %s" % [Fundraising.name_of(id), I18n.t(str(d["firm"]))], 11, Art.C_SKY))
	box.add_child(UIK.wrap(I18n.t(str(d["blurb"])), 8, Art.C_WHITE, 520))
	var p: Dictionary = Fundraising.cfg()["personalities"][d["personality"]]
	box.add_child(UIK.wrap("%s: %s" % [I18n.t(str(p["label"])), I18n.t(str(p["blurb"]))], 8, Art.C_SKY, 520))
	box.add_child(UIK.kv("Cheque size", "%s – %s" % [Fmt.money0(float(d["min"])), Fmt.money0(float(d["max"]))]))
	if not deal.is_empty():
		_open_deal(box, id, deal)
	else:
		_closed_or_new(box, id, done)
	_act(box, "Back to investors", "BackInvestors", func():
		selected = ""
		notice = ""
		rebuild())


func _closed_or_new(box: VBoxContainer, id: String, done: Dictionary) -> void:
	if not done.is_empty():
		var shown := str(done["status"])
		var line := I18n.t({"signed": "Signed. The money is in the company and this investor is on your cap table.", "passed": "The investor passed.", "declined": "You declined this round.", "expired": "The term sheet expired.", "closed": "The company closed."}.get(shown, "Closed."))
		box.add_child(UIK.wrap(line, 8, Art.C_WHITE, 520))
		if done.has("pass_reason"):
			box.add_child(UIK.wrap(str(done["pass_reason"]), 8, Art.C_MUTED, 520))
		if done.get("dd", {}).has("findings"):
			_findings(box, done["dd"]["findings"])
	var why := Fundraising.approach_block(id)
	if why != "":
		box.add_child(UIK.wrap("✗ " + I18n.t(why), 8, Art.C_MUTED, 520))
		if str(Fundraising.inv(id)["kind"]) == "vc" and not Fundraising.introduced(id) and Fundraising.introducer(id) != "":
			var who := Fundraising.introducer(id)
			_act(box, I18n.t("Ask %s for an introduction") % Fundraising.name_of(who), "RequestIntro", func(): _say(Fundraising.request_intro(id), I18n.t("%s introduced you. Approach the fund when you are ready.") % Fundraising.name_of(who)), true)
		return
	if str(Fundraising.inv(id)["kind"]) == "vc":
		var intro: Dictionary = Fundraising.N()["intro"].get(id, {})
		box.add_child(UIK.wrap(I18n.t("Introduced by %s. A fund runs due diligence on your books before it hears a pitch.") % Fundraising.name_of(str(intro.get("from", ""))), 8, Art.C_SKY, 520))
	_act(box, "Approach this investor", "ApproachInvestor", func(): _say(Fundraising.start(id), I18n.t("Round opened.")), true)


func _findings(box: VBoxContainer, findings: Array) -> void:
	for f in findings:
		box.add_child(UIK.wrap("%s %s: %s (%s %s)" % ["✓" if f["ok"] else "✗", f["label"], f["value"], I18n.t("needs"), f["need"]], 8, Art.C_GREEN if f["ok"] else Art.C_RED, 520))


func _open_deal(box: VBoxContainer, id: String, deal: Dictionary) -> void:
	match str(deal["status"]):
		"dd":
			box.add_child(UIK.wrap(I18n.t("Due diligence is reading your books. Result on %s.") % Clock.fmt_short(int(deal["dd"]["ready"])), 8, Art.C_WHITE, 520))
			box.add_child(UIK.wrap(I18n.t("Checklist: 12 months of revenue, trading history, a clean tax record and no unpaid penalties."), 8, Art.C_MUTED, 520))
			if Clock.now() >= int(deal["dd"]["ready"]):
				_act(box, "Read the due diligence result", "ReadDD", func(): _say(Fundraising.progress_dd(str(deal["id"])), I18n.t("Due diligence is complete.")), true)
		"ready":
			_ready_round(box, id, deal)
		"offered":
			_offered(box, id, deal)


func _ready_facts(box: VBoxContainer) -> void:
	box.add_child(UIK.label("Figures you can show (from your books)", 9, Art.C_SKY))
	for f in Fundraising.facts():
		box.add_child(UIK.wrap("• %s: %s" % [I18n.t(str(f["label"])), str(f["text"])], 8, Art.C_WHITE, 520))


func _ready_round(box: VBoxContainer, id: String, deal: Dictionary) -> void:
	box.add_child(UIK.wrap(Fundraising.impression_line(Fundraising.name_of(id), str(Fundraising.N()["impression"].get(id, "neutral"))), 8, Art.C_SKY, 520))
	var options := Fundraising.ask_options(id)
	if options.is_empty():
		box.add_child(UIK.wrap("At the current valuation the smallest cheque would take more of the company than this investor allows. Grow the business first.", 8, Art.C_MUTED, 520))
	else:
		if not options.has(ask):
			ask = float(options[0])
		var asks: Array = options.map(func(v): return [str(v), Fmt.money0(float(v))])
		box.add_child(MiniGame.choice_row("Ask for", asks, str(ask), func(v):
			ask = float(v)
			rebuild(), "Ask"))
		box.add_child(UIK.wrap(I18n.t("Valuation estimate before the pitch: %s. The deck and your answers move it.") % Fmt.money0(Fundraising.price_estimate(id)), 8, Art.C_MUTED, 520))
	_ready_facts(box)
	if not options.is_empty():
		_act(box, "Build the deck and pitch", "StartPitch", func(): _pitch(str(deal["id"])), true)
	_act(box, "Walk away from this round", "WalkAway", func(): _say(Fundraising.decline(str(deal["id"])), I18n.t("You walked away. Nothing was spent.")))


func _pitch(deal_id: String) -> void:
	var game := PitchGame.new(deal_id)
	var chosen := ask
	MiniGames.play(game, func(result):
		if result.get("aborted", false):
			rebuild()
			return
		var outcome := Fundraising.pitch(deal_id, result.get("picks", []), result.get("answers", []), chosen)
		if outcome.get("ok", false) and outcome.get("passed", false):
			notice = I18n.t("The investor passed on this round.")
			rebuild()
		else:
			_say(outcome, I18n.t("The investor liked the pitch: read the term sheet.")))


func _offered(box: VBoxContainer, id: String, deal: Dictionary) -> void:
	_terms_box(box, deal)
	if deal.has("deck"):
		box.add_child(UIK.label("The deck you showed", 9, Art.C_SKY))
		for f in deal["deck"]:
			box.add_child(UIK.wrap("• %s: %s" % [I18n.t(str(f["label"])), str(f["text"])], 8, Art.C_WHITE, 520))
	var left := Fundraising.counters_left(deal)
	var asks := Fundraising.counter_asks(str(deal["id"]))
	if left > 0 and not asks.is_empty():
		box.add_child(UIK.wrap(I18n.t("Counter-offer: choose what to ask for. The investor grants what it can afford and refuses the rest. Counters left: %d.") % left, 8, Art.C_SKY, 520))
		for a in asks:
			var on: bool = counter_picks.has(a["id"])
			var b := UIK.button(("☑ " if on else "☐ ") + I18n.t(str(a["label"])), func():
				if on:
					counter_picks.erase(a["id"])
				else:
					counter_picks.append(a["id"])
				rebuild(), "tab_active" if on else "tab")
			b.name = "CounterAsk_" + str(a["id"])
			box.add_child(b)
		_act(box, "Send the counter-offer", "SendCounter", func():
			var asked := counter_picks.duplicate()
			counter_picks = []
			var r := Fundraising.counter(str(deal["id"]), asked)
			if r.get("ok", false):
				var note: Array = []
				for k in r["granted"]:
					note.append(I18n.t("granted: %s") % I18n.t(str(Fundraising.cfg()["counter_asks"][k]["label"])))
				for k in r["refused"]:
					note.append(I18n.t("refused: %s") % I18n.t(str(Fundraising.cfg()["counter_asks"][k]["label"])))
				_say(r, "; ".join(note))
			else:
				_say(r))
	elif left <= 0:
		box.add_child(UIK.wrap("✗ " + I18n.t("This is the investor's final offer. Sign it or walk away."), 8, Art.C_MUTED, 520))
	_act(box, "Sign and receive the funds", "SignTerms", func():
		_say(Fundraising.sign_sheet(str(deal["id"])), I18n.t("Signed. The money is in your company account and the cap table is updated.")), true)
	_act(box, "Decline the term sheet", "DeclineTerms", func(): _say(Fundraising.decline(str(deal["id"])), I18n.t("You declined the term sheet.")))


# ------------------------------------------------------------------ cap table
func _cap(box: VBoxContainer) -> void:
	box.add_child(UIK.label("Ownership", 10, Art.C_SKY))
	for r in Fundraising.cap_rows():
		box.add_child(UIK.kv(str(r["name"]), Fmt.pct(float(r["share"]), 1), Art.C_SKY if r["id"] == "founder" else Art.C_WHITE))
	box.add_child(UIK.wrap("Equity is ownership, not income. Each round dilutes every existing holder in proportion.", 8, Art.C_MUTED, 520))
	var rows := Fundraising.rounds()
	if not rows.is_empty():
		box.add_child(UIK.label("Rounds and dilution", 10, Art.C_SKY))
		for r in rows:
			box.add_child(UIK.wrap(I18n.t("%s: %s for %s. Your share %s → %s.") % [Fundraising.holder_name(str(r["holder"])), Fmt.money(float(r["amount"])), Fmt.pct(float(r["stake"]), 1), Fmt.pct(float(r["founder_before"]), 1), Fmt.pct(float(r["founder_after"]), 1)], 8, Art.C_WHITE, 520))
	var value := Fundraising.book_value()
	if value > 0.0:
		box.add_child(UIK.label("If the company were sold at its book value", 10, Art.C_SKY))
		box.add_child(UIK.kv("Book value", Fmt.money0(value)))
		box.add_child(UIK.kv("You would receive", Fmt.money0(Fundraising.founder_proceeds(value)), Art.C_GREEN))
		for deal in Fundraising.prefs():
			box.add_child(UIK.wrap(I18n.t("%s has a %dx liquidation preference: it is repaid first.") % [Fundraising.name_of(str(deal["investor"])), int(deal["terms"]["liq_pref"])], 8, Art.C_MUTED, 520))
	if Fundraising.rounds().is_empty() and Fundraising.cap_rows().size() <= 1:
		box.add_child(UIK.wrap("You own all of the company. No money has been raised yet.", 8, Art.C_MUTED, 520))


# ------------------------------------------------------------------ reports and the board
func _reports(box: VBoxContainer) -> void:
	var any := false
	for deal in Fundraising.deals().values():
		if deal["status"] != "signed":
			continue
		any = true
		box.add_child(UIK.title("%s · %s" % [Fundraising.name_of(str(deal["investor"])), Fmt.money(float(deal["terms"]["amount"]))], 10, Art.C_SKY))
		if bool(deal.get("reports", false)):
			box.add_child(UIK.kv("Next quarterly report", Clock.fmt_short(int(deal["next_report"]))))
			if float(deal.get("target", 0.0)) > 0.0:
				box.add_child(UIK.kv("Revenue milestone for the next quarter", Fmt.money(float(deal["target"]))))
				box.add_child(UIK.kv("Missed in a row", "%d / %d" % [int(deal["misses"]), int(deal["terms"]["strikes"])]))
		else:
			box.add_child(UIK.wrap("No reporting duties came with this round.", 8, Art.C_MUTED, 520))
		var board: Dictionary = deal.get("board", {})
		if str(board.get("status", "")) == "open":
			box.add_child(UIK.wrap("✗ " + I18n.t("Board review open until %s. Choose a response; if you do nothing the board appoints an advisor.") % Clock.fmt_short(int(board["expires"])), 8, Art.C_RED, 520))
			for c in Fundraising.board_choices(deal):
				box.add_child(UIK.wrap(str(c["detail"]), 8, Art.C_MUTED, 520))
				var b := _act(box, str(c["label"]), "Board_" + str(c["id"]), func(): _say(Fundraising.board_decide(str(deal["id"]), str(c["id"])), I18n.t("The board review is closed.")))
				b.disabled = str(c["block"]) != ""
				if str(c["block"]) != "":
					box.add_child(UIK.wrap("✗ " + str(c["block"]), 8, Art.C_MUTED, 520))
		for r in Fundraising.S()["reports"]:
			if r["deal"] != deal["id"]:
				continue
			var verdict := I18n.t("report only") if r["met"] == null else (I18n.t("milestone met") if r["met"] else I18n.t("milestone missed"))
			box.add_child(UIK.wrap(I18n.t("Quarter %d (%s): revenue %s, target %s, %s.") % [int(r["n"]), Clock.fmt_short(int(r["at"])), Fmt.money(float(r["actual"])), Fmt.money(float(r["target"])), verdict], 8, Art.C_WHITE, 520))
	if not any:
		box.add_child(UIK.wrap("No investor reports yet. They begin once a round is signed.", 8, Art.C_MUTED, 520))


# ------------------------------------------------------------------ partnerships
func _partners(box: VBoxContainer) -> void:
	if partner_sel != "":
		_partner(box, partner_sel)
		return
	box.add_child(UIK.wrap("A partnership is a contract: the partner issues real jobs, pays after the job's terms, and takes a share of what it pays. An exclusive deal pays more but shuts out rivals of the same kind.", 8, Art.C_MUTED, 520))
	for id in Fundraising.cfg()["partners"]:
		var d := Partnerships.def(id)
		box.add_child(UIK.title("%s · %s" % [Partnerships.name_of(id), Partnerships.kind_label(str(d["kind"]))], 10, Art.C_SKY))
		box.add_child(UIK.wrap(I18n.t(str(d["blurb"])), 8, Art.C_WHITE, 520))
		var item := Partnerships.item_for(id)
		var why := Partnerships.block(id)
		var state := I18n.t("Active") if not item.is_empty() and item["status"] == "active" else (I18n.t("Proposal waiting") if not item.is_empty() else (I18n.t(why) if why != "" else I18n.t("Ready to propose")))
		box.add_child(UIK.wrap(state, 8, Art.C_SKY, 520))
		_act(box, "Open", "Partner_" + id, func():
			partner_sel = id
			notice = ""
			rebuild())


func _partner(box: VBoxContainer, id: String) -> void:
	var d := Partnerships.def(id)
	var t := Partnerships.terms_for(id)
	box.add_child(UIK.title("%s · %s" % [Partnerships.name_of(id), Partnerships.kind_label(str(d["kind"]))], 11, Art.C_SKY))
	box.add_child(UIK.wrap(I18n.t(str(d["blurb"])), 8, Art.C_WHITE, 520))
	var item := Partnerships.item_for(id)
	if item.is_empty():
		_partner_history(box, id)
		var why := Partnerships.block(id)
		if why != "":
			box.add_child(UIK.wrap("✗ " + I18n.t(why), 8, Art.C_MUTED, 520))
		else:
			_terms_preview(box, t, false)
			_act(box, "Ask for a proposal", "ProposePartner", func(): _say(Partnerships.propose(id), I18n.t("The partner sent its terms.")), true)
	elif item["status"] == "offered":
		_terms_preview(box, item["terms"], false)
		box.add_child(UIK.kv("Exclusive deal: price per deliverable", Fmt.money(float(item["terms"]["exclusive_price"]))))
		box.add_child(UIK.kv("Exclusive for", I18n.t("%d days") % int(item["terms"]["exclusive_days"])))
		box.add_child(UIK.kv("Net per deliverable (open terms)", Fmt.money(Partnerships.net_per_period(item["terms"], false))))
		box.add_child(UIK.kv("Net per deliverable (exclusive terms)", Fmt.money(Partnerships.net_per_period(item["terms"], true))))
		_act(box, "Sign the open terms", "SignOpen", func(): _say(Partnerships.sign_deal(str(item["id"]), false), I18n.t("Signed. The first deliverable is waiting.")), true)
		_act(box, "Sign the exclusive terms", "SignExclusive", func(): _say(Partnerships.sign_deal(str(item["id"]), true), I18n.t("Signed. The first deliverable is waiting.")))
		_act(box, "Decline", "DeclinePartner", func(): _say(Partnerships.decline(str(item["id"])), I18n.t("You declined the proposal.")))
	else:
		_active_partner(box, item)
	_act(box, "Back to partners", "BackPartners", func():
		partner_sel = ""
		notice = ""
		rebuild())


func _terms_preview(box: VBoxContainer, t: Dictionary, _excl: bool) -> void:
	box.add_child(UIK.kv("Price per deliverable", Fmt.money(float(t["price"]))))
	box.add_child(UIK.kv("Deliverables", "%d × %d days" % [int(t["periods"]), int(t["period_days"])]))
	box.add_child(UIK.kv("Partner's share of what it pays", Fmt.pct(float(t["share"]))))
	box.add_child(UIK.kv("Work and supplies per deliverable", "%s · %s" % [Fmt.duration_min(int(t["minutes"])), Fmt.money(float(t["supplies"]))]))


func _partner_history(box: VBoxContainer, id: String) -> void:
	for item in Partnerships.P().values():
		if item["partner"] == id and not Partnerships.is_live(item):
			box.add_child(UIK.wrap(I18n.t("Earlier agreement: %s. Delivered %d, paid %d, shared %s.") % [I18n.t(str(item["status"]).capitalize()), int(item["delivered"]), int(item["paid"]), Fmt.money(float(item["share_paid"]))], 8, Art.C_MUTED, 520))


func _active_partner(box: VBoxContainer, item: Dictionary) -> void:
	box.add_child(UIK.kv("Price per deliverable", Fmt.money(float(item["price"]))))
	box.add_child(UIK.kv("Partner's share of what it pays", Fmt.pct(float(item["terms"]["share"]))))
	box.add_child(UIK.kv("Deliverables issued / done / paid", "%d / %d / %d (%d)" % [int(item["issued"]), int(item["delivered"]), int(item["paid"]), int(item["terms"]["periods"])]))
	box.add_child(UIK.kv("Shared with the partner so far", Fmt.money(float(item["share_paid"]))))
	if bool(item["exclusive"]):
		box.add_child(UIK.wrap(I18n.t("Exclusive until %s: you cannot sign another %s deal until then.") % [Clock.fmt_short(int(item["exclusive_until"])), Partnerships.kind_label(str(item["kind"])).to_lower()], 8, Art.C_SKY, 520))
	var job := Partnerships.current_job(item)
	if not job.is_empty():
		box.add_child(UIK.wrap(I18n.t("Waiting: %s, due %s.") % [str(job["scope"]), Clock.fmt_short(int(job["due"]))], 8, Art.C_WHITE, 520))
		_act(box, "Do this deliverable", "PartnerWork", func(): _say(Partnerships.work(str(item["id"])), I18n.t("Delivered and invoiced. The partner pays after the job's terms.")), true)
	else:
		box.add_child(UIK.wrap("No deliverable is waiting. The next one arrives on its date.", 8, Art.C_MUTED, 520))
	_act(box, "End this agreement", "EndPartnership", func(): _say(Partnerships.terminate(str(item["id"])), I18n.t("The agreement has ended.")))


# ------------------------------------------------------------------ community round
func _community(box: VBoxContainer) -> void:
	var c: Dictionary = Fundraising.cfg()["crowd"]
	box.add_child(UIK.wrap("A community round sells small equity stakes to customers and fans for an all-or-nothing goal. The promotion is a real cost; if the goal is missed every pledge is returned and nothing is raised.", 8, Art.C_MUTED, 520))
	for camp in Fundraising.S()["campaigns"].values():
		var line: String
		match str(camp["status"]):
			"running":
				line = I18n.t("Running until %s. Goal %s.") % [Clock.fmt_short(int(camp["ends"])), Fmt.money(float(camp["goal"]))]
			"funded":
				line = I18n.t("Funded: %s from %d backers for %s of the company.") % [Fmt.money(float(camp["raised"])), int(camp["backers"]), Fmt.pct(float(camp["stake"]), 1)]
			_:
				line = I18n.t("Missed: %s pledged against a %s goal. Every pledge was returned.") % [Fmt.money(float(camp.get("pledged", 0))), Fmt.money(float(camp["goal"]))]
		box.add_child(UIK.wrap(line, 8, Art.C_WHITE, 520))
	var why := Fundraising.crowd_block()
	if why != "":
		box.add_child(UIK.wrap("✗ " + I18n.t(why), 8, Art.C_MUTED, 520))
		return
	var goals: Array = Fundraising.crowd_goals()
	if goals.is_empty():
		box.add_child(UIK.wrap("The company's value is too small for a community round yet.", 8, Art.C_MUTED, 520))
		return
	if not goals.has(crowd_goal):
		crowd_goal = float(goals[0])
	if not c["promos"].has(crowd_promo):
		crowd_promo = float(c["promos"][0])
	box.add_child(MiniGame.choice_row("Goal", goals.map(func(v): return [str(v), Fmt.money0(float(v))]), str(crowd_goal), func(v):
		crowd_goal = float(v)
		rebuild(), "Goal"))
	box.add_child(MiniGame.choice_row("Promotion", c["promos"].map(func(v): return [str(v), Fmt.money0(float(v))]), str(crowd_promo), func(v):
		crowd_promo = float(v)
		rebuild(), "Promo"))
	box.add_child(UIK.wrap(I18n.t("Choose up to %d figures from your books for the campaign page.") % int(c["page_facts"]), 8, Art.C_SKY, 520))
	for f in Fundraising.facts():
		var on: bool = crowd_page.has(f["id"])
		var b := UIK.button(("☑ " if on else "☐ ") + "%s: %s" % [I18n.t(str(f["label"])), str(f["text"])], func():
			if on:
				crowd_page.erase(f["id"])
			elif crowd_page.size() < int(c["page_facts"]):
				crowd_page.append(f["id"])
			rebuild(), "tab_active" if on else "tab")
		b.name = "PageFact_" + str(f["id"])
		box.add_child(b)
	_act(box, "Launch the campaign", "LaunchCampaign", func(): _say(Fundraising.crowd_start(crowd_goal, crowd_promo, crowd_page), I18n.t("The campaign is live.")), true)
