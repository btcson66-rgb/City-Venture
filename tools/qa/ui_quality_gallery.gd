extends SceneTree
var out := ""
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	out = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	await process_frame
	var ui = load("res://scripts/ui/uik.gd")
	var router = root.get_node("SceneRouter")
	root.get_node("Clock").world_active = false
	root.get_node("UIRoot").set_hud_visible(false)
	var canvas := Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.theme = ui.theme()
	router._set_scene(canvas)
	var bg := ColorRect.new()
	bg.color = Color("102035")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)
	var surfaces := ["panel","panel_glass","button","button_hover","button_pressed","button_disabled","button_primary","button_primary_hover","button_danger","tab","tab_active","card","card_gold","field","header","inset","tooltip","prompt_key","bar_bg","bar_fill","bar_fill_green"]
	for i in surfaces.size():
		var item := Panel.new()
		item.position = Vector2(8+(i%5)*125,10+(i/5)*65)
		item.size = Vector2(116,50)
		var margin := 3 if surfaces[i].begins_with("bar_") else 4
		item.add_theme_stylebox_override("panel",ui.tex_box("ui/"+surfaces[i],margin,5))
		canvas.add_child(item)
		var label := Label.new()
		label.text = surfaces[i]
		label.position = Vector2(6,18)
		label.add_theme_font_size_override("font_size",8)
		if surfaces[i] in ["tooltip","prompt_key"]:label.add_theme_color_override("font_color",Color("102035"))
		item.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/actual_surface_states.png")
	print("ui_quality_gallery: 21 actual native stylebox states")
	quit()
