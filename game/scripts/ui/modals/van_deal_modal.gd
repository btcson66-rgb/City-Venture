class_name VanDealModal
extends Modal
## Dockside Motors: Sam Okoro's used panel van. Bought from the company account (a vehicle expense), insured monthly.

var _buy: Button


func _init() -> void:
	title_text = "Dockside Motors: used van"
	icon_name = "company"
	panel_size = Vector2(420, 300)


func build() -> void:
	var v := Logistics.van_cfg()
	var price := float(v.get("price", 9800))
	var ins := float(v.get("insurance_month", 165))
	if Logistics.has_van():
		body.add_child(UIK.wrap(I18n.t("Sam: \"She's yours. Keep her moving: the runs are in Company OS → Logistics.\""), 9, Art.C_WHITE, 380))
		footer.add_child(UIK.button("Close", close))
		return
	var top := UIK.hbox(10)
	body.add_child(top)
	top.add_child(_van_picture())
	var col := UIK.vbox(2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(col)
	col.add_child(UIK.title(I18n.t(str(v.get("name", "Used panel van"))), 11, Art.C_GOLD))
	col.add_child(UIK.wrap(I18n.t("White, 140,000 km, a sighing gearbox and an honest engine. Parked at Pier 7 once it's yours."), 8, Art.C_MUTED, 250))
	body.add_child(UIK.sep())
	body.add_child(UIK.kv("Price", Fmt.money(price), Art.C_GOLD, 9, true))
	var r2 := UIK.kv("Insurance, every month", Fmt.money(ins))
	r2.add_child(UIK.tip("vehicle_insurance"))
	body.add_child(r2)
	var r3 := UIK.kv("Fuel and upkeep", I18n.t("about %s per 100 km") % Fmt.money(100.0 * (Logistics.fuel_cost_per_km() + Logistics.upkeep_per_km())))
	r3.add_child(UIK.tip("fuel_cost"))
	body.add_child(r3)
	var r4 := UIK.kv("Room for", I18n.t("%d parcels") % int(v.get("capacity_parcels", 40)))
	r4.add_child(UIK.tip("van_capacity"))
	body.add_child(r4)
	body.add_child(UIK.kv("Paid from", "%s · %s" % [GameState.business_display_name(), Fmt.money0(Ledger.cash(GameState.business_entity()))]))
	body.add_child(UIK.wrap("In plain words: the van is a company expense today. It only pays back if you keep it busy, with your own parcels and delivery runs.", 7, Art.C_SKY, 390))
	var why := Logistics.buy_block()
	_buy = UIK.button(I18n.t("Buy the van (%s)") % Fmt.money(price), _do_buy, "primary")
	_buy.name = "BuyVan"
	_buy.disabled = why != ""
	if why != "":
		body.add_child(UIK.label(I18n.t("Not yet: %s.") % I18n.t(why), 8, Art.C_RED, true))
	footer.add_child(UIK.button("Not now", close))
	footer.add_child(_buy)


## The city's stock van until Dockside Motors' own picture lands (vehicles/van_player_side_*).
func _van_picture() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(132, 66)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var body_path := "vehicles/van_player_side_body" if Art.has_tex("vehicles/van_player_side_body") else "vehicles/van_side_body"
	var det_path := "vehicles/van_player_side_detail" if Art.has_tex("vehicles/van_player_side_detail") else "vehicles/van_side_detail"
	for path in [body_path, det_path]:
		var t := TextureRect.new()
		t.texture = Art.tex(path)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		t.size = Vector2(132, 66)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(t)
	return c


func _do_buy() -> void:
	var r := Logistics.buy_van()
	if not r["ok"]:
		UIRoot.toast(I18n.t(str(r["error"])), "warn", "lock")
		rebuild()
		return
	UIRoot.toast(I18n.t("Sam hands over the keys. The van is parked at Pier 7. Delivery runs are posted every morning in Company OS → Logistics."), "good", "parcel")
	rebuild()
