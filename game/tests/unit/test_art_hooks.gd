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


## A cache entry of null reads as "file absent" (Art.has_tex), whatever is on disk.
func _hide(path: String) -> void:
	Art._cache[path] = null
	_fake.append(path)


func test_pose_needs_every_layer() -> void:
	var app := {"presentation": "feminine", "face": "oval", "hair": "bob", "accessory": "none"}
	var layers := Art.character_layers(app, "casual_tee")
	for i in layers.size() - 1:
		_art(str(layers[i]["tex"]) + "_sit")
	_hide(str(layers[-1]["tex"]) + "_sit")
	var rig := CharacterRig.new()
	rig.setup(app, "casual_tee")
	runner.check(not rig.set_pose("sit"), "one layer missing: never mix pose and walk frames")
	runner.eq(rig.pose, "", "stays on the walk sheets")
	Art._cache.erase(str(layers[-1]["tex"]) + "_sit")
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


## Art batch R3: every walking layer has every pose, so no character ever falls back half-way.
func test_every_walk_layer_has_every_pose() -> void:
	var missing: Array = []
	var n := 0
	for f in DirAccess.get_files_at("res://assets/characters"):
		if not f.ends_with(".png") or f.begins_with("npc_"):
			continue
		var base := f.get_basename()
		var is_pose := false
		for p in CharacterRig.POSES:
			if base.ends_with("_" + p):
				is_pose = true
		if is_pose:
			continue
		n += 1
		for p in CharacterRig.POSES:
			if not Art.has_tex("characters/%s_%s" % [base, p]):
				missing.append("%s_%s" % [base, p])
	runner.check(n >= 134, "walk layers found (%d)" % n)
	runner.check(missing.is_empty(), "pose sheets missing: %s" % ", ".join(missing.slice(0, 8)))


func test_customers_sit_on_the_seats_facing_the_table() -> void:
	var room := Interior.new()
	room.def = DataDB.building("bloom_coffee")["interior"]
	var seats := room.seats()
	runner.check(seats.size() >= 9, "Bloom has its chairs as seats (%d)" % seats.size())
	# cafe_chair at (42,156), 14x22, left of the table at (60,160): centred on it, feet just in front, facing right
	var s := room.seat_near(Vector2(49, 179), 4.0)
	runner.check(not s.is_empty(), "the first chair is a seat")
	if not s.is_empty():
		runner.eq(s["pos"], Vector2(49, 179), "centred on the chair, in front of it")
		runner.eq(s["dir"], "right", "facing the table")
	var right := room.seat_near(Vector2(93, 179), 4.0)
	runner.eq(str(right.get("dir", "")), "left", "the chair on the other side faces back")
	runner.check(not room.seat_near(Vector2(330, 168), 48.0).is_empty(), "Maya's table spot snaps to a real chair")
	var cowork := Interior.new()
	cowork.def = DataDB.building("nexus_cowork")["interior"]
	var sofa := cowork.seat_near(Vector2(346, 196), 48.0)
	runner.eq(str(sofa.get("dir", "")), "down", "sofas face the room")
	runner.check(absf(float((sofa["pos"] as Vector2).x) - 349.0) <= 1.0, "centred on the sofa, not its left edge")
	runner.check(not bool(sofa.get("staff", true)), "anyone may take the sofa")
	var bank := Interior.new()
	bank.def = DataDB.building("nexus_bank")["interior"]
	var desk := bank.seat_near(Vector2(402, 112), 24.0)
	runner.eq(str(desk.get("dir", "")), "down", "Marcus sits behind his desk facing the room")
	runner.check(bool(desk.get("staff", false)), "customers don't take the manager's chair")
	var office := Interior.new()
	office.def = DataDB.building("small_office")["interior"]
	runner.check(not office.seat_near(Vector2(60, 196), 24.0).is_empty(), "the 2B desk spot next to a chair gets that chair")
	runner.check(office.seat_near(Vector2(112, 206), 24.0).is_empty(), "no chair there: that employee works standing")
	room.free()
	cowork.free()
	bank.free()
	office.free()


func test_suits_can_be_told_apart() -> void:
	var seen := {}
	for id in ["marcus", "daniel", "sofia", "tom"]:
		var d: Dictionary = DataDB.npc(id)
		runner.eq(d["outfit"], "business_suit", "%s wears a suit" % id)
		var c := str(d.get("outfit_tints", {}).get("top", ""))
		runner.check(c != "" and not seen.has(c), "%s has a suit colour of their own (%s)" % [id, c])
		seen[c] = true
	runner.check(Art.has_tex("characters/outfit_business_suit_masculine_top_detail"), "tie and shirt sit on their own untinted layer")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var t := Art.random_outfit_tints(rng, "business_suit")
	runner.eq(t["top"], t["bottom"], "a passer-by's suit jacket and trousers match")


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
