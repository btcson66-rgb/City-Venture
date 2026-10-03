extends SceneTree
var out := ""
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out=arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	load("res://scripts/ui/i18n.gd").init()
	load("res://scripts/ui/i18n.gd").set_locale("zh_TW")
	var state = root.get_node("GameState")
	state.new_game({"name":"報表驗收", "seed":63001})
	var company = load("res://scripts/sim/company.gd")
	company.register("報表驗收", "ecommerce", "22 Founders Lane")
	company.open_business_account(20000)
	var entity: String = state.company_id()
	var clock = root.get_node("Clock")
	clock.world_active = false
	var ledger = load("res://scripts/sim/ledger.gd")
	ledger.post(entity,"QA revenue",[{"acct":"cash","dr":1200},{"acct":"revenue","cr":1200}],{"segment":"ecommerce"})
	ledger.post(entity,"QA revenue",[{"acct":"cash","dr":600},{"acct":"revenue","cr":600}],{"segment":"cafe"})
	ledger.expense(entity,"rent_office",300,"QA shared rent",{"segment":"shared"})
	var os = load("res://scripts/ui/modals/company_os.gd").new("home_laptop")
	os.tab="segments"
	root.get_node("UIRoot").open_modal(os)
	await create_timer(.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out+"/segments_top.jpg",.85)
	var scroll: ScrollContainer = os.content.get_parent()
	scroll.scroll_vertical=330
	await create_timer(.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out+"/segments_allocated.jpg",.85)
	scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
	await create_timer(.2).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_jpg(out+"/segments_last_month.jpg",.85)
	var audit = load("res://tests/walkthrough/bot.gd").new()
	audit._audit_setup()
	for ctl in os.find_children("*", "Control", true, false):
		if ctl is Label:
			audit._audit_one(ctl.atr(ctl.text), ctl)
	var f:=FileAccess.open(out+"/english_audit.json",FileAccess.WRITE)
	f.store_string(JSON.stringify(audit.audit,"\t"))
	print("SEGMENTS GALLERY: 3 JPG; %d English audit flags" % audit.audit.size())
	var clean: bool = audit.audit.is_empty()
	audit.free()
	quit(0 if clean else 1)
