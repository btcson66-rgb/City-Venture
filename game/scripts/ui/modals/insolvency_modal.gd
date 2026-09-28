class_name InsolvencyModal
extends Modal
## The company can't pay its debts. Not game over: rescue it with savings, restructure with the bank,
## or close it and start again. After closing, the modal shows the closing statement.

var report := {}


func _init() -> void:
	title_text = "The company can't pay its debts"
	icon_name = "warning"
	panel_size = Vector2(460, 290)
	closable = false


func build() -> void:
	if not report.is_empty():
		_statement()
		return
	var st := Insolvency.state()
	var ent := str(st.get("entity", ""))
	body.add_child(UIK.title(GameState.entity_name(ent), 12, Art.C_GOLD))
	body.add_child(UIK.wrap(I18n.t("What happened: %s") % str(st.get("reason", "")), 8, Art.C_WHITE, 440))
	body.add_child(UIK.kv("Cash in the company", Fmt.money(Ledger.cash(ent)), UIK.money_color(Ledger.cash(ent)), 8))
	body.add_child(UIK.kv("Owed (bank, wages, suppliers)", Fmt.money(Insolvency.liabilities(ent)), Art.C_RED, 8))
	body.add_child(UIK.kv("Shortfall", Fmt.money(Insolvency.shortfall(ent)), Art.C_RED, 9, true))
	body.add_child(UIK.kv("Your personal cash", Fmt.money(Ledger.cash("player")), Art.C_WHITE, 8))
	body.add_child(UIK.sep())
	body.add_child(UIK.wrap("A company can fail. You don't. Pick what happens next:", 8, Art.C_SKY, 440))
	var need := Insolvency.shortfall(ent)
	var b1 := UIK.button(I18n.t("Put in %s of your own money") % Fmt.money0(need) if need > 0.0 else I18n.t("Pay what's owed from company cash and carry on"), func():
		var r := Insolvency.rescue_with_savings()
		if not r["ok"]:
			UIRoot.toast(I18n.t(str(r["error"])), "warn", "warning")
			return
		UIRoot.toast("The company is solvent again. Your savings took the hit.", "info", "cash")
		close())
	b1.name = "Rescue"
	b1.disabled = Ledger.cash("player") < Insolvency.shortfall(ent)
	body.add_child(b1)
	var b2 := UIK.button("Restructure the loan with Nexus Bank (24 months, +3% interest, credit hit)", func():
		var r := Insolvency.restructure()
		if not r["ok"]:
			UIRoot.toast(I18n.t(str(r["error"])), "warn", "bank")
			return
		UIRoot.toast("Loan restructured. Payments are smaller; the bank is watching.", "info", "bank")
		close())
	b2.name = "Restructure"
	b2.disabled = Bank.B()["loans"].values().filter(func(l): return l["entity"] == ent and l["status"] in ["called", "defaulted"]).is_empty()
	body.add_child(b2)
	var b3 := UIK.button("Close the company: sell off, pay what we can, start again", func():
		var r := Insolvency.close_company()
		if r["ok"]:
			report = r["report"]
			rebuild(), "danger")
	b3.name = "CloseCompany"
	body.add_child(b3)


func _statement() -> void:
	body.add_child(UIK.title("Closing statement", 12, Art.C_GOLD))
	body.add_child(UIK.kv("Stock sold to a liquidator (40% of cost)", Fmt.money(float(report.get("stock", 0.0))), Art.C_WHITE, 8))
	body.add_child(UIK.kv("Receivables sold (80%)", Fmt.money(float(report.get("receivables", 0.0))), Art.C_WHITE, 8))
	body.add_child(UIK.kv("Office deposit returned", Fmt.money(float(report.get("deposit", 0.0))), Art.C_WHITE, 8))
	for acct in report.get("paid", {}):
		body.add_child(UIK.kv(I18n.t("Paid — %s") % I18n.t(str(acct).replace("_", " ")), Fmt.money(float(report["paid"][acct])), Art.C_MUTED, 8))
	body.add_child(UIK.kv("Debt written off", Fmt.money(float(report.get("written_off", 0.0))), Art.C_RED, 8, true))
	body.add_child(UIK.kv("Returned to you", Fmt.money(float(report.get("returned", 0.0))), Art.C_GREEN, 8))
	body.add_child(UIK.sep())
	body.add_child(UIK.wrap(I18n.t("Credit score now %d. Bank loans pause for 90 days. You can register a new company at City Hall whenever you're ready.") % Bank.credit(), 8, Art.C_SKY, 440))
	var b := UIK.button("Start over", func():
		close()
		UIRoot.show_chapter_card("A fresh start", "A company can fail. You don't.", "backdrops/insolvency"), "primary", 90)
	b.name = "StartOver"
	footer.add_child(b)
