class_name PopupCheckoutGame
extends MiniGame
## Reuses the counter minigame flow, with checkout arithmetic instead of coffee recipes.
var correct:=0.0
var rng:=RandomNumberGenerator.new()
func _init() -> void:
	super._init();title_text="Pop-up checkout";icon_name="cash";rounds=4;round_time=20;rng.seed=Clock.now()*7+11
func intro_lines() -> Array:return ["Read the basket quantity and unit price, then choose the correct card charge.","Accurate checkout improves conversion during your one-hour shift. Waiting does not lower quality; practice creates no income."]
func round_name() -> String:return "Customer %d / %d"
func build_round() -> void:
	var stocked: Array=PopupStore.active().get("prices",{}).keys()
	if stocked.is_empty():award(0);next_round();return
	var product: String=stocked[rng.randi_range(0,stocked.size()-1)]
	var quantity:=rng.randi_range(1,3)
	var price:=float(PopupStore.active()["prices"][product]);correct=snappedf(quantity*price,.01)
	var box:=UIK.vbox(8);stage.add_child(box)
	box.add_child(UIK.wrap(I18n.t("Basket: %s · %d units × %s/unit")%[I18n.t(DataDB.products[product]["name"]),quantity,Fmt.money(price)],11,Art.C_WHITE,530))
	var options: Array=[correct,snappedf(correct+price*.5,.01),snappedf(maxf(.01,correct-price*.25),.01)]
	# Shuffle with the local minigame RNG; playing never changes market demand randomness.
	for i in range(options.size()-1,0,-1):
		var j:=rng.randi_range(0,i);var old: float=options[i];options[i]=options[j];options[j]=old
	for i in options.size():
		var amount: float=options[i]
		var button:=UIK.button(I18n.t("Charge %s")%Fmt.money(amount),func():award(1.0 if is_equal_approx(amount,correct) else 0.0);next_round())
		button.set_meta("practice_correct", is_equal_approx(amount,correct))
		button.name="PopupCharge_"+str(i);box.add_child(button)
func result_lines() -> Array:return [I18n.t("Checkout practice complete. Your one-hour shift now uses real visitors and available stock.")]
