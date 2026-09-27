class_name MonthCloseModal
extends Modal
## Month Close (kickoff §13). Profit and cash side by side — they are not the same number.

var rep: Dictionary


func _init(r: Dictionary) -> void:
	rep = r
	title_text = "Month Close — %s" % r.get("label", "")
	icon_name = "finance"
	panel_size = Vector2(520, 320)


func build() -> void:
	var cols := UIK.hbox(10)
	body.add_child(cols)
	for eid in rep["entities"]:
		var e: Dictionary = rep["entities"][eid]
		var v := UIK.vbox(1)
		v.custom_minimum_size = Vector2(240, 0)
		cols.add_child(v)
		v.add_child(UIK.label(str(e["name"]).to_upper(), 8, Art.C_GOLD, true))
		v.add_child(UIK.kv("Revenue", Fmt.money(e["revenue"])))
		v.add_child(UIK.kv("Refunds", Fmt.money(-e["refunds"]), Art.C_RED))
		v.add_child(UIK.kv("COGS", Fmt.money(-e["cogs"]), Art.C_RED))
		v.add_child(UIK.kv("Gross profit", Fmt.money(e["gross_profit"]), UIK.money_color(e["gross_profit"]), 8, true))
		v.add_child(UIK.kv("Advertising", Fmt.money(-e["advertising"]), Art.C_RED))
		v.add_child(UIK.kv("Shipping", Fmt.money(-e["shipping"]), Art.C_RED))
		var other_opex := float(e["opex_total"]) - float(e["advertising"]) - float(e["shipping"]) - float(e["rent_office"])
		v.add_child(UIK.kv("Other operating expense", Fmt.money(-other_opex), Art.C_RED))
		v.add_child(UIK.kv("Rent (office)", Fmt.money(-e["rent_office"]), Art.C_RED))
		v.add_child(UIK.kv("Business profit", Fmt.money(e["business_profit"]), UIK.money_color(e["business_profit"]), 9, true))
		if float(e["personal_total"]) > 0.0:
			v.add_child(UIK.kv("Rent (home) + living", Fmt.money(-e["personal_total"]), Art.C_RED))
			v.add_child(UIK.kv("Profit after life costs", Fmt.money(e["profit"]), UIK.money_color(e["profit"]), 8, true))
		v.add_child(UIK.sep())
		v.add_child(UIK.kv("Cash — start of month", Fmt.money(e["cash_open"])))
		if absf(float(e.get("owner_moves", 0.0))) > 0.01:
			v.add_child(UIK.kv("Owner money in / out", Fmt.money(e["owner_moves"], true), Art.C_SKY))
		v.add_child(UIK.kv("Cash — end of month", Fmt.money(e["cash_close"]), UIK.money_color(e["cash_close"]), 9, true))
		v.add_child(UIK.kv("Owed to you (ShopLane + invoices)", Fmt.money(e["ar"]), Art.C_GOLD))
		v.add_child(UIK.kv("You owe (suppliers)", Fmt.money(e["ap"]), Art.C_GOLD))
		v.add_child(UIK.kv("Stock at cost", Fmt.money(e["inventory"]), Art.C_SKY))
	var main: Dictionary = rep["entities"].values()[-1]
	var diff := float(main["profit"]) - float(main["cash_change"])
	body.add_child(UIK.sep())
	body.add_child(UIK.wrap("Profit this month: %s. Cash moved by %s. The gap (%s) is sitting in stock, in ShopLane's hands, or in unpaid invoices." % [Fmt.money(main["profit"]), Fmt.money(main["cash_change"], true), Fmt.money(diff)], 8, Art.C_SKY, 490))
	footer.add_child(UIK.button("Continue", close, "primary", 80))
