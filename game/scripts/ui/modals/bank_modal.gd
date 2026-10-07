class_name BankModal
extends Modal
## Nexus Bank teller / ATM. Business account opening with founder capital; transfers; statements.

var atm := false
var capital := 10000.0
var stmt_entity := "player"


func _init(is_atm := false) -> void:
	atm = is_atm
	title_text = I18n.t("Nexus Bank — ") + I18n.t("ATM" if atm else "Business banking")
	icon_name = "bank"
	help_key = "bank"
	panel_size = Vector2(440, 270)


func build() -> void:
	var cid := GameState.company_id()
	var cols := UIK.hbox(10)
	body.add_child(cols)
	var left := UIK.vbox(3)
	left.custom_minimum_size = Vector2(200, 0)
	cols.add_child(left)
	left.add_child(UIK.label_tip("ACCOUNTS", "overdraft", 7, Art.C_DIM, true))
	left.add_child(UIK.label_tip("Credit history", "credit_history", 7, Art.C_SKY))
	left.add_child(UIK.kv("Personal checking", Fmt.money0(Ledger.cash("player")), UIK.money_color(Ledger.cash("player")), 8, true))
	if GameState.flag("business_account_opened"):
		left.add_child(UIK.kv(GameState.entity_name(cid).left(18), Fmt.money0(Ledger.cash(cid)), UIK.money_color(Ledger.cash(cid)), 8, true))
	left.add_child(UIK.sep())
	if not atm:
		if cid == "":
			left.add_child(UIK.wrap("Sofia: \"Business accounts need a registered company. City Hall, Civic Center — then come back.\"", 8, Art.C_MUTED, 196))
		elif not GameState.flag("business_account_opened"):
			left.add_child(UIK.wrap(I18n.t("Open an account for %s and move founder capital in. Your stock and ShopLane balance move with it.") % GameState.entity_name(cid), 8, Art.C_WHITE, 196))
			var h := UIK.hbox(3)
			for amt in [2000.0, 5000.0, 10000.0, 15000.0]:
				h.add_child(UIK.button(Fmt.money0(amt), func(): capital = amt; rebuild(), "tab_active" if is_equal_approx(capital, amt) else "tab"))
			left.add_child(h)
			var ob := UIK.button(I18n.t("Open account with %s") % Fmt.money0(capital), _open, "primary" if Ledger.cash("player") >= capital else "")
			ob.name = "OpenAccount"
			ob.disabled = Ledger.cash("player") < capital
			left.add_child(ob)
			if ob.disabled:
				left.add_child(UIK.wrap(I18n.t("You only have %s in personal checking. Pick a smaller amount.") % Fmt.money0(Ledger.cash("player")), 7, Art.C_SKY, 196))
		else:
			left.add_child(UIK.label("Transfers", 8, Art.C_MUTED, true))
			var th := UIK.hbox(3)
			th.add_child(UIK.button("→ Company $1,000", func(): _xfer("player", cid, 1000.0)))
			th.add_child(UIK.button("← Draw $500", func(): _xfer(cid, "player", 500.0)))
			left.add_child(th)
			var lb := UIK.button(I18n.t("Business lending · credit %d points") % Bank.credit(), func(): UIRoot.open_modal(LoanModal.new(false)))
			lb.name = "Lending"
			left.add_child(lb)
			if GlobalMarket.company()["bank"]:
				var forward := UIK.button("Manage exchange risk", func(): UIRoot.open_modal(FXRiskModal.new()), "primary")
				forward.name = "BankFXRisk"
				left.add_child(forward)
				left.add_child(UIK.wrap("✓ International account ready. Open Overseas sales in Company OS next.", 7, Art.C_GREEN, 196))
			else:
				left.add_child(UIK.label_tip("International account", "overseas_storefront"))
				var why := GlobalMarket.bank_block()
				if why != "":
					left.add_child(UIK.wrap("✗ " + I18n.t(why), 7, Art.C_SKY, 196))
				var international := UIK.button(I18n.t("Open international account (%s)") % Fmt.money(float(GlobalMarket.cfg().get("bank_open_fee", 150))), func():
					var result := GlobalMarket.open_bank()
					if not result["ok"]:
						UIRoot.toast(I18n.t(str(result["error"])), "warn", "warning")
						return
					Clock.advance(30)
					rebuild(), "primary")
				international.name = "OpenInternationalAccount"
				international.disabled = why != ""
				left.add_child(international)
	var right := UIK.vbox(2)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	var sh := UIK.hbox(3)
	sh.add_child(UIK.label("STATEMENT", 7, Art.C_DIM, true))
	sh.add_child(UIK.button("Personal", func(): stmt_entity = "player"; rebuild(), "tab_active" if stmt_entity == "player" else "tab"))
	if GameState.flag("business_account_opened"):
		sh.add_child(UIK.button("Company", func(): stmt_entity = cid; rebuild(), "tab_active" if stmt_entity == cid else "tab"))
	right.add_child(sh)
	var list := UIK.vbox(1)
	for e in Ledger.entries(stmt_entity, 60):
		var c := Ledger.entry_cash(e)
		if absf(c) < 0.01:
			continue
		var row := UIK.hbox(3)
		row.add_child(UIK.label(Clock.fmt_short(int(e["t"])).left(6), 6, Art.C_DIM))
		var m := UIK.label(SavedText.display(str(e["memo"])).left(30), 7, Art.C_WHITE)
		m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(m)
		row.add_child(UIK.label(Fmt.money0(c, true), 7, UIK.money_color(c), true))
		list.add_child(row)
	right.add_child(UIK.scroll(list, Vector2(200, 170)))
	footer.add_child(UIK.button("Done", close, "", 70))


func _open() -> void:
	var r := Company.open_business_account(capital)
	if not r["ok"]:
		UIRoot.toast(r["error"], "bad", "warning")
		return
	Clock.advance(30)
	UIRoot.toast(I18n.t("Business account opened. %s now runs on its own books.") % GameState.entity_name(GameState.company_id()), "good", "bank")
	rebuild()


func _xfer(a: String, b: String, amt: float) -> void:
	var r := Company.transfer(a, b, amt)
	if not r["ok"]:
		UIRoot.toast(r["error"], "bad", "warning")
	rebuild()
