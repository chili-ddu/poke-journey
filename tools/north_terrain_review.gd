extends "res://tools/kanto_expansion_review.gd"
func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	await open_fixture("kanto_north")
	game.ui_root.visible=false
	var points := [Vector2i(20,40),Vector2i(31,40),Vector2i(55,40),Vector2i(74,18),Vector2i(79,17),Vector2i(92,17),Vector2i(110,25)]
	var i := 0
	for tile in points:
		game.world.player.position=Arena.resolve(Arena.tile_center(tile),game.world.player.radius)
		walker.target=game.world.player.position
		game.view3d._cam_ready=false
		await shot("terrain_north_%02d"%i)
		i+=1
	for place in ["mt_moon_1f","mt_moon_b1f","mt_moon_b2f"]:
		await open_fixture(place)
		game.ui_root.visible=false
		var warps := Arena.warps().duplicate()
		for warp in warps:
			var tile := Vector2i(int(warp.x),int(warp.y))
			for dir in [Vector2i.DOWN,Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:
				var next: Vector2i = tile+dir
				if not Arena.solid_at(next.x,next.y) and Arena.warp_at(Arena.tile_center(next)).is_empty():
					game.world.player.position=Arena.resolve(Arena.tile_center(next),game.world.player.radius)
					break
			walker.target=game.world.player.position
			game.view3d._cam_ready=false
			await shot("terrain_"+place+"_%02d"%int(warp.index))
	print("Northern terrain and cave warp views captured")
	game.queue_free()
	await process_frame
	quit()
