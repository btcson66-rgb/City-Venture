extends SceneTree
## Regressions for all customization branches. No gameplay or test fixtures are changed.
var failures: Array[String] = []
var combinations := 0
var texture_checks := 0
var checked := {}
var db: Node
var art: Node
var state: Node
func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)

func inspect(app: Dictionary, outfit: String) -> void:
	var sprite: Array = art.character_layers(app, outfit)
	var portrait: Array = art.portrait_layers(app, outfit)
	check(sprite.size() >= 11 and portrait.size() >= 9, "One-piece default override remains")
	for layer in sprite + portrait:
		var key: String = layer["tex"]
		if checked.has(key):
			continue
		checked[key] = true
		check(art.has_tex("world_detail/" + key), "Missing 4x layer: " + key)
		var t = art.tex(key)
		texture_checks += 1
		if t == null:
			check(false, "Missing layer: " + key)
			continue
		check(t.get_height() == (576 if key.begins_with("characters/") else 256), "Incorrect detail height: " + key)
		if key.begins_with("characters/"):
			check(t.get_width() == 512, "Incorrect character atlas width: " + key)
			for pose in ["sit", "idle", "phone", "interact", "carry"]:
				var pk: String = key + "_" + pose
				check(art.has_tex("world_detail/" + pk), "Missing detail pose: " + pk)
				var pt = art.tex(pk)
				texture_checks += 1
				check(pt != null and pt.get_size() == Vector2(512, 576), "Incorrect pose atlas: " + pk)
			if layer["name"] in ["eyes", "eyes_detail", "iris", "brows", "mouth"]:
				for suffix in ["", "_sit", "_idle", "_phone", "_interact", "_carry"]:
					var pk: String = key + "_expressions" + suffix
					var pt = art.tex(pk)
					texture_checks += 1
					check(art.has_tex("world_detail/" + pk) and pt != null and pt.get_size() == Vector2(512,576), "Incorrect expression atlas: " + pk)
	combinations += 1

func run() -> void:
	await process_frame
	db = root.get_node("DataDB")
	art = root.get_node("Art")
	state = root.get_node("GameState")
	var app: Dictionary = state.default_appearance()
	var outfits := ["barista", "business_suit", "civic_staff", "courier", "casual_tee", "casual_jacket"]
	for group in ["outfits", "outfits_shop"]:
		for option in db.character.get(group, []):
			outfits.append(option["id"])
	for pr in db.character["presentations"]:
		for face in db.character["face_shapes"]:
			for hair in db.character["hairstyles"]:
				for skin in db.character["skin_tones"]:
					app.merge({"presentation": pr["id"], "face": face["id"], "hair": hair["id"], "skin": skin["id"]}, true)
					for outfit in outfits:
						inspect(app, outfit)
	for pair in [["hair_colors", "hair_color"], ["eye_shapes", "eye_shape"], ["eye_colors", "eye_color"], ["eyebrows", "brows"], ["mouths", "mouth"], ["accessories", "accessory"]]:
		for option in db.character[pair[0]]:
			app = state.default_appearance()
			app[pair[1]] = option["id"]
			inspect(app, "startup_casual")
	# Skin tint must never replace texture geometry, hairstyle, face, clothes or selected options.
	app = state.default_appearance()
	var reference: Array = art.character_layers(app, "startup_casual")
	for option in db.character["skin_tones"]:
		app["skin"] = option["id"]
		var layers: Array = art.character_layers(app, "startup_casual")
		check(layers.size() == reference.size(), "Skin changed layer count")
		for i in mini(layers.size(), reference.size()):
			check(layers[i]["tex"] == reference[i]["tex"], "Skin changed texture geometry")
			if layers[i]["name"] != "body":
				check(layers[i]["tint"] == reference[i]["tint"], "Skin changed another layer tint")
	var rig = load("res://scripts/world/character_rig.gd").new()
	root.add_child(rig)
	rig.setup(app, "startup_casual")
	for pose in ["sit", "idle", "phone", "interact", "carry"]:
		check(rig.set_pose(pose), "Rig refused complete pose " + pose)
		for expression in ["neutral", "happy", "thinking", "surprised"]:
			rig.set_expression(expression)
			var eyes = rig.get_node("Body/eyes")
			check(eyes.frame % 4 == ["neutral", "happy", "thinking", "surprised"].find(expression), "Expression did not reach world eyes")
		rig.set_walking(true)
		check(rig.pose == ("carry" if pose == "carry" else ""), "Pose does not return to movement")
		rig.set_walking(false)
	rig.free()
	var saved: Dictionary = JSON.parse_string(JSON.stringify(state.template({"appearance": app, "outfit": "startup_casual"})))
	check(saved["player"]["appearance"] == app, "Appearance did not survive JSON round trip")
	for error in failures:
		printerr(error)
	print("custom_character_check: %d combinations; %d texture/pose checks; %d failures" % [combinations, texture_checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
