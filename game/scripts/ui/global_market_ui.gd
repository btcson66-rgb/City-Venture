class_name GlobalMarketUI
extends RefCounted
## Small Company OS extension; pricing and conversion stay at the existing terminal.


static func sales(os: CompanyOS, box: VBoxContainer) -> void:
	box.add_child(UIK.label_tip("ShopLane Global", "overseas_storefront", 10, Art.C_GOLD, true))
	OverseasPartnerUI.sales(box)
	var select := OptionButton.new()
	select.name = "GlobalRegion"
	var regions: Array = GlobalMarket.cfg().get("regions", {}).keys()
	regions.sort()
	for i in regions.size():
		select.add_item(I18n.t(str(DataDB.regions[regions[i]]["name"])), i)
		if regions[i] == os.global_region:
			select.select(i)
	select.item_selected.connect(func(i): os.global_region = str(regions[i]); os.rebuild())
	box.add_child(select)
	var region := os.global_region
	var ccy := GlobalMarket.currency(region)
	box.add_child(UIK.label_tip(I18n.t("1 %s = %s home dollars") % [ccy, Fmt.money(FX.rate(ccy))], "fx_rate"))
	var why := GlobalMarket.store_block(region)
	if why != "":
		box.add_child(UIK.wrap("✗ " + I18n.t(why), 8, Art.C_GOLD, 460))
		if not GlobalMarket.unlocked(region):
			return
		if not GlobalMarket.live(GameState.company_id()):
			var go := UIK.button("Find City Hall", func():
				var m := CityMapModal.new(false)
				m.sel = "civic_center"
				UIRoot.open_modal(m), "primary")
			go.name = "GlobalRegisterRoute"
			box.add_child(go)
		elif not GlobalMarket.company()["bank"]:
			var go := UIK.button("Find Nexus Bank", func():
				var m := CityMapModal.new(false)
				m.sel = "financial_district"
				UIRoot.open_modal(m), "primary")
			go.name = "GlobalBankRoute"
			box.add_child(go)
		return
	var stores: Dictionary = GlobalMarket.company()["stores"]
	if not stores.has(region):
		box.add_child(UIK.wrap("✓ Ready to open this region's storefront. Set local prices next.", 8, Art.C_GREEN, 460))
		var open := UIK.button("Open storefront", func(): GlobalMarket.open_store(region); os.rebuild(), "primary")
		open.name = "OpenGlobalStore_" + region
		box.add_child(open)
		return
	box.add_child(UIK.wrap("✓ Storefront open. Choose local prices; unsaved prices do not take orders.", 8, Art.C_GREEN, 460))
	var prices: Dictionary = stores[region]["prices"]
	var first := true
	for l in Ecommerce.E()["listings"].values():
		var p := DataDB.product(str(l["product"]))
		var row := UIK.hbox(4)
		box.add_child(row)
		row.add_child(UIK.label(str(p["name"]), 8))
		var edit := SpinBox.new()
		edit.name = "GlobalPrice_" + str(l["id"])
		edit.min_value = ceil(float(p["price_min"]) / FX.rate(ccy) * 100) / 100
		edit.max_value = floor(float(p["price_max"]) / FX.rate(ccy) * 100) / 100
		edit.step = 0.01
		edit.value = float(prices.get(l["id"], float(l["price"]) / FX.rate(ccy)))
		edit.suffix = ccy
		edit.custom_minimum_size = Vector2(100, 0)
		row.add_child(edit)
		var save := UIK.button("Save local price", func():
			var result := GlobalMarket.set_price(region, str(l["id"]), edit.value)
			if not result["ok"]:
				UIRoot.toast(I18n.t(str(result["error"])), "warn", "warning")
			os.rebuild(), "primary" if first else "")
		first = false
		save.name = "SaveGlobalPrice_" + str(l["id"])
		row.add_child(save)
		OverseasPartnerUI.price(box, region, float(prices.get(l["id"], edit.value)))
		CustomsUI.declaration(os, box, region, str(l["id"]))
		box.add_child(UIK.label(I18n.t("Expected demand: %.1f orders/day") % GlobalMarket.demand(region, l), 7, Art.C_MUTED))
	if Ecommerce.E()["listings"].is_empty():
		box.add_child(UIK.wrap("Create a product listing in Domestic sales first, then set its overseas price here.", 8, Art.C_GOLD, 460))
		var go := UIK.button("Domestic", func(): os.sales_page = "domestic"; os.rebuild(), "primary")
		go.name = "GlobalDomesticRoute"
		box.add_child(go)
	box.add_child(UIK.label_tip("International shipping", "international_shipping"))
	box.add_child(UIK.wrap("Pack overseas orders at your packing table. Economy and express couriers use international routes; your own van only delivers domestic parcels.", 7, Art.C_MUTED, 460))
	CustomsUI.guide(os, box)


static func finance(os: CompanyOS, box: VBoxContainer) -> void:
	if not GlobalMarket.live(GameState.company_id()) or not GlobalMarket.company()["bank"]:
		return
	box.add_child(UIK.title("Overseas payouts", 10, Art.C_GOLD))
	OverseasPartnerUI.finance(box)
	box.add_child(UIK.label_tip(I18n.t("Bank spread: %.1f%%") % (float(FX.cfg().get("bank_spread", 0.015)) * 100), "fx_spread"))
	box.add_child(UIK.label_tip("Realized exchange gain / loss", "fx_gain_loss"))
	box.add_child(UIK.kv("Realized exchange gain / loss", Fmt.money(-Ledger.balance(GameState.company_id(), "fx_gain_loss"))))
	var auto := CheckBox.new()
	auto.name = "AutoGlobalFX"
	auto.text = I18n.t("Automatically convert weekly foreign payouts")
	auto.button_pressed = bool(GlobalMarket.company()["auto_fx"])
	auto.toggled.connect(func(on): GlobalMarket.company()["auto_fx"] = on)
	box.add_child(auto)
	var first := true
	for ccy in GlobalMarket.company()["balances"]:
		var b := GlobalMarket.balance(GameState.company_id(), str(ccy))
		box.add_child(UIK.kv(I18n.t("Awaiting payout (%s)") % ccy, Fmt.money(float(b["receivable"])) + " " + str(ccy)))
		box.add_child(UIK.kv(I18n.t("Ready to convert (%s)") % ccy, Fmt.money(float(b["wallet"])) + " " + str(ccy)))
		if float(b["wallet"]) > 0:
			var convert := UIK.button(I18n.t("Convert to home cash (%s)") % Fmt.money(FX.to_home(float(b["wallet"]), str(ccy))), func():
				GlobalMarket.convert_currency(GameState.company_id(), str(ccy))
				os.rebuild(), "primary" if first else "")
			first = false
			convert.name = "ConvertGlobal_" + str(ccy)
			box.add_child(convert)
