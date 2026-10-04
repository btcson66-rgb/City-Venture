class_name GovernanceUI
extends RefCounted
## Shared-service UI preserves Company OS terminal access; only filing is also available by phone/City Hall.
static func render_os(owner: Node) -> void:
	var box: VBoxContainer=owner.get("content")
	var entity := GameState.company_id()
	box.add_child(UIK.label_tip("Company brand","company_brand",10,Art.C_GOLD,true))
	box.add_child(UIK.label(I18n.t("Brand: %.1f / 100 points")%Brand.score(entity)))
	var labels := {"reviews":I18n.t("Reviews"),"news":I18n.t("News"),"crises":I18n.t("Crisis handling"),"payments":I18n.t("On-time payments"),"employees":I18n.t("Employee treatment")}
	for key in Brand.components(entity):
		box.add_child(UIK.label(I18n.t("%s: %.1f / 100 points · weight %.0f%%")%[labels[key],float(Brand.components(entity)[key]),float(Brand.cfg()["brand_weights"][key])*100],8))
	box.add_child(UIK.wrap("Brand influences recruitment, B2B willingness and borrowing rates. Event effects fade over 90 days; paid advertising alone is not reputation.",8,Art.C_MUTED,460))
	box.add_child(UIK.label(I18n.t("Brand loan adjustment: %+.2f percentage points")%(Brand.apr_adjustment()*100),8))
	box.add_child(UIK.sep())
	box.add_child(UIK.label_tip("Tax filing","tax_filing",9,Art.C_WHITE,true))
	var due := Tax.returns(entity).any(func(r):return r["status"] in ["due","correction"])
	var tax := UIK.button("Review tax returns",func():Industries.run_action("tax_filing",{},owner),owner.call("_next_style",due))
	tax.name="ReviewTaxReturns"
	box.add_child(tax)
	box.add_child(UIK.label_tip("Legal disputes","legal_disputes",9,Art.C_WHITE,true))
	for c in Legal.cases(entity):
		if c["status"] not in ["open","pending"]:continue
		box.add_child(UIK.label(I18n.t("%s · amount %s")%[c["party"],Fmt.money(float(c["amount"]))],8))
		var button := UIK.button("Review dispute",_open_case.bind(str(c["id"])),owner.call("_next_style",c["status"]=="open"))
		button.name="ReviewLegal_"+str(c["id"])
		box.add_child(button)
	box.add_child(UIK.label_tip("Company insurance","company_insurance",9,Art.C_WHITE,true))
	box.add_child(UIK.wrap(I18n.t("Cover %.0f%% of eligible loss · deductible %s · limit %s per %d days")%[float(Insurance.cfg()["cover_share"])*100,Fmt.money(float(Insurance.cfg()["deductible"])),Fmt.money(float(Insurance.cfg()["period_limit"])),int(Insurance.cfg()["renew_days"])],8,Art.C_MUTED,460))
	for kind in Insurance.cfg()["policies"]:
		var spec: Dictionary=Insurance.cfg()["policies"][kind]
		var policy: Dictionary=Insurance.policies(entity).get(kind,{})
		box.add_child(UIK.label(I18n.t("%s · premium %s / 30 days")%[I18n.t(str(spec["name"])),Fmt.money(float(spec["monthly"]))],8))
		if policy.get("active",false):
			box.add_child(UIK.wrap(I18n.t("✓ Paid cover until %s; waiting period ends %s.")%[Clock.fmt_short(int(policy["until"])),Clock.fmt_short(int(policy["ready"]))],8,Art.C_GREEN,460))
			if policy.get("auto",false):
				var cancel := UIK.button("Stop next renewal",_cancel_policy.bind(entity,str(kind),owner))
				cancel.name="CancelInsurance_"+str(kind)
				box.add_child(cancel)
		else:
			box.add_child(UIK.label("✗ No cover; buy before a loss, then wait 7 days.",8,Art.C_MUTED))
			var buy := UIK.button("Buy cover",_buy_policy.bind(entity,str(kind),owner),owner.call("_next_style",kind=="property" and Ledger.cash(entity)>=float(spec["monthly"])))
			buy.name="BuyInsurance_"+str(kind)
			buy.disabled=Ledger.cash(entity)<float(spec["monthly"])
			box.add_child(buy)
	box.add_child(UIK.wrap("Claims reimburse actual crisis costs after a deductible, up to the paid policy limit. Fines and hypothetical lost sales are excluded; vehicle premiums keep their existing cover.",8,Art.C_MUTED,460))
	for c in Insurance.S()["claims"].values():
		if c["entity"]==entity:
			var label := UIK.label(I18n.t("Claim %s · %s · %s")%[c["id"],Fmt.money(float(c["amount"])),I18n.t("Claim paid") if c["status"]=="paid" else I18n.t("Claim pending")],8)
			label.name="InsuranceClaim_"+str(c["id"])
			box.add_child(label)
static func _open_case(id: String) -> void:UIRoot.open_modal(LegalCaseModal.new(id))
static func _buy_policy(entity: String,kind: String,owner: Node) -> void:
	var result := Insurance.buy(entity,kind)
	if not result["ok"]:UIRoot.toast(result["error"],"bad")
	owner.call("rebuild")
static func _cancel_policy(entity: String,kind: String,owner: Node) -> void:
	Insurance.cancel(entity,kind)
	owner.call("rebuild")
