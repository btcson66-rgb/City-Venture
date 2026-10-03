class_name OverseasPartnerModal
extends Modal
## Real distributor Contracts or overseas inventory. Calling Omar costs nothing; flights still charge each way.

var channel := "distributor"
var qty := 10


func _init() -> void:
	title_text = "Omar — your Lumina partner"
	icon_name = "world"
	help_key = "overseas_partner"
	panel_size = Vector2(490, 324)


func result(r: Dictionary) -> void:
	if not r.get("ok", false):
		UIRoot.toast(I18n.t(str(r.get("error", ""))), "warn", "warning")
	rebuild()


func build() -> void:
	var box := UIK.vbox(4)
	body.add_child(UIK.scroll(box, Vector2(460, 250)))
	if not GlobalMarket.live(GameState.company_id()):
		box.add_child(UIK.wrap("✗ Register a live company first. Closed-company deals cannot resume.", 8, Art.C_GOLD, 452))
		return
	if not GameState.flag("met_omar"):
		var call := UIK.button("Video call Omar", func():
			UIRoot.close_all()
			UIRoot.play_dialogue.call_deferred("omar_trade", func(): UIRoot.open_modal(OverseasPartnerModal.new())), "primary")
		call.name = "CallOmar"
		box.add_child(call)
		box.add_child(UIK.wrap("A video call costs nothing and lets you choose a partner without a flight.", 7, Art.C_MUTED, 452))
	else:
		box.add_child(UIK.wrap("✓ Omar contacted. Compare the two channels and choose your next step.", 7, Art.C_GREEN, 452))
	var visiting := bool(OverseasPartners.company()["visiting"])
	box.add_child(UIK.kv("Flight each way (home dollars)", Fmt.money(float(OverseasPartners.cfg()["flight_fare"]))))
	var trip := UIK.hbox(4)
	box.add_child(trip)
	for payer in ["player", GameState.company_id()]:
		var b := UIK.button(I18n.t("Return — %s" if visiting else "Visit Lumina — %s") % (I18n.t("Personal account") if payer == "player" else I18n.t("Company account")), func():
			result(OverseasPartners.travel(str(payer), visiting)))
		b.name = "LuminaFlight_" + str(payer)
		b.disabled = Ledger.cash(str(payer)) < float(OverseasPartners.cfg()["flight_fare"])
		trip.add_child(b)
	box.add_child(UIK.wrap("One day passes each way. Your businesses keep running. If ticket cash is short, use the video call.", 7, Art.C_MUTED, 452))
	var choices := UIK.hbox(5)
	box.add_child(choices)
	for value in ["distributor", "warehouse"]:
		var b := UIK.button("Distributor" if value == "distributor" else "Overseas warehouse", func(): channel = str(value); rebuild(), "tab_active" if channel == value else "tab")
		b.name = "PartnerChannel_" + str(value)
		choices.add_child(b)
	var l := OverseasPartners.listing()
	if l.is_empty():
		box.add_child(UIK.wrap("✗ Create an active product listing first. You can review this expansion after 45 days if the company cannot trade.", 7, Art.C_GOLD, 452))
	elif channel == "distributor":
		box.add_child(UIK.label_tip("Distributor", "distributor"))
		box.add_child(UIK.wrap("Omar buys a batch at 55% of your retail price and owns the customers. You fund freight and stock; payment follows delivery. A home-currency quote pays less and may be declined.", 7, Art.C_WHITE, 452))
		var quote := UIK.button("Request distributor contract", func():
			var r := OverseasPartners.distributor_offer()
			if r["ok"]:
				var os := CompanyOS.new("home_laptop")
				os.tab = "contracts"
				os.sel_contract = str(r["id"])
				UIRoot.open_modal(os)
			else:
				result(r), "primary" if GameState.flag("met_omar") else "")
		quote.name = "RequestOmarContract"
		quote.disabled = not GameState.flag("met_omar")
		box.add_child(quote)
	else:
		box.add_child(UIK.label_tip("Overseas warehouse", "third_party_logistics"))
		box.add_child(UIK.wrap("You keep the customer relationship and retail margin. Pay sea freight and duty before dispatch, monthly rent per unsold unit, and shipping for each sale. Slow stock still ties up cash.", 7, Art.C_WHITE, 452))
		var opened: bool = not OverseasPartners.company()["warehouse"].is_empty()
		if not opened:
			var open := UIK.button(I18n.t("Open Lumina warehouse (%s)") % Fmt.money(float(OverseasPartners.cfg()["warehouse_open_fee"])), func(): result(OverseasPartners.open_warehouse()), "primary" if GameState.flag("met_omar") else "")
			open.name = "OpenLuminaWarehouse"
			box.add_child(open)
		else:
			var spin := SpinBox.new()
			spin.name = "LuminaTransferUnits"
			spin.min_value = 1
			spin.max_value = int(OverseasPartners.cfg()["warehouse_capacity"])
			spin.step = 1
			spin.value = qty
			spin.suffix = I18n.t("units")
			spin.value_changed.connect(func(value): qty = int(value))
			box.add_child(spin)
			box.add_child(UIK.kv("Overseas stock (units)", str(Ecommerce.total_units_at(OverseasPartners.warehouse_location()))))
			box.add_child(UIK.kv("Storage / local shipping (home dollars/unit)", Fmt.money(float(OverseasPartners.cfg()["warehouse_rent_unit_month"])) + I18n.t(" /month · ") + Fmt.money(float(OverseasPartners.cfg()["warehouse_shipping_unit"]))))
			var send := UIK.button("Send stock by sea", func(): result(OverseasPartners.transfer(str(l["product"]), qty)), "primary")
			send.name = "SendLuminaStock"
			box.add_child(send)
			box.add_child(UIK.wrap("Open Lumina Overseas sales and save a local price. Warehouse orders then pack and ship automatically after the batch arrives.", 7, Art.C_MUTED, 452))
			if OverseasPartners.clearance_available():
				var sell := UIK.button("Offer remaining stock to Omar", func():
					var r := OverseasPartners.distributor_offer(str(l["product"]), true)
					if r["ok"]:
						var os := CompanyOS.new("home_laptop")
						os.tab = "contracts"
						os.sel_contract = str(r["id"])
						UIRoot.open_modal(os)
					else:
						result(r))
				sell.name = "ClearLuminaStock"
				box.add_child(sell)
	box.add_child(UIK.label_tip("Who owns the customer", "who_owns_the_customer"))
	if OverseasPartners.review_available() and not GameState.flag("lumina_channel_income"):
		var review := UIK.button("Review expansion without claiming income", func(): OverseasPartners.review(); rebuild())
		review.name = "ReviewLuminaExpansion"
		box.add_child(review)
