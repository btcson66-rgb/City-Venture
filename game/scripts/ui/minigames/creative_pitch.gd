class_name CreativePitch
extends MiniGame
## Three client-preference card choices; actual creative score feeds campaign CTR.
var brief := {}
var selections: Array=[]
func _init(client_brief: Dictionary) -> void:
	super._init()
	brief=client_brief
	rounds=3
	round_time=float(Media.cfg().get("creative_round_seconds",15))
	title_text="Creative Pitch"
	help_key="creative_pitch"
	icon_name="star"
func intro_lines() -> Array:
	return ["Build the client pitch from slogan, visual and tone cards.","Match the preferences above the cards. Take your time; the challenge clock is optional.","A matching card earns the point. Waiting never lowers your score."]
func build_round() -> void:
	var category: String=["slogan","visual","tone"][round_i]
	var cards := UIK.vbox(6)
	cards.position=Vector2(10,8)
	cards.size=Vector2(550,220)
	stage.add_child(cards)
	cards.add_child(UIK.wrap(I18n.t("%s · audience: %s")%[I18n.t(str(brief.get("client",""))),I18n.t(Media.cfg()["audiences"][int(brief["audience"])])],10,Art.C_SKY,520))
	var preferences: Array=brief["preferences"]
	var wanted: Array=[]
	for k in 3:wanted.append(I18n.t(Media.cfg()["creative_cards"][["slogan","visual","tone"][k]][int(preferences[k])]))
	cards.add_child(UIK.wrap(I18n.t("Client preferences: %s / %s / %s")%wanted,8,Art.C_SKY,520))
	var options: Array=Media.cfg()["creative_cards"][category]
	var order: Array=range(options.size())
	# The order is shuffled per brief and round so the right card is not always in the same place.
	var shuffle := RandomNumberGenerator.new()
	shuffle.seed=hash(str(brief.get("id",""))+category)
	for n in range(order.size()-1,0,-1):
		var j := shuffle.randi_range(0,n)
		var t=order[n];order[n]=order[j];order[j]=t
	for i in order:
		var card := UIK.button(options[i],choose.bind(i),"button")
		card.name="CreativeCard_"+category+"_"+str(i)
		cards.add_child(card)
func choose(index: int) -> void:
	selections.append(index)
	award(1 if index==int(brief["preferences"][round_i]) else 0)
	next_round()
func result_lines() -> Array:return [I18n.t("Creative quality: %d%%. Client fit changes campaign clicks.")%roundi(score()*100)]
