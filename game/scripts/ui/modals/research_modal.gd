class_name ResearchModal
extends Modal
var product := ""

func _init() -> void:
	title_text="Crestline competitor research"
	icon_name="info"
	help_key="market_research"
	panel_size=Vector2(480,300)

func build() -> void:
	body.add_child(UIK.label_tip("Competitor research","market_research"))
	if product=="":
		var ids := ShopLife.products()
		if ids.is_empty(): body.add_child(UIK.wrap("✗ Own or list a product — buy stock or create a listing first.",9,Art.C_GOLD,440))
		for index in ids.size():
			var id: String=ids[index]
			var button := UIK.button(I18n.t("Research %s · 30 minutes; cached results are free")%I18n.t(DataDB.product(id)["name"]),inspect.bind(id),"primary" if index==0 else "")
			button.name="Research_"+id
			body.add_child(button)
	else:
		var card: Dictionary=ShopLife.S()["research"][product]
		body.add_child(UIK.kv("Crestline shelf price",Fmt.money(float(card["price"]))))
		body.add_child(UIK.wrap("Brand positioning, warranty and packaging support this premium price.",9,Art.C_WHITE,440))
		var listing := Ecommerce.listing_for(product)
		if not listing.is_empty():
			body.add_child(UIK.kv("Your unit price",Fmt.money(float(listing["price"]))))
			body.add_child(UIK.kv("Your price tier",I18n.t(ShopLife.tier(product))))
			var gap := float(card["price"])-float(listing["price"])
			body.add_child(UIK.wrap(I18n.t("You are %s below the large brand. Consider price carefully; better reviews and packaging can also win customers.")%Fmt.money(gap),8,Art.C_SKY,440) if gap>=0 else UIK.wrap("You cost more than Crestline. Explain your quality and warranty, or review the price.",8,Art.C_SKY,440))
		else: body.add_child(UIK.wrap("No selling price yet — create a listing.",8,Art.C_SKY,440))
		body.add_child(UIK.wrap(I18n.t("✓ Saved until %s — return to your terminal to review pricing.")%Clock.fmt_short(int(card["until"])),8,Art.C_MUTED,440))
		var back := UIK.button("Return to the store",close,"primary")
		back.name="ResearchDone"
		footer.add_child(back)
	if product=="": footer.add_child(UIK.button("Close",close))

func inspect(id: String) -> void:
	var result := ShopLife.research(id)
	if not result["ok"]: UIRoot.toast(result["error"],"warn","info");return
	product=id
	rebuild()
