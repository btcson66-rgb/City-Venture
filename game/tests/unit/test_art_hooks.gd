extends RefCounted
## Optional art from the visuals track: NPC sheets, outfit detail layers, portrait accessories and poses show up as
## soon as the file exists, and everything falls back to today's look while it doesn't.
## Art files are simulated by putting a texture into Art's cache under the path the game would load.

var runner
var _fake: Array[String] = []


func _art(path: String, w := 128, h := 144) -> void:
	Art._cache[path] = ImageTexture.create_from_image(Image.create(w, h, false, Image.FORMAT_RGBA8))
	_fake.append(path)


func _cleanup() -> void:
	for p in _fake:
		Art._cache.erase(p)
	_fake.clear()


func _names(layers: Array) -> Array:
	return layers.map(func(L): return str(L.get("name", L["tex"])))


func test_missing_optional_art_keeps_the_layered_look() -> void:
	runner.check(not Art.has_tex("characters/npc_nobody"), "no sheet for an unknown NPC")
	runner.check(Art.opt_tex("logos/nobody") == null, "opt_tex returns null without a warning")
	var app: Dictionary = DataDB.npc("maya")["appearance"]
	var L := Art.character_layers(app, "casual_jacket", {}, "maya")
	runner.check(L.size() >= 10, "Maya is still built from layers (%d)" % L.size())
	runner.check(not _names(L).has("top_detail"), "no detail layer until the art exists")


func test_npc_sheet_replaces_the_rig() -> void:
	_art("characters/npc_maya")
	_art("portraits/npc_maya", 256, 64)
	var app: Dictionary = DataDB.npc("maya")["appearance"]
	var L := Art.character_layers(app, "casual_jacket", {"top": Color.RED}, "maya")
	runner.eq(L.size(), 1, "one hand-made sheet")
	runner.eq(str(L[0]["tex"]), "characters/npc_maya", "Maya's own sheet")
	runner.eq(L[0]["tint"], Color.WHITE, "never tinted")
	var P := Art.portrait_layers(app, "casual_jacket", {}, "maya")
	runner.eq(P.size(), 1, "one hand-made portrait strip")
	runner.eq(int(P[0]["frames"]), 4, "with the 4 expressions")
	runner.check(Art.character_layers(app, "casual_jacket").size() > 1, "the player never picks up an NPC sheet")
	_cleanup()


func test_outfit_detail_layers_sit_above_the_tinted_fabric() -> void:
	_art("characters/outfit_business_suit_masculine_top_detail")
	_art("characters/outfit_business_suit_masculine_bottom_detail")
	var app := {"presentation": "masculine", "face": "square"}
	var L := Art.character_layers(app, "business_suit", {"top": Color8(60, 60, 70)})
	var n := _names(L)
	runner.eq(n.find("top_detail"), n.find("top") + 1, "top detail right above the top")
	runner.eq(n.find("bottom_detail"), n.find("bottom") + 1, "bottom detail right above the bottom")
	runner.eq(L[n.find("top")]["tint"], Color8(60, 60, 70), "fabric takes the NPC colour")
	runner.eq(L[n.find("top_detail")]["tint"], Color.WHITE, "shirt and tie keep their colours")
	_cleanup()


func test_portrait_glasses_follow_the_accessory() -> void:
	_art("portraits/acc_glasses_round", 64, 64)
	var glasses := Art.portrait_layers({"accessory": "glasses_round"}, "casual_tee")
	var bare := Art.portrait_layers({"accessory": "none"}, "casual_tee")
	runner.eq(str(glasses[-1]["tex"]), "portraits/acc_glasses_round", "glasses drawn last, over the hair")
	runner.eq(glasses.size(), bare.size() + 1, "only when the character wears them")
	_cleanup()


func test_pose_needs_every_layer() -> void:
	var rig := CharacterRig.new()
	rig.setup({"presentation": "feminine", "face": "oval", "hair": "bob", "accessory": "none"}, "casual_tee")
	runner.check(not rig.set_pose("sit"), "no sit art yet")
	runner.eq(rig.pose, "", "stays on the walk sheets")
	var layers := Art.character_layers({"presentation": "feminine", "face": "oval", "hair": "bob", "accessory": "none"}, "casual_tee")
	for i in layers.size() - 1:
		_art(str(layers[i]["tex"]) + "_sit")
	runner.check(not rig.set_pose("sit"), "one layer missing: never mix pose and walk frames")
	_art(str(layers[-1]["tex"]) + "_sit")
	runner.check(rig.set_pose("sit"), "complete pose art is used")
	runner.eq(rig.pose, "sit", "sitting")
	var body: Sprite2D = rig.get_node("Body/body")
	runner.eq(body.texture, Art.tex(str(body.get_meta("tex")) + "_sit"), "layers swapped to the pose sheets")
	rig.set_walking(true)
	runner.eq(rig.pose, "", "walking off ends a standing pose")
	runner.eq(body.texture, Art.tex(str(body.get_meta("tex"))), "back on the walk sheet")
	runner.check(not rig.set_pose("dance"), "unknown poses are refused")
	rig.free()
	_cleanup()


func test_named_npcs_are_told_apart() -> void:
	var maya: Dictionary = DataDB.npc("maya")
	var elena: Dictionary = DataDB.npc("elena")
	var diff := 0
	for k in ["face", "hair", "eye_shape", "brows"]:
		if maya["appearance"][k] != elena["appearance"][k]:
			diff += 1
	runner.check(diff >= 3, "Maya and Elena differ in face, hair, eyes or brows (%d)" % diff)
	runner.check(DataDB.npc("ken")["outfit"] != DataDB.npc("dara")["outfit"], "Ken no longer dresses like the PostPoint clerk")
	for id in DataDB.npcs:
		var d: Dictionary = DataDB.npcs[id]
		for s in d.get("schedule", []):
			var p := str(s.get("pose", "idle"))
			runner.check(CharacterRig.POSES.has(p), "%s: pose '%s' is known" % [id, p])
		if d.has("logo"):
			runner.check(str(d["logo"]) != "" and not d.has("appearance"), "%s: a logo only for faceless contacts" % id)
