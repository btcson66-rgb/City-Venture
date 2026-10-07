class_name CapitalMarketModal
extends Modal
var selected_offer := ""
var underwriter := ""
func _init() -> void:
	title_text="Ownership and public markets"
	icon_name="bank"
	help_key="capital_market"
	panel_size=Vector2(510,348)
	pauses_time=true
func result(value: Dictionary) -> void:
	if not value.get("ok",false): UIRoot.toast(I18n.t(str(value.get("error",""))),"warn","info")
	rebuild()
func action(box: Control,text: String,id: String,fn: Callable,primary := false) -> Button:
	var b := UIK.button(text,fn,"primary" if primary else "")
	b.name=id
	box.add_child(b)
	return b
func build() -> void:
	CapitalMarket.begin()
	var box := UIK.vbox(4)
	body.add_child(UIK.scroll(box,Vector2(476,232)))
	var current_ipo: Dictionary = CapitalMarket.S()["ipo"]
	if CapitalMarket.live() and current_ipo.get("stage","")=="roadshow":
		roadshow(box,current_ipo)
		return
	box.add_child(UIK.label_tip("Ownership routes", "capital_routes",10,Art.C_SKY))
	box.add_child(UIK.wrap("NPC companies are used for this consolidation scenario. Their revenue and growth are scenario inputs, never income on your books. Acquired firms are recorded investments; their staffing remains separate from your own team.",7,Art.C_MUTED,458))
	if not CapitalMarket.live():
		box.add_child(UIK.wrap("✗ This company is closed or replaced. Continue with your current life.",8,Art.C_MUTED,458))
		action(body,"Continue operating","CapitalContinue",close,true)
		return
	var s := CapitalMarket.S()
	box.add_child(UIK.wrap(CapitalMarket.route_text(),8,Art.C_WHITE,458))
	var ipo: Dictionary = s["ipo"]
	if s["route"]=="public":
		box.add_child(UIK.kv("Share price (home dollars per share)",Fmt.money(float(ipo["price"]))))
		box.add_child(UIK.kv("Next quarterly report",Clock.fmt_short(int(ipo["next_quarter"]))))
		box.add_child(UIK.kv("Quarter revenue expectation (home dollars)",Fmt.money(float(ipo["expectation"]))))
		box.add_child(UIK.kv("Public reputation (percent)","%.0f%%"%float(s["reputation"])))
		box.add_child(UIK.wrap("Major acquisitions use a majority board vote. Outside shareholders support commitments within half of available cash; other large commitments depend on the founder's remaining votes.",7,Art.C_WHITE,458))
		for report in s["quarter_reports"]:
			box.add_child(UIK.wrap(I18n.t("Quarter: actual %s home dollars, expected %s home dollars. Share price %s home dollars per share.")%[Fmt.money(float(report["actual"])),Fmt.money(float(report["expected"])),Fmt.money(float(report["price"]))],7,Art.C_WHITE,458))
	elif s["route"] != "acquired":
		box.add_child(UIK.label("Acquisition proposals",9,Art.C_SKY))
		for offer in s["offers"]:
			action(box,I18n.t("%s offers %s home dollars")%[offer["name"],Fmt.money0(float(offer["price"]))],"SelectOffer_"+str(offer["id"]),func():selected_offer=offer["id"];rebuild())
		if selected_offer != "":
			var offer: Dictionary = s["offers"].filter(func(o):return o["id"]==selected_offer)[0]
			box.add_child(UIK.kv("Founder payout (home dollars)",Fmt.money(Fundraising.founder_proceeds(CapitalMarket.final_offer_price(offer)))))
			var why := CapitalMarket.offer_block(selected_offer)
			box.add_child(UIK.wrap("The final sale price cannot exceed current company value after withdrawals or losses.",7,Art.C_MUTED,458))
			box.add_child(UIK.wrap(I18n.t("Due diligence until %s; expires %s.")%[Clock.fmt_short(int(offer["ready"])),Clock.fmt_short(int(offer["expires"]))],7,Art.C_WHITE,458))
			box.add_child(UIK.wrap("✓ " + I18n.t("Review the founder payout and confirm the sale.") if why=="" else "✗ "+I18n.t(why),7,Art.C_WHITE,458))
			action(box,"Decline this proposal","DeclineOffer",func():offer["status"]="declined";selected_offer="";rebuild())
			if why=="":
				action(body,"Sell founder shares to the selected buyer","ConfirmCapitalSale",func():result(CapitalMarket.sell(selected_offer)),true)
				action(body,"Keep operating","CapitalContinue",close)
				return
		box.add_child(UIK.label_tip("Public listing", "ipo_process",9,Art.C_SKY))
		var stage := str(ipo.get("stage",""))
		if stage=="audit":
			box.add_child(UIK.wrap(I18n.t("Paid audit completes at %s. A failed audit keeps its fee; you can retry after fixing the operating or compliance record.")%Clock.fmt_short(int(ipo["ready"])),7,Art.C_WHITE,458))
			if Clock.now()>=int(ipo["ready"]):
				action(body,"Read the completed audit","ReadListingAudit",func():result(CapitalMarket.progress_audit()),true)
				action(body,"Keep operating","CapitalContinue",close)
				return
		elif stage=="priced":
			box.add_child(UIK.kv("Proposed share price (home dollars per share)",Fmt.money(float(ipo["price"]))))
			box.add_child(UIK.wrap("Listing issues 20% new public equity, dilutes every existing owner proportionally and deducts the underwriting commission. This is capital, not sales revenue.",7,Art.C_WHITE,458))
			action(body,"Issue shares and list the company","ConfirmListing",func():result(CapitalMarket.list_company()),true)
			action(body,"Keep operating","CapitalContinue",close)
			return
		else:
			if stage=="failed": box.add_child(UIK.wrap("✗ "+I18n.t(str(ipo.get("failure","Audit conditions failed. Repair the record before retrying."))),7,Art.C_MUTED,458))
			var why := CapitalMarket.ipo_block()
			box.add_child(UIK.kv("Annual revenue threshold (home dollars)",Fmt.money0(float(CapitalMarket.cfg()["annual_revenue_min"]))))
			box.add_child(UIK.kv("Consecutive profitable operating years (years)",str(int(CapitalMarket.cfg()["profitable_years"]))))
			box.add_child(UIK.wrap("✓ "+I18n.t("Select an underwriter and start the paid audit.") if why=="" else "✗ "+I18n.t(why),7,Art.C_MUTED,458))
			for u in CapitalMarket.cfg()["underwriters"]:
				action(box,I18n.t("%s: audit %s home dollars, commission %s")%[I18n.t(str(u["name"])),Fmt.money(float(u["fee"])),Fmt.pct(float(u["commission"]))],"Underwriter_"+str(u["id"]),func():underwriter=u["id"];rebuild())
			if underwriter!="" and why=="":
				action(body,"Pay for the selected listing audit","StartListingAudit",func():result(CapitalMarket.start_audit(underwriter)),true)
				action(body,"Keep operating","CapitalContinue",close)
				return
		action(box,"Keep the company private","ChoosePrivateRoute",func():result(CapitalMarket.private_route()))
	box.add_child(UIK.label_tip("Acquire and integrate", "acquisition_integration",9,Art.C_SKY))
	for id in s["targets"]:
		var target: Dictionary = s["targets"][id]
		if target.has("owner"): continue
		var price := CapitalMarket.valuation(float(target["revenue"]),float(target["revenue"])/(1+float(target["growth"])))
		box.add_child(UIK.kv(target["name"]+I18n.t(" (home dollars)"),Fmt.money0(price)))
		box.add_child(UIK.wrap(I18n.t("Integration fee %s home dollars; %d days, estimated staff loss %s. Retain purchase cash or arrange a normal bank loan.")%[Fmt.money(price*float(CapitalMarket.cfg()["integration_fee_share"])),int(CapitalMarket.cfg()["integration_days"]),Fmt.pct(float(CapitalMarket.cfg()["integration_loss_share"]))],7,Art.C_WHITE,458))
		action(box,"Acquire this company","AcquireNPC_"+str(id),func():result(CapitalMarket.acquire(id)))
	for task in s["integrations"]:
		box.add_child(UIK.wrap(I18n.t("Integration staffing: %d people before, %d people after; systems fee %s home dollars.")%[int(task["staff_before"]),int(task["staff_after"]),Fmt.money(float(task["fee"]))],7,Art.C_WHITE,458))
	action(body,"Continue operating","CapitalContinue",close,true)

func roadshow(box: Control,ipo: Dictionary) -> void:
	var index := int(ipo["answers"].size())
	var q: Dictionary = CapitalMarket.cfg()["questions"][index]
	box.add_child(UIK.label_tip("Investor roadshow","ipo_process",10,Art.C_SKY))
	box.add_child(UIK.kv("Investor question (round)","%d / %d"%[index+1,CapitalMarket.cfg()["questions"].size()]))
	box.add_child(UIK.kv("Supported answers (answers)",str(int(ipo["score"]))))
	box.add_child(UIK.wrap(q["text"],9,Art.C_SKY,458))
	box.add_child(UIK.wrap("Answers change pricing confidence. Unsupported promises may cause investors to decline; no answer guarantees profitable future operations.",7,Art.C_MUTED,458))
	action(box,q["good"],"RoadshowTransparent",func():result(CapitalMarket.answer(index,true)))
	box.add_child(UIK.wrap(_effect_text(q["good_effect"]),7,Art.C_MUTED,458))
	action(box,q["risk"],"RoadshowPromise",func():result(CapitalMarket.answer(index,false)))
	box.add_child(UIK.wrap(_effect_text(q["risk_effect"]),7,Art.C_MUTED,458))
	action(body,"Withdraw listing and stay private","WithdrawIPO",func():result(CapitalMarket.private_route()))
	action(body,"Keep operating","CapitalContinue",close)

## Both answers show their full price, time and risk terms; neither is marked as the better one.
func _effect_text(effect: Dictionary) -> String:
	var text := I18n.t("Price effect %+d%%, listing delay %d days.")%[roundi((float(effect["price_factor"])-1.0)*100),int(effect["delay_days"])]
	if float(effect["caught_chance"])>0:text+=" "+I18n.t("%d%% chance investors reject the listing.")%roundi(float(effect["caught_chance"])*100)
	return text
