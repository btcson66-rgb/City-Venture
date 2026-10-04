class_name ContactsModal
extends Modal
var selected := ""
var notice := ""
func _init(id := "") -> void:
	title_text="Contacts";help_key="personal_life";icon_name="people";panel_size=Vector2(570,310);selected=id
func build() -> void:
	if PersonalLife.ill():
		body.add_child(UIK.wrap("Stress illness: take a recovery day or a shorter medical visit. Work is still possible; this expires within 3 days.",9,Art.C_GOLD,530))
		var row := UIK.hbox(5);body.add_child(row)
		var rest := UIK.button("Free recovery day · 480 minutes",func():_result(PersonalLife.recover(false)),"primary")
		rest.name="RecoveryRest";row.add_child(rest)
		var fee := UIK.button(I18n.t("Medical visit · %s · 90 minutes")%Fmt.money(float(PersonalLife.cfg()["medical_fee"])),func():_result(PersonalLife.recover(true)))
		fee.name="RecoveryMedical";row.add_child(fee)
	if notice!="":body.add_child(UIK.wrap(notice,8,Art.C_SKY,530))
	if selected=="":_list()
	else:_person()
	footer.add_child(UIK.button("Close",close))
func _list() -> void:
	var list := UIK.vbox(5);body.add_child(UIK.scroll(list,Vector2(535,235)))
	var activity := UIK.button("City social calendar",func():close();UIRoot.open_modal(SocialCalendarModal.new()))
	activity.name="SocialCalendar";list.add_child(activity)
	var rest := UIK.button("Take a break · 120 minutes",func():PersonalLife.rest(120,float(PersonalLife.cfg()["break_stress_relief"]));rebuild())
	rest.name="PersonalBreak";list.add_child(rest)
	for id in PersonalLife.stories():
		var c := PersonalLife.contact(id)
		var text := "%s · %s · %d / 100"%[DataDB.npc(id)["name"],PersonalLife.stage_name(id),roundi(c["affinity"])]
		var b := UIK.button(text,func():selected=id;notice="";rebuild())
		b.name="Contact_"+id;list.add_child(b)
func _person() -> void:
	var id := selected;var c := PersonalLife.contact(id)
	var v := UIK.vbox(5);body.add_child(UIK.scroll(v,Vector2(535,235)))
	v.add_child(UIK.title(str(DataDB.npc(id)["name"]),12))
	v.add_child(UIK.label(I18n.t("%s · affinity %d / 100")%[PersonalLife.stage_name(id),roundi(c["affinity"])],9))
	var prefs: Array=[]
	for gift in DataDB.npc(id)["relationship"]["preferences"]:prefs.append(I18n.t(PersonalLife.cfg()["gifts"][gift]["name"]))
	v.add_child(UIK.wrap(I18n.t("Prefers: %s")%", ".join(prefs),9,Art.C_SKY,510))
	var n := PersonalLife.next(id)
	if n["ok"]:
		var node: Dictionary=n["node"]
		v.add_child(UIK.wrap(I18n.t(node["detail"]),9,Art.C_WHITE,510))
		var b := UIK.button(I18n.t("Help · %d minutes · %s")%[int(node["minutes"]),Fmt.money(float(node["cost"]))],_request.bind(id,node,int(c["step"])),"" if PersonalLife.ill() else "primary")
		b.name="PersonalRequest";v.add_child(b)
	else:v.add_child(UIK.wrap(("✓ " if int(c["step"])>=3 and not c["retired"] else "✗ ")+I18n.t(n["reason"]),9,Art.C_WHITE,510))
	if int(c["step"])>=3 and not c["retired"]:_referral(v,id,c)
	if PersonalLife.known(id):
		var gifts := UIK.hbox(5);v.add_child(gifts)
		for gift in PersonalLife.cfg()["gifts"]:
			var item: Dictionary=PersonalLife.cfg()["gifts"][gift]
			var b := UIK.button("%s · %s"%[I18n.t(item["name"]),Fmt.money(float(item["cost"]))],func():_result(PersonalLife.gift(id,gift)))
			b.name="Gift_"+gift;gifts.add_child(b)
	var back := UIK.button("Back",func():selected="";notice="";rebuild())
	back.name="ContactsBack";footer.add_child(back)
func _request(id: String,node: Dictionary,index: int) -> void:
	if Ledger.cash("player")<float(node["cost"]):_result(PersonalLife.error("Insufficient personal cash — earn money before this request."));return
	visible=false
	MiniGames.play(PersonalRequestGame.new(node),func(result):
		visible=true
		if not result.get("aborted",false):_result(PersonalLife.request_done(id,index,float(result["score"])))
	)
func _referral(v: VBoxContainer,id: String,c: Dictionary) -> void:
	var def: Dictionary=PersonalLife.stories()[id]["referral"]
	v.add_child(UIK.wrap(I18n.t(def["detail"]),9,Art.C_SKY,510))
	v.add_child(UIK.wrap(I18n.t("Referral fee %s · supplies %s · %d minutes · payment in 30 days; the client may default.")%[Fmt.money(float(def["price"])),Fmt.money(float(def["cost"])),int(def["minutes"])],8,Art.C_WHITE,510))
	var job := Jobs.get_job(str(c["job"]))
	var style := "" if PersonalLife.ill() else "primary"
	if job.is_empty():
		var b := UIK.button("Review the referred job",func():_result(PersonalLife.referral(id)),style)
		b.name="ReferralReview";v.add_child(b)
	elif job["status"]=="offered":
		var b := UIK.button("Accept the referred job",func():_result(Jobs.accept(str(job["id"]))),style)
		b.name="ReferralAccept";v.add_child(b)
		var decline := UIK.button("Decline referral",func():job["status"]="declined";rebuild())
		decline.name="ReferralDecline";v.add_child(decline)
	elif job["status"]=="active":
		var b := UIK.button("Do the referred work",func():
			visible=false
			MiniGames.play(PersonalRequestGame.new(PersonalLife.stories()[id]["steps"][2]),func(result):
				visible=true
				if not result.get("aborted",false):_result(PersonalLife.referral_work(id,float(result["score"])))
			),style)
		b.name="ReferralWork";v.add_child(b)
	else:v.add_child(UIK.wrap("✓ "+I18n.t("Referral resolved — check the job's invoice or payment in Finance."),8,Art.C_WHITE,510))
func _result(result: Dictionary) -> void:
	notice=I18n.t("Request recorded — check the next step.") if result.get("ok",false) else str(result.get("error",I18n.t("This request is no longer available — check Contacts.")))
	rebuild()
