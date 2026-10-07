class_name TaxFilingModal
extends Modal
var entity := ""
var _primary := false
var advanced := false
func _init(company: String) -> void:
	entity=company
	title_text="Tax Filing"
	icon_name="finance"
	help_key="tax_filing"
	panel_size=Vector2(580,340)
func build() -> void:
	AssistantPolicy.toggle(body,"tax")
	var details := UIK.button("Advanced",func():advanced=not advanced;rebuild())
	details.name="TaxAdvanced"
	body.add_child(details)
	_primary=false
	if not Tax.vat_entity(entity):
		body.add_child(UIK.wrap("✗ Register an open company first; visit City Hall's registration counter.",8,Art.C_GOLD,520))
		return
	body.add_child(UIK.label_tip("VAT and income tax","tax_filing",9,Art.C_WHITE,true))
	if advanced:body.add_child(UIK.label(I18n.t("VAT %.0f%% · annual company income tax %.0f%%")%[float(Tax.cfg()["vat_rate"])*100,float(Tax.cfg()["income_rate"])*100],8))
	body.add_child(UIK.label(GameState.entity_name(entity),9,Art.C_WHITE,true))
	if GameState.company_id()!="":
		var target := "player" if entity!="player" else GameState.company_id()
		var switch := UIK.button("Personal seller VAT" if target=="player" else "Company tax returns",_switch_entity.bind(target))
		switch.name="TaxEntity_"+target
		body.add_child(switch)
	if advanced:body.add_child(UIK.wrap("Customer prices include collected VAT. File every two months; annual income tax uses pretax profit after carried losses. Filing is a process, not a quiz.",8,Art.C_MUTED,520))
	body.add_child(UIK.label(I18n.t("Collected VAT owed %s · income tax owed %s")%[Fmt.money(maxf(0,-Ledger.balance(entity,"tax_payable"))),Fmt.money(maxf(0,-Ledger.balance(entity,"income_tax_payable")))],8))
	if advanced:body.add_child(UIK.label(I18n.t("Loss available to carry forward: %s")%Fmt.money(float(Tax.E(entity)["loss"])),8))
	var returns := Tax.returns(entity)
	if returns.is_empty():body.add_child(UIK.wrap("✓ No return due yet; the next calendar period creates it automatically.",8,Art.C_GREEN,520))
	for r in returns:
		body.add_child(UIK.sep())
		body.add_child(UIK.label(str(r["period"]),9,Art.C_WHITE,true))
		body.add_child(UIK.label(I18n.t("Payment %s · penalty %s · due %s")%[Fmt.money(float(r["amount"])),Fmt.money(float(r["fine"])),Clock.fmt_short(int(r["due"]))],8))
		if r.has("pretax_profit"):body.add_child(UIK.label(I18n.t("Pretax profit %s · carried loss used %s")%[Fmt.money(float(r["pretax_profit"])),Fmt.money(float(r["loss_used"]))],8))
		if r["status"]=="due":
			body.add_child(UIK.label("✗ Not filed; choose a filing method below.",8,Art.C_GOLD))
			var cpa_fee := float(Tax.cfg()["accountant_fee"])
			var cpa_ready := Ledger.cash(entity)>=Tax.payable(r)+cpa_fee
			var diy_ready := Ledger.cash(entity)>=Tax.payable(r)
			var diy := UIK.button(I18n.t("File yourself · %d minutes · %.0f%% form-error chance")%[int(Tax.cfg()["diy_minutes"]),float(Tax.cfg()["diy_error_chance"])*100],_file.bind(str(r["id"]),"diy"),_style(diy_ready and not cpa_ready))
			diy.name="FileTax_"+str(r["id"])+"_diy"
			diy.disabled=not diy_ready
			if advanced:body.add_child(diy)
			var cpa := UIK.button(I18n.t("Hire accountant · %s · %d minutes · accurate filing")%[Fmt.money(cpa_fee),int(Tax.cfg()["accountant_minutes"])],_file.bind(str(r["id"]),"accountant"),_style(cpa_ready))
			cpa.name="FileTax_"+str(r["id"])+"_accountant"
			cpa.disabled=not cpa_ready
			body.add_child(cpa)
			if not diy_ready:body.add_child(UIK.wrap("✗ Insufficient company cash; visit a terminal → Finance to fund the payment.",8,Art.C_GOLD,520))
		elif r["status"]=="correction":
			body.add_child(UIK.wrap("✗ Documents need correction; fix them now or automatic correction charges a fee in 7 days.",8,Art.C_GOLD,520))
			var fix := UIK.button(I18n.t("Correct yourself · %d minutes")%int(Tax.cfg()["correction_minutes"]),_correct.bind(str(r["id"]),"diy"),_style(true))
			fix.name="CorrectTax_"+str(r["id"])+"_diy"
			body.add_child(fix)
			var cpa := UIK.button(I18n.t("Accountant correction · %s")%Fmt.money(float(Tax.cfg()["correction_fee"])),_correct.bind(str(r["id"]),"accountant"))
			cpa.name="CorrectTax_"+str(r["id"])+"_accountant"
			cpa.disabled=Ledger.cash(entity)<float(Tax.cfg()["correction_fee"])
			body.add_child(cpa)
		else:body.add_child(UIK.label("✓ Filing recorded; next review the following tax period.",8,Art.C_GREEN))
func _style(ready: bool) -> String:
	if ready and not _primary:_primary=true;return "primary"
	return ""
func _file(id: String,method: String) -> void:
	var result := Tax.file(entity,id,method)
	if not result["ok"]:UIRoot.toast(result["error"],"bad")
	rebuild()
func _correct(id: String,method: String) -> void:
	var result := Tax.correct(entity,id,method)
	if not result["ok"]:UIRoot.toast(result["error"],"bad")
	rebuild()
func _switch_entity(target: String) -> void:
	entity=target
	rebuild()
