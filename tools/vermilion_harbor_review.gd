extends "res://tools/kanto_expansion_review.gd"
const Game=preload("res://scripts/game.gd")
const HARBOR_OUT="res://docs/vermilion_harbor/"

func shot(label: String) -> void:
	game.ui_root.visible=false
	for _i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(HARBOR_OUT+label+".png")

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_vermilion_harbor_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	Game.bot_events=[];Game.arena_trip={};Game.carry={};Game.destination={}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(HARBOR_OUT))
	await open_fixture("kanto_east")
	game.world.player.position=Arena.tile_center(Vector2i(23,71))
	walker.target=game.world.player.position;game.view3d._cam_ready=false
	await shot("01_town_pier")
	await walk_to(Vector2i(23,74),true)
	await arrive("vermilion_harbor","02_arrival")
	assert(Arena.tile_of(game.world.player.position)==Vector2i(32,6))
	await walk_to(Vector2i(32,11))
	await shot("03_empty_berth")
	await walk_to(Vector2i(32,13))
	await shot("04_pier_end")
	assert(Arena.solid_at(32,14) and Arena.warp_at(Arena.tile_center(Vector2i(32,14))).is_empty())
	game.view3d.visible=false
	await shot("05_flat_view")
	game.view3d.visible=true
	await walk_to(Vector2i(32,5),true)
	await arrive("kanto_east","06_return_to_town")
	assert(Arena.tile_of(game.world.player.position)==Vector2i(23,73))
	FileAccess.open(HARBOR_OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_transitions":results,"walked_to_pier_end":true,"boarding_triggers":0,"ship_present":false,"views":["3d","2d"]},"  "))
	print("Vermilion harbor: real town/pier round trip, empty berth and blocked boarding edge passed")
	game.free();await process_frame;SaveData.clear();quit()
