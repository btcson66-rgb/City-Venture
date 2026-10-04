class_name IndustryGuidance
extends RefCounted
## Saved optional guides share the first-venture tutorial state and condition DSL.
static func definitions() -> Dictionary:return DataDB.story.get("side_stories",{})
static func guide(id: String) -> Dictionary:return definitions().get("intro_"+id,{})
## Guide progress rides in the shared tutorial record once the tutorial has initialised itself; before that it waits in its own
## record so this module never writes the tutorial's on/off state first.
static func progress(id: String) -> Dictionary:
	var holder: Dictionary
	if GameState.data.has("tutorial") and not GameState.data["tutorial"].is_empty():
		holder=GameState.data["tutorial"]
		if not holder.has("industries"):holder["industries"]={}
		var waiting: Dictionary=GameState.data.get("industry_guides",{})
		for k in waiting:
			if not holder["industries"].has(k):holder["industries"][k]=waiting[k]
		GameState.data.erase("industry_guides")
	else:
		if not GameState.data.has("industry_guides"):GameState.data["industry_guides"]={}
		holder={"industries":GameState.data["industry_guides"]}
	var key:=GameState.company_id()+":"+id
	if not holder["industries"].has(key):holder["industries"][key]={"step":0,"seen":false,"skipped":false,"company":GameState.company_id()}
	return holder["industries"][key]
static func open_first(id: String) -> void:
	if guide(id).is_empty() or GameState.company_id()=="":return
	var p:=progress(id)
	skip_completed(id)
	if p["skipped"] or (p["seen"] and int(p.get("shown",0))==int(p["step"])):return
	p["seen"]=true;p["shown"]=p["step"]
	UIRoot.open_modal(IndustryGuideModal.new(id))
static func skip_completed(id: String) -> void:
	var p:=progress(id);var d:=guide(id)
	if d.is_empty():return
	if GameState.data["entities"].get(p["company"],{}).has("closed"):p["skipped"]=true;return
	while int(p["step"])<d["objectives"].size() and Cond.all(d["objectives"][p["step"]]["complete_when"]):p["step"]=int(p["step"])+1
static func decline(id: String) -> void:
	GameState.set_flag("side_"+id+"_declined");StoryEngine.check()
static func mentor_pin(id: String) -> void:
	var d:=guide(id)
	if d.is_empty():return
	var map:=CityMapModal.new(false)
	map.sel=str(DataDB.buildings.get(d["building"],{}).get("district",""))
	map.title_text=I18n.t(str(DataDB.npcs.get(d["mentor"],{}).get("name",d["mentor"])))+" · "+I18n.t(str(DataDB.buildings.get(d["building"],{}).get("name",d["building"])))
	UIRoot.open_modal(map)
static func check() -> void:
	for id in definitions():
		var d: Dictionary=definitions()[id];var p: Dictionary=StoryEngine.side_progress().get(id,{})
		if p.get("status","")!="active":continue
		# Flags and industry state belong to the selected company; defer other owners.
		if str(p.get("company",""))!=GameState.company_id():continue
		if not p.has("started"):p["started"]=Clock.now()
		if Clock.now()-int(p["started"])>90*Clock.DAY:decline(str(d["business"]));continue
		# Scripted opportunities use actual industry events, never fabricated ledger income.
		var business: String=d["business"]
		var event: String=d.get("guided_event","")
		if event=="" or str(p.get("company",""))!=GameState.company_id():continue
		var ready:=false
		if business=="manufacturing":ready=Manufacturing.valid() and not recovery_order().is_empty()
		if business=="media":ready=not Media.running().is_empty()
		if business=="hotel":ready=Hotel.is_running() and int(Hotel.S()["completed_blocks"])>=1
		if business=="automotive":ready=Automotive.is_running() and not Automotive._flood_car().is_empty()
		if ready and not EventEngine.S()["history"].any(func(e):return e["id"]==event) and not EventEngine._queued(event):
			if not p.get("guided_event_sent",false):p["guided_event_sent"]=true;EventEngine.trigger(event)
static func recovery_order() -> Dictionary:
	for order in Manufacturing.S()["orders"].values():
		if order["status"]=="active" and float(order["escaped"])>0 and int(order["produced"])<int(order["qty"]):return order
	return {}
static func recovery_plan(outsource: bool) -> Dictionary:
	if not Manufacturing.valid():return {"ok":false,"error":"Open the factory before planning recovery."}
	if Manufacturing.S()["slots"].any(func(s):return s.get("story_recovery",false)):return {"ok":false,"error":"Recovery is already planned. Finish the real order."}
	var order:=recovery_order()
	if order.is_empty():return {"ok":false,"error":"There is no unfinished defective batch. Continue with the next order."}
	var machines: Array=[""] if outsource else Manufacturing.S()["machines"]
	var first: int=int(ceil(Clock.now()/60.0))*60
	for offset in range(7*24):
		var start: int=first+offset*60
		if not outsource and start%Clock.DAY<18*60:continue
		for machine in machines:
			var result:=Manufacturing.plan(str(order["job"]),str(machine),start,2,not outsource,outsource)
			if result["ok"]:
				for slot in Manufacturing.S()["slots"]:
					if slot["id"]==result["id"]:slot["story_recovery"]=true
				return result
	return {"ok":false,"error":"No recovery slot fits this week. Free a machine or choose outsourcing."}
