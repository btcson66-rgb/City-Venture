extends RefCounted
## Shopping Street (B1): the district and its four buildings load, Threadline sells outfits that land in the
## wardrobe and cost personal cash, store-bought outfits draw as a stand-in until their art exists, and the weekend
## market stalls are only out on Saturday and Sunday daytime.

var runner


func test_shopping_street_is_open_and_linked() -> void:
	runner.check(DataDB.districts.has("shopping_street"), "district data loads")
	runner.eq(str(DataDB.district_def_in_city("shopping_street").get("status", "")), "active", "open on the city map")
	var linked := false
	for ex in DataDB.districts["old_town"]["exits"]:
		linked = linked or ex["to"] == "shopping_street"
	runner.check(linked, "walkable from the canonical Old Town neighbor")
	for bid in ["threadline_apparel", "lantern_bistro", "crestline_flagship", "popup_unit"]:
		runner.eq(str(DataDB.building(bid).get("district", "")), "shopping_street", bid + " is on Shopping Street")
		runner.check(DataDB.buildings_meta.has(DataDB.building(bid)["exterior"]["sprite"]), bid + " has facade metadata")


func test_threadline_sells_into_the_wardrobe() -> void:
	runner.check(not Wardrobe.owns("executive"), "not owned at the start")
	runner.eq(Wardrobe.owned().size(), 3, "three starter outfits")
	var cash0 := Ledger.cash("player")
	runner.check(Wardrobe.buy("executive"), "bought")
	runner.check(Wardrobe.owns("executive"), "now owned")
	runner.check(absf(Ledger.cash("player") - (cash0 - 640.0)) < 0.01, "paid $640 from personal cash")
	runner.eq(Wardrobe.buy_block("executive"), "Owned", "can't buy it twice")
	runner.check(Wardrobe.wear("executive"), "can wear it")
	runner.eq(Wardrobe.wearing(), "executive", "wearing it")
	runner.check(not Wardrobe.wear("formal_evening"), "can't wear what you don't own")
	runner.check(Ledger.check_balanced(), "ledger balanced")


func test_broke_players_cannot_buy() -> void:
	Ledger.expense("player", "other", Ledger.cash("player") - 50.0, "test drain")
	runner.eq(Wardrobe.buy_block("travel"), "Not enough cash", "blocked when short")
	runner.check(not Wardrobe.buy("travel"), "no purchase")


func test_old_saves_get_a_wardrobe() -> void:
	GameState.data["player"].erase("wardrobe")
	GameState.data["player"]["outfit"] = "office_professional"
	runner.check(Wardrobe.owns("startup_casual") and Wardrobe.owns("home"), "starters restored")


func test_shop_outfits_use_their_own_art() -> void:
	var app := GameState.default_appearance()
	var pres := str(app.get("presentation", "masculine"))
	var L := Art.character_layers(app, "executive")
	var tops := L.filter(func(l): return l["name"] == "top")
	runner.eq(tops.size(), 1, "one top layer")
	runner.eq(str(tops[0]["tex"]), "characters/outfit_executive_%s_top" % pres, "executive uses its own sheet")
	for l in L:
		runner.check(Art.has_tex(str(l["tex"])), "layer exists: " + str(l["tex"]))
	for l in Art.portrait_layers(app, "formal_evening"):
		runner.check(Art.has_tex(str(l["tex"])), "portrait layer exists: " + str(l["tex"]))

func test_market_stalls_are_out_on_weekend_days_only() -> void:
	var stalls: Array = DataDB.districts["shopping_street"]["props"].filter(func(p): return p.has("show"))
	runner.eq(stalls.size(), 6, "six stalls")
	var w: Dictionary = stalls[0]["show"]
	while not (Clock.weekday() == 6 and Clock.hour() == 11):
		Clock.advance(60)
	runner.check(WorldScene.in_window(w), "Saturday 11:00: out")
	Clock.advance(9 * 60)
	runner.check(not WorldScene.in_window(w), "Saturday 20:00: packed away")
	while not (Clock.weekday() == 3 and Clock.hour() == 11):
		Clock.advance(60)
	runner.check(not WorldScene.in_window(w), "Wednesday: no market")


func test_undrawn_furniture_shows_its_stand_in_until_the_art_lands() -> void:
	var room := Interior.new()
	var shelf := {"sprite": "retail_shelf", "fallback": "shoe_shelf", "x": 0, "y": 0}
	runner.eq(room.prop_key(shelf), "interiors/shoe_shelf", "Crestline shelf drawn as the shoe shelf for now")
	runner.eq(room.prop_key({"sprite": "escalator", "x": 0, "y": 0}), "", "no stand-in: nothing drawn")
	Art._cache["interiors/retail_shelf"] = ImageTexture.create_from_image(Image.create(48, 48, false, Image.FORMAT_RGBA8))
	runner.eq(room.prop_key(shelf), "interiors/retail_shelf", "the real shelf once it exists")
	Art._cache.erase("interiors/retail_shelf")
	room.free()
