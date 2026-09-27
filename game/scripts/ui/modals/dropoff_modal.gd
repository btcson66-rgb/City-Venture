class_name DropoffModal
extends Modal


func _init() -> void:
	title_text = "PostPoint — drop-off"
	icon_name = "parcel"
	panel_size = Vector2(360, 170)


func build() -> void:
	var ids: Array = GameState.data["player"]["carrying_parcels"]
	var econ := 0.0
	var exp := 0.0
	for oid in ids:
		var o: Dictionary = GameState.data["ecommerce"]["orders"].get(oid, {})
		if not o.is_empty():
			econ += Ecommerce.ship_cost(o, "economy")
			exp += Ecommerce.ship_cost(o, "express")
	body.add_child(UIK.wrap("Dara: \"%d parcel%s? Economy's three days, Express is one.\"" % [ids.size(), "s" if ids.size() != 1 else ""], 9, Art.C_WHITE, 340))
	var b1 := UIK.button("Economy · 3 days — %s" % Fmt.money(econ), _drop.bind("economy"), "primary")
	b1.name = "DropEconomy"
	body.add_child(b1)
	var b2 := UIK.button("Express · 1 day — %s" % Fmt.money(exp), _drop.bind("express"))
	b2.name = "DropExpress"
	body.add_child(b2)
	body.add_child(UIK.label("No pickup fee when you bring them in.", 7, Art.C_DIM))


func _drop(method: String) -> void:
	var r := Ecommerce.dropoff_carried(method)
	if r["ok"]:
		Clock.advance(5)
		UIRoot.toast("Shipped %d parcel%s — %s." % [r["count"], "s" if r["count"] > 1 else "", Fmt.money(r["cost"])], "good", "parcel")
	close()
