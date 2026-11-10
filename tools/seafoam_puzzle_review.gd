extends SceneTree
const Game=preload("res://scripts/game.gd")
const Puzzle=preload("res://scripts/story/seafoam_puzzle.gd")
const Data=Puzzle.Data
const OUT="res://docs/seafoam_puzzle/"
const DT=1.0/60.0
var game: Node
var transitions:=0
var pushes:=0
class Walker:
	extends RefCounted
	var target:=Vector2.ZERO
	func move_dir(w):return (target-w.player.position).normalized() if target.distance_to(w.player.position)>0.6 else Vector2.ZERO
	func aim_point(w):return target if target.distance_to(w.player.position)>0.6 else w.player.position+w.player.facing*50
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func _init() -> void:call_deferred("run")

func configure() -> void:
	game.set_process(false);game.world.god=true
	var walker:=Walker.new();walker.target=game.world.player.position;game.world.player.controller=walker
	game.world.player.repel_steps=999999;game.lure_t=999999
	game.dialog_text="";game.dialog_t=0;game.banner_t=0
	game.status_messages.clear();game.status_message_active=false
	game.road_pursuit.clear(game.world)

func open_place(place: String) -> void:
	if is_instance_valid(game):game.free()
	OS.set_environment("DUNGEON",place)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	configure();OS.set_environment("DUNGEON","")
	await process_frame

func shot(label: String) -> void:
	game.ui_root.visible=false;game.world.cam.position=game.world.player.position;game.view3d._cam_ready=false
	for _i in 8:await process_frame
	await RenderingServer.frame_post_draw
	assert(DisplayServer.window_get_size()==Vector2i(384,216))
	root.get_texture().get_image().save_png(OUT+label+".png")

func arrive(place: String) -> void:
	var prior=game
	for _i in 600:
		if current_scene!=prior:break
		await create_timer(0.01).timeout
	assert(current_scene!=prior,"Actual scene reload completed")
	game=current_scene;configure();assert(DungeonDB.current==place);transitions+=1
	await process_frame

func finish_event() -> void:
	for _i in 600:
		if game.state!="seafoam_event":return
		game.advance(DT);await process_frame
	assert(false,"Puzzle animation finished")

func space() -> void:
	var key:=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true;game._unhandled_input(key)

func walk_path(goal: Vector2i) -> void:
	var p: Player=game.world.player
	var start:=Arena.tile_of(p.position)
	var queue: Array[Vector2i]=[start];var previous: Dictionary={};var seen={start:true};var cursor:=0
	while cursor<queue.size() and not seen.has(goal):
		var at:=queue[cursor];cursor+=1
		for d in [Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			var next: Vector2i=at+d;var point:=Arena.tile_center(next)
			if seen.has(next) or not Arena.warp_at(point).is_empty() or Arena.terrain_blocked(next,2):continue
			if Arena.resolve(point,p.radius,false,2).distance_to(point)>0.1:continue
			seen[next]=true;previous[next]=at;queue.append(next)
	assert(seen.has(goal),"Calm water opens a real route to the northern island")
	var path: Array[Vector2i]=[];var at:=goal
	while at!=start:path.push_front(at);at=previous[at]
	for tile in path:
		if p.travel_terrain==0 and Arena.is_water(tile):
			p.facing=Vector2(tile-Arena.tile_of(p.position));assert(game.lapras_escape.try_call())
			while game.state=="lapras_event":game.advance(DT);await process_frame
		p.controller.target=Arena.tile_center(tile)
		for _i in 240:
			if p.position.distance_to(p.controller.target)<1.0:break
			game.advance(DT);await process_frame
		assert(p.position.distance_to(p.controller.target)<1.0,"Normal walking/surfing reached the next tile")
	assert(Arena.tile_of(p.position)==goal)

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_seafoam_puzzle_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","1");OS.set_environment("LANG_CODE","ko")
	Game.starter="charmander";Game.destination={};Game.carry={};Game.arena_trip={};Game.bot_puzzles={};Game.bot_events=["friend_lapras_surf"]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	# Before solving: current carries the rider through the native B3 outlet.
	await open_place("seafoam_islands_b3f")
	game.world.player.position=Arena.tile_center(Vector2i(23,9));game.world.player.travel_terrain=2
	game.lapras_escape.follow(0);assert(game.seafoam.check_environment())
	await shot("01_strong_current_b3");await finish_event();await arrive("seafoam_islands_b4f")
	assert(game.seafoam.phase=="current" or game.seafoam.check_environment());await finish_event()
	assert(Arena.tile_of(game.world.player.position)==Vector2i(27,18))
	game.world.player.position=Arena.tile_center(Vector2i(8,16));game.world.player.travel_terrain=2
	game.lapras_escape.follow(0);assert(game.seafoam.check_environment())
	await shot("02_strong_current_b4");await finish_event()
	assert(Arena.tile_of(game.world.player.position)==Vector2i(12,12))
	# Solve all four original boards, fast-forwarding only the walking between pushes.
	Game.bot_puzzles={};Game.carry={};await open_place("seafoam_islands_1f")
	var exp: int=game.world.player.exp_total
	var solutions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://test/fixtures/seafoam_puzzle_solutions.json"))
	var floors=["seafoam_islands_1f","seafoam_islands_b1f","seafoam_islands_b2f","seafoam_islands_b3f"]
	for index in floors.size():
		var floor: String=floors[index]
		assert(DungeonDB.current==floor)
		for action in solutions[floor]:
			var p: Player=game.world.player
			p.position=Arena.tile_center(Data.vec(action.stand));p.controller.target=p.position;p.facing=Vector2(Data.vec(action.direction))
			p.travel_terrain=0;game.lapras_escape.follow(0)
			assert(Arena.resolve(p.position,p.radius).distance_to(p.position)<0.1)
			if pushes==0:await shot("03_original_boulder")
			space();assert(game.state=="seafoam_event");pushes+=1
			if pushes==1:
				for _i in 6:game.advance(DT);await process_frame
				await shot("04_push")
			if game.seafoam.holes.has(Data.vec(action.to)):
				while game.seafoam.phase=="pushing":game.advance(DT);await process_frame
				for _i in 6:game.advance(DT);await process_frame
				await shot("%02d_falling_%s"%[5+index,floor])
			await finish_event();assert(game.world.player.exp_total==exp)
		var hole: Dictionary=Data.data().floors[floor].holes[0]
		game.world.player.position=Arena.tile_center(Data.vec(hole.tile));game.world.player.facing=Vector2.DOWN
		game.warp_armed=true # The intervening walk has left the arrival tile.
		game._check_warp();assert(game.seafoam.phase=="player_fall")
		await finish_event();await arrive(hole.floor)
		if DungeonDB.current=="seafoam_islands_b3f":
			assert(game.seafoam.stopped() and String(Arena.theme.map).ends_with("_calm"))
			await shot("09_calm_b3")
	assert(DungeonDB.current=="seafoam_islands_b4f" and game.seafoam.stopped())
	assert(String(Arena.theme.map).ends_with("_calm"))
	game.lapras_escape.follow(0);await shot("10_calm_b4")
	await walk_path(Vector2i(9,2));await shot("11_northern_island_accessible")
	# A real save/reload retains the solved layouts and boulder positions.
	game.bot=false;game.seafoam._persist();game._save_here()
	game.free();await process_frame;OS.set_environment("BOT","0");Game.carry={};Game.destination={}
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game;configure()
	assert(game.seafoam.stopped() and String(Arena.theme.map).ends_with("_calm"))
	await shot("12_saved_puzzle_resume")
	var checks={"root_boulders":6,"holes":8,"pushes":pushes,"actual_scene_transitions":transitions,"b3_stopped":true,"b4_stopped":true,"strong_currents":true,"northern_island_walked_to":true,"save_reload":true,"zero_cost":game.world.player.exp_total==exp,"window":[384,216],"diagnostic":"Walks between pushes fast-forwarded; real Space pushes, player falls, current rides and final navigation"}
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("Seafoam review: %d native pushes, 2 calm layouts, current rides, %d actual transitions, northern island navigation and save/reload passed"%[pushes,transitions])
	game.free();await process_frame;SaveData.clear();quit()
