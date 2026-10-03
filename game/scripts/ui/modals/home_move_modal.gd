class_name HomeMoveModal
extends Modal
func _init() -> void:
	title_text="Find a home — Okafor Lettings"
	icon_name="home"
	help_key="home_moving"
	panel_size=Vector2(460,330)
	pauses_time=true
func act(box: Control,label: String,id: String,fn: Callable,primary := false) -> void:
	var b:=UIK.button(label,func():
		var result: Dictionary=fn.call()
		if not result["ok"]:UIRoot.toast(I18n.t(result["error"]),"warn","home")
		rebuild(),"primary" if primary else "")
	b.name=id;box.add_child(b)
func build() -> void:
	if Tutorial.first_venture_active():
		body.add_child(UIK.wrap("Finish the arrival tutorial before moving. Your first home stays at Riverside.",9,Art.C_WHITE,426))
		footer.add_child(UIK.button("Keep current home",close,"primary"))
		return
	var box:=UIK.vbox(4)
	body.add_child(UIK.scroll(box,Vector2(426,230)))
	box.add_child(UIK.label_tip("Home rent and location","home_rent_vs_location",10,Art.C_GOLD))
	box.add_child(UIK.wrap(I18n.t("Current home: %s · %s per month")%[I18n.t(DataDB.properties[Living.home()]["name"]),Fmt.money(Living.home_rent())],8,Art.C_WHITE,410))
	var pending: Dictionary=Housing.S()["pending"]
	if not pending.is_empty():
		box.add_child(UIK.wrap(I18n.t("Reserved %s. Notice ends %s; current rent continues until moving day.")%[I18n.t(DataDB.properties[pending["to"]]["name"]),Clock.fmt_short(int(pending["ready"]))],8,Art.C_SKY,410))
		var why:=Housing.capacity_block(pending["to"])
		box.add_child(UIK.wrap("✗ "+I18n.t(why) if why!="" else "✓ "+I18n.t("Keep enough cash and wait for the notice date, or move once it arrives."),8,Art.C_MUTED,410))
		var can_move: bool=Clock.now()>=int(pending["ready"]) and why=="" and Ledger.cash("player")>=Housing.fee()+(Living.home_rent() if pending["mode"]=="penalty" else 0)
		if can_move:act(footer,"Retry this move","RetryHomeMove",Housing.execute,true)
		act(footer,"Cancel reservation and return deposit","CancelHomeMove",Housing.cancel,not can_move)
	else:
		var primary:=false
		for pid in DataDB.properties:
			var property: Dictionary=DataDB.properties[pid]
			if property.get("kind","")!="home" or pid==Living.home():continue
			box.add_child(UIK.label(I18n.t(property["name"]),9,Art.C_GOLD))
			var deposit:=float(property["monthly_rent"])*World.rent_mult()
			box.add_child(UIK.wrap(I18n.t("%s per month · one-month deposit %s · storage %d units · moving service %s")%[Fmt.money(deposit),Fmt.money(deposit),int(property["inventory_units"]),Fmt.money(Housing.fee())],8,Art.C_WHITE,410))
			var why:=Housing.capacity_block(pid)
			box.add_child(UIK.wrap("✗ "+I18n.t(why) if why!="" else "✓ "+I18n.t("Choose notice to avoid the termination fee, or pay to move today."),8,Art.C_MUTED,410))
			if why=="":
				act(box,"Reserve with 30 days' notice","HomeNotice_"+pid,Housing.request.bind(pid,"notice"),not primary)
				primary=true
				act(box,I18n.t("Move today: termination fee %s")%Fmt.money(Living.home_rent()),"HomeNow_"+pid,Housing.request.bind(pid,"penalty"))
	footer.add_child(UIK.button("Keep current home",close))
