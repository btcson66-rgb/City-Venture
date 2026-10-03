extends Node
## Evidence screenshots for #67: district, three interiors, closed view and every Rate Board page (zh_TW).
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
func modal_capture(page: String,name: String) -> void:
	var modal := HotelUI.new()
	modal.page=page
	UIRoot.open_modal(modal)
	await capture(name)
	modal.close()
func recruit(role: String) -> void:
	Staff.post_job(role)
	Clock.advance(18*60)
	Staff.hire(Staff.S()["applicants"][0]["id"])
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):out=arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	I18n.init()
	I18n.set_locale("zh_TW")
	GameState.new_game({"name":"旅館驗收","seed":67001})
	UIRoot._suppress_decisions=true
	Help.auto=false
	GameState.data["tutorial"]={"off":true,"seen":{},"step":99,"v":99}
	Company.register("旅館驗收","hotel","The Aster")
	Company.open_business_account(25000)
	Ledger.post(GameState.company_id(),"QA hotel equity",[{"acct":"cash","dr":400000},{"acct":"equity","cr":400000}])
	await modal_capture("board","hotel_prerequisites")
	GameState.mark_visited("the_aster")
	await modal_capture("board","hotel_open_choice")
	Hotel.start("own")
	Clock.advance_to(Clock.next_time_of_day(10*60))
	await clear_overlays()
	for building in ["the_aster","skyline_grand","observation_deck"]:
		SceneRouter._enter("interior",building,"door","")
		Clock.world_active=false
		await capture(building)
	SceneRouter._enter("district","luxury_heights","metro","",Vector2(190,352))
	Clock.world_active=false
	await capture("luxury_heights_aster_facade")
	SceneRouter._enter("district","luxury_heights","metro","",Vector2(560,352))
	Clock.world_active=false
	await capture("luxury_heights_skyline_facade")
	SceneRouter._enter("district","luxury_heights","metro","",Vector2(1000,352))
	Clock.world_active=false
	await capture("luxury_heights_day")
	Clock.advance_to(Clock.next_time_of_day(21*60))
	await clear_overlays()
	await capture("luxury_heights_night")
	await modal_capture("board","rate_board")
	await modal_capture("ops","daily_operations")
	Staff.register_employer()
	recruit("housekeeper")
	recruit("housekeeper")
	recruit("front_desk")
	Hotel.set_peak(.2)
	Clock.advance(24*Clock.DAY)
	await clear_overlays()
	await modal_capture("board","rate_board_after_24_days")
	await modal_capture("ops","daily_operations_staffed")
	await modal_capture("groups","groups_and_ota")
	await modal_capture("reviews","guest_reviews")
	await modal_capture("growth","growth_stages")
	var os := CompanyOS.new("home_laptop")
	os.tab="hotel"
	UIRoot.open_modal(os)
	await capture("company_os_hotel")
	os.close()
	print("HOTEL GALLERY balanced: "+str(Ledger.check_balanced()))
	get_tree().quit()
