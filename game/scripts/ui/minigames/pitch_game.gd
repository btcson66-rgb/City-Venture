class_name PitchGame
extends MiniGame
## The investor pitch (#116). First build the deck: for each slide pick one figure read from the company's own
## books (nothing can be typed in or invented), most important first. Then answer the investor's questions.
## The game only collects the picks; Fundraising.pitch() validates them against the books and prices the round.

var deal_id := ""
var investor := ""
var picks: Array = []
var answers: Array = []
var facts: Array = []
var asked: Array = []
var deck_n := 0


func _init(deal: String) -> void:
	super._init()
	deal_id = deal
	investor = str(Fundraising.get_deal(deal)["investor"])
	facts = Fundraising.facts()
	asked = Fundraising.questions(investor)
	deck_n = mini(int(Fundraising.cfg()["deck_slots"]), facts.size())
	rounds = deck_n + asked.size()
	title_text = I18n.t("Pitch to %s") % Fundraising.name_of(investor)
	help_key = "pitch_game"
	icon_name = "finance"
	panel_size = Vector2(600, 330)


func intro_lines() -> Array:
	var gate := str(Fundraising.N()["impression"].get(investor, "neutral"))
	return [Fundraising.impression_line(Fundraising.name_of(investor), gate),
		"Build the deck from the figures in your real books. The first slide counts most, so lead with what matters to this investor.",
		"Then answer the investor's questions. An answer is only backed when your deck holds a figure that supports it."]


func round_name() -> String:
	return "Slide or question %d / %d"


func build_round() -> void:
	var v := UIK.vbox(5)
	v.position = Vector2(8, 4)
	v.size = Vector2(560, 228)
	stage.add_child(v)
	if round_i < deck_n:
		_slide(v)
	else:
		_question(v)


func _slide(v: VBoxContainer) -> void:
	v.add_child(UIK.wrap(I18n.t("Slide %d of %d: choose the figure to show.") % [round_i + 1, deck_n], 9, Art.C_SKY, 540))
	var grid := UIK.vbox(3)
	v.add_child(UIK.scroll(grid, Vector2(550, 190)))
	for f in facts:
		if f["id"] in picks:
			continue
		var text := "%s: %s" % [I18n.t(str(f["label"])), str(f["text"])]
		var b := UIK.button(text, _pick.bind(str(f["id"])))
		b.name = "DeckFact_" + str(f["id"])
		grid.add_child(b)


func _pick(id: String) -> void:
	if id in picks:
		return
	picks.append(id)
	var f := Fundraising.fact(id)
	var interest: Dictionary = Fundraising.cfg()["personalities"][str(Fundraising.inv(investor)["personality"])]["interest"]
	award(float(f.get("strength", 0.0)) * float(interest.get(str(f.get("category", "")), 0.5)))
	next_round()


func _question(v: VBoxContainer) -> void:
	var q: Dictionary = asked[round_i - deck_n]
	v.add_child(UIK.wrap("%s: \"%s\"" % [Fundraising.name_of(investor), I18n.t(str(q["text"]))], 10, Art.C_SKY, 540))
	var deck: Array = picks.map(func(id): return Fundraising.fact(str(id)))
	for option in q["options"]:
		var style := str(option["style"])
		var backed := Fundraising.answer_supported(style, deck)
		var tag := I18n.t("Backed by your deck") if backed else I18n.t("No figure in your deck backs this")
		var b := UIK.button("%s\n%s" % [I18n.t(str(option["label"])), tag], _answer.bind(style, backed))
		b.name = "Answer_" + style
		v.add_child(b)


func _answer(style: String, backed: bool) -> void:
	answers.append(style)
	award(1.0 if backed else 0.4)
	next_round()


func extra_result() -> Dictionary:
	return {"picks": picks, "answers": answers}


func result_lines() -> Array:
	return [I18n.t("The pitch is done. The investor now weighs the deck against your books; the term sheet, or a polite no, follows.")]


## Bots and tests: lead with the strongest figures and give the first answer of each question.
func autoplay(_quality := 0.9) -> void:
	var order := facts.duplicate()
	order.sort_custom(func(a, b): return float(a["strength"]) > float(b["strength"]))
	picks = order.slice(0, deck_n).map(func(f): return str(f["id"]))
	answers = asked.map(func(q): return str(q["options"][0]["style"]))
	round_i = rounds
	points = float(rounds)
	_finish()
