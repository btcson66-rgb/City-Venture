extends SceneTree
## Render native/detail pairs through the game's Art, UIK and Sprite2D paths at both acceptance resolutions.

const SAMPLES := {
	"backdrops": "backdrops/menu", "cards": "cards/bloom_coffee",
	"city_map": "city_map/aurelia_map", "world_map": "world_map/board",
	"ui": "ui/panel", "minigames": "minigames/route_map",
	"events": "events/rail_frozen", "logos": "logos/saas_crm",
	"products": "products/wireless_earbuds_photo", "effects": "effects/water_sparkle",
}
var out := ""
var failures: Array = []
var measurements: Array = []


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.substr(6)
	call_deferred("run")


func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)


func click(button: Button) -> void:
	var position := root.get_final_transform() * button.get_global_rect().get_center()
	var move := InputEventMouseMotion.new()
	move.position = position
	Input.parse_input_event(move)
	await process_frame
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = position
		Input.parse_input_event(event)
		await process_frame


func run() -> void:
	await process_frame
	var art := root.get_node("Art")
	var kit = load("res://scripts/ui/uik.gd")
	DirAccess.make_dir_recursive_absolute(out)
	root.content_scale_size = Vector2i(640, 360)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	for resolution in [Vector2i(1280, 720), Vector2i(2560, 1440)]:
		root.size = resolution
		for group in SAMPLES:
			var key: String = SAMPLES[group]
			# Use the first shipped filename when a representative art id is absent.
			if not ResourceLoader.exists("res://assets/" + key + ".png"):
				var dir := DirAccess.open("res://assets/" + group)
				for file in dir.get_files():
					if file.ends_with(".png") and ResourceLoader.exists("res://assets/world_detail/" + group + "/" + file):
						key = group + "/" + file.get_basename()
						break
			var native: Texture2D = load("res://assets/" + key + ".png")
			var before := Vector2.ZERO
			for mode in ["native", "detail"]:
				art._cache.clear()
				kit._theme = null
				if mode == "native":
					art._cache[key] = native
					for panel in ["panel", "button", "button_hover", "button_pressed", "button_disabled"]:
						art._cache["ui/" + panel] = load("res://assets/ui/" + panel + ".png")
					for icon in ["bank", "map", "mail"]:
						art._cache["ui/icons/" + icon] = load("res://assets/ui/icons/" + icon + ".png")
				var page := Control.new()
				page.size = Vector2(640, 360)
				root.add_child(page)
				var bg := ColorRect.new()
				bg.color = Color("142033")
				bg.size = page.size
				page.add_child(bg)
				var title: Label = kit.label("#62 / %s / %s / %dx%d" % [key, mode, resolution.x, resolution.y], 12)
				title.position = Vector2(12, 8)
				title.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
				page.add_child(title)
				var texture: Texture2D = art.tex(key)
				check(texture.get_size() == native.get_size(), key + " logical size " + mode)
				if group == "ui":
					var panel := Panel.new()
					panel.position = Vector2(80, 60)
					panel.size = Vector2(480, 210)
					panel.add_theme_stylebox_override("panel", kit.tex_box(key))
					page.add_child(panel)
					for i in range(3):
						var button := Button.new()
						button.name = "ReviewButton_%d" % i
						button.theme = kit.theme()
						button.text = "Button %d" % (i + 1)
						button.position = Vector2(110 + i * 145, 110)
						button.size = Vector2(130, 50)
						page.add_child(button)
					var icon_index := 0
					for icon in ["bank", "map", "mail"]:
						var image := TextureRect.new()
						image.texture = art.icon(icon)
						image.position = Vector2(120 + icon_index * 140, 220)
						page.add_child(image)
						icon_index += 1
				elif group == "effects":
					var sprite := Sprite2D.new()
					sprite.texture = texture
					sprite.hframes = 4
					sprite.frame = 2
					sprite.position = Vector2(320, 180)
					sprite.scale = Vector2(8, 8)
					page.add_child(sprite)
				else:
					var pic := TextureRect.new()
					pic.texture = texture
					pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
					pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
					pic.position = Vector2(20, 35)
					pic.size = Vector2(600, 285)
					page.add_child(pic)
				var hit := Button.new()
				hit.name = "ReviewHitTarget"
				hit.position = Vector2(270, 330)
				hit.size = Vector2(100, 24)
				hit.theme = kit.theme()
				hit.text = "Hit target"
				page.add_child(hit)
				var clicked := [false]
				hit.pressed.connect(func(): clicked[0] = true)
				await process_frame
				await RenderingServer.frame_post_draw
				var center := hit.get_global_rect().get_center()
				if mode == "native":
					before = center
				else:
					check(center == before, key + " click position unchanged")
				await click(hit)
				check(clicked[0], key + " real mouse hit " + mode)
				var image := root.get_texture().get_image()
				check(image.get_size() == resolution, "capture resolution")
				var path := out + "/%s_%s_%dx%d.jpg" % [group, mode, resolution.x, resolution.y]
				check(image.save_jpg(path, 0.85) == OK, "save " + path)
				measurements.append({"key": key, "mode": mode, "resolution": str(resolution), "logical": str(texture.get_size()), "pixels": str(texture.get_image().get_size()), "hit_center": str(center)})
				page.free()
				await process_frame
	var f := FileAccess.open(out + "/render_checks.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"failures": failures, "measurements": measurements}, "  "))
	print("DETAIL ART REVIEW: %d captures, %d failures" % [measurements.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)
