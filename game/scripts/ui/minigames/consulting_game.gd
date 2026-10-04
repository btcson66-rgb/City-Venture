class_name ConsultingGame
extends MiniGame
## Four client-work tasks: classify research, calculate model values, order a process, or select brand cards.
var kind := "market"
var selections: Array = []
var correct := 0
var selected_card := ""
func _init(work_type := "market") -> void:
	super._init()
	kind = work_type
	title_text = "Client work session"
	help_key = "consulting_work"
	rounds = 3
	round_time = 0.0
func intro_lines() -> Array:
	return ["Use the client's brief. Research, financial models, operating processes and brand strategy each need different work.", "Your work quality affects acceptance. A session uses real consulting hours; no payment is earned before acceptance."]
func build_round() -> void:
	selections = []
	selected_card = ""
	_layout()
func _layout() -> void:
	UIK.clear(stage)
	var view := UIK.vbox(8)
	stage.add_child(view)
	var cases: Array = FreelanceWorkflow.cfg()["cases"][kind]
	var task: Dictionary = cases[round_i]
	view.add_child(UIK.wrap(I18n.t(task["text"]), 10, Art.C_WHITE, 550))
	if kind == "operations":
		view.add_child(UIK.label(I18n.t("Process order: %s") % " → ".join(selections.map(func(x): return I18n.t(str(x)))), 9, Art.C_SKY))
	elif kind == "brand":
		view.add_child(UIK.label("Pick a card, then confirm how it fits the client brief.", 9, Art.C_SKY))
	var options: Array = task["options"]
	var order: Array = range(options.size())
	var shuffle := RandomNumberGenerator.new()
	shuffle.seed = hash(kind + str(round_i))
	for n in range(order.size() - 1, 0, -1):
		var other := shuffle.randi_range(0, n)
		var swap = order[n]
		order[n] = order[other]
		order[other] = swap
	for index in order:
		var option := str(options[index])
		var button := UIK.button(I18n.t(option), _choose.bind(index), "tab_active" if selected_card == option else "")
		button.name = "ConsultChoice_%d" % index
		button.disabled = kind == "operations" and option in selections
		view.add_child(button)
	if kind == "brand":
		var submit := UIK.button("Confirm client fit", _submit_brand, "primary")
		submit.name = "ConfirmFit"
		submit.disabled = selected_card == ""
		view.add_child(submit)
func _choose(index: int) -> void:
	if phase != "play": return
	var task: Dictionary = FreelanceWorkflow.cfg()["cases"][kind][round_i]
	if index < 0 or index >= task["options"].size(): return
	if kind == "operations":
		var option := str(task["options"][index])
		if option in selections: return
		selections.append(option)
		if selections.size() < task["options"].size(): _layout(); return
		_finish_task(selections == task["answer"])
	elif kind == "brand":
		selected_card = str(task["options"][index])
		_layout()
	else: _finish_task(index == int(task["answer"]))
func _submit_brand() -> void:
	if phase != "play" or round_i >= rounds or selected_card == "": return
	var task: Dictionary = FreelanceWorkflow.cfg()["cases"][kind][round_i]
	_finish_task(selected_card == str(task["options"][int(task["answer"])]))
func _finish_task(ok: bool) -> void:
	correct += int(ok)
	award(1.0 if ok else 0.0)
	next_round()
func result_lines() -> Array: return [I18n.t("Client-work quality: %d%%") % roundi(score() * 100)]
