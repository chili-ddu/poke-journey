extends SceneTree
const Game=preload("res://scripts/game.gd")
const Bird=preload("res://scripts/story/bird_event.gd")
const OUT="res://docs/fly_map/"
const DT=1.0/60.0
var game: Node
var frame:=0
var ticks:=0
var journeys: Array=[]

class Pilot:
	extends RefCounted
	func move_dir(_w):return Vector2.ZERO
	func aim_point(w):return w.player.position+Vector2.UP*80.0
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func _init() -> void:call_deferred("run")

func configure() -> void:
	game.set_process(false);game.bot=false;game.world.god=true
	game.world.player.controller=Pilot.new();game.road_pursuit.clear(game.world)
	game.view3d.set_process(false)
	game.banner_t=0.0;game.dialog_text="";game.dialog_t=0.0

func capture(name: String="") -> void:
	await RenderingServer.frame_post_draw
	var img:=root.get_texture().get_image()
	img.save_png(OUT+"frames/%04d.png"%frame);frame+=1
	if name!="":img.save_png(OUT+name+".png")

func tick(seconds: float) -> void:
	for _i in int(ceil(seconds/DT)):
		if not is_instance_valid(game) or current_scene!=game:break
		game.advance(DT);game.view3d._process(DT);game._update_dialogue_focus()
		await process_frame
		if not is_instance_valid(game) or current_scene!=game:break
		if ticks%3==0:await capture()
		ticks+=1

func space() -> void:
	var key:=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true
	game._unhandled_input(key)

func map_key(code: Key) -> void:
	var key:=InputEventKey.new();key.physical_keycode=code;key.pressed=true
	game.fly_screen._unhandled_input(key)

func select_map(id: String) -> void:
	var entry:=FlyDestinations.find(id);var rect: Array=entry.region
	var click:=InputEventMouseButton.new();click.pressed=true;click.button_index=MOUSE_BUTTON_LEFT
	click.position=game.fly_screen.origin()+game.fly_screen.MAP.position+Vector2(float(rect[0])+4,float(rect[1])+4)
	game.fly_screen._gui_input(click)
	assert(game.fly_screen.selected().id==id)

func arrive(id: String) -> void:
	var prior=game
	for _i in 600:
		if current_scene!=null and current_scene!=prior:break
		await create_timer(0.01).timeout
	assert(current_scene!=null and current_scene!=prior)
	game=current_scene;configure()
	assert(Arena.area_at(game.world.player.position)==id)
	assert(game.bird_event.phase=="fly_arrive")
	await process_frame

func journey(id: String, prefix: String) -> void:
	var p: Player=game.world.player
	var hp:=p.hp;var pp:=p.pp.duplicate();var exp_before:=p.exp_total;var bag:=p.bag.duplicate(true)
	game.world._start_hop(p.position+Vector2.UP*24.0);await tick(0.13)
	space();assert(game.menu=="fly")
	await tick(0.3);select_map(id);await tick(0.45)
	await capture(prefix+"_map")
	map_key(KEY_SPACE);assert(game.bird_event.phase=="calling")
	await tick(0.47);await capture(prefix+"_pickup")
	await tick(0.9);await arrive(id)
	await tick(Bird.ARRIVE_TIME+0.03);await capture(prefix+"_landing")
	await tick(Bird.RELEASE_TIME+Bird.LEAVE_TIME+0.05)
	p=game.world.player
	assert(p.hp==hp and p.pp==pp and p.exp_total==exp_before and p.bag==bag)
	assert(game.bird_event.phase=="idle" and game.bird_event.can_land(p.position))
	var saved:=SaveData.load_saved()
	assert(saved.map==DungeonDB.current and saved.pos.distance_to(p.position)<0.1)
	journeys.append({"area":id,"map":DungeonDB.current,"hp_preserved":hp,"pp_preserved":true,"exp_preserved":exp_before,
		"saved_landing":true,"carrier":Bird.carrier(p),"actual_scene_reload":true})

func run() -> void:
	await CaptureWindow.park(self)
	ViewScale.window_ready=true
	SaveData.path="user://save_fly_map_review.cfg";SaveData.clear();SaveData.store_progress("events",Bird.FRIEND)
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","1");OS.set_environment("LANG_CODE","ko")
	Game.starter="charmander";Game.bot_events=[Bird.FRIEND];
	Game.destination={};Game.arena_trip={};Game.carry={}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"frames"))
	for file in DirAccess.get_files_at(OUT+"frames"):
		if file.ends_with(".png"):DirAccess.remove_absolute(OUT+"frames/"+file)
	OS.set_environment("DUNGEON","kanto_south")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	OS.set_environment("DUNGEON","");configure()
	OS.set_environment("BOT","0")
	game.world.player.position=Arena.tile_center(Arena.area_tile("pallet_town",Vector2i(11,9)))
	game.world.player.hp=11;game.world.player.pp[0]=maxi(1,game.world.player.pp[0]-3)
	game.world.cam.position=game.world.player.position;game.view3d._cam_ready=false
	game.world._start_hop(game.world.player.position+Vector2.UP*24.0);await tick(0.13)
	space();assert(game.fly_screen.visible)
	await tick(0.3);await capture("01_native_town_map")
	assert(not game.fly_screen.entries.any(func(entry):return entry.id=="vermilion_city"))
	var locked:=FlyDestinations.find("vermilion_city");var rect: Array=locked.region
	var event:=InputEventMouseButton.new();event.button_index=MOUSE_BUTTON_LEFT;event.pressed=true
	event.position=game.fly_screen.origin()+game.fly_screen.MAP.position+Vector2(rect[0]+4,rect[1]+4)
	game.fly_screen._gui_input(event)
	assert(game.menu=="fly" and game.bird_event.helper==null)
	assert(game.fly_screen.notice==Lang.t("fly_unvisited",[FlyDestinations.label(locked)]))
	await tick(0.15);await capture("01b_unvisited_rejected")
	var at: Vector2=game.world.player.position;var hop: float=game.world.player.hop_t
	map_key(KEY_ESCAPE)
	assert(game.world.player.position==at and game.world.player.hop_t==hop and game.bird_event.helper==null)
	# The remaining animation fixtures use explicitly saved prior visits.
	for entry in FlyDestinations.all_locations():
		if entry.enabled:
			game.events.append(FlyDestinations.visit_flag(entry.id))
			SaveData.store_progress("events",FlyDestinations.visit_flag(entry.id))
	await journey("route24","02_route24")
	game.world.player.setup_player("blastoise",36,[],{});game.world.player.controller=Pilot.new()
	game.world.player.hp=game.world.player.max_hp-7
	await journey("vermilion_city","03_vermilion")
	await journey("pewter_city","04_pewter")
	await journey("route4","05_same_field")
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"destinations":FlyDestinations.available(game.events).size(),"unvisited_rejected":true,"cancel_preserves_jump":true,
		"journeys":journeys,"frames":frame,"fps":20},"  "))
	print("Fly map review: native map, cancellation, four real trips including shared-field travel, HP/PP/EXP/bag preservation and saved safe landings passed; %d frames"%frame)
	game.free();await process_frame;SaveData.clear();quit()
