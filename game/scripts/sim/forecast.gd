class_name Forecast
extends RefCounted
## Cash forecast, week by week ("Revenue ≠ cash", Chapters 4 and 6). Uses what is actually scheduled
## or contracted: payroll every Friday, office rent, loan payments, supplier invoices on terms,
## customer and contract receivables on their due dates, the ShopLane balance on the next Monday,
## ad spend, plus an estimate of marketplace sales from the last 14 days. Restocking is left out
## on purpose: it's the decision the forecast is there to inform.


static func weekly(ent: String, weeks := 9) -> Dictionary:
	var now := Clock.now()
	var horizon := now + weeks * 7 * Clock.DAY
	var flows: Array = []   # [t, amount, label]
	# payroll
	var pay := 0.0
	for p in Staff.people():
		pay += float(p["salary_week"])
	if pay > 0.0 and ent == Staff.entity():
		var t := _next_weekday_at(int(Staff.cfg().get("payroll_weekday", 5)), int(Staff.cfg().get("payroll_hour", 17)) * 60)
		var first := true
		while t < horizon:
			flows.append([t, -(pay + (Staff.wages_owed() if first else 0.0)), "Payroll"])
			first = false
			t += 7 * Clock.DAY
	# leases on this entity
	for pid in GameState.data["living"]["leases"]:
		var ls: Dictionary = GameState.data["living"]["leases"][pid]
		if ls.get("entity", "") != ent:
			continue
		var t2 := _next_day_of_month(int(ls.get("day", 1)))
		while t2 < horizon:
			flows.append([t2, -float(ls["rent"]), "Rent"])
			t2 = _next_day_of_month(int(ls.get("day", 1)), t2 + Clock.DAY)
	if ent == "player":
		var lv := DataDB.living()
		var t3 := _next_day_of_month(int(lv.get("rent_due_day_of_month", 14)))
		while t3 < horizon:
			flows.append([t3, -Living.home_rent(), "Home rent"])
			t3 = _next_day_of_month(int(lv.get("rent_due_day_of_month", 14)), t3 + Clock.DAY)
		var bill_at := Living.next_living_bill_at()
		# Auto-paid on issue; manual bills have the same grace period as AssistantPolicy.bill.
		var grace := 0 if bool(AssistantPolicy.S()["tasks"].get("bills", true)) else int(AssistantPolicy.cfg().get("bill_due_days", 7)) * Clock.DAY
		while bill_at + grace < horizon:
			flows.append([bill_at + grace, -Living.daily_living() * 7.0, "Living costs"])
			bill_at += 7 * Clock.DAY
	# Already-issued unpaid bills retain their saved due dates, including older saves.
	for bill in AssistantPolicy.S().get("bills", []):
		if not bill.get("paid", false) and bill.get("entity", "") == ent:
			flows.append([maxi(now, int(bill.get("due", now))), -float(bill["amount"]), "Bills due"])
	# loans
	for l in Bank.loans(ent):
		var bal := float(l["balance"])
		var t4 := int(l["next"])
		while t4 < horizon and bal > 0.01:
			var amt := minf(float(l["payment"]), bal * (1.0 + float(l["apr"]) / 12.0))
			flows.append([t4, -amt, "Loan payment"])
			bal -= amt - bal * float(l["apr"]) / 12.0
			t4 += 30 * Clock.DAY
	# scheduled money: supplier invoices, contract and gig receivables
	for it in GameState.data["schedule"]:
		var t5 := int(it["t"])
		if t5 >= horizon:
			continue
		match str(it["kind"]):
			"eco.ap_due":
				var po: Dictionary = GameState.data["ecommerce"]["purchase_orders"].get(str(it["p"].get("po", "")), {})
				if not po.is_empty() and po.get("entity", "") == ent:
					flows.append([t5, -float(po["total"]), "Supplier invoice"])
			"con.pay":
				var c: Dictionary = GameState.data["contracts"].get(str(it["p"].get("id", "")), {})
				if not c.is_empty() and c.get("seller", "") == ent and c["status"] == "delivered":
					flows.append([t5, float(c["receivable"]), I18n.t("%s pays") % GameState.entity_name(c["buyer"])])
			"rail.unfreeze":
				# frozen bridge money comes back at the recovery ratio; whoever waited tops up the gap
				var ratio := float(Rails.X().get("ratio", 0.9))
				for fi in Rails.X().get("items", []):
					if str(fi["entity"]) != ent:
						continue
					if bool(fi["rerouted"]):
						flows.append([t5, float(fi["amount"]) * ratio, "Frozen funds return"])
					else:
						flows.append([t5, -float(fi["amount"]) * (1.0 - ratio), "Bridge shortfall"])
			"car.gig_paid":
				var g: Dictionary = Careers.F()["gigs"].get(str(it["p"].get("id", "")), {})
				if not g.is_empty() and g.get("entity", "") == ent and g["status"] == "invoiced":
					flows.append([t5, float(g["invoiced"]), "Client payment"])
	# ShopLane balance lands on the next Monday payout
	var mb := Ledger.balance(ent, "marketplace_balance")
	if mb > 0.01:
		flows.append([_next_weekday_at(1, 9 * 60), mb, "ShopLane payout"])
	# estimated marketplace sales (net of fees), paid out weekly
	var est := _sales_run_rate(ent)
	var ads := Ecommerce.total_ad_budget() if ent == GameState.business_entity() else 0.0
	var rows: Array = []
	var cash := Ledger.cash(ent)
	var low := cash
	var first_negative := -1
	for w in weeks:
		var w0 := now + w * 7 * Clock.DAY
		var w1 := w0 + 7 * Clock.DAY
		var inflow := 0.0
		var outflow := 0.0
		var items := {}
		for f in flows:
			if int(f[0]) >= w0 and int(f[0]) < w1:
				var a := float(f[1])
				if a >= 0:
					inflow += a
				else:
					outflow -= a
				items[f[2]] = float(items.get(f[2], 0.0)) + a
		if w >= 1 and est > 0.0:
			inflow += est * 7.0
			items["Estimated sales"] = est * 7.0
		if ads > 0.0:
			outflow += ads * 7.0
			items["Ads"] = -ads * 7.0
		cash += inflow - outflow
		if cash < low:
			low = cash
		if cash < 0.0 and first_negative < 0:
			first_negative = w
		rows.append({"start": w0, "in": inflow, "out": outflow, "end": cash, "items": items})
	return {"rows": rows, "low": low, "first_negative": first_negative, "start_cash": Ledger.cash(ent), "run_rate": est}


static func ok(ent: String) -> bool:
	return weekly(ent)["first_negative"] < 0


## Average daily marketplace sales net of fees and refunds over the last 14 days.
static func _sales_run_rate(ent: String) -> float:
	var t0 := Clock.now() - 14 * Clock.DAY
	var s := 0.0
	for o in GameState.data["ecommerce"]["orders"].values():
		if o.get("entity", "") != ent or int(o.get("t", o.get("placed", 0))) < t0:
			continue
		if o["status"] in ["refunded", "cancelled"]:
			continue
		s += float(o["unit_price"]) * int(o["qty"]) - float(o.get("fee", 0.0))
	return s / 14.0


static func _next_weekday_at(wd: int, minute: int) -> int:
	var t := Clock.now() - Clock.minute_of_day() + minute
	for i in 8:
		if Clock.weekday(t) == wd and t > Clock.now():
			return t
		t += Clock.DAY
	return t


static func _next_day_of_month(day: int, from := -1) -> int:
	var t := (Clock.now() if from < 0 else from)
	t = t - (t % Clock.DAY) + 9 * 60
	for i in 40:
		if int(Clock.date_at(t)["day"]) == day and t >= (Clock.now() if from < 0 else from) - 9 * 60:
			return t
		t += Clock.DAY
	return t
