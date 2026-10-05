class_name HotelUI
extends Modal
## Rate Board: 30-day demand calendar, prices, channels and overbooking, plus daily operations, groups, reviews and growth.
var page := "board"
var has_primary := false
func _init() -> void:
	title_text="Rate Board"
	help_key="hotel"
	icon_name="sleep"
	panel_size=Vector2(610,345)
static func open() -> void:UIRoot.open_modal(HotelUI.new())
static func render(owner: Node) -> void:
	owner.content.add_child(UIK.label_tip("Hotel / Tourism","hotel",10))
	owner.content.add_child(UIK.wrap("Set room prices, channels and overbooking against a 30-day demand calendar.",8,Art.C_WHITE,460))
	var go := UIK.button("Open Rate Board",open,"primary")
	go.name="OpenRateBoard"
	owner.content.add_child(go)
static func board(det: Control,_board: Node) -> void:
	det.add_child(UIK.wrap("Take over or lease the Aster Inn in Luxury Heights, then set prices on the Rate Board.",8,Art.C_WHITE,300))
	var go := UIK.button("Open Rate Board",open,"primary")
	go.name="OpenRateBoard"
	det.add_child(go)
func act(callback: Callable) -> void:
	var result: Dictionary=callback.call()
	if not result.get("ok",false):EventBus.notify.emit(result.get("error",""),"bad","sleep")
	rebuild()
func button(parent: Control,label: String,id: String,callback: Callable,primary := false) -> void:
	var main := primary and not has_primary
	if main:has_primary=true
	var action := UIK.button(label,act.bind(callback),"primary" if main else "button")
	action.name=id
	parent.add_child(action)
func nav_button(parent: Control,label: String,id: String,next: String,primary := false) -> void:
	var main := primary and not has_primary
	if main:has_primary=true
	var action := UIK.button(label,switch.bind(next),"primary" if main else "button")
	action.name=id
	parent.add_child(action)
func switch(next: String) -> void:page=next;reset_scroll=true;rebuild()
func line(content: Control,text: String,color := Art.C_WHITE) -> void:content.add_child(UIK.wrap(text,8,color,550))
func check(content: Control,ok: bool,text: String) -> void:line(content,("✓ " if ok else "✗ ")+I18n.t(text),Art.C_GREEN if ok else Art.C_GOLD)
func build() -> void:
	has_primary=false
	if not Hotel.is_running():
		var content := UIK.vbox(4)
		body.add_child(UIK.scroll(content,Vector2(580,300)))
		closed_view(content)
		return
	var nav := UIK.hbox(4)
	body.add_child(nav)
	for tab in [["board","Rate Board"],["ops","Daily operations"],["groups","Groups and OTA"],["reviews","Guest reviews"],["growth","Growth"]]:
		var choice := UIK.button(tab[1],switch.bind(tab[0]),"tab_active" if page==tab[0] else "tab")
		choice.name="HotelTab_"+tab[0]
		nav.add_child(choice)
	var content := UIK.vbox(4)
	body.add_child(UIK.scroll(content,Vector2(580,270)))
	var info := Hotel.stats(30)
	line(content,I18n.t("Rating %.1f of 5 · occupancy %d%% (30 days) · ADR %s · RevPAR %s · cash %s")%[Hotel.rating(),roundi(float(info["occupancy"])*100),Fmt.money(float(info["adr"])),Fmt.money(float(info["revpar"])),Fmt.money0(Ledger.cash(Hotel.entity()))],Art.C_SKY)
	match page:
		"board":board_page(content)
		"ops":ops_page(content)
		"groups":groups_page(content)
		"reviews":reviews_page(content)
		"growth":growth_page(content)
func closed_view(content: Control) -> void:
	content.add_child(UIK.label_tip("Aster Inn","hotel",9))
	line(content,"Take over the 12-room Aster Inn: set prices, choose channels and keep the rooms clean.",Art.C_SKY)
	var company: bool=GameState.company_id()!="" and GameState.flag("business_account_opened")
	check(content,company,"Register a company and open its bank account first.")
	check(content,GameState.visited("the_aster"),"Visit The Aster in Luxury Heights and meet Henri Dubois first.")
	var cash := Ledger.cash(GameState.company_id()) if GameState.company_id()!="" else 0.0
	check(content,cash>=Hotel.takeover_price(),I18n.t("Take over for %s, or lease with %s cash for the first month (you have %s).")%[Fmt.money0(Hotel.takeover_price()),Fmt.money0(Hotel.lease_cost()),Fmt.money0(cash)])
	if Hotel.open_block()=="":
		if cash>=Hotel.takeover_price():
			button(content,I18n.t("Take over the Aster Inn · %s")%Fmt.money0(Hotel.takeover_price()),"TakeoverAster",Hotel.start.bind("own"),true)
			button(content,I18n.t("Lease instead · %s per month plus equipment")%Fmt.money0(float(DataDB.properties["aster_inn"]["monthly_rent"])),"LeaseAster",Hotel.start.bind("lease"))
		else:
			button(content,I18n.t("Lease the Aster Inn · %s first month")%Fmt.money0(Hotel.lease_cost()),"LeaseAster",Hotel.start.bind("lease"),cash>=Hotel.lease_cost())
	if not has_primary:
		var destination := "civic_center" if GameState.company_id()=="" else "financial" if not GameState.flag("business_account_opened") else "luxury_heights"
		var route := UIK.button(I18n.t(DataDB.districts[destination]["name"]) if DataDB.districts.has(destination) else destination,func():
			close()
			var map := CityMapModal.new(false)
			map.sel=destination
			UIRoot.open_modal(map),"primary")
		route.name="RouteHotelPrerequisite"
		content.add_child(route)
		has_primary=true

# ------------------------------------------------------------------ Rate Board
func change_price(type: String,delta: float) -> Dictionary:
	var t: Dictionary=Hotel.cfg()["types"][type]
	return Hotel.set_price(type,clampf(Hotel.rack_price(type)+delta,float(t["min_price"]),float(t["max_price"])))
func channel(allot_delta := 0.0,toggle := "") -> Dictionary:
	var c: Dictionary=Hotel.S()["channels"]
	var open := bool(c["ota_open"])
	var tier := str(c["ota_tier"])
	if toggle=="open":open=not open
	if toggle=="tier":tier="featured" if tier=="standard" else "standard"
	return Hotel.set_channels(open,tier,clampf(float(c["ota_allot"])+allot_delta,0,1))
func calendar_note(row: Dictionary) -> String:
	if str(row["event"])!="":return I18n.t(str(row["event"])).left(14)
	if int(row["blocked"])>0:return "%d %s"%[int(row["blocked"]),I18n.t("group rooms")]
	return " "
func board_page(content: Control) -> void:
	content.add_child(UIK.label_tip("30-day demand calendar","hotel_calendar",9))
	line(content,"Each day shows expected occupancy at your current prices. Gold days are peak demand; purple days have a city event.",Art.C_MUTED)
	var grid := GridContainer.new()
	grid.columns=7
	grid.add_theme_constant_override("h_separation",2)
	grid.add_theme_constant_override("v_separation",2)
	content.add_child(grid)
	for row in Hotel.calendar(30):
		var date := Clock.date_at((int(row["day"])-1)*Clock.DAY+12*60)
		var color := Art.C_PURPLE if str(row["event"])!="" else Art.C_GOLD if float(row["index"])>=float(Hotel.cfg()["peak_threshold"]) else Art.C_BLUE if float(row["index"])<.9 else Art.C_MUTED
		var cell := UIK.chip("%s %d\n%d%% · ×%.2f\n%s"%[I18n.t(Clock.WEEKDAYS[int(row["weekday"])]),int(date["day"]),roundi(float(row["occupancy"])*100),float(row["index"]),calendar_note(row)],color)
		cell.custom_minimum_size=Vector2(76,0)
		grid.add_child(cell)
	content.add_child(UIK.sep())
	content.add_child(UIK.label_tip("Room prices","hotel_adr",9))
	for type in Hotel.TYPES:
		var t: Dictionary=Hotel.cfg()["types"][type]
		var row := UIK.hbox(4)
		content.add_child(row)
		var state := "" if not Hotel.out_of_order(type) else " ✗ "+I18n.t("not for sale")
		row.add_child(UIK.label(I18n.t("%s · %d rooms · %s per night (market %s)")%[Hotel.type_name(type),Hotel.rooms_of(type),Fmt.money(Hotel.rack_price(type)),Fmt.money0(float(t["ref_price"]))]+state,8))
		for delta in [-10.0,-1.0,1.0,10.0]:
			button(row,Fmt.money0(delta,true),"Price_%s_%s"%[type,str(int(delta)).replace("-","m")],change_price.bind(type,delta))
	content.add_child(UIK.sep())
	content.add_child(UIK.label_tip("Channels","hotel_channels",9))
	var c: Dictionary=Hotel.S()["channels"]
	var tier: Dictionary=Hotel.cfg()["ota_tiers"][c["ota_tier"]]
	line(content,I18n.t("Direct: no commission, lower volume. OTA %s: %d%% commission on every night, more guests. Agency group blocks: 25%% off, rooms locked in advance (see Groups and OTA).")%[I18n.t(tier["name"]),roundi(float(tier["commission"])*100)],Art.C_MUTED)
	var row := UIK.hbox(4)
	content.add_child(row)
	button(row,I18n.t("OTA listing: %s")%I18n.t("open ✓" if c["ota_open"] else "closed ✗"),"ToggleOTA",channel.bind(0.0,"open"))
	button(row,I18n.t("Tier: %s · %d%%")%[I18n.t(tier["name"]),roundi(float(tier["commission"])*100)],"ToggleOTATier",channel.bind(0.0,"tier"))
	button(row,"−10%","OTAAllotLess",channel.bind(-.1,""))
	row.add_child(UIK.label(I18n.t("OTA share of rooms %d%%")%roundi(float(c["ota_allot"])*100),8))
	button(row,"+10%","OTAAllotMore",channel.bind(.1,""))
	content.add_child(UIK.label_tip("Overbooking and peak pricing","hotel_overbook",9))
	var ob := UIK.hbox(4)
	content.add_child(ob)
	button(ob,"−1%","OverbookLess",func():return Hotel.set_overbook(maxf(0,float(Hotel.S()["overbook"])-.01)))
	ob.add_child(UIK.label(I18n.t("Overbooking %d%% · walk cost about %s per guest at the Standard price")%[roundi(float(Hotel.S()["overbook"])*100),Fmt.money0(Hotel.rack_price("standard")*float(Hotel.cfg()["walk_price_mult"])+float(Hotel.cfg()["walk_relocation"]))],8))
	button(ob,"+1%","OverbookMore",func():return Hotel.set_overbook(minf(float(Hotel.cfg()["overbook_max"]),float(Hotel.S()["overbook"])+.01)))
	var pk := UIK.hbox(4)
	content.add_child(pk)
	button(pk,"−5%","PeakLess",func():return Hotel.set_peak(maxf(0,float(Hotel.S()["peak"])-.05)))
	pk.add_child(UIK.label(I18n.t("Peak-day surcharge %d%% on days at ×%.1f demand or more")%[roundi(float(Hotel.S()["peak"])*100),float(Hotel.cfg()["peak_threshold"])],8))
	button(pk,"+5%","PeakMore",func():return Hotel.set_peak(minf(float(Hotel.cfg()["peak_max"]),float(Hotel.S()["peak"])+.05)))
	nav_button(content,"Next: daily operations","BoardNextOps","ops",true)

# ------------------------------------------------------------------ operations
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
func ops_page(content: Control) -> void:
	content.add_child(UIK.label_tip("Housekeeping capacity","hotel_housekeeping",9))
	var work := Hotel.turnover_work()
	var capacity := Hotel.hk_capacity()
	check(content,capacity>=work,I18n.t("Housekeeping can clean %.1f rooms a day; last night's turnover needs %.1f (rooms left dirty cannot be sold).")%[capacity,work])
	var housekeepers := Staff.count("housekeeper")
	var desk := Staff.count("front_desk")
	check(content,housekeepers>0,I18n.t("%d housekeepers hired (each cleans about %d rooms a day; the owner covers %d).")%[housekeepers,roundi(float(Hotel.cfg()["rooms_per_housekeeper"])),int(Hotel.cfg()["owner_clean"])])
	check(content,Hotel.desk_coverage()>=.99,I18n.t("Front desk coverage %d%% with %d staff.")%[roundi(Hotel.desk_coverage()*100),desk])
	var row := UIK.hbox(4)
	content.add_child(row)
	var need_hk: bool=capacity<work or housekeepers==0
	button(row,I18n.t("Recruit housekeeper · %s per week")%Fmt.money0(float(Staff.role_def("housekeeper")["salary_week"][0])),"Recruit_housekeeper",recruit.bind("housekeeper"),need_hk)
	button(row,I18n.t("Recruit front desk · %s per week")%Fmt.money0(float(Staff.role_def("front_desk")["salary_week"][0])),"Recruit_front_desk",recruit.bind("front_desk"),not need_hk and Hotel.desk_coverage()<.99)
	button(content,I18n.t("Temporary cleaners: %s · %s per room")%[I18n.t("on ✓" if Hotel.S()["temp"] else "off ✗"),Fmt.money0(float(Hotel.cfg()["temp_cost_room"]))],"ToggleTemp",func():return Hotel.set_temp(not bool(Hotel.S()["temp"])))
	content.add_child(UIK.sep())
	content.add_child(UIK.label_tip("Breakfast and supplies","hotel_supplies",9))
	for mode in ["none","standard","own_cafe"]:
		var b: Dictionary=Hotel.cfg()["breakfast"][mode]
		var mark := "● " if Hotel.S()["breakfast"]==mode else ""
		button(content,mark+I18n.t("%s · %s per guest · service +%.2f")%[I18n.t(b["name"]),Fmt.money(float(b["cost"])),float(b["service"])],"Breakfast_"+mode,Hotel.set_breakfast.bind(mode))
	if not Cafe.leased():line(content,"✗ "+I18n.t("Lease your corner cafe to serve breakfast from its kitchen at wholesale cost."),Art.C_GOLD)
	line(content,I18n.t("Linen, laundry and amenities cost %s per occupied room-night; utilities %s per room per day.")%[Fmt.money(float(Hotel.cfg()["supplies_room"])),Fmt.money(float(Hotel.cfg()["utilities_room_day"]))],Art.C_MUTED)
	content.add_child(UIK.sep())
	content.add_child(UIK.label_tip("Room equipment and renovation","hotel_equipment",9))
	var urgent := ""
	for type in Hotel.TYPES:
		var issues: Dictionary=Hotel.type_issues(type)
		var cond := float(Hotel.S()["rooms"][type]["cond"])
		var renovating: bool=Clock.now()<int(Hotel.S()["rooms"][type]["reno_until"])
		var ok: bool=not issues["broken"] and not issues["due"] and not renovating
		var status := I18n.t("In service")
		if renovating:status=I18n.t("renovating until %s")%Clock.fmt_short(int(Hotel.S()["rooms"][type]["reno_until"]))
		elif issues["broken"]:status=I18n.t("broken: rooms not for sale")
		elif issues["due"]:status=I18n.t("service due")
		line(content,("✓ " if ok else "✗ ")+I18n.t("%s · condition %d%% · %s")%[Hotel.type_name(type),roundi(cond),status],Art.C_GREEN if ok else Art.C_GOLD)
		var eq := UIK.hbox(4)
		content.add_child(eq)
		if issues["broken"] or issues["due"]:
			if urgent=="":urgent=type
			button(eq,I18n.t("Service %s equipment · %s")%[Hotel.type_name(type),Fmt.money0(Hotel.maintain_cost(type))],"Maintain_"+type,Hotel.maintain.bind(type),urgent==type)
		button(eq,I18n.t("Renovate %s · %s · %d days offline")%[Hotel.type_name(type),Fmt.money0(Hotel.renovation_cost(type)),int(Hotel.cfg()["types"][type]["renovate_days"])],"Renovate_"+type,Hotel.renovate.bind(type))
	nav_button(content,"Next: groups and OTA","OpsNextGroups","groups",true)

# ------------------------------------------------------------------ groups and OTA
func groups_page(content: Control) -> void:
	content.add_child(UIK.label_tip("Travel-agency group blocks","hotel_blocks",9))
	var offers := Hotel.open_blocks()
	if offers.is_empty():line(content,"✗ "+I18n.t("No group block is waiting. New offers arrive every Monday morning."),Art.C_GOLD)
	for b in offers:
		var date := Clock.date_at((int(b["start"])-1)*Clock.DAY+12*60)
		var conflict := Hotel.block_conflict(b)
		line(content,I18n.t("%s · %d %s rooms × %d nights from %s %d · group rate %s per room-night (%s off the %s rack) · total %s · 20%% deposit · Net 30")%[Hotel.cfg()["block"]["client"],int(b["rooms"]),Hotel.type_name(b["type"]),int(b["nights"]),I18n.t(Clock.MONTHS[int(date["month"])-1]),int(date["day"]),Fmt.money(float(b["rate"])),Fmt.pct(float(Hotel.cfg()["block"]["discount"])),Fmt.money(float(b["rack"])),Fmt.money0(float(b["rate"])*int(b["rooms"])*int(b["nights"]))])
		if conflict!="":line(content,"✗ "+I18n.t(conflict),Art.C_GOLD)
		else:button(content,I18n.t("Lock %d rooms for the group")%int(b["rooms"]),"AcceptBlock_"+b["id"],Hotel.accept_block.bind(b["id"]),true)
	for b in Hotel.locked_blocks():
		line(content,"✓ "+I18n.t("Locked: %d %s rooms for %d nights, %d done. The group pays at the end of the stay.")%[int(b["rooms"]),Hotel.type_name(b["type"]),int(b["nights"]),int(b["done"])],Art.C_GREEN)
	content.add_child(UIK.sep())
	content.add_child(UIK.label_tip("OTA statements","hotel_ota",9))
	var pending := Hotel.ota_pending()
	line(content,I18n.t("Unbilled OTA nights this week: gross %s, commission %s. Statements are invoiced every %d days, paid Net %d.")%[Fmt.money(float(pending["gross"])),Fmt.money(float(pending["commission"])),int(Hotel.cfg()["ota_settle_days"]),int(Hotel.cfg()["ota_terms"])],Art.C_MUTED)
	content.add_child(UIK.tip("net_terms"))
	for job in Jobs.S()["items"].values():
		if job["entity"]==Hotel.entity() and job["segment"]=="hotel" and job["status"] in ["invoiced","paid"]:
			line(content,I18n.t("%s · %s · received %s · %s")%[job["client"],I18n.t(job["scope"]),Fmt.money(float(job["receivable"])),I18n.t(str(CompanyOS.STATUS_TEXT.get(job["status"],str(job["status"]).capitalize())))],Art.C_MUTED)
	nav_button(content,"Next: guest reviews","GroupsNextReviews","reviews",true)

# ------------------------------------------------------------------ reviews
func reviews_page(content: Control) -> void:
	content.add_child(UIK.label_tip("Guest reviews","hotel_reviews",9))
	var parts := Hotel.review_parts()
	line(content,I18n.t("Overall %.1f of 5 from %d reviews in the last %d days. Cleanliness 35%%, service 35%%, value 30%%. Vera Stone's review counts five times.")%[Hotel.rating(),Hotel.review_count(),int(Hotel.cfg()["review"]["window_days"])],Art.C_SKY)
	for part in [["cleanliness","Cleanliness"],["service","Service"],["value","Value for money"]]:
		check(content,float(parts[part[0]])>=3.8,I18n.t("%s %.1f of 5")%[I18n.t(part[1]),float(parts[part[0]])])
	line(content,I18n.t("Condition of rooms %d%% · housekeeping gap %.1f rooms · walks so far %d (cost %s)")%[roundi(Hotel.avg_condition()),maxf(0,Hotel.turnover_work()-Hotel.hk_capacity()),int(Hotel.S()["stats"]["walks"]),Fmt.money0(float(Hotel.S()["stats"]["walk_cost"]))],Art.C_MUTED)
	var shown := 0
	var reviews: Array=Hotel.S()["reviews"].duplicate()
	reviews.reverse()
	for r in reviews:
		if r["kind"]=="prior":continue
		shown+=1
		if shown>8:break
		var who := "Guests"
		if r["kind"]=="vera":who="Vera Stone ×5"
		elif r["kind"]=="storm":who="Review storm"
		elif r["kind"]=="walk":who="Walked guests"
		line(content,I18n.t("Day %d · %s · %.1f of 5 · weight %d")%[int(r["day"]),I18n.t(who),float(r["score"]),int(r["w"])],Art.C_WHITE if float(r["score"])>=3.5 else Art.C_GOLD)
	var worst := ""
	for type in Hotel.TYPES:
		var r: Dictionary=Hotel.S()["rooms"][type]
		if float(r["cond"])<55 and Clock.now()>=int(r["reno_until"]) and (worst=="" or float(r["cond"])<float(Hotel.S()["rooms"][worst]["cond"])):worst=type
	if worst!="":button(content,I18n.t("Renovate %s · %s")%[Hotel.type_name(worst),Fmt.money0(Hotel.renovation_cost(worst))],"ReviewRenovate_"+worst,Hotel.renovate.bind(worst),true)
	nav_button(content,"Next: growth","ReviewsNextGrowth","growth",true)

# ------------------------------------------------------------------ growth
func growth_page(content: Control) -> void:
	content.add_child(UIK.label_tip("Growth stages","hotel_growth",9))
	line(content,I18n.t("Stage 1 · Aster Inn · %d rooms (open)")%12,Art.C_GREEN)
	for target in [2,3]:
		var c: Dictionary=Hotel.cfg()["stages"][str(target)]
		var rooms := 0
		for type in Hotel.TYPES:rooms+=int(c["add"][type])
		line(content,I18n.t("Stage %d · %s · +%d rooms · %s")%[target,I18n.t(c["name"]),rooms,Fmt.money0(Hotel.upgrade_price(target))],Art.C_SKY)
		if Hotel.stage()>=target:
			line(content,"✓ "+I18n.t("Open"),Art.C_GREEN)
			continue
		var rows := Hotel.gate(target)
		for row in rows:check(content,row[0],str(row[1]))
		var cash_ok := Ledger.cash(Hotel.entity())>=Hotel.upgrade_price(target)
		check(content,cash_ok,I18n.t("Cash %s of %s.")%[Fmt.money0(Ledger.cash(Hotel.entity())),Fmt.money0(Hotel.upgrade_price(target))])
		if target==Hotel.stage()+1 and rows.all(func(r):return r[0]) and cash_ok:button(content,I18n.t("Open %s · %s")%[I18n.t(c["name"]),Fmt.money0(Hotel.upgrade_price(target))],"Upgrade_"+str(target),Hotel.upgrade,true)
	line(content,"The group Campaign Mixer can run an internal hotel campaign at media cost; measured conversions lift real demand for a few days.",Art.C_MUTED)
	nav_button(content,"Back to the Rate Board","GrowthNextBoard","board",true)
