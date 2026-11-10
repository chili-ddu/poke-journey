extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","7")
	OS.set_environment("DUNGEON","kanto_south")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.banner_t = 0
	game.world.player.position = Arena.resolve(Arena.tile_center(Arena.area_rect("route1").get_center()),game.world.player.radius)
	game.world.player.set_level(15)
	game._step_wild(0.1)
	assert(game._fear_active)
	var final_page: String
	while not game.dialog_text.is_empty():
		final_page=game.dialog_text
		game._advance_timed_message()
	assert(game.displayed_message()==final_page and game.dialog_text.is_empty())
	for i in 20:
		game.world.step_visual(1.0/60)
		await process_frame
	var out := "res://docs/wild_fear_review"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out+"/retained_message.png")
	print("Fear suppression and retained small message review passed")
	game.free()
	await process_frame
	quit()
