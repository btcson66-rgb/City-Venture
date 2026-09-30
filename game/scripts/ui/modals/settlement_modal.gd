class_name SettlementModal
extends Modal
## Paying a supplier abroad (Year 5 on): pick a rail, see what it costs, how long the money takes to land and how
## reliable the rail has been. Opened when you buy from an importer, or later to speed up a payment stuck on the wire
## (or to reroute one frozen on the bridge, Chapter 11).

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
	panel_size = Vector2(440, 330)


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
	var frozen_po := false
	if po_id != "":
		var po: Dictionary = Ecommerce.E()["purchase_orders"][po_id]
		var st: Dictionary = po["settlement"]
		frozen_po = Rails.is_frozen_po(po)
		if frozen_po:
			body.add_child(UIK.wrap(I18n.t("Your payment is stuck on the frozen bridge until about %s. Pay again by another rail to get the goods moving; the frozen money comes back when the bridge reopens.") % Clock.fmt_short(Rails.frozen_until()), 7, Art.C_RED, 410))
		else:
			body.add_child(UIK.wrap(I18n.t("Paid by %s. It lands around %s; the supplier ships after that. A faster rail costs its own fee.") % [I18n.t(str(Ecommerce.settlement_def(str(st["method"]))["name"])), Clock.fmt_short(int(st["clears"]))], 7, Art.C_GOLD, 410))
	else:
		body.add_child(UIK.wrap("Cross-border payments are jammed. The supplier ships only once your money lands on their side.", 7, Art.C_MUTED, 410) if World.year() < 6 \
			else UIK.wrap("The supplier ships only once your money lands on their side. Compare the rails: fee, speed and track record.", 7, Art.C_MUTED, 410))
	var kyc := Compliance.kyc(amount) if po_id == "" else {}
	if not kyc.is_empty():
		body.add_child(UIK.label_tip(I18n.t("KYC check: %s and %d more hours before this payment lands (payments over %s).") % [Fmt.money(float(kyc["fee"])), int(kyc["hours"]), Fmt.money0(Compliance.kyc_threshold())], "kyc", 7, Art.C_GOLD))
	var list := UIK.vbox(3)
	for m in Ecommerce.settlement_options():
		var id := str(m["id"])
		if po_id != "" and not frozen_po and id == str(Ecommerce.E()["purchase_orders"][po_id]["settlement"]["method"]):
			continue
		if frozen_po and Rails.is_digital(id):
			continue   # the frozen rail can't rescue a payment stuck on it
		var row := UIK.hbox(6)
		var v := UIK.vbox(0)
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(v)
		var h: Array = Ecommerce.settlement_range(id)
		var speed := I18n.t("lands in about %d hour(s)") % int(h[0]) if int(h[1]) < 24 else (I18n.t("lands in %d–%d days") % [int(h[0]) / 24, int(h[1]) / 24] if h[0] != h[1] else I18n.t("lands in %d days") % (int(h[0]) / 24))
		var title := I18n.t(str(m["name"])) + "  ·  " + I18n.t("fee %s") % Fmt.money(Ecommerce.settlement_fee(id, amount)) + "  ·  " + speed
		var title_row: Control = UIK.label_tip(title, str(m["tip"]), 8, Art.C_WHITE, true) if m.has("tip") else UIK.label(title, 8, Art.C_WHITE, true)
		v.add_child(title_row)
		v.add_child(UIK.wrap(I18n.t(str(m.get("desc", ""))), 7, Art.C_MUTED, 300))
		var rel := Rails.reliability(id)
		var rec := Rails.reliability_text(id) + ("  ·  " + I18n.t("regular rate") if Rails.fee_mult(id) < 1.0 else "")
		v.add_child(UIK.label_tip(rec, "rail_reliability", 7, Art.C_RED if rel < 0.9 else Art.C_SKY))
		var why := Ecommerce.settlement_block(id)
		if why != "":
			v.add_child(UIK.label(I18n.t(why), 7, Art.C_GOLD))
		var b := UIK.button("Pay this way" if po_id == "" else ("Reroute" if frozen_po else "Switch"), _pay.bind(id), "primary" if why == "" else "", 72)
		b.name = "Settle_" + id
		b.disabled = why != ""
		row.add_child(b)
		list.add_child(UIK.card(row))
	body.add_child(UIK.scroll(list, Vector2(420, 218)))
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
