extends "res://tools/kanto_expansion_review.gd"
const Game=preload("res://scripts/game.gd")
const ROUTE_OUT="res://docs/route11_diglett/"
var failed:=false

func setup_controller() -> void:
	super.setup_controller()
	game.bot=false;game.world.god=true;game.world.player.repel_steps=999999
	game.beaten=TrainerDB.TRAINERS.keys()
	game.road_pursuit.clear(game.world)

func shot(label: String) -> void:
	game.ui_root.visible=false
	for _i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(ROUTE_OUT+label+".png")

func take_exit(map_id: String,index: int,destination: String,label: String) -> void:
	if failed:return
	var tile:=Arena.warp_tile(map_id,index)
	assert(tile.x>=0,"Source exit exists")
	if Arena.tile_of(game.world.player.position)==tile:
		for direction in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var next: Vector2i=tile+direction
			var point:=Arena.tile_center(next)
			if Arena.solid_at(next.x,next.y) or not Arena.warp_at(point).is_empty() or Arena.resolve(point,game.world.player.radius).distance_to(point)>0.1:continue
			await walk_to(next);break
	await walk_to(tile,true)
	if game.state!="warp":
		failed=true;push_error("Exit did not trigger: "+map_id+str(index));quit(1);return
	await arrive(destination,label)

func wild_sample(place: String,ids: Array) -> void:
	await open_fixture(place)
	var candidates: Array[Vector2i]=[]
	for y in int(Arena.map.height):
		for x in int(Arena.map.width):
			var tile:=Vector2i(x,y)
			if Arena.solid_at(x,y) or not Arena.warp_at(Arena.tile_center(tile)).is_empty():continue
			if place=="route11" and not Arena.is_grass(tile):continue
			candidates.append(tile)
	var center:=Vector2(Arena.map.width,Arena.map.height)*0.5
	candidates.sort_custom(func(a,b):return Vector2(a).distance_to(center)<Vector2(b).distance_to(center))
	var cfg:=DungeonDB.area_cfg(place)
	var found:=false
	for tile in candidates:
		game.world.player.position=Arena.tile_center(tile)
		if game.world._wild_spawn_points(cfg,8.0).size()>=ids.size():found=true;break
	assert(found,"Space for staged native wild samples")
	walker.target=game.world.player.position;game.view3d._cam_ready=false
	game.world.player.repel_steps=0
	for id in ids:
		var level:=0
		for entry in cfg.encounters:
			if entry[0]==id:level=int(entry[1]);break
		assert(level>0 and game.world.queue_spawn(id,level),"Native wild species can spawn")
	game.world._step_spawns(2.0)
	game.world.player.repel_steps=999999
	assert(game.world.alive_enemies().size()==ids.size())
	for _i in 100:
		game.advance(1.0/60.0)
		if _i%4==0:await process_frame
	await shot("wild_"+place)

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_route11_diglett_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	# Native Route 2 keeps its existing Cut-tree requirement. Review the
	# optional southern facilities with the obstructing tree already cut.
	Game.bot_events=["friend_scyther_cut","cut_tree_route2_18_26"];Game.arena_trip={};Game.carry={};Game.destination={}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROUTE_OUT))
	await open_fixture("kanto_east")
	game.world.player.position=Arena.tile_center(Vector2i(46,59));walker.target=game.world.player.position
	game.view3d._cam_ready=false
	await take_exit("vermilion_city",5009,"route11","01_city_to_route11")
	await walk_to(Vector2i(20,10));await shot("02_road_grass")
	await take_exit("route11",1,"route11_east_entrance_1f","03_east_gate")
	await take_exit("route11_east_entrance_1f",4,"route11_east_entrance_2f","04_gate_upstairs")
	await take_exit("route11_east_entrance_2f",0,"route11_east_entrance_1f","05_gate_downstairs")
	await take_exit("route11_east_entrance_1f",0,"route11","06_gate_to_road")
	await take_exit("route11",0,"digletts_cave_south_entrance","07_south_entrance")
	await take_exit("digletts_cave_south_entrance",1,"digletts_cave_b1f","08_cave_south_ladder")
	await take_exit("digletts_cave_b1f",0,"digletts_cave_north_entrance","09_cave_north_ladder")
	await take_exit("digletts_cave_north_entrance",1,"kanto_south","10_route2_shortcut")
	await take_exit("route2",4,"route2_house","11_route2_house")
	await take_exit("route2_house",1,"kanto_south","12_house_to_route2")
	await take_exit("route2",6,"route2_east_building","13_route2_gate")
	await take_exit("route2_east_building",1,"kanto_south","14_route2_south_exit")
	await take_exit("route2",5,"route2_east_building","15_route2_return_gate")
	await take_exit("route2_east_building",3,"kanto_south","16_route2_return_north")
	await take_exit("route2",3,"digletts_cave_north_entrance","17_cave_return_entrance")
	await take_exit("digletts_cave_north_entrance",0,"digletts_cave_b1f","18_cave_return_ladder")
	await take_exit("digletts_cave_b1f",1,"digletts_cave_south_entrance","19_cave_return_south")
	await take_exit("digletts_cave_south_entrance",0,"route11","20_return_route11")
	await take_exit("route11",5009,"kanto_east","21_return_vermilion")
	if failed or results.size()!=20:
		push_error("Incomplete route review: %d transitions"%results.size());quit(1);return
	await wild_sample("route11",["drowzee","ekans","spearow"])
	await wild_sample("digletts_cave_b1f",["diglett","dugtrio"])
	FileAccess.open(ROUTE_OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"actual_transitions":results,"transition_count":results.size(),"cave_walked_both_directions":true,"gate_stairs_both_directions":true,"route2_gate_both_directions":true,"wild_samples":"Explicitly queued native species and levels; normal live AI, god mode and no random encounters during walking review."},"  "))
	print("Route 11/Diglett review passed: ",results.size()," real transitions, cave walked both ways and live wild samples")
	game.free();await process_frame;SaveData.clear();quit()
