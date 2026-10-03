class_name InfoModal
extends Modal
## Simple readable content: news board, loan brochure, permits kiosk, whiteboard.

var lines: Array = []
var ok_text := "Close"


func _init() -> void:
	pauses_time = true   # reading: help cards, news, brochures


static func make(t: String, ic: String, ls: Array, size := Vector2(380, 220)) -> InfoModal:
	var m := InfoModal.new()
	m.title_text = t
	m.icon_name = ic
	m.lines = ls
	m.panel_size = size
	return m


func build() -> void:
	var v := UIK.vbox(4)
	for l in lines:
		if typeof(l) == TYPE_ARRAY:
			v.add_child(UIK.kv(str(l[0]), str(l[1]), l[2] if l.size() > 2 else Art.C_WHITE))
		elif str(l).begins_with("# "):
			# the catalogue has the whole line ("# YOU DID THE WHOLE LOOP"): translate it, then drop the marker
			var hd := I18n.t(str(l))
			v.add_child(UIK.label(hd.substr(2) if hd.begins_with("# ") else I18n.t(str(l).substr(2)), 8, Art.C_GOLD, true))
		elif str(l) == "---":
			v.add_child(UIK.sep())
		else:
			v.add_child(UIK.wrap(str(l), 8, Art.C_WHITE, 350))
	body.add_child(UIK.scroll(v, Vector2(360, panel_size.y - 70)))
	footer.add_child(UIK.button(ok_text, close, "primary" if ok_text != "Close" else "", 70))


## Shown when the guided first venture is done: what the player just did, and what else there is.
static func first_venture() -> InfoModal:
	var m := make("Your first business loop", "star", [
		"# YOU DID THE WHOLE LOOP",
		"Buy stock → shoot and list → sell → pack → ship → get paid. Then a job on the side, a shift, and a night's sleep.",
		"From now on the city runs at its own pace: stock takes a couple of days, and parcels 1–3 days to arrive.",
		"---",
		"# FROM HERE IT'S YOUR CALL",
		"• Grow the shop: more products, better photos, ads (Company OS → Sales).",
		"• Make it official: register a company at City Hall (Civic Center), then open a business account at Nexus Bank.",
		"• Keep your job and get promoted, or switch jobs: Business Board → Part-time jobs.",
		"• Take consulting work you do yourself: Company OS → Freelance.",
		"• Build a software product: SaaS on the Business Board.",
		"• Explore: Shopping Street is west of Civic Center.",
		"---",
		"Every screen has a ? button in its top corner that explains how it works. The gold arrow keeps pointing at your story goal."],
		Vector2(430, 262))
	m.ok_text = "Let's go"
	return m


static func news() -> InfoModal:
	Clock.advance(5)
	GameState.set_flag("news_read")   # keep the old key for existing saves
	GameState.set_flag("news_read_y%d" % World.year())
	if GameState.flag("fx_shock_started"):
		GameState.set_flag("fx_news_read")
	var y := DataDB.year_def(int(GameState.data["world"]["year"]))
	var ls: Array = [I18n.t("# AURELIA DAILY · Year %d — %s") % [int(y.get("year", 1)), I18n.t(str(y.get("name", "")))]]
	if GameState.flag("fx_shock_started"):
		ls.append(I18n.t("Exchange-risk briefing: Auroria fell %.0f%% at the start of this chapter. Unchanged local prices bring home less cash; compare repricing, forward hedging and home-currency invoices.") % (float(OverseasPartners.cfg()["shock"]["drop"]) * 100))
	for h in Rails.headlines(y):   # Year 7's headlines follow the bridge exploit
		ls.append("• " + I18n.t(str(h)))
	ls.append("---")
	ls.append("# MARKET NOTES")
	ls.append(I18n.t("• Base rate: %s. Credit is cheap — for now.") % Fmt.pct(float(y.get("interest_rate", 0.025)), 1))
	ls.append(I18n.t("• Shipping index: %.2f (1.00 = normal).") % float(y.get("shipping_index", 1.0)))
	if Rails.frozen():
		ls.append(I18n.t("• Digital-dollar bridge: FROZEN until about %s.") % Clock.fmt_short(Rails.frozen_until()))
	elif int(y.get("year", 1)) >= 6:
		ls.append("• Digital-dollar bridge: open.")
	ls.append("• ShopLane fee 10%. Payouts every Monday.")
	return make("News board", "info", ls)


static func whiteboard() -> InfoModal:
	var be := GameState.business_entity()
	var cur := MonthClose.current(be)
	return make("Whiteboard", "tasks", ["# IDEAS · PEOPLE · PRODUCT · GROWTH",
		["This month revenue", Fmt.money(cur["net_revenue"])], ["Gross profit", Fmt.money(cur["gross_profit"])],
		["Operating costs", Fmt.money(cur["opex_total"])], ["Cash in bank", Fmt.money(Ledger.cash(be))],
		["Waiting at ShopLane", Fmt.money(Ledger.balance(be, "marketplace_balance"))], "---",
		"Scribbled in the corner: 'profit is an opinion, cash is a fact.'"])
