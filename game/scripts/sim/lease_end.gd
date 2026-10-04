class_name LeaseEnd
extends RefCounted
## Lease notices retain the property until the paid notice expires. Exit is revalidated against current obligations.


static func error(text: String) -> Dictionary:
	return {"ok": false, "error": I18n.t(text)}


static func policy(pid: String) -> Dictionary:
	return DataDB.properties.get(pid, {})


static func workers(pid: String) -> Array:
	return Staff.people().filter(func(p): return str(p.get("workplace", Staff.workplace(str(p["role"])))) == pid)


static func obligations(pid: String) -> Array:
	var result: Array = []
	for order in Ecommerce.E()["orders"].values():
		if order.get("location", "") == pid and order["status"] in ["placed", "packed", "carrying", "awaiting_pickup"]:
			result.append({"kind": "order", "id": order["id"]})
	for po in Ecommerce.E()["purchase_orders"].values():
		if po.get("location", "") == pid and po["status"] in ["in_transit", "awaiting_payment"]:
			result.append({"kind": "purchase", "id": po["id"]})
	for contract in GameState.data["contracts"].values():
		if contract.get("location", "") == pid and contract["status"] == "active":
			result.append({"kind": "contract", "id": contract["id"]})
	var segment := str(policy(pid).get("lease_segment", ""))
	if segment != "":
		for job in Jobs.S()["items"].values():
			if job.get("segment", "") == segment and job.get("entity", "") == Living.D()["leases"].get(pid, {}).get("entity", "") and job["status"] in ["active", "delivered"]:
				result.append({"kind": "job", "id": job["id"]})
	return result


static func quote(pid: String, mode: String, plan: Dictionary = {}) -> Dictionary:
	var prop := policy(pid)
	var lease: Dictionary = Living.D()["leases"].get(pid, {})
	if prop.is_empty() or lease.is_empty(): return error("This property has no active lease.")
	if mode not in ["notice", "immediate"]: return error("Choose notice or immediate termination.")
	var ent := str(lease["entity"])
	if not is_finite(float(lease.get("rent", 0))) or float(lease.get("rent", 0)) < 0 or int(prop.get("notice_days", 30)) < 0 or float(prop.get("early_exit_fee_months", 0)) < 0:
		return error("Invalid lease terms. Review the property data before ending this lease.")
	if GameState.data["entities"].get(ent, {}).has("closed"): return error("This company is already closed.")
	if lease.has("ending"): return error("Notice has already been given. Review the pending notice.")
	if str(prop.get("kind", "")) == "home" and Living.home() == pid:
		return error("Choose a new home before ending your current home lease.")
	var count := Ecommerce.total_units_at(pid)
	var due := obligations(pid)
	var team := workers(pid)
	var destination := str(plan.get("destination", ""))
	if destination != "" and Living.D()["leases"].get(destination, {}).has("ending"): return error("Choose a destination that is not already ending its lease.")
	var stock_mode := str(plan.get("stock", ""))
	if pid == "unit12_factory" and (Manufacturing.material_units() > 0 or Manufacturing.S()["pos"].values().any(func(p): return p["status"] == "transit")) and stock_mode != "liquidate":
		return error("Liquidate factory materials and prepaid deliveries before ending the factory lease.")
	if count > 0 and stock_mode not in ["move", "liquidate"]: return error("Choose where to move stock, or sell it to the liquidator.")
	if (count > 0 and stock_mode == "move") or due.any(func(o): return o["kind"] != "job"):
		if destination == pid or not Ecommerce.stock_locations().has(destination): return error("Choose another active stock location for outstanding orders and deliveries.")
		if Ecommerce.space_block(destination, count + Ecommerce.incoming_units(pid)) != "": return error("The destination has insufficient room for stock and incoming deliveries.")
	if not team.is_empty() and str(plan.get("staff", "")) not in ["transfer", "dismiss"]: return error("Transfer or dismiss employees before their workplace ends.")
	if not team.is_empty() and str(plan.get("staff", "")) == "transfer":
		if destination == pid or not Living.has_lease(destination): return error("Choose another leased workplace for employees.")
		if int(policy(destination).get("capacity", {}).get("staff", 0)) < workers(destination).size() + team.size(): return error("The destination has insufficient staff capacity.")
	# Fixed-premises industries cannot transfer contracts into a warehouse. The player may finish work first or cancel it.
	if stock_mode == "liquidate" and due.any(func(o): return o["kind"] in ["order", "contract"]): return error("Move reserved stock with its orders, or finish those orders before liquidating. No customer stock may be sold away.")
	var jobs := due.filter(func(o): return o["kind"] == "job")
	if not jobs.is_empty() and str(plan.get("jobs", "")) != "cancel": return error("Finish industry jobs first, or cancel them with their contractual penalties.")
	var deposit := maxf(0.0, float(lease.get("deposit", float(lease["rent"]) * float(prop.get("deposit_months", 0)))))
	deposit = minf(deposit, maxf(0, Ledger.balance(ent, "deposits")))
	var damage := minf(deposit, maxf(0.0, float(lease.get("damage", 0.0))))
	var early := Clock.now() - int(lease["since"]) < int(prop.get("min_term_months", 0)) * 30 * Clock.DAY
	var notice := int(prop.get("notice_days", 30))
	var rent := snappedf(float(lease["rent"]) * notice / 30.0, 0.01)
	var fee := snappedf(float(lease["rent"]) * float(prop.get("early_exit_fee_months", 0)) if early else 0.0, 0.01)
	var moving := snappedf(count * float(prop.get("moving_cost_per_unit", 0.25)), 0.01) if stock_mode == "move" else 0.0
	var severance := 0.0
	if plan.get("staff", "") == "dismiss":
		for person in team: severance += float(person["salary_week"]) * float(Staff.cfg().get("severance_weeks", 1))
	var penalties := 0.0
	var refunds := 0.0
	for ob in jobs:
		var job := Jobs.get_job(ob["id"])
		penalties += snappedf(float(job["price"]) * float(job.get("penalty_rate", 0)), 0.01)
		refunds += float(job.get("deposit_paid", 0))
	var raw_value := 0.0
	if pid == "unit12_factory":
		for lot in Manufacturing.S()["lots"]: raw_value += int(lot["qty"]) * float(lot["unit"])
		for po in Manufacturing.S()["pos"].values():
			if po["status"] == "transit": raw_value += float(po["cost"])
	return {"ok": true, "entity": ent, "property": pid, "mode": mode, "plan": plan.duplicate(true), "notice_rent": rent,
		"early_fee": fee, "deposit": deposit, "damage": damage, "refund": deposit - damage, "moving": moving,
		"severance": severance, "penalties": penalties, "job_refunds": refunds, "stock_units": count, "workers": team.size(), "materials": snappedf(raw_value * float(prop.get("liquidation_rate", 0.4)), 0.01),
		"due": Clock.now() + notice * Clock.DAY if mode == "notice" else Clock.now(), "total": rent + fee + moving + severance + penalties + refunds}


static func end_lease(pid: String, mode: String, plan: Dictionary = {}) -> Dictionary:
	var q := quote(pid, mode, plan)
	if not q["ok"]: return q
	# Refunds are payable only when the lease actually ends; they never finance the upfront exit bill.
	if Ledger.cash(q["entity"]) < float(q["total"]): return error("Save enough cash for the notice, fees, moving and contract settlement first.")
	var lease: Dictionary = Living.D()["leases"][pid]
	Ledger.expense(q["entity"], Living.rent_category(str(policy(pid)["kind"])), q["notice_rent"], I18n.t("Lease notice rent: %s") % I18n.t(policy(pid)["name"]), {"type": "lease_notice", "id": pid})
	Ledger.expense(q["entity"], "penalties", q["early_fee"], I18n.t("Early lease exit: %s") % I18n.t(policy(pid)["name"]), {"type": "lease_exit", "id": pid})
	lease["ending"] = q.duplicate(true)
	GameState.timeline(I18n.t("Lease notice: %s · ends %s") % [I18n.t(policy(pid)["name"]), Clock.fmt_short(q["due"])], "business")
	if mode == "immediate": return _finish(pid)
	return q


static func _finish(pid: String) -> Dictionary:
	var lease: Dictionary = Living.D()["leases"].get(pid, {})
	if lease.is_empty() or not lease.has("ending"): return error("This property has no pending notice.")
	if GameState.data["entities"].get(str(lease["entity"]), {}).has("closed"): return error("This company is already closed.")
	var q: Dictionary = lease["ending"]
	if Clock.now() < int(q["due"]): return error("The notice period has not ended yet. Keep using the premises until the exit date.")
	var plan: Dictionary = q["plan"]
	# Revalidate a fresh quote without charging the already-paid notice a second time.
	lease.erase("ending")
	var current := quote(pid, q["mode"], plan)
	lease["ending"] = q
	if not current["ok"]:
		q["blocked"] = current["error"]
		return current
	var ent := str(q["entity"])
	var dest := str(plan.get("destination", ""))
	var count := Ecommerce.total_units_at(pid)
	var moving := float(current["moving"])
	if Ledger.cash(ent) < moving + float(current["severance"]) + float(current["penalties"]) + float(current["job_refunds"]):
		q["blocked"] = I18n.t("Cash changed during notice. Fund the remaining exit costs first.")
		return {"ok": false, "error": q["blocked"]}
	for ob in obligations(pid):
		if ob["kind"] == "job":
			var job := Jobs.get_job(ob["id"])
			var penalty := snappedf(float(job["price"]) * float(job.get("penalty_rate", 0)), 0.01)
			if job.get("segment", "") == "media":
				var campaign: Dictionary = Media.S()["campaigns"].get(job["id"], {})
				if not campaign.is_empty(): Media._settle(campaign, true)
			elif job.get("segment", "") == "hotel": Hotel.cancel_block(str(job["id"]))
			elif job.get("segment", "") == "energy": Energy.cancel_install(str(job["id"]), I18n.t("Premises lease ended"))
			var refund := float(job.get("deposit_paid", 0)) if job["status"] in ["active", "delivered"] else 0.0
			if refund > 0:
				Ledger.post(ent, I18n.t("Lease exit job refund: %s") % job["id"], [{"acct": "deferred_revenue", "dr": refund}, {"acct": "cash", "cr": refund}], {"type": "job", "id": job["id"], "segment": job["segment"]})
			Ledger.expense(ent, "penalties", penalty, I18n.t("Lease exit job penalty: %s") % job["id"], {"type": "job", "id": job["id"], "segment": job["segment"]})
			if job["status"] != "invoiced":
				job["deposit_paid"] = 0.0
				job["status"] = "closed"
			if job.get("segment", "") == "manufacturing":
				var order: Dictionary = Manufacturing.S()["orders"].get(job["id"], {})
				if not order.is_empty(): order["status"] = "cancelled"
		else:
			var record: Dictionary = Ecommerce.E()["orders"][ob["id"]] if ob["kind"] == "order" else Ecommerce.E()["purchase_orders"][ob["id"]] if ob["kind"] == "purchase" else GameState.data["contracts"][ob["id"]]
			record["location"] = dest
	for product in Ecommerce.inv(pid).keys():
		var item: Dictionary = Ecommerce.inv(pid)[product]
		var qty := int(item["qty"])
		if qty <= 0: continue
		if plan.get("stock", "") == "move":
			Ecommerce._add_stock(dest, product, qty, float(item["avg_cost"]), float(item.get("defect_rate", 0)))
		else:
			var value := snappedf(qty * float(item["avg_cost"]), 0.01)
			var proceeds := snappedf(value * float(policy(pid).get("liquidation_rate", 0.4)), 0.01)
			Ledger.post(ent, I18n.t("Lease exit stock liquidation: %s") % product, [{"acct": "cash", "dr": proceeds}, {"acct": "exp:inventory_writeoff", "dr": value - proceeds}, {"acct": "inventory", "cr": value}], {"type": "liquidation", "segment": "ecommerce"})
		item["qty"] = 0
	Ledger.expense(ent, "shipping", moving, I18n.t("Lease exit stock move: %d units") % count, {"type": "lease_move", "id": pid})
	for person in workers(pid):
		if plan.get("staff", "") == "transfer": person["workplace"] = dest
		else: Staff.let_go(str(person["id"]))
	var damage := minf(float(current["damage"]), float(current["deposit"]))
	var deposit := float(current["deposit"])
	if deposit > 0:
		Ledger.post(ent, I18n.t("Lease deposit settlement: %s") % I18n.t(policy(pid)["name"]), [{"acct": "cash", "dr": deposit - damage}, {"acct": "exp:maintenance", "dr": damage}, {"acct": "deposits", "cr": deposit}], {"type": "lease_exit", "id": pid})
	if pid == "aster_inn": Hotel._ota_settle()
	if pid == "unit12_factory": _liquidate_materials(ent, pid)
	Living.D()["leases"].erase(pid)
	GameState.set_flag("leased_" + pid, false)
	BuildingInfo.invalidate_availability()
	GameState.timeline(I18n.t("Lease ended: %s") % I18n.t(policy(pid)["name"]), "business")
	EventBus.world_refresh.emit()
	# Movement consumes simulation time only after all obligations and deposit balances are settled.
	var minutes := count * int(policy(pid).get("moving_minutes_per_unit", 1)) if plan.get("stock", "") == "move" else 0
	if minutes > 0: Clock.advance(minutes)
	return {"ok": true, "refund": deposit - damage, "ended": pid}


static func on_hour() -> void:
	for pid in Living.D()["leases"].keys():
		var lease: Dictionary = Living.D()["leases"][pid]
		if lease.has("ending") and Clock.now() >= int(lease["ending"]["due"]) and not lease["ending"].has("blocked"):
			var result := _finish(pid)
			if not result["ok"]: GameState.add_message("landlord", I18n.t("Lease exit needs attention: %s") % result["error"])


## Usage and incident damage affect the deposit claim; expense is recognized only at actual settlement.
static func record_damage(pid: String, amount: float) -> Dictionary:
	var lease: Dictionary = Living.D()["leases"].get(pid, {})
	if lease.is_empty() or not is_finite(amount) or amount < 0: return error("Invalid property damage claim.")
	var deposit := float(lease.get("deposit", float(lease["rent"]) * float(policy(pid).get("deposit_months", 0))))
	lease["damage"] = minf(deposit, float(lease.get("damage", 0)) + amount)
	return {"ok": true, "damage": lease["damage"]}


## Raw materials cannot be used in a warehouse. Cancel scheduled deliveries and realize their liquidation once.
static func _liquidate_materials(ent: String, pid: String) -> void:
	var raw := 0.0
	var transit := 0.0
	for lot in Manufacturing.S()["lots"]: raw += int(lot["qty"]) * float(lot["unit"])
	for po in Manufacturing.S()["pos"].values():
		if po["status"] == "transit":
			transit += float(po["cost"])
			po["status"] = "closed"
			Sim.cancel("mfg.arrival", "id", po["id"])
	raw = snappedf(raw, 0.01)
	transit = snappedf(transit, 0.01)
	var raised := snappedf((raw + transit) * float(policy(pid).get("liquidation_rate", 0.4)), 0.01)
	if raw + transit > 0:
		Ledger.post(ent, I18n.t("Factory materials liquidated"), [{"acct": "cash", "dr": raised}, {"acct": "exp:inventory_writeoff", "dr": raw + transit - raised}, {"acct": "inventory", "cr": raw}, {"acct": "inventory_in_transit", "cr": transit}], Manufacturing.source())
	Manufacturing.S()["lots"] = []
