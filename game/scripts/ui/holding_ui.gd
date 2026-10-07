class_name HoldingUI
extends RefCounted
static func action(os,c: Control,label: String,id: String,fn: Callable,primary: Array,want := false) -> void:
	GroupUI._btn(os,c,label,id,fn,primary,want)
static func render(os,primary: Array) -> void:
	var c: VBoxContainer=os.content
	var parent := GameState.company_id()
	if parent=="" or GameState.data["entities"][parent]["type"]!="holding":
		c.add_child(UIK.wrap("Register a holding company at City Hall, fund its business account at Nexus Bank, then switch to it here. Each company keeps its own stock, employees and bank book.",8,Art.C_MUTED,450))
		return
	os._section("Holding portfolio")
	c.add_child(UIK.wrap("Share transfers keep book value. Internal sales are eliminated; goods markup becomes group profit only after a real outside sale. A guarantee can put the parent at risk.",8,Art.C_MUTED,450))
	var descendants := HoldingGroups.members(parent)
	for id in descendants:
		c.add_child(UIK.label(("● " if id==parent else "  ↳ ")+GameState.entity_name(id)+" · "+Fmt.money0(Ledger.cash(id)),8,Art.C_SKY))
	var free: Array = CompanyPortfolio.ids().filter(func(id):return id!=parent and HoldingGroups.owner(id)=="player")
	for id in free:
		action(os,c,I18n.t("Place %s into this holding group")%GameState.entity_name(id),"HoldingAdd_"+id,HoldingGroups.hold.bind(parent,id),primary,true)
	var t0 := Clock.month_start()
	var report := HoldingGroups.consolidated(parent,t0,Clock.now()+1)
	os._section("Consolidated month to date")
	for pair in [["External revenue","revenue"],["Group profit","profit"],["Group cash","cash"],["Consolidated assets","assets"],["Consolidated liabilities","liabilities"],["Unsold stock markup removed","unrealized_margin"],["Subsidiary investment removed","investment_elimination"],["Internal loan principal removed","loan_elimination"],["Accrued internal interest removed","interest_elimination"]]:c.add_child(UIK.kv(pair[0],Fmt.money0(report[pair[1]])))
	var closed: Array = HoldingGroups.S()["reports"].filter(func(row):return row["parent"]==parent)
	if not closed.is_empty():
		var last: Dictionary=closed[-1]
		c.add_child(UIK.wrap(I18n.t("Last group close: %s profit, %s outside revenue.")%[Fmt.money0(last["report"]["profit"]),Fmt.money0(last["report"]["revenue"])],8,Art.C_SKY,450))
	var children: Array=descendants.filter(func(id):return id!=parent and HoldingGroups.owner(id)==parent)
	for child in children:
		os._section(GameState.entity_name(child))
		var amount := SpinBox.new()
		amount.name="HoldingAmount_"+child
		amount.min_value=1;amount.max_value=100000;amount.step=.01;amount.value=100
		amount.suffix=I18n.t("AUD")
		c.add_child(amount)
		action(os,c,"Fund subsidiary with group loan","HoldingLoan_"+child,func():return HoldingGroups.loan(parent,child,amount.value),primary)
		action(os,c,"Provide 1 hour of management service","HoldingFee_"+child,func():return HoldingGroups.management(parent,child,amount.value),primary)
		for loan in Bank.loans(child):
			var guaranteed: bool=HoldingGroups.S()["guarantees"].has(loan["id"])
			c.add_child(UIK.wrap(("✓ " if guaranteed else "✗ ")+I18n.t("Parent guarantee: %s outstanding. The parent pays if this subsidiary closes with unpaid debt.")%Fmt.money(float(loan["balance"])),7,Art.C_MUTED,450))
			if not guaranteed:action(os,c,"Guarantee subsidiary bank loan","HoldingGuarantee_"+str(loan["id"]),HoldingGroups.guarantee.bind(parent,str(loan["id"])),primary)
		for buyer in CapitalMarket.cfg()["npc_companies"]:
			action(os,c,I18n.t("Sell subsidiary to %s")%str(buyer["name"]),"HoldingSell_"+child+"_"+str(buyer["id"]),func():
				UIRoot.open_modal(HoldingSaleModal.new("Sell this subsidiary?","The acquisition proceeds go to the holding company. This transfers all held shares to the buyer.",func():
					var result:=HoldingGroups.sell_subsidiary(parent,child,str(buyer["id"]))
					if not result["ok"]:EventBus.notify.emit(result["error"],"bad","company")
					os.rebuild()))
				return {"ok":true},primary)
		action(os,c,"Return subsidiary shares to founder","HoldingRelease_"+child,HoldingGroups.release.bind(parent,child),primary)
	for loan in HoldingGroups.S()["loans"].values():
		if loan["from"]!=parent or float(loan["balance"])<=0:continue
		c.add_child(UIK.wrap(I18n.t("%s owes principal %s · %s APR · next interest %s")%[GameState.entity_name(loan["to"]),Fmt.money(float(loan["balance"])),Fmt.pct(float(loan["apr"])),Clock.fmt_date(int(loan["next"]))],8,Art.C_MUTED,450))
		action(os,c,"Repay group loan principal","HoldingRepay_"+str(loan["id"]),HoldingGroups.repay.bind(str(loan["id"]),float(loan["balance"])),primary)
	if children.size()>=2:
		os._section("Transfer actual stock between subsidiaries")
		var seller := OptionButton.new();seller.name="HoldingSeller"
		var buyer := OptionButton.new();buyer.name="HoldingBuyer"
		for id in children:seller.add_item(GameState.entity_name(id));buyer.add_item(GameState.entity_name(id))
		buyer.select(1)
		c.add_child(seller);c.add_child(buyer)
		var product := OptionButton.new();product.name="HoldingProduct"
		var products: Array=DataDB.products.keys()
		for id in products:product.add_item(I18n.t(DataDB.product(id)["name"]))
		c.add_child(product)
		var qty := SpinBox.new();qty.name="HoldingUnits";qty.min_value=1;qty.max_value=1000;qty.value=1;qty.suffix=I18n.t("units")
		var price := SpinBox.new();price.name="HoldingPrice";price.min_value=.01;price.max_value=10000;price.step=.01;price.value=20;price.suffix=I18n.t("AUD per unit")
		c.add_child(qty);c.add_child(price)
		action(os,c,"Transfer stocked units at this price","HoldingGoods",func():return HoldingGroups.goods(str(children[seller.selected]),str(children[buyer.selected]),str(products[product.selected]),int(qty.value),price.value),primary)
