extends "res://tools/kanto_expansion_review.gd"
const FRONT := {
	"cerulean_city":[0,1,2,3,4,5,6,12,13],
	"vermilion_city":[3,4,5,6,7,8,9],
}
func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_city_exteriors_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	var rear_only := OS.get_environment("EXTERIORS_REAR_ONLY")=="1"
	for place in ([] if rear_only else ["kanto_north","kanto_east"]):
		await open_fixture(place)
		game.ui_root.visible=false
		var city := "cerulean_city" if place=="kanto_north" else "vermilion_city"
		var warps := Arena.warps().duplicate()
		for id in FRONT[city]:
			var door := Vector2i(-1,-1)
			var target := ""
			for warp in warps:
				if warp.map==city and int(warp.index)==id:
					door=Vector2i(int(warp.x),int(warp.y));target=DungeonDB.WARP_MAPS[warp.to];break
			assert(door.x>=0)
			await open_fixture(place)
			var approach := door
			for delta in [Vector2i.DOWN*2,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]:
				var candidate: Vector2i = door+delta
				var center := Arena.tile_center(candidate)
				if not Arena.solid_at(candidate.x,candidate.y) and Arena.warp_at(center).is_empty() and center.distance_to(Arena.resolve(center,game.world.player.radius))<0.1:
					approach=candidate;break
			assert(approach!=door)
			game.world.player.position=Arena.tile_center(approach)
			walker.target=game.world.player.position
			game.view3d._cam_ready=false
			game.ui_root.visible=false
			await shot("exterior_"+target)
			print("ENTER ",target)
			await walk_to(door,true)
			await arrive(target,"exterior_inside_"+target)
			var arrival := Arena.tile_of(game.world.player.position)
			for dir in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				var next: Vector2i = arrival+dir
				if not Arena.solid_at(next.x,next.y) and Arena.warp_at(Arena.tile_center(next)).is_empty():
					await walk_to(next);break
			await walk_to(arrival,true)
			await arrive(place,"exterior_return_"+target)
	for id in [8,9]:
		await open_fixture("kanto_north")
		var door := Arena.warp_tile("cerulean_city",id)
		var target: String = DungeonDB.WARP_MAPS[Arena.warp_at(Arena.tile_center(door)).to]
		game.world.player.position=Arena.tile_center(door+Vector2i.UP)
		walker.target=game.world.player.position
		game.view3d._cam_ready=false
		game.ui_root.visible=false
		await shot("exterior_rear_"+str(id))
		await walk_to(door,true)
		await arrive(target,"exterior_rear_inside_"+str(id))
		var arrival := Arena.tile_of(game.world.player.position)
		await walk_to(arrival+Vector2i.DOWN)
		await walk_to(arrival,true)
		await arrive("kanto_north","exterior_rear_return_"+str(id))
	var report := "city_rear_checks.json" if rear_only else "city_exteriors_checks.json"
	FileAccess.open(OUT+report,FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	print("City entrances/returns passed: ",results.size()," transitions; rear_only=",rear_only)
	game.queue_free()
	await process_frame
	quit()
