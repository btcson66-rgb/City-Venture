class_name Help
extends RefCounted
## Every screen explains itself. A screen with a help key (Modal.help_key) shows its card the first time it opens and
## keeps a "?" button in its header to read it again. Texts: data/help/help.json ({key: {title, lines}}).
## Cards don't pop up while the guided first venture (Tutorial) is walking the player through; they wait until later.

static var auto := true      # bots and tests turn automatic cards off
static var _data := {}


static func data() -> Dictionary:
	if _data.is_empty():
		var d = DataDB._read("res://data/help/help.json")
		_data = d if typeof(d) == TYPE_DICTIONARY else {}
	return _data


static func has(key: String) -> bool:
	return data().has(key)


static func seen(key: String) -> bool:
	return GameState.has_game() and bool(GameState.data.get("help_seen", {}).get(key, false))


static func card(key: String) -> InfoModal:
	var h: Dictionary = data().get(key, {})
	var lines: Array = []
	for l in h.get("lines", []):
		lines.append("• " + I18n.t(str(l)))
	var m := InfoModal.make(I18n.t(str(h.get("title", "How it works"))), "info", lines, Vector2(400, 200))
	m.ok_text = "Got it"
	return m


static func open(key: String) -> void:
	if not has(key):
		return
	if GameState.has_game():
		if not GameState.data.has("help_seen"):
			GameState.data["help_seen"] = {}
		GameState.data["help_seen"][key] = true
	UIRoot.open_modal(card(key))


## The first time a screen opens (outside the guided tutorial), show its card.
static func show_once(key: String) -> void:
	if not auto or not has(key) or seen(key) or not GameState.has_game():
		return
	if UIRoot.tutorial != null and UIRoot.tutorial.is_active():
		return
	open(key)
