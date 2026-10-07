class_name FeatureIntroModal
extends Modal
## A two-click rehearsal: no clock, cash, score or business effects.
var feature := ""
var step := 0
func _init(id: String) -> void:
	feature = id
	title_text = I18n.t(str(FeatureGate.definition(id).get("label", "Overview")))
	help_key = "feature_intro"
	pauses_time = true
	panel_size = Vector2(390,230)
func build() -> void:
	body.add_child(UIK.wrap(I18n.t("Practice: select the highlighted next action. Nothing is spent or changed." if step == 0 else "That is all. Choose one action at a time; details are there whenever you want them."), 9, Art.C_WHITE, 350))
	var next := UIK.button(I18n.t("Try the next action" if step == 0 else "Ready to explore"), func():
		if step == 0:step = 1;rebuild()
		else:
			if feature not in FeatureGate.state()["guided"]:FeatureGate.state()["guided"].append(feature)
			close(), "primary")
	next.name = "FeaturePracticeNext"
	body.add_child(next)
	var skip := UIK.button(I18n.t("Skip this guide"), func():
		if feature not in FeatureGate.state()["guided"]:FeatureGate.state()["guided"].append(feature)
		close())
	skip.name = "FeaturePracticeSkip"
	footer.add_child(skip)
