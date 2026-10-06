class_name PersonalRequestGame
extends MiniGame
## Choose how to help: every approach is honest work that trades time, money and trust differently.
var request: Dictionary
var approach := "thorough"
func _init(node: Dictionary) -> void:
	super._init()
	request=node
	title_text=node["title"]
	rounds=1
	round_time=float(PersonalLife.cfg()["request_round_seconds"])
func intro_lines() -> Array:return [request["detail"],"Choose how to help. Each approach is real work with its own time, cost and trust; the work completes either way."]
func extra_result() -> Dictionary:return {"approach":approach}
func _options() -> Array:
	var out: Array=[]
	for answer in request["choices"]:out.append({"id":str(answer["id"]),"label":str(answer["label"]),"approach":"thorough"})
	for key in PersonalLife.approaches():
		if key!="thorough":out.append({"id":key,"label":str(PersonalLife.approaches()[key]["label"]),"approach":key})
	return out
func build_round() -> void:
	var v := UIK.vbox(7);stage.add_child(v)
	v.add_child(UIK.wrap(I18n.t(request["detail"]),9,Art.C_WHITE,530))
	for option in _options():
		var terms := PersonalLife.approach_terms(request,str(option["approach"]))
		var text := "%s\n%s"%[I18n.t(option["label"]),I18n.t("%d min · supplies %s · +%d trust")%[int(terms["minutes"]),Fmt.money(float(terms["cost"])),roundi(float(terms["affinity"]))]]
		var key := str(option["approach"])
		var b := UIK.button(text,func():approach=key;award(1.0);next_round())
		b.name="PersonalAnswer_"+str(option["id"]);v.add_child(b)
