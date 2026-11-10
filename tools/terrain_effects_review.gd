extends "res://tools/north_walk_review.gd"

func run() -> void:
	await CaptureWindow.park(self)
	var phase := OS.get_environment("REVIEW_PHASE")
	if phase=="":phase="after"
	SaveData.path="user://save_terrain_effects_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	await open_fixture("kanto_south")
	game.view3d.set_process(false)
	game.ui_root.visible=false
	var chosen := Vector2i(-1,-1)
	var best := -INF
	for tile in Arena._grass_tiles:
		if Arena.area_at(Arena.tile_center(tile))!="route1":continue
		var clear := true
		for step in range(-2,3):
			var at := Arena.tile_center(tile+Vector2i(0,step))
			if Arena.resolve(at,game.world.player.radius).distance_to(at)>0.1 or not Arena.warp_at(at).is_empty():clear=false
		var score := Arena.ground_height(Arena.tile_center(tile))
		if clear and score>best:chosen=tile;best=score
	assert(chosen.x>=0)
	var player: Player=game.world.player
	player.position=Arena.tile_center(chosen+Vector2i.DOWN)
	walker.target=Arena.tile_center(chosen+Vector2i.UP*2)
	game.view3d._cam_ready=false
	var report := []
	var grass_frames := 0
	for frame in 100:
		game.advance(1.0/60)
		game.view3d._process(1.0/60)
		if frame in [12,28,44,60]:
			await process_frame
			game.view3d._process(0.0)
			await shot("terrain_effects_"+phase+"_north_%d"%frame)
			var entry: Dictionary=game.view3d._sprites[player.get_instance_id()]
			var sprite: Sprite3D=entry.sprite
			var expected: Vector3 = game.view3d.sprite_pixel_position(sprite,entry.tail_pixel)
			var halo_screen: Vector2=game.view3d.cam.unproject_position(entry.halo.position)
			var expected_screen: Vector2=game.view3d.cam.unproject_position(expected)
			var grass_count := 0
			var grass_error := 0.0
			for effect in game.world.get_children():
				if not effect is Fx or effect.kind not in ["tallgrass","rustle"]:continue
				var effect_entry: Dictionary=game.view3d._sprites.get(effect.get_instance_id(),{})
				if not effect_entry.has("layered_grass") or not effect_entry.layered_grass.visible:continue
				grass_count+=1
				var node: MeshInstance3D=effect_entry.layered_grass
				var tile: Vector2i=effect.tile if effect.kind=="tallgrass" else Arena.tile_of(effect.position)
				var ground := View3D.flora_ground_frame(tile)
				for vertex in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
					grass_error=maxf(grass_error,game.view3d.cam.unproject_position(ground*vertex).distance_to(game.view3d.cam.unproject_position(node.transform*vertex)))
			grass_frames+=grass_count
			report.append({"frame":frame,"tile":[chosen.x,chosen.y],"altitude":Arena.ground_height(player.position),"halo_error_pixels":halo_screen.distance_to(expected_screen),"light_visible":entry.light.visible,"light_range":entry.light.omni_range,"grass_effects":grass_count,"grass_alignment_error_pixels":grass_error})
			if phase=="after":
				assert(halo_screen.distance_to(expected_screen)<1.0,"Tail glow stays on the original flame pixels")
				assert(entry.light.omni_range<maxf(0.01,expected.y-sprite.position.y),"Tail illumination uses height above the sprite feet")
				assert(grass_error<0.02,"Rustle follows the static grass ramp and footprint")
	assert(grass_frames>0,"Raised grass rustles were exercised")
	FileAccess.open(OUT+"terrain_effects_"+phase+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	game.view3d.ov.get_texture().get_image().save_png(OUT+"terrain_effects_"+phase+"_overlay.png")
	var overlay: Image=game.view3d.ov.get_texture().get_image()
	var ink := 0
	for y in overlay.get_height():
		for x in overlay.get_width():
			if overlay.get_pixel(x,y).a>0.01:ink+=1
	assert(ink==0,"Walking grass and tail glow must not leave duplicate art in the floor overlay")
	print("TERRAIN EFFECTS ",phase,": ",report)
	game.queue_free()
	await process_frame
	quit()
