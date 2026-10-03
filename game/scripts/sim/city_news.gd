class_name CityNews
extends RefCounted
## Bounded saved city feed: one macro headline, up to two queued rival/event/achievement stories per day.


static func S() -> Dictionary:
	if not GameState.data.has("city_news"):
		GameState.data["city_news"] = {"version": 1, "day": -1, "items": [], "queue": [], "timeline_cursor": GameState.data["timeline"].size(), "event_cursor": GameState.data["events"]["history"].size()}
	return GameState.data["city_news"]


static func enqueue(text: String, kind: String) -> void:
	var queue: Array = S()["queue"]
	if not queue.any(func(item): return item["text"] == text):
		queue.append({"text": text, "kind": kind})
	while queue.size() > int(Rivals.cfg()["news_queue_limit"]):
		queue.pop_front()


static func publish_day() -> void:
	if int(S()["day"]) == Clock.day_index():
		return
	var timeline: Array = GameState.data["timeline"]
	for index in range(int(S()["timeline_cursor"]), timeline.size()):
		if timeline[index].get("kind", "") in ["milestone", "business"]:
			enqueue(str(timeline[index]["text"]), "achievement")
	S()["timeline_cursor"] = timeline.size()
	var history: Array = GameState.data["events"]["history"]
	for index in range(int(S()["event_cursor"]), history.size()):
		var event: Dictionary = DataDB.events.get(str(history[index].get("id", "")), {})
		if not event.is_empty():
			enqueue(I18n.t("City update: %s") % I18n.t(str(event.get("presentation", {}).get("title", ""))), "event")
	S()["event_cursor"] = history.size()
	var items: Array = S()["items"]
	items.append({"day": Clock.day_index(), "t": Clock.now(), "kind": "macro", "text": I18n.t("%s · base rate %s · price level %.2f × baseline") % [I18n.t(Macro.phase()), Fmt.pct(Macro.rate(), 2), Macro.costs()]})
	# Keep player events visible despite the weekly batch of AI company reports.
	# One player story per edition; the remaining slot drains older city news.
	var queue: Array = S()["queue"]
	var player_index := queue.find_custom(func(story): return story["kind"] in ["event", "achievement"])
	if player_index > 0:
		var player_story = queue[player_index]
		queue.remove_at(player_index)
		queue.push_front(player_story)
	for index in mini(2, queue.size()):
		var story: Dictionary = S()["queue"].pop_front()
		story.merge({"day": Clock.day_index(), "t": Clock.now()}, true)
		items.append(story)
	while items.size() > int(Rivals.cfg()["news_limit"]):
		items.pop_front()
	S()["day"] = Clock.day_index()
