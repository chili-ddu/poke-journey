extends "res://tools/kanto_water_review.gd"
func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_kanto_water_resume_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("SEED","17")
	await open_fixture("kanto_east")
	assert(find_shore("vermilion_city"))
	assert(game.world.field_water.surf(game.world))
	var at: Vector2=game.world.player.position
	SaveData.store(game.world.player,[],"kanto_east",at)
	var saved := SaveData.load_saved()
	assert(saved.pos.distance_to(at)<0.1,"Water position stored")
	load("res://scripts/game.gd").destination={"map":saved.map,"pos":saved.pos,"layout":saved.layout}
	await open_fixture("kanto_east")
	assert(game.world.player.position.distance_to(at)<0.1,"Saved water position restored")
	assert(game.world.player.travel_terrain==2,"Surf restored on resume")
	assert(Arena.is_water(Arena.tile_of(game.world.player.position)))
	game.world.step(1.0/60.0)
	assert(game.world.player.position.distance_to(at)<0.1,"Does not eject onto a shore or wall")
	print("KANTO WATER RESUME PASSED")
	quit()
