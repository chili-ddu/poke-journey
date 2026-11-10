extends SceneTree

const Game=preload("res://scripts/game.gd")
const Data=preload("res://scripts/data/road_trainer_db.gd")
const Search=preload("res://scripts/battle/trainer_search.gd")
const OUT="res://docs/road_trainers/"
const DT=1.0/60.0
var game: Node
var failed:=false
var transitions: Array=[]
var results: Array=[]

class Still:
	extends RefCounted
	func move_dir(_w):return Vector2.ZERO
	func aim_point(w):return w.player.position+Vector2.UP*80
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func _init() -> void:call_deferred("run")

func check(ok: bool,message: String) -> bool:
	if not ok:failed=true;push_error(message)
	return ok

func configure() -> void:
	game.set_process(false);game.bot=false;game.world.god=true;game.banner_t=0
	game.world.player.controller=Still.new()
	if game.view3d!=null:game.view3d.set_process(false)
	check(DisplayServer.get_name()=="headless" or DisplayServer.window_get_size()==CaptureWindow.view_size(),"Every scene uses the minimum 1x test window")

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
	for i in 60:
		if game.state!="talk" or not game.can_advance():break
		game._talk_next()

func transition(place: String) -> bool:
	var previous=game;var from:=DungeonDB.current
	for i in 700:
		if current_scene!=previous:break
		if is_instance_valid(previous) and previous.state=="encounter":previous.advance(DT)
		await create_timer(0.005).timeout
	if not check(current_scene!=previous,"Real scene reload: "+from+" -> "+place):return false
	game=current_scene;configure()
	if not check(DungeonDB.current==place,"Destination: "+place):return false
	transitions.append({"from":from,"to":place})
	return not failed

func spawn(id: String,area: String,terrain: int):
	var driver=Search.new();driver.area=area;driver.terrain=terrain
	var bounds:=Arena.area_rect(area)
	var options: Array[Vector2i]=[]
	for y in range(bounds.position.y+1,bounds.end.y-1,3):
		for x in range(bounds.position.x+1,bounds.end.x-1,3):
			var tile:=Vector2i(x,y)
			if driver.walkable(tile) and Arena.area_at(Arena.tile_center(tile))==area:options.append(tile)
	options.sort_custom(func(a,b):return Vector2(a).distance_squared_to(bounds.get_center())<Vector2(b).distance_squared_to(bounds.get_center()))
	var excluded: Array=Data.POOLS[area].filter(func(other):return other!=id)
	for tile in options.slice(0,50):
		game.world.player.position=Arena.tile_center(tile);game.world.player.travel_terrain=2 if terrain==1 else 0
		game._set_cam(game.world.player.position,World.CAM_ZOOM)
		for i in 4:
			game.advance(DT);await render()
		if driver.spawn(game.world,game.view3d,excluded):return driver
	return null

func run() -> void:
	await CaptureWindow.park(self)
	AudioServer.set_bus_mute(0,true)
	SaveData.path="user://save_mainland_road_trainers_review.cfg"
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","11");OS.set_environment("LANG_CODE","ko")
	var fixtures: Array=[
		["route8","road8_little_girl_eli"], ["route10","road10_poke_maniac_herman"],
		["route12","road12_fisher_ned"], ["route17",Data.POOLS.route17[0]],
		["route15","road15_black_belt_ron"], ["route19","road19_swimmer_f_water_lia"],
		["route21_north","road21_north_swimmer_f_water_lil"]]
	for fixture in fixtures:
		var area: String=fixture[0];var id: String=fixture[1];var tr: Dictionary=TrainerDB.get_trainer(id)
		var terrain:=int(tr.terrain)
		SaveData.clear();Game.starter="charmander";Game.carry={};Game.arena_trip={};Game.destination={}
		Game.bot_events=[Game.LaprasEscape.FRIEND]
		OS.set_environment("DUNGEON","kanto_world")
		game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game;configure()
		OS.set_environment("DUNGEON","")
		game.world.player.setup("raichu",50,Mon.TEAM_PLAYER)
		game.world.player.exp_total=SpeciesDB.exp_for_level(50,SpeciesDB.get_species("raichu").growth)
		var driver=await spawn(id,area,terrain)
		if not check(driver!=null,"Native offscreen connected search: "+area):quit(1);return
		if not check(not driver.visible_at(game.world,game.view3d,driver.actor.position),"The trainer really enters offscreen"):quit(1);return
		var return_at: Vector2=game.world.player.position
		game.road_pursuit.sync_visit(area);game.road_pursuit.terrain=terrain
		game.road_pursuit.pursuits.append(driver);game.road_pursuit.deployed.append(id)
		var goal: Vector2i=driver.player_cell(game.world)
		if not driver.walkable(goal):goal=Arena.tile_of(return_at)
		var path: Array=driver.route(Arena.tile_of(driver.actor.position),goal)
		if not check(not path.is_empty(),"Trainer has a real route to the player"):quit(1);return
		for tile in path:
			driver.actor.walk_target=Arena.tile_center(tile);driver.actor.face_toward(driver.actor.walk_target)
			for tick in 50:
				game.world.step_visual(DT)
				if tick%4==0:await render()
				if not driver.actor.walking():break
			if driver.detects(game.world):break
		if not check(driver.step(game.world,game.view3d,0.0,[],false)==driver.actor,"Search discovers the player through normal detection"):quit(1);return
		game._start_intro(driver.actor)
		await shot(area+"_field")
		finish_talk()
		if not await transition("arena_route1"):quit(1);return
		await shot(area+"_intro")
		if tr.has("partner_sprite") and not check(game.arena_trainer.has_meta("trainer_partner"),"Paired trainer has two people in the arena"):quit(1);return
		var seen: Dictionary={};var ai_frames:=0;var alive_t:=0.0;var last_mon:=0
		for tick in 18000:
			if game.battle.is_empty():break
			if game.state=="talk" and game.can_advance():game._talk_next()
			game.advance(DT)
			if game.battle.has("mon") and is_instance_valid(game.battle.mon) and not game.battle.mon.dead and game.sendout.is_empty() and game.state=="fight":
				var mon: Enemy=game.battle.mon;var instance:=mon.get_instance_id()
				if instance!=last_mon:alive_t=0;last_mon=instance
				alive_t+=DT
				if mon.windup_t>0 or mon.attack_anim_t>0:ai_frames+=1
				if not seen.has(instance):
					if not check(mon.max_hp==int(SpeciesDB.stats_at(mon.species_id,mon.level,mon.ivs).hp) and game.world._damage_mult(mon)==1.0,"Original HP and damage in the actual battle"):quit(1);return
					seen[instance]={"species":mon.species_id,"level":mon.level,"hp":mon.max_hp,"ivs":mon.ivs}
					await shot(area+"_party_%d"%seen.size())
				if alive_t>=4.0:game.world.damage(mon,mon.hp)
			if tick%6==0:await render()
		if not check(game.battle.is_empty() and game.beaten.has(id) and seen.size()==tr.party.size() and ai_frames>0,"Full party battle and victory: "+id):quit(1);return
		if not check(SaveData.load_saved().trainers.has(id),"Victory is persisted"):quit(1);return
		await shot(area+"_victory")
		finish_talk()
		if not await transition("kanto_world"):quit(1);return
		for i in 15:game.advance(DT);await render()
		if not check(game.world.player.position.distance_to(return_at)<0.1,"Battle returns to the original road position"):quit(1);return
		if terrain==1 and not check(game.world.player.travel_terrain==2 and is_instance_valid(game.lapras_escape.helper),"Water return restores surfing and the Lapras mount"):quit(1);return
		await shot(area+"_returned")
		results.append({"area":area,"trainer":id,"terrain":terrain,"party":seen.values(),"ai_frames":ai_frames,"saved":true,"returned":true})
		print("Road native passed: ",area," / ",id," / ",seen.size()," party members")
		game.queue_free();await process_frame
	FileAccess.open(OUT+"native_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"window_size":DisplayServer.window_get_size(),"battles":results,"actual_scene_transitions":transitions,"validation":"Invulnerable idle player; normal AI, party sendouts, damage defeat callbacks, rewards, persistence, and real scene reloads. Human balance is not tested."},"  "))
	SaveData.clear();Game.arena_trip={};Game.destination={};Game.carry={}
	quit(1 if failed else 0)
