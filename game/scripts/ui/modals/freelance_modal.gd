class_name FreelanceModal
extends Modal
var gig_id := ""
var quote_multiplier := 1.0
var revision_allowance := 1
func _init(id: String) -> void:
	gig_id = id
	title_text = "Client project"
	help_key = "freelance_workflow"
	panel_size = Vector2(500, 320)
	pauses_time = true
func build() -> void:
	var g := FreelanceWorkflow.gig(gig_id)
	if g.is_empty(): return
	body.add_child(UIK.wrap(Careers.gig_title(g), 10, Art.C_WHITE, 470))
	body.add_child(UIK.label_tip("Interview, scope and acceptance", "freelance_stages", 8))
	body.add_child(UIK.label(I18n.t("%s · %.1f/%.1f h · fee %s · due %s") % [FreelanceWorkflow.stage_label(g), float(g["done"]), float(g["hours"]), Fmt.money(g["fee"]), Clock.fmt_short(int(g["due"]))], 8, Art.C_SKY))
	if not FreelanceWorkflow.available(g):
		body.add_child(UIK.wrap("✓ Project ended. Review payment status in Company OS, or choose another offer.", 9, Art.C_MUTED, 470))
		return
	var w: Dictionary = g["workflow"]
	match str(w["stage"]):
		"interview":
			body.add_child(UIK.wrap("Client: ask about the goal, audience and budget. Skipping questions leaves gaps at acceptance.", 9, Art.C_WHITE, 470))
			var next_topic := ""
			for candidate in ["goal", "audience", "budget"]:
				if not candidate in w["asked"]: next_topic = candidate; break
			for topic in ["goal", "audience", "budget"]:
				var asked: bool = topic in w["asked"]
				var question := UIK.button(("✓ " if asked else "✗ ") + I18n.t({"goal":"Project goal", "audience":"Target audience", "budget":"Budget"}[topic]), _ask.bind(topic), "primary" if topic == next_topic else "")
				question.name = "Interview_" + topic
				question.disabled = asked
				body.add_child(question)
			_action("Prepare proposal", "Proposal", func(): _result(FreelanceWorkflow.prepare_proposal(gig_id)), next_topic == "")
		"proposal":
			body.add_child(UIK.wrap("Quote the project and choose the included revision allowance. A higher reputation permits a higher quote.", 9, Art.C_WHITE, 470))
			var quotes := UIK.hbox(5)
			for mult in [0.8, 1.0, 1.2]:
				var choice := UIK.button(Fmt.money(float(g["fee"]) * mult), func(): quote_multiplier = mult; rebuild(), "tab_active" if is_equal_approx(mult, quote_multiplier) else "")
				choice.name = "Quote_%d" % roundi(mult * 100)
				quotes.add_child(choice)
			body.add_child(quotes)
			var allowances := UIK.hbox(5)
			for count in [0,1,2]:
				var choice := UIK.button(I18n.t("%d revision(s)") % count, func(): revision_allowance = count; rebuild(), "tab_active" if count == revision_allowance else "")
				choice.name = "RevisionAllowance_%d" % count
				allowances.add_child(choice)
			body.add_child(allowances)
			_action("Agree quote and scope", "AgreeProposal", func(): _result(FreelanceWorkflow.propose(gig_id, quote_multiplier, revision_allowance)), true)
		"work", "revision_work":
			body.add_child(UIK.wrap("Allocate up to two hours to this session. Each day's work is capped; rest before continuing tomorrow.", 9, Art.C_WHITE, 470))
			_action("Work 1 h", "Session_1", _work.bind(1.0))
			_action("Work 2 h", "Session_2", _work.bind(2.0), true)
		"scope":
			body.add_child(UIK.wrap("Client requests extra scope. The added work is real; agree a surcharge or absorb it within the original fee.", 9, Art.C_WHITE, 470))
			_action("Charge for added scope", "Scope_charge", func(): _result(FreelanceWorkflow.scope(gig_id, true)))
			_action("Absorb the added work", "Scope_absorb", func(): _result(FreelanceWorkflow.scope(gig_id, false)))
		"delivery":
			_action("Deliver to client", "DeliverGig", func(): _result(FreelanceWorkflow.deliver(gig_id)), true)
		"revision", "failed":
			var covered := int(w["revisions"]) < int(w["revision_limit"])
			body.add_child(UIK.wrap(I18n.t("Revision rounds: %d/%d included. Choose revision work or discounted settlement.") % [int(w["revisions"]), int(w["revision_limit"])], 9, Art.C_WHITE, 470))
			_action("Use included revision" if covered else I18n.t("Agree paid revision (%s)") % Fmt.money(FreelanceWorkflow.cfg()["revision_fee"]), "ReviseGig", func(): _result(FreelanceWorkflow.revise(gig_id, not covered)))
			_action("Settle at a discount", "SettleGig", func(): _result(FreelanceWorkflow.accept_delivery(gig_id, true)))
		"acceptance":
			_action("Request acceptance and invoice", "AcceptDelivery", func(): _result(FreelanceWorkflow.accept_delivery(gig_id)), true)
func _action(text: String, stable: String, callback: Callable, primary := false) -> void:
	var button := UIK.button(text, callback, "primary" if primary else "")
	button.name = stable
	body.add_child(button)
func _ask(topic: String) -> void:
	var result := FreelanceWorkflow.ask(gig_id, topic)
	if result["ok"]:
		var kind: String = FreelanceWorkflow.gig(gig_id)["workflow"]["type"]
		UIRoot.toast(I18n.t(FreelanceWorkflow.cfg()["interview_answers"][kind][topic]), "info", "people")
	rebuild()
func _result(result: Dictionary) -> void:
	if not result["ok"]: UIRoot.toast(result.get("error", ""), "warn", "warning")
	rebuild()
func _work(hours: float) -> void:
	MiniGames.play(ConsultingGame.new(str(FreelanceWorkflow.gig(gig_id)["workflow"]["type"])), func(result):
		if not result.get("aborted", false): _result(FreelanceWorkflow.work(gig_id, hours, float(result.get("score", 0.0)))))
