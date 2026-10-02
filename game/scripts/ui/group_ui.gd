class_name GroupUI
extends RefCounted
## Company OS "Group" tab (#71): internal supply between your businesses, the consolidated group view, multi-industry
## group jobs and milestone progress. One primary button: accept the first open job, else review the segment P&L.


static func render(os) -> void:
	var c: VBoxContainer = os.content
	var primary := [false]
	os._section_tip("Group", "transfer_price")
	c.add_child(UIK.wrap(I18n.t("Your businesses can trade with each other. Set the transfer price; both sides show in Segments and the group total never counts it twice."), 8, Art.C_MUTED, 450))
	var offers := GroupJobs.offered()
	if offers.is_empty():
		var seg := UIK.button(I18n.t("Review segment results"), os._set_tab.bind("segments"), "primary")
		seg.name = "GroupNext"
		c.add_child(seg)
		primary[0] = true
	_supply(os, c)
	_consolidated(c)
	_jobs(os, c, primary)
	_milestones(c)


static func _btn(os, parent: Control, text: String, id: String, cb: Callable, primary: Array, want_primary := false) -> void:
	var main: bool = want_primary and not primary[0]
	if main:
		primary[0] = true
	var b := UIK.button(text, func():
		var result = cb.call()
		if typeof(result) == TYPE_DICTIONARY and not result.get("ok", true):
			EventBus.notify.emit(str(result.get("error", "")), "bad", "contracts")
		os.rebuild(), "primary" if main else "")
	b.name = id
	parent.add_child(b)


static func _supply(os, c: VBoxContainer) -> void:
	os._section("Internal supply")
	var rows := InternalSupply.pairs()
	if rows.is_empty():
		c.add_child(UIK.label("✗ " + I18n.t("No supply pair is running yet."), 8, Art.C_GOLD, true))
		c.add_child(UIK.wrap(I18n.t("Next step: %s") % InternalSupply.next_step(), 8, Art.C_SKY, 450))
		return
	var none := [true]
	for p in rows:
		var l: Dictionary = p["link"]
		var st: Dictionary = p["state"]
		var k: String = p["key"]
		var card := UIK.vbox(2)
		c.add_child(UIK.card(card))
		card.add_child(UIK.label("✓ %s → %s · %s" % [InternalSupply.industry_name(p["seller"]), InternalSupply.industry_name(p["buyer"]), I18n.t(str(l["good"]))], 8, Art.C_GREEN, true))
		card.add_child(UIK.wrap(I18n.t(str(l["effect"])), 7, Art.C_MUTED, 430))
		var unit := I18n.t(str(l["unit_label"]))
		card.add_child(UIK.kv(I18n.t("Transfer price per %s") % unit, Fmt.money(float(p["price"])), Art.C_GOLD))
		card.add_child(UIK.kv(I18n.t("Your cost / outside market"), "%s / %s" % [Fmt.money(float(p["cost"])), Fmt.money(float(p["market"]))]))
		var modes := UIK.hbox(3)
		card.add_child(modes)
		var plus_label := I18n.t("Cost + %d%%") % roundi(float(st["markup"]) * 100.0)
		for m in [["cost", I18n.t("At cost")], ["plus", plus_label], ["market", I18n.t("Market price")]]:
			var on: bool = st["mode"] == m[0]
			var label: String = ("● " if on else "") + m[1]
			_btn(os, modes, label, "GroupMode_" + k.replace(":", "_") + "_" + str(m[0]), _set_mode.bind(k, m[0]), none)
		if not bool(l.get("native", false)):
			_btn(os, modes, I18n.t("Resume") if st["paused"] else I18n.t("Pause"), "GroupPause_" + k.replace(":", "_"), func(): return InternalSupply.set_paused(k, not st["paused"]), none)
		var life := InternalSupply.lifetime(k)
		if int(life["trades"]) > 0:
			card.add_child(UIK.wrap(I18n.t("Traded %s %s · internal sales %s · saved versus outside %s") % [str(snappedf(float(life["qty"]), 0.1)), unit, Fmt.money0(float(life["revenue"])), Fmt.money0(float(life["saving"]))], 7, Art.C_SKY, 430))
		else:
			card.add_child(UIK.label("✗ " + I18n.t("No trade yet. The first one settles at 22:00."), 7, Art.C_DIM))


static func _set_mode(k: String, mode: String) -> Dictionary:
	var st := InternalSupply.state(k)
	var markup := -1.0
	if mode == "plus":
		var options: Array = InternalSupply.cfg().get("markup_options", [0.2])
		# pressing Cost + X% again steps to the next markup
		if st["mode"] == "plus":
			var i := options.find(float(st["markup"]))
			markup = float(options[(i + 1) % options.size()])
		else:
			markup = float(st["markup"])
	return InternalSupply.set_policy(k, mode, markup)


static func _consolidated(c: VBoxContainer) -> void:
	c.add_child(UIK.sep())
	var entity := GameState.business_entity()
	var t0 := Clock.month_start()
	var r := InternalSupply.group_report(entity, t0, Clock.now() + 1)
	c.add_child(UIK.label(I18n.t("GROUP THIS MONTH (internal trade eliminated)"), 7, Art.C_DIM, true))
	c.add_child(UIK.kv("Segment sales added up", Fmt.money0(float(r["segments_sum_revenue"]))))
	c.add_child(UIK.kv("Eliminated internal sales", Fmt.money0(-float(r["eliminated"]))))
	c.add_child(UIK.kv("Group net revenue", Fmt.money0(float(r["net_revenue"])), Art.C_GOLD))
	c.add_child(UIK.kv("Group operating profit", Fmt.money0(float(r["operating_profit"])), UIK.money_color(float(r["operating_profit"]))))
	c.add_child(UIK.label(("✓ " + I18n.t("Internal sales equal internal purchases.")) if r["balanced"] else ("✗ " + I18n.t("Internal sales and purchases differ; check the ledger.")), 7, Art.C_GREEN if r["balanced"] else Art.C_RED))


static func _jobs(os, c: VBoxContainer, primary: Array) -> void:
	c.add_child(UIK.sep())
	os._section("Group jobs")
	var any := false
	for job in GroupJobs.offered():
		any = true
		var def: Dictionary = GroupJobs.defs()[job["def"]]
		var card := UIK.vbox(2)
		c.add_child(UIK.card(card))
		card.add_child(UIK.label("%s · %s" % [I18n.t(str(def["title"])), I18n.t(str(def["client_name"]))], 9, Art.C_GOLD, true))
		card.add_child(UIK.wrap(I18n.t(str(def["pitch"])), 7, Art.C_MUTED, 430))
		card.add_child(UIK.kv("Reward if every part is done", Fmt.money0(float(def["reward"])), Art.C_GREEN))
		card.add_child(UIK.kv("Time to finish", I18n.t("%d days") % int(def["deadline_days"])))
		for part in def["parts"]:
			var mine := InternalSupply.running(str(part["industry"]))
			card.add_child(UIK.label("%s %s: %s · %s" % ["✓" if mine else "✗", InternalSupply.industry_name(str(part["industry"])), I18n.t(str(part["label"])), Fmt.money0(float(def["reward"]) * float(part["share"]))], 7, Art.C_GREEN if mine else Art.C_GOLD))
		card.add_child(UIK.wrap(I18n.t("A part from a business you do not run, or cannot finish, can be subcontracted for a fee. Unfinished parts at the deadline pay nothing."), 7, Art.C_DIM, 430))
		_btn(os, card, I18n.t("Accept group job"), "GroupAccept_" + str(job["id"]), GroupJobs.accept.bind(job["id"]), primary, true)
	for job in GroupJobs.active():
		any = true
		var def: Dictionary = GroupJobs.defs()[job["def"]]
		var card := UIK.vbox(2)
		c.add_child(UIK.card(card))
		var left := maxi(0, int(ceil(float(int(job["deadline"]) - Clock.now()) / Clock.DAY)))
		card.add_child(UIK.label("%s · %s" % [I18n.t(str(def["title"])), I18n.t("%d days left") % left], 9, Art.C_GOLD, true))
		for part in def["parts"]:
			var ps := GroupJobs.part_state(job, part)
			var tag := "✓" if ps["done"] else "✗"
			var progress := I18n.t("subcontracted") if ps["sub"] else "%d/%d" % [int(ps["have"]), int(ps["target"])]
			card.add_child(UIK.label("%s %s: %s · %s" % [tag, InternalSupply.industry_name(str(part["industry"])), I18n.t(str(part["label"])), progress], 7, Art.C_GREEN if ps["done"] else Art.C_WHITE))
			if not ps["done"]:
				_btn(os, card, I18n.t("Subcontract %s for %s") % [InternalSupply.industry_name(str(part["industry"])), Fmt.money0(float(part["subcontract"]))],
					"GroupSub_" + str(job["id"]) + "_" + str(part["id"]), GroupJobs.subcontract.bind(job["id"], part["id"]), primary)
		card.add_child(UIK.kv("Pays if closed now", Fmt.money0(GroupJobs.earned(job)), Art.C_GREEN))
		card.add_child(UIK.wrap(I18n.t("Next step: %s") % GroupJobs.next_step(job), 7, Art.C_SKY, 430))
	var recent := GroupJobs.finished()
	for i in range(maxi(0, recent.size() - 2), recent.size()):
		var done: Dictionary = recent[i]
		var d: Dictionary = GroupJobs.defs().get(done["def"], {})
		c.add_child(UIK.label("%s %s · %s %s" % ["✓" if done["status"] == "completed" else "✗", I18n.t(str(d.get("title", done["def"]))), I18n.t("paid"), Fmt.money0(float(done["paid"]))], 7, Art.C_MUTED))
	if not any:
		c.add_child(UIK.label("✗ " + I18n.t("No group job on offer."), 8, Art.C_GOLD, true))
		c.add_child(UIK.wrap(I18n.t("Next step: run two or more businesses. Clients with big orders phone you; the offer lasts about ten days."), 7, Art.C_SKY, 450))


static func _milestones(c: VBoxContainer) -> void:
	c.add_child(UIK.sep())
	var total := Milestones.count()
	c.add_child(UIK.label(I18n.t("MILESTONES %d of %d") % [total[0], total[1]], 7, Art.C_DIM, true))
	var line: Array = []
	for entry in Industries.all():
		var n := Milestones.count(entry["id"])
		line.append("%s %d/%d" % [InternalSupply.industry_name(entry["id"]), n[0], n[1]])
	c.add_child(UIK.wrap(" · ".join(line), 7, Art.C_MUTED, 450))
	c.add_child(UIK.wrap(I18n.t("Full list: phone, Timeline, Achievements."), 7, Art.C_DIM, 450))
