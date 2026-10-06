class_name FitnessModal
extends Modal
var desk := false
var attending := false

func _init(at_desk := false) -> void:
	desk=at_desk
	title_text="Harbor Point Fitness"
	icon_name="people"
	help_key="fitness"
	panel_size=Vector2(500,340)

func build() -> void:
	body.add_child(UIK.label_tip("Membership and business connections","networking"))
	if Clock.now()<int(ShopLife.S()["paid_until"]): body.add_child(UIK.wrap(I18n.t("✓ Membership paid until %s — choose a class.")%Clock.fmt_short(int(ShopLife.S()["paid_until"])),8,Art.C_SKY,460))
	elif bool(ShopLife.S()["single"]): body.add_child(UIK.wrap("✓ Single-class pass ready — choose a class.",8,Art.C_SKY,460))
	else: body.add_child(UIK.wrap("✗ No class pass — buy one at Rosa's reception.",8,Art.C_GOLD,460))
	if desk:
		if not bool(ShopLife.S()["membership"]):
			var monthly := UIK.button(I18n.t("Join · %s per month")%Fmt.money(float(ShopLife.cfg()["monthly_fee"])),purchase.bind(true))
			monthly.name="FitnessMonthly"
			body.add_child(monthly)
		else:
			var cancel := UIK.button("Cancel future renewals; keep paid access",func(): ShopLife.cancel();rebuild())
			cancel.name="FitnessCancel"
			body.add_child(cancel)
		if not ShopLife.has_pass():
			var single := UIK.button(I18n.t("Single class · %s")%Fmt.money(float(ShopLife.cfg()["single_fee"])),purchase.bind(false),"primary")
			single.name="FitnessSingle"
			body.add_child(single)
	var main := false
	for item in ShopLife.cfg()["class_times"]:
		var minute := int(item["minute"])
		var receipt := "%d:%s"%[Clock.day_index(),item["id"]]
		var available: bool = not ShopLife.S()["classes"].has(receipt) and Clock.minute_of_day()>=minute and Clock.minute_of_day()<minute+int(ShopLife.cfg()["class_grace_minutes"]) and ShopLife.has_pass()
		var button := UIK.button(I18n.t("%02d:%02d · %s · %d minutes")%[minute/60,minute%60,I18n.t(item["name"]),int(ShopLife.cfg()["class_minutes"])],attend.bind(str(item["id"])),"primary" if available and not main else "")
		button.name="FitnessClass_"+item["id"]
		button.disabled=not available
		if available:main=true
		body.add_child(button)
	if ShopLife.has_pass() and not main:
		var next := Clock.now()+Clock.DAY
		for item in ShopLife.cfg()["class_times"]: next=mini(next,Clock.next_time_of_day(int(item["minute"])))
		var wait := UIK.button(I18n.t("Wait for the next class · %d minutes")%(next-Clock.now()),func(): Clock.advance_to(next);rebuild(),"primary")
		wait.name="FitnessWait"
		body.add_child(wait)
	body.add_child(UIK.wrap("Arrive within ten minutes of class start. A class takes one hour; connections offer business choices, never automatic income.",8,Art.C_MUTED,460))
	footer.add_child(UIK.button("Close",close))

func purchase(monthly: bool) -> void:
	var result := ShopLife.buy(monthly)
	if not result["ok"]: UIRoot.toast(result["error"],"warn","people")
	rebuild()

func attend(id: String) -> void:
	if attending:return
	attending=true
	var scene := SceneRouter.world_scene()
	if scene!=null and scene.player!=null: scene.player.rig.set_pose("interact")
	await get_tree().create_timer(0.5).timeout
	var result := ShopLife.attend(id)
	if scene!=null and is_instance_valid(scene) and scene.player!=null: scene.player.rig.set_pose("")
	if not result["ok"]:UIRoot.toast(result["error"],"warn","people");attending=false;rebuild()
	else:close()


func _exit_tree() -> void:
	# Closing during the short animation must not leave the player frozen in an interaction pose.
	if attending:
		var scene := SceneRouter.world_scene()
		if scene!=null and scene.player!=null:scene.player.rig.set_pose("")
