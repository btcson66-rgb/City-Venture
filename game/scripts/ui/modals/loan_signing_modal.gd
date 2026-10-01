class_name LoanSigningModal
extends Modal
## Explicit consent to the afternoon signing cost; disbursement is revalidated after confirmation.
var sign: Callable

func _init(callback: Callable) -> void:
	sign = callback
	pauses_time = true
	title_text = "Sign the loan"
	icon_name = "bank"
	help_key = "loans"
	panel_size = Vector2(390, 0)

func build() -> void:
	body.add_child(UIK.wrap("Signing takes the afternoon; funds arrive today. First payment in 30 days.", 9, Art.C_WHITE, 360))
	var confirm := UIK.button("Confirm loan signing", func(): close(); sign.call(), "primary")
	confirm.name = "ConfirmLoan"
	footer.add_child(confirm)
	var cancel := UIK.button("Cancel", close)
	cancel.name = "CancelLoan"
	footer.add_child(cancel)
	_fit.call_deferred()


## Fit translated signing text and buttons naturally, following the decision-window review convention.
func _fit() -> void:
	await get_tree().process_frame
	panel.size = Vector2(panel_size.x, 0)
	panel.reset_size()
	panel.position = (Vector2(640, 360) - panel.size) / 2.0
