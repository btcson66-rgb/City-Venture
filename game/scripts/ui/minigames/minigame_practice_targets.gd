class_name MinigamePracticeTargets
extends RefCounted
## Resolve contextual targets without duplicating the practice flow in each game.

static func resolve(g: MiniGame, selector: String) -> String:
	if not selector.begins_with("$"): return selector
	match selector:
		"$size", "$drink", "$milk", "$shots":
			var key := selector.substr(1)
			return key.capitalize() + "_" + str(g.get("want")[key])
		"$delivery": return "Deliver_%d" % int(g.get("want")["destination"])
		"$bin": return "Bin_" + str(g.get("parcel")["bin"])
		"$field":
			var bad := str(g.get("form")["bad"])
			return "" if bad == "" else "Field_" + bad
		"$form_decision": return "Approve" if g.get("form")["bad"] == "" else "Reject"
		"$desk": return "Desk_" + str(g.get("visitors")[g.round_i]["answer"])
		"$room":
			for child in g.find_children("Room_*", "Button", true, false):
				if not g.get("rooms").has(str(child.name).substr(5)): return str(child.name)
		"$note":
			for note in TellerCashGame.NOTES:
				if note <= int(g.get("amount")) - int(g.call("total")): return "Note_%d" % note
		"$refund": return "Refund_yes" if g.get("receipt_valid") else "Refund_no"
		"$box": return "Box_" + str(g.call("need_box"))
		"$item":
			for i in Packing.pieces(g.call("_order")).size():
				if not g.get("placements").any(func(p): return int(p["item"]) == i): return "PackItem_%d" % i
		"$rotation", "$grid":
			var plan := Packing.plan(g.call("_order"), g.get("box"))
			if plan.is_empty(): return ""
			var place: Dictionary = plan[int(g.get("selected"))]
			if selector == "$rotation": return "RotateItem" if bool(place["rotated"]) != bool(g.get("rotated")) else ""
			return "Grid_%d_%d" % [int(place["x"]), int(place["y"])]
		"$label":
			var labels: Array = g.get("labels")
			for i in labels.size():
				if labels[i]["ok"]: return "Label_%d" % i
		"$backdrop": return "Backdrop_" + str(PhotoShootGame.SUITS.get(g.get("product"), [["white"]])[0][0])
		"$consult":
			var task: Dictionary = FreelanceWorkflow.cfg()["cases"][g.get("kind")][g.round_i]
			var index: int = int(task["answer"]) if g.get("kind") != "operations" else task["options"].find(task["answer"][g.get("selections").size()])
			return "ConsultChoice_%d" % index
		"$consult_followup": return "ConfirmFit" if g.get("kind") == "brand" else ""
		"$creative":
			return "CreativeCard_%s_%d" % [["slogan", "visual", "tone"][g.round_i], int(g.get("brief")["preferences"][g.round_i])]
		"$charge":
			for button in g.find_children("PopupCharge_*", "Button", true, false):
				if button.get_meta("practice_correct", false): return str(button.name)
		"$personal":
			# Practice demonstrates an approach, without labelling judgment choices universally correct.
			var options: Array = g.find_children("PersonalAnswer_*", "Button", true, false)
			return str(options[0].name) if not options.is_empty() else ""
		"$stop": return "Stop_%d" % (int(g.get("best")["order"][g.get("order").size()]) + 1)
		"$fact":
			for fact in g.get("facts"):
				if not fact["id"] in g.get("picks"): return "DeckFact_" + str(fact["id"])
		"$pitch_answer":
			var options: Array = g.find_children("Answer_*", "Button", true, false)
			return str(options[0].name) if not options.is_empty() else ""
	return ""
