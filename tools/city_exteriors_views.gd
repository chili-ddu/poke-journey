extends "res://tools/city_exteriors_review.gd"
func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	for place in ["kanto_north","kanto_east"]:
		await open_fixture(place)
		game.ui_root.visible=false
		var city := "cerulean_city" if place=="kanto_north" else "vermilion_city"
		for warp in Arena.warps():
			if warp.map!=city or int(warp.index) not in FRONT[city]:continue
			var door := Vector2i(int(warp.x),int(warp.y))
			game.world.player.position=Arena.resolve(Arena.tile_center(door+Vector2i.DOWN*2),game.world.player.radius)
			walker.target=game.world.player.position
			game.view3d._cam_ready=false
			await shot("exterior_"+String(DungeonDB.WARP_MAPS[warp.to]))
	print("Final city roof/front/shoreline views captured")
	game.queue_free()
	await process_frame
	quit()
