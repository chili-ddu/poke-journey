extends SceneTree
func _init() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT", "1")
	OS.set_environment("GOD", "1")
	OS.set_environment("SEED", "1")
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	for place in ["viridian_forest"]:
		OS.set_environment("DUNGEON", place)
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		game.set_process(false)
		await process_frame
		game.banner_t = 0
		game.hud.visible = false
		var start := Vector2i(29,61)
		var goal := Vector2i(5,10)
		var queue: Array[Vector2i] = [start]
		var parents := {start:start}
		var cursor := 0
		while cursor<queue.size():
			var tile := queue[cursor]
			cursor += 1
			for dir in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
				var next: Vector2i = tile+dir
				if parents.has(next) or Arena.solid_at(next.x,next.y): continue
				var center := Arena.tile_center(next)
				if center.distance_to(Arena.resolve(center,game.world.player.radius))>0.01: continue
				parents[next] = tile
				queue.append(next)
		assert(parents.has(goal),"South entrance connects to north exit")
		var path: Array[Vector2i] = [goal]
		while path.back()!=start: path.append(parents[path.back()])
		path.reverse()
		for i in range(1,path.size()):
			for sample in 9:
				var at := Arena.tile_center(path[i-1]).lerp(Arena.tile_center(path[i]),sample/8.0)
				assert(at.distance_to(Arena.resolve(at,game.world.player.radius))<0.01,"Path segment clear")
		var entries := [["south_entry",Vector2(29.5,61.5)],["north_exit",Vector2(5.5,11.5)]]
		for fraction in [0.15,0.3,0.45,0.6,0.75,0.9]:
			entries.append(["path_"+str(fraction),Vector2(path[int((path.size()-1)*fraction)])+Vector2(0.5,0.5)])
		for entry in entries:
			game.world.player.position = Arena.resolve(entry[1]*Arena.TILE,game.world.player.radius)
			game.view3d._cam_ready = false
			for frame in 20:
				game.world._step_tall_grass()
				game.world.step_visual(1.0/60.0)
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out+"/"+entry[0]+".png")
		FileAccess.open(out+"/checks.json",FileAccess.WRITE).store_string(JSON.stringify({"reachable_tiles":parents.size(),"route_tiles":path.size(),"radius":game.world.player.radius,"route_segments_clear":true,"trainer_event":"not simulated"},"  "))
		print("Forest route clear: ",path.size()," tiles; accessible ",parents.size())
		game.free()
		await process_frame
	print("center structure review OK")
	quit()
