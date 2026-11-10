extends "res://tools/north_walk_review.gd"

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_region_elevation_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	await open_fixture("kanto_south")
	game.beaten.append(TrainerDB.rival_for(game.starter))
	game.ui_root.visible=false
	var start := Arena.area_tile("route1",Vector2i(12,38))
	var goal := Arena.area_tile("viridian_city",Vector2i(24,38))
	game.world.player.position=Arena.tile_center(start)
	walker.target=game.world.player.position
	game.view3d._cam_ready=false
	var lower := Arena.ground_height(game.world.player.position)
	await shot("region_elevation_route1_lower")
	await walk_to(goal)
	assert(current_scene==game and game.state!="warp","No field reload while reaching higher region")
	assert(Arena.area_at(game.world.player.position)=="viridian_city")
	var upper := Arena.ground_height(game.world.player.position)
	assert(upper-lower>1.0,"Road terraces accumulate into the city's permanent altitude")
	assert(automatic_jumps==0,"Uphill route follows the connecting paths rather than jumping backward over ledges")
	await shot("region_elevation_viridian_higher")
	FileAccess.open(OUT+"region_elevation_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"from":"route1","to":"viridian_city","starting_altitude":lower,"arrival_altitude":upper,"reload":false,"uphill_jumps":automatic_jumps},"  "))
	print("REGIONAL ELEVATION: Route 1 -> Viridian remains higher: ",lower," -> ",upper)
	game.queue_free()
	await process_frame
	quit()
