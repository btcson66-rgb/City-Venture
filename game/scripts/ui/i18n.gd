class_name I18n
extends RefCounted
## Localization. Source text is English; translations are gettext catalogues in res://i18n/<locale>.po.
## Plain Label/Button text is translated automatically by Godot (exact match). Templates with values
## go through I18n.t() before formatting; data stays English so logic and saves are language-neutral.

const LOCALES := [["en", "English"], ["zh_TW", "繁體中文"], ["zh_CN", "简体中文"]]
const SETTINGS := "user://settings.cfg"
const CJK_FONTS := {"zh_TW": "res://assets/fonts/NotoSansTC-Regular-subset.ttf", "zh_CN": "res://assets/fonts/NotoSansSC-Regular-subset.ttf"}

static var _ready_done := false
static var _fonts := {}


static func init() -> void:
	if _ready_done:
		return
	_ready_done = true
	for l in LOCALES:
		var path := "res://i18n/%s.po" % l[0]
		if l[0] != "en" and ResourceLoader.exists(path):
			TranslationServer.add_translation(load(path))
	var loc := ""
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS) == OK:
		loc = str(cfg.get_value("general", "locale", ""))
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			loc = a.substr(7)
	if loc == "":
		var os_loc := OS.get_locale()
		if os_loc.begins_with("zh"):
			loc = "zh_CN" if (os_loc.contains("CN") or os_loc.contains("SG") or os_loc.contains("Hans")) else "zh_TW"
		else:
			loc = "en"
	set_locale(loc, false)


static func set_locale(loc: String, save := true) -> void:
	TranslationServer.set_locale(loc)
	_apply_fonts(loc)
	if save:
		var cfg := ConfigFile.new()
		cfg.load(SETTINGS)
		cfg.set_value("general", "locale", loc)
		cfg.save(SETTINGS)


static func locale() -> String:
	return TranslationServer.get_locale()


static func is_zh() -> bool:
	return locale().begins_with("zh")


static func locale_name(loc := "") -> String:
	if loc == "":
		loc = locale()
	for l in LOCALES:
		if loc.begins_with(l[0]):
			return l[1]
	return "English"


## Next language in the list (for a simple cycling selector).
static func next_locale() -> String:
	var cur := locale()
	for i in LOCALES.size():
		if cur.begins_with(LOCALES[i][0]) and (LOCALES[i][0] != "zh_TW" or cur.begins_with("zh_TW")) and (LOCALES[i][0] != "zh_CN" or cur.begins_with("zh_CN")):
			return LOCALES[(i + 1) % LOCALES.size()][0]
	return "en"


static func t(s: String) -> String:
	if s == "":
		return s
	return str(TranslationServer.translate(s))


## Translate each item and join with the locale's list separator ("a, b" / "a、b").
## `ids` = items are snake_case ids from data (product_sales -> "product sales").
static func join(items: Array, ids := false) -> String:
	var out: Array[String] = []
	for it in items:
		var s := str(it)
		if ids:
			s = s.replace("_", " ")
		out.append(t(s))
	return ("、" if is_zh() else ", ").join(out)


## English plural suffix; nothing in Chinese ("1 order" / "2 orders" vs "1 筆訂單" / "2 筆訂單").
static func pl(n: int, suffix := "s") -> String:
	if is_zh():
		return ""
	return suffix if n != 1 else ""


## CJK fallback glyphs for the Latin UI fonts (Traditional or Simplified shapes by locale).
static func _apply_fonts(loc: String) -> void:
	var order: Array = ["zh_CN", "zh_TW"] if loc.begins_with("zh_CN") else ["zh_TW", "zh_CN"]
	var fb: Array[Font] = []
	for k in order:
		if not _fonts.has(k) and ResourceLoader.exists(CJK_FONTS[k]):
			_fonts[k] = load(CJK_FONTS[k])
		if _fonts.has(k):
			fb.append(_fonts[k])
	# The CJK fallback raises every line's height (Godot takes the tallest font in the chain), which would
	# push English layouts ~30% taller. Negative spacing on the UI fonts pulls the line box back: English
	# keeps its original metrics; Chinese keeps a little extra room for the taller glyphs.
	var top := -1 if loc.begins_with("zh") else -2
	var bottom := -1
	# Pixelify has no arrows, checkmarks or stars: title text falls back to Inter before the CJK fonts
	var title_fb: Array[Font] = [Art.font_body]
	title_fb.append_array(fb)
	for v in [UIK.body_font(), UIK.bold_font(), UIK.title_font()]:
		var fv := v as FontVariation
		fv.fallbacks = title_fb if v == UIK.title_font() else fb
		fv.set_spacing(TextServer.SPACING_TOP, top)
		fv.set_spacing(TextServer.SPACING_BOTTOM, bottom)
