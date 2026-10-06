class_name HoldingSaleModal
extends Modal
var explanation: String
var confirmed: Callable
func _init(heading: String,text: String,callback: Callable) -> void:
	title_text=heading
	explanation=text
	confirmed=callback
	pauses_time=true
func build() -> void:
	body.add_child(UIK.wrap(explanation,9,Art.C_WHITE,390))
	footer.add_child(UIK.button("Keep subsidiary",close))
	var submit:=UIK.button("Confirm subsidiary sale",func():close();confirmed.call(),"primary")
	submit.name="ConfirmSubsidiarySale"
	footer.add_child(submit)
