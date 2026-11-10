extends SceneTree

const Game=preload("res://scripts/game.gd")
const Story=preload("res://scripts/story/rival_progression.gd")
const OUT="res://docs/rival_progression/"
const DT=1.0/60.0
var game: Node
var failed:=false
var results: Array=[]
var transitions: Array=[]

class Walker:
	extends RefCounted
	var target:=Vector2.ZERO
	var active:=false
	func move_dir(w):
		var delta: Vector2=target-w.player.position
		return delta.normalized()*clampf(delta.length()/8.0,0.15,1.0) if active and delta.length()>0.7 else Vector2.ZERO
	func aim_point(w):return target if active else w.player.position+Vector2.UP*80
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func _init() -> void:call_deferred("run")

func check(ok: bool,message: String) -> bool:
	if not ok:failed=true;push_error(message)
	return ok

func configure() -> void:
	game.set_process(false);game.world.god=true;game.world.player.controller=Walker.new();game.banner_t=0
	if game.view3d!=null:game.view3d.set_process(false)
	check(DisplayServer.get_name()=="headless" or DisplayServer.window_get_size()==CaptureWindow.view_size(),"Minimum 1x window after every scene change")

func render() -> void:
	if game.view3d!=null:game.view3d._process(DT)
	await process_frame

func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	game._update_dialogue_focus()
	for i in 8:await render()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")

func finish_talk() -> void:
	for i in 80:
		if game.state!="talk" or not game.can_advance():break
		game._talk_next()

func transition(place: String) -> bool:
	var previous=game;var from:=DungeonDB.current
	for i in 700:
		if current_scene!=previous:break
		if is_instance_valid(previous) and previous.state=="encounter":previous.advance(DT)
		await create_timer(0.005).timeout
	if not check(current_scene!=previous,"Actual scene transition: "+from+" -> "+place):return false
	game=current_scene;configure()
	if not check(DungeonDB.current==place,"Correct destination: "+place):return false
	transitions.append({"from":from,"to":place});return true

func walk_step(tile: Vector2i,stop_at_rival: bool=false) -> bool:
	var target:=Arena.tile_center(tile)
	if not check(Arena.resolve(target,game.world.player.radius).distance_to(target)<0.1,"Walkable review step "+str(tile)):return false
	var walker: Walker=game.world.player.controller
	walker.target=target;walker.active=true
	for tick in 240:
		game.advance(DT)
		if game.state=="warp":walker.active=false;return true
		if stop_at_rival and game.state=="rival":walker.active=false;return true
		if game.world.player.position.distance_to(target)<0.8:break
		if tick%5==0:await render()
	walker.active=false
	return check(game.world.player.position.distance_to(target)<0.8,"Walk reaches "+str(tile)+" actual "+str(game.world.player.position))

func run() -> void:
	await CaptureWindow.park(self)
	AudioServer.set_bus_mute(0,true)
	SaveData.path="user://save_rival_progression_review.cfg"
	OS.set_environment("BOT","0");OS.set_environment("GOD","1");OS.set_environment("SEED","17");OS.set_environment("LANG_CODE","ko")
	for stage in Story.Data.STAGES:
		print("Green review preparing: ",stage.id)
		SaveData.clear();Game.starter="charmander";Game.destination={};Game.carry={};Game.arena_trip={};Game.rival_leaving=""
		var place:=String(stage.map) if String(stage.map)!="" else "kanto_world"
		# Enter the original Silph room through its actual 3F teleport pad.
		OS.set_environment("DUNGEON","silph_co_3f" if stage.id=="silph" else place)
		game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game;configure()
		OS.set_environment("DUNGEON","")
		game.world.player.setup("raichu",80,Mon.TEAM_PLAYER)
		game.world.player.exp_total=SpeciesDB.exp_for_level(80,SpeciesDB.get_species("raichu").growth)
		game.beaten=[]
		if stage.rule=="all_leaders":
			for cfg in TrainerDB.GymData.GYMS.values():game.beaten.append(cfg.leader)
		if stage.id=="silph":
			game.world.player.position=Arena.tile_center(Vector2i(14,14));game.warp_armed=true;game._save_here()
			if not await walk_step(Vector2i(13,14)):quit(1);return
			if not check(game.state=="warp","Original Silph teleport activates"):quit(1);return
			if not await transition(place):quit(1);return
			var pad:=Vector2i(5,4)
			var arrival: Vector2i=pad+game._door_out_dir(pad) if game.mode=="overworld" else pad
			if not check(Arena.tile_of(game.world.player.position)==arrival,"Native Silph 7F arrival: "+str(game.world.player.position)):quit(1);return
			for tile in [Vector2i(4,5),Vector2i(3,5),Vector2i(2,5)]:
				if not await walk_step(tile,true):quit(1);return
		else:
			var region:=Arena.area_rect(stage.area)
			var start:=Vector2i(34,5) if stage.area=="route22" else Vector2i(16,8)
			var entry:=Vector2i(33,5) if stage.area=="route22" else Vector2i(17,8)
			game.world.player.position=Arena.tile_center(region.position+start);game.warp_armed=true;game._save_here()
			game.rival_progression.check();await shot(String(stage.id)+"_waiting")
			if not await walk_step(region.position+entry,true):quit(1);return
		if not check(game.state=="rival","Walk into Green's trigger: "+String(stage.id)):quit(1);return
		for tick in 2400:
			if game.state!="rival":break
			game.advance(DT)
			if tick%6==0:await render()
		if not check(game.state=="talk","Green reaches the player without crossing walls"):quit(1);return
		var id:=Story.trainer_id(stage.id,"charmander")
		var return_at: Vector2=game.world.player.position
		await shot(String(stage.id)+"_challenge");finish_talk()
		if not check(game.state=="encounter" and Game.arena_trip.trainer==id,"Correct Green encounter and starter branch"):quit(1);return
		if not await transition(stage.arena):quit(1);return
		var party: Array=TrainerDB.get_trainer(id).party
		var seen: Dictionary={};var last_mon:=0;var alive_t:=0.0;var ai_frames:=0
		for tick in 24000:
			if game.battle.is_empty():break
			if game.state=="talk" and game.can_advance():game._talk_next()
			game.advance(DT)
			if game.battle.has("mon") and is_instance_valid(game.battle.mon) and not game.battle.mon.dead and game.sendout.is_empty() and game.state=="fight":
				var mon: Enemy=game.battle.mon;var instance:=mon.get_instance_id()
				if instance!=last_mon:alive_t=0;last_mon=instance
				alive_t+=DT
				if mon.windup_t>0 or mon.attack_anim_t>0:ai_frames+=1
				if not seen.has(instance):
					if not check(mon.max_hp==int(SpeciesDB.stats_at(mon.species_id,mon.level,mon.ivs).hp) and game.world._damage_mult(mon)==1.0,"Full normal HP and outgoing damage"):quit(1);return
					seen[instance]={"species":mon.species_id,"level":mon.level,"hp":mon.max_hp,"ivs":mon.ivs}
					if seen.size()==1:await shot(String(stage.id)+"_battle")
				if alive_t>=4.0:game.world.damage(mon,mon.hp)
			if tick%6==0:await render()
		if not check(game.battle.is_empty() and game.beaten.has(id) and seen.size()==party.size() and ai_frames>0,"All party members, AI, and victory: "+String(stage.id)):quit(1);return
		if not check(SaveData.load_saved().trainers.has(id),"Green victory saved separately"):quit(1);return
		finish_talk()
		if not await transition(place):quit(1);return
		if not check(game.world.player.position.distance_to(return_at)<0.1,"Return to original challenge position"):quit(1);return
		if not check(game.state=="leave","Green departs after victory"):quit(1);return
		for tick in 2400:
			if game.state!="leave":break
			game.advance(DT)
			if tick%6==0:await render()
		if not check(game.rival_exit.is_empty() and game.state in ["fight","town"] and not game.rival_progression.check(),"Safe departure and no repeat encounter"):quit(1);return
		await shot(String(stage.id)+"_returned")
		results.append({"stage":stage.id,"trainer":id,"party":seen.values(),"ai_frames":ai_frames,"walked_into_trigger":true,"saved":true,"returned":true,"departure_finished":true,"does_not_repeat":true})
		print("Green native passed: ",stage.id," / ",seen.size()," party members")
		game.queue_free();await process_frame
	FileAccess.open(OUT+"native_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"window_size":DisplayServer.window_get_size(),"battles":results,"actual_scene_transitions":transitions,"validation":"Invulnerable non-attacking walker; real field walking, Silph 3F teleport, Green approach, cut-ins, full party sendout and normal AI, controlled defeat callbacks, saves, original-position returns, departure and no repeat. Human balance is not tested."},"  "))
	SaveData.clear();Game.destination={};Game.arena_trip={};Game.carry={};Game.rival_leaving=""
	quit(1 if failed else 0)
