extends Node
var out := ""
func _ready() -> void:call_deferred("run")
func capture(name: String) -> void:
	await get_tree().create_timer(1.0).timeout
	for toast in UIRoot.toast_box.get_children():toast.hide()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out+"/"+name+".jpg",.85)
func clear_overlays() -> void:
	UIRoot._pending_reports.clear()
	for overlay in UIRoot.modal_layer.get_children():
		if overlay is Modal:overlay.close()
	await get_tree().process_frame
func modal_capture(page: String,name: String,selected := "") -> void:
	var modal := MediaUI.new()
	modal.page=page
	modal.selected=selected
	UIRoot.open_modal(modal)
	await capture(name)
	modal.close()
func recruit(role: String) -> void:
	Staff.post_job(role)
	Clock.advance(18*60)
	Staff.hire(Staff.S()["applicants"][0]["id"])
func win() -> String:
	for week in 12:
		for brief in Media.S()["briefs"].values().duplicate():
			if brief["status"]!="open":continue
			Media.prepare(brief["id"],1)
			if Media.propose(brief["id"]).get("won",false):return brief["id"]
		Clock.advance(7*Clock.DAY)
	return ""
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	I18n.init()
	I18n.set_locale("zh_TW")
	GameState.new_game({"name":"媒體驗收","seed":66001})
	UIRoot._suppress_decisions=true
	Help.auto=false
	GameState.data["tutorial"]={"off":true,"seen":{},"step":99,"v":99}
	Company.register("媒體驗收","media","The Loft")
	Company.open_business_account(25000)
	Ledger.post(GameState.company_id(),"QA media equity",[{"acct":"cash","dr":175000},{"acct":"equity","cr":175000}])
	await modal_capture("briefs","agency_prerequisites")
	Living.lease("loft_office")
	Media.start()
	Staff.register_employer()
	Clock.advance_to(Clock.next_time_of_day(10*60))
	await clear_overlays()
	for building in ["aurelia_university","the_loft","campus_radio"]:
		SceneRouter._enter("interior",building,"door","")
		Clock.world_active=false
		await capture(building)
	SceneRouter._enter("district","university","metro","",Vector2(190,352))
	Clock.world_active=false
	await capture("university_campus_facade")
	SceneRouter._enter("district","university","metro","",Vector2(1090,352))
	Clock.world_active=false
	await capture("campus_radio_facade")
	SceneRouter._enter("district","university","metro","",Vector2(640,352))
	Clock.world_active=false
	await capture("university_day")
	Clock.advance_to(Clock.next_time_of_day(21*60))
	await clear_overlays()
	await capture("university_night")
	await modal_capture("briefs","client_briefs")
	var brief: Dictionary=Media.S()["briefs"].values().filter(func(b):return b["status"]=="open")[0]
	var creative := CreativePitch.new(brief)
	UIRoot.open_modal(creative)
	await capture("creative_intro")
	creative.start()
	await capture("creative_cards")
	for i in 3:creative.choose(int(brief["preferences"][i]))
	await capture("creative_result")
	creative.close()
	var id := win()
	await clear_overlays()
	await modal_capture("mixer","campaign_mixer",id)
	Clock.advance(Clock.DAY)
	await clear_overlays()
	await modal_capture("mixer","daily_metrics",id)
	Clock.advance(int(Media.cfg()["campaign_days"])*Clock.DAY)
	await clear_overlays()
	await modal_capture("reports","campaign_reports")
	recruit("media_designer")
	recruit("media_buyer")
	id=win()
	Clock.advance(int(Media.cfg()["campaign_days"])*Clock.DAY)
	await clear_overlays()
	await modal_capture("radio","acquire_owned_media")
	Media.buy_radio()
	await modal_capture("radio","owned_media_inventory")
	Living.lease("corner_cafe")
	await modal_capture("group","group_campaigns")
	var os := CompanyOS.new("home_laptop")
	os.tab="media"
	UIRoot.open_modal(os)
	await capture("company_os_media")
	os.close()
	print("MEDIA GALLERY balanced: "+str(Ledger.check_balanced()))
	get_tree().quit()
