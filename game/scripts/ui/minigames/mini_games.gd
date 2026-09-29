class_name MiniGames
extends RefCounted
## Which hands-on minigame each kind of work opens.
##   Part-time shifts → one game per job · "Shoot photos myself" → PhotoShootGame · packing table → PackGame
##   SaaS "Code for 2 hours" and freelance work sessions → TypingGame
## Bots and tests set `auto` to a quality (0..1): every minigame then finishes itself at that quality right after it
## opens, so the walkthrough exercises the real flow without scripting each game.

static var auto := -1.0


static func for_job(job_id: String) -> MiniGame:
	match job_id:
		"barista":
			return BaristaGame.new()
		"parcel_sorter":
			return ParcelSortGame.new()
		"cowork_host":
			return CoworkHostGame.new()
		"city_clerk":
			return ClerkFormsGame.new()
		"bank_teller":
			return TellerCashGame.new()
	return null


## Open `g` over whatever is on screen; `done(result)` when it ends ({score, ...} or {aborted: true}).
static func play(g: MiniGame, done: Callable) -> void:
	g.on_done = done
	UIRoot.open_modal(g)
	if auto >= 0.0:
		g.autoplay.call_deferred(auto)
