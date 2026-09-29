class_name ClothingShopModal
extends Modal
## A clothing store's rails (Threadline, Shopping Street): see an outfit on yourself, buy it, wear it.
## Cosmetic only (Handoff §2.1). Items: options.json → outfits_shop with this store.

const TURN := ["down", "right", "up", "left"]

var store := ""
var sel := ""
var preview: CharacterRig
var _turn_t := 0.0
var _turn_i := 0


func _init(store_id := "threadline_apparel") -> void:
	store = store_id
	title_text = str(DataDB.building(store).get("name", "Store"))
	icon_name = "shirt"
	help_key = "clothing_shop"
	panel_size = Vector2(452, 238)


func build() -> void:
	var items := Wardrobe.shop_items(store)
	if items.is_empty():
		body.add_child(UIK.label("Nothing on the rails today.", 8, Art.C_MUTED))
		footer.add_child(UIK.button("Close", close))
		return
	if Wardrobe.item(sel).is_empty():
		sel = items[0]["id"]
	var it := Wardrobe.item(sel)
	var h := UIK.hbox(10)
	body.add_child(h)
	var pb := WardrobeModal.preview_box(GameState.data["player"]["appearance"], sel, 3)
	preview = pb[1]
	preview.set_dir(TURN[_turn_i])
	h.add_child(pb[0])
	var v := UIK.vbox(3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UIK.label("THE COLLECTION", 7, Art.C_DIM, true))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	for o in items:
		var tag := I18n.t("owned") if Wardrobe.owns(o["id"]) else Fmt.money0(float(o["price"]))
		var b := UIK.button("%s · %s" % [I18n.t(o["name"]), tag], _select.bind(o["id"]), "tab_active" if o["id"] == sel else "tab", 150)
		b.name = "Item_" + o["id"]
		grid.add_child(b)
	v.add_child(grid)
	v.add_child(UIK.sep())
	v.add_child(UIK.label(I18n.t(it["name"]), 10, Art.C_WHITE, true))
	v.add_child(UIK.wrap(I18n.t(it.get("blurb", "")), 7, Art.C_MUTED, 280))
	v.add_child(UIK.kv("Price", Fmt.money(float(it["price"])), Art.C_GOLD))
	v.add_child(UIK.kv("Your cash", Fmt.money(Ledger.cash("player")), UIK.money_color(Ledger.cash("player"))))
	footer.add_child(UIK.button("Close", close))
	if Wardrobe.owns(sel):
		var w := UIK.button("Wearing it" if Wardrobe.wearing() == sel else "Wear it now", _wear, "primary")
		w.name = "Wear"
		w.disabled = Wardrobe.wearing() == sel
		footer.add_child(w)
	else:
		var why := Wardrobe.buy_block(sel)
		var b2 := UIK.button(I18n.t("Buy — %s") % Fmt.money(float(it["price"])) if why == "" else I18n.t(why), _buy, "primary")
		b2.name = "Buy"
		b2.disabled = why != ""
		footer.add_child(b2)


func _process(delta: float) -> void:
	_turn_t += delta
	if _turn_t > 1.4 and preview != null and is_instance_valid(preview):
		_turn_t = 0.0
		_turn_i = (_turn_i + 1) % TURN.size()
		preview.set_dir(TURN[_turn_i])


func _select(id: String) -> void:
	sel = id
	rebuild()


func _buy() -> void:
	var it := Wardrobe.item(sel)
	if Wardrobe.buy(sel):
		UIRoot.toast(I18n.t("Bought: %s. It's in your wardrobe.") % I18n.t(it["name"]), "good", "shirt")
	rebuild()


func _wear() -> void:
	Wardrobe.wear(sel)
	rebuild()
