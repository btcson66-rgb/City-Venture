class_name RunCardModal
extends Modal
## Simple scenario opening/result card; the unmerged life-review ticket can later supply its scoring view.

var opening := true


func _init(is_opening := true) -> void:
	opening = is_opening
	title_text = "Scenario opening" if opening else "Scenario result"
	icon_name = "star"
	panel_size = Vector2(480, 300)
	pauses_time = true
	closable = false
	help_key = "run_open" if opening else "run_result"


func build() -> void:
	var definition: Dictionary = Replay.S().get("scenario", {})
	body.add_child(UIK.title(str(definition.get("name", "")), 12, Art.C_SKY))
	body.add_child(UIK.wrap(str(definition.get("description", "")), 8, Art.C_WHITE, 410))
	body.add_child(UIK.wrap(str(definition.get("goal", "")), 8, Art.C_SKY, 410))
	if opening:
		body.add_child(UIK.kv("Deadline", Clock.fmt_datetime(int(Replay.S().get("deadline", Clock.now())))))
		body.add_child(UIK.kv("Seed", str(Replay.S().get("seed", 0))))
		for key in definition.get("win", {}):
			body.add_child(UIK.kv(_label(key), _format(key, float(Replay.metrics().get(key, 0))) + " / " + _format(key, float(definition["win"][key]))))
	else:
		Replay.record_result()
		var result: Dictionary = Replay.S().get("result", {})
		body.add_child(UIK.label("✓ " + I18n.t("Objective met — continue in sandbox") if result.get("status", "") == "won" else "✗ " + I18n.t("Objective missed — continue or try a new run"), 8, Art.C_SKY))
		for key in ["net_worth", "elapsed_days", "rating", "score"]:
			body.add_child(UIK.kv(_label(key), _format(key, float(result.get(key, 0)))))
		if str(Replay.S().get("week", "")) != "":
			body.add_child(UIK.wrap("✓ " + I18n.t("Local record saved — view it from new game setup") if Replay.S().get("recorded", false) else "✗ " + I18n.t("Local record could not be saved — check storage and retry"), 8, Art.C_MUTED, 410))
	var action := UIK.button("Begin scenario" if opening else "Continue in sandbox", func():
		Replay.S()["opening_seen" if opening else "result_seen"] = true
		close(), "primary")
	action.name = "BeginScenario" if opening else "ContinueScenario"
	footer.add_child(action)


static func _label(key: String) -> String:
	var labels := {"revenue": "Revenue", "cash": "Cash", "net_worth": "Net worth", "net_worth_gain": "Net worth gained", "elapsed_days": "Time played", "rating": "Rating", "runs": "Delivery runs", "shifts": "Work shifts", "score": "Challenge score"}
	return str(labels.get(key, key))


static func _format(key: String, value: float) -> String:
	if key in ["cash", "net_worth", "net_worth_gain", "revenue"]:
		return Fmt.money0(value)
	match key:
		"elapsed_days": return I18n.t("%.1f days") % value
		"rating": return I18n.t("No rating yet") if value < 0 else I18n.t("%.2f / 5 stars") % value
		"score": return I18n.t("%d points") % roundi(value)
		"runs": return I18n.t("%d runs") % roundi(value)
		"shifts": return I18n.t("%d shifts") % roundi(value)
	return str(value)
