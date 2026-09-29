class_name ClerkFormsGame
extends MiniGame
## A shift at City Hall's registration counter: check each company registration form against the rules. Approve good
## ones; for a bad one, click the wrong field, then Reject. It's the same form the player files in Chapter 3.

const RULES := ["ID number: one letter and six digits (e.g. K204918)", "Filing fee paid: $300", "Company name filled in",
	"Signed by the applicant"]
const PEOPLE := ["Mara Lindqvist", "Tobi Okafor", "Ren Tanaka", "Ava Moreau", "Jon Silva", "Nadia Haddad", "Chris Walsh", "Lea Novak"]
const COMPANIES := ["Brightpath Studio", "Harbor & Pine Co.", "Kettle Labs", "Northwind Goods", "Paper Crane Ltd", "Riverstone Bakery",
	"Pixel Orchard", "Lumen Tea House"]
const TYPES := ["E-commerce", "Café", "Consulting", "Software", "Retail"]

var form := {}
var marked := ""
var right := 0
var rng := RandomNumberGenerator.new()


func _init() -> void:
	super._init()
	title_text = "Shift — City Hall registration counter"
	icon_name = "civic"
	rounds = 6
	round_time = 0.0
	rng.seed = Clock.now() * 19 + 7


func intro_lines() -> Array:
	return ["Check each company registration form against the four rules on your desk.",
		"All good? Approve it. Something wrong? Click the wrong field first, then Reject.",
		"This is the same form you'll file for your own company, so the rules are worth remembering."]


func round_name() -> String:
	return "Form %d / %d"


func build_round() -> void:
	var id := "%s%06d" % [char(65 + rng.randi_range(0, 25)), rng.randi_range(100000, 999999)]
	form = {"applicant": PEOPLE[rng.randi_range(0, PEOPLE.size() - 1)], "company": COMPANIES[rng.randi_range(0, COMPANIES.size() - 1)],
		"type": TYPES[rng.randi_range(0, TYPES.size() - 1)], "id": id, "fee": "$300", "signed": true, "bad": ""}
	if rng.randf() < 0.6:
		var bad: String = ["id", "fee", "company", "signed"][rng.randi_range(0, 3)]
		form["bad"] = bad
		match bad:
			"id":
				form["id"] = [id.substr(0, 6), id.substr(1), id + "7"][rng.randi_range(0, 2)]
			"fee":
				form["fee"] = ["$30", "$200", "$0"][rng.randi_range(0, 2)]
			"company":
				form["company"] = ""
			"signed":
				form["signed"] = false
	marked = ""
	_layout()


func _layout() -> void:
	UIK.clear(stage)
	var h := UIK.hbox(12)
	stage.add_child(h)
	var paper := card(Color(0.98, 0.97, 0.93), Color8(150, 140, 120))
	paper.custom_minimum_size = Vector2(330, 200)
	h.add_child(paper)
	var pv := UIK.vbox(3)
	paper.add_child(pv)
	pv.add_child(UIK.label("AURELIA · COMPANY REGISTRATION", 8, Color8(40, 60, 110), true))
	for f in [["applicant", "Applicant"], ["company", "Company name"], ["type", "Business type"], ["id", "ID number"],
			["fee", "Filing fee paid"], ["signed", "Signature"]]:
		var key: String = f[0]
		var val := str(form[key])
		if key == "signed":
			val = "✎ " + str(form["applicant"]) if form["signed"] else "—"
		elif key == "company" and val == "":
			val = "—"
		elif key == "type":
			val = I18n.t(val)
		var b := UIK.button("%s:  %s" % [I18n.t(str(f[1])), val], _mark.bind(key), "tab_active" if marked == key else "tab", 310)
		b.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.name = "Field_" + key
		if marked == key:
			b.add_theme_color_override("font_color", Art.C_RED)
		pv.add_child(b)
	var right_col := UIK.vbox(6)
	h.add_child(right_col)
	var note := card(Color(1.0, 0.93, 0.55), Color8(170, 140, 40))
	var nv := UIK.vbox(1)
	note.add_child(nv)
	nv.add_child(UIK.label("RULES", 7, Color8(90, 70, 10), true))
	for r in RULES:
		nv.add_child(UIK.wrap("• " + I18n.t(r), 7, Color8(60, 50, 10), 190))
	right_col.add_child(note)
	var ap := UIK.button("Approve", _decide.bind(true), "primary", 200)
	ap.name = "Approve"
	right_col.add_child(ap)
	var rj := UIK.button("Reject (click the wrong field first)" if marked == "" else "Reject", _decide.bind(false), "danger", 200)
	rj.name = "Reject"
	rj.disabled = marked == ""
	right_col.add_child(rj)


func _mark(key: String) -> void:
	marked = "" if marked == key else key
	_layout()


func _decide(approve: bool) -> void:
	var bad := str(form["bad"])
	if approve and bad == "":
		right += 1
		award(1.0)
		flash("✓ Approved: all in order", true)
	elif not approve and bad != "" and marked == bad:
		right += 1
		award(1.0)
		flash("✓ Rejected for the right reason", true)
	elif not approve and bad != "":
		award(0.5)
		flash("½ Right to reject, but that field was fine", false)
	elif approve:
		award(0.0)
		flash("✗ That form had a problem", false)
	else:
		award(0.0)
		flash("✗ That form was fine", false)
	next_round()


func extra_result() -> Dictionary:
	return {"right": right}


func result_lines() -> Array:
	return [I18n.t("Forms handled correctly: %d / %d") % [right, rounds]]
