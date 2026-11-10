extends "res://tools/saffron_access_review.gd"

const VISUAL_OUT="res://docs/saffron_visual_review/"

func shot(label: String) -> void:
	game.ui_root.visible=false
	for _i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(VISUAL_OUT+label+".png")

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VISUAL_OUT))
	SaveData.path="user://save_saffron_visual_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","1");OS.set_environment("LANG_CODE","ko")
	Game.starter="charmander";Game.destination={};Game.carry={};Game.arena_trip={}
	await open_fixture("saffron_city")
	var version:=OS.get_environment("REVIEW_VERSION")
	if version=="":version="after"
	var views={"northwest":Vector2i(24,15),"gyms":Vector2i(44,14),"silph":Vector2i(34,32),"center":Vector2i(24,40),"southeast":Vector2i(44,40),"south":Vector2i(34,44),"west_gate":Vector2i(12,27),"east_gate":Vector2i(55,27),"north_gate":Vector2i(34,7)}
	for label in views:
		game.world.player.position=Arena.resolve(Arena.tile_center(views[label]),game.world.player.radius)
		walker.target=game.world.player.position
		game.view3d._cam_ready=false
		await shot(version+"_"+label)
	# Walk the streets around every city block using the same radius and doors
	# as play. No open-road tile may turn into a visual or collision wall.
	game.world.player.position=Arena.tile_center(Vector2i(34,7))
	walker.target=game.world.player.position
	var stops=[Vector2i(20,15),Vector2i(44,13),Vector2i(51,23),Vector2i(52,32),Vector2i(44,40),Vector2i(34,44),Vector2i(24,40),Vector2i(16,32),Vector2i(16,23),Vector2i(34,15)]
	var visited: Array=[]
	for tile in stops:
		if not reachable().has(tile):
			push_error("Saffron street survey cannot reach "+str(tile));quit(1);return
		await walk_to(tile)
		if game.world.player.position.distance_to(Arena.tile_center(tile))>0.8:
			push_error("Saffron street survey did not finish "+str(tile));quit(1);return
		visited.append([tile.x,tile.y])
	var report={"version":version,"street_stops_walked":visited,"region_views":views.size(),"original_collision_and_warps":true}
	FileAccess.open(VISUAL_OUT+version+"_checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	# Keep the product camera untouched; use a separate fixed survey for the whole city.
	game.view3d.set_process(false)
	var camera: Camera3D=game.view3d.cam
	camera.set_orthogonal(78,0.1,180)
	camera.position=Vector3(33,65,78)
	camera.look_at(Vector3(33,0,27),Vector3.UP)
	game.look_rect.visible=false
	await shot(version+"_overview")
	game.free();await process_frame;SaveData.clear()
	print("Saffron visual survey complete: ",version)
	quit()
