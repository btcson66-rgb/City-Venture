class_name Company
extends RefCounted
## Business registration (City Hall) and business banking (Nexus Bank).
## Registration creates the company entity; operations move onto its books once a business
## account is opened and capitalised (until then the founder's personal account carries it).


static func slug(name: String) -> String:
	var s := name.to_lower().strip_edges()
	var out := ""
	for ch in s:
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif ch.unicode_at(0) >= 0x2E80:
			# CJK and other scripts: keep the id ASCII-safe with the code point ("河光" -> "u6cb3u5149")
			out += "u%x" % ch.unicode_at(0)
		elif out != "" and not out.ends_with("_"):
			out += "_"
	return out.trim_suffix("_").left(40)


static func validate_name(name: String) -> String:
	var n := name.strip_edges()
	var cjk := false
	for ch in n:
		if ch.unicode_at(0) >= 0x2E80:
			cjk = true
	if n.length() < (2 if cjk else 3):
		return "Company names need at least 3 characters." if not cjk else "Company names need at least 2 characters."
	if n.length() > 28:
		return "Keep it under 28 characters."
	if slug(n) == "":
		return "Use letters or numbers."
	for c in DataDB.companies.values():
		if str(c.get("name", "")).to_lower() == n.to_lower():
			return "That name is already registered in Aurelia."
	return ""


static func registration() -> Dictionary:
	return DataDB.regulations.get("company_registration_aurelia", {})


## Registration fee after the City Hall clerk's staff discount.
static func registration_fee() -> float:
	return snappedf(float(registration().get("fee", 300)) * (1.0 - Careers.perk_value("registration_discount")), 0.01)


static func register(name: String, business_type: String, address: String) -> Dictionary:
	if GameState.company_id() != "":
		return {"ok": false, "error": "You already own a registered company."}
	var err := validate_name(name)
	if err != "":
		return {"ok": false, "error": err}
	var reg := registration()
	var fee := registration_fee()
	if Ledger.cash("player") < fee:
		return {"ok": false, "error": I18n.t("The registration fee is %s.") % Fmt.money0(fee)}
	var cid := "co_" + slug(name)
	var k := 2
	while GameState.data["entities"].has(cid):   # a closed company keeps its books; a restart gets a fresh id
		cid = "co_%s_%d" % [slug(name), k]
		k += 1
	var n := name.strip_edges()
	if not n.to_lower().ends_with(" ltd") and not n.to_lower().ends_with(" inc") and not n.to_lower().ends_with(" co"):
		pass
	GameState.data["entities"][cid] = {"id": cid, "name": n, "kind": "company", "type": business_type, "address": address,
		"founded": Clock.now(), "bank_account": false, "seller_account": "business", "registration_no": "AUR-%06d" % (GameState.randi_range(100000, 999999))}
	GameState.data["company"] = cid
	Ledger.expense("player", "registration", fee, I18n.t("Company registration fee — %s") % n, {"type": "registration"})
	GameState.set_flag("company_registered")
	Ecommerce.lift_cap()
	GameState.timeline(I18n.t("Founded %s (registration %s).") % [n, GameState.data["entities"][cid]["registration_no"]], "milestone")
	EventBus.company_registered.emit(cid)
	EventBus.world_refresh.emit()
	return {"ok": true, "company": cid}


## Open the company's business account and move `capital` from personal savings into it.
static func open_business_account(capital: float) -> Dictionary:
	var cid := GameState.company_id()
	if cid == "":
		return {"ok": false, "error": "Register a company at City Hall first."}
	if GameState.flag("business_account_opened"):
		return {"ok": false, "error": "The account is already open."}
	if capital < 500.0:
		return {"ok": false, "error": "Minimum opening deposit is $500."}
	if Ledger.cash("player") < capital:
		return {"ok": false, "error": I18n.t("You only have %s personally.") % Fmt.money0(Ledger.cash("player"))}
	Ledger.post("player", I18n.t("Capital injected into %s") % GameState.entity_name(cid), [{"acct": "investments", "dr": capital}, {"acct": "cash", "cr": capital}], {"type": "capital"})
	Ledger.post(cid, "Founder capital (opening deposit)", [{"acct": "cash", "dr": capital}, {"acct": "equity", "cr": capital}], {"type": "capital"})
	GameState.data["entities"][cid]["bank_account"] = true
	GameState.set_flag("business_account_opened")
	Ecommerce.transfer_business_to(cid)
	GameState.timeline(I18n.t("Opened a business account at Nexus Bank with %s of founder capital.") % Fmt.money0(capital), "business")
	EventBus.world_refresh.emit()
	return {"ok": true}


## Move money between personal and company accounts later on.
static func transfer(from_ent: String, to_ent: String, amount: float) -> Dictionary:
	if Acquisition.sold():
		return {"ok": false, "error": "The company belongs to Hale Group now: no money moves between it and you."}
	if amount <= 0.0 or Ledger.cash(from_ent) < amount:
		return {"ok": false, "error": "Not enough cash."}
	if from_ent == "player":
		Ledger.post("player", I18n.t("Transfer to %s") % GameState.entity_name(to_ent), [{"acct": "investments", "dr": amount}, {"acct": "cash", "cr": amount}], {"type": "transfer"})
		Ledger.post(to_ent, "Additional founder capital", [{"acct": "cash", "dr": amount}, {"acct": "equity", "cr": amount}], {"type": "transfer"})
	else:
		Ledger.post(from_ent, "Owner withdrawal", [{"acct": "equity", "dr": amount}, {"acct": "cash", "cr": amount}], {"type": "transfer"})
		Ledger.post("player", I18n.t("Withdrawal from %s") % GameState.entity_name(from_ent), [{"acct": "cash", "dr": amount}, {"acct": "investments", "cr": amount}], {"type": "transfer"})
	return {"ok": true}


static func company_value() -> float:
	var e := GameState.business_entity()
	return Ledger.cash(e) + Ledger.balance(e, "inventory") + Ledger.balance(e, "inventory_in_transit") + Ledger.balance(e, "goods_out") \
		+ Ledger.balance(e, "marketplace_balance") + Ledger.balance(e, "accounts_receivable") + Ledger.balance(e, "deposits") \
		+ Ledger.balance(e, "accounts_payable") + Ledger.balance(e, "deferred_revenue") + Ledger.balance(e, "escrow_held") + Ledger.balance(e, "frozen_funds") + Ledger.balance(e, "fixed_assets")


# ================================================================ Green Business Grant (Year 4)
const GREEN_GRANT := 3000.0


## A green product live on ShopLane (the solar desk lamp, or anything with `eco` in its data).
static func has_green_listing() -> bool:
	for l in Ecommerce.E()["listings"].values():
		if l.get("active", false) and bool(DataDB.product(l["product"]).get("eco", false)):
			return true
	return false


## Why the grant can't be claimed yet ("" = it can): the checklist the permits kiosk shows.
static func green_grant_block() -> String:
	if World.year() < 4:
		return "The grant opens with the Green Shift."
	if GameState.flag("green_grant"):
		return "Already granted."
	if GameState.company_id() == "":
		return "Only registered companies can apply."
	if Ecommerce.packaging() != "recycled":
		return "Switch to recycled packaging first (Company OS → Operations)."
	if not has_green_listing():
		return "List a green product on ShopLane first."
	return ""


static func claim_green_grant() -> Dictionary:
	var why := green_grant_block()
	if why != "":
		return {"ok": false, "error": why}
	Ledger.post(GameState.company_id(), I18n.t("Green Business Grant — City of Aurelia"),
		[{"acct": "cash", "dr": GREEN_GRANT}, {"acct": "other_income", "cr": GREEN_GRANT}], {"type": "grant"})
	GameState.set_flag("green_grant")
	GameState.timeline(I18n.t("Won the city's Green Business Grant: %s.") % Fmt.money0(GREEN_GRANT), "milestone")
	return {"ok": true, "amount": GREEN_GRANT}
