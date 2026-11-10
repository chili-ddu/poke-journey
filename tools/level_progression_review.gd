extends "res://tools/kanto_expansion_review.gd"
const Game=preload("res://scripts/game.gd")
const Policy=preload("res://scripts/data/level_progression.gd")
const REVIEW_OUT="res://docs/level_progression/"
var report: Dictionary={}

func shot(label: String) -> void:
	game.ui_root.visible=true;game.view3d._cam_ready=false
	for _i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(REVIEW_OUT+label+".png")

func setup_controller() -> void:
	super.setup_controller()
	game.bot=true;game.world.god=true;game.lure_t=100000
	game.world.player.repel_steps=100000
	game.road_pursuit.clear(game.world)

func enter(to: String) -> void:
	var door: Dictionary=Arena.warps().filter(func(w):return w.to==to)[0]
	game.world.player.position=Arena.tile_center(Vector2i(int(door.x),int(door.y)))
	walker.target=game.world.player.position;game.bot=false
	game.warp_armed=true;game._check_warp()
	assert(game.state=="warp")
	await arrive(DungeonDB.WARP_MAPS[to],"arrival_"+to)

# This review checks progression and travel, independent of historical blur values.
func arrive(place: String,label: String) -> void:
	for i in 180:
		await create_timer(0.01).timeout
		if current_scene!=game:break
	assert(current_scene!=game,"Scene reload completes")
	game=current_scene;setup_controller()
	await process_frame
	assert(DungeonDB.current==place,"Correct arrival map")
	for i in 30:
		game.advance(1.0/60)
		await process_frame
	assert(game.state!="warp","No automatic door bounce")
	assert(root.size==Vector2i(384,216))
	results.append({"arrival":place})
	await shot(label)

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_OUT))
	SaveData.path="user://save_level_progression_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("LANG_CODE","ko")
	Game.bot_events=[];Game.bot_beaten=[];Game.destination={};Game.carry={};Game.arena_trip={}
	await open_fixture("kanto_world")
	game.world.player.set_level(12)
	var door: Dictionary=Arena.warps().filter(func(w):return DungeonDB.warp_destination(w)=="pewter_gym")[0]
	var tile:=Vector2i(int(door.x),int(door.y))
	game.world.player.position=Arena.tile_center(tile);walker.target=game.world.player.position
	game.warp_armed=true;game._check_warp()
	assert(game.state!="warp");await shot("01_gym_locked")
	report.gym_before_saffron_locked=true
	while game.state=="talk":game._talk_next()
	OS.set_environment("BOT","0")
	await enter("route5_south_entrance")
	await enter("saffron_city")
	assert(Policy.unlocked(game.events))
	assert(SaveData.load_saved().events.has(Policy.config().unlock_event))
	report.actual_first_saffron_visit_saved=true
	var windows: Dictionary={}
	for area in ["route5","route24","route12","route19","route23","cerulean_cave_1f"]:
		var values: Array=[]
		for i in 100:values.append(game.world.wild_level(area,5))
		windows[area]={"min":values.min(),"max":values.max()}
	assert(windows.route5.min==10 and windows.route5.max==14)
	assert(windows.route24.min==12 and windows.route24.max==14)
	assert(windows.route12.min==20 and windows.route12.max==20)
	report.player_level=game.world.player.level;report.wild_windows=windows
	# Return to the field with persistent first-visit progress, then enter the gym.
	await enter("route5_south_entrance")
	await enter("route5")
	assert(Policy.unlocked(game.events))
	await enter("pewter_city_gym")
	report.actual_gym_entry_after_saffron=true
	report.window_size=str(root.size);report.viewport_size=str(root.content_scale_size)
	FileAccess.open(REVIEW_OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	game.free();await process_frame;SaveData.clear()
	print("Level progression native review passed")
	quit()
