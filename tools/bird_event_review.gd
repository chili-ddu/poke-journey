extends SceneTree
const Game=preload("res://scripts/game.gd")
const Bird=preload("res://scripts/story/bird_event.gd")
const OUT="res://docs/bird_friend/"
const DT=1.0/60.0
var game: Node
var frame:=0
var recording:=false

class Pilot:
	extends RefCounted
	var direction:=Vector2.ZERO
	func move_dir(_w):return direction
	func aim_point(w):return w.player.position+Vector2.UP*80.0
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func _init() -> void:call_deferred("run")

func configure() -> void:
	game.set_process(false);game.bot=false
	game.world.god=true;game.world.player.controller=Pilot.new()
	game.banner_t=0.0;game.road_pursuit.clear(game.world)

func shot(name: String) -> void:
	game._update_dialogue_focus()
	game.world._step_tall_grass()
	for _i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")

func tick(seconds: float) -> void:
	for i in int(ceil(seconds/DT)):
		if not is_instance_valid(game) or current_scene!=game:break
		game.advance(DT)
		if game.bird_event.phase=="transition":assert(game.world.player.lift>100.0,"Fade preserves the airborne pose")
		await process_frame
		if not is_instance_valid(game) or current_scene!=game:break
		if recording and i%3==0:
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+"frames/%04d.png"%frame);frame+=1

func pause_shot(name: String, seconds: float=0.6) -> void:
	await shot(name)
	# Hold dialogue for the recording without automatically advancing it.
	if recording:
		for _i in int(seconds*20.0):
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+"frames/%04d.png"%frame);frame+=1

func space() -> void:
	var key:=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true
	game._unhandled_input(key)

func finish_talk() -> void:
	for _i in 40:
		if game.state!="talk":break
		game._talk_next()

func arrive(place: String) -> void:
	var prior=game
	for _i in 600:
		if current_scene!=null and current_scene!=prior:break
		await create_timer(0.01).timeout
	assert(current_scene!=null and current_scene!=prior,"Real scene transition completed")
	game=current_scene;configure()
	assert(DungeonDB.current==place)
	await process_frame

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_bird_event_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","1");OS.set_environment("LANG_CODE","ko")
	Game.starter="charmander";Game.bot_events=[];Game.arena_trip={};Game.carry={};Game.destination={}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"frames"))
	for file in DirAccess.get_files_at(OUT+"frames"):
		if file.ends_with(".png"):DirAccess.remove_absolute(OUT+"frames/"+file)
	OS.set_environment("DUNGEON","kanto_south")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	OS.set_environment("DUNGEON","");configure();await process_frame
	assert(game.view3d!=null)
	game.world.player.position=Arena.tile_center(Arena.area_tile("pallet_town",Vector2i(11,9)))
	var source: Vector2=game.world.player.position
	game.world.cam.position=source;game.view3d._cam_ready=false
	game.dialog_text="";game.dialog_t=0.0
	await shot("01_before_jump")
	game.world._start_hop(source+Vector2.UP*24.0)
	await tick(0.13)
	space();assert(game.bird_event.phase=="swoop")
	recording=true
	await tick(0.5);await pause_shot("02_swoop",0.0)
	await tick(0.3);await pause_shot("03_caught")
	finish_talk();await tick(0.7);await pause_shot("04_carried_away",0.0)
	await tick(0.5);recording=false
	await arrive(Bird.ARENA)
	recording=true;await tick(0.9);await pause_shot("05_nest_drop",1.0)
	game._talk_next();await pause_shot("06_hungry_chicks",1.0)
	finish_talk()
	var exp_before: int=game.world.player.exp_total
	for _i in 6:
		game.bird_event.step_battle(Bird.INTERVAL);game.world._step_spawns(1.0)
	var spawn_clock: float=game.bird_event.spawn_t
	game.bird_event.spawn_t=100.0
	await tick(2.0) # Actual approach and peck AI, with damage protection for this capture.
	game.bird_event.spawn_t=spawn_clock
	for enemy in game.world.alive_enemies():enemy.frozen=true
	await pause_shot("07_flock_battle",1.0)
	for enemy in game.world.alive_enemies():game.world.damage(enemy,enemy.hp)
	game.world.step_visual(1.5)
	for _i in range(6,Bird.COUNT):
		game.bird_event.step_battle(Bird.INTERVAL);game.world._step_spawns(1.0)
		for enemy in game.world.alive_enemies():game.world.damage(enemy,enemy.hp)
		game.world.step_visual(1.5)
	game.bird_event.step_battle(DT)
	assert(game.bird_event.phase=="boss_arrival")
	await tick(0.85);await pause_shot("08_angry_parent",1.0)
	finish_talk();game.world._step_spawns(1.0)
	var parent: Enemy=game.bird_event.boss()
	assert(parent!=null);parent.frozen=true
	await pause_shot("09_pidgeotto_boss",0.6)
	game.world.damage(parent,parent.hp);game.world.step_visual(1.5)
	game.bird_event.step_battle(DT)
	assert(game.events.has(Bird.WON) and not game.events.has(Bird.FRIEND))
	assert(game.world.player.exp_total==exp_before)
	await pause_shot("10_astonished",1.0)
	game._talk_next();await pause_shot("11_apology",1.0)
	finish_talk();await tick(1.2);recording=false
	await arrive("kanto_south")
	assert(game.world.player.position.distance_to(source)<0.1,"Exact pre-jump return position")
	recording=true;await tick(1.05);await pause_shot("12_back_home",0.6)
	game._talk_next();await pause_shot("13_strongest_dream",0.8)
	game._talk_next();await pause_shot("14_number_one_fan",1.0)
	game._talk_next();await pause_shot("15_promise",0.8)
	finish_talk();await tick(0.9);finish_talk()
	assert(game.events.has(Bird.FRIEND))
	var exp_after: int=game.world.player.exp_total
	await pause_shot("16_friend_unlocked",0.3)
	game.dialog_text="";game.dialog_t=0.0
	game.world._start_hop(game.world.player.position+Vector2.UP*24.0)
	await tick(0.13);space();game.bird_event.choose_destination("pallet_town");await tick(0.8)
	game.world.player.controller.direction=Vector2.RIGHT
	await tick(0.6);await pause_shot("17_pidgeotto_ride",0.5)
	await tick(1.5);await arrive("kanto_south");await tick(Bird.ARRIVE_TIME+Bird.RELEASE_TIME+Bird.LEAVE_TIME+0.1)
	assert(game.bird_event.phase=="idle")
	game.world.player.setup_player("blastoise",36,[],{})
	game.world.player.controller=Pilot.new();game.world.player.position=source
	game.world._start_hop(source+Vector2.UP*24.0)
	await tick(0.13);space();game.bird_event.choose_destination("pallet_town");await tick(0.8)
	assert(game.bird_event.helper.species_id=="pidgeot")
	await tick(0.3);await pause_shot("18_pidgeot_large_passenger",1.0)
	await tick(1.5);await arrive("kanto_south");await tick(Bird.ARRIVE_TIME+Bird.RELEASE_TIME+Bird.LEAVE_TIME+0.1);recording=false
	assert(game.bird_event.can_land(game.world.player.position))
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"pidgey":Bird.COUNT,"pidgeotto_boss":1,"spawn_interval":Bird.INTERVAL,"zero_exp":game.events.has(Bird.WON),"exp_before":exp_before,
		"exp_after":exp_after,"actual_scene_transitions":4,"exact_return":true,"friend_unlocked":game.events.has(Bird.FRIEND),"large_carrier":"pidgeot","frames":frame,
		"combat_validation":"Diagnostic defeats use World.damage and normal defeat callbacks; not a manual difficulty playtest."},"  "))
	print("Bird review: kidnapping, real nest round trip, 13 zero-EXP defeats, friendship, both carriers and safe landing passed; %d frames"%frame)
	game.free();await process_frame;SaveData.clear();quit()
