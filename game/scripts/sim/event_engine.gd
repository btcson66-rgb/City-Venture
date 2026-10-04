class_name EventEngine
extends RefCounted
## Data-driven dynamic events (Handoff §32, kickoff §17). Each event binds context,
## is presented to the player as a decision, and its effects change money / inventory / options.


static func S() -> Dictionary:
	return GameState.data["events"]


static func on_hour(t: int, h: int) -> void:
	if h != 9 and h != 15:
		return
	for id in DataDB.events:
		var d: Dictionary = DataDB.events[id]
		var tr: Dictionary = d.get("trigger", {})
		if tr.get("when", "") != "daily" or d.get("status", "active") != "active":
			continue
		if tr.get("once", false) and S()["fired"].has(id):
			continue
		if int(S()["cooldowns"].get(id, 0)) > t:
			continue
		if Clock.day_index() < int(tr.get("earliest_day", 0)):
			continue
		if _queued(id):
			continue
		if not Cond.all(tr.get("conditions", [])):
			continue
		if GameState.randf() >= clampf(float(tr.get("chance", 0.0)) * Replay.number("event_frequency", 1.0) / 2.0, 0.0, 1.0):
			continue
		var ctx := bind(d)
		if ctx.is_empty() and not d.get("bind", {}).is_empty():
			continue
		trigger(id, ctx)


static func _queued(id: String) -> bool:
	for q in S()["queue"]:
		if q["id"] == id:
			return true
	return false


## Resolve `bind` selectors into a context dictionary (empty if the event can't apply right now).
static func bind(d: Dictionary) -> Dictionary:
	var ctx := {}
	var b: Dictionary = d.get("bind", {})
	if b.has("acquisition"):
		return Acquisition.context()   # Hale Group's price, from the company's own books
	if b.has("import_po"):
		# an import shipment that is on the way (the latest one placed)
		var pick := {}
		for po in GameState.data["ecommerce"]["purchase_orders"].values():
			if str(po["status"]) == "in_transit" and World.is_import(str(po["supplier"])) and (pick.is_empty() or int(po["placed"]) > int(pick["placed"])):
				pick = po
		if pick.is_empty():
			return {}
		return {"po_id": str(pick["id"]), "supplier": I18n.t(str(DataDB.supplier(str(pick["supplier"]))["name"])), "qty": int(pick["qty"]),
			"product": I18n.t(str(DataDB.product(str(pick["product"]))["name"])), "total": Fmt.money0(float(pick["total"])),
			"escrow": str(pick.get("escrow", "")) == "held", "days": int(Rails.cfg().get("shipment_lost", {}).get("reship_days", 10))}
	if b.has("product"):
		var best := ""
		var best_n := -1
		for l in GameState.data["ecommerce"]["listings"].values():
			var ok: bool = l.get("active", false) or b["product"] == "any_listed"
			if ok and int(l["orders"]) > best_n:
				best_n = int(l["orders"])
				best = l["product"]
		if b["product"] == "bottle_or_best":
			best = "water_bottle"
		if best == "":
			return {}
		ctx["product_id"] = best
		ctx["product"] = I18n.t(DataDB.product(best)["name"])
		ctx["product_lower"] = I18n.t(str(ctx["product"])) if I18n.is_zh() else str(ctx["product"]).to_lower()
	if b.has("supplier"):
		var counts := {}
		for po in GameState.data["ecommerce"]["purchase_orders"].values():
			if not ctx.has("product_id") or po["product"] == ctx["product_id"]:
				counts[po["supplier"]] = int(counts.get(po["supplier"], 0)) + 1
		var sup := ""
		var n := 0
		for s in counts:
			if int(counts[s]) > n:
				n = int(counts[s])
				sup = s
		if sup == "":
			return {}
		ctx["supplier_id"] = sup
		ctx["supplier"] = I18n.t(DataDB.supplier(sup)["name"])
		var o := Ecommerce.offer(sup, ctx.get("product_id", ""))
		if not o.is_empty():
			ctx["moq"] = int(o["moq"])
			ctx["unit_cost"] = Fmt.money0(Ecommerce.unit_cost(sup, ctx["product_id"]))
			ctx["moq_cost_v"] = Ecommerce.unit_cost(sup, ctx["product_id"]) * int(o["moq"])
			ctx["moq_cost"] = Fmt.money0(ctx["moq_cost_v"])
	return ctx


static func trigger(id: String, ctx := {}) -> Dictionary:
	var d: Dictionary = DataDB.events.get(id, {})
	if d.is_empty():
		push_warning("EventEngine: unknown event " + id)
		return {}
	if ctx.is_empty() and not d.get("bind", {}).is_empty():
		ctx = bind(d)   # a chapter fires its events with no context: bind the product and supplier now
	S()["fired"][id] = int(S()["fired"].get(id, 0)) + 1
	var cd := int(d.get("trigger", {}).get("cooldown_days", 0))
	if cd > 0:
		S()["cooldowns"][id] = Clock.now() + cd * Clock.DAY
	if ctx.is_empty() and not d.get("bind", {}).is_empty():
		ctx = bind(d)   # a story action or a conversation fires the event with no context of its own
	var inst := {"iid": "%s-%d" % [id, int(S()["fired"][id])], "id": id, "ctx": ctx, "t": Clock.now()}
	S()["queue"].append(inst)
	var pres: Dictionary = d.get("presentation", {})
	if pres.get("channel", "phone") == "phone" and pres.get("speaker", "") != "":
		var lines: Array = pres.get("lines", [])
		if not lines.is_empty():
			GameState.add_message(pres["speaker"], fill(str(lines[0]), ctx))
	EventBus.decision_requested.emit(inst)
	return inst


static func pending() -> Array:
	return S()["queue"]


static func next_pending() -> Dictionary:
	return {} if S()["queue"].is_empty() else S()["queue"][0]


static func fill(text: String, ctx: Dictionary) -> String:
	text = I18n.t(text)  # translate the template first, then drop the values in
	for k in ctx:
		var v = ctx[k]
		# values that are data text (a return reason, a product name) translate too; names/amounts pass through
		text = text.replace("{" + str(k) + "}", I18n.t(v) if v is String else str(v))
	text = text.replace("{company}", GameState.business_display_name())
	text = text.replace("{player}", str(GameState.data["player"]["name"]))
	text = text.replace("{international_fee}", Fmt.money(float(GlobalMarket.cfg().get("bank_open_fee", 150))))
	return text


static func choice_available(c: Dictionary, ctx: Dictionary) -> bool:
	for r in c.get("requires", []):
		var expr := fill(str(r), ctx)
		if expr.contains("{moq_cost_v}"):
			expr = expr.replace("{moq_cost_v}", str(ctx.get("moq_cost_v", 0)))
		if not Cond.eval(expr, ctx):
			return false
	return true


## Apply the player's decision.
static func choose(iid: String, choice_id: String) -> Dictionary:
	var inst := {}
	for q in S()["queue"]:
		if q["iid"] == iid:
			inst = q
	if inst.is_empty():
		return {"ok": false, "error": "No such decision."}
	var d: Dictionary = DataDB.events[inst["id"]]
	var choice := {}
	for c in d.get("choices", []):
		if c["id"] == choice_id:
			choice = c
	if choice.is_empty():
		return {"ok": false, "error": "No such choice."}
	if not choice_available(choice, inst["ctx"]):
		return {"ok": false, "error": "You can't do that right now."}
	var results: Array = []
	for e in choice.get("effects", []):
		var r := Effects.apply(e, inst["ctx"])
		results.append(r)
		if not r.get("ok", true):
			return {"ok": false, "error": r.get("error", "That didn't work.")}
	S()["queue"].erase(inst)
	S()["history"].append({"iid": iid, "id": inst["id"], "t": Clock.now(), "choice": choice_id})
	GameState.timeline(I18n.t("Decision: %s — %s") % [fill(str(d.get("presentation", {}).get("title", inst["id"])), inst["ctx"]), fill(str(choice.get("label", choice_id)), inst["ctx"])], "crisis", {"art":"events/" + str(inst["id"])})
	EventBus.world_refresh.emit()
	return {"ok": true, "results": results, "outcome": fill(str(choice.get("outcome", "")), inst["ctx"])}


static func handle(kind: String, p: Dictionary) -> void:
	if kind == "evt.trigger":
		if p.get("story_once", false):
			var guard := "event_done:" + str(p["id"])
			if GameState.flag(guard) or _queued(p["id"]):
				return
			GameState.set_flag(guard)
		trigger(p["id"], p.get("ctx", {}))
