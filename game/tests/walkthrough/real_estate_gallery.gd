extends Node
var out := ""
func _ready() -> void:call_deferred("run")
func capture(name: String) -> void:
	await get_tree().create_timer(1.5).timeout
	for toast in UIRoot.toast_box.get_children():toast.hide()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_jpg(out+"/"+name+".jpg",.85)
func clear_overlays() -> void:
	UIRoot._pending_reports.clear()
	for overlay in UIRoot.modal_layer.get_children():
		if overlay is Modal:overlay.close()
	await get_tree().process_frame
func modal_capture(page: String,name: String) -> void:
	var modal := RealEstateUI.new()
	modal.page=page
	UIRoot.open_modal(modal)
	await get_tree().create_timer(.2).timeout
	if UIRoot.top_modal()!=modal:UIRoot.top_modal().close()
	await capture(name)
	modal.close()
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	I18n.init()
	I18n.set_locale("zh_TW")
	GameState.new_game({"name":"住宅驗收","seed":65001})
	UIRoot._suppress_decisions=true
	Help.auto=false
	GameState.data["tutorial"]={"off":true,"seen":{},"step":99,"v":99}
	Company.register("住宅驗收","real_estate","Harlow")
	Company.open_business_account(25000)
	Ledger.post(GameState.company_id(),"QA development equity",[{"acct":"cash","dr":2500000},{"acct":"equity","cr":2500000}])
	await modal_capture("matches","brokerage_prerequisites")
	Compliance.apply_permit("brokerage")
	Clock.advance(3*Clock.DAY)
	Living.lease("realty_office")
	RealEstate.start()
	await clear_overlays()
	await modal_capture("permits","property_permits")
	var company_os := CompanyOS.new("home_laptop")
	company_os.tab="real_estate"
	UIRoot.open_modal(company_os)
	await capture("company_os_real_estate")
	company_os.close()
	Clock.advance_to(Clock.next_time_of_day(10*60))
	for building in ["maple_court","birch_row","harlow_finch","lot7"]:
		SceneRouter._enter("interior",building,"door","")
		Clock.world_active=false
		await capture(building)
	SceneRouter._enter("district","residential","metro","",Vector2(640,352))
	Clock.world_active=false
	await capture("residential_day")
	await modal_capture("matches","matchmaker")
	RealEstate.buy("maple_1",.2,25)
	await modal_capture("properties","properties")
	RealEstate.renovate("maple_1","modern")
	await modal_capture("properties","renovation")
	Compliance.apply_permit("building")
	Clock.advance(7*Clock.DAY)
	await modal_capture("development","development_options")
	RealEstate.develop("small","創業大樓")
	await modal_capture("development","development_progress")
	SceneRouter._enter("district","residential","metro","",Vector2(1340,352))
	Clock.world_active=false
	await capture("lot7_construction")
	Clock.advance_to(int(RealEstate.S()["project"]["due"])+Clock.DAY)
	await get_tree().create_timer(.2).timeout
	await clear_overlays()
	SceneRouter._enter("district","residential","metro","",Vector2(1340,352))
	Clock.world_active=false
	await capture("completed_tower")
	var map := CityMapModal.new(false)
	map.sel="residential"
	UIRoot.open_modal(map)
	await get_tree().create_timer(.2).timeout
	if UIRoot.top_modal()!=map:UIRoot.top_modal().close()
	await capture("completed_tower_map")
	map.close()
	await modal_capture("development","development_completed")
	await modal_capture("properties","completed_building_portfolio")
	Clock.advance_to(Clock.next_time_of_day(21*60))
	await clear_overlays()
	SceneRouter._enter("district","residential","metro","",Vector2(640,352))
	Clock.world_active=false
	await capture("residential_night")
	print("REAL ESTATE GALLERY: 19 JPG")
	get_tree().quit()
