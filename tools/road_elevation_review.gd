extends "res://tools/north_walk_review.gd"

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_road_elevation_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	var reports := []
	for route in ["route1","route2","route3","route4","route5","route6"]:
		await open_fixture("kanto_east" if route=="route6" else "kanto_south")
		game.view3d.set_process(false)
		game.ui_root.visible=false
		var chosen := Vector2i(-1,-1)
		var direction := Vector2i.ZERO
		var best := 0.2
		for tile in Arena._elevated_ledges:
			if Arena.area_at(Arena.tile_center(tile))!=route:continue
			var dir: Vector2i=Vector2i(Arena.LEDGE_DIRS[Arena.ledge_at(tile.x,tile.y)])
			var clear := true
			for side in [-1,1]:
				var at := Arena.tile_center(tile+dir*side)
				if not Arena.warp_at(at).is_empty() or Arena.resolve(at,game.world.player.radius).distance_to(at)>0.1:clear=false
			var drop := Arena.ground_height(Arena.tile_center(tile-dir))-Arena.ground_height(Arena.tile_center(tile+dir))
			if clear and drop>best:chosen=tile;direction=dir;best=drop
		assert(chosen.x>=0,"Traversable elevated ledge on "+route)
		var start := Arena.tile_center(chosen-direction)
		var goal := Arena.tile_center(chosen+direction)
		var player: Player=game.world.player
		player.position=start
		walker.target=start
		game.view3d._cam_ready=false
		for i in 20:
			game.advance(1.0/60)
			game.view3d._process(1.0/60)
		var screen: Vector2=game.view3d.cam.unproject_position(View3D.to3d(start))
		var picked: Vector2=game.view3d.ground_at_screen(screen)
		assert(picked.distance_to(start)<0.1,"Mouse ray follows raised road floor")
		await shot("road_elevation_"+route+"_upper")
		walker.target=goal
		var hopped := false
		var captured := false
		var last_y := INF
		var max_step := 0.0
		for i in 300:
			game.advance(1.0/60)
			game.view3d._process(1.0/60)
			assert(game.state!="warp" and current_scene==game,"No map reload on terrace")
			var sprite: Sprite3D=game.view3d._sprites[player.get_instance_id()].sprite
			if is_finite(last_y):max_step=maxf(max_step,absf(sprite.position.y-last_y))
			last_y=sprite.position.y
			if player.hop_t>0:
				hopped=true
				if not captured:
					await shot("road_elevation_"+route+"_jump")
					captured=true
			if player.position.distance_to(goal)<0.8 and player.hop_t<=0:break
			if i%4==0:await process_frame
		assert(hopped and player.position.distance_to(goal)<0.8,"Automatic downhill jump lands")
		assert(max_step<0.4,"Character follows continuous height during drop")
		await shot("road_elevation_"+route+"_lower")
		# The existing deliberate reverse jump is also a continuous uphill arc.
		walker.target=start
		game.world._start_hop(start)
		for i in 300:
			game.advance(1.0/60)
			game.view3d._process(1.0/60)
			if player.position.distance_to(start)<0.8 and player.hop_t<=0:break
			if i%4==0:await process_frame
		assert(player.position.distance_to(start)<0.8,"Deliberate uphill jump lands")
		reports.append({"route":route,"ledge":[chosen.x,chosen.y],"height_difference":best,"max_sprite_height_step":max_step,"downhill_jump":true,"uphill_jump":true,"mouse_error_px":picked.distance_to(start)})
		print("ROAD ELEVATION ",route," drop=",best," max step=",max_step)
	FileAccess.open(OUT+"road_elevation_checks.json",FileAccess.WRITE).store_string(JSON.stringify(reports,"  "))
	print("Six road terraces, downhill/uphill jumps, and raised-floor mouse picking passed")
	game.queue_free()
	await process_frame
	quit()
