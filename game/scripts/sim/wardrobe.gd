class_name Wardrobe
extends RefCounted
## Clothes the player owns and what they wear. Cosmetic only (Handoff §2.1): no outfit changes a number.
## Starter outfits come from the character creator; the rest are bought at Threadline (Shopping Street),
## options.json → outfits_shop.

const STARTERS := ["startup_casual", "office_professional", "home"]


static func owned() -> Array:
	var p: Dictionary = GameState.data["player"]
	if not p.has("wardrobe"):
		p["wardrobe"] = STARTERS.duplicate()   # saves from before the wardrobe existed
	var cur: String = p.get("outfit", "startup_casual")
	if not cur in p["wardrobe"]:
		p["wardrobe"].append(cur)
	return p["wardrobe"]


static func owns(id: String) -> bool:
	return id in owned()


static func wearing() -> String:
	return str(GameState.data["player"].get("outfit", "startup_casual"))


## Every outfit the player can wear or buy, with a display name: [{id, name, price?, blurb?}].
static func catalogue() -> Array:
	var out: Array = []
	for o in DataDB.character.get("outfits", []):
		out.append(o)
	for o in DataDB.character.get("outfits_shop", []):
		out.append(o)
	return out


static func item(id: String) -> Dictionary:
	for o in catalogue():
		if o["id"] == id:
			return o
	return {}


static func shop_items(store: String) -> Array:
	return DataDB.character.get("outfits_shop", []).filter(func(o): return str(o.get("store", "")) == store)


## Dress code (#116): casual < business < formal. It only decides which events you can enter and how a first
## conversation opens; no outfit changes a number.
static func dress_of(id: String) -> String:
	var it := item(id)
	return str(it.get("dress", "casual"))


static func rank_of(level: String) -> int:
	var levels: Array = Fundraising.cfg()["dress_levels"]
	for i in levels.size():
		if levels[i]["id"] == level:
			return i
	return 0


static func dress_rank(id: String) -> int:
	return rank_of(dress_of(id))


## "" when the purchase can go ahead, else the reason shown on the button.
static func buy_block(id: String) -> String:
	var it := item(id)
	if it.is_empty() or not it.has("price"):
		return "Not sold here"
	if owns(id):
		return "Owned"
	if Ledger.cash("player") < float(it["price"]):
		return "Not enough cash"
	return ""


static func buy(id: String) -> bool:
	if buy_block(id) != "":
		return false
	var it := item(id)
	var store := DataDB.building(str(it.get("store", "")))
	Ledger.expense("player", "clothing", float(it["price"]), "%s — %s" % [store.get("name", "Store"), I18n.t(it["name"])], {"type": "purchase"})
	owned().append(id)
	GameState.inc_stat("outfits_bought")
	GameState.timeline(I18n.t("Bought the %s outfit at %s.") % [I18n.t(it["name"]), I18n.t(store.get("name", ""))])
	return true


static func wear(id: String) -> bool:
	if not owns(id):
		return false
	GameState.data["player"]["outfit"] = id
	var ws := SceneRouter.world_scene()
	if ws != null and ws.player != null:
		ws.player.refresh_appearance()
	return true
