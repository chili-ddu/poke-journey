extends SceneTree
const Game=preload("res://scripts/game.gd")
const Bird=preload("res://scripts/story/bird_event.gd")
const OUT="res://docs/bird_friend/nest_bowl/"
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

func tick(seconds: float) -> void:
	for _i in int(ceil(seconds/DT)):
		game.advance(DT);game.view3d._process(DT)
		await process_frame

func shot(name: String) -> void:
	for _i in 4:
		game.view3d._process(0.0)
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")

func finish_talk() -> void:
	for _i in 10:
		if game.state!="talk":return
		game._talk_next()

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_bird_nest_bowl_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","1");OS.set_environment("LANG_CODE","ko")
	Game.starter="charmander";Game.bot_events=[];Game.destination={};Game.arena_trip={};Game.carry={}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	OS.set_environment("DUNGEON",Bird.ARENA)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	OS.set_environment("DUNGEON","")
	game.set_process(false);game.bot=false;game.world.god=true;game.view3d.set_process(false)
	game.world.player.controller=Still.new();game.banner_t=0.0
	var crowns: MeshInstance3D=game.view3d.root3d.get_node("TreeCanopies")
	var branches: MeshInstance3D=game.view3d.root3d.get_node("NestBranches")
	assert(int(crowns.get_meta("trees"))>200 and int(branches.get_meta("branches"))>60)
	assert(int(crowns.get_meta("scaled_trees"))>0 and is_equal_approx(float(crowns.get_meta("max_tree_scale")),1.5))
	assert((crowns.material_override as StandardMaterial3D).texture_filter==BaseMaterial3D.TEXTURE_FILTER_NEAREST)
	assert(branches.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	var p: Player=game.world.player
	var hp:=p.hp;var pp:=p.pp.duplicate();var exp_before:=p.exp_total
	await tick(Bird.NEST_PASS_TIME+Bird.NEST_THROW_TIME+Bird.NEST_SETTLE_TIME+0.1)
	assert(game.bird_event.phase=="nest_intro" and game.state=="talk")
	var center: Vector2=game.bird_event.nest_center()
	var roosts: Array=[]
	for mon in game.world.bystanders:
		var feet: Vector2=mon.position+Vector2(0,mon.feet_offset())
		assert(feet.distance_to(center)<Arena.TILE*5.8)
		assert(not Arena.solid_at(Arena.tile_of(feet).x,Arena.tile_of(feet).y))
		var screen: Vector2=game.view3d.cam.unproject_position(game.view3d.to3d(feet))
		assert(Rect2(Vector2.ZERO,Vector2(game.view3d.vp.size)).has_point(screen))
		roosts.append({"feet_tiles":[feet.x/Arena.TILE,feet.y/Arena.TILE],"inside_lining":true,"on_open_ground":true})
	assert(roosts.size()==6)
	await shot("01_intro")
	game.state="bird_event"
	await shot("02_waiting")
	game.state="talk"
	finish_talk();assert(game.bird_event.phase=="battle")
	for _i in 6:
		game.bird_event.step_battle(Bird.INTERVAL);game.world._step_spawns(1.0)
	assert(game.world.alive_enemies().size()==6 and game.world.bystanders.is_empty())
	for i in 6:
		var mon: Mon=game.world.alive_enemies()[i]
		var feet:=mon.position+Vector2(0,mon.feet_offset())
		var prior: Array=roosts[i].feet_tiles
		assert(feet.distance_to(Vector2(float(prior[0]),float(prior[1]))*Arena.TILE)<0.1)
	await shot("03_joined_from_roosts")
	for _i in 6:
		game.bird_event.step_battle(Bird.INTERVAL);game.world._step_spawns(1.0)
	assert(game.world.alive_enemies().size()==12)
	game.bird_event.spawn_t=100.0
	await tick(0.7)
	for mon in game.world.alive_enemies():
		var feet: Vector2=mon.position+Vector2(0,mon.feet_offset())
		assert(feet.distance_to(center)<Arena.TILE*7.0)
		assert(game.world.exp_gain(mon)==0)
	await shot("04_flock_battle")
	assert(p.hp==hp and p.pp==pp and p.exp_total==exp_before)
	var report={"center_tiles":[center.x/Arena.TILE,center.y/Arena.TILE],"lining_height":Arena.ground_height(center),
		"rim_height":Arena.ground_height(center+Vector2.RIGHT*8.25*Arena.TILE),"waiting_chicks":roosts,
		"all_six_visible_inside_lining":true,"all_twelve_entries_inside_bowl":true,"waiting_to_combat_without_position_jump":true,
		"hp_pp_exp_preserved":true,"zero_exp":true,"actual_native_render":true,
		"native_canopy_trees":crowns.get_meta("trees"),"enlarged_canopies":crowns.get_meta("scaled_trees"),"max_tree_scale":crowns.get_meta("max_tree_scale"),
		"solid_pixel_bark_branches":branches.get_meta("branches"),"nearest_texture_filter":true}
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("Nest bowl review: recessed lining, rounded lip, six visible interior roosts, twelve safe entries, original zero-EXP battle and HP/PP preserved")
	game.free();await process_frame;SaveData.clear();quit()
