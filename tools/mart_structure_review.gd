extends SceneTree
func _init() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT", "1")
	OS.set_environment("GOD", "1")
	OS.set_environment("SEED", "1")
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	for place in ["viridian_mart", "pewter_mart"]:
		OS.set_environment("DUNGEON", place)
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		game.set_process(false)
		await process_frame
		game.banner_t = 0
		game.hud.visible = false
		for entry in [["front", Vector2(4.5,6.5)], ["clerk", Vector2(4.5,3.5)], ["right", Vector2(6.5,5.5)]]:
			game.world.player.position = Arena.resolve(entry[1] * Arena.TILE, game.world.player.radius)
			game.view3d._cam_ready = false
			for frame in 20:
				game.world.step_visual(1.0 / 60.0)
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out + "/" + place + "_" + entry[0] + ".png")
		game.free()
		await process_frame
	print("mart structure review OK")
	quit()
