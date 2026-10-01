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
var _absent := {}
var font_title: FontFile
var font_body: FontFile


func _ready() -> void:
	font_title = load("res://assets/fonts/PixelifySans.ttf")
	font_body = load("res://assets/fonts/Inter.ttf")


func tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var full := "res://assets/" + path + ".png"
	# Customisation keeps stable logical keys (also used by pose probes and saved appearances).
	# Native and detail layers share geometry; prefer their direct 4x rendering when present.
	if (path.begins_with("characters/") or path.begins_with("portraits/")) and not path.get_file().begins_with("npc_"):
		var detail := "res://assets/world_detail/" + path + ".png"
		if ResourceLoader.exists(detail):
			full = detail
	var t: Texture2D = null
	if ResourceLoader.exists(full):
		t = load(full)
	else:
		push_warning("Art: missing texture " + full)
	_cache[path] = t
	return t


## True when an optional art file exists, without the missing-texture warning. New art from the visuals track
## (logos, chapter cards, poses, NPC sheets...) shows up as soon as the file is committed; until then callers
## keep their current look.
func has_tex(path: String) -> bool:
	if _cache.has(path):
		return _cache[path] != null
	if _absent.has(path):
		return false
	var ok := ResourceLoader.exists("res://assets/" + path + ".png")
	if not ok:
		_absent[path] = true   # characters spawn all day; don't hit the filesystem for the same missing pose again
	return ok


## tex() for optional art: null when the file isn't there yet (no warning).
func opt_tex(path: String) -> Texture2D:
	return tex(path) if has_tex(path) else null


func icon(name: String) -> Texture2D:
	return tex("ui/icons/" + name)


func opt_color(group: String, id: String, fallback := Color.WHITE) -> Color:
	var o := DataDB.character_option(group, id)
	if o.has("color"):
		return Color(o["color"])
	return fallback


## Resolve an appearance dictionary into layer textures + tints for CharacterRig.
## outfit_tints: optional {"top": Color, "bottom": Color} for tintable NPC outfits.
## Optional art, used when the file exists:
##  - characters/npc_<npc_id>: a hand-made full sheet for a named NPC, replaces the layered rig
##  - outfit_<o>_<pres>_top_detail / _bottom_detail: untinted details (shirt, tie, badge, bag) drawn over the
##    tinted fabric, so one suit can be charcoal on Marcus and navy on Daniel
func character_layers(app: Dictionary, outfit: String, outfit_tints := {}, npc_id := "") -> Array:
	if npc_id != "" and has_tex("world_detail/characters/npc_" + npc_id):
		return [{"tex": "world_detail/characters/npc_" + npc_id, "tint": Color.WHITE, "name": "npc_detail"}]
	if npc_id != "" and has_tex("characters/npc_" + npc_id):
		return [{"tex": "characters/npc_" + npc_id, "tint": Color.WHITE, "name": "npc"}]
	var pres: String = app.get("presentation", "masculine")
	var face: String = app.get("face", "round")
	var hair: String = app.get("hair", "messy")
	var hc: Color = app.get("_hair_color_c", opt_color("hair_colors", app.get("hair_color", "brown"), Color8(120, 82, 54)))
	var sc: Color = app.get("_skin_c", opt_color("skin_tones", app.get("skin", "s2"), Color8(248, 208, 176)))
	var ec: Color = app.get("_eye_c", opt_color("eye_colors", app.get("eye_color", "brown"), Color8(120, 80, 52)))
	var eyes: String = app.get("eye_shape", "round")
	var r := _resolve_outfit(outfit, "characters/outfit_%s_" + pres + "_top", outfit_tints)
	outfit = r[0]
	outfit_tints = r[1]
	var L: Array = []
	L.append({"tex": "characters/hair_%s_back" % hair, "tint": hc, "name": "hair_back"})
	L.append({"tex": "characters/body_%s_%s" % [pres, face], "tint": sc, "name": "body"})
	var base := "characters/outfit_%s_%s" % [outfit, pres]
	L.append({"tex": base + "_bottom", "tint": outfit_tints.get("bottom", Color.WHITE), "name": "bottom"})
	if has_tex(base + "_bottom_detail"):
		L.append({"tex": base + "_bottom_detail", "tint": Color.WHITE, "name": "bottom_detail"})
	L.append({"tex": base + "_shoes", "tint": Color.WHITE, "name": "shoes"})
	L.append({"tex": base + "_top", "tint": outfit_tints.get("top", Color.WHITE), "name": "top"})
	if has_tex(base + "_top_detail"):
		L.append({"tex": base + "_top_detail", "tint": Color.WHITE, "name": "top_detail"})
	L.append({"tex": "characters/eyes_%s" % eyes, "tint": Color.WHITE, "name": "eyes"})
	L.append({"tex": "characters/iris_%s" % eyes, "tint": ec, "name": "iris"})
	if has_tex("characters/eyes_detail_%s" % eyes):
		L.append({"tex": "characters/eyes_detail_%s" % eyes, "tint": Color.WHITE, "name": "eyes_detail"})
	L.append({"tex": "characters/brows_%s" % app.get("brows", "straight"), "tint": hc, "name": "brows"})
	L.append({"tex": "characters/mouth_%s" % app.get("mouth", "smile"), "tint": Color.WHITE, "name": "mouth"})
	L.append({"tex": "characters/hair_%s_front" % hair, "tint": hc, "name": "hair_front"})
	# any accessory with a sheet (glasses, backpack today; hats, bags, watches, badges, headsets as their art lands)
	var acc: String = app.get("accessory", "none")
	if acc != "none" and has_tex("characters/acc_" + acc):
		L.append({"tex": "characters/acc_" + acc, "tint": Color.WHITE, "name": "acc"})
	return L


## Portrait layers. Optional art, used when the file exists: portraits/npc_<npc_id> (a hand-made 4-expression
## strip that replaces the layers), portraits/outfit_<o>_detail (untinted collar details) and
## portraits/acc_<accessory> (glasses on the portrait, 64x64).
func portrait_layers(app: Dictionary, outfit: String, outfit_tints := {}, npc_id := "") -> Array:
	if npc_id != "" and has_tex("world_detail/portraits/npc_" + npc_id):
		return [{"tex": "world_detail/portraits/npc_" + npc_id, "tint": Color.WHITE, "frames": 4}]
	if npc_id != "" and has_tex("portraits/npc_" + npc_id):
		return [{"tex": "portraits/npc_" + npc_id, "tint": Color.WHITE, "frames": 4}]
	var hc: Color = app.get("_hair_color_c", opt_color("hair_colors", app.get("hair_color", "brown"), Color8(120, 82, 54)))
	var sc: Color = app.get("_skin_c", opt_color("skin_tones", app.get("skin", "s2"), Color8(248, 208, 176)))
	var ec: Color = app.get("_eye_c", opt_color("eye_colors", app.get("eye_color", "brown"), Color8(120, 80, 52)))
	var hair: String = app.get("hair", "messy")
	var eyes: String = app.get("eye_shape", "round")
	var r := _resolve_outfit(outfit, "portraits/outfit_%s", outfit_tints)
	outfit = r[0]
	outfit_tints = r[1]
	var L: Array = [
		{"tex": "portraits/hair_%s_back" % hair, "tint": hc, "frames": 1},
		{"tex": "portraits/head_%s" % app.get("face", "round"), "tint": sc, "frames": 1},
		{"tex": "portraits/outfit_%s" % outfit, "tint": outfit_tints.get("top", Color.WHITE), "frames": 1},
	]
	if has_tex("portraits/outfit_%s_detail" % outfit):
		L.append({"tex": "portraits/outfit_%s_detail" % outfit, "tint": Color.WHITE, "frames": 1})
	L.append_array([
		{"tex": "portraits/eyes_%s" % eyes, "tint": Color.WHITE, "frames": 4},
		{"tex": "portraits/iris_%s" % eyes, "tint": ec, "frames": 4},
	])
	if has_tex("portraits/eyes_detail_%s" % eyes):
		L.append({"tex": "portraits/eyes_detail_%s" % eyes, "tint": Color.WHITE, "frames": 4})
	L.append_array([
		{"tex": "portraits/brows_%s" % app.get("brows", "straight"), "tint": hc, "frames": 4},
		{"tex": "portraits/mouth_%s" % app.get("mouth", "smile"), "tint": Color.WHITE, "frames": 4},
		{"tex": "portraits/hair_%s_front" % hair, "tint": hc, "frames": 1},
	])
	var acc: String = app.get("accessory", "none")
	if acc != "none" and has_tex("portraits/acc_" + acc):
		L.append({"tex": "portraits/acc_" + acc, "tint": Color.WHITE, "frames": 1})
	return L


## Outfits sold before their art exists (options.json → outfits_shop[].stand_in) are drawn as a tinted existing
## outfit, so Threadline works now and the real sheets take over as soon as `probe % outfit` exists.
## Explicit tints win over the stand-in's. Returns [outfit, tints].
func _resolve_outfit(outfit: String, probe: String, tints: Dictionary) -> Array:
	if has_tex(probe % outfit):
		return [outfit, tints]
	var st: Dictionary = DataDB.character_option("outfits_shop", outfit).get("stand_in", {})
	if st.is_empty():
		return [outfit, tints]
	var t := {}
	for k in st.get("tints", {}):
		t[k] = Color(st["tints"][k])
	t.merge(tints, true)
	return [str(st["outfit"]), t]


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


## No skin-like tans here: a tan tee on a seated customer reads as a bare chest.
const CLOTH_TINTS := [Color8(70, 110, 170), Color8(200, 90, 80), Color8(90, 150, 110), Color8(230, 200, 120), Color8(140, 110, 180),
	Color8(60, 60, 70), Color8(220, 220, 226), Color8(120, 150, 190), Color8(70, 140, 140), Color8(100, 100, 120)]


## Suits come in suit colours, jacket and trousers matching (the fabric is dyeable since art batch R1).
const SUIT_TINTS := [Color8(58, 61, 68), Color8(44, 62, 102), Color8(184, 188, 196), Color8(110, 46, 58), Color8(92, 74, 60),
	Color8(34, 36, 42), Color8(120, 124, 134)]


func random_outfit_tints(rng: RandomNumberGenerator, outfit := "") -> Dictionary:
	var shop := DataDB.character_option("outfits_shop", outfit)
	if not shop.is_empty():
		# store-bought looks keep their own colours; `npc_tops` lets passers-by vary the coat
		var tops: Array = shop.get("npc_tops", [])
		return {} if tops.is_empty() else {"top": Color(str(tops[rng.randi_range(0, tops.size() - 1)]))}
	if outfit == "business_suit":
		var c: Color = SUIT_TINTS[rng.randi_range(0, SUIT_TINTS.size() - 1)]
		return {"top": c, "bottom": c}
	return {"top": CLOTH_TINTS[rng.randi_range(0, CLOTH_TINTS.size() - 1)],
		"bottom": [Color8(60, 80, 130), Color8(50, 52, 60), Color8(120, 110, 100), Color8(80, 90, 110)][rng.randi_range(0, 3)]}
