class_name MediaUI
extends Modal
## Client briefs, normalized channel mixer, ongoing metrics and settled reports in one saved workflow.
var selected := ""
var page := "briefs"
var has_primary := false
var internal_target := "cafe"
var internal_budget := 5000.0
func _init() -> void:
	calm_profile = "media"
	title_text="Campaign Mixer"
	help_key="media"
	icon_name="star"
	panel_size=Vector2(610,345)
static func open() -> void:UIRoot.open_modal(MediaUI.new())
static func render(owner: Node) -> void:
	owner.content.add_child(UIK.label_tip("Media / Advertising","media",10))
	owner.content.add_child(UIK.wrap("Pitch client briefs, mix media channels and measure results before invoicing.",8,Art.C_WHITE,460))
	var go := UIK.button("Open Campaign Mixer",open,"primary")
	go.name="OpenCampaignMixer"
	owner.content.add_child(go)
static func board(det: Control,_board: Node) -> void:
	det.add_child(UIK.wrap("Lease The Loft in University before opening the agency.",8,Art.C_WHITE,300))
	var go := UIK.button("Open Campaign Mixer",open,"primary")
	go.name="OpenCampaignMixer"
	det.add_child(go)
func act(callback: Callable) -> void:
	var result: Dictionary=callback.call()
	if not result.get("ok",false):EventBus.notify.emit(result.get("error",""),"bad","star")
	elif result.has("won") and not result["won"]:EventBus.notify.emit(I18n.t("The pitch lost. Review creative fit before the next proposal."),"info","star")
	rebuild()
func button(parent: Control,label: String,id: String,callback: Callable,primary := false) -> void:
	var main := primary and not has_primary
	if main:has_primary=true
	var action := UIK.button(label,act.bind(callback),"primary" if main else "button")
	action.name=id
	parent.add_child(action)
func switch(next: String) -> void:page=next;reset_scroll=true;rebuild()
func pick(id: String) -> Dictionary:selected=id;return {"ok":true}
func build() -> void:
	has_primary=false
	var nav := UIK.hbox(4)
	body.add_child(nav)
	for tab in [["briefs","Client briefs"],["mixer","Media mix"],["reports","Campaign reports"],["group","Group campaigns"],["radio","Owned media"]]:
		var choice := UIK.button(tab[1],switch.bind(tab[0]),"tab_active" if page==tab[0] else "tab")
		choice.name="MediaTab_"+tab[0]
		nav.add_child(choice)
	var content := UIK.vbox(4)
	body.add_child(UIK.scroll(content,Vector2(580,270)))
	if not Media.is_running():
		var conditions := [[GameState.company_id()!="" and GameState.flag("business_account_opened"),"Register a company and open its bank account first."],[Living.has_lease("loft_office"),"Lease The Loft in University before opening the agency."]]
		for condition in conditions:content.add_child(UIK.wrap(("✓ " if condition[0] else "✗ ")+I18n.t(condition[1]),8,Art.C_WHITE,550))
		if conditions.all(func(c):return c[0]):button(content,"Open the campaign studio","OpenAgency",Media.start,true)
		else:
			var destination := "civic_center" if GameState.company_id()=="" else "financial" if not GameState.flag("business_account_opened") else "university"
			button(content,I18n.t(DataDB.districts[destination]["name"]),"RouteAgencyPrerequisite",func():
				close()
				var map := CityMapModal.new(false)
				map.sel=destination
				UIRoot.open_modal(map)
				return {"ok":true},true)
		return
	content.add_child(UIK.label(I18n.t("Reputation: %d%% · campaign slots: %d/%d · cash: %s")%[roundi(float(Media.S()["reputation"])*100),Media.occupied().size(),Media.capacity(),Fmt.money(Ledger.cash(Media.entity()))],8))
	match page:
		"briefs":briefs(content)
		"mixer":mixer(content)
		"reports":reports(content)
		"group":group(content)
		"radio":radio(content)
func briefs(content: Control) -> void:
	content.add_child(UIK.label_tip("Client brief","media_kpi",9))
	for brief in Media.S()["briefs"].values():
		if brief["status"]!="open":continue
		content.add_child(UIK.wrap(I18n.t("%s · budget %s · %s · audience %s · %d days remaining")%[brief["client"],Fmt.money0(brief["budget"]),I18n.t("Relevant reach" if brief["goal"]=="awareness" else "Conversions"),I18n.t(Media.cfg()["audiences"][int(brief["audience"])]),maxi(0,ceili((int(brief["deadline"])-Clock.now())/float(Clock.DAY)))],8,Art.C_WHITE,550))
		if not brief.get("competitors", []).is_empty():
			content.add_child(UIK.wrap(Rivals.competing_text(brief["competitors"]), 8, Art.C_SKY, 550))
		var preferences: Array=brief["preferences"]
		content.add_child(UIK.wrap(I18n.t("Client preferences: %s / %s / %s")%[I18n.t(Media.cfg()["creative_cards"]["slogan"][int(preferences[0])]),I18n.t(Media.cfg()["creative_cards"]["visual"][int(preferences[1])]),I18n.t(Media.cfg()["creative_cards"]["tone"][int(preferences[2])])],8,Art.C_SKY,550))
		content.add_child(UIK.label(I18n.t("Creative quality %.0f%% · service fee %s · media rebate %.0f%% · Net 30")%[float(brief["quality"])*100,Fmt.money0(Media.cfg()["service_fee"]),float(Media.cfg()["media_rebate"])*100],8))
		content.add_child(UIK.tip("net_terms"))
		var row := UIK.hbox(4)
		content.add_child(row)
		var creative := UIK.button("Build Creative Pitch",play_creative.bind(brief["id"]),"primary" if float(brief["quality"])==0 and not has_primary else "button")
		creative.name="CreativePitch_"+brief["id"]
		row.add_child(creative)
		if float(brief["quality"])==0:has_primary=true
		button(row,I18n.t("Propose · %s · %d minutes")%[Fmt.money0(Media.cfg()["pitch_cost"]),int(Media.cfg()["pitch_minutes"])],"Propose_"+brief["id"],Media.propose.bind(brief["id"]),float(brief["quality"])>0)
	for role in ["media_designer","media_buyer","media_intern"]:
		button(content,I18n.t("Recruit %s")%I18n.t(Staff.role_def(role)["name"]),"Recruit_"+role,recruit.bind(role))
func recruit(role: String) -> Dictionary:
	if not Staff.employer_registered():
		close()
		var map := CityMapModal.new(false)
		map.sel="civic_center"
		UIRoot.open_modal(map)
		return {"ok":true}
	var result := Staff.post_job(role)
	if result.get("ok",false):
		close()
		var os := CompanyOS.new("home_laptop")
		os.tab="people"
		UIRoot.open_modal(os)
	return result
func play_creative(id: String) -> void:
	var brief: Dictionary=Media.S()["briefs"].get(id,{})
	if brief.is_empty() or brief["status"]!="open":return
	if Ledger.cash(Media.entity())<float(Media.cfg()["creative_cost"]):
		EventBus.notify.emit(I18n.t("Save the creative production cost first."),"bad","star")
		return
	MiniGames.play(CreativePitch.new(brief),func(result):
		var production := Media.prepare(id,float(result.get("score",0)))
		if not production.get("ok",false):EventBus.notify.emit(production.get("error",""),"bad","star")
		if is_instance_valid(self):rebuild())
func shift(id: String,cid: String,delta: float) -> Dictionary:
	var campaign: Dictionary=Media.S()["campaigns"][id]
	var mix: Dictionary=campaign["mix"].duplicate()
	var opposite := ""
	var best := -1.0
	for channel in mix:
		if channel==cid:continue
		var available := float(mix[channel]) if delta>0 else 100-float(mix[channel])
		if available>best:best=available;opposite=channel
	var amount := minf(absf(delta),minf(best,100-float(mix[cid]) if delta>0 else float(mix[cid])))
	mix[cid]=float(mix[cid])+amount*(1 if delta>0 else -1)
	mix[opposite]=float(mix[opposite])-amount*(1 if delta>0 else -1)
	return Media.adjust(id,mix)
func mixer(content: Control) -> void:
	content.add_child(UIK.label_tip("Media mix","media_mix",9))
	for campaign in Media.S()["campaigns"].values():
		if campaign["status"] not in ["running","paused"]:continue
		button(content,campaign["client"],"SelectCampaign_"+campaign["id"],pick.bind(campaign["id"]),selected=="")
	var campaign: Dictionary=Media.S()["campaigns"].get(selected,{})
	if campaign.get("status","") not in ["running","paused"]:campaign={};selected=""
	if campaign.is_empty():content.add_child(UIK.wrap("✗ Select a running campaign to adjust media shares.",8,Art.C_SKY,550));return
	content.add_child(UIK.wrap(I18n.t("Spend %s/%s · impressions %d · clicks %d · conversions %d")%[Fmt.money0(campaign["spent"]),Fmt.money0(campaign["budget"]),roundi(campaign["impressions"]),roundi(campaign["clicks"]),roundi(campaign["conversions"])],8,Art.C_WHITE,550))
	if campaign["status"]=="paused":button(content,"Resume after funding the media purchase","ResumeCampaign_"+selected,Media.resume.bind(selected),true)
	for cid in Media.cfg()["channels"]:
		var channel: Dictionary=Media.cfg()["channels"][cid]
		var row := UIK.hbox(4)
		content.add_child(row)
		row.add_child(UIK.label(I18n.t("%s · %.0f%% · CPM %s · audience fit %.0f%%")%[I18n.t(channel["name"]),float(campaign["mix"][cid]),Fmt.money(float(channel["cpm"])*Media.price_mult()),float(channel["audience"][int(campaign["audience"])])*100],8))
		button(row,"−","MixLess_"+cid,shift.bind(selected,cid,-10))
		button(row,"+","MixMore_"+cid,shift.bind(selected,cid,10))
	content.add_child(UIK.wrap("Shares total 100%. Changing the mix affects the next buying cycle, not past reports.",8,Art.C_MUTED,550))
	var next := UIK.button("Campaign reports",switch.bind("reports"),"primary")
	next.name="MixerNextReport"
	content.add_child(next)
func reports(content: Control) -> void:
	content.add_child(UIK.label_tip("Campaign reports","media_kpi",9))
	for campaign in Media.S()["campaigns"].values():
		content.add_child(UIK.wrap(I18n.t("%s · %d campaign days · spend %s · impressions %d · relevant reach %d · clicks %d · conversions %d")%[campaign["client"],int(campaign["days"]),Fmt.money0(campaign["spent"]),roundi(campaign["impressions"]),roundi(campaign["reach"]),roundi(campaign["clicks"]),roundi(campaign["conversions"])],8,Art.C_WHITE,550))
		if campaign["status"] in ["completed","cancelled"]:
			content.add_child(UIK.label(("✓ " if campaign.get("kpi_met",false) else "✗ ")+I18n.t("KPI settlement · bonus %s · review the next client brief.")%Fmt.money0(campaign["bonus"]),8))
			if campaign["target"]=="":content.add_child(UIK.label(I18n.t("Invoice: %s · %s")%[Fmt.money(Jobs.get_job(campaign["id"])["price"]),I18n.t(str(CompanyOS.STATUS_TEXT.get(Jobs.get_job(campaign["id"])["status"],str(Jobs.get_job(campaign["id"])["status"]).capitalize())))],8))
		else:content.add_child(UIK.label(I18n.t("Campaign in progress; adjust its media mix."),8))
	var next := UIK.button("Client briefs",switch.bind("briefs"),"primary")
	next.name="ReviewNextBrief"
	content.add_child(next)
func group(content: Control) -> void:
	content.add_child(UIK.wrap("Internal campaigns charge the target segment at media cost. No agency service fee or supplier rebate; measured conversions boost real business demand.",8,Art.C_SKY,550))
	for target in ["ecommerce","cafe","hotel"]:
		if target=="hotel" and not GameState.flag("hotel_active"):continue
		var label: String={"ecommerce":"Ecommerce","cafe":"Cafe","hotel":"Hotel"}[target]
		button(content,I18n.t("Run %s internal campaign · %s")%[I18n.t(label),Fmt.money0(internal_budget)],"GroupCampaign_"+target,Media.group_campaign.bind(target,internal_budget),target=="cafe" and Cafe.leased())
	for change in [-5000,5000]:
		button(content,I18n.t("Media budget %s")%Fmt.money0(change,true),"GroupBudget_"+str(change),func():internal_budget=clampf(internal_budget+change,float(Media.cfg()["budget_min"]),float(Media.cfg()["budget_max"]));return {"ok":true})
func radio(content: Control) -> void:
	content.add_child(UIK.label_tip("Owned media","owned_media",9))
	if Media.S()["radio"].is_empty():
		if Media.stage()<2:
			content.add_child(UIK.wrap("✗ Complete two campaigns and hire a designer and media buyer before buying Campus Radio.",8,Art.C_SKY,550))
			if int(Media.S()["completed"])<int(Media.cfg()["agency_completed"]):
				var next := UIK.button("Client briefs",switch.bind("briefs"),"primary")
				next.name="RadioNextBrief"
				content.add_child(next)
			else:
				var role := "media_designer" if Staff.count("media_designer")==0 else "media_buyer"
				button(content,I18n.t("Recruit %s")%I18n.t(Staff.role_def(role)["name"]),"RadioRecruit",recruit.bind(role),true)
			return
		button(content,I18n.t("Acquire Campus Radio · %s")%Fmt.money0(Media.cfg()["agency_asset_price"]),"BuyCampusRadio",Media.buy_radio,true)
		return
	var radio: Dictionary=Media.S()["radio"]
	var asset: Dictionary=Assets.S()["items"].get(radio["asset"],{})
	if asset.get("status","")!="working" or asset.get("maintenance_due",false):
		button(content,I18n.t("Maintain Campus Radio · %s")%Fmt.money0(Media.cfg()["asset_maintenance_cost"]),"MaintainCampusRadio",Assets.maintain.bind(radio["asset"]),true)
	content.add_child(UIK.label(I18n.t("Audience %d listeners · %d impressions available today")%[floori(radio["audience"]),floori(radio["inventory"])],9))
	for offer in radio["offers"].values():
		if Jobs.get_job(offer["id"])["status"]!="offered":continue
		button(content,I18n.t("Sell %d impressions · %s")%[int(offer["impressions"]),Fmt.money0(Jobs.get_job(offer["id"])["price"])],"SellRadio_"+offer["id"],Media.sell_slot.bind(offer["id"]),true)
