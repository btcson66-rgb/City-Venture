class_name DropoffModal
extends Modal


func _init() -> void:
	title_text = "PostPoint — drop-off"
	icon_name = "parcel"
	help_key = "dropoff"
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
	body.add_child(UIK.wrap(I18n.t("Dara: \"%d parcel%s? Economy's three days, Express is one.\"") % [ids.size(), I18n.pl(ids.size())], 9, Art.C_WHITE, 340))
	var b1 := UIK.button(I18n.t("Economy · 3 days — %s") % Fmt.money(econ), _drop.bind("economy"), "primary")
	b1.name = "DropEconomy"
	body.add_child(b1)
	var b2 := UIK.button(I18n.t("Express · 1 day — %s") % Fmt.money(exp), _drop.bind("express"))
	b2.name = "DropExpress"
	body.add_child(b2)
	body.add_child(UIK.label("No pickup fee when you bring them in.", 7, Art.C_DIM))


func _drop(method: String) -> void:
	var r := Ecommerce.dropoff_carried(method)
	if r["ok"]:
		Clock.advance(5)
		UIRoot.toast(I18n.t("Shipped %d parcel%s — %s.") % [r["count"], I18n.pl(r["count"]), Fmt.money(r["cost"])], "good", "parcel")
	close()
