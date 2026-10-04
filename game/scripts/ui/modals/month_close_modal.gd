class_name MonthCloseModal
extends Modal
## Month Close (kickoff §13). Profit and cash side by side — they are not the same number.

var rep: Dictionary


func _init(r: Dictionary) -> void:
	pauses_time = true
	rep = r
	title_text = I18n.t("Month Close — %s") % MonthClose.label_of(r)
	icon_name = "finance"
	help_key = "month_close"
	panel_size = Vector2(520, 320)


func build() -> void:
	var cols := UIK.hbox(10)
	# scrolls if a language's taller line height (or more entities) would push the footer off-screen
	var reports_scroll := UIK.scroll(cols, Vector2(500, 226))
	# Multiple companies must scroll inside the report, keeping Continue within the viewport.
	reports_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	body.add_child(reports_scroll)
	for eid in rep["entities"]:
		var e: Dictionary = rep["entities"][eid]
		var v := UIK.vbox(1)
		v.custom_minimum_size = Vector2(240, 0)
		cols.add_child(v)
		v.add_child(UIK.label(I18n.t(str(e["name"])).to_upper(), 8, Art.C_GOLD, true))
		v.add_child(UIK.kv_tip("Revenue", Fmt.money(e["revenue"]), "revenue"))
		v.add_child(UIK.kv("Refunds", Fmt.money(-e["refunds"]), Art.C_RED))
		v.add_child(UIK.kv_tip("COGS", Fmt.money(-e["cogs"]), "cogs", Art.C_RED))
		v.add_child(UIK.kv_tip("Gross profit", Fmt.money(e["gross_profit"]), "gross_margin", UIK.money_color(e["gross_profit"]), 8, true))
		v.add_child(UIK.kv("Realized exchange gain / loss", Fmt.money(float(e.get("fx_gain_loss", 0)), true)))
		var ch: Dictionary = OverseasPartners.S()["chapters"].get("ch15_currency_swing", {})
		if not ch.is_empty() and e["entity"] == ch["entity"] and int(rep["t1"]) > int(ch["started"]):
			GameState.set_flag("fx_month_viewed")
		v.add_child(UIK.kv("Advertising", Fmt.money(-e["advertising"]), Art.C_RED))
		v.add_child(UIK.kv("Shipping", Fmt.money(-e["shipping"]), Art.C_RED))
		var other_opex := float(e["opex_total"]) - float(e["advertising"]) - float(e["shipping"]) - float(e["rent_office"])
		v.add_child(UIK.kv_tip("Other operating expense", Fmt.money0(-other_opex), "opex", Art.C_RED))
		v.add_child(UIK.kv("Rent (premises)", Fmt.money0(-e["rent_office"]), Art.C_RED))
		v.add_child(UIK.kv_tip("Business profit", Fmt.money0(e["business_profit"]), "cash_vs_profit", UIK.money_color(e["business_profit"]), 9, true))
		if float(e.get("wages", 0.0)) > 0.0:
			v.add_child(UIK.kv("Wages from your job", Fmt.money0(e["wages"]), Art.C_GREEN))
		if float(e["personal_total"]) > 0.0 or float(e.get("wages", 0.0)) > 0.0:
			v.add_child(UIK.kv("Rent (home) + living", Fmt.money0(-e["personal_total"]), Art.C_RED))
			v.add_child(UIK.kv("Profit after life costs", Fmt.money0(e["profit"]), UIK.money_color(e["profit"]), 8, true))
		v.add_child(UIK.sep())
		v.add_child(UIK.kv("Cash — start of month", Fmt.money0(e["cash_open"])))
		if absf(float(e.get("owner_moves", 0.0))) > 0.01:
			v.add_child(UIK.kv("Owner money in / out", Fmt.money0(e["owner_moves"], true), Art.C_SKY))
		v.add_child(UIK.kv_tip("Cash — end of month", Fmt.money0(e["cash_close"]), "cash_vs_profit", UIK.money_color(e["cash_close"]), 9, true))
		v.add_child(UIK.kv_tip("Owed to you (ShopLane + invoices)", Fmt.money0(e["ar"]), "accounts_receivable", Art.C_GOLD))
		v.add_child(UIK.kv("You owe (suppliers)", Fmt.money0(e["ap"]), Art.C_GOLD))
		v.add_child(UIK.kv("Stock at cost", Fmt.money0(e["inventory"]), Art.C_SKY))
	var main: Dictionary = rep["entities"].values()[-1]
	# compare profit with the cash the business itself generated (owner money in/out is not profit)
	var op_cash := float(main["cash_change"]) - float(main.get("owner_moves", 0.0))
	var diff := float(main["profit"]) - op_cash
	body.add_child(UIK.sep())
	body.add_child(UIK.wrap(I18n.t("Profit this month: %s. Cash moved by %s. The gap (%s) is sitting in stock, in ShopLane's hands, or in unpaid invoices.") % [Fmt.money0(main["profit"]), Fmt.money0(op_cash, true), Fmt.money0(diff)], 8, Art.C_SKY, 490))
	footer.add_child(UIK.button("Continue", close, "primary", 80))
