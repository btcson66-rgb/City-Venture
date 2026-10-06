class_name LegacyMentorModal
extends Modal
## A real hour at the co-work terminal; advice records time and topic, never phantom income.

func _init() -> void:
	title_text = "Mentor a new founder"
	icon_name = "people"
	panel_size = Vector2(430, 240)
	pauses_time = true

func build() -> void:
	body.add_child(UIK.wrap("A new founder at Nexus Co-work has enough cash for one batch. Discuss product pricing or inventory cash flow; either conversation takes one hour and pays no fee.", 8, Art.C_WHITE, 400))
	for topic in ["pricing", "inventory"]:
		var b := UIK.button("Discuss pricing and margin" if topic == "pricing" else "Discuss inventory and cash flow", func():
			Clock.advance(60)
			GameState.inc_stat("founders_mentored")
			LegacyBusiness.S()["mentor_topic"] = topic
			GameState.timeline(I18n.t("Mentored a founder at Nexus Co-work: %s, 1 hour.") % I18n.t("Pricing and margin" if topic == "pricing" else "Inventory and cash flow"), "business")
			close())
		b.name = "MentorTopic_" + topic
		body.add_child(b)
