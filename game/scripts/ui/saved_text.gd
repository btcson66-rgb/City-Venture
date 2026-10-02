class_name SavedText
extends RefCounted
## Old ledger memos contain already formatted English. Translate their known
## catalogue template for display, keeping the original saved text untouched.
static var _patterns: Array = []
static var _cache := {}
static var _tokens := RegEx.create_from_string("%%|%[-+0-9.]*[sdif]")

static func _escape(text: String) -> String:
	var escaped := ""
	for character in text:
		escaped += ("\\" if character in "\\.^$|?*+()[]{}" else "") + character
	return escaped

static func _init_patterns() -> void:
	if not _patterns.is_empty(): return
	var catalogue: Translation = load("res://i18n/zh_TW.po")
	for source in catalogue.get_message_list():
		var matches := _tokens.search_all(source)
		if matches.is_empty(): continue
		var pattern := "^"
		var offset := 0
		var literal := 0
		var count := 0
		for token in matches:
			var part := source.substr(offset, token.get_start() - offset)
			literal += part.length()
			pattern += _escape(part)
			if token.get_string() == "%%": pattern += "%"
			else:
				count += 1
				pattern += "(.+?)" if token.get_string().ends_with("s") else "([+-]?[0-9,]+(?:\\.[0-9]+)?)"
			offset = token.get_end()
		pattern += _escape(source.substr(offset)) + "$"
		literal += source.length() - offset
		# Skip generic value-only UI formats; specific ledger descriptions win.
		if literal < 5 or count == 0: continue
		_patterns.append({"source": source, "regex": RegEx.create_from_string(pattern), "literal": literal, "count": count})
	_patterns.sort_custom(func(a, b): return a["literal"] > b["literal"])

static func display(text: String) -> String:
	if not I18n.is_zh(): return text
	if text == "Coffee — Bloom Coffee": return I18n.t("Coffee — Bloom Coffee")
	var translated := I18n.t(text)
	if translated != text: return translated
	var key := I18n.locale() + ":" + text
	if _cache.has(key): return _cache[key]
	_init_patterns()
	for template in _patterns:
		var match_text: RegExMatch = template["regex"].search(text)
		if match_text == null: continue
		var target := I18n.t(template["source"])
		if target == template["source"]: continue
		var pieces := _tokens.search_all(target)
		var count := pieces.filter(func(piece): return piece.get_string() != "%%").size()
		if count != int(template["count"]): continue
		var result := ""
		var offset := 0
		var arg := 1
		for piece in pieces:
			result += target.substr(offset, piece.get_start() - offset)
			if piece.get_string() == "%%": result += "%"
			else:
				result += I18n.t(match_text.get_string(arg))
				arg += 1
			offset = piece.get_end()
		result += target.substr(offset)
		_cache[key] = result
		return result
	_cache[key] = text
	return text
