class_name PersonalRequestGame
extends MiniGame
## Read the person's evidence and choose a useful response; no affinity until real work completes.
var request: Dictionary
func _init(node: Dictionary) -> void:
	super._init()
	request=node
	title_text=node["title"]
	rounds=1
	round_time=float(PersonalLife.cfg()["request_round_seconds"])
func intro_lines() -> Array:return [request["detail"],"Read the evidence, then choose a response. A wrong answer uses the time and supplies but the request remains available."]
func build_round() -> void:
	var v := UIK.vbox(7);stage.add_child(v)
	v.add_child(UIK.wrap(I18n.t(request["detail"]),9,Art.C_WHITE,530))
	var answers: Array=request["choices"].duplicate()
	# The useful answer is not always the first button.
	var offset := int(request.get("order",0)) % answers.size()
	answers=answers.slice(offset)+answers.slice(0,offset)
	for answer in answers:
		var b := UIK.button(str(answer["label"]),func():award(1.0 if answer["correct"] else 0.0);next_round())
		b.name="PersonalAnswer_"+str(answer["id"]);v.add_child(b)
