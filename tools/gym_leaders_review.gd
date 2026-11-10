extends SceneTree

const Game=preload("res://scripts/game.gd")
const Data=preload("res://scripts/data/gym_leaders.gd")
const OUT="res://docs/gym_leaders/"
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
	check(DisplayServer.get_name()=="headless" or DisplayServer.window_get_size()==CaptureWindow.view_size(),"Every scene stays at the minimum 1x test window")

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
	transitions.append({"from":from,"to":place})
	return true

func route(goal: Vector2i) -> Array:
	var occupied: Dictionary={}
	for n in game.world.npcs:occupied[Arena.tile_of(n.position)]=true
	var start:=Arena.tile_of(game.world.player.position)
	var queue: Array[Vector2i]=[start];var parents: Dictionary={start:{"from":start,"step":start}};var cursor:=0
	while cursor<queue.size() and not parents.has(goal):
		var cell: Vector2i=queue[cursor];cursor+=1
		var options: Array[Vector2i]=[]
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:options.append(cell+d)
		for tile in options:
			if occupied.has(tile) or Arena.solid_at(tile.x,tile.y):continue
			var at:=Arena.tile_center(tile)
			if Arena.resolve(at,game.world.player.radius).distance_to(at)>0.1:continue
			var door:=Arena.warp_at(at)
			if not door.is_empty() and DungeonDB.warp_destination(door)!=DungeonDB.current:continue
			var arrival:=tile
			if not door.is_empty():arrival=Arena.warp_tile(String(door.to),int(door.to_warp))
			if parents.has(arrival):continue
			parents[arrival]={"from":cell,"step":tile};queue.append(arrival)
	var path: Array=[]
	if not parents.has(goal):return path
	var cell:=goal
	while cell!=start:
		path.push_front({"step":parents[cell].step,"arrival":cell});cell=parents[cell].from
	return path

func walk_to(goal: Vector2i) -> bool:
	var place:=DungeonDB.current;var path:=route(goal)
	if not check(not path.is_empty() or Arena.tile_of(game.world.player.position)==goal,"Walkable gym route to "+str(goal)+" in "+place):return false
	for action in path:
		var tile: Vector2i=action.step
		if Arena.tile_of(game.world.player.position)==tile and game.world.player.position.distance_to(Arena.tile_center(tile))<1.0:continue
		var walker: Walker=game.world.player.controller
		walker.target=Arena.tile_center(tile);walker.active=true
		var warped:=false
		for tick in 240:
			game.advance(DT)
			if game.state=="warp":
				if not await transition(place):return false
				if not check(Arena.tile_of(game.world.player.position)==Vector2i(action.arrival),"Warp arrives at its native target"):return false
				warped=true;break
			if game.world.player.position.distance_to(walker.target)<0.8:break
			if tick%5==0:await render()
		if not warped and not check(game.world.player.position.distance_to(walker.target)<0.8,"Movement to %s in %s; actual %s, target %s, radius %s"%[tile,place,game.world.player.position,walker.target,game.world.player.radius]):return false
		if not warped and not check(Vector2i(action.arrival)==tile,"Stepping onto the pad must trigger its warp"):return false
	(game.world.player.controller as Walker).active=false
	return check(Arena.tile_of(game.world.player.position)==goal,"Reached conversation %s; actual %s at %s in %s"%[goal,Arena.tile_of(game.world.player.position),game.world.player.position,place])

func run() -> void:
	await CaptureWindow.park(self)
	AudioServer.set_bus_mute(0,true)
	SaveData.path="user://save_all_gym_leaders_review.cfg"
	OS.set_environment("BOT","0");OS.set_environment("GOD","1");OS.set_environment("SEED","17");OS.set_environment("LANG_CODE","ko")
	for place in Data.GYMS:
		if OS.get_environment("GYM_REVIEW_ONLY")!="" and place!=OS.get_environment("GYM_REVIEW_ONLY"):continue
		var cfg: Dictionary=Data.GYMS[place];var slug: String=cfg.slug
		print("Gym review preparing: ",place)
		SaveData.clear();Game.starter="charmander";Game.destination={};Game.carry={};Game.arena_trip={}
		OS.set_environment("DUNGEON",place)
		game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game;configure()
		OS.set_environment("DUNGEON","")
		game.world.player.setup("raichu",80,Mon.TEAM_PLAYER)
		game.world.player.exp_total=SpeciesDB.exp_for_level(80,SpeciesDB.get_species("raichu").growth)
		var entrance: Dictionary=Arena.warps()[0]
		game.world.player.position=Arena.tile_center(Vector2i(int(entrance.x),int(entrance.y)-1))
		game.warp_armed=true;game._save_here()
		var member_id:="";var member_tile:=Vector2i.ZERO
		for n in game.world.npcs:
			if Data.NPC_PARTIES.has(n.id):member_id=n.id;member_tile=n.talk_tile;break
		if not check(member_id!="","Gym has ordinary dialogue members"):quit(1);return
		if not await walk_to(member_tile):quit(1);return
		var member: Npc=game.npc_in_reach()
		if not check(member!=null and member.id==member_id,"Normal interaction selects the member"):quit(1);return
		game._talk(member);await shot(slug+"_member");finish_talk()
		if not check(game.state=="town" and game.battle.is_empty() and Game.arena_trip.is_empty(),"Talking to a gym member cannot start combat"):quit(1);return
		var leader_tile: Vector2i=Data.PLACE_OVERRIDES[place].trainers[0].tile+Vector2i.DOWN
		if not await walk_to(leader_tile):quit(1);return
		var lead: Npc=game.npc_in_reach()
		if not check(lead!=null and lead.trainer_id==cfg.leader,"Normal interaction selects the leader"):quit(1);return
		var return_at: Vector2=game.world.player.position
		game._talk(lead);await shot(slug+"_challenge");finish_talk()
		if not check(game.state=="encounter" and game.encounter.kind=="leader","Leader cut-in starts only after speaking"):quit(1);return
		game.advance(0.65);await shot(slug+"_cutin")
		if not await transition(cfg.arena):quit(1);return
		var party: Array=TrainerDB.get_trainer(cfg.leader).party
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
					if not check(mon.max_hp==int(SpeciesDB.stats_at(mon.species_id,mon.level,mon.ivs).hp) and game.world._damage_mult(mon)==1.0,"Full original HP and damage"):quit(1);return
					seen[instance]={"species":mon.species_id,"level":mon.level,"hp":mon.max_hp,"ivs":mon.ivs}
					await shot(slug+"_party_%d"%seen.size())
				if alive_t>=4.0:game.world.damage(mon,mon.hp)
			if tick%6==0:await render()
		if not check(game.battle.is_empty() and game.beaten.has(cfg.leader) and seen.size()==party.size() and ai_frames>0,"Complete leader party and victory: "+slug):quit(1);return
		if not check(SaveData.load_saved().trainers.has(cfg.leader),"Victory saved"):quit(1);return
		await shot(slug+"_victory");finish_talk()
		if not await transition(place):quit(1);return
		if not check(game.world.player.position.distance_to(return_at)<0.1,"Battle returns to the challenge position"):quit(1);return
		for n in game.world.npcs:
			if Data.NPC_PARTIES.has(n.id) and not check(not n.is_trainer() and not game.beaten.has(n.id),"Members remain noncombat after leader victory"):quit(1);return
		game._talk(game.trainers[0]);await shot(slug+"_returned");finish_talk()
		if not check(game.battle.is_empty() and Game.arena_trip.is_empty(),"Speaking to a defeated leader does not restart combat"):quit(1);return
		results.append({"gym":place,"leader":cfg.leader,"party":seen.values(),"ai_frames":ai_frames,"member_dialogue_only":true,"walked_from_entrance":true,"saved":true,"returned":true})
		print("Gym native passed: ",slug," / ",seen.size()," party members")
		game.queue_free();await process_frame
	var report_name:="native_checks" if OS.get_environment("GYM_REVIEW_ONLY")=="" else "partial_checks"
	FileAccess.open(OUT+report_name+".json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"window_size":DisplayServer.window_get_size(),"battles":results,"actual_scene_transitions":transitions,"validation":"Invulnerable non-attacking walker. Real walking, maze/warp traversal, normal dialogue, cut-ins, full party sendouts and AI, controlled defeat callbacks, rewards, saves and scene reloads. Human balance is not tested."},"  "))
	SaveData.clear();Game.destination={};Game.arena_trip={};Game.carry={}
	quit(1 if failed else 0)
