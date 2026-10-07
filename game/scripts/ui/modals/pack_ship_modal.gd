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
	panel_size = Vector2(420, 250 + (36 if Logistics.has_van() else 0))


func build() -> void:
	AssistantPolicy.toggle(body,"packing")
	var waiting := Ecommerce.orders_with(["placed"], location)
	var packable := waiting.filter(func(o): return Ecommerce.can_pack(o, location))
	var packed := Ecommerce.orders_with(["packed"], location)
	var inv := Ecommerce.inv(location)
	var stock_line := []
	for pid in inv:
		stock_line.append("%s ×%d" % [I18n.t(DataDB.product(pid)["name"]), int(inv[pid]["qty"])])
	body.add_child(UIK.wrap(I18n.t("Stock here: ") + (", ".join(stock_line) if not stock_line.is_empty() else I18n.t("No stock")), 8, Art.C_MUTED, 400))
	body.add_child(UIK.label_tip("Courier or self delivery", "courier_tiers", 8, Art.C_SKY))
	body.add_child(UIK.sep())
	body.add_child(UIK.label(I18n.t("Orders waiting to be packed: %d") % waiting.size(), 9, Art.C_WHITE, true))
	for o in waiting.slice(0, 5):
		body.add_child(UIK.label("  %s · %s · %s · %s" % [o["id"], Packing.summary(o), o["customer"], Fmt.money(Packing.total(o))], 8, Art.C_MUTED))
	if waiting.size() > 5:
		body.add_child(UIK.label(I18n.t("  …and %d more") % (waiting.size() - 5), 8, Art.C_DIM))
	var mins := int(DataDB.shipping().get("pack_minutes_per_order", 8))
	var pb := UIK.button(I18n.t("Pack %d order%s (%s)") % [packable.size(), I18n.pl(packable.size()), Fmt.duration_min(mins * packable.size())], _pack, "primary" if not packable.is_empty() else "")
	pb.disabled = packable.is_empty()
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
		var abroad := packed.any(func(o): return o.has("region"))
		var b1 := UIK.button((I18n.t("Courier · Economy / international 7–14 days (%s)") if abroad else I18n.t("Courier · Economy 3 days (%s)")) % Fmt.money(econ + fee), _courier.bind("economy"), "primary" if packable.is_empty() else "")
		b1.name = "CourierEconomy"
		var b2 := UIK.button((I18n.t("Courier · Express / international 7–10 days (%s)") if abroad else I18n.t("Courier · Express 1 day (%s)")) % Fmt.money(exp + fee), _courier.bind("express"))
		b2.name = "CourierExpress"
		h.add_child(b1)
		h.add_child(b2)
		body.add_child(h)
		if Logistics.has_van():
			var q := Logistics.ship_quote(location)
			var vr := UIK.hbox(4)
			var bv := UIK.button(I18n.t("Own van · same day (%s fuel, about %s of your time)") % [Fmt.money(float(q["fuel"])), Fmt.duration_min(int(q["minutes"]))], _own_van)
			bv.name = "OwnVan"
			bv.disabled = int(q["count"]) == 0
			vr.add_child(bv)
			vr.add_child(UIK.tip("own_van_shipping"))
			body.add_child(vr)
			body.add_child(UIK.label("Fuel instead of a courier fee, delivered today: cheaper per parcel, but the driving is your time.", 7, Art.C_DIM))
			if int(q["all"]) > int(q["count"]):
				body.add_child(UIK.label(I18n.t("The van takes %d parcels a trip: the other %d wait for the next one.") % [int(q["count"]), int(q["all"]) - int(q["count"])], 7, Art.C_DIM))
		var b3 := UIK.button("Carry them to PostPoint yourself (cheaper, costs your time)", _carry)
		b3.name = "Carry"
		body.add_child(b3)
		body.add_child(UIK.label(I18n.t("Courier picks up in ~2 hours and adds a %s pickup fee.") % Fmt.money(fee), 7, Art.C_DIM))
	footer.add_child(UIK.button("Done", close, "primary" if packable.is_empty() and packed.is_empty() else "", 70))


## You pack by hand (PackGame): each order's quality follows it to the customer.
func _pack() -> void:
	var waiting := Ecommerce.orders_with(["placed"], location).filter(func(o): return Ecommerce.can_pack(o, location))
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


## Deliver the packed parcels yourself in your van: fuel per parcel instead of a courier fee, same day, and the drive
## takes your time.
func _own_van() -> void:
	var r := Logistics.ship_own_van(location)
	if not r["ok"]:
		UIRoot.toast(I18n.t(str(r["error"])), "warn", "warning")
		rebuild()
		return
	Clock.advance(int(r["minutes"]))
	UIRoot.toast(I18n.t("Van run done: %d parcel%s delivered, %s of fuel, %s on the road.") % [r["count"], I18n.pl(r["count"]), Fmt.money(r["cost"]), Fmt.duration_min(int(r["minutes"]))], "good", "parcel")
	if is_inside_tree():
		rebuild()


func _carry() -> void:
	var n := Ecommerce.carry_parcels(location)
	UIRoot.toast(I18n.t("You're carrying %d parcel%s. Drop them at PostPoint (Riverside).") % [n, I18n.pl(n)], "info", "parcel")
	close()
