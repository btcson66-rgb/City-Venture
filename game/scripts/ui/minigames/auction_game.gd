class_name AuctionGame
extends MiniGame
## Live bidding against three bidders with private ceilings. Each poll tick they may raise; enough quiet
## ticks and the hammer falls. The sale itself is settled by Automotive, so the result is real money.
var lot_id := ""
var elapsed := 0.0
var stopped := false
var settled := false
var outcome := {}
var bid_label: Label
var leader_label: Label
var going_label: Label
var bid_button: Button

func _init(lot: String) -> void:
	super._init()
	lot_id = lot
	rounds = 1
	round_time = 0
	title_text = "Auction"
	help_key = "auction"
	icon_name = "metro"
func lot() -> Dictionary:
	return Automotive.S()["lots"].get(lot_id, {})
func intro_lines() -> Array:
	return ["Bid against live bidders. Press Bid to raise; stop bidding when the price passes what the car is worth to you.", "The buyer fee is added to the hammer price. Hidden defects are not shown unless Jun inspected the car."]
func build_round() -> void:
	var box := UIK.vbox(6)
	box.position = Vector2(10, 8)
	box.size = Vector2(550, 220)
	stage.add_child(box)
	var current := lot()
	var car: Dictionary = current["car"]
	box.add_child(UIK.wrap(I18n.t("%s · %d years · %s km · market %s") % [I18n.t(car["name"]), int(car["age"]), Fmt._group(int(car["km"])), Fmt.money0(Automotive.true_value(car) if bool(current["inspected"]) else Automotive.visible_value(car))], 10, Art.C_GOLD, 520))
	bid_label = UIK.label("", 14, Art.C_WHITE, true)
	bid_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(bid_label)
	leader_label = UIK.label("", 9, Art.C_SKY)
	leader_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(leader_label)
	going_label = UIK.label("", 9, Art.C_MUTED)
	going_label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	box.add_child(going_label)
	bid_button = UIK.button("Bid", bid, "primary")
	bid_button.name = "AuctionBid"
	box.add_child(bid_button)
	var stop := UIK.button("Stop bidding", stop_bidding)
	stop.name = "AuctionStop"
	box.add_child(stop)
	refresh_labels()
func refresh_labels() -> void:
	var current := lot()
	if current.is_empty() or bid_label == null or not is_instance_valid(bid_label): return
	var leader := str(current["leader"])
	bid_label.text = I18n.t("Current bid %s") % Fmt.money0(current["bid"]) if float(current["bid"]) > 0 else I18n.t("Opening bid %s") % Fmt.money0(current["open"])
	var who := I18n.t("You") if leader == "player" else ""
	for bidder in current["bidders"]:
		if bidder["id"] == leader: who = I18n.t(bidder["name"])
	leader_label.text = I18n.t("High bidder: %s · with fee %s") % [who, Fmt.money0(float(current["bid"]) + Automotive.buyer_fee(float(current["bid"])))] if who != "" else I18n.t("No bids yet.")
	var polls := int(Automotive.auction()["silent_polls"])
	going_label.text = [I18n.t("Bidding is open."), I18n.t("Going once…"), I18n.t("Going twice…"), I18n.t("Last call…")][clampi(int(current["silent"]), 0, 3)] if polls <= 3 else ""
	bid_button.text = I18n.t("Bid %s") % Fmt.money0(Automotive.next_bid(current))
	bid_button.disabled = stopped or leader == "player"
func bid() -> void:
	var result := Automotive.auction_bid(lot_id)
	if not result["ok"]: flash(result["error"], false)
	refresh_labels()
func stop_bidding() -> void:
	stopped = true
	refresh_labels()
func _process(delta: float) -> void:
	super._process(delta)
	if phase != "play" or settled or lot().is_empty(): return
	elapsed += delta
	if elapsed < float(Automotive.auction()["poll_seconds"]): return
	elapsed = 0.0
	tick()
func tick() -> void:
	var result := Automotive.auction_step(lot_id)
	if result["ok"] and result["raised"] != "": flash(I18n.t("%s bids %s") % [I18n.t(result["raised"]), Fmt.money0(result["bid"])], false)
	refresh_labels()
	if result["ok"] and result["sold"]: settle()
func settle() -> void:
	if settled: return
	settled = true
	outcome = Automotive.auction_hammer(lot_id)
	var current := lot()
	var gain := 0.0
	if outcome.get("won", false):
		gain = clampf((Automotive.true_value(current["car"]) - float(outcome["price"])) / maxf(1.0, Automotive.true_value(current["car"])) / 0.25, 0.0, 1.0)
	award(gain)
	Clock.advance(int(Automotive.auction()["minutes"]))
	next_round()
func round_timeout() -> void:
	settle()
func result_lines() -> Array:
	if outcome.get("won", false):
		return [I18n.t("✓ Sold to you for %s plus the buyer fee. Inspect, recondition and list it from My lot.") % Fmt.money0(outcome["price"])]
	if float(outcome.get("price", 0)) > 0:
		return [I18n.t("✗ Another bidder won at %s. Next step: try another lot.") % Fmt.money0(outcome["price"])]
	return [I18n.t("✗ No sale. Next step: check the other lots.")]
func autoplay(quality := 0.9) -> void:
	super.autoplay(quality)
