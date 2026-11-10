extends "res://tools/north_walk_review.gd"

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_tile_alignment_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	var phase := OS.get_environment("REVIEW_PHASE")
	if phase=="":phase="after"
	await open_fixture("kanto_south")
	game.view3d.set_process(false)
	game.ui_root.visible=false
	for fixture in [{"id":"road_ledge","tile":Vector2i(19,202)},{"id":"tree_path","tile":Vector2i(33,188)}]:
		var goal: Vector2=Arena.tile_center(fixture.tile)
		assert(Arena.resolve(goal,game.world.player.radius).distance_to(goal)<0.1)
		game.world.player.position=goal
		walker.target=goal
		game.view3d._cam_ready=false
		for i in 20:
			game.advance(1.0/60)
			game.view3d._process(1.0/60)
		await shot("tile_alignment_"+phase+"_"+String(fixture.id))
		if fixture.id=="road_ledge" and phase in ["endcaps","rim","foot"]:
			var bounds := Rect2(game.view3d.cam.unproject_position(View3D.to3d(Vector2(17,200)*Arena.TILE)),Vector2.ZERO)
			for at in [Vector2(21,200),Vector2(17,201),Vector2(21,201)]:
				bounds=bounds.expand(game.view3d.cam.unproject_position(View3D.to3d(at*Arena.TILE)))
			var image: Image=root.get_texture().get_image()
			var region := Rect2i(Vector2i(bounds.position.floor())-Vector2i(12,12),Vector2i(bounds.size.ceil())+Vector2i(24,24))
			var detail: String={"rim":"ledge_rim_after_detail.png","foot":"ledge_foot_after_detail.png","endcaps":"ledge_endcaps_after_detail.png"}[phase]
			image.get_region(region.intersection(Rect2i(Vector2i.ZERO,image.get_size()))).save_png(OUT+detail)
	print("TILE ALIGNMENT ",phase,": road bank and tree underlay captured")
	game.queue_free()
	await process_frame
	quit()
