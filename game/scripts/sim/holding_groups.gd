class_name HoldingGroups
extends RefCounted
## Full-owned subsidiary transfers, real inventory trades and financing. Consolidation removes held stock markup and reciprocal claims.
static func cfg() -> Dictionary: return CompanyPortfolio.cfg()
static func S() -> Dictionary:
	if not GameState.data.has("holding_groups"):
		var basis := {}
		var ids := CompanyPortfolio.ids(true)
		if ids.size()==1: basis[ids[0]]=maxf(0,Ledger.balance("player","investments"))
		GameState.data["holding_groups"]={"basis":basis,"parents":{},"loans":{},"seq":1,"guarantees":{},"trades":[],"margin":{},"margin_events":[],"reports":[]}
	return GameState.data["holding_groups"]
static func basis(id: String) -> float: return float(S()["basis"].get(id,0))
static func add_basis(id: String,amount: float) -> void: S()["basis"][id]=maxf(0,basis(id)+amount)
static func owner(id: String) -> String: return str(S()["parents"].get(id,"player"))
static func members(parent: String) -> Array:
	var result: Array=[parent]
	var changed := true
	while changed:
		changed=false
		for child in S()["parents"]:
			if S()["parents"][child] in result and not result.has(child): result.append(child); changed=true
	return result.filter(func(id):return GlobalMarket.live(str(id)))
static func hold(parent: String,child: String) -> Dictionary:
	if parent==child or not GlobalMarket.live(parent) or not GlobalMarket.live(child) or GameState.data["entities"][parent]["type"]!=cfg()["holding_type"] or owner(child)!="player" or members(child).has(parent): return {"ok":false,"error":"Choose an independent operating company and a live holding company."}
	var shares: Dictionary = CompanyPortfolio.run_in(child,func():return GameState.data.get("cap_table",{"founder":1.0}))
	if float(shares.get("founder",0))<1: return {"ok":false,"error":"Only wholly founder-owned companies can enter this holding group. Other shareholders keep their rights."}
	var value := basis(child)
	if value>0:
		Ledger.post("player",I18n.t("Subsidiary shares transferred: %s")%Fmt.money(value),[{"acct":"investments","cr":value},{"acct":"investments","dr":value}],{"type":"ownership","subsidiary":child})
		Ledger.post(parent,I18n.t("Investment in subsidiary: %s")%Fmt.money(value),[{"acct":"investment_in_subsidiary:"+child,"dr":value},{"acct":"equity","cr":value}],{"type":"capital","subsidiary":child})
		add_basis(parent,value)
	S()["parents"][child]=parent
	CompanyPortfolio.run_in(child,func():GameState.data["cap_table"]={parent:1.0})
	GameState.timeline(I18n.t("Placed %s into %s through a book-value share transfer.")%[GameState.entity_name(child),GameState.entity_name(parent)],"company")
	return {"ok":true,"book":value}
static func release(parent: String,child: String) -> Dictionary:
	if owner(child)!=parent: return {"ok":false,"error":"This subsidiary is no longer held here. Choose another company."}
	var value := maxf(0,Ledger.balance(parent,"investment_in_subsidiary:"+child))
	if value>0:
		Ledger.post(parent,I18n.t("Subsidiary released at book value: %s")%Fmt.money(value),[{"acct":"equity","dr":value},{"acct":"investment_in_subsidiary:"+child,"cr":value}],{"type":"ownership"})
		add_basis(parent,-value)
	S()["parents"].erase(child)
	CompanyPortfolio.run_in(child,func():GameState.data["cap_table"]={"founder":1.0})
	return {"ok":true}
static func loan(lender: String,borrower: String,amount: float) -> Dictionary:
	if lender==borrower or not GlobalMarket.live(lender) or not GlobalMarket.live(borrower) or owner(borrower)!=lender or not is_finite(amount) or amount<=0 or Ledger.cash(lender)<amount: return {"ok":false,"error":"Use a funded holding company and its live subsidiary for this loan."}
	var id := "GROUP-%d"%int(S()["seq"])
	S()["seq"]=int(S()["seq"])+1
	Ledger.post(lender,I18n.t("Group loan principal: %s")%Fmt.money(amount),[{"acct":"group_loan_receivable:"+id,"dr":amount},{"acct":"cash","cr":amount}],{"type":"group_loan","from":lender,"to":borrower})
	Ledger.post(borrower,I18n.t("Group loan principal: %s")%Fmt.money(amount),[{"acct":"cash","dr":amount},{"acct":"group_loan_payable:"+id,"cr":amount}],{"type":"group_loan","from":lender,"to":borrower})
	S()["loans"][id]={"id":id,"from":lender,"to":borrower,"balance":amount,"next":Clock.now()+int(cfg()["monthly_days"])*Clock.DAY,"apr":cfg()["loan_apr"],"interest_owed":0.0}
	return {"ok":true,"id":id}
static func repay(id: String,amount: float) -> Dictionary:
	var loan: Dictionary = S()["loans"].get(id,{})
	if loan.is_empty() or not is_finite(amount) or amount<=0 or amount>float(loan["balance"]) or Ledger.cash(loan["to"])<amount: return {"ok":false,"error":"Keep enough subsidiary cash and choose an outstanding principal amount."}
	Ledger.post(loan["to"],I18n.t("Group loan repayment: %s")%Fmt.money(amount),[{"acct":"group_loan_payable:"+id,"dr":amount},{"acct":"cash","cr":amount}],{"type":"group_loan","from":loan["from"],"to":loan["to"]})
	Ledger.post(loan["from"],I18n.t("Group loan repayment: %s")%Fmt.money(amount),[{"acct":"cash","dr":amount},{"acct":"group_loan_receivable:"+id,"cr":amount}],{"type":"group_loan","from":loan["from"],"to":loan["to"]})
	loan["balance"]=float(loan["balance"])-amount
	return {"ok":true}
static func management(parent: String,child: String,fee: float) -> Dictionary:
	if owner(child)!=parent or not GlobalMarket.live(parent) or not GlobalMarket.live(child) or not is_finite(fee) or fee<=0 or Ledger.cash(child)<fee: return {"ok":false,"error":"Choose a live subsidiary with cash for the management service."}
	Clock.advance(int(float(cfg()["management_hours"])*60))
	Ledger.post(child,I18n.t("Group management service: %s")%Fmt.money(fee),[{"acct":"ic_cost","dr":fee},{"acct":"cash","cr":fee}],{"type":"group_management","from":parent,"to":child})
	Ledger.post(parent,I18n.t("Group management service: %s")%Fmt.money(fee),[{"acct":"cash","dr":fee},{"acct":"ic_revenue","cr":fee}],{"type":"group_management","from":parent,"to":child})
	return {"ok":true}
static func key(ent: String,loc: String,product: String) -> String: return ent+":"+loc+":"+product
static func margin_change(k: String,delta: float) -> void:
	S()["margin"][k]=snappedf(float(S()["margin"].get(k,0))+delta,.01)
	S()["margin_events"].append({"t":Clock.now(),"key":k,"delta":delta})
static func stock_margin(ent: String,loc: String,product: String,qty: int,before: int) -> float:
	var k := key(ent,loc,product)
	var amount := snappedf(float(S()["margin"].get(k,0))*float(qty)/maxi(1,before),.01)
	if not is_zero_approx(amount):margin_change(k,-amount)
	return amount
static func goods(seller: String,buyer: String,product: String,qty: int,price: float,loc := "") -> Dictionary:
	if loc=="":loc=Living.home()
	if seller==buyer or not GlobalMarket.live(seller) or not GlobalMarket.live(buyer) or owner(seller)!=owner(buyer) or owner(seller)=="player" or not is_finite(price) or price<=0 or qty<=0 or Ledger.cash(buyer)<price*qty: return {"ok":false,"error":"Choose sibling subsidiaries, actual stock and an affordable transfer price."}
	var result: Dictionary = CompanyPortfolio.run_in(seller,func():
		if Ecommerce.stock(loc,product)<qty:return {"ok":false,"error":"The selling subsidiary does not have these units."}
		var before := Ecommerce.stock(loc,product)
		var cost := snappedf(Ecommerce.avg_cost(loc,product)*qty,.01)
		var prior_margin := stock_margin(seller,loc,product,qty,before)
		Ecommerce.inv(loc)[product]["qty"]=before-qty
		return {"ok":true,"cost":cost,"original_cost":cost-prior_margin})
	if not result["ok"]:return result
	var amount := snappedf(price*qty,.01)
	Ledger.post(seller,I18n.t("Group goods sale: %s per unit")%Fmt.money(price),[{"acct":"cash","dr":amount},{"acct":"ic_revenue","cr":amount},{"acct":"cogs","dr":result["cost"]},{"acct":"inventory","cr":result["cost"]}],{"type":"group_goods","from":seller,"to":buyer,"product":product})
	Ledger.post(buyer,I18n.t("Group goods purchase: %s per unit")%Fmt.money(price),[{"acct":"inventory","dr":amount},{"acct":"cash","cr":amount}],{"type":"group_goods","from":seller,"to":buyer,"product":product})
	CompanyPortfolio.run_in(buyer,func():Ecommerce._add_stock(loc,product,qty,price,0))
	margin_change(key(buyer,loc,product),amount-float(result["original_cost"]))
	S()["trades"].append({"from":seller,"to":buyer,"t":Clock.now(),"product":product,"qty":qty,"price":price,"cost":result["cost"],"margin":amount-float(result["original_cost"])})
	return {"ok":true,"amount":amount}
static func guarantee(parent: String,loan_id: String) -> Dictionary:
	var loan: Dictionary = Bank.B()["loans"].get(loan_id,{})
	if loan.is_empty() or owner(str(loan["entity"]))!=parent or not GlobalMarket.live(parent) or not loan["status"] in ["active","late","called"]: return {"ok":false,"error":"Choose an outstanding bank loan of this holding company's subsidiary."}
	if S()["guarantees"].has(loan_id):return {"ok":true}
	S()["guarantees"][loan_id]={"parent":parent,"borrower":loan["entity"],"max":loan["balance"],"settled":false}
	return {"ok":true}
static func on_hour() -> void:
	for loan in S()["loans"].values():
		if float(loan["balance"])<=0 or not GlobalMarket.live(str(loan["to"])) or Clock.now()<int(loan["next"]):continue
		var interest := snappedf(float(loan["balance"])*float(loan["apr"])/12,.01)
		var source := {"type":"group_interest","from":loan["from"],"to":loan["to"]}
		if Ledger.cash(loan["to"])>=interest:
			Ledger.post(loan["to"],I18n.t("Group loan interest: %s")%Fmt.money(interest),[{"acct":"exp:interest","dr":interest},{"acct":"cash","cr":interest}],source)
			Ledger.post(loan["from"],I18n.t("Group loan interest: %s")%Fmt.money(interest),[{"acct":"cash","dr":interest},{"acct":"other_income","cr":interest}],source)
		else:
			Ledger.post(loan["to"],I18n.t("Group interest accrued: %s")%Fmt.money(interest),[{"acct":"exp:interest","dr":interest},{"acct":"group_interest_payable:"+str(loan["id"]),"cr":interest}],source)
			Ledger.post(loan["from"],I18n.t("Group interest accrued: %s")%Fmt.money(interest),[{"acct":"group_interest_receivable:"+str(loan["id"]),"dr":interest},{"acct":"other_income","cr":interest}],source)
			loan["interest_owed"]=float(loan["interest_owed"])+interest
		loan["next"]=int(loan["next"])+int(cfg()["monthly_days"])*Clock.DAY
static func margin_at(ids: Array,t: int) -> float:
	var amount := 0.0
	for row in S()["margin_events"]:
		if int(row["t"])<t and str(row["key"]).get_slice(":",0) in ids: amount+=float(row["delta"])
	return amount
static func consolidated(parent: String,t0: int,t1: int) -> Dictionary:
	var ids := members(parent)
	var result := {"members":ids,"revenue":0.0,"profit":0.0,"cash":0.0,"unrealized_margin":margin_at(ids,t1),"investment_elimination":0.0,"loan_elimination":0.0,"assets":0.0,"liabilities":0.0,"interest_elimination":0.0}
	for id in ids:
		var row := MonthClose.compute(id,t0,t1)
		result["revenue"]+=float(row["net_revenue"])
		result["profit"]+=float(row["business_profit"])
		result["cash"]+=float(row["cash_close"])
		result["assets"]+=asset_total(id,t1)
		result["liabilities"]+=liability_total(id,t1)
		for child in ids:result["investment_elimination"]+=maxf(0,Ledger.balance_at(id,"investment_in_subsidiary:"+child,t1))
	for loan in S()["loans"].values():
		if loan["from"] in ids and loan["to"] in ids:result["loan_elimination"]+=maxf(0,Ledger.balance_at(loan["from"],"group_loan_receivable:"+str(loan["id"]),t1))
		if loan["from"] in ids and loan["to"] in ids:result["interest_elimination"]+=maxf(0,Ledger.balance_at(loan["from"],"group_interest_receivable:"+str(loan["id"]),t1))
	result["assets"]-=float(result["investment_elimination"])+float(result["loan_elimination"])+float(result["interest_elimination"])+float(result["unrealized_margin"])
	result["liabilities"]-=float(result["loan_elimination"])+float(result["interest_elimination"])
	result["profit"]-=margin_at(ids,t1)-margin_at(ids,t0)
	return result
static func on_month_end(t0: int,t1: int) -> void:
	for id in CompanyPortfolio.ids():
		if GameState.data["entities"][id]["type"]==cfg()["holding_type"]: S()["reports"].append({"parent":id,"t0":t0,"t1":t1,"report":consolidated(id,t0,t1)})

static func pack_margin(order: Dictionary,loc: String,before: Variant) -> void:
	# `before` is stock before packing: a product -> units dictionary for multi-item orders (or one legacy int).
	var amount := 0.0
	for item in Packing.items(order):
		var units := int(before.get(item["product"],0)) if typeof(before)==TYPE_DICTIONARY else int(before)
		amount+=stock_margin(str(order["entity"]),loc,str(item["product"]),int(item["qty"]),units)
	amount=snappedf(amount,.01)
	if is_zero_approx(amount): return
	order["group_internal_margin"]=amount
	order["group_margin_key"]=key(str(order["entity"]),"pending",str(order["id"]))
	margin_change(order["group_margin_key"],amount)
static func deliver_margin(order: Dictionary) -> void:
	if not order.has("group_internal_margin") or order.get("group_margin_delivered",false):return
	margin_change(order["group_margin_key"],-float(order["group_internal_margin"]))
	order["group_margin_delivered"]=true
static func return_margin(order: Dictionary) -> void:
	if not order.get("group_margin_delivered",false) or order.get("group_margin_returned",false):return
	margin_change(key(str(order["entity"]),str(order["location"]),str(order["product"])),float(order["group_internal_margin"]))
	order["group_margin_returned"]=true
static func consume_stock_margin(ent: String,loc: String,product: String,qty: int,before: int) -> void:
	stock_margin(ent,loc,product,qty,before)
static func cover_guarantees(child: String,unpaid: float) -> float:
	var covered := 0.0
	for id in S()["guarantees"]:
		var g: Dictionary = S()["guarantees"][id]
		if g["borrower"]!=child or g["settled"] or not GlobalMarket.live(str(g["parent"])):continue
		var loan: Dictionary = Bank.B()["loans"].get(id,{})
		var amount := minf(unpaid-covered,minf(float(g["max"]),float(loan.get("balance",0))))
		if amount<=0:continue
		var cash := minf(amount,maxf(0,Ledger.cash(g["parent"])))
		var lines: Array = [{"acct":"exp:other","dr":amount}]
		if cash>0:lines.append({"acct":"cash","cr":cash})
		if cash<amount:lines.append({"acct":"accounts_payable","cr":amount-cash})
		Ledger.post(g["parent"],I18n.t("Subsidiary guarantee settled: %s")%Fmt.money(amount),lines,{"type":"guarantee","subsidiary":child})
		Ledger.post(child,I18n.t("Bank debt covered by holding guarantee: %s")%Fmt.money(amount),[{"acct":"loan_payable","dr":amount},{"acct":"other_income","cr":amount}],{"type":"guarantee","parent":g["parent"]})
		g["settled"]=true
		covered+=amount
		if cash<amount:CompanyPortfolio.run_in(g["parent"],func():Insolvency.begin(g["parent"],"A subsidiary guarantee is unpaid."))
	return covered
static func liquidated_margin(ent: String) -> void:
	for k in S()["margin"].keys():
		if str(k).get_slice(":",0)==ent:margin_change(k,-float(S()["margin"][k]))
static func parent_closure_block(id: String) -> bool:
	return members(id).size()>1

static func debt_accounts(ent: String) -> Array:
	var out: Array=[]
	for acct in GameState.data["ledger"]["balances"].get(ent,{}):
		if str(acct).begins_with("group_loan_payable:") or str(acct).begins_with("group_interest_payable:"):out.append(acct)
	return out
static func settle_group_debt(child: String,acct: String,paid: float,written_off: float) -> void:
	var id := acct.get_slice(":",1)
	var loan: Dictionary = S()["loans"].get(id,{})
	if loan.is_empty():return
	var asset := "group_loan_receivable:"+id if acct.begins_with("group_loan_payable:") else "group_interest_receivable:"+id
	var lines: Array=[]
	if paid>0:lines.append({"acct":"cash","dr":paid})
	if written_off>0:lines.append({"acct":"exp:other","dr":written_off})
	if paid+written_off>0:lines.append({"acct":asset,"cr":paid+written_off})
	if not lines.is_empty():Ledger.post(loan["from"],I18n.t("Subsidiary loan collected or written off: %s")%Fmt.money(paid+written_off),lines,{"type":"group_debt_settlement","from":loan["from"],"to":child})
	if acct.begins_with("group_loan_payable:"):loan["balance"]=maxf(0,float(loan["balance"])-paid-written_off)
	else:loan["interest_owed"]=maxf(0,float(loan["interest_owed"])-paid-written_off)
static func sell_subsidiary(parent: String,child: String,buyer: String) -> Dictionary:
	if owner(child)!=parent or not GlobalMarket.live(parent) or not GlobalMarket.live(child):return {"ok":false,"error":"Choose a live subsidiary owned by this holding company."}
	var selected: Array = CapitalMarket.cfg()["npc_companies"].filter(func(npc):return npc["id"]==buyer)
	if selected.is_empty():return {"ok":false,"error":"Choose an available buyer."}
	var price: float = CompanyPortfolio.run_in(child,func():
		var quote:=Acquisition.quote()
		# Group disposals retain the real acquisition model but never its narrative minimum offer.
		return snappedf(maxf(0,float(quote["enterprise"])+float(quote["cash"])+float(quote["stock"])+float(quote["owed"])-float(quote["debts"]))*float(cfg()["disposal_factor"]),.01))
	if price<=0:return {"ok":false,"error":"Open the subsidiary business account before seeking an acquisition offer."}
	var carrying := maxf(0,Ledger.balance(parent,"investment_in_subsidiary:"+child))
	var shares: Dictionary = CompanyPortfolio.run_in(child,func():return GameState.data.get("cap_table",{}))
	if float(shares.get(parent,0))<1:return {"ok":false,"error":"Other shareholders keep their rights. Sell only a wholly held subsidiary."}
	var lines: Array=[{"acct":"cash","dr":price},{"acct":"investment_in_subsidiary:"+child,"cr":carrying}]
	lines.append({"acct":"other_income","cr":price-carrying} if price>=carrying else {"acct":"exp:other","dr":carrying-price})
	Ledger.post(parent,I18n.t("Subsidiary sale: %s")%Fmt.money(price),lines,{"type":"subsidiary_sale","subsidiary":child})
	S()["parents"].erase(child)
	CompanyPortfolio.run_in(child,func():
		GameState.data["cap_table"]={buyer:1.0}
		GameState.set_flag("company_sold")
		GameState.data["acquisition_receipt"]={"entity":child,"price":price,"buyer":selected[0]["name"],"choice":"accept","t":Clock.now()})
	return {"ok":true,"paid":price}
static func asset_total(id: String,t: int) -> float:
	var total := 0.0
	for acct in GameState.data["ledger"]["balances"].get(id,{}):
		if acct in ["cash","inventory","inventory_in_transit","goods_out","deposits","investments","accounts_receivable","marketplace_balance","escrow_held","frozen_funds","fixed_assets","property_assets","forward_collateral"] or str(acct).begins_with("fx_wallet:") or str(acct).begins_with("fx_receivable:") or str(acct).begins_with("investment_in_subsidiary:") or str(acct).begins_with("group_loan_receivable:") or str(acct).begins_with("group_interest_receivable:"):total+=Ledger.balance_at(id,acct,t)
	return total
static func liability_total(id: String,t: int) -> float:
	var total := 0.0
	for acct in GameState.data["ledger"]["balances"].get(id,{}):
		if acct in ["loan_payable","wages_payable","accounts_payable","deferred_revenue"] or str(acct).begins_with("group_loan_payable:") or str(acct).begins_with("group_interest_payable:"):total-=Ledger.balance_at(id,acct,t)
	return total
