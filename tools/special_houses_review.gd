extends "res://tools/kanto_expansion_review.gd"
func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_special_houses_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	var places := {"cerulean_city_house1":[Vector2i(5,6),Vector2i(3,3)],"cerulean_city_house2":[Vector2i(3,6),Vector2i(6,3)],"cerulean_city_house5":[Vector2i(6,6),Vector2i(6,3)],"route5_pokemon_day_care":[Vector2i(5,6),Vector2i(3,3)]}
	for place in places:
		await open_fixture(place)
		game.ui_root.visible=false
		var index := 0
		for tile in places[place]:
			game.world.player.position=Arena.resolve(Arena.tile_center(tile),game.world.player.radius)
			walker.target=game.world.player.position
			game.view3d._cam_ready=false
			await shot("objects_"+place+"_%d"%index)
			index+=1
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DungeonDB.theme().map+"/hd2d_cards.json"))
		print("FACILITY ",place," objects=",data.facility_objects.size()," reachable=",reachable().size())
	for place in places:
		await open_fixture(place)
		var exit_tile := Arena.tile_of(game.world.player.position)
		for dir in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			var next: Vector2i = exit_tile+dir
			if not Arena.solid_at(next.x,next.y) and Arena.warp_at(Arena.tile_center(next)).is_empty():
				await walk_to(next)
				break
		await walk_to(exit_tile,true)
		await arrive("kanto_north","objects_exit_"+place)
	for place in ["cerulean_city_house1","cerulean_city_house2"]:
		await open_fixture(place)
		var rear := Arena.warp_tile(place,3)
		assert(rear.x>=0)
		await walk_to(Arena.tile_of(game.world.player.position)+Vector2i.UP)
		await walk_to(rear,true)
		await arrive("kanto_north","objects_rear_exit_"+place)
	print("Four front exits and two rear exits walked successfully")
	game.queue_free()
	await process_frame
	quit()
