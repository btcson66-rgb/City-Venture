extends RefCounted
## Localization: catalogues load, templates keep their placeholders, dates/plurals follow the locale,
## and switching language never changes game data (logic stays on English source text).

var runner


func _with(loc: String, body: Callable) -> void:
	var before := TranslationServer.get_locale()
	I18n.init()
	TranslationServer.set_locale(loc)
	body.call()
	TranslationServer.set_locale(before)


func test_catalogues_load_and_translate() -> void:
	_with("zh_TW", func():
		runner.eq(I18n.t("New Game"), "新遊戲", "zh_TW: menu")
		runner.eq(I18n.t("Wireless Earbuds"), "無線耳機", "zh_TW: product name")
		runner.eq(I18n.t("Riverside"), "河濱區", "zh_TW: district"))
	_with("zh_CN", func():
		runner.eq(I18n.t("New Game"), "新游戏", "zh_CN: menu")
		runner.eq(I18n.t("Software"), "软件", "zh_CN: Mainland phrasing"))
	_with("en", func():
		runner.eq(I18n.t("New Game"), "New Game", "en: source text"))


func test_templates_keep_values_and_plurals() -> void:
	_with("zh_TW", func():
		var s := I18n.t("Pack %d order%s (%s)") % [3, I18n.pl(3), Fmt.duration_min(24)]
		runner.eq(s, "打包 3 筆訂單（24 分鐘）", "zh template + plural + duration")
		var f := EventEngine.fill("{customer}: I paid {price} for this.", {"customer": "Ben D.", "price": "$38.99"})
		runner.eq(f, "Ben D.：我可是付了 $38.99。", "event template translated before filling"))
	_with("en", func():
		runner.eq(I18n.t("Pack %d order%s (%s)") % [1, I18n.pl(1), "8 min"], "Pack 1 order (8 min)", "en singular")
		runner.eq(I18n.t("Pack %d order%s (%s)") % [2, I18n.pl(2), "16 min"], "Pack 2 orders (16 min)", "en plural"))


func test_dates_follow_locale() -> void:
	var t := 840  # Sun, Jun 1 2:00 PM
	_with("zh_TW", func():
		runner.eq(Clock.fmt_date(t), "6月1日（週日）", "zh date")
		runner.eq(Clock.fmt_time(t), "下午 2:00", "zh time"))
	_with("en", func():
		runner.eq(Clock.fmt_date(t), "Sun, Jun 1", "en date")
		runner.eq(Clock.fmt_time(t), "2:00 PM", "en time"))


func test_language_switch_does_not_touch_game_data() -> void:
	var name_before: String = DataDB.product("wireless_earbuds")["name"]
	_with("zh_TW", func():
		runner.eq(DataDB.product("wireless_earbuds")["name"], name_before, "data stays English under zh_TW")
		runner.check(Ecommerce.buy("tradelink_wholesale", "wireless_earbuds", 50)["ok"], "gameplay works in Chinese"))


func test_chinese_company_name_registers() -> void:
	runner.eq(Company.validate_name("河光商行"), "", "Chinese company name is valid")
	runner.check(Company.slug("河光商行").begins_with("u"), "ASCII-safe id for a Chinese name")
	runner.check(Company.slug("Riverlight Goods") == "riverlight_goods", "English ids unchanged")


## The web build has no system fonts to fall back on: Chinese text drawn with a bare font file shows as hex boxes.
## Only the font setup may touch Art.font_body / Art.font_title; everything else uses the UIK wrappers.
func test_no_text_drawn_with_a_bare_font_file() -> void:
	var allowed := ["res://autoload/art.gd", "res://scripts/ui/uik.gd", "res://scripts/ui/i18n.gd"]
	var bad: Array = []
	for path in _scripts("res://scripts") + _scripts("res://autoload"):
		if path in allowed:
			continue
		var src := FileAccess.get_file_as_string(path)
		for bare in ["Art.font_body", "Art.font_title"]:
			if src.contains(bare):
				bad.append(path + " uses " + bare)
	runner.eq(bad, [], "text uses the UIK font wrappers (they carry the CJK fallback)")
	for v in [UIK.body_font(), UIK.bold_font(), UIK.title_font(), UIK.num_font()]:
		runner.check(not (v as FontVariation).fallbacks.is_empty(), "every UI font has a CJK fallback")


func _scripts(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_scripts(dir + "/" + d))
	return out
