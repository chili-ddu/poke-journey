extends SceneTree
func _init() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT", "1")
	OS.set_environment("GOD", "1")
	OS.set_environment("SEED", "1")
	var out := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(out)
	for place in ["viridian_center", "pewter_center"]:
		OS.set_environment("DUNGEON", place)
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		game.set_process(false)
		await process_frame
		game.banner_t = 0
		game.hud.visible = false
		game.world.player.position = Vector2(7.5, 4.5) * Arena.TILE
		var nurse: Npc
		for npc in game.world.npcs:
			if npc.talk == "nurse": nurse = npc
		assert(nurse != null)
		game._start_heal(nurse)
		for frame in 90:
			game._step_heal(1.0 / 60.0)
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out + "/" + place + "_healing.png")
		for frame in 600:
			if game.state != "heal": break
			game._step_heal(1.0 / 60.0)
		assert(game.heal.is_empty())
		assert(game.view3d._healing_offset(game.world.player) == Vector3.ZERO)
		game.free()
		await process_frame
	print("center healing review OK")
	quit()
