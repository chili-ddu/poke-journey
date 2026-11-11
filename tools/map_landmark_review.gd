extends "res://tools/kanto_expansion_review.gd"

const LANDMARKS := {
	"route24_bridge":Vector2i(288,20), "route24_south":Vector2i(288,41),
	"vermilion":Vector2i(288,225), "vermilion_pier":Vector2i(291,230),
	"lavender":Vector2i(396,142), "lavender_south":Vector2i(394,147),
	"cerulean":Vector2i(286,64), "cerulean_doors":Vector2i(288,69),
	"fuchsia":Vector2i(215,324), "fuchsia_south":Vector2i(215,325)
}

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path = "user://map_landmark_review_only.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("SEED","7")
	var output := OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(output)
	await open_fixture("kanto_world")
	game.ui_layer.hide()
	for id in LANDMARKS:
		var tile: Vector2i = LANDMARKS[id]
		var pos := Arena.tile_center(tile)
		assert(not Arena.solid_at(tile.x,tile.y) and Arena.resolve(pos,game.world.player.radius).distance_to(pos)<0.1)
		game.world.player.position=pos
		await capture_landmark(output,id)
	await open_fixture("pewter_museum_1f")
	game.ui_layer.hide()
	for y in [5,6]:
		await walk_to(Vector2i(10,y))
		await capture_landmark(output,"museum_walk_%d"%y)
	print("Landmark views and museum walk complete.")
	game.free()
	quit()

func capture_landmark(output: String,id: String) -> void:
	game.world.player.facing=Vector2.DOWN
	game.world.player.queue_redraw()
	game.view3d._cam_ready=false
	for i in 22:
		game.world.step_visual(1./60)
		await process_frame
	await RenderingServer.frame_post_draw
	assert(DisplayServer.window_get_size()==Vector2i(384,216))
	assert(root.get_texture().get_image().save_png(output.path_join(id+".png"))==OK)
