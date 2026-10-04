extends RefCounted
var bot
func _init(b) -> void: bot = b
func run() -> void:
	UIRoot._suppress_decisions = true
	Help.auto = false
	GameState.new_game({"name":"Alex Chen","seed":115})
	Clock.world_active = false
	GameState.data["tutorial"] = {"v":3,"off":true,"seen":{}}
	SceneRouter._enter("district","civic_center","metro", "up", Vector2(560,390))
	UIRoot.set_hud_visible(true)
	# Isolated contact setup: an existing rendered car's actual front is driven into the pedestrian.
	Clock.world_active = false
	var scene := SceneRouter.world_scene() as District
	for car in scene.cars: car.set_process(false)
	GameState.data["clock"]["minutes"] = 18*30
	await bot.wait(0.2)
	await bot.shot("green_crosswalk")
	var car: Car = scene.cars[0]
	car.lane_y = 424
	car.position.y = 424
	car.dir = 1
	car.speed = 75
	car.cur_speed = 75
	scene.player.global_position = Vector2(560,424)
	car.position.x = 560-car.length/2.0-2
	Clock.world_active = true
	car._process(0.1)
	Clock.world_active = false
	bot.expect(TrafficSafety.latest().is_empty() and car.cur_speed == 0,"green crossing stops live car without injury")
	GameState.data["clock"]["minutes"] = 18*30+9
	car.cur_speed = 75
	Clock.world_active = true
	car._process(0.1)
	Clock.world_active = false
	await bot.wait(0.3)
	bot.expect(TrafficSafety.S()["injury"] == "major","red crossing live swept contact causes major injury")
	bot.expect(not TrafficSafety.latest()["counterparty_fault"],"red crossing is pedestrian fault")
	await bot.shot("red_collision_injury")
	await bot.click_named("Ambulance")
	await bot.wait(0.9)
	bot.expect(SceneRouter.world_scene().scene_id == "civic_clinic","ambulance entered clinic interior")
	bot.expect(Actions.npc_present("dr_lin"),"doctor present")
	await bot.shot("hospital_admission")
	var before := Clock.now()
	await bot.click_named("Treatment")
	bot.expect(Clock.now()-before >= Clock.DAY and Clock.now()-before <= 3*Clock.DAY,"hospital advances one to three days")
	bot.expect(TrafficSafety.S()["injury"] == "none","discharged")
	bot.expect(Ledger.balance("player","exp:medical") == 1800,"actual medical bill")
	await bot.shot("discharge_bill")
	UIRoot.close_all()
	await bot.wait(0.2)
	await bot.shot("clinic_doctor")
	Actions.run("health_insurance",{})
	await bot.wait(0.2)
	await bot.click_named("BuyHealthPolicy")
	bot.expect(TrafficSafety.insured(),"monthly policy purchased after discharge")
	await bot.shot("health_policy")
	UIRoot.close_all()
	TrafficSafety.S()["cooldown"] = 0
	GameState.data["clock"]["minutes"] += 30
	TrafficSafety.hit(30,"civic_center",Vector2(600,424))
	Actions.run("clinic",{})
	await bot.wait(0.2)
	await bot.shot("pharmacy_medicine")
	await bot.click_named("Treatment")
	bot.expect(TrafficSafety.latest()["health_claim"] == 29.75,"pharmacy claim covers actual medicine expense")
	bot.expect(Ledger.check_balanced(),"all medical and insurance entries balanced")
	await bot.shot("medicine_recovery")
