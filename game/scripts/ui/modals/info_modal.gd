class_name InfoModal
extends Modal
## Simple readable content: news board, loan brochure, permits kiosk, whiteboard.

var lines: Array = []


static func make(t: String, ic: String, ls: Array, size := Vector2(380, 220)) -> InfoModal:
	var m := InfoModal.new()
	m.title_text = t
	m.icon_name = ic
	m.lines = ls
	m.panel_size = size
	return m


func build() -> void:
	var v := UIK.vbox(4)
	for l in lines:
		if typeof(l) == TYPE_ARRAY:
			v.add_child(UIK.kv(str(l[0]), str(l[1]), l[2] if l.size() > 2 else Art.C_WHITE))
		elif str(l).begins_with("# "):
			v.add_child(UIK.label(str(l).substr(2), 8, Art.C_GOLD, true))
		elif str(l) == "---":
			v.add_child(UIK.sep())
		else:
			v.add_child(UIK.wrap(str(l), 8, Art.C_WHITE, 350))
	body.add_child(UIK.scroll(v, Vector2(360, panel_size.y - 70)))
	footer.add_child(UIK.button("Close", close, "", 70))


static func news() -> InfoModal:
	Clock.advance(5)
	var y := DataDB.year_def(int(GameState.data["world"]["year"]))
	var ls: Array = [I18n.t("# AURELIA DAILY · Year %d — %s") % [int(y.get("year", 1)), y.get("name", "")]]
	for h in y.get("headlines", []):
		ls.append("• " + str(h))
	ls.append("---")
	ls.append("# MARKET NOTES")
	ls.append(I18n.t("• Base rate: %s. Credit is cheap — for now.") % Fmt.pct(float(y.get("interest_rate", 0.025)), 1))
	ls.append(I18n.t("• Shipping index: %.2f (1.00 = normal).") % float(y.get("shipping_index", 1.0)))
	ls.append("• ShopLane fee 10%%. Payouts every Monday.")
	return make("News board", "info", ls)


static func whiteboard() -> InfoModal:
	var be := GameState.business_entity()
	var cur := MonthClose.current(be)
	return make("Whiteboard", "tasks", ["# IDEAS · PEOPLE · PRODUCT · GROWTH",
		["This month revenue", Fmt.money(cur["net_revenue"])], ["Gross profit", Fmt.money(cur["gross_profit"])],
		["Operating costs", Fmt.money(cur["opex_total"])], ["Cash in bank", Fmt.money(Ledger.cash(be))],
		["Waiting at ShopLane", Fmt.money(Ledger.balance(be, "marketplace_balance"))], "---",
		"Scribbled in the corner: 'profit is an opinion, cash is a fact.'"])
