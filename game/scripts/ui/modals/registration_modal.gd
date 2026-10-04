class_name RegistrationModal
extends Modal
## City Hall company registration (Chapter 3): name, business type, address, fee.

var name_edit: LineEdit
var address := ""
var error_label: Label
var done := false


func _init() -> void:
	title_text = "Business Registration — City of Aurelia"
	icon_name = "civic"
	help_key = "registration"
	panel_size = Vector2(420, 250)


func build() -> void:
	var reg := Company.registration()
	if done:
		var cid := GameState.company_id()
		var e: Dictionary = GameState.data["entities"][cid]
		body.add_child(UIK.title(e["name"], 16, Art.C_GOLD))
		body.add_child(UIK.label(I18n.t("Registration no. %s · Founded %s") % [e["registration_no"], Clock.fmt_date(int(e["founded"]))], 8, Art.C_MUTED))
		body.add_child(UIK.wrap("Ana: \"All done. Congratulations. Open a business account at Nexus Bank and you're set.\"", 9, Art.C_WHITE, 390))
		body.add_child(UIK.wrap("ShopLane seller cap lifted · B2B contracts unlocked · office leases unlocked · supplier net terms unlocked", 7, Art.C_GREEN, 390))
		footer.add_child(UIK.button("Thanks", close, "primary", 80))
		return
	body.add_child(UIK.label("Company name", 8, Art.C_MUTED, true))
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "e.g. Riverlight Goods"
	name_edit.max_length = 28
	name_edit.custom_minimum_size = Vector2(260, 18)
	name_edit.name = "CompanyName"
	body.add_child(name_edit)
	body.add_child(UIK.label("Business type", 8, Art.C_MUTED, true))
	for t in reg.get("business_types", []):
		body.add_child(UIK.label("  ● " + I18n.t(t["name"]), 8, Art.C_WHITE))
	body.add_child(UIK.label("Registered address", 8, Art.C_MUTED, true))
	var ah := UIK.hbox(4)
	var opts := [["Riverside Tower 7C (home)", "Riverside Tower 7C, Riverside"]]
	if Living.has_lease("nexus_cowork_desk"):
		opts.append(["Nexus Co-work", "Nexus Co-work, Startup Hub"])
	if address == "":
		address = opts[0][1]
	for o in opts:
		ah.add_child(UIK.button(o[0], func(): address = o[1]; rebuild(), "tab_active" if address == o[1] else "tab"))
	body.add_child(ah)
	body.add_child(UIK.kv("Registration fee", Fmt.money0(Company.registration_fee()) + (I18n.t("  (staff discount)") if Careers.has_perk("registration_discount") else ""), Art.C_GOLD))
	body.add_child(UIK.kv("Processing time", Fmt.duration_min(int(reg.get("processing_min", 45)))))
	error_label = UIK.label("", 8, Art.C_RED)
	body.add_child(error_label)
	footer.add_child(UIK.button("Cancel", close))
	var sb := UIK.button("Register & pay", _submit, "primary")
	sb.name = "Submit"
	footer.add_child(sb)


func _submit() -> void:
	var r := Company.register(name_edit.text, "retail_online", address)
	if not r["ok"]:
		error_label.text = r["error"]
		return
	Clock.advance(int(Company.registration().get("processing_min", 45)))
	done = true
	rebuild()
