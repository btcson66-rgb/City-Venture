class_name WardrobeModal
extends Modal
## Cosmetic only (Handoff §2.1): outfits and accessories have no gameplay effect.
## Shows the outfits the player owns (Wardrobe); more are sold at Threadline on Shopping Street.

var preview: CharacterRig


func _init() -> void:
	title_text = "Wardrobe"
	icon_name = "shirt"
	panel_size = Vector2(380, 214)


## A character preview at `zoom`× standing on a floor card. Returns [container, rig].
## A scaled Node2D like the character creator's views: the rig's outline CanvasGroup renders black inside a SubViewport.
static func preview_box(app: Dictionary, outfit: String, zoom := 2) -> Array:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UIK.flat(Color8(18, 28, 46), Color8(52, 70, 102), 1))
	box.custom_minimum_size = Vector2(32 * zoom + 12, 48 * zoom + 12)
	box.clip_contents = true
	var stage := Control.new()
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(stage)
	var holder := Node2D.new()
	holder.scale = Vector2(zoom, zoom)
	holder.position = Vector2(16 * zoom + 2, 46 * zoom + 4)   # box content margins are 4 / 2 px
	stage.add_child(holder)
	var rig := CharacterRig.new()
	holder.add_child(rig)
	rig.setup(app, outfit)
	return [box, rig]


func build() -> void:
	var p: Dictionary = GameState.data["player"]
	var h := UIK.hbox(10)
	body.add_child(h)
	var pb := preview_box(p["appearance"], Wardrobe.wearing())
	preview = pb[1]
	h.add_child(pb[0])
	var v := UIK.vbox(3)
	h.add_child(v)
	v.add_child(UIK.label("OUTFIT", 7, Art.C_DIM, true))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	for o in Wardrobe.catalogue():
		if not Wardrobe.owns(o["id"]):
			continue
		var b := UIK.button(o["name"], _set_outfit.bind(o["id"]), "tab_active" if o["id"] == Wardrobe.wearing() else "tab", 128)
		b.name = "Wear_" + o["id"]
		grid.add_child(b)
	v.add_child(grid)
	v.add_child(UIK.label("ACCESSORY", 7, Art.C_DIM, true))
	var ah := UIK.hbox(3)
	for a in DataDB.character.get("accessories", []):
		ah.add_child(UIK.button(I18n.t(a["name"]).left(10), _set_acc.bind(a["id"]), "tab_active" if a["id"] == p["appearance"].get("accessory", "none") else "tab"))
	v.add_child(ah)
	if Wardrobe.catalogue().any(func(o): return not Wardrobe.owns(o["id"])):
		v.add_child(UIK.label("More outfits at Threadline, Shopping Street.", 6, Art.C_DIM))


func _set_outfit(id: String) -> void:
	Wardrobe.wear(id)
	rebuild()


func _set_acc(id: String) -> void:
	GameState.data["player"]["appearance"]["accessory"] = id
	var ws := SceneRouter.world_scene()
	if ws and ws.player:
		ws.player.refresh_appearance()
	rebuild()
