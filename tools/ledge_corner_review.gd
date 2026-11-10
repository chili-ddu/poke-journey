extends "res://tools/north_walk_review.gd"

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_ledge_corner_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	await open_fixture("kanto_south")
	game.view3d.set_process(false)
	game.ui_root.visible=false
	var patches: Dictionary=Arena._ledge_patches.duplicate()
	var report := []
	var ends := {}
	for tile in patches:
		var patch: Dictionary=patches[tile]
		if patch.kind!="end":continue
		var hi := -INF
		var lo := INF
		for row in patch.heights:
			hi=maxf(hi,float(row.max()))
			lo=minf(lo,float(row.min()))
		if hi-lo>float(ends.get(patch.direction,{}).get("amplitude",0.15)):
			ends[patch.direction]={"tile":tile,"amplitude":hi-lo}
	var end_tiles := []
	for value in ends.values():end_tiles.append(value.tile)
	for tile in patches:
		var patch: Dictionary=patches[tile]
		if patch.kind not in ["outer","inner"] and tile not in end_tiles:continue
		var chosen := Vector2i(-1,-1)
		var distance := INF
		for dy in range(1,5):
			for dx in range(-3,4):
				var candidate: Vector2i=tile+Vector2i(dx,dy)
				var pos := Arena.tile_center(candidate)
				if not Arena.warp_at(pos).is_empty() or Arena._ledge_patches.has(candidate) or Arena.resolve(pos,game.world.player.radius).distance_to(pos)>0.1:continue
				var score := Vector2(dx,dy-2).length()
				if score<distance:chosen=candidate;distance=score
		assert(chosen.x>=0,"Accessible corner viewing position")
		game.world.player.position=Arena.tile_center(chosen)
		walker.target=game.world.player.position
		game.view3d._cam_ready=false
		for i in 20:
			game.advance(1.0/60)
			game.view3d._process(1.0/60)
		await shot("ledge_corner_"+String(patch.kind)+"_%d_%d" % [tile.x,tile.y])
		# A solid elbow must remain impassable, even though the neighboring ledge
		# can be crossed by a deliberate jump.
		var center := Arena.tile_center(tile)
		assert(Arena.resolve(center,game.world.player.radius).distance_to(center)>0.1)
		if patch.direction=="":assert(Arena.resolve(center,game.world.player.radius,true).distance_to(center)>0.1)
		if chosen==tile+Vector2i.DOWN:
			walker.target=center
			for i in 45:
				game.advance(1.0/60)
				game.view3d._process(1.0/60)
			assert(Arena.tile_of(game.world.player.position)!=tile,"Walking cannot cut through solid corner")
			walker.target=game.world.player.position
		report.append({"kind":patch.kind,"tile":[tile.x,tile.y],"native_solid":Arena.solid_at(tile.x,tile.y),"walk_blocked":true,"jump_blocked":patch.direction==""})
		print("CORNER ",patch.kind," ",tile)
	FileAccess.open(OUT+"ledge_corner_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("All ",report.size()," corner/end views captured and collision checked")
	game.queue_free()
	await process_frame
	quit()
