class_name GlobalRegionModal
extends Modal
## Region facts and actual company revenue. This does not offer overseas travel.

var region := ""


func _init(id: String) -> void:
	region = id
	title_text = str(DataDB.regions.get(id, {}).get("name", "Overseas region"))
	icon_name = "world"
	help_key = "global_markets"
	panel_size = Vector2(420, 280)


func build() -> void:
	var r: Dictionary = DataDB.regions.get(region, {})
	var ccy := GlobalMarket.currency(region)
	body.add_child(UIK.kv("Currency", I18n.t(str(FX.cfg().get("currencies", {}).get(ccy, {}).get("name", ccy))) + " · " + ccy))
	body.add_child(UIK.label_tip(I18n.t("1 %s = %s home dollars") % [ccy, Fmt.money(FX.rate(ccy))], "fx_rate"))
	body.add_child(UIK.kv("Shipping", I18n.t("Economy 7–14 days; express 7–10 days")))
	body.add_child(UIK.wrap(I18n.t("Industries: ") + I18n.join(r.get("industries", [])), 8, Art.C_WHITE, 390))
	var revenue := float(GlobalMarket.company()["stores"].get(region, {}).get("revenue", 0)) if GlobalMarket.live(GameState.company_id()) else 0.0
	body.add_child(UIK.kv("Your regional revenue", Fmt.money(revenue) + " " + ccy))
	var why := GlobalMarket.store_block(region)
	body.add_child(UIK.wrap(("✗ " + I18n.t(why)) if why != "" else I18n.t("✓ Region available. Open Company OS → Sales → Overseas next."), 8, Art.C_GOLD if why != "" else Art.C_GREEN, 390))
	body.add_child(UIK.label_tip("International shipping", "international_shipping"))
	footer.add_child(UIK.button("Close", close))
	var trade := UIK.button("Compare trade route", func(): close(); UIRoot.open_modal(TradeQuoteModal.new(region)), "primary")
	trade.name = "TradeRoute_" + region
	footer.add_child(trade)
