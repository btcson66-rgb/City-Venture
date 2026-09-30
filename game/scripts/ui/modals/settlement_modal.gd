class_name SettlementModal
extends Modal
## Paying a supplier abroad in the Clearing Crisis (Year 5): pick a rail, see what it costs and how long the money
## takes to land. Opened when you buy from an importer, or later to speed up a payment stuck on the wire.

var supplier := ""
var product := ""
var qty := 0
var location := ""
var po_id := ""               # set: switching a pending payment instead of buying


static func for_purchase(sid: String, pid: String, n: int, loc: String) -> SettlementModal:
	var m := SettlementModal.new()
	m.supplier = sid
	m.product = pid
	m.qty = n
	m.location = loc
	return m


static func for_pending(id: String) -> SettlementModal:
	var m := SettlementModal.new()
	m.po_id = id
	var po: Dictionary = Ecommerce.E()["purchase_orders"].get(id, {})
	m.supplier = str(po.get("supplier", ""))
	m.product = str(po.get("product", ""))
	m.qty = int(po.get("qty", 0))
	return m


func _init() -> void:
	title_text = "Pay a supplier abroad"
	icon_name = "bank"
	help_key = "settlement"
	panel_size = Vector2(430, 262)


func _amount() -> float:
	if po_id != "":
		return float(Ecommerce.E()["purchase_orders"][po_id]["total"])
	return snappedf(Ecommerce.unit_cost(supplier, product) * qty, 0.01)


func build() -> void:
	var amount := _amount()
	var art := Art.opt_tex("events/payment_pending")   # 160×90 illustration, once the art exists
	if art != null:
		var tr := TextureRect.new()
		tr.texture = art
		tr.custom_minimum_size = Vector2(160, 90) * 0.5
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
		body.add_child(tr)
	var head := I18n.t("%d × %s from %s: %s") % [qty, I18n.t(DataDB.product(product).get("name", product)), I18n.t(DataDB.supplier(supplier).get("name", supplier)), Fmt.money(amount)]
	body.add_child(UIK.label(head, 8, Art.C_WHITE, true))
	if po_id != "":
		var st: Dictionary = Ecommerce.E()["purchase_orders"][po_id]["settlement"]
		body.add_child(UIK.wrap(I18n.t("Paid by %s. It lands around %s; the supplier ships after that. A faster rail costs its own fee.") % [I18n.t(str(Ecommerce.settlement_def(str(st["method"]))["name"])), Clock.fmt_short(int(st["clears"]))], 7, Art.C_GOLD, 410))
	else:
		body.add_child(UIK.wrap("Cross-border payments are jammed. The supplier ships only once your money lands on their side.", 7, Art.C_MUTED, 410))
	for m in Ecommerce.settlement_options():
		var id := str(m["id"])
		if po_id != "" and id == str(Ecommerce.E()["purchase_orders"][po_id]["settlement"]["method"]):
			continue
		var row := UIK.hbox(6)
		var v := UIK.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		var h: Array = m.get("clear_hours", [24, 24])
		var speed := I18n.t("lands in about %d hour(s)") % int(h[0]) if int(h[1]) < 24 else (I18n.t("lands in %d–%d days") % [int(h[0]) / 24, int(h[1]) / 24] if h[0] != h[1] else I18n.t("lands in %d days") % (int(h[0]) / 24))
		v.add_child(UIK.label(I18n.t(str(m["name"])) + "  ·  " + I18n.t("fee %s") % Fmt.money(Ecommerce.settlement_fee(id, amount)) + "  ·  " + speed, 8, Art.C_WHITE, true))
		v.add_child(UIK.wrap(I18n.t(str(m.get("desc", ""))), 7, Art.C_MUTED, 300))
		var why := Ecommerce.settlement_block(id)
		if why != "":
			v.add_child(UIK.label(I18n.t(why), 7, Art.C_GOLD))
		var b := UIK.button("Pay this way" if po_id == "" else "Switch", _pay.bind(id), "primary" if why == "" else "", 72)
		b.name = "Settle_" + id
		b.disabled = why != ""
		row.add_child(b)
		body.add_child(UIK.card(row))
	footer.add_child(UIK.button("Cancel", close))


func _pay(method: String) -> void:
	var r: Dictionary
	if po_id != "":
		r = Ecommerce.switch_settlement(po_id, method)
		if r["ok"]:
			UIRoot.toast(I18n.t("Switched: the payment lands %s.") % Clock.fmt_short(int(r["clears"])), "good", "bank")
	else:
		r = Ecommerce.buy(supplier, product, qty, location, false, -1, 1.0, method)
		if r["ok"]:
			UIRoot.toast(I18n.t("Paid %s. The supplier ships once it lands.") % Fmt.money(r["total"]), "good", "bank")
	if not r["ok"]:
		UIRoot.toast(I18n.t(str(r["error"])), "bad", "warning")
		return
	close()
