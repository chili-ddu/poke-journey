extends SceneTree
const Game=preload("res://scripts/game.gd")
const Passage=preload("res://scripts/story/moon_passage.gd")
const OUT="res://docs/moon_passage/"
const PATH="user://save_moon_passage_review.cfg"
const DT=1.0/50.0
var game: Node
var health: int
var pp: Array
var exp_before: int
var checks: Array=[]
class Still:
	extends RefCounted
	func move_dir(_w):return Vector2.ZERO
	func aim_point(w):return w.player.position+Vector2.UP*80
	func want_skill(_i,_w):return false
	func want_dodge(_w):return false
	func want_jump(_w):return false
	func want_item(_w):return false

func _init() -> void:call_deferred("run")

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	DirAccess.make_dir_recursive_absolute("/tmp/poke-moon-passage-frames")
	SaveData.path=PATH
	if FileAccess.file_exists(PATH):DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	OS.set_environment("DUNGEON","kanto_north")
	Game.bot_events=[];Game.bot_beaten=[];Game.destination={};Game.carry={};Game.arena_trip={}
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	freeze()
	OS.set_environment("DUNGEON","");OS.set_environment("BOT","0")
	var west:=Arena.warp_tile("route4",0)
	game.world.player.position=Arena.tile_center(west+Vector2i.DOWN)
	game.world.cam.position=game.world.player.position
	game.view3d._cam_ready=false
	game._save_here()
	for i in 18:await frame()
	await shot("01_western_entrance")
	game.world.player.position=Arena.tile_center(west);game.warp_armed=true;game._check_warp()
	assert(game.state=="warp")
	await arrive(Passage.PLACE)
	assert(game.state=="moon_event")
	for i in 24:await frame()
	await shot("02_clefairy_approaches")
	for i in 100:
		if game.state=="talk":break
		await frame()
	assert(game.state=="talk" and game.dialog_text.contains("R"))
	await shot("03_warning")
	press_space();await frame();await shot("04_offer")
	press_space();await frame();await shot("05_metronome_dialogue")
	game.world.player.hp=maxi(1,game.world.player.max_hp-3)
	health=game.world.player.hp;pp=game.world.player.pp.duplicate();exp_before=game.world.player.exp_total
	press_space()
	assert(game.state=="moon_event" and game.moon_passage.actor.attack_anim=="Dance")
	var cave_id:=game.get_instance_id()
	for i in 94:
		await frame()
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/poke-moon-passage-frames/%03d.png"%i)
		if i==30:await shot("06_finger_waggle")
		if i==65:await shot("07_teleport_release")
	for i in 5:
		if not is_instance_valid(game) or not game.is_inside_tree() or game.state=="warp":break
		await frame()
	await arrive(KantoWorldTravel.ID,cave_id)
	for i in 22:await frame()
	assert(game.events.has(Passage.CROSSED))
	assert(game.world.player.hp==health and game.world.player.pp==pp and game.world.player.exp_total==exp_before)
	assert(not game.beaten.has(Game.MOON_GRADUATION))
	var east:=Arena.warp_tile("route4",1)
	assert(Arena.tile_of(game.world.player.position)==east+Vector2i.DOWN)
	assert(game.state=="fight" and game.battle.is_empty())
	assert(SaveData.load_saved().events.has(Passage.CROSSED))
	await shot("08_eastern_exit")
	game.world.player.position=Arena.tile_center(east);game.warp_armed=true;game._check_warp()
	assert(game.state=="talk" and game.dialog_text==game.moon_passage.text("blocked"))
	await frame();await shot("09_return_blocked")
	checks.append({"actual_scene_transitions":2,"arrival":DungeonDB.current,"east_exit":str(east),"hp_pp_exp_preserved":true,"no_rocket_battle_or_victory":true,"completion_saved":true,"reverse_entry_blocked":true})
	# Reload the actual isolated save and try the entrance again.
	while game.state=="talk":press_space()
	game._save_here();Game.destination={};Game.carry={}
	var old_id:=game.get_instance_id();reload_current_scene()
	await arrive(KantoWorldTravel.ID,old_id)
	game.warp_armed=true;game._check_warp()
	assert(game.state=="talk" and game.dialog_text==game.moon_passage.text("blocked"))
	checks.append({"reload_keeps_sealed_entry":true,"window":str(root.size),"isolated_save":PATH})
	assert(root.size==Vector2i(384,216))
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(checks,"  "))
	print("Moon passage: west entrance, Clefairy greeting, Metronome, east arrival, resource carry and sealed-entry reload passed")
	game.queue_free();await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	quit()

func freeze() -> void:
	game.set_process(false);game.view3d.set_process(false);game.bot=false
	game.world.player.controller=Still.new();game.banner_t=0.0

func frame() -> void:
	game.advance(DT)
	if game.is_inside_tree():
		game._update_dialogue_focus();game.view3d._process(DT)
	await process_frame

func press_space() -> void:
	var event:=InputEventKey.new();event.physical_keycode=KEY_SPACE;event.pressed=true
	game._unhandled_input(event)

func arrive(place: String,previous_id: int=0) -> void:
	var old_id:=game.get_instance_id() if previous_id==0 else previous_id
	for i in 360:
		await process_frame
		if is_instance_valid(current_scene) and current_scene.get_instance_id()!=old_id:break
	assert(is_instance_valid(current_scene) and current_scene.get_instance_id()!=old_id,"Real scene transition completed")
	game=current_scene;freeze()
	assert(DungeonDB.current==place,"Correct destination")
	assert(root.size==Vector2i(384,216),"Scene transitions keep the minimum window")
	await frame()

func shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+label+".png")
