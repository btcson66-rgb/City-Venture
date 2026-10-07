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
	panel_size = Vector2(570, 300)
	pauses_time = true


func build() -> void:
	var top := UIK.hbox(8)
	body.add_child(top)
	top.add_child(UIK.label(I18n.t("Credit score %d points · %s") % [Bank.credit(), I18n.t(Bank.credit_band())], 9,
		Art.C_GREEN if Bank.credit() >= 690 else (Art.C_SKY if Bank.credit() >= 620 else Art.C_RED), true))
	top.add_child(UIK.tip("loan_eligibility"))
	top.add_child(UIK.tip("credit_history"))
	top.add_child(UIK.expand())
	top.add_child(UIK.label_tip(I18n.t("Base rate %s") % Fmt.pct(Bank.base_rate(), 1), "interest_rate", 7, Art.C_MUTED))
	var cols := UIK.hbox(10)
	body.add_child(UIK.scroll(cols, Vector2(548, 215)))
	var left := UIK.vbox(3)
	left.custom_minimum_size = Vector2(230, 0)
	cols.add_child(left)
	var o := Bank.offer()
	var requirements := Bank.eligibility()
	var prerequisite := ""
	for requirement in requirements:
		if prerequisite == "" and requirement["id"] in ["company", "account"] and not requirement["ok"]:
			prerequisite = requirement["id"]
	if not o["ok"]:
		for requirement in requirements:
			var row := UIK.vbox(3)
			row.name = "Eligibility_" + str(requirement["id"])
			left.add_child(row)
			var mark := "✓" if requirement["ok"] else "✗"
			# F6: two lines per requirement (verdict with the one gap number, then the next step); the full figures sit in the tooltip.
			var gap := ""
			var detail := ""
			if requirement["id"] == "capacity":
				gap = I18n.t("gap %s") % Fmt.money0(float(requirement["gap"]))
				detail = I18n.t("Current %s · required %s · gap %s") % [Fmt.money0(float(requirement["value"])), Fmt.money0(float(requirement["need"])), Fmt.money0(float(requirement["gap"]))]
			elif requirement["id"] == "age":
				gap = I18n.t("%d more days") % int(requirement["gap"])
				detail = I18n.t("Current %d days · required %d days · %d more days") % [int(requirement["value"]), int(requirement["need"]), int(requirement["gap"])]
			elif not requirement["id"] in ["company", "account", "arrears"]:
				gap = I18n.t("gap %s") % (I18n.t("%d points") % int(requirement["gap"]))
				detail = I18n.t("Current %s · required %s · gap %s") % [I18n.t("%d points") % int(requirement["value"]), I18n.t("%d points") % int(requirement["need"]), I18n.t("%d points") % int(requirement["gap"])]
			var head := UIK.wrap(mark + " " + I18n.t(requirement["label"]) + ((" · " + gap) if gap != "" and not requirement["ok"] else ""), 8, Art.C_GREEN if requirement["ok"] else Art.C_RED, 240)
			head.tooltip_text = detail
			head.mouse_filter = Control.MOUSE_FILTER_PASS
			row.add_child(head)
			row.add_child(UIK.wrap(requirement["hint_action"], 7, Art.C_SKY, 240))
		left.add_child(UIK.label("WHAT YOUR BOOKS SUPPORT", 7, Art.C_DIM, true))
		for part in Bank.lending_basis()["parts"]:
			left.add_child(UIK.kv(str(part[0]), Fmt.money0(float(part[1])), Art.C_WHITE, 7))
	else:
		left.add_child(UIK.label("WHAT YOUR BOOKS SUPPORT", 7, Art.C_DIM, true))
		for r in o["reasons"]:
			left.add_child(UIK.kv(str(r[0]), Fmt.money0(float(r[1])), Art.C_WHITE if float(r[1]) >= 0 else Art.C_RED, 7))
		left.add_child(UIK.kv("Up to", Fmt.money0(float(o["max"])), Art.C_GREEN, 9, true))
		left.add_child(UIK.kv_tip("Interest (APR)", Fmt.pct(float(o["apr"]), 1), "interest_rate", Art.C_SKY, 8))
		var amt := _amount(o)
		var ah := UIK.hbox(3)
		left.add_child(ah)
		for f in [0.25, 0.5, 0.75, 1.0]:
			var b := UIK.button(Fmt.money0(maxf(1000.0, floorf(float(o["max"]) * f / 1000.0) * 1000.0)), func(): pick = f; rebuild(), "tab_active" if is_equal_approx(pick, f) else "tab")
			b.name = "Amt_%d" % int(f * 100)
			ah.add_child(b)
		var th := UIK.hbox(3)
		left.add_child(th)
		for m in [6, 12, 24]:
			var tb := UIK.button(I18n.t("%d months") % m, func(): months = m; rebuild(), "tab_active" if months == m else "tab")
			tb.name = "Term_%d" % m
			th.add_child(tb)
		var pmt := Bank.monthly_payment(amt, months)
		left.add_child(UIK.kv_tip("Monthly payment", Fmt.money0(pmt), "amortization", Art.C_WHITE, 8, true))
		left.add_child(UIK.kv("Total interest", Fmt.money0(pmt * months - amt), Art.C_MUTED, 7))
		if officer and Bank.at_bank() and Bank.marcus_on_duty():
			var tk := UIK.button(I18n.t("Borrow %s") % Fmt.money0(amt), _take, "primary")
			tk.name = "TakeLoan"
			left.add_child(tk)
		else:
			left.add_child(UIK.wrap("Marcus Reed signs loans in person (weekdays 13:00–16:00, Nexus Bank).", 7, Art.C_SKY, 226))
	if prerequisite != "":
		var action := UIK.button("View City Hall on city map" if prerequisite == "company" else "Open an account at the Nexus Bank counter", _city_hall if prerequisite == "company" else _open_account, "primary")
		action.name = "PrerequisiteCompany" if prerequisite == "company" else "PrerequisiteAccount"
		footer.add_child(action)
		var booking := UIK.button("Book an appointment", _book_appointment)
		booking.name = "BookLoanAppointment"
		footer.add_child(booking)
	elif not officer or not Bank.at_bank() or not Bank.marcus_on_duty():
		var entry := UIK.button("Meet Marcus Reed now" if Bank.at_bank() and Bank.marcus_on_duty() else "Book an appointment", _entry, "primary")
		entry.name = "MeetMarcus" if Bank.at_bank() and Bank.marcus_on_duty() else "BookLoanAppointment"
		footer.add_child(entry)
	if not Bank.at_bank():
		var route := UIK.button("View Nexus Bank on city map", _route)
		route.name = "RouteNexusBank"
		footer.add_child(route)
		left.add_child(UIK.wrap("Use the Metro to Financial District, then enter Nexus Bank and go to the manager desk.", 7, Art.C_SKY, 240))
	if Bank.appointment_hint() != "":
		left.add_child(UIK.wrap(Bank.appointment_hint(), 7, Art.C_SKY, 240))
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
		v.add_child(UIK.kv("Balance", Fmt.money0(float(l["balance"])), Art.C_WHITE, 7))
		v.add_child(UIK.kv("Payment", I18n.t("%s on %s") % [Fmt.money0(float(l["payment"])), Clock.fmt_date(int(l["next"]))], Art.C_MUTED, 7))
		var lid: String = l["id"]
		if l["status"] == "late" and not l.get("phone_extension", false):
			var extend := UIK.button("Request three more days", func():
				var result := Bank.request_payment_extension(lid)
				UIRoot.toast(result.get("outcome", result.get("error", "")), "good" if result["ok"] else "bad")
				rebuild())
			extend.name = "LoanExtend_" + lid
			v.add_child(extend)
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
	UIRoot.open_modal(LoanSigningModal.new(_sign))


func _entry() -> void:
	if Bank.at_bank() and Bank.marcus_on_duty():
		officer = true
		GameState.set_flag("met_marcus")
		if not GameState.data["npcs"].has("marcus"):
			GameState.data["npcs"]["marcus"] = {}
		GameState.data["npcs"]["marcus"]["met"] = true
		Bank.B().erase("appointment")
		Sim.cancel("bank.appointment", "id", "lending")
		rebuild()
	else:
		_book_appointment()


func _book_appointment() -> void:
	Bank.book_appointment()
	UIRoot.open_modal(InfoModal.make("Loan appointment", "bank", [Bank.appointment_hint()]))
	rebuild()


func _city_hall() -> void:
	_city_map("civic_center")


func _open_account() -> void:
	if Bank.at_bank():
		close()
		UIRoot.open_modal(BankModal.new())
	else:
		_route()


func _route() -> void:
	_city_map("financial")


func _city_map(district: String) -> void:
	var map := CityMapModal.new(false)
	map.sel = district
	UIRoot.open_modal(map)


func _sign() -> void:
	if not officer or not Bank.at_bank() or not Bank.marcus_on_duty():
		_entry()
		return
	var o := Bank.offer()
	if not o["ok"]:
		rebuild()
		return
	var r := Bank.take_loan(_amount(o), months)
	if not r["ok"]:
		UIRoot.toast(I18n.t(str(r["error"])), "warn", "bank")
		return
	Clock.advance(maxi(0, 17 * 60 - Clock.minute_of_day()))
	UIRoot.toast(I18n.t("%s is in the company account. First payment in 30 days.") % Fmt.money0(float(r["loan"]["principal"])), "good", "bank")
	rebuild()


func _repay(id: String, amt: float) -> void:
	var r := Bank.repay(id, amt)
	if not r["ok"]:
		UIRoot.toast(I18n.t(str(r["error"])), "warn", "bank")
	rebuild()
