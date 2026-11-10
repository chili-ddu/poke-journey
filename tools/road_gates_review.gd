extends "res://tools/kanto_expansion_review.gd"
const Game=preload("res://scripts/game.gd")
const Access=preload("res://scripts/data/road_access.gd")
const REVIEW_OUT="res://docs/road_gates/"

func shot(label: String) -> void:
	game.ui_root.visible=game.state=="talk"
	game.view3d._cam_ready=false
	for _i in 16:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(REVIEW_OUT+label+".png")

func setup_controller() -> void:
	super.setup_controller()
	game.bot=true;game.world.god=true;game.lure_t=100000
	game.world.player.repel_steps=100000
	game.road_pursuit.clear(game.world)
	game.beaten.append(TrainerDB.cerulean_rival_for(game.starter))

func attempt(start: Vector2i, goal: Vector2i) -> void:
	game.world.player.position=Arena.tile_center(start)
	walker.target=Arena.tile_center(goal)
	for _i in 100:game.advance(1.0/60)
	walker.target=game.world.player.position

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_OUT))
	SaveData.path="user://save_road_gates_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("LANG_CODE","ko")
	Game.starter="charmander";Game.bot_events=[];Game.destination={};Game.carry={};Game.arena_trip={}
	await open_fixture("kanto_world")
	var bridge:=Arena.area_rect("route24")
	attempt(bridge.position+Vector2i(11,42),bridge.position+Vector2i(11,36))
	assert(game.world.player.position.y>Arena.tile_center(bridge.position+Vector2i(11,39)).y)
	await shot("01_bridge_closed")
	game._talk(game.road_gates.construction[1]);await shot("02_construction_dialogue")
	while game.state=="talk":game._talk_next()
	game.events.append(Access.SAFFRON_VISITED);game.road_gates.refresh()
	attempt(bridge.position+Vector2i(11,42),bridge.position+Vector2i(11,36))
	assert(game.world.player.position.y<Arena.tile_center(bridge.position+Vector2i(11,39)).y)
	await shot("03_bridge_open")
	var road:=Arena.area_rect("route11")
	game.world.player.position=Arena.tile_center(road.position+Vector2i(6,8));walker.target=game.world.player.position
	await walk_to(road.position+Vector2i(-1,9))
	assert(Arena.area_at(game.world.player.position)=="vermilion_city")
	await shot("04_cave_to_city")
	attempt(road.position+Vector2i(8,9),road.position+Vector2i(14,9))
	assert(game.world.player.position.x<Arena.tile_center(road.position+Vector2i(10,9)).x)
	await shot("05_snorlax_blocks_road")
	game._talk(game.road_gates.sleep_talk);await shot("06_snorlax_dialogue")
	while game.state=="talk":game._talk_next()
	assert(is_instance_valid(game.road_gates.sleeper))
	assert(not game.events.has(Access.SNORLAX_AWAKENED))
	var report={"bridge_blocks_actual_walk":true,"saffron_opens_bridge":true,"cave_to_vermilion_walked":true,
		"snorlax_blocks_actual_walk":true,"snorlax_remains_after_saffron_and_talk":true,
		"wake_event_reserved":Access.SNORLAX_AWAKENED,"art_source":"existing, unchanged worker/boulder and Snorlax Sleep frames",
		"window_size":str(root.size),"viewport_size":str(root.content_scale_size)}
	FileAccess.open(REVIEW_OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	game.free();await process_frame;SaveData.clear()
	print("Road gates native review passed")
	quit()
