extends "res://tools/kanto_expansion_review.gd"
func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_city_facilities_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	var places := {"cerulean_city_bike_shop":[Vector2i(6,5),Vector2i(6,3)],"vermilion_city_pokemon_fan_club":[Vector2i(5,8),Vector2i(3,3)],"cerulean_city_gym":[Vector2i(8,17),Vector2i(4,4)],"vermilion_city_gym":[Vector2i(5,17),Vector2i(5,9),Vector2i(5,4)]}
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
		await arrive("kanto_north" if String(place).begins_with("cerulean") else "kanto_east","objects_exit_"+place)
	print("Four facility exits walked successfully")
	game.queue_free()
	await process_frame
	quit()
