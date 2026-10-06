class_name TrafficModal
extends Modal
var mode := "clinic"
var selected := 0
func _init(m := "clinic") -> void:
	mode = m
	title_text = "Clinic & health insurance"
	icon_name = "civic"
	help_key = "traffic_safety"
	panel_size = Vector2(500,300)
	pauses_time = true
func add_button(label: String, name_id: String, fn: Callable, primary := false, enabled := true) -> void:
	var b := UIK.button(label, fn, "primary" if primary and enabled else "button")
	b.name = name_id
	b.disabled = not enabled
	_content().add_child(b)
var _list: VBoxContainer
func _content() -> Control:
	return _list
func build() -> void:
	var scroll_body := UIK.vbox(4)
	body.add_child(UIK.scroll(scroll_body, Vector2(470,220)))
	var content := scroll_body
	_list = scroll_body
	content.add_child(UIK.tip("personal_health"))
	var s := TrafficSafety.S()
	var a := TrafficSafety.latest() if selected == 0 else TrafficSafety.accident(selected)
	content.add_child(UIK.wrap("Use a green crosswalk. Crossing elsewhere or on red can cause a collision.",8,Art.C_MUTED,470))
	content.add_child(UIK.label(I18n.t("Injury: %s") % TrafficSafety.severity_label(str(s["injury"])),9,Art.C_GOLD))
	if mode == "accident" and s["injury"] == "major":
		content.add_child(UIK.wrap("An ambulance can take you to Civic Clinic. Admission takes up to three days and your business keeps running. Phone replies, meetings and the bank appointment wait for you; if a chapter, contract or group-job deadline is nearer, you are discharged early.",8,Art.C_WHITE,470))
		add_button("Take ambulance", "Ambulance", _ambulance, true)
	elif mode == "accident":
		content.add_child(UIK.wrap("Minor injuries slow walking for three days. Buy medicine at the Civic Clinic pharmacy to recover sooner.",8,Art.C_WHITE,470))
		add_button("Visit clinic", "VisitClinic", _ambulance, s["injury"] == "minor")
	else:
		content.add_child(UIK.wrap("Emergency care is available even without cash. Unpaid medical bills remain payable here. Insurance must already be active when the collision happens.",8,Art.C_MUTED,470))
		if s["injury"] != "none":
			var fee := float(TrafficSafety.cfg()["major_fee"] if s["injury"] == "major" else TrafficSafety.cfg()["medicine_fee"])
			var injury := TrafficSafety.current_injury()
			var ready: bool = s["injury"] == "major" or Ledger.cash("player") >= fee * (1.0-float(TrafficSafety.cfg()["coverage"]) if injury.get("insured_at_hit",false) else 1.0)
			if not ready: content.add_child(UIK.wrap("✗ " + I18n.t("Add cash before buying medicine, or wait for natural recovery."),8,Art.C_GOLD,470))
			add_button(I18n.t("Treatment / medicine: %s") % Fmt.money(fee), "Treatment", func(): TrafficSafety.treat(); rebuild(), true, ready)
		content.add_child(UIK.label(("✓ " + I18n.t("Covered until %s") % Clock.fmt_short(int(s["policy_until"]))) if TrafficSafety.insured() else "✗ " + I18n.t("No active policy — buy coverage before an accident."),8))
		add_button(I18n.t("Health insurance: %s / 30 days") % Fmt.money(float(TrafficSafety.cfg()["premium"])), "BuyHealthPolicy", func(): TrafficSafety.buy_policy(); rebuild(), false, not TrafficSafety.insured() and Ledger.cash("player") >= float(TrafficSafety.cfg()["premium"]))
		if TrafficSafety.insured(): add_button("Cancel automatic renewal", "CancelHealthRenewal", func(): s["renew"] = false; rebuild(), false, s["renew"])
		for old in s["accidents"]:
			if float(old.get("debt",0)) > 0 or (old["counterparty_fault"] and old["treated"] and not old["settled"]):
				add_button(I18n.t("Review accident #%d") % int(old["id"]), "Accident_%d" % int(old["id"]), func(): selected = int(old["id"]); rebuild())
		if not a.is_empty() and a["treated"]:
			content.add_child(UIK.wrap(I18n.t("Treatment complete: %d hospital days; medical bill %s; health claim %s.") % [int(a.get("hospital_days",0)), Fmt.money(float(a["medical_paid"])), Fmt.money(float(a["health_claim"]))],8,Art.C_WHITE,470))
		if not a.is_empty() and float(a.get("debt",0)) > 0:
			add_button(I18n.t("Pay medical balance: %s") % Fmt.money(float(a["debt"])), "PayMedicalDebt", func(): TrafficSafety.pay_debt(int(a["id"])); rebuild(), false, Ledger.cash("player") >= float(a["debt"]))
		if not a.is_empty() and a["counterparty_fault"] and a["treated"] and not a["settled"]:
			if int(a["procedure_due"]) == 0:
				add_button("Accept partial settlement", "SettleTraffic", func(): TrafficSafety.settle(false,int(a["id"])); rebuild())
				add_button("File claim — wait seven days", "FileTrafficClaim", func(): TrafficSafety.settle(true,int(a["id"])); rebuild())
			else:
				content.add_child(UIK.label(I18n.t("Claim collection: %s") % Clock.fmt_short(int(a["procedure_due"])),8))
				add_button("Collect verified claim", "CollectTrafficClaim", func(): TrafficSafety.settle(true,int(a["id"])); rebuild(), false, Clock.now() >= int(a["procedure_due"]))
	footer.add_child(UIK.button("Close", close))
func _ambulance() -> void:
	close()
	SceneRouter.ambulance_clinic()
