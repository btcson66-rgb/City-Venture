class_name PersonalLife
extends RefCounted
## Personal opportunities are earned work, never passive industry multipliers.
static var _stories := {}
static var _sleeping := false
static var _resting := false
static func cfg() -> Dictionary:return DataDB.economy["personal_life"]
static func stories() -> Dictionary:
	if _stories.is_empty():
		for file in DirAccess.get_files_at("res://data/story/personal"):
			if file.ends_with(".json"):
				var d: Dictionary=DataDB._read("res://data/story/personal/"+file)
				_stories[d["npc"]]=d
	return _stories
static func S() -> Dictionary:
	if not GameState.data.has("personal_life"):
		GameState.data["personal_life"]={"energy":100.0,"stress":0.0,"work_minutes":0,"contacts":{},"events":{},"illness_until":0,"cooldown_until":0}
	return GameState.data["personal_life"]
static func contact(id: String) -> Dictionary:
	if not S()["contacts"].has(id):S()["contacts"][id]={"affinity":0.0,"known":id=="maya","step":0,"entity":"","retired":false,"gift_day":-1,"job":"","honesty":{},"kinds":{}}
	return S()["contacts"][id]
static func meet(id: String) -> void:
	if DataDB.npc(id).has("relationship"):contact(id)["known"]=true
static func known(id: String) -> bool:return bool(contact(id)["known"]) or GameState.flag("met_"+id)
static func change(id: String,amount: float) -> void:
	if DataDB.npc(id).has("relationship") and is_finite(amount):contact(id)["affinity"]=clampf(float(contact(id)["affinity"])+amount,0,100)
static func stage(id: String) -> int:
	var value := float(contact(id)["affinity"])
	var thresholds: Array=DataDB.npc(id).get("relationship",{}).get("stages",[0,cfg()["friend"],cfg()["partner"]])
	return 2 if value>=float(thresholds[2]) else (1 if value>=float(thresholds[1]) else 0)
static func stage_name(id: String) -> String:return I18n.t(["Acquaintance","Friend","Trusted contact"][stage(id)])
## Partners are earned through variety: favours alone never reach the top stage.
static func note_kind(id: String,kind: String) -> void:
	if DataDB.npc(id).has("relationship"):contact(id).get_or_add("kinds",{})[kind]=Clock.now()
static func has_variety(id: String) -> bool:return contact(id).get("kinds",{}).size()>=int(cfg()["variety_kinds"])
static func approaches() -> Dictionary:return cfg()["approaches"]
## Cost and time of a request approach: every approach trades time, money and trust differently.
static func approach_terms(node: Dictionary,approach: String) -> Dictionary:
	var a: Dictionary=approaches().get(approach,approaches()["thorough"])
	return {"minutes":maxi(5,roundi(float(node["minutes"])*float(a["minutes"]))),"cost":float(node["cost"])*float(a["cost"])+float(a["extra_cost"]),"affinity":float(cfg()["request_affinity"])*float(a["affinity"])}
static func valid_entity(entity: String) -> bool:return GameState.data["entities"].has(entity) and not GameState.data["entities"][entity].has("closed")
static func next(id: String) -> Dictionary:
	var c := contact(id)
	if not stories().has(id):return {"ok":false,"reason":"No personal request — attend a city event."}
	if c["retired"] or (c["entity"]!="" and not valid_entity(str(c["entity"]))):return {"ok":false,"reason":"This business closed — the personal chain is retired."}
	if int(c["step"])>=3:return {"ok":false,"reason":"Already completed — review the referral."}
	if not known(id):return {"ok":false,"reason":"Meet this person in town or at a city event first."}
	var node: Dictionary=stories()[id]["steps"][int(c["step"])]
	if stage(id)<int(node["stage"]):return {"ok":false,"reason":"Attend events or offer a preferred gift to reach the next relationship stage."}
	if int(node["stage"])>=2 and not has_variety(id):return {"ok":false,"reason":"Trust needs more than favours — attend a city event, offer a gift or complete a deal with them first."}
	return {"ok":true,"node":node}
static func request_done(id: String,index: int,quality: float,approach := "thorough") -> Dictionary:
	var n := next(id)
	if not n["ok"] or int(contact(id)["step"])!=index or not is_finite(quality) or quality<0 or quality>1:return error("This request is no longer available — check Contacts.")
	var node: Dictionary=n["node"]
	var terms := approach_terms(node,approach)
	var cost := float(terms["cost"])
	if Ledger.cash("player")<cost:return error("Insufficient personal cash — earn money before this request.")
	var c := contact(id)
	if c["entity"]=="":c["entity"]=GameState.business_entity()
	if cost>0:Ledger.expense("player","dining",cost,I18n.t("Personal request supplies: %s")%Fmt.money(cost),{"type":"personal_request","npc":id})
	work(int(terms["minutes"]))
	Clock.advance(int(terms["minutes"]))
	# Hourly processing can close the originating business during the work.
	if not valid_entity(str(c["entity"])):c["retired"]=true;return error("This business closed — the personal chain is retired.")
	if quality<float(cfg()["request_quality"]):return error("Review the evidence and try again. The time and supplies were used.")
	c["step"]=index+1
	change(id,float(terms["affinity"]))
	return {"ok":true}
static func gift(id: String,item: String) -> Dictionary:
	if not known(id) or not DataDB.npc(id).has("relationship") or not cfg()["gifts"].has(item):return error("Meet this person before offering a gift.")
	var c := contact(id)
	if int(c["gift_day"])==Clock.day_index():return error("Already offered a gift today — return tomorrow.")
	var cost := float(cfg()["gifts"][item]["cost"])
	if Ledger.cash("player")<cost:return error("Insufficient personal cash — earn money before this request.")
	Ledger.expense("player","dining",cost,I18n.t("Personal gift: %s")%Fmt.money(cost),{"type":"personal_gift","npc":id})
	c["gift_day"]=Clock.day_index()
	note_kind(id,"gift")
	change(id,float(cfg()["preferred_gift_affinity"]) if item in DataDB.npc(id)["relationship"]["preferences"] else float(cfg()["other_gift_affinity"]))
	Clock.advance(int(cfg()["gift_minutes"]))
	return {"ok":true}
static func event_key(id: String) -> String:
	var d := Clock.date_at(Clock.now())
	return "%d-%d:%s"%[d["year"],d["month"],id]
static func event_available(event: Dictionary) -> bool:
	var d := Clock.date_at(Clock.now())
	return int(d["day"])==int(event["day"]) and Clock.hour()>=int(event["hour"]) and Clock.hour()<int(event["end_hour"]) and not S()["events"].has(event_key(event["id"]))
static func attend(id: String) -> Dictionary:
	var event: Dictionary=cfg()["events"].get(id,{})
	if event.is_empty() or not event_available(event):return error("This monthly event is closed or already attended — check its next date.")
	var cost := float(event["cost"])
	if Ledger.cash("player")<cost:return error("Insufficient personal cash — earn money before this request.")
	Ledger.expense("player","dining",cost,I18n.t("City social event: %s")%Fmt.money(cost),{"type":"personal_social","id":id})
	S()["events"][event_key(id)]=Clock.now()
	for npc in event["npcs"]:meet(npc);change(npc,float(cfg()["event_affinity"]));note_kind(npc,"event")
	rest(int(event["minutes"]),float(cfg()["social_stress_relief"]))
	# Keep at most one year of receipts; lifetime contacts and affinity remain saved.
	for key in S()["events"].keys():
		if Clock.now()-int(S()["events"][key])>366*Clock.DAY:S()["events"].erase(key)
	return {"ok":true,"info":event["detail"]}
static func energy() -> float:return float(S()["energy"])
static func fatigue() -> float:return clampf((float(cfg()["low_energy"])-energy())/float(cfg()["low_energy"]),0,1)
static func response_speed() -> float:return 1.0+fatigue()*float(cfg()["fatigue_timer_multiplier"])
static func movement(pixels: float) -> void:
	if is_finite(pixels) and pixels>0:S()["energy"]=maxf(0,energy()-pixels*float(cfg()["energy_per_pixel"]))
static func work(minutes: int) -> void:
	if minutes<=0:return
	S()["energy"]=maxf(0,energy()-minutes*float(cfg()["energy_per_work_minute"]))
	S()["work_minutes"]=int(S()["work_minutes"])+minutes
	S()["stress"]=minf(100,float(S()["stress"])+minutes*float(cfg()["work_stress_per_minute"])*(2 if int(S()["work_minutes"])>int(cfg()["continuous_work_minutes"]) else 1))
static func rest(minutes: int,relief: float) -> void:
	_resting=true
	Clock.advance(minutes)
	_resting=false
	S()["work_minutes"]=0
	S()["energy"]=minf(100,energy()+minutes*float(cfg()["rest_energy_per_minute"]))
	S()["stress"]=maxf(0,float(S()["stress"])-relief)
static func sleep_begin() -> void:_sleeping=true
static func sleep_end(minutes: int) -> void:
	_sleeping=false
	S()["energy"]=minf(100,energy()+maxi(0,minutes)*float(cfg()["sleep_energy_per_minute"]))
	S()["stress"]=maxf(0,float(S()["stress"])-float(cfg()["sleep_stress_relief"]))
	S()["work_minutes"]=0
static func ill() -> bool:return Clock.now()<int(S()["illness_until"])
static func recover(medical: bool) -> Dictionary:
	if not ill():return error("Already recovered — return to your plans.")
	var cost := float(cfg()["medical_fee"]) if medical else 0.0
	if Ledger.cash("player")<cost:return error("Insufficient personal cash — take a free recovery day.")
	if cost>0:Ledger.expense("player","living",cost,I18n.t("Recovery consultation: %s")%Fmt.money(cost),{"type":"personal_health"})
	rest(int(cfg()["medical_minutes"] if medical else cfg()["recovery_minutes"]),float(cfg()["recovery_stress_relief"]))
	S()["illness_until"]=0
	return {"ok":true}
static func on_hour(t: int,h: int) -> void:
	if not GameState.data.has("personal_life"):return
	# Daily debt and crisis stress is processed even while sleeping or resting; only the hour-by-hour recovery checks wait.
	if h==20 and S().get("stress_day",-1)!=Clock.day_index():
		S()["stress_day"]=Clock.day_index()
		var debt := Bank.debt(GameState.business_entity())
		var crises := not EventEngine.pending().is_empty()
		S()["stress"]=clampf(float(S()["stress"])+(float(cfg()["debt_daily_stress"]) if debt>0 else 0)+(float(cfg()["crisis_daily_stress"]) if crises else 0)-(0.0 if _sleeping or _resting else float(cfg()["daily_stress_decay"])),0,100)
	if _sleeping or _resting:return
	if int(S()["illness_until"])>0 and t>=int(S()["illness_until"]):S()["illness_until"]=0;S()["stress"]=minf(float(S()["stress"]),float(cfg()["recovered_stress"]))
	if float(S()["stress"])>=float(cfg()["illness_threshold"]) and not ill() and t>=int(S()["cooldown_until"]):
		S()["illness_until"]=t+int(cfg()["illness_days"])*Clock.DAY
		S()["cooldown_until"]=t+int(cfg()["illness_cooldown_days"])*Clock.DAY
		EventBus.notify.emit("Stress illness — open Contacts to choose free rest or a shorter medical visit. Recovery also occurs within 3 days.","warn","people")
static func on_ledger(entry: Dictionary) -> void:
	var source: Dictionary=entry["source"]
	var id := str(source.get("npc",source.get("supplier",source.get("buyer",source.get("client","")))))
	var late := bool(source.get("late",false))
	if source.get("type","") in ["po","ap"]:
		var po: Dictionary=Ecommerce.E()["purchase_orders"].get(str(source.get("id","")),{})
		id=str(DataDB.supplier(str(po.get("supplier",""))).get("contact_npc",""))
		late=Clock.now()>int(po.get("pay_due",Clock.now()))
	if id=="" and source.get("type","")=="job":id=str(Jobs.get_job(str(source.get("id",""))).get("personal_npc",""))
	if not DataDB.npc(id).has("relationship"):return
	var cash_out := false
	var real_purchase := false
	var real_revenue := false
	for line in entry["lines"]:
		if line["acct"]=="cash" and float(line.get("cr",0))>0:cash_out=true
		if line["acct"] in ["inventory_in_transit","accounts_payable","inventory"] and float(line.get("dr",0))>0:real_purchase=true
		if line["acct"]=="revenue" and float(line.get("cr",0))>0:real_revenue=true
	if source.get("type","") in ["personal_gift","personal_request","personal_social"]:return
	var key := "%s:%s"%[source.get("type",""),source.get("id",entry["n"])]
	var c := contact(id)
	if c["honesty"].has(key):return
	if cash_out and real_purchase:
		change(id,-float(cfg()["honesty_affinity"]) if late else float(cfg()["honesty_affinity"]))
		note_kind(id,"deal");c["honesty"][key]=Clock.now()
	elif real_revenue and source.get("type","")=="job":
		var job := Jobs.get_job(str(source.get("id","")))
		if job.get("status","") in ["delivered","invoiced"]:
			change(id,float(cfg()["honesty_affinity"]) if int(job["delivered"])<=int(job["due"]) else -float(cfg()["honesty_affinity"]))
			note_kind(id,"deal");c["honesty"][key]=Clock.now()
	for old in c["honesty"].keys():
		if Clock.now()-int(c["honesty"][old])>90*Clock.DAY:c["honesty"].erase(old)
static func referral(id: String) -> Dictionary:
	var c := contact(id)
	if int(c["step"])<3 or c["retired"] or not valid_entity(str(c["entity"])):return error("Complete this personal chain before reviewing its referral.")
	if c["job"]!="":return {"ok":true,"id":c["job"]}
	var def: Dictionary=stories()[id]["referral"]
	c["job"]=Jobs.offer({"entity":c["entity"],"client":def["client"],"scope":I18n.t(def["detail"]),"price":def["price"],"work":def["minutes"],"segment":"consulting","terms":30,"deposit":0,"penalty_rate":.15,"due":Clock.now()+7*Clock.DAY,"personal_npc":id,"personal_cost":def["cost"]})
	return {"ok":c["job"]!="","id":c["job"]}
static func referral_work(id: String,quality: float) -> Dictionary:
	var c := contact(id);var job := Jobs.get_job(str(c["job"]))
	if job.is_empty() or c["retired"] or not valid_entity(str(job.get("entity",""))) or job["status"]!="active" or not is_finite(quality) or quality<0 or quality>1:return error("This job is no longer active — check its status.")
	var cost := float(job["personal_cost"])
	if Ledger.cash(str(job["entity"]))<cost:return error("Fund the referral's supplies before working.")
	Ledger.expense(str(job["entity"]),"other",cost,I18n.t("Referral work supplies: %s")%Fmt.money(cost),{"type":"personal_job","id":job["id"],"segment":"consulting"})
	var minutes := int(job["work"])
	work(minutes);Clock.advance(minutes)
	if quality<float(cfg()["request_quality"]):return error("Review the evidence and try again. The time and supplies were used.")
	var result := Jobs.progress(str(job["id"]),minutes)
	if not result["ok"]:return result
	Jobs.deliver(str(job["id"]))
	return Jobs.invoice(str(job["id"]))
static func on_company_closed(entity: String) -> void:
	if not GameState.data.has("personal_life"):return
	for c in S()["contacts"].values():
		if c["entity"]==entity:c["retired"]=true
static func error(text: String) -> Dictionary:return {"ok":false,"error":I18n.t(text)}
static func is_running() -> bool:return false
static func segment_tag() -> String:return "shared"
static func os_tab() -> Dictionary:return {}
static func board_detail() -> Callable:return func(_a,_b):pass
static func handle(_kind: String,_payload: Dictionary) -> void:pass
