extends "res://tools/forest_rescue_review.gd"
const FENCE_OUT="res://docs/fence_review/"

func shot(name: String) -> void:
	for _i in 20:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(FENCE_OUT+name+".png")

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_fence_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	Game.bot_events=[];Game.arena_trip={};Game.carry={};Game.destination={}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FENCE_OUT))
	await open_place("kanto_rock_pass")
	game.ui_root.visible=false
	var cases: Dictionary={"01_north_corner":Vector2i(88,8),"02_behind_fence":Vector2i(87,4),"03_south_end":Vector2i(88,29),"04_route9_turn":Vector2i(4,5)}
	for name in cases:
		game.world.player.position=Arena.tile_center(cases[name])-Vector2(0,game.world.player.feet_offset())
		game.world.cam.position=game.world.player.position
		game.view3d._cam_ready=false
		await shot(name)
	print("Fence review: north turn, behind fence, south end and Route 9 captured")
	game.free();await process_frame;SaveData.clear();quit()
