class_name LegalCaseModal
extends Modal
var case_id := ""
func _init(id: String) -> void:
	case_id=id
	title_text="Legal Dispute"
	icon_name="contracts"
	help_key="legal_disputes"
	panel_size=Vector2(560,310)
func build() -> void:
	var c := Legal.get_case(case_id)
	if c.is_empty() or not Tax.valid(str(c.get("entity",""))):
		body.add_child(UIK.wrap("✗ This company or dispute is closed; return to your current company's terminal.",8,Art.C_GOLD,500))
		return
	body.add_child(UIK.label_tip("Legal disputes","legal_disputes",9,Art.C_WHITE,true))
	body.add_child(UIK.label(I18n.t("%s · disputed amount %s")%[c["party"],Fmt.money(float(c["amount"]))],9))
	if c["status"]=="open":
		body.add_child(UIK.wrap(I18n.t("✗ Unresolved; choose a route. No response by %s uses settlement automatically, including its fee and risks.")%Clock.fmt_short(int(c["expires"])),8,Art.C_GOLD,500))
		for option in Legal.options():
			var terms: Dictionary=Legal.options()[option]
			var ready := Ledger.cash(str(c["entity"]))>=float(terms["fee"])
			var label := I18n.t("%s · fee %s · %d days · success %.0f%% · recovery %.0f%% · relationship %d points")%[I18n.t(str(terms["name"])),Fmt.money(float(terms["fee"])),int(terms["days"]),float(terms["win"])*100,float(terms["recovery"])*100,int(terms["relationship"])]
			body.add_child(UIK.wrap(label,8,Art.C_MUTED,500))
			var b := UIK.button(str(terms["name"]),_choose.bind(str(option)),"primary" if terms.get("recommended",false) and ready else "")
			b.name="LegalChoice_"+str(option)
			b.disabled=not ready
			body.add_child(b)
		body.add_child(UIK.wrap("Customer recovery settles existing receivables. Earned employee wages remain owed even after a successful defence. IP success avoids compensation; it creates no income.",8,Art.C_MUTED,500))
	elif c["status"]=="pending":body.add_child(UIK.wrap(I18n.t("✓ Response submitted; next review the outcome on %s.")%Clock.fmt_short(int(c["resolves"])),8,Art.C_GREEN,500))
	else:body.add_child(UIK.label(I18n.t("✓ Closed; recovered %s, paid %s.")%[Fmt.money(float(c["recovered"])),Fmt.money(float(c["paid"]))],8,Art.C_GREEN))
func _choose(option: String) -> void:
	var result := Legal.choose(case_id,option)
	if not result["ok"]:UIRoot.toast(result["error"],"bad")
	rebuild()
