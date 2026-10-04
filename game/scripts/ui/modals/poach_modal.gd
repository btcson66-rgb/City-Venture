class_name PoachModal
extends Modal
## Time keeps running; unacknowledged offers expire without permanently pausing the city.

var employee := ""


func _init(id := "") -> void:
	employee = id
	title_text = "Competing job offer"
	icon_name = "people"
	help_key = "poach"
	panel_size = Vector2(470, 260)


func _process(delta: float) -> void:
	super._process(delta)
	if Rivals.S().get("offers", {}).get(employee, {}).get("status", "") != "pending":
		close()


func build() -> void:
	var offer: Dictionary = Rivals.S().get("offers", {}).get(employee, {})
	if offer.is_empty():
		body.add_child(UIK.wrap("✗ Offer expired — return to your team.", 8, Art.C_MUTED, 430))
		return
	var rival: Dictionary = Rivals.S()["companies"][offer["rival"]]
	body.add_child(UIK.label_tip("Competing job offer", "market_competition"))
	body.add_child(UIK.wrap(I18n.t("%s has an offer from %s: %s per week. Respond by %s.") % [offer["name"], rival["name"], Fmt.money(float(offer["salary"])), Clock.fmt_short(int(offer["expires"]))], 9, Art.C_WHITE, 430))
	body.add_child(UIK.wrap("Retaining them increases future payroll. Letting them leave loses their work capacity. No answer means they leave when the offer expires.", 8, Art.C_SKY, 430))
	var keep := UIK.button(I18n.t("Match %s/week and retain") % Fmt.money(float(offer["salary"])), func(): Rivals.answer(employee, true); close())
	keep.name = "RetainEmployee"
	footer.add_child(keep)
	var leave := UIK.button("Let them take the job", func(): Rivals.answer(employee, false); close())
	leave.name = "ReleaseEmployee"
	body.add_child(leave)
