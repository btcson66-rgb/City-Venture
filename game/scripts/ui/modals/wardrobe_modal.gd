class_name WardrobeModal
extends Modal
## Cosmetic only (Handoff §2.1): outfits and accessories have no gameplay effect.

var preview: CharacterRig


func _init() -> void:
	title_text = "Wardrobe"
	icon_name = "shirt"
	panel_size = Vector2(360, 200)


func build() -> void:
	var p: Dictionary = GameState.data["player"]
	var h := UIK.hbox(10)
	body.add_child(h)
	var pv := SubViewportContainer.new()
	pv.custom_minimum_size = Vector2(64, 96)
	pv.stretch = true
	var vp := SubViewport.new()
	vp.size = Vector2i(32, 48)
	vp.transparent_bg = true
	pv.add_child(vp)
	preview = CharacterRig.new()
	preview.position = Vector2(16, 46)
	vp.add_child(preview)
	preview.setup(p["appearance"], p.get("outfit", "startup_casual"))
	h.add_child(pv)
	var v := UIK.vbox(3)
	h.add_child(v)
	v.add_child(UIK.label("OUTFIT", 7, Art.C_DIM, true))
	for o in DataDB.character.get("outfits", []):
		var b := UIK.button(o["name"], _set_outfit.bind(o["id"]), "tab_active" if o["id"] == p.get("outfit", "") else "tab", 150)
		v.add_child(b)
	v.add_child(UIK.label("ACCESSORY", 7, Art.C_DIM, true))
	var ah := UIK.hbox(3)
	for a in DataDB.character.get("accessories", []):
		ah.add_child(UIK.button(a["name"].left(10), _set_acc.bind(a["id"]), "tab_active" if a["id"] == p["appearance"].get("accessory", "none") else "tab"))
	v.add_child(ah)
	v.add_child(UIK.label("Planned: " + ", ".join(DataDB.character.get("outfits_planned", [])), 6, Art.C_DIM))


func _set_outfit(id: String) -> void:
	GameState.data["player"]["outfit"] = id
	_apply()


func _set_acc(id: String) -> void:
	GameState.data["player"]["appearance"]["accessory"] = id
	_apply()


func _apply() -> void:
	var ws := SceneRouter.world_scene()
	if ws and ws.player:
		ws.player.refresh_appearance()
	rebuild()
