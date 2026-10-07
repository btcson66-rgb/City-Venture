class_name RealEstateUI
extends Modal
## Matchmaker keeps owner mandates and client needs side by side; property and project decisions follow.
var page := "matches"
var mandate_id := ""
var client_id := ""
var negotiation := "balanced"
var ratio := 1.0
var screen_score := 650
var down := .2
var years := 25
var project_name := "VENTURE TOWER"
var has_primary := false
func _init() -> void:
	project_name=I18n.t("VENTURE TOWER")
	title_text="Matchmaker"
	icon_name="home"
	help_key="real_estate"
	panel_size=Vector2(610,345)
static func open(initial := "matches") -> void:
	var modal := RealEstateUI.new()
	modal.page=initial
	UIRoot.open_modal(modal)
static func render(owner: Node) -> void:
	owner.content.add_child(UIK.label_tip("Real Estate","real_estate",10))
	owner.content.add_child(UIK.wrap("Match owner mandates to clients, finance rentals and build a named property.",8,Art.C_WHITE,460))
	var go := UIK.button("Open Matchmaker",open,"primary")
	go.name="OpenMatchmaker"
	owner.content.add_child(go)
static func board(det: Control,_board: Node) -> void:
	det.add_child(UIK.wrap("Apply for the brokerage licence at City Hall; then lease Harlow & Finch in Residential.",8,Art.C_WHITE,300))
	var go := UIK.button("Open Matchmaker",open,"primary")
	go.name="OpenMatchmaker"
	det.add_child(go)
func switch(next: String) -> void:
	page=next
	reset_scroll=true
	rebuild()
func act(callback: Callable) -> void:
	var result: Dictionary=callback.call()
	if result.has("closed"):
		client_id=""
		if result["closed"]:mandate_id=""
	if not result.get("ok",false):EventBus.notify.emit(result.get("error",""),"bad","home")
	elif result.has("closed") and not result["closed"]:EventBus.notify.emit(I18n.t("No deal this time. Review budget, fit and negotiation."),"info","home")
	rebuild()
func button(parent: Control,label: String,id: String,callback: Callable,primary := false) -> Button:
	var main := primary and not has_primary
	if main:has_primary=true
	var result := UIK.button(label,act.bind(callback),"primary" if main else "button")
	result.name=id
	parent.add_child(result)
	return result
func build() -> void:
	has_primary=false
	var tabs := UIK.hbox(4)
	body.add_child(tabs)
	for tab in [["matches","Client matches"],["properties","Properties"],["development","Development"]]:
		var b := UIK.button(tab[1],switch.bind(tab[0]),"tab_active" if page==tab[0] else "tab")
		b.name="RealtyTab_"+tab[0]
		tabs.add_child(b)
	var content := UIK.vbox(4)
	body.add_child(UIK.scroll(content,Vector2(580,270)))
	if page=="permits":permits(content);return
	if not RealEstate.is_running():
		content.add_child(UIK.label_tip("Real Estate","real_estate",10))
		var conditions := [[GameState.company_id()!="" and GameState.flag("business_account_opened"),"Register a company and open its bank account first."],[RealEstate.licence(),"Apply for the brokerage licence at City Hall; processing takes three days."],[Living.has_lease("realty_office"),"Lease Harlow & Finch in Residential first."]]
		for condition in conditions:content.add_child(UIK.wrap(("✓ " if condition[0] else "✗ ")+I18n.t(condition[1]),8,Art.C_WHITE,550))
		if conditions.all(func(c):return c[0]):button(content,"Open the brokerage","OpenBrokerage",RealEstate.start,true)
		else:
			var destination := "civic_center" if GameState.company_id()=="" else "financial" if not GameState.flag("business_account_opened") else "civic_center" if not RealEstate.licence() else "residential"
			button(content,I18n.t(DataDB.districts[destination]["name"]),"RouteRealtyPrerequisite",func():
				close()
				var map := CityMapModal.new(false)
				map.sel=destination
				UIRoot.open_modal(map)
				return {"ok":true},true)
		return
	content.add_child(UIK.label(I18n.t("Brokerage cash: %s · market index: %.2f")%[Fmt.money(Ledger.cash(RealEstate.entity())),RealEstateMarket.index()],8))
	if page=="matches":matches(content)
	elif page=="properties":properties(content)
	else:development(content)
func permits(content: Control) -> void:
	content.add_child(UIK.label_tip("Property permits","real_estate",10))
	for id in ["brokerage","building"]:
		var entry: Dictionary=Compliance.S().get("permits",{}).get(id,{})
		var granted := Compliance.permit_valid(id)
		var pending: bool = entry.get("entity","")==GameState.company_id() and entry.get("status","")=="pending"
		var title := "Brokerage exam and licence" if id=="brokerage" else "Lot 7 building permit"
		content.add_child(UIK.label(("✓ " if granted else "✗ ")+I18n.t(title),9))
		if granted:continue
		if id=="building" and int(RealEstate.S()["stage"])<2:
			content.add_child(UIK.wrap("✗ Own a rental and apply for the building permit at City Hall first.",8,Art.C_SKY,550))
			button(content,"Manage properties","PrepareRealtyOwnership",func():switch("properties");return {"ok":true},true)
			continue
		if pending:
			content.add_child(UIK.label(I18n.t("Processing: %d days remaining")%maxi(0,ceili((int(entry["due"])-Clock.now())/float(Clock.DAY))),8))
			continue
		var cost := float(RealEstate.cfg()["licence_fee"] if id=="brokerage" else RealEstate.cfg()["permit_fee"])
		var days := int(RealEstate.cfg()["licence_days"] if id=="brokerage" else RealEstate.cfg()["permit_days"])
		button(content,I18n.t("Apply: %s · %d days")%[Fmt.money(cost),days],"ApplyRealtyPermit_"+id,Compliance.apply_permit.bind(id),true)
func choose_match(kind: String,id: String) -> Dictionary:
	if kind=="mandate":mandate_id=id
	else:client_id=id
	return {"ok":true}
func matches(content: Control) -> void:
	content.add_child(UIK.label_tip("Match score","realty_match",9))
	if Staff.employer_registered() and Staff.count("realty_agent")==0:
		button(content,"Recruit a realty agent","RecruitRealtyAgent",func():
			var result := Staff.post_job("realty_agent")
			if result["ok"]:
				close()
				var staff := CompanyOS.new("home_laptop")
				staff.tab="people"
				UIRoot.open_modal(staff)
			return result)
	var columns := UIK.hbox(8)
	content.add_child(columns)
	var owners := UIK.vbox(4)
	var clients := UIK.vbox(4)
	owners.custom_minimum_size=Vector2(272,0)
	clients.custom_minimum_size=Vector2(272,0)
	columns.add_child(owners)
	columns.add_child(clients)
	owners.add_child(UIK.label("Owner mandates",9))
	clients.add_child(UIK.label("Buyers and tenants",9))
	for mandate in RealEstate.S()["mandates"].values():
		if mandate["status"]!="open":continue
		owners.add_child(UIK.wrap(I18n.t("%s · %d rooms · minimum %s · %s")%[I18n.t(DataDB.properties[mandate["property"]]["name"]),int(mandate["rooms"]),Fmt.money(mandate["floor"]),I18n.t("Sale") if mandate["kind"]=="sale" else I18n.t("Rent")],8,Art.C_WHITE,268))
		button(owners,("✓ " if mandate_id==mandate["id"] else "")+I18n.t("Select property"),"Mandate_"+mandate["id"],choose_match.bind("mandate",mandate["id"]),mandate_id=="")
	for client in RealEstate.S()["clients"].values():
		if client["status"]!="open":continue
		clients.add_child(UIK.wrap(I18n.t("%s · budget %s · %d rooms · urgency %d/5 · %s")%[client["name"],Fmt.money(client["budget"]),int(client["rooms"]),int(client["urgency"]),I18n.t("Buyer") if client["kind"]=="sale" else I18n.t("Tenant")],8,Art.C_WHITE,268))
		button(clients,("✓ " if client_id==client["id"] else "")+I18n.t("Select client"),"Client_"+client["id"],choose_match.bind("client",client["id"]),mandate_id!="" and client_id=="")
	var m: Dictionary=RealEstate.S()["mandates"].get(mandate_id,{})
	var c: Dictionary=RealEstate.S()["clients"].get(client_id,{})
	content.add_child(UIK.label(I18n.t("Match score: %.0f%%")%[RealEstate.score(m,c)*100],9))
	var row := UIK.hbox(4)
	content.add_child(row)
	for choice in ["hard","balanced","soft"]:button(row,("✓ " if negotiation==choice else "")+I18n.t({"hard":"Hard negotiation","balanced":"Balanced negotiation","soft":"Soft negotiation"}[choice]),"Negotiate_"+choice,func():negotiation=choice;return {"ok":true})
	if not m.is_empty() and not c.is_empty():button(content,I18n.t("Arrange viewing: %s · %d minutes")%[Fmt.money(RealEstate.cfg()["show_cost"]),int(RealEstate.cfg()["show_minutes"])],"ArrangeViewing",RealEstate.viewing.bind(mandate_id,client_id,negotiation),true)
	else:content.add_child(UIK.wrap("✗ Select an owner mandate and a client, then arrange a viewing.",8,Art.C_SKY,550))
func adjust(key: String,delta: float) -> Dictionary:
	match key:
		"rent":ratio=clampf(snappedf(ratio+delta,.01),float(RealEstate.cfg()["rent_min"]),float(RealEstate.cfg()["rent_max"]))
		"screen":screen_score=clampi(screen_score+int(delta),int(RealEstate.cfg()["screen_min"]),int(RealEstate.cfg()["screen_max"]))
		"down":down=clampf(snappedf(down+delta,.01),float(RealEstate.cfg()["down_min"]),float(RealEstate.cfg()["down_max"]))
		"years":years=clampi(years+int(delta),int(RealEstate.cfg()["mortgage_year_min"]),int(RealEstate.cfg()["mortgage_year_max"]))
	return {"ok":true}
func properties(content: Control) -> void:
	content.add_child(UIK.label_tip("Property mortgage","mortgage",9))
	if RealEstate.S()["project"].get("status","")=="completed":
		button(content,"Rent the completed building as a portfolio","RentRealtyBuilding",func():return RealEstate.list_building(ratio,screen_score),true)
	for entry in [["down",.05,I18n.t("Down payment: %.0f%%")%[down*100]],["years",5,I18n.t("Mortgage term: %d years")%years],["rent",.1,I18n.t("Rent asking ratio: %.0f%%")%[ratio*100]],["screen",50,I18n.t("Minimum tenant credit: %d points")%screen_score]]:
		var row := UIK.hbox(4)
		content.add_child(row)
		button(row,"−","RealtyLess_"+entry[0],adjust.bind(entry[0],-float(entry[1])))
		row.add_child(UIK.label(entry[2],8))
		button(row,"+","RealtyMore_"+entry[0],adjust.bind(entry[0],float(entry[1])))
	for property in RealEstate.S()["properties"].values():
		if property["status"]=="sold":continue
		content.add_child(UIK.wrap(I18n.t("%s · book %s · market %s · rent %s/month")%[I18n.t(property["name"]),Fmt.money(property["book"]),Fmt.money(RealEstateMarket.value(property)),Fmt.money(property["rent"])],8,Art.C_WHITE,550))
		if property["status"]=="occupied":content.add_child(UIK.label(I18n.t("Tenant: %s · credit %d points")%[property["tenant"]["name"],int(property["tenant"]["credit"])],8));continue
		if not property["renovation"].is_empty():content.add_child(UIK.label(I18n.t("Renovation completes in %d days")%ceili((int(property["renovation"]["due"])-Clock.now())/float(Clock.DAY)),8));continue
		button(content,I18n.t("List rental · estimated vacancy %d days")%RealEstate.vacancy_days(ratio,screen_score),"ListRental_"+property["id"],RealEstate.list_rental.bind(property["id"],ratio,screen_score),true)
		var row := UIK.hbox(4)
		content.add_child(row)
		for grade in ["basic","modern","premium"]:button(row,I18n.t({"basic":"Basic renovation","modern":"Modern renovation","premium":"Premium renovation"}[grade])+" · "+Fmt.money0(RealEstate.cfg()["renovations"][grade]["cost"]),"Renovate_"+property["id"]+"_"+grade,RealEstate.renovate.bind(property["id"],grade))
		button(content,"Sell empty unit","SellUnit_"+property["id"],RealEstate.sell.bind(property["id"]))
	for home in RealEstate.listings():
		if RealEstate.S()["properties"].has(home["id"]):continue
		var price := float(home["purchase_price"])*RealEstateMarket.index()
		button(content,I18n.t("Buy %s · price %s · down %s")%[I18n.t(home["name"]),Fmt.money0(price),Fmt.money0(price*down)],"BuyProperty_"+home["id"],RealEstate.buy.bind(home["id"],down,years),true)
func development(content: Control) -> void:
	content.add_child(UIK.label_tip("Ruiz development","development",9))
	var project: Dictionary=RealEstate.S()["project"]
	if not project.is_empty():
		content.add_child(UIK.wrap(I18n.t("%s · budget %s · paid %s · completion in %d days")%[project["name"],Fmt.money0(project["budget"]),Fmt.money0(project["paid"]),maxi(0,ceili((int(project["due"])-Clock.now())/float(Clock.DAY)))],9,Art.C_WHITE,550))
		var status := str(project["status"])
		content.add_child(UIK.label(I18n.t({"building":"Construction in progress","paused":"✗ Fund the next construction milestone.","completed":"✓ Building complete. Sell or rent units in Properties."}.get(status,"Project closed")),9))
		var next_step: Callable=switch.bind("properties")
		if status=="paused":
			next_step=func():
				close()
				var finance := CompanyOS.new("home_laptop")
				finance.tab="finance"
				UIRoot.open_modal(finance)
		var go := UIK.button("Finance" if status=="paused" else "Manage properties",next_step,"primary")
		go.name="ManageRealtyProperties"
		content.add_child(go)
		return
	if int(RealEstate.S()["stage"])<2 or not Compliance.permit_valid("building"):content.add_child(UIK.wrap("✗ Own a rental and apply for the building permit at City Hall first.",9,Art.C_SKY,550));return
	content.add_child(UIK.label("Name the completed building",8))
	var name_input := LineEdit.new()
	name_input.name="ProjectName"
	name_input.max_length=32
	name_input.text=project_name
	name_input.text_changed.connect(func(value):project_name=value)
	content.add_child(name_input)
	for scale in ["small","medium","large"]:
		var spec: Dictionary=RealEstate.cfg()["development"][scale]
		button(content,I18n.t("%d units · %d days · budget %s")%[int(spec["units"]),int(spec["days"]),Fmt.money0(spec["cost"])],"Develop_"+scale,func():return RealEstate.develop(scale,project_name),true)
