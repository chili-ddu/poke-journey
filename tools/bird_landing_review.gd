extends SceneTree
const Game=preload("res://scripts/game.gd")
const Bird=preload("res://scripts/story/bird_event.gd")
const OUT="res://docs/bird_friend/landing/"
const DT=1.0/60.0
var game: Node
var frames:=0
var checks: Array=[]
var edge_cache: Dictionary={}

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

func screen_edge(mon: Mon, top: bool) -> Vector2:
	var sprite: Sprite3D=game.view3d._sprites[mon.get_instance_id()].sprite
	# Measure the actual 3D frame. The 2D draw metadata may already contain the
	# next key, whose native padding/anchor differs from the displayed key.
	var x: float=sprite.region_rect.size.x*0.5-sprite.offset.x
	var key:="%s:%s:%s:%s"%[sprite.texture.get_instance_id(),sprite.region_rect,x,top]
	if not edge_cache.has(key):edge_cache[key]=game.bird_event._central_edge({"tex":sprite.texture,"src":sprite.region_rect},x,top)
	var edge: float=edge_cache[key]
	return game.view3d.cam.unproject_position(game.view3d.sprite_pixel_position(sprite,Vector2(x,edge)))

func landing(species: String, prefix: String) -> void:
	if is_instance_valid(game):game.free()
	Game.bot_events=[Bird.FRIEND];Game.destination={};Game.arena_trip={};Game.carry={}
	OS.set_environment("DUNGEON","kanto_south")
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game
	OS.set_environment("DUNGEON","")
	game.set_process(false);game.bot=false;game.world.god=true;game.road_pursuit.clear(game.world)
	game.view3d.set_process(false)
	var p: Player=game.world.player
	p.setup_player(species,5 if species=="charmander" else 36,[],{});p.controller=Still.new()
	p.hp-=3
	var hp:=p.hp;var pp:=p.pp.duplicate();var exp_before:=p.exp_total
	game.dialog_text="";game.dialog_t=0.0;game.banner_t=0.0
	game.bird_event.arrive("pallet_town")
	game.world.cam.position=p.position;game.view3d._cam_ready=false
	var at:=p.position;var height:=p.lift;var carrier:=Bird.carrier(p)
	var first_frame:=frames
	var camera:=Transform3D.IDENTITY
	var first_screen:=Vector2.ZERO
	var previous_y:=-INF
	var drift:=0.0
	var min_overlap:=INF;var max_overlap:=-INF
	var max_overlap_fraction:=0.0
	var strokes: Dictionary={}
	var shown: Dictionary={}
	var total:=Bird.ARRIVE_TIME+Bird.RELEASE_TIME+Bird.LEAVE_TIME+0.12
	for tick in int(ceil(total/DT)):
		game.advance(DT);game.view3d._process(DT)
		await process_frame
		if tick==0:camera=game.view3d.cam.global_transform
		assert(game.view3d.cam.global_transform.is_equal_approx(camera),"The camera stays at ground height during the set-down")
		var phase: String=game.bird_event.phase
		if phase in ["fly_arrive","landing_release"] and tick>2:
			var bird: Mon=game.bird_event.helper
			var head:=screen_edge(p,true)
			var overlap:=screen_edge(bird,false).y-head.y
			if p.lift<height*0.35:
				min_overlap=minf(min_overlap,overlap);max_overlap=maxf(max_overlap,overlap)
				max_overlap_fraction=maxf(max_overlap_fraction,overlap/maxf(1.0,screen_edge(p,false).y-head.y))
			strokes[int(bird.stat_overlay.src.position.x)]=true
		if phase=="fly_arrive":
			var feet:=p.position+Vector2(0,p.feet_offset())
			var screen: Vector2=game.view3d.cam.unproject_position(View3D.to3d(feet,p.lift/Arena.TILE*game.view3d.bill))
			if tick==0:first_screen=screen
			drift=maxf(drift,absf(screen.x-first_screen.x))
			assert(screen.y>=previous_y-0.01,"Arrival descends from top to bottom")
			previous_y=screen.y
			assert(p.position==at and p.get_meta("carried",false))
		var mark:=""
		if phase=="fly_arrive" and p.lift<height*0.35 and not shown.has("entry"):mark="entry"
		elif phase=="fly_arrive" and p.lift<height*0.10 and not shown.has("slow"):mark="slow"
		elif phase=="landing_release" and not shown.has("touchdown"):mark="touchdown"
		elif phase=="flight_leave" and not shown.has("release"):mark="release"
		elif phase=="idle" and not shown.has("grounded"):mark="grounded"
		if mark!="":shown[mark]=true
		if tick%3==0 or mark!="":await shot(prefix+"_"+mark if mark!="" else "",tick%3==0)
	assert(drift<0.5 and shown.size()==5 and strokes.size()==2)
	assert(min_overlap>0.0 and max_overlap_fraction<0.2,"The talons overlap only the upper part of the passenger's head at either sprite size")
	assert(game.bird_event.phase=="idle" and p.lift==0.0 and p.position==at)
	assert(p.hp==hp and p.pp==pp and p.exp_total==exp_before)
	var saved:=SaveData.load_saved();assert(saved.map==DungeonDB.current and saved.pos.distance_to(at)<0.1)
	checks.append({"species":species,"carrier":carrier,"first_frame":first_frame,"end_frame":frames,
		"initial_height":height,"descent_seconds":Bird.ARRIVE_TIME,"support_seconds":Bird.RELEASE_TIME,
		"screen_x_drift_pixels":drift,"screen_y_increases":true,"ground_camera_fixed":true,
		"claw_head_overlap_screen_pixels":{"min":min_overlap,"max":max_overlap},"max_overlap_body_fraction":max_overlap_fraction,"visible_wing_poses":strokes.size(),
		"feet_contact_before_release":true,"hp_pp_exp_preserved":true,"saved_safe_landing":true})

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_bird_landing_review.cfg";SaveData.clear()
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","1");OS.set_environment("LANG_CODE","ko")
	Game.starter="charmander"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"frames"))
	for file in DirAccess.get_files_at(OUT+"frames"):
		if file.ends_with(".png"):DirAccess.remove_absolute(OUT+"frames/"+file)
	await landing("charmander","01_pidgeotto")
	await landing("blastoise","02_pidgeot")
	FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"cases":checks,"frames":frames,"fps":20},"  "))
	print("Landing review: both carriers descend vertically, fixed ground camera, slow feet contact before release, HP/PP/EXP and safe save preserved; %d frames"%frames)
	game.free();await process_frame;SaveData.clear();quit()
