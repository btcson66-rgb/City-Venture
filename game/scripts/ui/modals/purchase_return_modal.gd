class_name PurchaseReturnModal
extends Modal
## Confirmation quotes are checked again by the simulation when the player confirms.

var po_id := ""
var cancelling := false
var qty := 1


func _init(id: String, cancel := false) -> void:
	po_id = id
	cancelling = cancel
	title_text = "Cancel purchase" if cancelling else "Return stock to supplier"
	help_key = "purchase_returns"
	icon_name = "parcel"
	panel_size = Vector2(440, 0)
	pauses_time = true


func build() -> void:
	var po: Dictionary = Ecommerce.E()["purchase_orders"].get(po_id, {})
	if po.is_empty():
		body.add_child(UIK.label("That purchase order no longer exists."))
		return
	body.add_child(UIK.label(po_id + " · " + I18n.t(DataDB.supplier(str(po["supplier"]))["name"]), 9, Art.C_WHITE, true))
	body.add_child(UIK.label_tip("Cancel purchase" if cancelling else "Return stock to supplier", "purchase_cancel" if cancelling else "purchase_return"))
	var why := Ecommerce.cancel_block(po_id) if cancelling else Ecommerce.return_block(po_id)
	if not cancelling:
		var max_qty := Ecommerce.return_max(po_id)
		qty = clampi(qty, 1, maxi(1, max_qty))
		var row := UIK.hbox(6)
		row.add_child(UIK.label(I18n.t("Quantity (up to %d)") % max_qty))
		var less := UIK.button("−", func(): qty = maxi(1, qty - 1); rebuild())
		less.name = "ReturnQtyMinus"
		less.disabled = qty <= 1
		row.add_child(less)
		row.add_child(UIK.label(str(qty)))
		var more := UIK.button("+", func(): qty = mini(Ecommerce.return_max(po_id), qty + 1); rebuild())
		more.name = "ReturnQtyPlus"
		more.disabled = qty >= max_qty
		row.add_child(more)
		body.add_child(row)
	var quote := Ecommerce.cancel_quote(po_id) if cancelling else Ecommerce.return_quote(po_id, qty)
	body.add_child(UIK.kv("Invoice reduction" if cancelling and quote["unpaid"] else "Refund", Fmt.money0(float(quote["refund"])), Art.C_GREEN))
	body.add_child(UIK.label_tip(I18n.t("Return & cancellation fees") + ": " + Fmt.money0(float(quote["fee"])), "restocking_fee"))
	if cancelling:
		body.add_child(UIK.wrap("Refunded now. Unpaid terms reduce your invoice; any cancellation fee stays payable on its original due date. Settlement fees are not refundable.", 8, Art.C_MUTED, 410))
	else:
		body.add_child(UIK.kv("Return shipping", Fmt.money0(float(quote["shipping"]))))
		body.add_child(UIK.wrap(I18n.t("Cash arrives when the supplier receives the stock: %s. Reserved units cannot be returned.") % Clock.fmt_short(int(quote["due"])), 8, Art.C_MUTED, 410))
		if Ledger.cash(str(po["entity"])) < float(quote["shipping"]):
			why = I18n.t("Not enough cash for return shipping: %s.") % Fmt.money0(float(quote["shipping"]))
	if why != "":
		body.add_child(UIK.wrap(why, 8, Art.C_RED, 410))
	var confirm := UIK.button("Confirm cancellation" if cancelling else "Confirm return", _confirm, "primary")
	confirm.name = "ConfirmReturn"
	confirm.disabled = why != ""
	footer.add_child(confirm)
	_recenter.call_deferred()


func _recenter() -> void:
	await get_tree().process_frame
	panel.position = (Vector2(640, 360) - panel.size) / 2.0


func _confirm() -> void:
	var result := Ecommerce.cancel_purchase(po_id) if cancelling else Ecommerce.return_purchase(po_id, qty)
	if not result["ok"]:
		UIRoot.toast(result["error"], "bad", "warning")
		rebuild()
		return
	UIRoot.toast("Purchase cancelled." if cancelling else "Stock sent back. Refund is pending.", "good", "parcel")
	close()
