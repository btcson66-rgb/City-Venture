class_name PersonalAssetsModal
extends Modal
var tab: String="homes"
var primary: bool=false
func _init() -> void:
	title_text="Home and personal car"
	help_key="personal_assets"
	icon_name="home"
	panel_size=Vector2(470,350)
	pauses_time=true
func act(box: Control,label: String,id: String,call: Callable,recommend := false) -> void:
	var highlight: bool=recommend and not primary
	primary=primary or highlight
	var b:=UIK.button(label,func():
		var result: Dictionary=call.call()
		if not result.get("ok",false):UIRoot.toast(I18n.t(result.get("error","")),"warn","home")
		if result.get("close",false):close()
		else:rebuild(),"primary" if highlight else "")
	b.name=id;box.add_child(b)
func build() -> void:
	primary=false
	var nav:=UIK.hbox(3);body.add_child(nav)
	for id in ["homes","car","visits"]:
		var b:=UIK.button({"homes":"Housing ladder","car":"Personal car and commute","visits":"Furniture and invitations"}[id],func():tab=id;rebuild())
		b.name="PersonalTab_"+id;nav.add_child(b)
	var box:=UIK.vbox(4);body.add_child(UIK.scroll(box,Vector2(436,255)))
	box.add_child(UIK.label_tip("Personal assets have real costs","personal_asset_costs",10,Art.C_SKY))
	if tab=="homes":
		var homes: Array=DataDB.properties.values().filter(func(p):return p.get("owner_purchase",false))
		homes.sort_custom(func(a,b):return int(a["tier"])<int(b["tier"]))
		for p in homes:
			var id: String=p["id"]
			if not p.get("owner_purchase",false):continue
			box.add_child(UIK.label(I18n.t(p["name"]),9,Art.C_SKY))
			box.add_child(UIK.wrap(I18n.t("Purchase %s · management %s per month · tax and maintenance additional · storage %d units · %d guests per day")%[Fmt.money(PersonalAssets.price(id)),Fmt.money(float(p["management_month"])),int(p["inventory_units"]),int(p["guests"])],8,Art.C_WHITE,420))
			if not PersonalAssets.owned(id):
				var available: bool=int(p["tier"])==1 or PersonalAssets.S()["homes"].values().any(func(h):return int(h["tier"])==int(p["tier"])-1)
				available=available and Ledger.cash("player")>=PersonalAssets.price(id)*(.2+float(PersonalAssets.cfg()["purchase_fee"])) and PersonalAssets.personal_credit()>=int(RealEstate.cfg()["mortgage_credit"])
				box.add_child(UIK.wrap(("✓ " if available else "✗ ")+I18n.t("Choose mortgage terms to buy." if available else "Save a personal down payment and fee; buy the previous tier before upgrading."),8,Art.C_MUTED,420))
				act(box,"20% down, 20-year mortgage","PersonalBuy20_"+id,PersonalAssets.buy_home.bind(id,.2,20),available)
				act(box,"30% down, 30-year mortgage","PersonalBuy30_"+id,PersonalAssets.buy_home.bind(id,.3,30))
			else:
				var h: Dictionary=PersonalAssets.S()["homes"][id]
				box.add_child(UIK.wrap(I18n.t("Mortgage balance %s · monthly payment at today's rate %s · unpaid interest %s")%[Fmt.money(float(h["balance"])),Fmt.money(Bank.monthly_payment(float(h["balance"]),maxi(1,int(h["months"])-int(h["paid_n"])),PersonalAssets.market_rate()+float(RealEstate.cfg()["mortgage_margin"]))),Fmt.money(float(h["arrears"]))],8,Art.C_WHITE,420))
				if Living.home()==id:box.add_child(UIK.wrap("✓ "+I18n.t("You live here. Move to another home before renting or selling."),8,Art.C_MUTED,420))
				else:
					box.add_child(UIK.wrap("✓ "+I18n.t("Choose to live here, earn uncertain tenant rent or sell after fees."),8,Art.C_MUTED,420))
					if h["status"] in ["empty","occupied"]:
						act(box,"Move into owned home","PersonalMove_"+id,PersonalAssets.move_home.bind(id),true)
						act(box,"List rental at market rent","PersonalRent_"+id,PersonalAssets.rent_home.bind(id,1.0))
						act(box,"Sell home after fees","PersonalSell_"+id,PersonalAssets.sell_home.bind(id))
					else:act(box,"End rental with 30 days' notice","PersonalEndRent_"+id,PersonalAssets.end_tenancy.bind(id),true)
					act(box,"Collect outstanding tenant invoices","PersonalCollect_"+id,PersonalAssets.collect_rent.bind(id))
	elif tab=="car":
		var c: Dictionary=PersonalAssets.S()["car"]
		if c.is_empty():
			for model in PersonalAssets.cfg()["cars"]:
				act(box,I18n.t("Buy %s: %s")%[I18n.t(model["name"]),Fmt.money(float(model["price"]))],"PersonalCar_"+model["id"],PersonalAssets.buy_car.bind(model["id"]),true)
		else:
			box.add_child(UIK.wrap(I18n.t("%s parked in %s · insurance %s per month · no business performance bonus")%[I18n.t(c["name"]),I18n.t(DataDB.districts[c["location"]]["name"]),Fmt.money(float(PersonalAssets.cfg()["insurance_month"]))],8,Art.C_WHITE,420))
			if c["electric"]:act(box,"Charge at a Helio station","PersonalCharge",PersonalAssets.charge,true)
			for id in DataDB.districts:
				if id==c["location"] or not BuildingInfo.district_open(id):continue
				var q:=PersonalAssets.trip(c["location"],id,int(Clock.date()["hour"]))
				act(box,I18n.t("Drive to %s: %d min · metro %d min · parking %s · fuel %s")%[I18n.t(DataDB.districts[id]["name"]),int(q["minutes"]),PersonalAssets.metro_minutes(c["location"],id),Fmt.money(float(q["parking"])),Fmt.money(float(q["fuel"]))],"PersonalDrive_"+id,choose_drive.bind(id),true)
			act(box,"Sell personal car after depreciation","PersonalSellCar",PersonalAssets.sell_car)
	else:
		for style in PersonalAssets.cfg()["furniture"]:
			var spec: Dictionary=PersonalAssets.cfg()["furniture"][style]
			act(box,I18n.t("Install %s: %s")%[I18n.t(spec["name"]),Fmt.money(float(spec["cost"]))],"PersonalStyle_"+style,PersonalAssets.decorate.bind(style),true)
		for npc in DataDB.npcs:
			if GameState.flag("met_"+npc):act(box,I18n.t("Invite %s home for one hour")%DataDB.npcs[npc]["name"],"PersonalHost_"+npc,PersonalAssets.host.bind(npc))
	footer.add_child(UIK.button("Close",close,"primary" if not primary else ""))

func choose_drive(to: String) -> Dictionary:
	UIRoot.open_modal(PersonalDriveModal.new(to))
	return {"ok":true,"close":true}
