class_name CreativePitch
extends MiniGame
## Three client-preference card choices; actual creative score feeds campaign CTR.
var brief := {}
var selections: Array=[]
func _init(client_brief: Dictionary) -> void:
	super._init()
	brief=client_brief
	rounds=3
	round_time=0
	title_text="Creative Pitch"
	help_key="creative_pitch"
	icon_name="star"
func intro_lines() -> Array:
	return ["Build the client pitch from slogan, visual and tone cards.","Read the audience preferences in the brief. Matching cards improve click-through."]
func build_round() -> void:
	var category: String=["slogan","visual","tone"][round_i]
	var cards := UIK.vbox(6)
	cards.position=Vector2(10,8)
	cards.size=Vector2(550,220)
	stage.add_child(cards)
	cards.add_child(UIK.wrap(I18n.t("Audience: %s")%I18n.t(Media.cfg()["audiences"][int(brief["audience"])]),10,Art.C_GOLD,520))
	var options: Array=Media.cfg()["creative_cards"][category]
	for i in options.size():
		var card := UIK.button(options[i],choose.bind(i),"primary" if i==0 else "button")
		card.name="CreativeCard_"+category+"_"+str(i)
		cards.add_child(card)
func choose(index: int) -> void:
	selections.append(index)
	award(1 if index==int(brief["preferences"][round_i]) else 0)
	next_round()
func result_lines() -> Array:return [I18n.t("Creative quality: %d%%. Client fit changes campaign clicks.")%roundi(score()*100)]
