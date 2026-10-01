extends SceneTree
## Real PortraitView and CharacterRig renders for every option; QA labels only.
var out := "D:/City-Venture-character-quality/evidence/20261001_character_customization/after"
var db: Node
var state: Node
var router: Node
var pages := 0
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	await process_frame
	db = root.get_node("DataDB")
	state = root.get_node("GameState")
	router = root.get_node("SceneRouter")
	root.get_node("Clock").world_active = false
	root.get_node("UIRoot").set_hud_visible(false)
	for pair in [["presentations", "presentation"], ["face_shapes", "face"], ["hairstyles", "hair"], ["hair_colors", "hair_color"], ["eye_shapes", "eye_shape"], ["eye_colors", "eye_color"], ["eyebrows", "brows"], ["mouths", "mouth"], ["accessories", "accessory"], ["outfits", "outfit"], ["outfits_shop", "outfit"]]:
		var entries: Array = []
		for option in db.character[pair[0]]:
			var app: Dictionary = state.default_appearance()
			var outfit := "startup_casual"
			if pair[1] == "outfit":
				outfit = option["id"]
			else:
				app[pair[1]] = option["id"]
			entries.append({"app": app, "outfit": outfit, "label": option["id"], "expression": "neutral", "pose": ""})
		await page(pair[0], entries)
	for pr in db.character["presentations"]:
		var entries: Array = []
		for skin in db.character["skin_tones"]:
			var app: Dictionary = state.default_appearance()
			app.merge({"presentation": pr["id"], "skin": skin["id"]}, true)
			entries.append({"app": app, "outfit": "startup_casual", "label": pr["id"] + " " + skin["id"], "expression": "neutral", "pose": ""})
		await page("skins_" + pr["id"], entries)
	for skin in ["s1", "s3", "s6"]:
		var entries: Array = []
		for expression in ["neutral", "happy", "thinking", "surprised"]:
			var app: Dictionary = state.default_appearance()
			app["skin"] = skin
			entries.append({"app": app, "outfit": "startup_casual", "label": skin + " " + expression, "expression": expression, "pose": ""})
		await page("expressions_" + skin, entries)
	for pr in ["masculine", "feminine", "neutral"]:
		for family in [["starter", ["startup_casual", "office_professional", "home"]], ["uniforms", ["barista", "business_suit", "civic_staff", "courier", "casual_tee", "casual_jacket"]]]:
			var entries: Array = []
			for outfit in family[1]:
				var app: Dictionary = state.default_appearance()
				app.merge({"presentation": pr, "skin": "s4", "hair": "short_neat"}, true)
				entries.append({"app": app, "outfit": outfit, "label": outfit, "expression": "neutral", "pose": ""})
			await page(str(family[0]) + "_" + pr, entries)
	for pr in ["masculine", "feminine", "neutral"]:
		var entries: Array = []
		for pose in ["", "sit", "idle", "phone", "interact", "carry"]:
			var app: Dictionary = state.default_appearance()
			app.merge({"presentation": pr, "skin": "s5", "hair": "bob", "accessory": "glasses_round"}, true)
			entries.append({"app": app, "outfit": "office_professional", "label": pr + " " + ("walk" if pose == "" else pose), "expression": "neutral", "pose": pose})
		await page("poses_" + pr, entries)
	# Reconstruct a saved custom player, enter the real apartment, then exercise each pose there.
	var app: Dictionary = state.default_appearance()
	app.merge({"presentation": "feminine", "face": "heart", "hair": "ponytail", "hair_color": "auburn", "skin": "s6", "accessory": "glasses_square"}, true)
	state.data = JSON.parse_string(JSON.stringify(state.template({"appearance": app, "outfit": "home"})))
	router._enter("interior", "riverside_apartment", "bed_side", "down")
	root.get_node("Clock").world_active = false
	await process_frame
	for pose in ["", "sit", "phone", "interact", "carry"]:
		router.current.player.rig.set_pose(pose)
		await create_timer(.15).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out + "/world_saved_custom_" + ("walk" if pose == "" else pose) + ".png")
	print("custom_character_gallery: %d option/skin/expression/pose pages + 5 saved-custom-player world captures" % pages)
	quit()

func page(title: String, entries: Array) -> void:
	var canvas := Control.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	router._set_scene(canvas)
	var bg := ColorRect.new()
	bg.color = Color("101e30")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)
	var caption := Label.new()
	caption.text = "ACTUAL GAME RENDER / " + title
	caption.position = Vector2(12, 8)
	caption.add_theme_font_size_override("font_size", 13)
	canvas.add_child(caption)
	for i in entries.size():
		var entry: Dictionary = entries[i]
		var origin := Vector2(14 + (i % 4) * 157, 42 + (i / 4) * 148)
		var portrait = load("res://scripts/ui/portrait_view.gd").new()
		portrait.position = origin
		portrait.size = Vector2(64,64)
		canvas.add_child(portrait)
		portrait.setup_character(entry["app"], entry["outfit"])
		portrait.set_expr(entry["expression"])
		for j in 3:
			var rig = load("res://scripts/world/character_rig.gd").new()
			rig.position = origin + Vector2(18 + j * 45, 134)
			rig.scale = Vector2(1.3, 1.3)
			canvas.add_child(rig)
			rig.setup(entry["app"], entry["outfit"])
			rig.set_dir(["down", "right", "up"][j])
			rig.set_expression(entry["expression"])
			rig.set_pose(entry["pose"])
		var label := Label.new()
		label.text = entry["label"]
		label.position = origin + Vector2(67,20)
		label.add_theme_font_size_override("font_size", 9)
		canvas.add_child(label)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out + "/matrix_" + title + ".png")
	pages += 1
