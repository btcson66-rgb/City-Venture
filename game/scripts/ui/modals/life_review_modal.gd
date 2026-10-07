class_name LifeReviewModal
extends Modal
var confirm_kind := ""

func _init() -> void:
	title_text = "Life review"
	icon_name = "calendar"
	help_key = "life_review"
	panel_size = Vector2(510, 348)
	pauses_time = true

func start_next(kind: String) -> void:
	var result := LifeLegacy.next_life(kind)
	if not result["ok"]:
		UIRoot.toast(I18n.t(str(result["error"])), "warn", "info")
		rebuild()
		return
	UIRoot.close_all()
	SceneRouter.begin_world()

func build() -> void:
	var s := LifeLegacy.S()
	var box := UIK.vbox(5)
	body.add_child(UIK.scroll(box, Vector2(476, 232)))
	if s["review"].is_empty():
		box.add_child(UIK.wrap("Retirement records your life without closing or selling the company. You can keep playing or begin another life in a separate save slot.", 8, Art.C_WHITE, 458))
		if LifeLegacy.can_retire():
			var retire := UIK.button("Record retirement and review this life", func(): LifeLegacy.review(true); rebuild())
			retire.name = "RecordRetirement"
			box.add_child(retire)
		else:
			box.add_child(UIK.wrap("✗ Live thirty days or finish the main story before retiring. Continue living this life.", 8, Art.C_MUTED, 458))
		var play := UIK.button("Keep living this life", close, "primary")
		play.name = "KeepThisLife"
		body.add_child(play)
		return
	var review: Dictionary = s["review"]
	box.add_child(UIK.label_tip("Legacy archetypes", "legacy_archetypes", 10, Art.C_SKY))
	box.add_child(UIK.wrap(I18n.t("Primary: %s · Secondary: %s") % [I18n.t(review["primary"]["name"]), I18n.t(review["secondary"]["name"])], 9, Art.C_SKY, 458))
	box.add_child(UIK.wrap(review["epilogue"], 8, Art.C_WHITE, 458))
	box.add_child(UIK.label("Five key moments", 9, Art.C_SKY))
	box.add_child(UIK.wrap("Selected by the category weights in the legacy data, then by recency. Older records without a category keep their original text.", 7, Art.C_MUTED, 458))
	for row in review["moments"]:
		box.add_child(UIK.wrap("%s · %s" % [Clock.fmt_short(int(row["t"])), str(row["text"])], 8, Art.C_WHITE, 458))
	box.add_child(UIK.label("Recorded life statistics", 9, Art.C_SKY))
	var labels := {"industries":"Business types with revenue", "employees":"Current employees", "net_worth":"Book net worth (home dollars)", "delivered":"Delivered orders", "overseas":"Overseas deliveries", "features":"Software features", "energy_installs":"Energy installations", "chargers":"Open charging stations", "city_projects":"Completed city projects", "contacts":"Known contacts", "work_hours":"Recorded work hours"}
	for key in labels:
		var amount := float(review["metrics"][key])
		box.add_child(UIK.kv(labels[key], Fmt.money(amount) if key == "net_worth" else ("%.1f" % amount if key == "work_hours" else str(int(amount)))))
	box.add_child(UIK.wrap("Work hours include recorded paid shifts, cafe work and freelance hours. Older saves may lack hours recorded before this version.", 7, Art.C_MUTED, 458))
	var why := LifeLegacy.next_life_block()
	box.add_child(UIK.label_tip("A separate next life", "next_life", 9, Art.C_SKY))
	box.add_child(UIK.wrap("Starting cash falls to 80% per difficulty level and customer demand to 90% per level (floor 30%). Inherited capital is limited to 5% of current book net worth and at most 2,500 home dollars; it is equity, never sales revenue.", 7, Art.C_WHITE, 458))
	if why != "": box.add_child(UIK.wrap("✗ " + I18n.t(why), 7, Art.C_MUTED, 458))
	for kind in ["generation", "next"]:
		var button := UIK.button("Next generation" if kind == "generation" else "Next life with this character", func(): confirm_kind = kind; rebuild())
		button.name = "ChooseNextLife_" + kind
		button.disabled = why != ""
		box.add_child(button)
	if confirm_kind != "":
		box.add_child(UIK.wrap("Your current game is saved first. Only an empty slot is used; companies, earned income and achievements start fresh. Continue only when ready.", 8, Art.C_SKY, 458))
		var confirm := UIK.button("Save this life and start the selected next life", func(): start_next(confirm_kind), "primary")
		confirm.name = "ConfirmNextLife"
		confirm.disabled = why != ""
		body.add_child(confirm)
	var keep := UIK.button("Keep living this life", close, "primary" if confirm_kind == "" else "")
	keep.name = "KeepThisLife"
	body.add_child(keep)
