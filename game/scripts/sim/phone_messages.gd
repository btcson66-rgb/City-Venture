class_name PhoneMessages
extends RefCounted
## Read-only notifications. Meaningful choices live in formal screens or face-to-face dialogue.

static func S() -> Dictionary:
	if not GameState.data.has("phone_messages"):
		GameState.data["phone_messages"] = {"version": 2, "seq": 1, "agenda": []}
	var state: Dictionary = GameState.data["phone_messages"]
	if int(state.get("version", 0)) < 2: migrate(GameState.data)
	return GameState.data["phone_messages"]

## One-time, data-only old-save conversion: never execute a saved financial choice.
static func migrate(data: Dictionary) -> void:
	var state: Dictionary = data.get("phone_messages", {"seq": 1, "agenda": []})
	if int(state.get("version", 0)) >= 2:
		normalize(data)
		return
	state["version"] = 2
	state["seq"] = int(state.get("seq", 1))
	state["agenda"] = state.get("agenda", [])
	data["phone_messages"] = state
	for message in data.get("messages", []):
		var pending: bool = message.has("replies") and not message.has("answered")
		var target := legacy_target(message)
		if not target.is_empty(): message["target"] = target
		if pending:
			message["read"] = true
			# Neutral legacy flags only; cash, deals and purchases must still be chosen in their formal screen.
			for choice in message.get("replies", []):
				if str(choice.get("id", "")) != str(message.get("default_reply", "ack")): continue
				for effect in choice.get("effects", []):
					if effect.get("op", "") == "set_flag": data["flags"][str(effect["flag"])] = true
		if message.get("direction", "incoming") == "outgoing": message["read"] = true
		strip_legacy(message)
		if not message.has("id"):
			message["id"] = "MSG-%d" % state["seq"]
			state["seq"] += 1
		message["category"] = category(message)
		message["icon"] = "mail"
	normalize(data)
	state.erase("expiry")
	state.erase("cooldowns")
	state.erase("social")
	# Retain already-arranged visits; missing them has no penalty and never blocks story progress.
	for visit in state["agenda"]:
		if visit.get("status", "") == "planned":
			var target := {"kind":"map", "place":str(visit.get("location", "")).get_slice(":", 1)}
			var note := {"id":"VISIT-" + str(visit.get("id", "")), "t":int(visit.get("at", 0)), "from":visit.get("npc", ""), "text":"A friend is waiting. Visit when it suits you.", "read":true, "category":"life", "icon":"people", "target":target}
			if not data["messages"].any(func(m):return m.get("id", "") == note["id"]):data["messages"].append(note)

## Runs at every load: any message from any older build gets a stable id, category and target (idempotent).
static func normalize(data: Dictionary) -> void:
	var state: Dictionary = data.get("phone_messages", {})
	if not state.has("seq"): state["seq"] = 1
	data["phone_messages"] = state
	var taken := {}
	for message in data.get("messages", []): taken[str(message.get("id", ""))] = true
	for message in data.get("messages", []):
		if not message.has("t"): message["t"] = 0
		if not message.has("read"): message["read"] = true
		if not message.has("target"):
			var target := legacy_target(message)
			if not target.is_empty(): message["target"] = target
		strip_legacy(message)
		if str(message.get("id", "")) == "":
			var n := int(state["seq"])
			while taken.has("MSG-%d" % n): n += 1
			message["id"] = "MSG-%d" % n
			taken[message["id"]] = true
			state["seq"] = n + 1
		message["category"] = category(message)
		if not message.has("icon"): message["icon"] = "mail"

static func strip_legacy(message: Dictionary) -> void:
	for key in ["replies", "expires", "default_reply", "answered", "expired", "direction", "ctx"]:
		message.erase(key)

static func legacy_target(message: Dictionary) -> Dictionary:
	if message.has("decision"): return {"kind":"decision", "id":str(message["decision"])}
	var ctx: Dictionary = message.get("ctx", {})
	if ctx.has("contract"): return {"kind":"company", "tab":"contracts", "id":str(ctx["contract"])}
	if ctx.has("group_job"): return {"kind":"company", "tab":"group"}
	for choice in message.get("replies", []):
		for effect in choice.get("effects", []):
			match str(effect.get("op", "")):
				"phone_contract": return {"kind":"company", "tab":"contracts", "id":str(effect.get("id", effect.get("contract", "")))}
				"phone_group_job": return {"kind":"company", "tab":"group"}
				"fund_board": return {"kind":"fundraising", "tab":"reports", "id":str(effect.get("deal", ""))}
				"fund_partner": return {"kind":"fundraising", "tab":"partners", "id":str(effect.get("id", ""))}
				"phone_meeting", "phone_bank_later": return {"kind":"map", "place":"nexus_bank"}
				"phone_payment_extension": return {"kind":"bank"}
	return {}

static func category(message: Dictionary) -> String:
	if message.has("category"): return str(message["category"])
	if str(message.get("from", "")) in ["maya", "nina", "sam", "ken", "priya", "landlord"]: return "life"
	if str(message.get("from", "")) in ["city", "news", "traffic", "hospital"]: return "city"
	return "work"

static func prepare(message: Dictionary, options: Dictionary = {}) -> void:
	var state := S()
	for key in options:
		message[key] = options[key].duplicate(true) if options[key] is Dictionary or options[key] is Array else options[key]
	if not message.has("id"):
		message["id"] = "MSG-%d" % state["seq"]
		state["seq"] += 1
	var target := legacy_target(message)
	if not target.is_empty(): message["target"] = target
	strip_legacy(message)
	message["category"] = category(message)
	message["icon"] = str(message.get("icon", "mail"))

## A group is one actionable row, even if several real events arrive today.
static func append(message: Dictionary) -> bool:
	var key := str(message.get("merge", ""))
	if key != "":
		for prior in GameState.data["messages"]:
			if prior.get("merge", "") == key and int(prior["t"]) / Clock.DAY == int(message["t"]) / Clock.DAY:
				prior["count"] = int(prior.get("count", 1)) + 1
				prior["read"] = false
				prior["t"] = message["t"]
				prior["text"] = I18n.t("Today: %d new orders. Ready when you are.") % int(prior["count"])
				return false
	GameState.data["messages"].append(message)
	return true

static func get_message(id: String) -> Dictionary:
	S()
	for message in GameState.data.get("messages", []):
		if str(message.get("id", "")) == id:return message
	return {}

static func actionable(message: Dictionary) -> bool:
	var target: Dictionary = message.get("target", {})
	match str(target.get("kind", "")):
		"decision":return EventEngine.pending().any(func(e):return e["iid"] == target.get("id", ""))
		"company":
			if target.get("tab", "") == "contracts":return Contracts.C().get(target.get("id", ""), {}).get("status", "") in ["offered", "active"]
			return true
		"fundraising":
			if target.get("tab", "") == "partners":return Partnerships.get_item(str(target.get("id", ""))).get("status", "") == "offered"
			if target.get("tab", "") == "reports":return Fundraising.get_deal(str(target.get("id", ""))).get("board", {}).get("status", "") == "open"
			return false
		"bank":return Bank.loans().any(func(l):return l.get("status", "") == "late")
		"map":
			if str(message.get("id", "")).begins_with("VISIT-"):
				return S()["agenda"].any(func(v):return "VISIT-" + str(v.get("id", "")) == message["id"] and v.get("status", "") == "planned")
			return true
	return false

static func unread_actionable() -> int:
	S()
	return GameState.data.get("messages", []).filter(func(m):return not m.get("read", false) and actionable(m)).size()

static func read_all() -> void:
	for message in GameState.data.get("messages", []):message["read"] = true

static func destination(message: Dictionary) -> Control:
	var target: Dictionary = message.get("target", {})
	match str(target.get("kind", "")):
		"company":
			# A Go button must never land on a hidden tab.
			FeatureGate.grant("os_" + str(target.get("tab", "overview")))
			var screen := CompanyOS.new("notification")
			screen.tab = str(target.get("tab", "overview"))
			screen.sel_contract = str(target.get("id", ""))
			return screen
		"fundraising":
			var screen := FundraisingModal.new(str(target.get("tab", "investors")))
			screen.selected = str(target.get("id", ""))
			screen.partner_sel = str(target.get("id", ""))
			return screen
		"bank":return LoanModal.new(false)
		"map":
			var screen := CityMapModal.new(false)
			var place := str(target.get("place", ""))
			screen.sel = str(DataDB.building(place).get("district", place))
			return screen
		"decision":
			for event in EventEngine.pending():
				if event["iid"] == target.get("id", ""):return DecisionModal.new(event)
	return null

static func go(id: String) -> void:
	var message := get_message(id)
	message["read"] = true
	var screen := destination(message)
	UIRoot.phone.close()
	if screen != null:UIRoot.open_modal(screen)

static func on_minute(t: int) -> void:
	for visit in S()["agenda"]:
		if visit.get("status", "") == "planned" and t > int(visit.get("until", 0)):
			visit["status"] = "missed" # No penalty, forced response or additional notification.

static func check_arrival() -> void:
	if not GameState.has_game() or not GameState.data.has("phone_messages") or UIRoot.is_blocking():return
	var loc: Dictionary = GameState.data["player"].get("location", {})
	for visit in S()["agenda"]:
		if visit.get("status", "") != "planned" or Clock.now() < int(visit.get("at", 0)) or Clock.now() > int(visit.get("until", 0)):continue
		if str(loc.get("kind", "")) + ":" + str(loc.get("id", "")) != visit.get("location", ""):continue
		visit["status"] = "met"
		var conversation := str(visit.get("conversation", ""))
		if conversation != "":UIRoot.play_dialogue(conversation)
		return

static func contact_name(npc: String) -> String:
	var person := DataDB.npc(npc)
	if not person.is_empty(): return I18n.t(str(person["name"]))
	match npc:
		"assistant":
			return I18n.t("Assistant")
		"client":
			return I18n.t("Client")
		"landlord":
			return I18n.t("Landlord")
		"jobs_board":
			return I18n.t("Jobs Board")
		"shoplane":
			return I18n.t("ShopLane")
	if Fundraising.cfg().get("investors", {}).has(npc):
		return I18n.t(str(Fundraising.cfg()["investors"][npc].get("name", npc)))
	if Fundraising.cfg().get("partners", {}).has(npc):
		return Partnerships.name_of(npc)
	return npc.replace("_", " ").capitalize()
