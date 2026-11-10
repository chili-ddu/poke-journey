extends "res://tools/kanto_expansion_review.gd"
func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	for place in ["mt_moon_1f","mt_moon_b1f","mt_moon_b2f"]:
		await open_fixture(place)
		game.ui_root.visible=false
		var here := Arena.tile_of(game.world.player.position)
		var pos := Arena.tile_center(here+Vector2i.UP*2)
		if pos.distance_to(Arena.resolve(pos,game.world.player.radius))<0.1: game.world.player.position=pos
		walker.target=game.world.player.position
		game.view3d._cam_ready=false
		await shot(place)
		assert(game.view3d.root3d.has_node("TerrainHeightfield"),"Actual heightfield renderer active")
		for warp in Arena.warps():
			var tile := Vector2i(int(warp.x),int(warp.y))
			var found := false
			for dir in [Vector2i.DOWN,Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:
				var at := Arena.tile_center(tile+dir)
				if Arena.warp_at(at).is_empty() and Arena.resolve(at,game.world.player.radius).distance_to(at)<0.1:
					game.world.player.position=at
					found=true
					break
			assert(found,"Clear ladder/exit approach")
			walker.target=game.world.player.position
			game.view3d._cam_ready=false
			await shot("elevation_"+place+"_warp_"+str(warp.index))
		print("CAVE terrain reviewed: ",place)
	game.queue_free()
	await process_frame
	quit()
