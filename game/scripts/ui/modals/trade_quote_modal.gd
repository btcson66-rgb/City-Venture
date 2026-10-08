class_name TradeQuoteModal
extends Modal
## RFQ preview needs no stock; explicit signing creates a shared buyer contract and a paid cargo purchase.

var source := "aurelia"
var destination := "northridge"
var product := "wireless_earbuds"
var quantity := 50
var markup := .3
var term := "CIF"
var mode := "sea"
var payment := "lc"
var insured := true
var quote: Dictionary = {}


func _init(region := "northridge") -> void:
	calm_profile = "trade_quote"
	destination = region
	source = "zenkai" if region == "aurelia" else "aurelia"
	title_text = "Trade Deal Sheet — estimate"
	icon_name = "world"
	help_key = "trade_quote"
	panel_size = Vector2(560, 332)
	pauses_time = true
	refresh()


func refresh() -> void:
	quote = TradeQuote.sheet(source, destination, product, quantity, term, mode, payment, insured,markup)


static func value_label(value: String) -> String:
	match value:
		"seller": return I18n.t("Seller")
		"buyer": return I18n.t("Buyer")
		"sea": return I18n.t("Sea freight")
		"air": return I18n.t("Air freight")
		"tt_prepaid": return I18n.t("T/T prepaid")
		"tt_delivery": return I18n.t("T/T on delivery")
		"lc": return I18n.t("Letter of credit (L/C)")
		"open_account": return I18n.t("Open-account credit")
		"Supplier collection": return I18n.t("At supplier collection")
		"Vessel loading": return I18n.t("On vessel loading")
		_: return I18n.t(value)


func select_row(parent: Control, label: String, values: Array, selected: String, callback: Callable, node_name: String) -> void:
	var row := UIK.hbox(5)
	parent.add_child(row)
	row.add_child(UIK.label(label, 7))
	var option := OptionButton.new()
	option.name = node_name
	for value in values:
		var title := str(DataDB.regions.get(value, {}).get("name", DataDB.product(str(value)).get("name", value)))
		option.add_item(value_label(title))
	option.select(values.find(selected))
	option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	option.item_selected.connect(func(index): callback.call(str(values[index])); refresh(); rebuild())
	row.add_child(option)


func build() -> void:
	var content := UIK.vbox(3)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 245)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	body.add_child(scroll)
	content.add_child(UIK.wrap("Compare supplier costs and buyer demand before signing a trade.", 7, Art.C_SKY, 520))
	var regions: Array = DataDB.regions.keys()
	regions.sort()
	select_row(content, "Supply region", regions, source, func(value): source = value, "TradeSource")
	select_row(content, "Buyer region", regions, destination, func(value): destination = value, "TradeDestination")
	select_row(content, "Trade product", TradeQuote.cfg()["goods"].keys(), product, func(value): product = value, "TradeProduct")
	var qty_row := UIK.hbox(5)
	content.add_child(qty_row)
	qty_row.add_child(UIK.label("Quantity (units)", 7))
	var qty := SpinBox.new()
	qty.name = "TradeQuantity"
	qty.min_value = 1
	qty.max_value = 1000
	qty.step = 1
	qty.value = quantity
	qty.value_changed.connect(func(value): quantity = int(value); refresh(); rebuild())
	qty_row.add_child(qty)
	var markup_row:=UIK.hbox(5)
	content.add_child(markup_row);markup_row.add_child(UIK.label("Trade markup (%)",7))
	var markup_edit:=SpinBox.new()
	markup_edit.name="TradeMarkup";markup_edit.min_value=0;markup_edit.max_value=100;markup_edit.step=5;markup_edit.value=markup*100
	markup_edit.value_changed.connect(func(value):markup=float(value)/100.0;refresh();rebuild())
	markup_row.add_child(markup_edit)
	select_row(content, "Trade term", ["EXW", "FOB", "CIF", "DDP"], term, func(value): term = value, "TradeTerm")
	content.add_child(UIK.label_tip("Cost ownership and risk transfer", "trade_terms"))
	select_row(content, "Cargo transport", ["sea", "air"], mode, func(value): mode = value, "TradeTransport")
	select_row(content, "Trade payment", ["tt_prepaid", "tt_delivery", "lc", "open_account"], payment, func(value): payment = value, "TradePayment")
	var insurance := UIK.button("Cargo insurance: on" if insured else "Cargo insurance: off", func(): insured = not insured; refresh(); rebuild())
	insurance.name = "TradeInsurance"
	content.add_child(insurance)
	if not quote.get("ok", false):
		content.add_child(UIK.wrap("✗ " + I18n.t(str(quote["error"])), 8, Art.C_RED, 520))
	else:
		content.add_child(UIK.label_tip("RFQ — three-day estimate", "trade_rfq"))
		content.add_child(UIK.kv("Supply cost (home dollars)", Fmt.money(float(quote["purchase"]))))
		content.add_child(UIK.kv("Buyer quote (foreign total)", Fmt.money(float(quote["buyer_quote"])) + " " + str(quote["buyer_currency"])))
		for segment in quote["segments"]:
			content.add_child(UIK.kv(str(segment["kind"]), Fmt.money(float(segment["cost"])) + " " + I18n.t("home dollars") + " · " + value_label(str(segment["payer"]))))
		content.add_child(UIK.kv("Bank fee / spread (home dollars)", Fmt.money(float(quote["fee"])) + " / " + Fmt.money(float(quote["spread"]))))
		content.add_child(UIK.kv("Estimated margin (home dollars)", Fmt.money(float(quote["margin"]))))
		content.add_child(UIK.kv("Stress margin (home dollars)", Fmt.money(float(quote["stress_margin"])), Art.C_RED))
		content.add_child(UIK.wrap("Stress estimate: foreign receipts fall 15% and one seller cargo loss occurs. This is a scenario, not a forecast or a guaranteed result.", 7, Art.C_MUTED, 520))
		content.add_child(UIK.wrap(("✓ " if quote["competitive"] else "✗ ") + I18n.t("Compare buyer landed cost with demand before choosing a route."), 7, Art.C_SKY, 520))
		content.add_child(UIK.kv("Buyer landed / ceiling (home dollars)", Fmt.money(float(quote["buyer_landed"])) + " / " + Fmt.money(float(quote["buyer_ceiling"]))))
		content.add_child(UIK.kv("Cargo risk passes at", value_label(str(quote["risk_transfer"]))))
		content.add_child(UIK.kv("Departure wait / transit / payment (days)", "%d / %d / %d" % [quote["wait_days"], quote["transit_days"], quote["payment_days"]]))
		content.add_child(UIK.kv("Cargo loss / buyer default (%)", "%.1f / %.1f" % [100 * float(quote["cargo_risk"]), 100 * float(quote["default_risk"])]))
		content.add_child(UIK.kv("Hold warehouse rent (home dollars/day)", Fmt.money(float(quote["warehouse_rent_day"]))))
		content.add_child(UIK.wrap("No stock, contract, payment, insurance claim or forward hedge is created by this estimate.", 7, Art.C_MUTED, 520))
	var can_sign: bool=TradeIndustry.valid() and quote.get("ok",false) and TradeIndustry.available(quote)==""
	var can_import: bool=TradeIndustry.valid() and TradeIndustry.S()["agency"] and destination=="aurelia" and term=="DDP" and quote.get("ok",false) and TradeIndustry.available(quote,true)==""
	if can_import:
		var import_button:=UIK.button("Buy cargo for bonded warehouse",_procure,"primary")
		import_button.name="TradeProcure";footer.add_child(import_button)
	if can_sign:
		var sign_button:=UIK.button("Sign buyer contract and buy supplier cargo",_sign,"" if can_import else "primary")
		sign_button.name="TradeSign";footer.add_child(sign_button)
	elif TradeIndustry.valid():content.add_child(UIK.wrap("✗ "+I18n.t(TradeIndustry.available(quote)),8,Art.C_SKY,520))
	var refresh_button := UIK.button("Refresh RFQ estimate", func(): refresh(); rebuild(), "" if can_sign or can_import else "primary")
	refresh_button.name = "TradeRefreshRFQ"
	footer.add_child(refresh_button)

func _sign() -> void:
	var result:=TradeIndustry.sign(quote)
	if result["ok"]:close();TradeDeskUI.open()
	else:UIRoot.open_modal(InfoModal.make("International Trade","world",[str(result["error"])]))

func _procure() -> void:
	var result:=TradeIndustry.procure(quote)
	if result["ok"]:close();TradeDeskUI.open()
	else:UIRoot.open_modal(InfoModal.make("International Trade","world",[str(result["error"])]))
