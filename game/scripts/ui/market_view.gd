class_name MarketView
extends RefCounted
## Kept separate from Company OS to minimize overlap with the industry framework's tab work.


static func render(owner: CompanyOS) -> void:
	var content := owner.content
	content.add_child(UIK.label_tip("Market conditions", "macro_cycle", 9, Art.C_GOLD))
	if not Macro.active():
		content.add_child(UIK.wrap("✗ Market history is not initialized — enter the city to begin tracking.", 8, Art.C_MUTED, 440))
		return
	content.add_child(UIK.wrap(I18n.t("%s · base rate %s · price level %.2f × baseline") % [I18n.t(Macro.phase()), Fmt.pct(Macro.rate(), 2), Macro.costs()], 8, Art.C_SKY, 440))
	content.add_child(UIK.label_tip("Market share", "market_competition"))
	var industries: Array = Industries.all().map(func(entry): return str(entry["id"]))
	industries.sort()
	for industry in industries:
		var definition: Dictionary = DataDB.businesses[industry]
		content.add_child(UIK.label(str(definition.get("name", industry)), 9, Art.C_GOLD))
		var share := Rivals.shares(industry)
		content.add_child(UIK.wrap(I18n.t("Your share %s · other firms %s · demand %.2f × baseline") % [Fmt.pct(float(share["player"]), 1), Fmt.pct(float(share["outside"]), 1), Macro.demand(industry)], 8, Art.C_SKY, 440))
		for rival in Rivals.companies(industry):
			content.add_child(UIK.wrap(I18n.t("%s · %s · %s share · %s cash · %d locations") % [rival["name"], strategy(str(rival["strategy"])), Fmt.pct(float(share[rival["id"]]), 1), Fmt.money0(float(rival["cash"])), int(rival["locations"])], 8, Art.C_WHITE, 440))
			content.add_child(UIK.wrap(str(rival["last"]), 7, Art.C_MUTED, 440))
			if rival["status"] == "active" and Clock.day_index() >= int(Rivals.cfg()["acquire_after_days"]) and GameState.company_id() != "" and not Acquisition.sold():
				var id := str(rival["id"])
				var button := UIK.button(I18n.t("Acquire %s for %s") % [rival["name"], Fmt.money(Rivals.acquire_price(id))], func():
					var result := Acquisition.buy_rival(id)
					if not result["ok"]:
						UIRoot.toast(str(result["error"]), "warn", "info")
					owner.rebuild())
				button.name = "AcquireRival_" + id
				content.add_child(button)
	content.add_child(UIK.label_tip("City news", "macro_cycle", 9, Art.C_GOLD))
	var items: Array = CityNews.S()["items"]
	for index in range(items.size() - 1, maxi(-1, items.size() - 7), -1):
		content.add_child(UIK.wrap(Clock.fmt_short(int(items[index]["t"])) + " · " + str(items[index]["text"]), 8, Art.C_WHITE, 440))


static func strategy(id: String) -> String:
	match id:
		"low_price": return I18n.t("Low price")
		"quality": return I18n.t("High quality")
	return I18n.t("Expansion strategy")
