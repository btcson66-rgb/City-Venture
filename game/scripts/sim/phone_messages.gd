class_name PhoneMessages
extends RefCounted
## Saved message choices delegate to the existing condition/effect and event engines; income never comes from a reply.

static func cfg() -> Dictionary: return DataDB.economy.get("messages", {})
static func S() -> Dictionary:
	if not GameState.data.has("phone_messages"): GameState.data["phone_messages"] = {"seq": 1, "agenda": [], "cooldowns": {}, "social": {}, "expiry": {}}
	var state: Dictionary = GameState.data["phone_messages"]
	if not state.has("expiry"):
		state["expiry"] = {}
		for message in GameState.data["messages"]:
			if message.has("expires") and not message.has("answered"):
				prepare(message)
	return state
static func error(text: String) -> Dictionary: return {"ok": false, "error": I18n.t(text)}

static func prepare(message: Dictionary, options: Dictionary = {}) -> void:
	if not message.has("id"):
		message["id"] = "MSG-%d" % int(S()["seq"])
		S()["seq"] = int(S()["seq"]) + 1
	if message.get("direction", "incoming") == "outgoing": return
	for key in options: message[key] = options[key].duplicate(true) if options[key] is Array or options[key] is Dictionary else options[key]
	if message.has("expires") and not message.has("answered"): S()["expiry"][message["id"]] = int(message["expires"])
	if not message.has("replies"): message["replies"] = [{"id": "ack", "label": "Okay, thanks.", "effects": []}]

static func get_message(id: String) -> Dictionary:
	for message in GameState.data["messages"]:
		prepare(message)
		if message["id"] == id: return message
	return {}

static func contacts() -> Array:
	var result: Array = []
	for id in DataDB.npcs:
		var known: bool = GameState.flag("met_" + str(id)) or GameState.data["messages"].any(func(m): return m["from"] == id)
		if known: result.append(id)
	result.sort()
	return result

static func choices(message: Dictionary) -> Array:
	prepare(message)
	if message.has("answered") or message.get("direction", "incoming") == "outgoing": return []
	if message.has("decision"):
		for pending in EventEngine.pending():
			if pending["iid"] == message["decision"]: return DataDB.events[pending["id"]].get("choices", [])
		message["answered"] = "resolved_elsewhere"
		return []
	return message["replies"]

static func context(message: Dictionary) -> Dictionary:
	if message.has("decision"):
		for pending in EventEngine.pending():
			if pending["iid"] == message["decision"]: return pending["ctx"]
	return message.get("ctx", {})

static func reply(id: String, choice_id: String, expired := false) -> Dictionary:
	var message := get_message(id)
	if message.is_empty() or message.has("answered"): return error("This message has already been answered or is unavailable.")
	if not expired and message.has("expires") and Clock.now() >= int(message["expires"]):
		on_minute(Clock.now())
		return error("The reply deadline has passed. Review the outcome in this thread.")
	var available := choices(message).filter(func(c): return c["id"] == choice_id)
	if available.is_empty(): return error("Choose one of this message's replies.")
	var choice: Dictionary = available[0]
	var ctx := context(message)
	if not EventEngine.choice_available(choice, ctx): return error("Complete the reply's requirements first.")
	var result := {"ok": true}
	if message.has("decision"): result = EventEngine.choose(message["decision"], choice_id)
	else:
		for effect in choice.get("effects", []):
			result = Effects.apply(effect, ctx)
			if not result.get("ok", true): return result
	if not result["ok"]: return result
	# Mark the incoming message once; history remains intact across saves.
	if not choice.get("keep_open", false):
		message["answered"] = choice_id
		S()["expiry"].erase(id)
	message["read"] = true
	message["expired"] = expired
	outgoing(message["from"], EventEngine.fill(str(choice.get("label", choice.get("text", "Okay, thanks."))), ctx))
	var answer := str(result.get("outcome", choice.get("outcome", "")))
	if answer != "": GameState.add_message(message["from"], EventEngine.fill(answer, ctx))
	return result

static func outgoing(npc: String, text: String) -> void:
	var message := {"t": Clock.now(), "from": npc, "text": text, "direction": "outgoing", "read": true}
	prepare(message)
	GameState.data["messages"].append(message)

static func send(npc: String, template: String) -> Dictionary:
	if not contacts().has(npc): return error("Meet this contact or receive their message first.")
	if template in ["work", "payment"] and GameState.data["entities"].get(GameState.company_id(), {}).has("closed"): return error("This is a contract of a closed company.")
	var data: Dictionary = cfg().get("templates", {}).get(template, {})
	if data.is_empty(): return error("Choose a message template.")
	var key := npc + ":" + template
	if Clock.now() < int(S()["cooldowns"].get(key, 0)): return error("Wait for this contact's message cooldown to end.")
	if not Cond.all(data.get("requires", [])): return error("Complete this message template's requirements first.")
	var result := {"ok": true}
	match template:
		"coffee": result = book(npc)
		"work": Careers.refresh_offers(); GameState.add_message(npc, "Check the current freelance offers at a co-work desk. Each brief lists its requirements and payment terms.")
		"payment":
			if not Jobs.S()["items"].values().any(func(j): return j["entity"] == GameState.business_entity() and j["status"] == "invoiced"): return error("Invoice completed work before asking about payment.")
			GameState.add_message(npc, "Payment follows the invoice due date. Review receivables in Company OS; a reminder does not create a new payment.")
	if not result["ok"]: return result
	S()["cooldowns"][key] = Clock.now() + int(data["cooldown_minutes"])
	outgoing(npc, I18n.t(str(data["label"])))
	return result

static func book(npc: String, at := -1, location := "", conversation := "") -> Dictionary:
	var person := DataDB.npc(npc)
	if person.is_empty(): return error("This contact has no meeting location.")
	var schedule: Array = person.get("schedule", [])
	if location == "":
		if schedule.is_empty(): return error("This contact has no meeting location.")
		location = str(schedule[0]["location"])
	var kind := location.get_slice(":", 0)
	var place := location.get_slice(":", 1)
	if kind not in ["interior", "district"] or kind == "interior" and not DataDB.buildings.has(place) or kind == "district" and not DataDB.districts.has(place): return error("This contact has no meeting location.")
	if at < 0:
		var earliest := Clock.now() + int(cfg().get("meeting_lead_minutes", 60))
		for minute in range(earliest, earliest + 8 * Clock.DAY):
			var present := false
			for slot in schedule:
				if slot.get("location", "") == location and Cond.all([str(slot.get("if", ""))]) and DestinationHours._window(slot, minute, "from", "to") and DestinationHours._window(slot, minute + int(cfg().get("meeting_window_minutes", 60)) - 1, "from", "to"):
					present = true
			if present and (kind != "interior" or DestinationHours._open(DataDB.building(place), minute, npc) and DestinationHours._open(DataDB.building(place), minute + int(cfg().get("meeting_window_minutes", 60)) - 1, npc)):
				at = minute
				break
	if at < Clock.now(): return error("No meeting time is currently available. Ask again later.")
	if S()["agenda"].any(func(m): return m["npc"] == npc and m["status"] == "planned"): return error("You already have a meeting with this contact.")
	var meeting := {"id": "MEET-%d" % int(S()["seq"]), "npc": npc, "at": at, "until": at + int(cfg().get("meeting_window_minutes", 60)), "location": location, "conversation": conversation, "status": "planned"}
	S()["seq"] = int(S()["seq"]) + 1
	S()["agenda"].append(meeting)
	GameState.add_message(npc, I18n.t("Meeting: %s at %s. Check Agenda; if you miss it, book again.") % [Clock.fmt_datetime(at), I18n.t(DataDB.building(place).get("name", DataDB.districts.get(place, {}).get("name", place)))])
	return {"ok": true, "meeting": meeting}

static func meet(id: String) -> Dictionary:
	var rows: Array = S()["agenda"].filter(func(m): return m["id"] == id)
	if rows.is_empty(): return error("This meeting is unavailable.")
	var m: Dictionary = rows[0]
	if m["status"] != "planned" or Clock.now() < int(m["at"]) or Clock.now() > int(m["until"]): return error("Arrive during this meeting's time window, or book again.")
	var loc: Dictionary = GameState.data["player"].get("location", {})
	if str(loc.get("kind", "")) + ":" + str(loc.get("id", "")) != m["location"]: return error("Go to the meeting location shown in Agenda first.")
	m["status"] = "met"
	GameState.set_flag("phone_met_" + str(m["npc"]))
	S()["social"][m["npc"]] = int(S()["social"].get(m["npc"], 0)) + 1
	var conversation := str(m["conversation"])
	if conversation == "":
		for choice in DataDB.npc(m["npc"]).get("dialogue", []):
			if Cond.all(choice.get("when", [])): conversation = str(choice["conversation"]); break
	if conversation != "" and not UIRoot.is_blocking(): UIRoot.play_dialogue(conversation)
	return {"ok": true, "conversation": conversation}

static func on_minute(t: int) -> void:
	# An expiry index avoids scanning an entire saved conversation history every simulated minute.
	for id in S()["expiry"].keys():
		if t < int(S()["expiry"][id]): continue
		var message := get_message(str(id))
		if not message.is_empty() and not message.has("answered"):
			var result := reply(str(id), str(message.get("default_reply", "ack")), true)
			if not result["ok"]:
				message["answered"] = "expired_unavailable"
				message["expired"] = true
				GameState.add_message(message["from"], "The reply is no longer available. Review current Tasks or book a new time from Contacts.")
		S()["expiry"].erase(id)
	for meeting in S()["agenda"]:
		if meeting["status"] == "planned" and t > int(meeting["until"]):
			meeting["status"] = "missed"
			GameState.add_message(meeting["npc"], "We missed the meeting. You can book a new time from Contacts.")

static func check_arrival() -> void:
	if not GameState.has_game() or not GameState.data.has("phone_messages") or UIRoot.is_blocking(): return
	var loc: Dictionary = GameState.data["player"].get("location", {})
	for meeting in S()["agenda"]:
		if meeting["status"] == "planned" and Clock.now() >= int(meeting["at"]) and Clock.now() <= int(meeting["until"]) and str(loc.get("kind", "")) + ":" + str(loc.get("id", "")) == meeting["location"]:
			meet(str(meeting["id"]))
			return
