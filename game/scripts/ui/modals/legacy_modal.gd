class_name LegacyModal
extends Modal
## Current market step, ending choices and resumable five-card epilogue.

func _init() -> void:
	title_text = "Consolidation and legacy"
	icon_name = "company"
	help_key = "legacy"
	panel_size = Vector2(500, 340)
	pauses_time = true

func add_action(box: VBoxContainer, label: String, name_v: String, action: Callable, primary := false) -> Button:
	var b := UIK.button(label, action, "primary" if primary else "")
	b.name = name_v
	box.add_child(b)
	return b

func result(r: Dictionary) -> void:
	if not r.get("ok", false):
		UIRoot.toast(I18n.t(str(r.get("error", ""))), "warn", "info")
	rebuild()

func build() -> void:
	LegacyBusiness.reconcile()
	var box := UIK.vbox(4)
	body.add_child(UIK.scroll(box, Vector2(468, 268)))
	if LegacyBusiness.S()["ending"] != "":
		epilogue(box)
	elif GameState.flag("legacy_invited"):
		ending_choices(box)
	else:
		market_response(box)

func market_response(box: VBoxContainer) -> void:
	var m := LegacyBusiness.market()
	if m.is_empty():
		box.add_child(UIK.wrap("This story opens after the overseas partner chapter.", 8, Art.C_MUTED, 452))
		return
	box.add_child(UIK.label_tip("Market consolidation", "market_consolidation", 10, Art.C_SKY, true))
	box.add_child(UIK.wrap(I18n.t("%s is cutting prices in %s. The demand shock fades over %d days.") % [LegacyBusiness.rival(), LegacyBusiness.region_name(), int(LegacyBusiness.cfg()["rival_days"])], 8, Art.C_WHITE, 452))
	if m["branch"] != "independent":
		box.add_child(UIK.wrap("You manage a Hale Group division. The revenue goal is a management benchmark; the chapter only requires continued operations, not growth.", 8, Art.C_WHITE, 452))
		box.add_child(UIK.kv("Revenue benchmark (home dollars / 60 days)", Fmt.money0(float(LegacyBusiness.cfg()["division_revenue_goal"]))))
	else:
		box.add_child(UIK.kv("Victor's second offer (home dollars)", Fmt.money0(float(m["second_offer"]))))
		box.add_child(UIK.wrap("The call is a lower repeat offer. Compare the operating choices; the final ownership decision remains in the legacy chapter.", 7, Art.C_MUTED, 452))
	if GameState.flag("consolidation_unavailable"):
		box.add_child(UIK.wrap("This market is no longer available. Review the closure and continue.", 8, Art.C_SKY, 452))
		add_action(box, "Review unavailable market", "review_unavailable_market", func(): LegacyBusiness.review_unavailable(); rebuild(), true)
		return
	if not GameState.flag("consolidation_news_read"):
		add_action(box, "Read the consolidation news", "read_consolidation_news", func():
			var news := InfoModal.news()
			news.closed.connect(rebuild)
			UIRoot.open_modal(news), true)
		return
	box.add_child(UIK.label_tip("Niche or scale", "niche_vs_scale"))
	if int(m["responded"]) < 0:
		for route in ["niche", "scale"]:
			var chosen: bool = m["strategy"] == route
			add_action(box, I18n.t("Niche" if route == "niche" else "Scale") + (" ✓" if chosen else ""), "Strategy_" + route, func(): result(LegacyBusiness.choose(route)))
			box.add_child(UIK.wrap("Raise price; use good reviews or pay for a brand campaign. Fewer buyers, lower price sensitivity." if route == "niche" else "Lower price and buy additional inventory. More buyers, thinner margins and more cash tied up in stock.", 7, Art.C_MUTED, 452))
		box.add_child(UIK.kv("Good-review threshold (reviews)", str(int(LegacyBusiness.cfg()["good_reviews"]))))
		box.add_child(UIK.kv("Brand campaign fee (home dollars)", Fmt.money(float(LegacyBusiness.cfg()["brand_ad_fee"]))))
		box.add_child(UIK.kv("Additional scale stock (units)", str(int(LegacyBusiness.cfg()["scale_extra_units"]))))
		var why := LegacyBusiness.response_block()
		if str(m["strategy"]) != "":
			var commit := add_action(box, "Apply price and operating response", "apply_market_response", func(): result(LegacyBusiness.respond()), why == "")
			commit.disabled = why != ""
			box.add_child(UIK.wrap(("✓ " + I18n.t("Ready to apply the response.")) if why == "" else "✗ " + I18n.t(why), 7, Art.C_SKY, 452))
			if why != "":
				add_action(box, "Review unavailable market", "review_unavailable_market", func(): LegacyBusiness.review_unavailable(); rebuild())
	else:
		var days := maxi(0, (Clock.now() - int(m["responded"])) / Clock.DAY)
		box.add_child(UIK.wrap(I18n.t("Operating period: %d of %d days. Continue actual orders, costs and restocking; no revenue target is required.") % [days, int(LegacyBusiness.cfg()["survival_days"])], 8, Art.C_WHITE, 452))
		if GameState.flag("consolidation_survived"):
			add_action(box, "Accept Kai's interview", "kai_interview", func(): result(LegacyBusiness.interview()), true)
		else:
			add_action(box, "Continue operating", "continue_market_operations", close, true)
	box.add_child(UIK.label_tip("Price elasticity", "price_elasticity"))
	var r := LegacyBusiness.report()
	box.add_child(UIK.kv("Recorded market revenue (home dollars)", Fmt.money(r["revenue"])))
	box.add_child(UIK.kv("Market share (model estimate)", Fmt.pct(r["share_estimate"])))
	add_action(box, "Compare 90-day assumptions", "compare_consolidation", func(): UIRoot.open_modal(LegacyBusiness.comparison()))

func ending_choices(box: VBoxContainer) -> void:
	box.add_child(UIK.label_tip("Exit options", "exit_options", 10, Art.C_SKY, true))
	if not GameState.flag("legacy_met_maya"):
		add_action(box, "Call Maya or meet at Bloom Coffee", "meet_maya_legacy", func():
			UIRoot.close_all()
			UIRoot.play_dialogue.call_deferred("maya_legacy", func(): UIRoot.open_modal(LegacyModal.new())), true)
		return
	for choice in ["independent", "sale", "employees", "mentor"]:
		var why := LegacyBusiness.ending_block(choice)
		var b := add_action(box, LegacyBusiness.ending_title(choice), "LegacyChoice_" + choice, func(): result(LegacyBusiness.end_story(choice)))
		b.disabled = why != ""
		box.add_child(UIK.wrap(I18n.t({"independent": "Keep the current business and ownership; continue free play.", "sale": "Use today's Chapter 12 valuation. Previous sales never pay twice, and a closed company cannot be sold.", "employees": "Board-approved transfer of existing shares to the team, with an equity journal and no fabricated income.", "mentor": "Mentor at Nexus Co-work. A contract manager packs real orders and bills monthly; unpaid fees suspend the service."}[choice]), 7, Art.C_MUTED, 452))
		if why != "":
			box.add_child(UIK.wrap("✗ " + I18n.t(why), 7, Art.C_SKY, 452))
	box.add_child(UIK.label_tip("Employee ownership", "employee_ownership"))
	box.add_child(UIK.kv("Current valuation (home dollars)", Fmt.money0(Acquisition.quote()["price"])))
	box.add_child(UIK.kv("Founder sale proceeds (home dollars)", Fmt.money(Acquisition.quote()["take"])))
	if float(Acquisition.quote()["price"]) <= 0:
		box.add_child(UIK.wrap("✗ No capitalized company to sell. Open a business account or choose another ending; no sale payment is made.", 7, Art.C_MUTED, 452))
	box.add_child(UIK.kv("Contract manager (home dollars / month)", Fmt.money(float(LegacyBusiness.cfg()["manager_monthly_fee"]))))

func epilogue(box: VBoxContainer) -> void:
	var s := LegacyBusiness.S()
	var viewed := int(s["viewed"])
	if viewed >= s["cards"].size():
		box.add_child(UIK.wrap("Your ending is recorded. Free play continues from the actual books.", 9, Art.C_WHITE, 452))
		add_action(box, "Review this life", "legacy_life_review", func(): LifeLegacy.review(); UIRoot.open_modal(LifeReviewModal.new()))
		add_action(box, "Return to free play", "legacy_free_play", close, true)
		add_action(box, "Revisit the ending cards", "legacy_replay_cards", func(): s["viewed"] = 0; rebuild())
		return
	var card: Dictionary = s["cards"][viewed]
	box.add_child(UIK.title(str(card["title"]), 11))
	for line in card["lines"]:
		box.add_child(UIK.wrap(str(line), 8, Art.C_WHITE, 452))
	box.add_child(UIK.wrap(I18n.t("Epilogue card %d of %d") % [viewed + 1, s["cards"].size()], 7, Art.C_MUTED, 452))
	add_action(box, "Next card" if viewed + 1 < s["cards"].size() else "Finish epilogue", "legacy_next_card", func():
		LegacyBusiness.view_next()
		rebuild()
		if GameState.flag("legacy_cards_viewed"):
			LifeLegacy.review()
			UIRoot.open_modal(LifeReviewModal.new()), true)
