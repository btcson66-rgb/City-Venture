class_name CafeDepthModal
extends Modal
var property: String
var page: String="menu"
var chosen: bool=false
func _init(id := "corner_cafe") -> void:
	property=id
	title_text="Café menu, shifts and inspections"
	help_key="cafe_depth"
	icon_name="coffee"
	panel_size=Vector2(490,350)
	pauses_time=true
func action(box: Control,label: String,id: String,fn: Callable,primary := false) -> void:
	var highlight: bool=primary and not chosen;chosen=chosen or highlight
	var b:=UIK.button(label,func():
		var result: Dictionary=Cafe.in_shop(property,fn)
		if not result.get("ok",false):UIRoot.toast(I18n.t(result.get("error","")),"warn","coffee")
		rebuild(),"primary" if highlight else "")
	b.name=id;box.add_child(b)
func build() -> void:
	chosen=false
	var shops:=UIK.hbox(3);body.add_child(shops)
	for id in Cafe.cfg()["locations"]:
		var b:=UIK.button(I18n.t(DataDB.properties[id]["name"]),func():property=id;rebuild(),"tab_active" if id==property else "tab")
		b.name="CafeShop_"+id;shops.add_child(b)
	var tabs:=UIK.hbox(3);body.add_child(tabs)
	for id in ["menu","shifts","inspection","report"]:
		var b:=UIK.button({"menu":"Menu and ingredients","shifts":"Weekly café shifts","inspection":"Health inspection","report":"Thirty-day café report"}[id],func():page=id;rebuild())
		b.name="CafePage_"+id;tabs.add_child(b)
	var box:=UIK.vbox(4);body.add_child(UIK.scroll(box,Vector2(456,220)))
	Cafe.in_shop(property,func():build_shop(box))
	footer.add_child(UIK.button("Close",close,"primary" if not chosen else ""))
func build_shop(box: Control) -> void:
	var s:=Cafe.S()
	if not Cafe.leased():
		box.add_child(UIK.label_tip("Second location","second_location",10,Art.C_SKY))
		box.add_child(UIK.wrap("✗ "+I18n.t("Lease this café first. Each location needs its own fit-out, licence, staff and ingredients."),8,Art.C_WHITE,440))
		action(box,"Lease this café","CafeDepthLease",Living.lease.bind(property),true)
		return
	if not Cafe.fitted():
		if Cafe.fitting():box.add_child(UIK.wrap("✗ "+I18n.t("Fit-out underway. Wait until tomorrow."),8,Art.C_MUTED,440))
		else:action(box,"Fit out this café","CafeDepthFit",Cafe.fit_out,true)
	if not Cafe.permitted():
		if Cafe.permit_pending():box.add_child(UIK.wrap("✗ "+I18n.t("Licence application pending. Wait for approval."),8,Art.C_MUTED,440))
		else:action(box,"Apply for this café's food licence","CafeDepthPermit",Cafe.apply_permit,true)
	if page=="menu":
		box.add_child(UIK.label_tip("Seasonal menu","seasonal_menu",10,Art.C_SKY))
		for id in Cafe.cfg()["items"]:
			var item:=Cafe.item(id)
			box.add_child(UIK.wrap(I18n.t("%s · price %s · ingredient cost %s · unit gross profit %s")%[I18n.t(item["name"]),Fmt.money(Cafe.price(id)),Fmt.money(float(item["unit_cost"])),Fmt.money(CafeDepth.margin(id))],8,Art.C_WHITE,440))
			box.add_child(UIK.wrap(("✓ " if CafeDepth.available(id) else "✗ ")+I18n.t("Offer this item with ingredients in stock." if CafeDepth.available(id) else "Missing ingredients. Order supplies before serving." if CafeDepth.seasonal(id) else "Out of season. Use another item until the next listed month."),8,Art.C_MUTED,440))
		for id in Cafe.cfg()["materials"]:
			box.add_child(UIK.label(I18n.t("%s: %d units · %d units arriving")%[I18n.t(Cafe.cfg()["materials"][id]["name"]),int(s["pastries"]) if id=="bakery_pastry" else int(s["materials"].get(id,0)),int(s["material_incoming"].get(id,0))],8,Art.C_WHITE))
		for p in Cafe.cfg()["supply_packs"]:
			action(box,I18n.t("%d cups · %s")%[int(p["cups"]),Fmt.money(Cafe.pack_cost(p["id"]))],"CafeBeanPack_"+p["id"],Cafe.order_supplies.bind(p["id"]),int(s["supplies"])+int(s["incoming"])<50)
		for p in Cafe.cfg()["material_packs"]:action(box,I18n.t("Buy %s: %s")%[I18n.t(p["name"]),Fmt.money(float(p["cost"])*World.cost_mult(Cafe.SUPPLIER))],"CafeMaterial_"+p["id"],CafeDepth.order.bind(p["id"]),int(s["materials"].get(p["id"],0))+int(s["material_incoming"].get(p["id"],0))<40)
	elif page=="shifts":
		box.add_child(UIK.label_tip("Labour cost ratio","labor_cost_ratio",10,Art.C_SKY))
		box.add_child(UIK.wrap("Early shift 7:00–12:00; late shift 12:00–17:00. An unassigned shift stays closed unless you work the counter. Beyond forty hours costs 1.5 times the hourly wage.",8,Art.C_WHITE,440))
		for p in Staff.people().filter(func(p):return p["role"]=="barista"):
			CafeDepth.scheduled(p,Clock.now(),property)
			box.add_child(UIK.label(p["name"],9,Art.C_SKY))
			for day in range(1,8):
				var row:=UIK.hbox(3);box.add_child(row)
				row.add_child(UIK.label(I18n.t("Weekday %d")%day,8,Art.C_MUTED))
				for shift in ["early","late"]:
					var assigned: bool=CafeDepth.roster()[p["id"]].get(str(day)+":"+shift,"")==property
					action(row,("✓ " if assigned else "✗ ")+I18n.t("Early — toggle assignment" if shift=="early" else "Late — toggle assignment"),"CafeShift_"+p["id"]+"_"+str(day)+"_"+shift,CafeDepth.assign.bind(p["id"],day,shift))
	elif page=="inspection":
		box.add_child(UIK.label_tip("Health inspection","health_inspection",10,Art.C_SKY))
		box.add_child(UIK.wrap(I18n.t("Next inspection: %s. Improve waste, stockouts, ratings and daily cleaning; a closure ends after one day.")%Clock.fmt_short(int(s["inspection_next"])) if int(s["inspection_next"])>=0 else I18n.t("scheduled after opening"),8,Art.C_WHITE,440))
		var cleaned: bool=int(s["cleaned"])/Clock.DAY==Clock.day_index()
		box.add_child(UIK.wrap(("✓ " if cleaned else "✗ ")+I18n.t("Cleaned today. Inspect if due, or clean again tomorrow." if cleaned else "Clean for fifteen minutes before closing or inspection."),8,Art.C_MUTED,440))
		if not cleaned:action(box,"Closing clean: fifteen minutes","CafeClosingClean",CafeDepth.clean,true)
		if s["inspection_pending"]:
			action(box,"Inspect current shop now","CafeInspectNow",inspect_current)
		if not s["inspections"].is_empty():box.add_child(UIK.label(I18n.t({"pass":"Inspection passed","improve":"One-day improvement closure","fine":"Inspection fine and one-day closure"}[s["inspections"][-1]["outcome"]]),8,Art.C_SKY))
	else:
		box.add_child(UIK.wrap("Ingredients are expensed when ordered. Restocking days may show negative gross margin; the graph uses actual posted costs.",8,Art.C_MUTED,440))
		var days: Array=s["days"].filter(func(row):return int(row["d"])>=Clock.day_index()-29)
		for metric in ["served","rev","gross_margin"]:
			var graph:=CafeDayChart.new()
			graph.rows=days;graph.metric=metric;box.add_child(graph)
func inspect_current() -> Dictionary:
	var s:=Cafe.S()
	return EventEngine.choose(s["inspection_iid"],"as_is") if s.has("inspection_iid") else CafeDepth.inspect()
