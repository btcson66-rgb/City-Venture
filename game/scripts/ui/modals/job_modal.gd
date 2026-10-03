class_name JobModal
extends Modal
## A part-time job, opened at the workplace's staff door or from the Business Board: apply, work a
## 4-hour shift (time passes, wage paid), see the promotion ladder and the job's perk, or quit.

var job_id := ""


func _init(id: String) -> void:
	job_id = id
	var j := Careers.job_def(id)
	title_text = I18n.t("Part-time job — %s") % I18n.t(str(j.get("employer", "")))
	icon_name = "people"
	help_key = "job"
	panel_size = Vector2(420, 262)


func build() -> void:
	var j := Careers.job_def(job_id)
	var hired := Careers.current_job() == job_id
	var top := UIK.hbox(6)
	body.add_child(top)
	top.add_child(UIK.title(I18n.t(str(Careers.rank(job_id)["title"])), 13, Art.C_GOLD))
	top.add_child(UIK.expand())
	top.add_child(UIK.chip(I18n.t("YOUR JOB") if hired else I18n.t("HIRING"), Art.C_GREEN if hired else Art.C_SKY))
	body.add_child(UIK.wrap(I18n.t(str(j.get("blurb", ""))), 8, Art.C_SKY, 400))
	var h: Dictionary = DataDB.building(str(j["building"])).get("hours", {})
	var days := str(h.get("days", "all"))
	body.add_child(UIK.kv("Pay", I18n.t("$%d / hour · %s per 4-hour shift") % [int(Careers.wage(job_id)), Fmt.money0(Careers.shift_pay(job_id))], Art.C_GREEN))
	body.add_child(UIK.kv("Shifts", I18n.t("Any time %s–%s, %s · one shift a day") % [h.get("open", ""), h.get("close", ""),
		I18n.t("every day") if days == "all" else I18n.t("Mon–Fri")]))
	body.add_child(UIK.kv("Perk", I18n.t(str(j.get("perk", {}).get("desc", ""))), Art.C_GOLD))
	# promotion ladder
	var ladder := UIK.hbox(4)
	body.add_child(ladder)
	var ranks: Array = j.get("ranks", [])
	var ri := Careers.rank_index(job_id)
	for i in ranks.size():
		var r: Dictionary = ranks[i]
		var col := Art.C_GOLD if i == ri else (Art.C_GREEN if i < ri else Art.C_DIM)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UIK.flat(Color(0.06, 0.1, 0.18, 0.9), col, 1, 2))
		var v := UIK.vbox(0)
		p.add_child(v)
		v.add_child(UIK.label(I18n.t(str(r["title"])), 7, col, true))
		v.add_child(UIK.label(I18n.t("$%d/h · from %d shifts") % [int(r["wage"]), int(r["shifts"])], 6, Art.C_MUTED))
		ladder.add_child(p)
	body.add_child(UIK.label(I18n.t("Shifts worked: %d") % Careers.shifts(job_id), 7, Art.C_MUTED, true))
	body.add_child(UIK.label("You do the work yourself: the better the shift goes, the more you earn (60% of the wage is guaranteed).", 7, Art.C_SKY))
	var nr := Careers.next_rank(job_id)
	if not nr.is_empty():
		body.add_child(UIK.label(I18n.t("%d more shift(s) to %s") % [int(nr["shifts"]) - Careers.shifts(job_id), I18n.t(str(nr["title"]))], 7, Art.C_SKY))
	# actions
	if hired:
		var why := Careers.shift_block(job_id)
		var here := SceneRouter.world_scene() != null and SceneRouter.world_scene().scene_id == str(j["building"])
		if not here:
			why = "go to the workplace to work a shift"
		var hrs := Careers.shift_hours_now(job_id) if Careers.shift_block(job_id) == "" else int(j.get("shift_hours", 4))
		var b := UIK.button(I18n.t("Start a %d-hour shift (up to +%s)") % [hrs, Fmt.money0(Careers.pay_for(job_id, 1.0, hrs))], _work, "primary" if why == "" else "")
		b.name = "WorkShift"
		b.disabled = why != ""
		footer.add_child(b)
		if why != "":
			body.add_child(UIK.label(I18n.t("Can't start a shift now: %s.") % I18n.t(why), 7, Art.C_GOLD, true))
		footer.add_child(UIK.button("Quit job", func():
			Careers.quit()
			UIRoot.toast(I18n.t("You left the job at %s.") % I18n.t(str(j["employer"])), "info", "people")
			rebuild()))
	else:
		var cur := Careers.current_job()
		if cur != "":
			body.add_child(UIK.label(I18n.t("Taking this job means leaving %s.") % I18n.t(str(Careers.job_def(cur)["employer"])), 7, Art.C_GOLD, true))
		var a := UIK.button("Take the job", _apply, "primary")
		a.name = "ApplyJob"
		footer.add_child(a)
	footer.add_child(UIK.button("Close", close))


func _apply() -> void:
	var r := Careers.hire(job_id)
	if r["ok"]:
		UIRoot.toast(I18n.t("Hired! You're now a %s at %s.") % [I18n.t(str(Careers.rank(job_id)["title"])), I18n.t(str(Careers.job_def(job_id)["employer"]))], "good", "check")
	rebuild()


func _work() -> void:
	# the shift runs on UIRoot: this modal is freed on close, which would cancel an await here
	UIRoot.work_shift_flow(job_id)
	close()
