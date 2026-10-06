class_name CapitalMarket
extends RefCounted
## Company-bound transactions and listing receipts; NPC company numbers are labelled scenarios, never player income.
static func cfg() -> Dictionary:
	return DataDB.economy["capital_market"]
static func S() -> Dictionary:
	if not GameState.data.has("capital_market"):
		GameState.data["capital_market"] = {"entity":"", "route":"", "offers":[], "targets":{}, "ipo":{}, "integrations":[], "quarter_reports":[], "npc_mergers":[], "pressure":{}, "reputation":float(cfg()["reputation_start"])}
	return GameState.data["capital_market"]
static func live() -> bool:
	return GlobalMarket.live(str(S()["entity"])) and S()["entity"] == GameState.company_id()
static func valuation(revenue: float, previous: float) -> float:
	if not is_finite(revenue) or not is_finite(previous): return 0
	var growth := clampf((revenue - previous) / maxf(1, previous), -float(cfg()["growth_cap"]), float(cfg()["growth_cap"]))
	return snappedf(maxf(0,revenue) * float(cfg()["revenue_multiple"]) * (1 + growth), .01)
## Yearly closes rescan the journal, so results are kept for the current ledger state and hour; any new entry or time step recomputes.
static func annual(ent: String, offset := 0) -> Dictionary:
	var cache: Dictionary = S().get_or_add("cache", {})
	var key := "%s|%d|%d|%d" % [ent, offset, GameState.data["ledger"]["journal"].size(), Clock.now() / int(cfg()["valuation_cache_minutes"])]
	if cache.has(key): return cache[key]
	if cache.size() > 16: cache.clear()
	var end := Clock.now() + 1 - offset * int(cfg()["window_days"]) * Clock.DAY
	cache[key] = MonthClose.compute(ent, end - int(cfg()["window_days"]) * Clock.DAY, end)
	return cache[key]
static func begin() -> void:
	if World.year() < 9: return
	if S()["entity"] != GameState.company_id():
		GameState.data.erase("capital_market")
		S()["entity"] = GameState.company_id()
	if not live(): return
	if Acquisition.sold():
		S()["route"]="acquired"
		S()["buyer"]=GameState.data.get("acquisition_receipt",{}).get("buyer","Hale Group")
		return
	if not S()["offers"].is_empty():
		if S()["offers"].any(func(o):return o["status"]=="open" and Clock.now()<=int(o["expires"])): return
		S()["offers"].clear()
		S()["next_offers"]=Clock.now()+int(cfg()["offer_cooldown_days"])*Clock.DAY
	if Clock.now()<int(S().get("next_offers",0)): return
	var price := company_valuation()
	for i in cfg()["npc_companies"].size():
		var npc: Dictionary = cfg()["npc_companies"][i]
		S()["offers"].append({"id":npc["id"],"name":npc["name"],"factor":1+float(cfg()["offer_premium_step"])*i,"price":snappedf(price*(1+float(cfg()["offer_premium_step"])*i),.01),"ready":Clock.now()+int(cfg()["due_days"])*Clock.DAY,"expires":Clock.now()+int(cfg()["offer_days"])*Clock.DAY,"status":"open"})
		if not S()["targets"].has(npc["id"]): S()["targets"][npc["id"]] = npc.duplicate(true)
	if S()["npc_mergers"].is_empty(): S()["npc_mergers"] = [{"buyer":"hale","target":"meridian","at":Clock.now()+3*Clock.DAY,"done":false}]
	if not S().get("announced",false):
		S()["announced"]=true
		GameState.timeline(I18n.t("Consolidation opens: NPC companies review acquisitions and public listings."), "world")
static func offer_block(id: String) -> String:
	if not live(): return "This company is closed or replaced. Continue with your current life."
	if S()["route"] in ["acquired","public"]: return "Ownership is already committed. Review the recorded route."
	for offer in S()["offers"]:
		if offer["id"] != id: continue
		if offer["status"] != "open" or Clock.now() > int(offer["expires"]): return "This offer has expired or was declined. Choose another route."
		if Clock.now() < int(offer["ready"]): return "Due diligence is still running. Continue operating until its stated date."
		if Acquisition.sold() or float(GameState.data.get("cap_table",{}).get("founder",1)) <= 0: return "These founder shares have already been sold. Continue operating."
		if final_offer_price(offer)<=0: return "The company no longer has positive sale value. Keep operating or remain private."
		return ""
	return "Choose an available offer."
static func sell(id: String) -> Dictionary:
	var why := offer_block(id)
	if why != "": return {"ok":false,"error":why}
	var offer: Dictionary = S()["offers"].filter(func(o):return o["id"]==id)[0]
	var founder := float(GameState.data.get("cap_table",{}).get("founder",1))
	var sale_price := final_offer_price(offer)
	var take := Fundraising.founder_proceeds(sale_price)
	var carrying := HoldingGroups.basis(GameState.company_id())
	var gain := take-carrying
	var lines: Array = [{"acct":"cash","dr":take},{"acct":"investments","cr":carrying}]
	lines.append({"acct":"other_income","cr":gain} if gain >= 0 else {"acct":"exp:other","dr":-gain})
	Ledger.post("player",I18n.t("Founder share sale to %s: %s")%[offer["name"],Fmt.money(take)],lines,{"type":"sale","entity":S()["entity"]})
	offer["status"]="accepted"
	S()["route"]="acquired"
	S()["buyer"]=offer["name"]
	GameState.data["cap_table"]={str(offer["id"]):1.0}
	GameState.data["acquisition_receipt"]={"entity":S()["entity"],"price":sale_price,"choice":"accept","buyer":offer["name"],"t":Clock.now()}
	GameState.set_flag("company_sold")
	GameState.timeline(I18n.t("Sold founder shares to %s for %s; the company continues under its new owner.")%[offer["name"],Fmt.money(take)],"milestone")
	return {"ok":true,"paid":take}
static func private_route() -> Dictionary:
	if S()["route"] == "private" and not S()["ipo"].get("stage","") in ["audit","roadshow","priced"]: return {"ok":true}
	if S()["route"] in ["acquired","public"]: return {"ok":false,"error":"Ownership is already committed. Review the recorded route."}
	S()["route"]="private"
	if S()["ipo"].get("stage","") in ["audit","roadshow","priced"]: S()["ipo"]["stage"]="withdrawn"
	GameState.timeline(I18n.t("Kept the company private: no listing capital, no public quarterly obligation."), "company")
	return {"ok":true}
static func board_approve(cost: float) -> bool:
	if S()["route"] != "public": return true
	var shares: Dictionary = GameState.data.get("cap_table",{"founder":1.0})
	var votes := float(shares.get("founder",0))
	if cost <= maxf(0,Ledger.cash(str(S()["entity"]))) * float(cfg()["board_cash_share"]):
		for owner in shares:
			if owner != "founder": votes += float(shares[owner])
	S()["last_vote"]={"for":votes,"cost":cost,"approved":votes>.5,"at":Clock.now()}
	return votes > .5
static func acquire(id: String) -> Dictionary:
	if not live(): return {"ok":false,"error":"This company is closed or replaced. Continue with your current life."}
	var target: Dictionary = S()["targets"].get(id,{})
	if target.is_empty() or target.has("owner"): return {"ok":false,"error":"This target is no longer independent. Review another company."}
	var price := valuation(float(target["revenue"]),float(target["revenue"])/(1+float(target["growth"])))
	var fee := snappedf(price * float(cfg()["integration_fee_share"]),.01)
	if Ledger.cash(S()["entity"]) < price+fee: return {"ok":false,"error":"Retain cash for the purchase and integration fee, or arrange a bank loan."}
	if not board_approve(price+fee): return {"ok":false,"error":"The board rejected this large purchase. Reduce the commitment or keep operating."}
	Ledger.post(S()["entity"],I18n.t("Company acquisition: %s")%Fmt.money(price),[{"acct":"investments","dr":price},{"acct":"cash","cr":price}],{"type":"acquisition","target":id})
	Ledger.expense(S()["entity"],"other",fee,I18n.t("Integration systems fee: %s")%Fmt.money(fee),{"type":"integration","target":id})
	target["owner"]=S()["entity"]
	S()["integrations"].append({"target":id,"ready":Clock.now()+int(cfg()["integration_days"])*Clock.DAY,"staff_before":target["staff"],"staff_after":maxi(0,int(target["staff"])-maxi(1,int(ceil(float(target["staff"])*float(cfg()["integration_loss_share"]))))),"fee":fee,"done":false})
	GameState.timeline(I18n.t("Bought %s; integration carries staff attrition and systems cost, without assumed revenue.")%target["name"],"company")
	return {"ok":true,"price":price,"fee":fee}
static func ipo_block() -> String:
	if not live(): return "This company is closed or replaced. Continue with your current life."
	if Acquisition.sold() or S()["route"] in ["public","acquired"]: return "Ownership is already committed. Review the recorded route."
	if Clock.now() < int(cfg()["profitable_years"]) * int(cfg()["window_days"]) * Clock.DAY: return "Operate through two complete years before applying."
	if float(annual(S()["entity"])["net_revenue"]) < float(cfg()["annual_revenue_min"]): return "Build the required actual annual revenue before applying."
	for i in int(cfg()["profitable_years"]):
		if float(annual(S()["entity"],i)["business_profit"]) <= 0: return "Both consecutive complete operating years must be profitable."
	if float(MonthClose.compute(S()["entity"],Clock.now()-int(cfg()["recovery_days"])*Clock.DAY,Clock.now()+1)["opex"].get("penalties",0)) > 0: return "Build a complete clean compliance year before applying; prior fines remain disclosed."
	return ""
static func start_audit(id: String) -> Dictionary:
	var why := ipo_block()
	if why != "": return {"ok":false,"error":why}
	if not S()["ipo"].is_empty() and not S()["ipo"].get("stage","") in ["failed","withdrawn"]: return {"ok":false,"error":"The listing process is already running. Continue its next step."}
	var chosen: Array = cfg()["underwriters"].filter(func(u):return u["id"]==id)
	if chosen.is_empty(): return {"ok":false,"error":"Choose an underwriter."}
	var u: Dictionary = chosen[0]
	if Ledger.cash(S()["entity"]) < float(u["fee"]): return {"ok":false,"error":"Keep enough company cash for the audit fee."}
	Ledger.expense(S()["entity"],"other",u["fee"],I18n.t("Listing audit fee: %s")%Fmt.money(float(u["fee"])),{"type":"listing_audit"})
	S()["ipo"]={"stage":"audit","underwriter":id,"ready":Clock.now()+int(cfg()["audit_days"])*Clock.DAY,"answers":[],"score":0,"price":0.0}
	return {"ok":true}
static func progress_audit() -> Dictionary:
	var ipo: Dictionary = S()["ipo"]
	if ipo.get("stage","") != "audit": return {"ok":false,"error":"No audit is waiting. Review the current listing step."}
	if Clock.now() < int(ipo["ready"]): return {"ok":false,"error":"The audit is still running. Continue operating until its stated date."}
	var why := ipo_block()
	if why != "":
		ipo["stage"]="failed"
		ipo["failure"]=why
		return {"ok":false,"error":why}
	ipo["stage"]="roadshow"
	return {"ok":true}
static func answer(index: int, transparent: bool) -> Dictionary:
	var ipo: Dictionary = S()["ipo"]
	if not live() or ipo.get("stage","") != "roadshow" or index != ipo["answers"].size() or index >= cfg()["questions"].size(): return {"ok":false,"error":"This investor question is already answered or unavailable. Continue the current step."}
	ipo["answers"].append(transparent)
	if transparent: ipo["score"]=int(ipo["score"])+1
	# Each answer trades price against time and risk: detail is slower and prices lower, a bold promise prices higher but investors may see through it.
	var effect: Dictionary = cfg()["questions"][index]["good_effect" if transparent else "risk_effect"]
	ipo["factor"]=float(ipo.get("factor",1.0))*float(effect["price_factor"])
	ipo["delay_days"]=int(ipo.get("delay_days",0))+int(effect["delay_days"])
	if float(effect["caught_chance"])>0 and GameState.randf()<float(effect["caught_chance"]): ipo["caught"]=true
	if ipo["answers"].size() == cfg()["questions"].size():
		ipo["stage"]="failed" if ipo.get("caught",false) else "priced"
		ipo["failure"]="Investors declined unsupported promises. The audit fee is not refunded."
		ipo["valuation"] = company_valuation() * float(ipo["factor"])
		ipo["price"] = snappedf(float(ipo["valuation"])/int(cfg()["shares"]),.01)
		ipo["list_after"] = Clock.now()+int(ipo["delay_days"])*Clock.DAY
	return {"ok":true}
static func list_company() -> Dictionary:
	var ipo: Dictionary = S()["ipo"]
	var why := ipo_block()
	if why != "": return {"ok":false,"error":why}
	if ipo.get("stage","") != "priced": return {"ok":false,"error":"Complete the roadshow and review the price first."}
	var u: Dictionary = cfg()["underwriters"].filter(func(row):return row["id"]==ipo["underwriter"])[0]
	if Clock.now() < int(ipo.get("list_after",0)): return {"ok":false,"error":"Detailed disclosures are still being reviewed. Continue operating until the stated listing date."}
	if company_valuation()*float(ipo["factor"])+.01 < float(ipo["valuation"]):
		ipo["stage"]="failed"
		ipo["failure"]="The company books changed after pricing. Rebuild the record and reapply, or remain private."
		return {"ok":false,"error":ipo["failure"]}
	var gross := snappedf(float(ipo["valuation"])*float(cfg()["public_share"]),.01)
	var fee := snappedf(gross*float(u["commission"]),.01)
	Ledger.post(S()["entity"],I18n.t("Public share subscription: %s")%Fmt.money(gross),[{"acct":"cash","dr":gross},{"acct":"equity:public","cr":gross}],{"type":"capital"})
	Ledger.expense(S()["entity"],"bank_fees",fee,I18n.t("Underwriting commission: %s")%Fmt.money(fee),{"type":"listing"})
	var shares: Dictionary = GameState.data.get("cap_table",{"founder":1.0}).duplicate()
	for owner in shares: shares[owner]=float(shares[owner])*(1-float(cfg()["public_share"]))
	shares["public"]=float(shares.get("public",0))+float(cfg()["public_share"])
	GameState.data["cap_table"]=shares
	Fundraising.on_public_listing()
	S()["route"]="public"
	ipo["stage"]="listed"
	ipo["next_quarter"]=Clock.now()+int(cfg()["quarter_days"])*Clock.DAY
	ipo["quarter_start"]=Clock.now()
	ipo["expectation"]=float(annual(S()["entity"])["net_revenue"])*float(cfg()["quarter_expectation_share"])
	GameState.timeline(I18n.t("Listed shares at %s home dollars per share; quarterly reporting and board votes now apply.")%Fmt.money(float(ipo["price"])),"milestone")
	return {"ok":true,"capital":gross,"fee":fee}
static func on_hour() -> void:
	if World.year() >= 9: begin()
	if not live(): return
	for merger in S()["npc_mergers"]:
		if not merger["done"] and Clock.now() >= int(merger["at"]):
			var target: Dictionary = S()["targets"].get(merger["target"],{})
			if not target.has("owner"):
				target["owner"]=merger["buyer"]
				GameState.timeline(I18n.t("Hale Group acquired Meridian Supply; it is no longer an independent target."),"world")
			merger["done"]=true
	for task in S()["integrations"]:
		if not task["done"] and Clock.now() >= int(task["ready"]):
			S()["targets"][task["target"]]["staff"]=task["staff_after"]
			task["done"]=true
			GameState.timeline(I18n.t("Acquisition integration completed; the staff attrition is recorded, without invented sales."),"company")
	var ipo: Dictionary = S()["ipo"]
	if S()["route"] == "public" and Clock.now() >= int(ipo.get("next_quarter",9223372036854775807)):
		var report := MonthClose.compute(S()["entity"],int(ipo["quarter_start"]),int(ipo["next_quarter"]))
		var missed := float(report["net_revenue"]) < float(ipo["expectation"]) or float(report["business_profit"]) < 0
		ipo["price"] = snappedf(float(ipo["price"])*float(cfg()["miss_price_factor"] if missed else cfg()["beat_price_factor"]),.01)
		S()["quarter_reports"].append({"at":ipo["next_quarter"],"actual":report["net_revenue"],"expected":ipo["expectation"],"missed":missed,"price":ipo["price"]})
		if missed:
			S()["reputation"] = maxf(float(cfg()["reputation_min"]),float(S()["reputation"])-float(cfg()["reputation_hit"]))
			var hits := {}
			for person in Staff.people():
				var hit := mini(int(person["morale"]),int(cfg()["morale_hit"]))
				person["morale"] = int(person["morale"])-hit
				hits[person["id"]] = hit
			S()["pressure"]={"until":Clock.now()+int(cfg()["pressure_days"])*Clock.DAY,"hits":hits}
		GameState.timeline(I18n.t("Quarterly report published: actual results changed the quoted share price."),"company")
		ipo["quarter_start"]=ipo["next_quarter"]
		ipo["next_quarter"]=int(ipo["next_quarter"])+int(cfg()["quarter_days"])*Clock.DAY
	if not S()["pressure"].is_empty() and Clock.now() >= int(S()["pressure"]["until"]):
		for person in Staff.people(): person["morale"]=mini(100,int(person["morale"])+int(S()["pressure"].get("hits",{}).get(person["id"],0)))
		S()["reputation"] = minf(float(cfg()["reputation_start"]),float(S()["reputation"])+float(cfg()["reputation_hit"]))
		S()["pressure"].clear()
static func route_text() -> String:
	return I18n.t({"public":"You raised equity rather than sales income; quarterly disclosure and board votes now limit your freedom.","acquired":"You sold existing founder shares; the payout is an ownership transaction and your company answers to its new owner.","private":"You retained private ownership and its risks, without public capital or quarterly market pressure."}.get(str(S()["route"]),"No consolidation ownership route was recorded."))

static func demand_factor() -> float:
	return float(S()["reputation"])/float(cfg()["reputation_start"]) if live() and S()["route"]=="public" else 1.0

static func board_grant_approve() -> bool:
	var votes := float(GameState.data.get("cap_table",{}).get("founder",0))
	S()["last_vote"]={"for":votes,"kind":"employee_grant","approved":votes>.5,"at":Clock.now()}
	return votes>.5

static func company_valuation() -> float:
	if not live(): return 0
	var q := Acquisition.quote()
	return snappedf(maxf(0,valuation(float(annual(S()["entity"])["net_revenue"]),float(annual(S()["entity"],1)["net_revenue"]))+float(q["cash"])+float(q["stock"])+float(q["owed"])+maxf(0,Ledger.balance(str(S()["entity"]),"investments"))-float(q["debts"])),.01)

static func final_offer_price(offer: Dictionary) -> float:
	return snappedf(minf(float(offer["price"]),company_valuation()*float(offer.get("factor",1))),.01)
