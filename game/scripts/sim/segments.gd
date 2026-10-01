class_name Segments
extends RefCounted
## Revenue/cost attribution plus exact-cent allocation; reporting never creates journal entries.

static func compute(entity: String, t0: int, t1: int) -> Dictionary:
	var rows := {}
	for entry in Industries.all():
		rows[entry["id"]] = _row(entry["id"])
	rows["shared"] = _row("shared")
	for entry in GameState.data["ledger"]["journal"]:
		if entry["entity"] != entity or int(entry["t"]) < t0 or int(entry["t"]) >= t1:
			continue
		var segment := str(entry.get("source", {}).get("segment", Industries.infer_segment(entry.get("source", {}), entry["lines"])))
		if not rows.has(segment): rows[segment] = _row(segment)
		var row: Dictionary = rows[segment]
		for line in entry["lines"]:
			var account := str(line["acct"])
			var amount := float(line.get("dr", 0)) - float(line.get("cr", 0))
			if account == "revenue": row["revenue"] -= amount
			elif account == "refunds": row["refunds"] += amount
			elif account == "cogs": row["cogs"] += amount
			elif account == "other_income": row["other_income"] -= amount
			elif account.begins_with("exp:") and account.substr(4) in Ledger.OPEX_BUSINESS:
				row["opex"] += amount
	var weight := 0.0
	var recipients: Array = []
	for id in rows:
		rows[id]["net_revenue"] = snappedf(float(rows[id]["revenue"]) - float(rows[id]["refunds"]), 0.01)
		if id != "shared" and float(rows[id]["net_revenue"]) > 0:
			recipients.append(id)
			weight += float(rows[id]["net_revenue"])
	var remaining := snappedf(float(rows["shared"]["opex"]), 0.01)
	var pool := remaining
	if weight > 0:
		rows["shared"]["opex"] = 0.0
		for i in range(recipients.size()):
			var id: String = recipients[i]
			var allocation := remaining if i == recipients.size()-1 else snappedf(pool * float(rows[id]["net_revenue"]) / weight, 0.01)
			rows[id]["allocated"] = allocation
			rows[id]["opex"] += allocation
			remaining = snappedf(remaining - allocation, 0.01)
	var totals := _row("total")
	for row in rows.values():
		row["gross_profit"] = snappedf(float(row["net_revenue"]) - float(row["cogs"]), 0.01)
		row["operating_profit"] = snappedf(float(row["gross_profit"]) - float(row["opex"]) + float(row["other_income"]), 0.01)
		for key in ["revenue", "refunds", "net_revenue", "cogs", "gross_profit", "opex", "other_income", "operating_profit"]:
			totals[key] = snappedf(float(totals[key]) + float(row[key]), 0.01)
	return {"rows":rows, "totals":totals, "shared_pool":pool}

static func _row(id: String) -> Dictionary:
	return {"id":id, "revenue":0.0, "refunds":0.0, "net_revenue":0.0, "cogs":0.0,
		"gross_profit":0.0, "opex":0.0, "allocated":0.0, "other_income":0.0, "operating_profit":0.0}
