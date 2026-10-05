class_name ExportIncomeModal
extends InfoModal
## Last converted foreign order: historical sale/fees and actual conversion allocation, all in home dollars.


func _init() -> void:
	title_text = "What your overseas order really earned"
	icon_name = "finance"
	help_key = "global_markets"
	panel_size = Vector2(430, 290)
	var order: Dictionary = {}
	for o in Ecommerce.foreign_orders():
		if o.get("entity", "") == GameState.company_id() and o.has("delivery_rate") and o.get("global_paid", false) and (order.is_empty() or int(o["delivered"]) > int(order["delivered"])):
			order = o
	if order.is_empty():
		lines = ["No converted overseas receipt is available. This chapter ended through the company-closure alternative."]
		return
	var source: Dictionary = {}
	for entry in Ledger.entries(str(order["entity"]), 100000):
		if entry.get("source", {}).get("type", "") == "fx_conversion" and entry["source"]["currency"] == order["currency"]:
			source = entry["source"]
			break
	var gross := snappedf(float(order["foreign_price"]) * int(order["qty"]) * float(order["delivery_rate"]), 0.01)
	var fee := float(order.get("fee", 0))
	var shipping := float(order.get("ship", {}).get("cost", 0)) + float(order.get("pickup_fee_share", 0))
	var foreign := float(order.get("foreign_due", 0))
	var spot := float(source.get("rate", order["delivery_rate"]))
	var spread := snappedf(foreign * spot * float(FX.cfg().get("bank_spread", 0.015)), 0.01)
	var current := snappedf(foreign * spot, 0.01)
	var net := current - spread - shipping
	lines = [["Sale at delivery (home dollars)", Fmt.money(gross)], ["Platform fee (home dollars)", Fmt.money(-fee)],
		["International freight (home dollars)", Fmt.money(-shipping)], ["Exchange rate difference (home dollars)", Fmt.money(current - gross + fee)],
		["Bank spread (home dollars)", Fmt.money(-spread)], ["Net receipt before stock and packing (home dollars)", Fmt.money(net)],
		"This allocates the conversion quote and pickup fee to this order. Stock, packing, duties and refunds still reduce profit; revenue is not cash."]
