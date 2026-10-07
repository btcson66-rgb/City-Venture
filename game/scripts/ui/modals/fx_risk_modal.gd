class_name FXRiskModal
extends Modal
## One actionable hedge quote; the free home-invoice alternative has a genuine acceptance tradeoff.

var ccy := "AUR"
var notional := 100.0
var days := 30


func _init() -> void:
	title_text = "Manage foreign receipts"
	icon_name = "finance"
	help_key = "fx_risk"
	panel_size = Vector2(490, 320)


func build() -> void:
	var box := UIK.vbox(4)
	body.add_child(UIK.scroll(box, Vector2(460, 246)))
	if not GameState.flag("met_marcus_fx"):
		var meet := UIK.button("Call Marcus about exchange risk", func():
			UIRoot.close_all()
			UIRoot.play_dialogue.call_deferred("marcus_fx", func(): UIRoot.open_modal(FXRiskModal.new())), "primary")
		meet.name = "CallMarcusFX"
		box.add_child(meet)
	box.add_child(UIK.label_tip("Forward contract", "forward_contract"))
	box.add_child(UIK.wrap("Selling foreign receipts forward locks a rate. You pay a fee and refundable collateral; the hedge loses if foreign currency strengthens. It does not replace collecting your invoices.", 7, Art.C_WHITE, 454))
	var row := UIK.hbox(5)
	box.add_child(row)
	var currencies: Array = FX.cfg().get("currencies", {}).keys()
	currencies.sort()
	var choice := OptionButton.new()
	choice.name = "ForwardCurrency"
	for currency in currencies:
		choice.add_item(str(currency))
	choice.select(currencies.find(ccy))
	choice.item_selected.connect(func(index): ccy = str(currencies[index]); rebuild())
	row.add_child(choice)
	var amount := SpinBox.new()
	amount.name = "ForwardNotional"
	amount.custom_minimum_size = Vector2(140, 0)
	amount.min_value = 1
	amount.max_value = float(FXForward.cfg().get("maximum_notional", 10000))
	amount.step = 1
	amount.value = notional
	amount.suffix = ccy
	amount.value_changed.connect(func(value): notional = value; rebuild())
	row.add_child(amount)
	for duration in [30, 60]:
		var b := UIK.button(I18n.t("%d days") % duration, func(): days = duration; rebuild(), "tab_active" if duration == days else "tab")
		b.name = "ForwardDays_%d" % duration
		row.add_child(b)
	box.add_child(UIK.kv("Available to hedge (foreign units)", Fmt.money(FXForward.exposure(GameState.company_id(), ccy, days)) + " " + ccy))
	var unbooked := FXForward.projected(GameState.company_id(), ccy, days)
	if unbooked >= 1:
		box.add_child(UIK.wrap(I18n.t("Estimated unbooked sales of about %s %s are not hedgeable until they are booked.") % [Fmt.money(unbooked), ccy], 7, Art.C_MUTED, 454))
	var q := FXForward.quote(ccy, notional, days)
	if q["ok"]:
		box.add_child(UIK.kv("Locked quote (home dollars/foreign unit)", Fmt.money(float(q["rate"])) + " / " + ccy))
		box.add_child(UIK.kv("Fee / refundable collateral (home dollars)", Fmt.money(float(q["fee"])) + " / " + Fmt.money(float(q["collateral"]))))
	else:
		box.add_child(UIK.wrap("✗ " + I18n.t(str(q["error"])), 7, Art.C_SKY, 454))
	var sign := UIK.button("Sign forward hedge", func():
		var result := FXForward.open(ccy, notional, days)
		if not result["ok"]:
			UIRoot.toast(I18n.t(str(result["error"])), "warn", "warning")
		rebuild(), "primary" if GameState.flag("met_marcus_fx") and q["ok"] else "")
	sign.name = "SignForward"
	sign.disabled = not q["ok"]
	box.add_child(sign)
	box.add_child(UIK.label_tip("Home-currency invoices", "invoice_currency"))
	box.add_child(UIK.wrap("Future overseas distributor offers can use home currency. Buyers take the exchange risk: acceptance is lower and their offer is cheaper. Existing invoices keep their agreed currency.", 7, Art.C_MUTED, 454))
	var home := UIK.button("Choose home-currency invoices", func(): OverseasPartners.choose_home_invoices(); rebuild(), "primary" if GameState.flag("met_marcus_fx") and not q["ok"] else "")
	home.name = "ChooseHomeInvoices"
	home.disabled = not GlobalMarket.live(GameState.company_id())
	box.add_child(home)
