extends "res://tools/kanto_expansion_review.gd"
func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_city_outdoor_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	for place in ["kanto_north","kanto_east"]:
		await open_fixture(place)
		game.ui_root.visible=false
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DungeonDB.theme().map+"/hd2d_cards.json"))
		var seen := {}
		for obj in data.city_outdoor_props.objects:
			var kind: String = obj.kind
			if seen.has(kind):continue
			var xy: Array = obj.tiles[obj.tiles.size()/2]
			var tile := Vector2i(int(xy[0]),int(xy[1]))
			var approach := tile
			for offset in [Vector2i.DOWN*2,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]:
				var next: Vector2i = tile+offset
				var pos := Arena.tile_center(next)
				if not Arena.solid_at(next.x,next.y) and Arena.ledge_at(next.x,next.y)==0 and Arena.warp_at(pos).is_empty() and pos.distance_to(Arena.resolve(pos,game.world.player.radius))<0.1:
					approach=next;break
			if approach==tile:continue
			seen[kind]=true
			game.world.player.position=Arena.tile_center(approach)
			walker.target=game.world.player.position
			game.view3d._cam_ready=false
			await shot("outdoor_"+place+"_"+kind)
			# Exercise movement along the object boundary, without changing native collision.
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i = approach+offset
				var pos := Arena.tile_center(next)
				if not Arena.solid_at(next.x,next.y) and Arena.ledge_at(next.x,next.y)==0 and Arena.warp_at(pos).is_empty() and pos.distance_to(Arena.resolve(pos,game.world.player.radius))<0.1:
					await walk_to(next)
					await walk_to(approach)
					break
		print("Outdoor props reviewed: ",place," ",data.city_outdoor_props.source_tile_counts," views=",seen.keys())
	print("Native outdoor props and nearby movement passed")
	game.queue_free()
	await process_frame
	quit()
