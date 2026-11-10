extends SceneTree
const Game=preload("res://scripts/game.gd")
const Event=preload("res://scripts/story/lapras_escape.gd")
const Data=Event.Data
const OUT="res://docs/lapras_escape/"
const DT=1.0/60.0
var game: Node
class Still:
	extends RefCounted
	var moving:=Vector2.ZERO
	func move_dir(_w):return moving
	func aim_point(w):return w.player.position+Vector2.UP*80.0
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func _init() -> void:call_deferred("run")

func configure() -> void:
	game.set_process(false);game.bot=false;game.world.god=true
	game.world.player.controller=Still.new();game.world.player.repel_steps=99999;game.lure_t=99999
	game.banner_t=0.0;game.dialog_text="" if game.state!="talk" else game.dialog_text
	game.status_messages.clear();game.status_message_times.clear();game.status_message_active=false
	game.road_pursuit.clear(game.world)

func open_place(place: String) -> void:
	if is_instance_valid(game):game.free()
	OS.set_environment("DUNGEON",place)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	configure();OS.set_environment("DUNGEON","")
	await process_frame

func finish_talk() -> void:
	for _i in 60:
		if game.state!="talk":break
		game._talk_next()

func shot(name: String) -> void:
	game._update_dialogue_focus();game.world._step_tall_grass()
	game.world.cam.position=game.world.player.position
	game.view3d._cam_ready=false
	for _i in 12:await process_frame
	await RenderingServer.frame_post_draw
	assert(DisplayServer.window_get_size()==Vector2i(384,216))
	root.get_texture().get_image().save_png(OUT+name+".png")

func frames(count: int) -> void:
	for _i in count:
		game.advance(DT)
		await process_frame

func arrive(place: String) -> void:
	var prior=game
	for _i in 600:
		if current_scene!=prior:break
		if is_instance_valid(prior) and prior.state=="encounter":prior.advance(DT)
		await create_timer(0.01).timeout
	assert(current_scene!=prior,"Real scene transition completed")
	game=current_scene;configure();assert(DungeonDB.current==place)
	await process_frame

func space() -> void:
	var input:=InputEventKey.new();input.physical_keycode=KEY_SPACE;input.pressed=true
	game._unhandled_input(input)

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_lapras_escape_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","1");OS.set_environment("LANG_CODE","ko")
	Game.bot_events=[];Game.arena_trip={};Game.carry={};Game.destination={};Game.starter="charmander"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await open_place(Data.PLACE)
	game.world.player.position=Arena.tile_center(game.lapras_escape.target.talk_tile)
	game.world.player.facing=Vector2.UP
	await shot("01_exhibit")
	space();assert(game.state=="talk");await shot("02_request")
	finish_talk();await frames(28);await shot("03_escape")
	await frames(78);assert(game.state=="talk");await shot("04_staff_pursuit")
	finish_talk();await arrive(Data.ARENA)
	await shot("05_four_staff")
	finish_talk();await frames(75)
	assert(game.world.alive_enemies().size()==4)
	await shot("06_four_active")
	var player_screen: Vector2=game.view3d.cam.unproject_position(game.view3d.to3d(game.world.player.position))
	assert(player_screen.y<154.0,"Player remains above the message box")
	assert(player_screen.x>168.0 and player_screen.x<274.0,"Player stays clear of side HUD panels")
	var event=game.lapras_escape
	var original: Array=event.active.duplicate()
	var start_exp: int=game.world.player.exp_total
	game.world.damage(original[0],original[0].hp)
	await frames(100)
	assert(event.next==[2,1,1,1])
	for i in range(1,4):assert(event.active[i]==original[i])
	await shot("07_independent_replacement")
	for _round in 4:
		for e in game.world.alive_enemies():game.world.damage(e,e.hp)
		game.world.step_visual(2.0);event.step_battle(2.0)
	assert(game.defeated==12 and game.events.has(Data.WON))
	assert(game.world.player.exp_total==start_exp)
	await shot("08_victory")
	finish_talk();await arrive(Data.PLACE)
	assert(game.state=="talk" and game.lapras_escape.phase=="reunion")
	await shot("09_beach_reunion")
	game._talk_next();await shot("10_promise")
	finish_talk();assert(game.events.has(Data.FRIEND));await frames(60)
	game.world.player.facing=Vector2.DOWN
	space();assert(game.state=="lapras_event")
	await frames(42);await shot("11_lapras_arrives")
	await frames(24)
	assert(game.world.player.travel_terrain==2 and game.lapras_escape.mounted)
	await shot("12_surf_friend")
	game.world.player.controller.moving=Vector2.DOWN
	await frames(60);game.world.player.controller.moving=Vector2.ZERO
	assert(game.lapras_escape.helper!=null and game.world.player.travel_terrain==2)
	await shot("13_open_sea")
	game._save_here();var saved:=SaveData.load_saved()
	assert(saved.events.has(Data.FRIEND) and Arena.is_water(Arena.tile_of(saved.pos)))
	game.free();await process_frame
	OS.set_environment("BOT","0");Game.destination={};Game.carry={};Game.arena_trip={}
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game;configure()
	await frames(2)
	assert(game.events.has(Data.FRIEND) and game.world.player.travel_terrain==2)
	assert(game.world.bystanders.filter(func(m):return m.species_id=="lapras").size()==1)
	await shot("14_saved_surf_resume")
	var checks={"staff":4,"per_staff":3,"total":12,"maximum_active":4,"independent_replacement":true,"zero_exp":start_exp==game.world.player.exp_total,"friend":true,"space_call":true,"saved_surf_resume":true,"actual_scene_transitions":2,"window":[384,216],"defeats":"Normal damage callbacks, diagnostic fast-forward"}
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("Lapras review: escape, 4 independent parties / 12 defeats, beach friendship, shore call and saved surf resume passed")
	game.free();await process_frame;SaveData.clear();quit()
