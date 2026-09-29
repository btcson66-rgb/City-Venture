class_name LoanModal
extends Modal
## Nexus Bank business lending with Marcus Reed. Shows the credit score, what the books support and
## why, lets the player pick an amount and term (monthly payment shown up front), and lists
## existing loans with early repayment. Only Marcus can sign a new loan (`officer`).

var officer := false
var pick := 0.5
var months := 12


func _init(with_officer := false) -> void:
	officer = with_officer
	title_text = "Nexus Bank — Business lending"
	icon_name = "bank"
	help_key = "loans"
	panel_size = Vector2(470, 300)


func build() -> void:
	var top := UIK.hbox(8)
	body.add_child(top)
	top.add_child(UIK.label(I18n.t("Credit score %d · %s") % [Bank.credit(), I18n.t(Bank.credit_band())], 9,
		Art.C_GREEN if Bank.credit() >= 690 else (Art.C_GOLD if Bank.credit() >= 620 else Art.C_RED), true))
	top.add_child(UIK.expand())
	top.add_child(UIK.label(I18n.t("Base rate %s") % Fmt.pct(Bank.base_rate(), 1), 7, Art.C_MUTED))
	var cols := UIK.hbox(10)
	body.add_child(cols)
	var left := UIK.vbox(3)
	left.custom_minimum_size = Vector2(230, 0)
	cols.add_child(left)
	var o := Bank.offer()
	if not o["ok"]:
		left.add_child(UIK.label("MARCUS REED", 7, Art.C_DIM, true))
		left.add_child(UIK.wrap("\"" + I18n.t(str(o["error"])) + "\"", 8, Art.C_GOLD, 226))
		left.add_child(UIK.wrap("I lend on cash flow and collateral: gross profit, money owed to you, signed contracts and stock.", 7, Art.C_MUTED, 226))
	else:
		left.add_child(UIK.label("WHAT YOUR BOOKS SUPPORT", 7, Art.C_DIM, true))
		for r in o["reasons"]:
			left.add_child(UIK.kv(str(r[0]), Fmt.money0(float(r[1])), Art.C_WHITE if float(r[1]) >= 0 else Art.C_RED, 7))
		left.add_child(UIK.kv("Up to", Fmt.money0(float(o["max"])), Art.C_GREEN, 9, true))
		left.add_child(UIK.kv("Interest (APR)", Fmt.pct(float(o["apr"]), 1), Art.C_GOLD, 8))
		var amt := _amount(o)
		var ah := UIK.hbox(3)
		left.add_child(ah)
		for f in [0.25, 0.5, 0.75, 1.0]:
			var b := UIK.button(Fmt.money0(floorf(float(o["max"]) * f / 1000.0) * 1000.0), func(): pick = f; rebuild(), "tab_active" if is_equal_approx(pick, f) else "tab")
			b.name = "Amt_%d" % int(f * 100)
			ah.add_child(b)
		var th := UIK.hbox(3)
		left.add_child(th)
		for m in [6, 12, 24]:
			var tb := UIK.button(I18n.t("%d months") % m, func(): months = m; rebuild(), "tab_active" if months == m else "tab")
			tb.name = "Term_%d" % m
			th.add_child(tb)
		var pmt := Bank.monthly_payment(amt, months)
		left.add_child(UIK.kv("Monthly payment", Fmt.money(pmt), Art.C_WHITE, 8, true))
		left.add_child(UIK.kv("Total interest", Fmt.money(pmt * months - amt), Art.C_MUTED, 7))
		if officer:
			var tk := UIK.button(I18n.t("Borrow %s") % Fmt.money0(amt), _take, "primary")
			tk.name = "TakeLoan"
			left.add_child(tk)
		else:
			left.add_child(UIK.wrap("Marcus Reed signs loans in person (weekdays 13:00–16:00, Nexus Bank).", 7, Art.C_SKY, 226))
	var right := UIK.vbox(3)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	right.add_child(UIK.label("YOUR LOANS", 7, Art.C_DIM, true))
	var ls := Bank.loans()
	if ls.is_empty():
		right.add_child(UIK.label("None.", 7, Art.C_DIM))
	for l in ls:
		var p := UIK.panel("ui/card", 4)
		right.add_child(p)
		var v := UIK.vbox(1)
		p.add_child(v)
		var status_col := Art.C_GREEN if l["status"] == "active" else Art.C_RED
		v.add_child(UIK.label("%s · %s" % [l["id"], CompanyOS.status_text(l["status"])], 8, status_col, true))
		v.add_child(UIK.kv("Balance", Fmt.money(float(l["balance"])), Art.C_WHITE, 7))
		v.add_child(UIK.kv("Payment", I18n.t("%s on %s") % [Fmt.money(float(l["payment"])), Clock.fmt_date(int(l["next"]))], Art.C_MUTED, 7))
		var lid: String = l["id"]
		var rh := UIK.hbox(3)
		v.add_child(rh)
		var r1 := UIK.button(I18n.t("Repay %s") % Fmt.money0(1000.0), func(): _repay(lid, 1000.0))
		r1.name = "Repay1k_" + lid
		rh.add_child(r1)
		var r2 := UIK.button("Pay off", func(): _repay(lid, float(l["balance"])))
		r2.name = "PayOff_" + lid
		rh.add_child(r2)
	footer.add_child(UIK.button("Close", close, "", 70))


func _amount(o: Dictionary) -> float:
	return maxf(1000.0, floorf(float(o["max"]) * pick / 1000.0) * 1000.0)


func _take() -> void:
	var o := Bank.offer()
	if not o["ok"]:
		UIRoot.toast(I18n.t(str(o["error"])), "warn", "bank")
		return
	var r := Bank.take_loan(_amount(o), months)
	if not r["ok"]:
		UIRoot.toast(I18n.t(str(r["error"])), "warn", "bank")
		return
	Clock.advance(30)
	UIRoot.toast(I18n.t("%s is in the company account. First payment in 30 days.") % Fmt.money0(float(r["loan"]["principal"])), "good", "bank")
	rebuild()


func _repay(id: String, amt: float) -> void:
	var r := Bank.repay(id, amt)
	if not r["ok"]:
		UIRoot.toast(I18n.t(str(r["error"])), "warn", "bank")
	rebuild()
