extends "res://tools/kanto_expansion_review.gd"
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var phase: String=args[0] if not args.is_empty() else "after"
	var out := "res://docs/tree_canopy_alpha_review/"+phase+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	await CaptureWindow.park(self)
	SaveData.path="user://save_tree_canopy_alpha_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("SEED","7")
	for entry in [["kanto_south",14,174,2,3],["viridian_forest",3,43,3,4],["arena_route1",-1,-1,2,3],["arena_viridian_forest",-1,-1,3,4]]:
		await open_fixture(entry[0])
		game.ui_root.visible=false
		if int(entry[1])>=0:
			var goal := Vector2i(int(entry[1])+int(entry[3])/2,int(entry[2])+int(entry[4]))
			var best := INF
			var chosen: Vector2=game.world.player.position
			for y in range(goal.y-5,goal.y+6):
				for x in range(goal.x-5,goal.x+6):
					if Arena.solid_at(x,y):continue
					var at := Arena.tile_center(Vector2i(x,y))
					if Arena.resolve(at,game.world.player.radius).distance_to(at)>0.1:continue
					var distance := Vector2(x,y).distance_squared_to(Vector2(goal))
					if distance<best:best=distance;chosen=at
			game.world.player.position=chosen
			game.view3d._cam_ready=false
		for i in 25:await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(out+String(entry[0])+".png")
	print("TREE CANOPY REVIEW PASSED: ",phase," 4 maps")
	quit()
