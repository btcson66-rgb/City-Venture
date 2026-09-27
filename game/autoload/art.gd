extends Node
## Texture cache, palette and character appearance resolution.

const C_NAVY_900 := Color8(13, 27, 43)
const C_NAVY_800 := Color8(18, 31, 49)
const C_NAVY_700 := Color8(27, 39, 63)
const C_NAVY_600 := Color8(38, 56, 88)
const C_NAVY_500 := Color8(50, 65, 94)
const C_BLUE := Color8(77, 138, 214)
const C_BLUE_DARK := Color8(52, 106, 176)
const C_SKY := Color8(178, 214, 242)
const C_WHITE := Color8(244, 246, 250)
const C_MUTED := Color8(160, 170, 192)
const C_DIM := Color8(110, 122, 148)
const C_GREEN := Color8(111, 207, 128)
const C_RED := Color8(234, 112, 92)
const C_GOLD := Color8(226, 180, 82)
const C_PURPLE := Color8(170, 130, 214)

var _cache := {}
var font_title: FontFile
var font_body: FontFile


func _ready() -> void:
	font_title = load("res://assets/fonts/PixelifySans.ttf")
	font_body = load("res://assets/fonts/Inter.ttf")


func tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var full := "res://assets/" + path + ".png"
	var t: Texture2D = null
	if ResourceLoader.exists(full):
		t = load(full)
	else:
		push_warning("Art: missing texture " + full)
	_cache[path] = t
	return t


func icon(name: String) -> Texture2D:
	return tex("ui/icons/" + name)


func opt_color(group: String, id: String, fallback := Color.WHITE) -> Color:
	var o := DataDB.character_option(group, id)
	if o.has("color"):
		return Color(o["color"])
	return fallback


## Resolve an appearance dictionary into layer textures + tints for CharacterRig.
## outfit_tints: optional {"top": Color, "bottom": Color} for tintable NPC outfits.
func character_layers(app: Dictionary, outfit: String, outfit_tints := {}) -> Array:
	var pres: String = app.get("presentation", "masculine")
	var face: String = app.get("face", "round")
	var hair: String = app.get("hair", "messy")
	var hc: Color = app.get("_hair_color_c", opt_color("hair_colors", app.get("hair_color", "brown"), Color8(120, 82, 54)))
	var sc: Color = app.get("_skin_c", opt_color("skin_tones", app.get("skin", "s2"), Color8(248, 208, 176)))
	var ec: Color = app.get("_eye_c", opt_color("eye_colors", app.get("eye_color", "brown"), Color8(120, 80, 52)))
	var eyes: String = app.get("eye_shape", "round")
	var L: Array = []
	L.append({"tex": "characters/hair_%s_back" % hair, "tint": hc, "name": "hair_back"})
	L.append({"tex": "characters/body_%s_%s" % [pres, face], "tint": sc, "name": "body"})
	L.append({"tex": "characters/outfit_%s_%s_bottom" % [outfit, pres], "tint": outfit_tints.get("bottom", Color.WHITE), "name": "bottom"})
	L.append({"tex": "characters/outfit_%s_%s_shoes" % [outfit, pres], "tint": Color.WHITE, "name": "shoes"})
	L.append({"tex": "characters/outfit_%s_%s_top" % [outfit, pres], "tint": outfit_tints.get("top", Color.WHITE), "name": "top"})
	L.append({"tex": "characters/eyes_%s" % eyes, "tint": Color.WHITE, "name": "eyes"})
	L.append({"tex": "characters/iris_%s" % eyes, "tint": ec, "name": "iris"})
	L.append({"tex": "characters/brows_%s" % app.get("brows", "straight"), "tint": hc, "name": "brows"})
	L.append({"tex": "characters/mouth_%s" % app.get("mouth", "smile"), "tint": Color.WHITE, "name": "mouth"})
	L.append({"tex": "characters/hair_%s_front" % hair, "tint": hc, "name": "hair_front"})
	var acc: String = app.get("accessory", "none")
	if acc.begins_with("glasses_"):
		L.append({"tex": "characters/acc_" + acc, "tint": Color.WHITE, "name": "acc"})
	elif acc == "backpack":
		L.append({"tex": "characters/acc_backpack", "tint": Color.WHITE, "name": "acc"})
	return L


func portrait_layers(app: Dictionary, outfit: String, outfit_tints := {}) -> Array:
	var hc: Color = app.get("_hair_color_c", opt_color("hair_colors", app.get("hair_color", "brown"), Color8(120, 82, 54)))
	var sc: Color = app.get("_skin_c", opt_color("skin_tones", app.get("skin", "s2"), Color8(248, 208, 176)))
	var ec: Color = app.get("_eye_c", opt_color("eye_colors", app.get("eye_color", "brown"), Color8(120, 80, 52)))
	var hair: String = app.get("hair", "messy")
	var eyes: String = app.get("eye_shape", "round")
	return [
		{"tex": "portraits/hair_%s_back" % hair, "tint": hc, "frames": 1},
		{"tex": "portraits/head_%s" % app.get("face", "round"), "tint": sc, "frames": 1},
		{"tex": "portraits/outfit_%s" % outfit, "tint": outfit_tints.get("top", Color.WHITE), "frames": 1},
		{"tex": "portraits/eyes_%s" % eyes, "tint": Color.WHITE, "frames": 4},
		{"tex": "portraits/iris_%s" % eyes, "tint": ec, "frames": 4},
		{"tex": "portraits/brows_%s" % app.get("brows", "straight"), "tint": hc, "frames": 4},
		{"tex": "portraits/mouth_%s" % app.get("mouth", "smile"), "tint": Color.WHITE, "frames": 4},
		{"tex": "portraits/hair_%s_front" % hair, "tint": hc, "frames": 1},
	]


## Deterministic random appearance for ambient NPCs.
func random_appearance(rng: RandomNumberGenerator) -> Dictionary:
	var ch := DataDB.character
	var pick := func(group: String) -> String:
		var arr: Array = ch.get(group, [])
		return arr[rng.randi_range(0, arr.size() - 1)]["id"]
	var app := {
		"presentation": pick.call("presentations"), "face": pick.call("face_shapes"), "hair": pick.call("hairstyles"),
		"hair_color": pick.call("hair_colors"), "skin": pick.call("skin_tones"), "eye_shape": pick.call("eye_shapes"),
		"eye_color": pick.call("eye_colors"), "brows": pick.call("eyebrows"), "mouth": pick.call("mouths"),
		"accessory": ["none", "none", "none", "glasses_round", "glasses_square", "backpack"][rng.randi_range(0, 5)],
	}
	if app["hair_color"] in ["rose", "navy"] and rng.randf() < 0.7:
		app["hair_color"] = "dark_brown"
	return app


const CLOTH_TINTS := [Color8(70, 110, 170), Color8(200, 90, 80), Color8(90, 150, 110), Color8(230, 200, 120), Color8(140, 110, 180),
	Color8(60, 60, 70), Color8(220, 220, 226), Color8(120, 150, 190), Color8(190, 140, 100), Color8(100, 100, 120)]


func random_outfit_tints(rng: RandomNumberGenerator) -> Dictionary:
	return {"top": CLOTH_TINTS[rng.randi_range(0, CLOTH_TINTS.size() - 1)],
		"bottom": [Color8(60, 80, 130), Color8(50, 52, 60), Color8(120, 110, 100), Color8(80, 90, 110)][rng.randi_range(0, 3)]}
