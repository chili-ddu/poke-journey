extends "res://tools/kanto_expansion_review.gd"
const DEST := "res://docs/pickup_trail_applied/"

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_pickup_trail_applied.cfg"
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DEST))
	await open_fixture("kanto_south")
	game.ui_root.visible=false
	game.view3d.set_process(false)
	game.world.player.position=Arena.tile_center(Vector2i(23,209))
	game.world.player.repel_steps=100000
	game.world.player.bag.clear();game.world.player.reward_reserve.clear()
	walker.target=game.world.player.position
	game.view3d._cam_ready=false
	for i in 12:
		game.world.step_visual(1.0/60.0)
		game.view3d._process(1.0/60.0)
		await process_frame
	for i in 3: game.world.spawn_loot("oran_berry",game.world.player.position+Vector2(-30+i*3,2))
	var seen := false
	for frame in 48:
		if frame==22: walker.target=game.world.player.position+Vector2(12,0)
		game.world.step(1.0/30.0)
		game.view3d._process(1.0/30.0)
		for fx in game.world.fxs:
			if fx.kind!="pickup_trail": continue
			seen=true
			if fx.pickup_trail==null: continue
			assert(fx.pickup_trail.history.size()<=9)
			assert(fx.pickup_trail.motes.size()<=4)
			if game.view3d._sprites.has(fx.get_instance_id()):
				var ent: Dictionary=game.view3d._sprites[fx.get_instance_id()]
				for node in ent.values():
					assert(not (node.material_override as ShaderMaterial).shader.code.contains("depth_test_disabled"))
				if ent.has("segment0") and ent.segment0.visible:
					var points: Array=fx.pickup_trail.history
					var expected: Vector3=(game.view3d._pickup_point(points[0])+game.view3d._pickup_point(points[1]))*0.5
					assert(ent.segment0.position.distance_to(expected)<0.001,"Light stays on the actual 3D flight history")
		await process_frame
		await RenderingServer.frame_post_draw
		assert(DisplayServer.window_get_size()==Vector2i(384,216))
		root.get_texture().get_image().save_png(DEST+"%03d.png"%frame)
	assert(seen)
	assert(game.world.player.bag.oran_berry==3)
	assert(game.world.drops.is_empty())
	assert(game.world.fxs.filter(func(f): return f.kind=="pickup_trail").is_empty())
	print("Applied pickup trail verified: normal inventory, native history/depth, moving collector, full expiry")
	game.free()
	quit()
