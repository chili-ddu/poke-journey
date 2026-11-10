extends "res://tools/kanto_expansion_review.gd"
func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	var places := {"kanto_north":[Vector2i(199,73),Vector2i(192,71)],"kanto_east":[Vector2i(31,15),Vector2i(24,8)],"route5_south_entrance":[Vector2i(4,5)],"route6_north_entrance":[Vector2i(4,5)],"underground_path_north_entrance":[Vector2i(6,7),Vector2i(7,5)],"underground_path_south_entrance":[Vector2i(6,7)],"underground_path_north_south_tunnel":[Vector2i(4,5),Vector2i(4,30),Vector2i(3,58)]}
	for place in places:
		await open_fixture(place)
		game.ui_root.visible=false
		var i := 0
		for tile in places[place]:
			game.world.player.position=Arena.resolve(Arena.tile_center(tile),game.world.player.radius)
			walker.target=game.world.player.position
			game.view3d._cam_ready=false
			await shot("underground_"+place+"_%d"%i)
			i+=1
	print("Underground and route entrance views captured")
	game.queue_free()
	await process_frame
	quit()
