extends SceneTree
## Captures use the game's real PortraitView and CharacterRig, with no renderer overrides.
var out := ""
var db: Node
var state: Node
var router: Node
var pages := 0
var use_palette := false
var art_palette: Dictionary = {}
const OUTFITS = ["executive", "luxury_citywear", "travel", "formal_evening", "logistics_site"]
func _initialize() -> void:
    out = OS.get_cmdline_user_args()[0]
    use_palette = "--art-palette-preview" in OS.get_cmdline_user_args()
    art_palette = JSON.parse_string(FileAccess.get_file_as_string("res://assets/outfit_palette.json"))["defaults"]
    DirAccess.make_dir_recursive_absolute(out)
    call_deferred("run")
func run() -> void:
    await process_frame
    db = root.get_node("DataDB")
    state = root.get_node("GameState")
    router = root.get_node("SceneRouter")
    root.get_node("Clock").world_active = false
    root.get_node("UIRoot").set_hud_visible(false)
    for pr in ["masculine", "feminine", "neutral"]:
        for skin in ["s1", "s2", "s3", "s4", "s5", "s6"]:
            var entries: Array = []
            for outfit in OUTFITS:
                var app: Dictionary = state.default_appearance()
                app.merge({"presentation":pr, "skin":skin},true)
                entries.append({"app":app, "outfit":outfit, "label":pr+" "+skin+" "+outfit, "expression":"neutral", "pose":""})
            await page(pr+"_"+skin, entries)
        for outfit in OUTFITS:
            var entries: Array = []
            for pose in ["", "sit", "idle", "phone", "interact", "carry"]:
                var app: Dictionary = state.default_appearance()
                app.merge({"presentation":pr, "skin":"s5"},true)
                entries.append({"app":app, "outfit":outfit, "label":outfit+" "+pose, "expression":"neutral", "pose":pose})
            await page(pr+"_poses_"+outfit, entries)
    for outfit in OUTFITS:
        var app: Dictionary = state.default_appearance()
        app["skin"] = "s6"
        state.data = JSON.parse_string(JSON.stringify(state.template({"appearance":app,"outfit":outfit})))
        router._enter("interior", "threadline_apparel", "entrance", "down")
        root.get_node("Clock").world_active = false
        await process_frame
        if use_palette:
            router.current.player.rig.setup(app, outfit, palette_tints(outfit))
        await create_timer(.2).timeout
        await RenderingServer.frame_post_draw
        root.get_texture().get_image().save_png(out+"/world_"+outfit+".png")
    print("shop_wardrobe_gallery: %d actual game matrix pages + 5 retail world captures" % pages)
    quit()

func palette_tints(outfit: String) -> Dictionary:
    if not use_palette: return {}
    var values: Dictionary = art_palette[outfit]
    return {"top":Color(values["top"]), "bottom":Color(values["bottom"])}

func page(title: String, entries: Array) -> void:
    var canvas := Control.new()
    canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
    router._set_scene(canvas)
    var bg := ColorRect.new()
    bg.color = Color("101e30")
    bg.set_anchors_preset(Control.PRESET_FULL_RECT)
    canvas.add_child(bg)
    var caption := Label.new()
    caption.text = ("ART PALETTE PREVIEW / " if use_palette else "CURRENT GAME UNWIRED DEFAULT / ") + title
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
        portrait.setup_character(entry["app"], entry["outfit"], palette_tints(entry["outfit"]))
        portrait.set_expr(entry["expression"])
        for j in 3:
            var rig = load("res://scripts/world/character_rig.gd").new()
            rig.position = origin + Vector2(18 + j * 45, 134)
            rig.scale = Vector2(1.3, 1.3)
            canvas.add_child(rig)
            rig.setup(entry["app"], entry["outfit"], palette_tints(entry["outfit"]))
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
