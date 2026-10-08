class_name FeatureIntroModal
extends Control
## A quiet first-use hint, not a modal: it outlines one control inside the open screen (the same sky-blue outline
## the minigame practice uses) with a one-line hint. One or two steps, skippable, never pauses the clock, shown once per
## feature. Nothing is spent or changed. Bots dismiss it with the stable "FeaturePracticeSkip" button.
const CARD := "FeatureIntroCard"
static var _industry_definitions := {}
static func industry_definitions() -> Dictionary:
	if _industry_definitions.is_empty():_industry_definitions = DataDB._read("res://data/help/industry_intros.json")
	return _industry_definitions

static func industry_for_tab(tab: String) -> String:
	for industry in Industries.all():
		if industry["sim_class"].os_tab().get("id", "") == tab:return str(industry["id"])
	return ""

func industry_steps() -> Array:
	return industry_definitions().get(feature.trim_prefix("industry_"), {}).get("steps", []) if feature.begins_with("industry_") else []

var feature := ""
var host: Control
var step := 0
var _target: Control
var _card: PanelContainer
var _hint: Label
var _next: Button


func _init(id := "") -> void:
	feature = id
	name = "FeatureIntro"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Show the hint inside `screen` (a Company OS style screen with `Tab_<id>` buttons and a `content` column).
static func show_in(screen: Control, id: String) -> FeatureIntroModal:
	if screen == null or not is_instance_valid(screen):return null
	dismiss_in(screen)
	var intro := FeatureIntroModal.new(id)
	intro.host = screen
	screen.add_child(intro)
	return intro


static func dismiss_in(screen: Node) -> void:
	for child in screen.get_children():
		if child is FeatureIntroModal:
			child.finish()


## Closes every visible hint (used by bots so a hint can never stand in their way).
static func dismiss_all(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group("feature_intro"):
		if node is FeatureIntroModal:node.finish()


func _ready() -> void:
	add_to_group("feature_intro")
	_mark_guided()
	_card = UIK.panel("ui/panel", 4)
	_card.name = CARD
	var box := UIK.vbox(2)
	_hint = UIK.wrap("", 8, Art.C_WHITE, 190)
	box.add_child(_hint)
	var row := UIK.hbox(4)
	_next = UIK.button("", _advance, "" if feature.begins_with("industry_") else "primary")
	_next.name = "FeaturePracticeNext"
	_next.custom_minimum_size = Vector2(60, 28)
	row.add_child(_next)
	var skip := UIK.button(I18n.t("Skip this guide"), finish)
	skip.name = "FeaturePracticeSkip"
	skip.custom_minimum_size = Vector2(60, 28)
	row.add_child(skip)
	box.add_child(row)
	_card.add_child(box)
	add_child(_card)
	_show_step()


func _mark_guided() -> void:
	if feature != "" and feature not in FeatureGate.state()["guided"]:FeatureGate.state()["guided"].append(feature)


## Step 0 outlines the tab itself, step 1 the first real action on it (when there is one).
func _find_target(index: int) -> Control:
	if not industry_steps().is_empty():
		if index >= industry_steps().size():return null
		var target: String = industry_steps()[index]["target"]
		if target == "@tab":return host.find_child("Tab_"+host.tab,true,false) as Control if host is CompanyOS else null
		if target != "@primary":return host.find_child(target, true, false) as Control
		var controls: Node = host.content if host is CompanyOS else host
		var fallback: Button
		for button in controls.find_children("*", "Button", true, false):
			if button.disabled or not button.is_visible_in_tree() or button is CheckBox:continue
			if button.name == "FeatureGuideReplay" or button.name == "IndustryGuideReplay" or button.name == "Help" or button.name == "Close":continue
			if fallback == null:fallback = button
			if button.get_meta("calm_primary", false) or button.get_meta("primary_action", false):return button
		return fallback
	var tab_id := feature.trim_prefix("os_")
	if index == 0:
		var tab := host.find_child("Tab_" + tab_id, true, false) as Control
		return tab
	var content = host.get("content")
	if content == null or not is_instance_valid(content):return null
	for button in content.find_children("*", "Button", true, false):
		if button is CheckBox or button.disabled or not button.is_visible_in_tree():continue
		if button.name in ["FeatureGuideReplay", "Help", "Close"]:continue
		return button
	return null


func _show_step() -> void:
	_target = _find_target(step)
	if _target == null and step == 0:
		step = 1
		_target = _find_target(step)
	if _target == null:
		finish()
		return
	if not industry_steps().is_empty():
		_hint.text = I18n.t(str(industry_steps()[step]["text"]))
		if industry_steps()[step].get("label_hint",false):_hint.text = _hint.text % I18n.t(str(industry_definitions()[feature.trim_prefix("industry_")]["label"]))
		_next.text = I18n.t("Next") if _find_target(step+1) != null else I18n.t("Got it")
		return
	var label := I18n.t(str(FeatureGate.definition(feature).get("label", "Overview")))
	_hint.text = (I18n.t("This is %s. Open it any time from here.") % label) if step == 0 else I18n.t("Start with the outlined button. Nothing here is timed.")
	_next.text = I18n.t("Next") if step == 0 and _find_target(1) != null else I18n.t("Got it")


func _advance() -> void:
	if not industry_steps().is_empty() and _find_target(step+1) != null:
		step += 1
		_show_step()
	elif step == 0 and industry_steps().is_empty() and _find_target(1) != null:
		step = 1
		_show_step()
	else:
		finish()


func finish() -> void:
	_mark_guided()
	if not is_queued_for_deletion():queue_free()


func _process(_delta: float) -> void:
	if host == null or not is_instance_valid(host) or not is_instance_valid(_target) or not _target.is_visible_in_tree():
		finish()
		return
	# The card floats just under the outlined control, kept inside the screen.
	var rect := _target.get_global_rect()
	var local := get_global_transform().affine_inverse() * rect.position
	var view := get_viewport_rect().size
	var at := Vector2(local.x, local.y + rect.size.y + 6.0)
	var size := _card.get_combined_minimum_size()
	if at.y + size.y > view.y - 4.0:at.y = maxf(4.0, local.y - size.y - 6.0)
	at.x = clampf(at.x, 4.0, maxf(4.0, view.x - size.x - 4.0))
	_card.position = at
	queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_target):return
	var rect := _target.get_global_rect()
	var origin := get_global_transform().affine_inverse() * rect.position
	draw_rect(Rect2(origin, rect.size).grow(3), Art.C_SKY, false, 2)
