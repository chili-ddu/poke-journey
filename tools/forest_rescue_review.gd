extends SceneTree
const Game=preload("res://scripts/game.gd")
const Rescue=preload("res://scripts/story/forest_rescue.gd")
const OUT="res://docs/route22_scyther_rescue/"
const DT=1.0/60.0
var game: Node
class Still:
	extends RefCounted
	func move_dir(_w):return Vector2.ZERO
	func aim_point(w):return w.player.position+Vector2.UP*80.0
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func _init() -> void:call_deferred("run")

func configure() -> void:
	game.set_process(false)
	game.bot=false
	game.world.god=true
	game.world.player.controller=Still.new()
	game.banner_t=0.0
	game.road_pursuit.clear(game.world)
	game.road_pursuit.cooldown=10000.0
	assert(DisplayServer.window_get_size()==Vector2i(384,216))

func open_place(place: String) -> void:
	if is_instance_valid(game):game.free()
	OS.set_environment("DUNGEON",place)
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game);current_scene=game
	configure()
	OS.set_environment("DUNGEON","")
	await process_frame

func finish_talk() -> void:
	for _i in 40:
		if game.state!="talk":break
		game._talk_next()

func shot(name: String) -> void:
	game._update_dialogue_focus()
	game.world._step_tall_grass()
	for _i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")

func arrive(place: String) -> void:
	var prior=game
	for _i in 600:
		if current_scene!=prior:break
		if is_instance_valid(prior) and prior.state=="encounter":prior.advance(DT)
		await create_timer(0.01).timeout
	assert(current_scene!=prior,"The real scene transition completed")
	game=current_scene;configure()
	assert(DungeonDB.current==place)
	await process_frame

func run() -> void:
	await CaptureWindow.park(self)
	Game.starter="charmander"
	SaveData.path="user://save_forest_rescue_review.cfg"
	SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","1");OS.set_environment("LANG_CODE","ko")
	Game.bot_events=[];Game.arena_trip={};Game.carry={};Game.destination={}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await open_place(Rescue.PLACE)
	assert(game.view3d!=null)
	game.world.player.position=Arena.tile_center(Rescue.tile(Rescue.PLAYER_TILE))
	var return_at: Vector2=game.world.player.position
	game.world.player.facing=Vector2.LEFT
	game.dialog_text="";game.dialog_t=0.0
	game.status_messages.clear();game.status_message_times.clear();game.status_message_active=false
	game.world.cam.position=game.world.player.position
	game.view3d._cam_ready=false
	assert(Arena.area_at(game.world.player.position)=="route22")
	await shot("01_injured_scyther")
	game.advance(DT)
	assert(game.state=="talk")
	await shot("02_discovery")
	game._talk_next()
	await shot("03_champion_road")
	finish_talk()
	for _i in 100:
		game.advance(DT)
		for mon in game.forest_rescue.ambushers:
			var feet: Vector2=mon.position+Vector2(0,mon.feet_offset())
			assert(Arena.resolve(feet,mon.radius).distance_to(feet)<0.1,"Ambush approach stays on the road")
		await process_frame
	assert(game.state=="talk")
	await shot("04_mankey_ambush")
	finish_talk()
	await arrive(Rescue.ARENA)
	finish_talk()
	var start_exp: int=game.world.player.exp_total
	var start_level: int=game.world.player.level
	await shot("05_square_arena")
	var preview_count:=mini(6,Rescue.COUNT)
	for i in preview_count:
		game.forest_rescue.step_battle(Rescue.INTERVAL)
		game.world._step_spawns(1.0)
		for e in game.world.alive_enemies():
			assert(e.species_id=="mankey" and e.level==Rescue.GRUNT_LEVEL and e.hp==e.max_hp)
			e.frozen=true
	await shot("06_mankey_stream")
	for e in game.world.alive_enemies():game.world.damage(e,e.hp)
	game.world.step_visual(2.0)
	for i in range(preview_count,Rescue.COUNT):
		game.forest_rescue.step_battle(Rescue.INTERVAL)
		game.world._step_spawns(1.0)
		for e in game.world.alive_enemies():game.world.damage(e,e.hp)
		game.world.step_visual(2.0)
	game.forest_rescue.step_battle(DT);game.world._step_spawns(1.0)
	var boss: Enemy=game.forest_rescue.boss()
	assert(boss!=null and game.defeated==Rescue.COUNT)
	boss.position=game.world.player.position+Vector2.UP*Arena.TILE*3.0
	boss.frozen=true
	assert(boss.species_id=="mankey" and boss.level==Rescue.BOSS_LEVEL and boss.hp==boss.max_hp)
	await shot("07_mankey_leader")
	game.world.damage(boss,boss.hp)
	game.world.step_visual(2.0)
	game.dialog_text="";game.dialog_t=0.0;game.status_messages.clear()
	game.forest_rescue.step_battle(DT)
	assert(game.events.has(Rescue.WON))
	assert(game.world.player.exp_total==start_exp and game.world.player.level==start_level)
	finish_talk()
	await arrive(Rescue.PLACE)
	assert(game.world.player.position.distance_to(return_at)<0.1,"Victory returns to the same Route22 position")
	for _i in 55:game.advance(DT);await process_frame
	assert(game.state=="talk")
	await shot("08_scyther_thanks")
	game._talk_next();game._talk_next()
	await shot("09_scyther_promise")
	finish_talk()
	assert(game.events.has(Rescue.FRIEND))
	assert(game.world.player.known_moves().has("cut"))
	assert(SaveData.load_saved().events.has(Rescue.FRIEND))
	assert(SaveData.load_saved().learned.has("cut"))
	await shot("10_friend_unlocked")
	finish_talk()
	assert(game.world.player.exp_total==start_exp)
	await open_place("kanto_south")
	var tree: Npc=game.field_friends.trees[0]
	var tree_tile:=tree.tile
	game.world.player.position=Arena.resolve(Arena.tile_center(tree_tile+Vector2i.DOWN),game.world.player.radius)
	game.world.player.facing=Vector2.UP
	game.world.cam.position=game.world.player.position
	game.view3d._cam_ready=false
	game.dialog_text="";game.dialog_t=0.0
	await shot("11_native_cut_tree")
	game.dialog_text="";game.dialog_t=0.0
	var call:=InputEventKey.new();call.physical_keycode=KEY_SPACE;call.pressed=true
	game._unhandled_input(call)
	assert(game.state=="field_cut")
	assert(game.field_friends.phase=="self_cut")
	for _i in 150:
		if game.field_friends.cut:break
		game.advance(DT);await process_frame
	assert(not is_instance_valid(game.field_friends.helper))
	await shot("12_self_cut")
	for _i in 180:
		if game.state!="field_cut":break
		game.advance(DT);await process_frame
	assert(game.field_friends.phase=="idle")
	assert(not Arena.solid_at(tree_tile.x,tree_tile.y))
	await shot("13_path_open")
	var ending_exp: int=game.world.player.exp_total
	Game.starter="squirtle";Game.bot_events=[Rescue.FRIEND];Game.carry={};Game.arena_trip={};Game.destination={}
	await open_place("kanto_south")
	tree=game.field_friends.trees[0]
	var fallback_tile: Vector2i=tree.tile
	game.world.player.position=Arena.resolve(Arena.tile_center(tree.tile+Vector2i.DOWN),game.world.player.radius)
	game.world.player.facing=Vector2.UP;game.world.cam.position=game.world.player.position;game.view3d._cam_ready=false
	game.dialog_text="";game.dialog_t=0.0;game.status_messages.clear();game.status_message_active=false
	game._unhandled_input(call)
	assert(game.field_friends.phase=="calling")
	for _i in 150:
		if game.field_friends.eye_glinted:break
		game.advance(DT);await process_frame
	assert(is_instance_valid(game.field_friends.helper))
	await shot("14_friend_cut_help")
	for _i in 240:
		if game.state!="field_cut":break
		game.advance(DT);await process_frame
	assert(not Arena.solid_at(fallback_tile.x,fallback_tile.y))
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"mankey":Rescue.COUNT,"mankey_leader":1,"grunt_level":Rescue.GRUNT_LEVEL,"leader_level":Rescue.BOSS_LEVEL,"spawn_interval":Rescue.INTERVAL,
		"starting_exp":start_exp,"ending_exp":ending_exp,"level":start_level,"friend":game.events.has(Rescue.FRIEND),
		"native_tree_open":true,"self_cut_learned_and_saved":true,"incompatible_friend_help":true,"normal_full_hp":true,"window_size":[384,216],"actual_scene_transitions":2,"returned_to_same_route22_position":true,"ambush_paths_clear":true,"combat_defeats":"diagnostic fast-forward through normal damage/defeat callbacks","art_source":"existing"},"  "))
	print("Route22 rescue review: real scene round trip, %d zero-EXP Mankey defeats, saved self Cut and friend fallback passed"%[Rescue.COUNT+1])
	game.free();await process_frame
	SaveData.clear()
	quit()
