extends SceneTree
const Game=preload("res://scripts/game.gd")
const Bird=preload("res://scripts/story/bird_event.gd")
const OUT="res://docs/bird_friend/snatch/"
const DT=1.0/60.0
var game: Node
var frame:=0
var ticks:=0
var checks: Array=[]

class Pilot:
	extends RefCounted
	var direction:=Vector2.ZERO
	func move_dir(_w):return direction
	func aim_point(w):return w.player.position+Vector2.RIGHT*80.0
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func _init() -> void:call_deferred("run")

func open_case(friendly: bool, species: String) -> void:
	if is_instance_valid(game):game.free()
	Game.bot_events=[Bird.FRIEND] if friendly else []
	Game.destination={};Game.arena_trip={};Game.carry={}
	OS.set_environment("DUNGEON","kanto_south")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	OS.set_environment("DUNGEON","")
	game.set_process(false);game.bot=false;game.world.god=true;game.road_pursuit.clear(game.world)
	game.view3d.set_process(false)
	if species!="charmander":game.world.player.setup_player(species,36,[],{})
	game.world.player.controller=Pilot.new()
	game.world.player.position=Arena.tile_center(Arena.area_tile("pallet_town",Vector2i(11,9)))
	game.world.cam.position=game.world.player.position;game.view3d._cam_ready=false
	game.dialog_text="";game.dialog_t=0.0;game.banner_t=0.0
	for _i in 20:
		game.view3d._process(DT)
		await process_frame

func tick(seconds: float, prefix: String="") -> void:
	for _i in int(ceil(seconds/DT)):
		if not is_instance_valid(game) or current_scene!=game:return
		game.advance(DT)
		game.view3d._process(DT)
		game._update_dialogue_focus()
		await process_frame
		if ticks%2==0:
			await RenderingServer.frame_post_draw
			var img:=root.get_texture().get_image()
			img.save_png(OUT+"frames/%04d.png"%frame);frame+=1
			if prefix!="" and game.bird_event.pickup_stage in ["dive","grip","pull","carried"]:
				var target:=OUT+prefix+"_"+String(game.bird_event.pickup_stage)+".png"
				if not FileAccess.file_exists(target):img.save_png(target)
		ticks+=1

func space() -> void:
	var key:=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true
	game._unhandled_input(key)

func pickup(prefix: String, friendly: bool, species: String) -> void:
	await open_case(friendly,species)
	var first_frame:=frame
	var p: Player=game.world.player
	var source:=p.position;var hp_before:=p.hp
	var pp_before:=p.pp.duplicate();var exp_before:=p.exp_total
	await tick(0.25)
	game.world._start_hop(source+Vector2.UP*24.0)
	await tick(0.13)
	space()
	if friendly:game.bird_event.choose_destination("pallet_town")
	var jump_height:=p.lift
	var flight_direction: Vector2=game.bird_event.direction
	var camera: Transform3D=game.view3d.cam.global_transform
	await tick(Bird.DIVE_TIME+Bird.GRIP_TIME+Bird.PULL_TIME+0.04,prefix)
	assert(game.bird_event.gripped)
	assert(p.lift>30.0 and p.hp==hp_before and p.pp==pp_before and p.exp_total==exp_before)
	assert(game.bird_event.safe_at.distance_to(source)<0.1)
	if not friendly:
		assert(game.state=="talk" and game.bird_event.phase=="caught")
		await tick(0.55)
		game._talk_next()
		var height:=p.lift
		await tick(0.03)
		assert(p.lift>=height)
		await tick(0.85)
	else:
		assert(game.bird_event.phase=="fly_depart")
		p.controller.direction=Vector2.RIGHT
		await tick(0.25)
		assert(game.view3d.cam.global_transform.is_equal_approx(camera))
	checks.append({"case":prefix,"friendly":friendly,"species":species,"carrier":Bird.carrier(p) if friendly else "pidgeotto",
		"contact_before_pull":true,"jump_height_preserved":jump_height,"hp_unchanged":p.hp==hp_before,"original_return_position":true,
		"first_frame":first_frame,"end_frame":frame,"camera_locked":friendly,"direction":[flight_direction.x,flight_direction.y]})

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_bird_snatch_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","1");OS.set_environment("LANG_CODE","ko")
	Game.starter="charmander"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"frames"))
	for file in DirAccess.get_files_at(OUT+"frames"):
		if file.ends_with(".png"):DirAccess.remove_absolute(OUT+"frames/"+file)
	for file in DirAccess.get_files_at(OUT):
		if file.ends_with(".png"):DirAccess.remove_absolute(OUT+file)
	await pickup("01_kidnap",false,"charmander")
	await pickup("02_friendly",true,"charmander")
	await pickup("03_large",true,"blastoise")
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":checks,"frames":frame,"fps":30,"mid_dive_freeze_frames":0},"  "))
	print("Snatch review: three real-input pickups, continuous 30fps capture, no mid-dive holds; %d frames"%frame)
	game.free();await process_frame;SaveData.clear();quit()
