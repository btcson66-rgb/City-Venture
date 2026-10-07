class_name IndustryGuideModal
extends Modal
var industry: String
func _init(id: String) -> void:
	industry=id;title_text="First industry order";help_key="industry_first_order";icon_name="tasks";panel_size=Vector2(450,310);pauses_time=true
func build() -> void:
	IndustryGuidance.skip_completed(industry)
	var p:=IndustryGuidance.progress(industry);var d:=IndustryGuidance.guide(industry)
	if d.is_empty():return
	var box:=UIK.vbox(6);body.add_child(box)
	if p["skipped"] or int(p["step"])>=d["objectives"].size():
		box.add_child(UIK.wrap("✓ "+I18n.t("Guide finished. Continue from your industry tab."),10,Art.C_GREEN,410))
		footer.add_child(UIK.button("Close",close,"primary"));return
	var step: Dictionary=d["objectives"][p["step"]]
	box.add_child(UIK.label(I18n.t("FIRST ORDER %d/%d")%[int(p["step"])+1,d["objectives"].size()],10,Art.C_SKY))
	box.add_child(UIK.wrap("✗ "+I18n.t(step["text"]),10,Art.C_WHITE,410))
	box.add_child(UIK.wrap("You can skip this guide and continue operating. Already completed work is never repeated.",8,Art.C_MUTED,410))
	var b:=UIK.button("Continue in the industry tab",close,"primary")
	b.name="IndustryGuideContinue";footer.add_child(b)
	var skip:=UIK.button("Skip this guide",func():p["skipped"]=true;close())
	skip.name="IndustryGuideSkip";footer.add_child(skip)
