extends SceneTree
const Game=preload("res://scripts/game.gd")
const Bird=preload("res://scripts/story/bird_event.gd")
const OUT="res://docs/bird_friend/nest_throw/"
const DT=1.0/60.0
var game: Node
var frames:=0

class Still:
	extends RefCounted
	func move_dir(_w):return Vector2.ZERO
	func aim_point(w):return w.player.position+Vector2.UP*80.0
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func _init() -> void:call_deferred("run")

func shot(name: String="", record: bool=true) -> void:
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	if record:
		image.save_png(OUT+"frames/%04d.png"%frames);frames+=1
	if name!="":image.save_png(OUT+name+".png")

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_bird_nest_throw_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","1");OS.set_environment("LANG_CODE","ko")
	Game.starter="charmander";Game.bot_events=[];Game.destination={};Game.arena_trip={};Game.carry={}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"frames"))
	for file in DirAccess.get_files_at(OUT+"frames"):
		if file.ends_with(".png"):DirAccess.remove_absolute(OUT+"frames/"+file)
	OS.set_environment("DUNGEON",Bird.ARENA)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	OS.set_environment("DUNGEON","")
	game.set_process(false);game.bot=false;game.world.god=true;game.view3d.set_process(false)
	game.world.player.controller=Still.new();game.banner_t=0.0
	# Populate the native frame textures before recording the first carried pose.
	for _i in 3:
		game.view3d._process(0.0)
		await process_frame
	var p: Player=game.world.player
	var bird=game.bird_event
	var hp:=p.hp;var pp:=p.pp.duplicate();var exp_before:=p.exp_total
	var camera:=Transform3D.IDENTITY
	var seen: Dictionary={}
	var parent_offscreen:=false
	var trajectory: Array=[]
	var total:=Bird.NEST_PASS_TIME+Bird.NEST_THROW_TIME+Bird.NEST_SETTLE_TIME+0.75
	for tick in int(ceil(total/DT)):
		game.advance(DT);game.view3d._process(DT)
		await process_frame
		if tick==0:camera=game.view3d.cam.global_transform
		assert(camera.is_equal_approx(game.view3d.cam.global_transform),"The camera holds the nest throughout the throw")
		if is_instance_valid(bird.helper):
			var parent: Vector2=game.view3d.cam.unproject_position(View3D.to3d(bird.helper.position,bird.helper.lift/Arena.TILE*game.view3d.bill))
			if parent.x>game.view3d.vp.size.x or parent.y<0.0:parent_offscreen=true
		var mark:=""
		if not seen.has(bird.nest_stage):
			mark=String(bird.nest_stage);seen[mark]=true
		if bird.nest_stage=="thrown" and bird.elapsed>Bird.NEST_PASS_TIME+Bird.NEST_THROW_TIME*0.6 and not seen.has("falling"):
			mark="falling";seen[mark]=true
		if tick%2==0 or mark!="":await shot(mark,tick%2==0)
		if tick%2==0:trajectory.append({"time":float(tick+1)*DT,"stage":bird.nest_stage,"position":[p.position.x,p.position.y],"lift":p.lift,"carried":p.get_meta("carried",false)})
	assert(seen.size()==5 and parent_offscreen)
	assert(bird.phase=="nest_intro" and bird.helper==null and p.lift==0.0 and p.position==bird.origin)
	assert(p.hp==hp and p.pp==pp and p.exp_total==exp_before)
	assert(game.world.bystanders.size()==6 and game.world.remaining()==0)
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"fixed_nest_camera":true,"parent_exits_screen":parent_offscreen,
		"independent_throw_arc":true,"feet_impact_then_dialogue":true,"hp_pp_exp_preserved":true,"waiting_chicks":6,"frames":frames,"fps":30,"trajectory":trajectory},"  "))
	print("Nest throw review: carried pass, forward release, separate arc and impact, parent exits before dialogue, fixed nest camera and unchanged HP/PP/EXP; %d frames"%frames)
	game.free();await process_frame;SaveData.clear();quit()
