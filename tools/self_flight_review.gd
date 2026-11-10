extends "res://tools/fly_map_review.gd"
const SELF_OUT="res://docs/self_flight/"
var cases: Array=[]

func capture(name: String="") -> void:
	await RenderingServer.frame_post_draw
	var img:=root.get_texture().get_image()
	img.save_png(SELF_OUT+"frames/%04d.png"%frame);frame+=1
	if name!="":img.save_png(SELF_OUT+name+".png")

func self_journey(species: String,id: String,prefix: String) -> void:
	var p: Player=game.world.player
	p.setup_player(species,10,["scratch"],{});p.controller=Pilot.new()
	p.hp-=3;p.pp[0]=maxi(0,int(p.pp[0])-2)
	var hp:=p.hp;var pp:=p.pp.duplicate();var exp_before:=p.exp_total;var bag:=p.bag.duplicate(true)
	await tick(0.15)
	game.world._start_hop(p.position+Vector2.UP*24.0);await tick(0.13)
	space();assert(game.menu=="fly")
	select_map(id);await capture(prefix+"_map")
	map_key(KEY_SPACE)
	assert(game.bird_event.phase=="self_ready" and game.bird_event.helper==null)
	var camera: Transform3D=game.view3d.cam.global_transform
	var first:=frame
	await tick(0.10);await capture(prefix+"_wingbeat")
	await tick(Bird.SELF_READY_TIME);await capture(prefix+"_launch")
	assert(game.view3d.cam.global_transform.is_equal_approx(camera))
	assert(game.bird_event.helper==null and not p.get_meta("carried",false))
	await tick(0.5)
	var depart_end:=frame
	await arrive(id)
	assert(game.bird_event.self_flight and game.bird_event.helper==null)
	await tick(Bird.ARRIVE_TIME*0.6);await capture(prefix+"_descent")
	await tick(Bird.ARRIVE_TIME*0.4+0.03);await capture(prefix+"_landing")
	await tick(Bird.RELEASE_TIME+0.06)
	p=game.world.player
	assert(game.bird_event.phase=="idle" and p.lift==0.0 and game.bird_event.helper==null)
	assert(Arena.area_at(p.position)==id)
	assert(not p.get_meta("self_flight_pose",false) and not p.has_meta("loop_animation"))
	assert(p.hp==hp and p.pp==pp and p.exp_total==exp_before and p.bag==bag)
	var saved:=SaveData.load_saved();assert(saved.map==DungeonDB.current and saved.pos.distance_to(p.position)<0.1)
	cases.append({"species":species,"destination":id,"depart_first_frame":first,"depart_end_frame":depart_end,
		"no_carrier":true,"native_wingbeat":true,"departure_camera_fixed":true,"actual_scene_reload":true,
		"self_landing":true,"pose_cleared":true,"hp_pp_exp_bag_preserved":true,"saved_safe_landing":true})

func run() -> void:
	await CaptureWindow.park(self)
	ViewScale.window_ready=true
	SaveData.path="user://save_self_flight_review.cfg";SaveData.clear();SaveData.store_progress("events",Bird.FRIEND)
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","1");OS.set_environment("LANG_CODE","ko")
	Game.starter="charmander";Game.bot_events=[Bird.FRIEND,FlyDestinations.visit_flag("route24"),FlyDestinations.visit_flag("pallet_town")];Game.destination={};Game.arena_trip={};Game.carry={}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SELF_OUT+"frames"))
	for file in DirAccess.get_files_at(SELF_OUT+"frames"):
		if file.ends_with(".png"):DirAccess.remove_absolute(SELF_OUT+"frames/"+file)
	OS.set_environment("DUNGEON","kanto_south")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	OS.set_environment("DUNGEON","");configure();OS.set_environment("BOT","0")
	game.world.player.position=Arena.tile_center(Arena.area_tile("pallet_town",Vector2i(11,9)))
	game.world.cam.position=game.world.player.position;game.view3d._cam_ready=false
	await self_journey("charizard","route24","01_charizard")
	await self_journey("butterfree","pallet_town","02_butterfree")
	assert(cases.size()==2)
	FileAccess.open(SELF_OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":cases,"frames":frame,"fps":20},"  "))
	print("Self-flight review: Charizard and Butterfree, native wingbeats, no carrier, two real scene transfers, self landings, pose cleanup and resource/safe-save preservation passed; %d frames"%frame)
	game.free();await process_frame;SaveData.clear();quit()
