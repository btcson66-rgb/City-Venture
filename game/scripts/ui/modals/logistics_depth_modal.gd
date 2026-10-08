class_name LogisticsDepthModal
extends Modal
var vehicle: String="van1"
var chosen: bool=false
func _init() -> void:
	industry_intro = "logistics"
	title_text="Fleet, route contracts and maintenance";help_key="logistics_depth";icon_name="map";panel_size=Vector2(490,350);pauses_time=true
func action(box: Control,text: String,id: String,fn: Callable,primary := false) -> void:
	var active: bool=primary and not chosen;chosen=chosen or active
	var button:=UIK.button(text,func():
		var result: Dictionary=fn.call()
		if not result.get("ok",false):UIRoot.toast(I18n.t(result.get("error","")),"warn","map")
		rebuild(),"primary" if active else "")
	button.name=id;box.add_child(button)
func build() -> void:
	chosen=false
	var box:=UIK.vbox(4);body.add_child(UIK.scroll(box,Vector2(456,255)))
	box.add_child(UIK.label_tip("Vehicle condition","vehicle_condition",10,Art.C_SKY))
	for id in LogisticsDepth.vehicles():
		var v: Dictionary=LogisticsDepth.vehicles()[id]
		if not v["owned"]:continue
		var b:=UIK.button(LogisticsDepth.vehicle_name(id)+" · "+I18n.t(LogisticsDepth.model(v)["name"]),func():vehicle=id;rebuild(),"tab_active" if id==vehicle else "tab")
		b.name="FleetSelect_"+id;box.add_child(b)
		box.add_child(UIK.wrap(I18n.t("Condition %.0f/100 · %.1f km · breakdown risk %.1f%% per trip")%[float(v["condition"]),float(v["km"]),100*LogisticsDepth.chance(v)],8,Art.C_WHITE,440))
		box.add_child(UIK.wrap(("✓ " if LogisticsDepth.available(id) else "✗ ")+I18n.t("Ready. Assign a driver or choose a trip." if LogisticsDepth.available(id) else "Busy. Wait for the run or half-day service to finish."),8,Art.C_MUTED,440))
		box.add_child(UIK.label_tip("Preventive maintenance","preventive_maintenance",9,Art.C_SKY))
		action(box,I18n.t("Service %s: %s, half a day")%[LogisticsDepth.vehicle_name(id),Fmt.money(float(LogisticsDepth.cfg()["service_cost"]))],"FleetService_"+id,LogisticsDepth.service.bind(id),float(v["condition"])<60 and LogisticsDepth.available(id))
		box.add_child(UIK.label_tip("Cost per kilometre","cost_per_km",9,Art.C_SKY))
		var report:=LogisticsDepth.report(id)
		box.add_child(UIK.wrap(I18n.t("Revenue %s · fuel %s · service %s · insurance %s · depreciation %s · margin %s/km (before driver wages and initial van expense)")%[Fmt.money(float(v["revenue"])),Fmt.money(float(v["fuel"])),Fmt.money(float(v["maintenance"])),Fmt.money(float(report["insurance"])),Fmt.money(float(report["depreciation"])),Fmt.money(float(report["profit_km"]))],8,Art.C_WHITE,440))
		box.add_child(UIK.wrap(I18n.t("Allocated operating profit %s/km: company logistics profit including wages and setup costs, shared by kilometres driven.")%Fmt.money(float(report["allocated_profit_km"])),8,Art.C_MUTED,440))
	if not LogisticsDepth.vehicles().has("van2"):
		for id in LogisticsDepth.cfg()["models"]:
			var m: Dictionary=LogisticsDepth.cfg()["models"][id]
			action(box,I18n.t("Buy %s: %s + insurance %s")%[I18n.t(m["name"]),Fmt.money(float(m["price"])),Fmt.money(float(m["insurance_month"]))],"FleetBuy_"+id,LogisticsDepth.buy.bind(id))
	for p in Staff.people().filter(func(p):return p["role"]=="driver"):
		action(box,I18n.t("Assign %s to %s")%[p["name"],LogisticsDepth.vehicle_name(vehicle)],"FleetAssign_"+p["id"],LogisticsDepth.assign.bind(p["id"],vehicle))
	box.add_child(UIK.label_tip("Route contract","route_contract",10,Art.C_SKY))
	for c in Contracts.C().values():
		if c.get("type","")!="delivery_route":continue
		box.add_child(UIK.wrap(I18n.t("%s · %d trips/week · %s/trip · 90 days")%[GameState.entity_name(c["buyer"]),int(c["qty"]),Fmt.money(float(c["unit_price"]))],8,Art.C_WHITE,440))
		if c["status"]=="offered":
			action(box,"Counter +5% per trip","RouteCounter_"+c["id"],Contracts.counter.bind(c["id"],float(c["unit_price"])*1.05,0,0.0))
			action(box,"Sign ninety-day route","RouteSign_"+c["id"],Contracts.accept.bind(c["id"]),not chosen)
			action(box,"Decline this route","RouteDecline_"+c["id"],func():Contracts.reject(c["id"]);return {"ok":true})
		elif c["status"]=="active":
			box.add_child(UIK.label(I18n.t("Completed %d/%d trips this week")%[int(c["completed"]),int(c["qty"])],8,Art.C_MUTED))
			action(box,"Drive planned route","RouteDrive_"+c["id"],LogisticsDepth.run_route.bind(c["id"],vehicle),int(c["completed"])<int(c["qty"]) and LogisticsDepth.available(vehicle))
	footer.add_child(UIK.button("Close",close,"primary" if not chosen else ""))
