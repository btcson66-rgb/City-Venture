class_name Effects
extends RefCounted
## Closed vocabulary of effects used by events and story actions.


static func _num(v: Variant, ctx: Dictionary) -> float:
	if typeof(v) == TYPE_STRING:
		if ctx.has(v):
			return float(ctx[v])
		return float(v)
	return float(v)


## Cheap validation of the effects that can refuse, so a multi-effect reply is applied whole or not at all
## without copying the entire game state. Unknown or always-succeeding ops pass.
static func preflight(e: Dictionary, ctx: Dictionary) -> Dictionary:
	match str(e.get("op", "")):
		"purchase", "rush_order":
			if Ecommerce.offer(str(ctx.get("supplier_id", e.get("supplier", "tradelink_wholesale"))), str(ctx.get("product_id", e.get("product", "")))).is_empty():
				return {"ok": false, "error": "Supplier doesn't carry that."}
		"industry":
			var module := Industries.find(str(e.get("industry", "")))
			if module.is_empty() or not module["sim_class"].has_method("crisis"):
				return {"ok": false, "error": I18n.t("Unknown industry event.")}
		"fund_board":
			var deal := Fundraising.get_deal(str(e.get("deal", ctx.get("deal", ""))))
			if deal.is_empty() or deal["status"] != "signed" or str(deal.get("board", {}).get("status", "")) != "open":
				return {"ok": false, "error": I18n.t("This board review is already closed.")}
		"fund_partner":
			var item := Partnerships.get_item(str(e.get("id", ctx.get("partnership", ""))))
			if item.is_empty() or item["status"] != "offered":
				return {"ok": false, "error": I18n.t("This proposal is no longer open.")}
	return {"ok": true}


static func apply(e: Dictionary, ctx: Dictionary) -> Dictionary:
	var op: String = e.get("op", "")
	var ent := GameState.business_entity()
	match op:
		"cafe_inspection":
			return CafeDepth.decision(ctx,bool(e.get("prepare",false)))
		"market_strategy":
			return LegacyBusiness.choose(str(e["strategy"]))
		"customs_hold":
			return Customs.resolve(str(ctx.get("order", "")), str(e.get("choice", "")))

		"shop_network":
			return ShopLife.network_choice(str(e.get("kind", "")), ctx)
		"lease_damage":
			return LeaseEnd.record_damage(str(e.get("property", ctx.get("property", ""))), _num(e.get("amount", 0), ctx))
		"industry":
			var module := Industries.find(str(e.get("industry", "")))
			if module.is_empty() or not module["sim_class"].has_method("crisis"):
				return {"ok":false, "error":I18n.t("Unknown industry event.")}
			Insurance.crisis_context={"entity":ent,"industry":e.get("industry","")}
			var result: Dictionary
			if module["sim_class"].has_method("crisis_context"):
				result=module["sim_class"].crisis_context(str(e.get("kind","")),bool(e.get("retain",true)),ctx)
			else:
				result=module["sim_class"].crisis(str(e.get("kind", "")), bool(e.get("retain", true)))
			Insurance.crisis_context={}
			if result.get("ok",false):Brand.record(ent,"crises",2 if e.get("retain",true) else -2)
			return result
		"cash":
			var amt := _num(e.get("amount", 0), ctx)
			var cat: String = e.get("category", "other")
			if amt < 0:
				Ledger.expense(ent, cat, -amt, EventEngine.fill(e.get("memo", "Event cost"), ctx), {"type": "event"})
			elif amt > 0:
				Ledger.post(ent, EventEngine.fill(e.get("memo", "Event income"), ctx), [{"acct": "cash", "dr": amt}, {"acct": "other_income", "cr": amt}], {"type": "event"})
		"refund_order":
			return Ecommerce.resolve_return(ctx.get("order", ""), "refund")
		"replace_order":
			return Ecommerce.resolve_return(ctx.get("order", ""), "replace")
		"partial_refund":
			return Ecommerce.resolve_return(ctx.get("order", ""), "partial")
		"refuse_return":
			return Ecommerce.resolve_return(ctx.get("order", ""), "refuse")
		"purchase", "rush_order":
			var sup: String = ctx.get("supplier_id", e.get("supplier", "tradelink_wholesale"))
			var pid: String = ctx.get("product_id", e.get("product", ""))
			var o := Ecommerce.offer(sup, pid)
			if o.is_empty():
				return {"ok": false, "error": "Supplier doesn't carry that."}
			var qty := int(o["moq"]) if str(e.get("qty", "moq")) == "moq" else int(e["qty"])
			var lead := int(e.get("lead_days", -1))
			var mult := float(e.get("cost_mult", 1.0))
			return Ecommerce.buy(sup, pid, qty, "", false, lead, mult)
		"supplier_price_mod":
			var sup_id: String = ctx.get("supplier_id", e.get("supplier", "*"))
			# "cancel_era": undo the era's surcharge for this supplier (a supply agreement at pre-shock prices)
			var pm := 1.0 / World.cost_mult(sup_id) if str(e.get("mult", 1.0)) == "cancel_era" else float(e.get("mult", 1.0))
			GameState.data["ecommerce"]["supplier_mods"].append({
				"supplier": sup_id, "product": ctx.get("product_id", "*") if str(e.get("mult", 1.0)) != "cancel_era" else "*",
				"mult": pm, "from": Clock.now() + int(e.get("from_days", 0)) * Clock.DAY,
				"until": Clock.now() + int(e.get("days", 30)) * Clock.DAY})
		"demand_mod":
			GameState.data["ecommerce"]["demand_mods"].append({"product": ctx.get("product_id", "*") if e.get("scope", "product") == "product" else "*",
				"mult": float(e.get("mult", 1.0)), "until": Clock.now() + int(e.get("days", 3)) * Clock.DAY})
		"ad_price_mod":
			GameState.data["ecommerce"]["ad_price_mult"] = float(e.get("mult", 1.0))
			GameState.data["ecommerce"]["ad_price_until"] = Clock.now() + int(e.get("days", 7)) * Clock.DAY
		"listing_mod":
			var l := Ecommerce.listing_for(ctx.get("product_id", ""))
			if not l.is_empty():
				if e.has("price_mult"):
					Ecommerce.set_price(l["id"], float(l["price"]) * float(e["price_mult"]))
				if e.has("ad_budget_mult"):
					Ecommerce.set_ad_budget(l["id"], float(l["ad_budget"]) * float(e["ad_budget_mult"]))
		"pause_ads":
			Ecommerce.pause_all_ads()
		"create_contract_offer":
			var tpl: Dictionary = e.get("template", {}).duplicate(true)
			var cid := Contracts.create_offer(tpl)
			ctx["contract_id"] = cid
		"liquidate_inventory":
			var raised := Ecommerce.liquidate_all(float(e.get("rate", DataDB.living().get("liquidation_rate", 0.4))))
			return {"ok": true, "raised": raised}
		"reduce_spending":
			Ecommerce.pause_all_ads()
			GameState.data["living"]["reduced"] = true
		"equity_investment":
			# an investor buys `stake` of the company for `amount`: cash in, equity up, founder diluted (one path with every other round)
			var amt := _num(e.get("amount", 0), ctx)
			if GameState.company_id() == "":
				return {"ok": false, "error": "Investors buy shares in a registered company."}
			return Fundraising.issue_equity(str(e.get("investor", "investor")), amt, float(e.get("stake", 0.1)), EventEngine.fill(e.get("memo", "Equity investment"), ctx), {})
		"fund_intro":
			var offered := str(e.get("investor", ctx.get("investor", "elena")))
			return Fundraising.intro_offer(offered) if str(e.get("choice", "sign")) == "review" else Fundraising.intro_sign(offered)
		"fund_board":
			return Fundraising.board_decide(str(e.get("deal", ctx.get("deal", ""))), str(e.get("choice", "")))
		"fund_partner":
			return Partnerships.respond(str(e.get("id", ctx.get("partnership", ""))), str(e.get("choice", "")))
		"open_escrow":
			Rails.open_escrow()
		"rail_choice":
			# the bridge freeze decision (Chapter 11): wait, reroute by wire, or borrow and reroute
			return Rails.decide(str(e.get("choice", "")))
		"shipment_lost":
			return Rails.lost_shipment(str(ctx.get("po_id", "")), str(e.get("choice", "")))
		"acquisition":
			# Hale Group's offer (Chapter 12): accept, counter or decline
			return Acquisition.decide(str(e.get("choice", "")), ctx)
		"set_flag":
			GameState.set_flag(e["flag"], e.get("value", true))
		"message":
			GameState.add_message(e["from"], EventEngine.fill(e["text"], ctx), e.get("options", {}))
		"timeline":
			GameState.timeline(EventEngine.fill(e["text"], ctx), e.get("kind", "event"))
		"none":
			pass
		_:
			push_warning("Effects: unknown op " + op)
	return {"ok": true}
