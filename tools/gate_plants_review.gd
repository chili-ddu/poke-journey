extends "res://tools/saffron_access_review.gd"

const PLANT_OUT="res://docs/gate_plants_review/"

func shot(label: String) -> void:
	game.ui_root.visible=false
	for _i in 16:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(PLANT_OUT+label+".png")

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PLANT_OUT))
	SaveData.path="user://save_gate_plants_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","1")
	Game.starter="charmander";Game.destination={};Game.carry={};Game.arena_trip={}
	var version:=OS.get_environment("REVIEW_VERSION")
	if version=="":version="after"
	for place in ["route5_south_entrance","route6_north_entrance"]:
		await open_fixture(place)
		for row in [4,7,9]:
			game.world.player.position=Arena.tile_center(Vector2i(4,row))
			walker.target=game.world.player.position
			game.view3d._cam_ready=false
			await shot(version+"_"+place+"_"+str(row))
		for tile in [Vector2i(4,2),Vector2i(4,5),Vector2i(4,8)]:
			if not reachable().has(tile):push_error("Gate plant survey cannot reach "+str(tile));quit(1);return
			await walk_to(tile)
			if game.world.player.position.distance_to(Arena.tile_center(tile))>0.8:quit(1);return
		print("Gate plants walked: ",place)
	game.free();await process_frame;SaveData.clear()
	print("Gate plant survey complete: ",version)
	quit()
