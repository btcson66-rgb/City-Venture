class_name PopupStoreModal
extends Modal
var chosen:=false
func _init() -> void:
	industry_intro = "popup"
	title_text="Weekend pop-up";help_key="popup_store";icon_name="shop";panel_size=Vector2(500,360);pauses_time=true
func action(box: Control,text: String,id: String,fn: Callable,primary:=false) -> void:
	var highlight:=primary and not chosen;chosen=chosen or highlight
	var button:=UIK.button(text,func():
		var r: Dictionary=fn.call()
		if not r.get("ok",false):UIRoot.toast(I18n.t(r.get("error","")),"warn","lock")
		rebuild(),"primary" if highlight else "")
	button.name=id;box.add_child(button)
func build() -> void:
	chosen=false
	var box:=UIK.vbox(4);body.add_child(UIK.scroll(box,Vector2(464,265)))
	box.add_child(UIK.label_tip("Weekend pop-up","popup_store",10,Art.C_SKY))
	box.add_child(UIK.wrap(I18n.t("Saturday and Sunday 10:00–18:00 · %s/weekend · reserve at least one day ahead · capacity %d units")%[Fmt.money(float(PopupStore.cfg()["rent_weekend"])),int(PopupStore.cfg()["capacity"])],8,Art.C_WHITE,448))
	var a:=PopupStore.active()
	if a.is_empty():
		box.add_child(UIK.wrap("✗ "+I18n.t("No weekend reserved. Go to the notice at Pop-up Unit 5 to sign."),8,Art.C_MUTED,448))
		if GameState.data["player"]["location"].get("id","")=="popup_unit":
			box.add_child(UIK.label(I18n.t("Next weekend: %s")%str(Clock.date_at(PopupStore.next_weekend())["day"])+" · "+I18n.t(Clock.month_name(int(Clock.date_at(PopupStore.next_weekend())["month"]))),8,Art.C_WHITE))
			action(box,"Reserve this weekend","SignPopup",Living.lease.bind("popup_retail"),PopupStore.S()["history"].is_empty())
	else:
		box.add_child(UIK.label(I18n.t("Stock: %d/%d units")%[Ecommerce.total_units_at("popup_retail"),int(PopupStore.cfg()["capacity"])],8,Art.C_WHITE))
		box.add_child(UIK.wrap(I18n.t("Move stock in one hour. An available company van is free; otherwise transport costs %s per trip.")%Fmt.money(float(PopupStore.cfg()["move_fee"])),8,Art.C_MUTED,448))
		var shown: Dictionary={}
		for source in Ecommerce.stock_locations():
			for product in Ecommerce.inv(source):
				var available:=Ecommerce.available(source,product)
				if available<=0:continue
				var suffix: String="_"+source if shown.has(product) else ""
				shown[product]=true
				var row:=UIK.hbox(4);box.add_child(row)
				row.add_child(UIK.label(I18n.t("%s · %s · %d units")%[I18n.t(DataDB.products[product]["name"]),Ecommerce.location_name(source),available],8,Art.C_WHITE))
				var qty:=SpinBox.new();qty.min_value=1;qty.max_value=mini(available,int(PopupStore.cfg()["capacity"])-Ecommerce.total_units_at("popup_retail"));qty.value=mini(50,int(qty.max_value));qty.name="PopupQty_"+product+suffix;row.add_child(qty)
				action(box,"Move selected stock","PopupStock_"+product+suffix,func():return PopupStore.move_stock(product,source,int(qty.value)),Ecommerce.total_units_at("popup_retail")==0 and qty.max_value>0)
		for product in a["prices"]:
			box.add_child(UIK.label(I18n.t(DataDB.products[product]["name"])+" · "+Fmt.money(float(a["prices"][product]))+" / "+I18n.t("unit"),8,Art.C_WHITE))
			for delta in [-.5,.5]:action(box,I18n.t("Price %s")%Fmt.money(delta),"PopupPrice_"+product+str(delta),func():return PopupStore.set_price(product,float(a["prices"][product])+delta))
		box.add_child(UIK.label_tip("Foot traffic","foot_traffic",9,Art.C_SKY))
		var why:=PopupStore.owner_block()
		box.add_child(UIK.wrap(("✓ " if why=="" else "✗ ")+I18n.t("Work the checkout now." if why=="" else why),8,Art.C_MUTED,448))
		if why=="":
			var b:=UIK.button("Work checkout for one hour",func():close();PopupStore.open_till(),"primary" if not chosen else "")
			b.name="PopupTill";box.add_child(b);chosen=true
		box.add_child(UIK.wrap(I18n.t("Weekend employee: %s per hour, paid in addition to the normal roster. Assign Saturday or Sunday in People.")%Fmt.money(float(PopupStore.cfg()["employee_hourly"])),8,Art.C_MUTED,448))
	if not PopupStore.S()["history"].is_empty():
		var r: Dictionary=PopupStore.S()["history"][-1]
		box.add_child(UIK.label_tip("Channel margin","channel_margin",10,Art.C_SKY))
		box.add_child(UIK.label(I18n.t("Weekend report: %d visitors · %d units sold")%[int(r["customers"]),int(r["units"])],9,Art.C_WHITE))
		for pair in [["Sales revenue","revenue"],["Stock cost","cogs"],["Weekend rent","rent"],["Weekend wages","wages"],["Card fees","fee"],["Stock transport","move"],["Net profit","net"],["ShopLane fee estimate","shoplane_fee"],["ShopLane same-sales margin estimate","shoplane_net"]]:box.add_child(UIK.label(I18n.t(pair[0])+": "+Fmt.money(float(r[pair[1]])),8,Art.C_WHITE))
		box.add_child(UIK.wrap("Comparison uses only the units actually sold and the current ShopLane fee rate. It assumes the same prices, excludes online shipping and returns, and never books estimated income.",8,Art.C_MUTED,448))
	footer.add_child(UIK.button("Close",close,"primary" if not chosen else ""))
