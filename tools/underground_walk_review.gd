extends "res://tools/north_walk_review.gd"
func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_underground_walk_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	var plans: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUT+"underground_walk_plan.json"))
	var report := {}
	for direction in plans:
		var plan: Dictionary = plans[direction]
		automatic_jumps=0
		results=[]
		await open_fixture(plan.start[0])
		game.world.player.position=Arena.tile_center(Vector2i(int(plan.start[1]),int(plan.start[2])))
		walker.target=game.world.player.position
		var i := 0
		for leg in plan.legs:
			print("WALK ",direction," ",leg.place," -> ",leg.goal)
			assert(DungeonDB.current==leg.place)
			await walk_to(Vector2i(int(leg.goal[0]),int(leg.goal[1])),leg.to!="")
			if leg.to!="":await arrive(leg.to,"underground_walk_"+direction+"_%d"%i)
			i+=1
		var expected := "vermilion_city" if direction=="southbound" else "cerulean_city"
		assert(Arena.area_at(game.world.player.position)==expected)
		report[direction]={"destination":expected,"planned_steps":plan.walk_steps,"actual_automatic_jumps":automatic_jumps,"transitions":results.duplicate()}
		await shot("underground_walk_"+direction+"_arrived")
	for place in ["route5_south_entrance","route6_north_entrance"]:
		await open_fixture(place)
		var exit_tile := Vector2i(4,1) if place=="route5_south_entrance" else Vector2i(4,9)
		game.world.player.position=Arena.tile_center(exit_tile+(Vector2i.DOWN if exit_tile.y==1 else Vector2i.UP))
		walker.target=game.world.player.position
		game.warp_armed=true
		await walk_to(exit_tile,true)
		await arrive("kanto_north" if place=="route5_south_entrance" else "kanto_east","underground_gate_exit_"+place)
		print("GATE returned to route: ",place)
	FileAccess.open(OUT+"underground_walk_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("Cerulean <-> Vermilion: both native routes walked through underground path")
	game.queue_free()
	await process_frame
	quit()
