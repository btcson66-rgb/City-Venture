class_name CityFutureModal
extends Modal
func _init() -> void:
	title_text="City future";icon_name="civic";panel_size=Vector2(560,332);pauses_time=true;help_key="city_future"
func action(box: VBoxContainer,label: String,id: String,callback: Callable,primary := false) -> Button:
	var button:=UIK.button(label,callback,"primary" if primary else "")
	button.name=id;button.set_meta("civic_primary",primary);box.add_child(button);return button
func return_to_world() -> void:
	UIRoot.close_all()
func result(value: Dictionary) -> void:
	if not value.get("ok",false):UIRoot.toast(I18n.t(str(value.get("error",""))),"warn","info")
	rebuild()
func build() -> void:
	CityFuture.reconcile()
	var box:=UIK.vbox(4);body.add_child(UIK.scroll(box,Vector2(528,258)))
	if int(CityFuture.S()["current"])==0:
		box.add_child(UIK.wrap(I18n.t("After the business epilogue, the next proposal concerns the whole city. Industry gaps can be filled by paid partners."),8,Art.C_WHITE,510))
		var button:=action(box,I18n.t("Join the city proposal"),"city_start",func():result(CityFuture.start()),true)
		button.disabled=not CityFuture.eligible();return
	if GameState.flag("city_future_complete"):
		var cards: Array=CityFuture.S()["cards"];var index: int=CityFuture.S()["viewed"]
		if index<cards.size():
			box.add_child(UIK.label(I18n.t(str(cards[index]["title"])),10,Art.C_SKY))
			var keys: Dictionary={"quality":"Delivered quality", "approved":"Expo bid", "won":"Harbor tender", "rival_quality":"Rival bid quality", "cost":"Actual contribution (home dollars)", "transition":"Vehicle transition", "support":"Campaign participation", "green_probability":"Green candidate probability", "winner":"Elected mayor", "mayor":"Elected mayor", "expo":"Expo bid", "harbor_quality":"Harbor quality", "event":"Event plan", "expired":"Deadline", "policy":"Workplace policy"}
			for key in cards[index]["result"]:
				if key in ["people","retention_until","departed"]:continue
				var value: Variant=cards[index]["result"][key]
				var text: String=""
				if typeof(value)==TYPE_BOOL:text=("✓ " if value else "✗ ")+I18n.t("Review the recorded result and continue.")
				elif key=="cost":text=Fmt.money(float(value))
				elif key in ["quality","rival_quality","harbor_quality","green_probability"]:text=Fmt.pct(float(value))
				else:text=I18n.t({"green":"Mina Chen", "enterprise":"Daniel Ortiz", "neutral":"Neutral", "charging":"Charging network", "delay":"Phased transition", "both":"Both approaches", "economy":"Economy event", "resilient":"Standby crews", "cancel":"Cancelled event", "culture":"Culture workshop", "volunteer":"Graduate mentoring", "salary":"Weekly pay raises", "options":"Employee options"}.get(str(value),str(value)))
				box.add_child(UIK.kv(str(keys.get(key,key)),text))
			action(box,I18n.t("Next civic legacy card"),"city_next_card",func():CityFuture.S()["viewed"]=index+1;rebuild(),true)
		else:
			box.add_child(UIK.wrap(I18n.t("The city record preserves actual service deliveries and decisions. Your earlier business ending and accounts remain available."),8,Art.C_WHITE,510))
			if LegacyBusiness.S()["ending"]!="":action(box,I18n.t("Continue to the business legacy screen"),"city_legacy",func():close();UIRoot.open_modal(LegacyModal.new()),true)
			action(box,I18n.t("Return to free play"),"city_return",return_to_world,LegacyBusiness.S()["ending"]=="")
		return
	var c:=CityFuture.chapter();var num: int=c["number"]
	var definition:=CityFuture.definition(num)
	box.add_child(UIK.label_tip(I18n.t(str(definition["title"])),"city_future",10,Art.C_SKY))
	box.add_child(UIK.kv("Time remaining",I18n.t("%d days")%maxi(0,int(ceil(float(int(c["deadline"])-Clock.now())/Clock.DAY)))))
	if not GameState.flag("city%d_read"%num):
		box.add_child(UIK.wrap(I18n.t(str(DataDB.dialogue[str(definition["npc"])+"_civic"]["nodes"]["start"][0]["text"])),8,Art.C_WHITE,510))
		action(box,I18n.t("Read the civic briefing."),"city_read",func():result(CityFuture.read_brief()),true);return
	if c["mode"]=="":
		for service in definition["services"]:
			box.add_child(UIK.wrap(I18n.t("%s · %d %s · %s home dollars per unit · %d days")%[I18n.t(service["scope"]),int(service["units"]),I18n.t(service["unit"]),Fmt.money(service["unit_cost"]),int(service["days"])],7,Art.C_WHITE,510))
		box.add_child(UIK.wrap(I18n.t("Supplier delivery can fail. Premium service costs more and reduces failure risk; it does not guarantee delivery."),7,Art.C_MUTED,510))
		action(box,I18n.t("Fund basic suppliers · %s")%Fmt.money(CityFuture.contract_cost(num,false)),"city_fund_basic",func():result(CityFuture.procure("fund")))
		action(box,I18n.t("Fund premium suppliers · %s")%Fmt.money(CityFuture.contract_cost(num,true)),"city_fund_premium",func():result(CityFuture.procure("fund",true)))
		action(box,I18n.t("Join the civic partnership; municipal budget pays suppliers"),"city_partner",func():result(CityFuture.procure("partner")),true);return
	for receipt in c["contracts"]:
		box.add_child(UIK.wrap(("✓ " if receipt["status"]=="delivered" else "✗ ")+I18n.t(receipt["service"]["scope"])+" · "+I18n.t("Delivered; review its quality." if receipt["status"]=="delivered" else "Wait for delivery or review supplier failure." if receipt["status"]=="paid" else "Supplier failed; choose a plan using the remaining deliveries." if receipt["status"]=="failed" else "Payer closed; continue with the recorded loss or civic partnership."),7,Art.C_WHITE,510))
	if not GameState.flag("city%d_plan"%num):action(box,I18n.t("Return to the world and wait for paid delivery"),"city_wait",return_to_world,true);return
	if c["decision"]=="":
		var labels: Dictionary={"balanced":"Submit a balanced expo bid","premium":I18n.t("Buy independent assurance · %s")%Fmt.money(CityFuture.cfg()["assurance_fee"]),"withdraw":"Withdraw the expo bid; prepare a local event","transparent":"Publish the tender and accept independent scrutiny","low_bid":"Submit the lower-cost bid with reduced specifications","favor":"Ask for a secret favor; the bid will be disqualified","charging":I18n.t("Invest in charging infrastructure · %s")%Fmt.money(CityFuture.cfg()["transition_costs"]["charging"]),"delay":I18n.t("Support a transition delay consultation · %s")%Fmt.money(CityFuture.cfg()["transition_costs"]["delay"]),"both":I18n.t("Invest in a smaller network and seek phased rules · %s")%Fmt.money(CityFuture.cfg()["transition_costs"]["both"]),"salary":"Raise current employees' weekly pay by 8%","volunteer":"Mentor graduates for two hours; smaller brand gain and no team retention support","culture":I18n.t("Run the four-hour culture workshop · %s")%Fmt.money(0 if c["mode"]=="partner" else CityFuture.cfg()["workshop_fee"]),"options":"Offer 5% employee options after 30 days of continued employment","green":"Volunteer for Mina Chen; higher tax and energy grants","enterprise":"Volunteer for Daniel Ortiz; lower tax and faster zoning","neutral":"Stay neutral and accept the election result","resilient":I18n.t("Hire standby crews · %s; smaller crisis disruption")%Fmt.money(CityFuture.cfg()["standby_fee"]),"economy":"Run the economy event; accept larger disruption","cancel":"Cancel the city event; no demand peak"}
		for choice in definition["choices"]:
			var why:=CityFuture.choice_block(choice)
			var button:=action(box,I18n.t(labels[choice]),"CityChoice_"+str(choice),func():result(CityFuture.choose(choice)))
			button.disabled=why!=""
			if why!="":box.add_child(UIK.wrap("✗ "+I18n.t(why),7,Art.C_MUTED,510))
		return
	box.add_child(UIK.wrap(I18n.t("Decision recorded. Results use delivered services, rival bids and the election outcome; no sales income is awarded."),7,Art.C_WHITE,510))
	if num==19:
		box.add_child(UIK.kv("Delivered quality",Fmt.pct(float(c["result"]["quality"]))))
		box.add_child(UIK.wrap(("✓ " if c["result"]["approved"] else "✗ ")+I18n.t("Prepare the international expo and continue with Harbor reconstruction." if c["result"]["approved"] else "Prepare a smaller local event and continue with Harbor reconstruction."),8,Art.C_WHITE,510))
	elif num==20:
		box.add_child(UIK.kv("Delivered quality",Fmt.pct(float(c["result"]["quality"]))))
		box.add_child(UIK.kv("Rival bid quality",Fmt.pct(float(c["result"]["rival_quality"]))))
		box.add_child(UIK.wrap(("✓ " if c["result"]["won"] else "✗ ")+I18n.t("Review the tender result and continue with the energy transition."),8,Art.C_WHITE,510))
	elif num==23:
		box.add_child(UIK.kv("Elected mayor","Mina Chen" if c["result"]["winner"]=="green" else "Daniel Ortiz"))
		box.add_child(UIK.kv("Green candidate probability",Fmt.pct(float(c["result"]["green_probability"]))))
	elif num==24:
		box.add_child(UIK.wrap(I18n.t("International expo" if CityFuture.S()["expo_awarded"] else "Local city festival"),8,Art.C_SKY,510))

	if Clock.now()>=int(c["review_at"]):action(box,I18n.t("Review actual deliveries and the civic result."),"city_review",func():result(CityFuture.review()),true)
	else:action(box,I18n.t("Return to the world and wait two days for the result"),"city_wait_result",return_to_world,true)
