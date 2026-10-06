class_name PersonalDriveModal
extends Modal
var destination: String
func _init(to: String) -> void:
	destination=to
	title_text="Personal driving route"
	icon_name="metro"
	help_key="personal_assets"
	pauses_time=true
	panel_size=Vector2(400,270)
func build() -> void:
	var c: Dictionary=PersonalAssets.S()["car"]
	if c.is_empty():footer.add_child(UIK.button("Close",close,"primary"));return
	var from: String=c["location"]
	var q:=PersonalAssets.trip(from,destination,int(Clock.date()["hour"]))
	body.add_child(UIK.label(I18n.t(c["name"]),11,Art.C_GOLD))
	var img:=TextureRect.new()
	img.texture=Art.tex("city_map/aurelia_map")
	img.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.custom_minimum_size=Vector2(360,105)
	body.add_child(img)
	body.add_child(UIK.wrap(I18n.t("%s → %s · %d min driving and parking · parking %s")%[I18n.t(DataDB.districts[from]["name"]),I18n.t(DataDB.districts[destination]["name"]),int(q["minutes"]),Fmt.money(float(q["parking"]))],9,Art.C_WHITE,360))
	body.add_child(UIK.wrap(I18n.t("Metro alternative: %d min. Your car stays parked here if you cancel.")%PersonalAssets.metro_minutes(from,destination),8,Art.C_MUTED,360))
	var b:=UIK.button("Pay costs and drive",func():
		var result:=PersonalAssets.drive(destination)
		if result["ok"]:close()
		else:UIRoot.toast(result["error"],"warn","metro"),"primary")
	b.name="ConfirmPersonalDrive";footer.add_child(b)
	footer.add_child(UIK.button("Cancel",close))
