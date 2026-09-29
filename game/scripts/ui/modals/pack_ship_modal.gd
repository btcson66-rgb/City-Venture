class_name PackShipModal
extends Modal
## Packing table: pack waiting orders (takes time), then choose how they leave the building.

var location := ""
var packed_now := 0


func _init(loc: String) -> void:
	location = loc
	title_text = I18n.t("Packing table — %s") % Ecommerce.location_name(loc)
	icon_name = "parcel"
	help_key = "packing"
	panel_size = Vector2(420, 250)


func build() -> void:
	var waiting := Ecommerce.orders_with(["placed"], location)
	var packed := Ecommerce.orders_with(["packed"], location)
	var inv := Ecommerce.inv(location)
	var stock_line := []
	for pid in inv:
		stock_line.append("%s ×%d" % [I18n.t(DataDB.product(pid)["name"]), int(inv[pid]["qty"])])
	body.add_child(UIK.wrap(I18n.t("Stock here: ") + (", ".join(stock_line) if not stock_line.is_empty() else "none"), 8, Art.C_MUTED, 400))
	body.add_child(UIK.sep())
	body.add_child(UIK.label(I18n.t("Orders waiting to be packed: %d") % waiting.size(), 9, Art.C_WHITE, true))
	for o in waiting.slice(0, 5):
		body.add_child(UIK.label("  %s · %s · %s · %s" % [o["id"], I18n.t(DataDB.product(o["product"])["name"]), o["customer"], Fmt.money(o["unit_price"])], 8, Art.C_MUTED))
	if waiting.size() > 5:
		body.add_child(UIK.label(I18n.t("  …and %d more") % (waiting.size() - 5), 8, Art.C_DIM))
	var mins := int(DataDB.shipping().get("pack_minutes_per_order", 8))
	var pb := UIK.button(I18n.t("Pack %d order%s (%s)") % [waiting.size(), I18n.pl(waiting.size()), Fmt.duration_min(mins * waiting.size())], _pack, "primary")
	pb.disabled = waiting.is_empty()
	pb.name = "Pack"
	body.add_child(pb)
	body.add_child(UIK.sep())
	body.add_child(UIK.label(I18n.t("Packed and ready: %d") % packed.size(), 9, Art.C_WHITE, true))
	if not packed.is_empty():
		var econ := 0.0
		var exp := 0.0
		for o in packed:
			econ += Ecommerce.ship_cost(o, "economy")
			exp += Ecommerce.ship_cost(o, "express")
		var fee := float(DataDB.shipping()["pickup"]["courier_fee_per_batch"])
		var h := UIK.hbox(4)
		var b1 := UIK.button(I18n.t("Courier · Economy 3d (%s)") % Fmt.money(econ + fee), _courier.bind("economy"))
		b1.name = "CourierEconomy"
		var b2 := UIK.button(I18n.t("Courier · Express 1d (%s)") % Fmt.money(exp + fee), _courier.bind("express"))
		b2.name = "CourierExpress"
		h.add_child(b1)
		h.add_child(b2)
		body.add_child(h)
		var b3 := UIK.button("Carry them to PostPoint yourself (cheaper, costs your time)", _carry)
		b3.name = "Carry"
		body.add_child(b3)
		body.add_child(UIK.label(I18n.t("Courier picks up in ~2 hours and adds a %s pickup fee.") % Fmt.money(fee), 7, Art.C_DIM))
	footer.add_child(UIK.button("Done", close, "", 70))


## You pack by hand (PackGame): each order's quality follows it to the customer.
func _pack() -> void:
	var waiting := Ecommerce.orders_with(["placed"], location).filter(func(o): return Ecommerce.stock(location, str(o["product"])) >= int(o["qty"]))
	if waiting.is_empty():
		UIRoot.toast("Nothing to pack here: is the stock at this location?", "warn", "warning")
		return
	MiniGames.play(PackGame.new(waiting), func(res: Dictionary):
		if not res.get("aborted", false):
			_packed(res.get("quality", {})))


func _packed(quality: Dictionary) -> void:
	var n := Ecommerce.pack_orders(location, -1, quality)
	if n > 0:
		Clock.advance(int(DataDB.shipping().get("pack_minutes_per_order", 8)) * n)
		UIRoot.toast(I18n.t("Packed %d order%s.") % [n, I18n.pl(n)], "good", "parcel")
	else:
		UIRoot.toast("Nothing packed — is the stock at this location?", "warn", "warning")
	if is_inside_tree():
		rebuild()


func _courier(method: String) -> void:
	var r := Ecommerce.courier_pickup(location, method)
	if r["ok"]:
		UIRoot.toast(I18n.t("Courier booked: %d parcel%s, %s. Pickup %s.") % [r["count"], I18n.pl(r["count"]), Fmt.money(r["cost"]), Clock.fmt_time(r["pickup_at"])], "good", "parcel")
	rebuild()


func _carry() -> void:
	var n := Ecommerce.carry_parcels(location)
	UIRoot.toast(I18n.t("You're carrying %d parcel%s. Drop them at PostPoint (Riverside).") % [n, I18n.pl(n)], "info", "parcel")
	close()
