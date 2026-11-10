extends SceneTree
const Game=preload("res://scripts/game.gd")
const Trial=preload("res://scripts/story/tower_brothers.gd")
const Data=Trial.Data
const OUT="res://docs/tower_brothers/"
const DT:=1.0/60.0
var game: Node
var failed := false
var transitions: Array=[]
var fights: Array=[]
var current_defeats: Dictionary={}

func record_defeat(enemy: Enemy,_exp: int) -> void:
	var id: String=enemy.get_meta("tower_double","")
	if not id.is_empty():current_defeats[id]=int(current_defeats.get(id,0))+1

class Still:
	extends RefCounted
	func move_dir(_w):return Vector2.ZERO
	func aim_point(w):return w.player.position+Vector2.UP*80.0
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func _init() -> void:call_deferred("run")

func check(ok: bool,message: String) -> bool:
	if not ok:
		failed=true;push_error(message)
	return ok

func configure() -> void:
	game.set_process(false);game.world.god=true
	game.world.player.controller=Still.new();game.banner_t=0.0
	check(DisplayServer.get_name()=="headless" or DisplayServer.window_get_size()==CaptureWindow.view_size(),"Native reviews must keep the minimum 1x window after every scene change")

func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	game._update_dialogue_focus()
	for i in 12:await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")

func finish_talk() -> void:
	for i in 60:
		if game.state!="talk":break
		game._talk_next()

func transition(place: String) -> bool:
	var previous=game
	var from:=DungeonDB.current
	for i in 500:
		if current_scene!=previous:break
		if is_instance_valid(previous) and previous.state=="encounter":previous.advance(DT)
		await create_timer(0.005).timeout
	if not check(current_scene!=previous,"A real scene reload must finish: "+from+" -> "+place):return false
	game=current_scene;configure()
	if not check(DungeonDB.current==place,"Expected actual destination "+place):return false
	transitions.append({"from":from,"to":DungeonDB.current})
	await process_frame
	return true

func run() -> void:
	await CaptureWindow.park(self)
	AudioServer.set_bus_mute(0,true)
	var start_floor:=maxi(2,int(OS.get_environment("TOWER_REVIEW_START")))
	SaveData.path="user://save_tower_brothers_review_%s_%d.cfg"%["headless" if DisplayServer.get_name()=="headless" else "native",start_floor]
	SaveData.clear()
	OS.set_environment("BOT","0");OS.set_environment("GOD","1");OS.set_environment("SEED","31")
	OS.set_environment("LANG_CODE","ko")
	Game.starter="charmander";Game.destination={};Game.carry={};Game.arena_trip={};Game.bot_events=[]
	for n in range(2,start_floor):SaveData.store_progress("events",Data.flag(n))
	var player:=Player.new();player.setup_player("charmeleon",25,["ember","flamethrower","metal_claw","scary_face"])
	var first_place:=Data.floor_id(1 if start_floor==2 else start_floor)
	SaveData.store(player,[],first_place,Vector2(17.5,10.5)*Arena.TILE);player.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	OS.set_environment("DUNGEON",first_place)
	game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game;configure()
	OS.set_environment("DUNGEON","")
	if DisplayServer.get_name()!="headless" and not check(game.view3d!=null,"Native 3D tower renderer is available"):quit(1);return
	if start_floor==2:
		game.dialog_text="";game.dialog_t=0.0
		await shot("01_lobby")
		var stair:=Arena.warp_tile(Data.floor_id(1),3)
		game.world.player.position=Arena.tile_center(stair);game.warp_armed=true;game._check_warp()
		if not await transition(Data.floor_id(2)):quit(1);return
	var initial_exp: int=game.world.player.exp_total
	var initial_pid: int=game.world.player.pid
	for floor_number in range(start_floor,8):
		print("Tower review: %dF introduction"%floor_number)
		if not check(game.state=="talk" and game.tower_brothers.floor_number==floor_number,"Arrival introduces each floor without walking"):quit(1);return
		if not check(game.world.npcs.is_empty() and game.trainers.is_empty() and game.world.remaining()==0,"No ordinary trainers or wild encounters on tower floors"):quit(1);return
		await shot("%df_intro"%floor_number)
		finish_talk()
		if not await transition(Data.ARENA):quit(1);return
		current_defeats={};game.world.enemy_defeated.connect(record_defeat)
		finish_talk()
		var seen: Dictionary={}
		var frame_index:=0
		var record_sequence: bool=OS.get_environment("TOWER_SEQUENCE_FRAMES")=="1" and floor_number==6 and DisplayServer.get_name()!="headless"
		if record_sequence:
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+"sequence_frames"))
			# A separate render texture gives a readable preview; the native window stays 384×216.
			game.view3d.vp.size=Vector2i(768,432)
		for i in 900:
			if game.tower_brothers.phase!="cloning":break
			game.advance(DT)
			var trial=game.tower_brothers
			var moment: String=trial.summon_step
			if moment=="double" and trial.summon_t>=trial.double_duration*0.4:
				var key: String=trial.active_brother+"_double"
				if not seen.has(key):
					seen[key]=true;await shot("%df_%s"%[floor_number,key])
			if moment=="spread" and trial.summon_t>=0.4:
				var key: String=trial.active_brother+"_spread"
				if not seen.has(key):
					seen[key]=true;await shot("%df_%s"%[floor_number,key])
			if moment=="hold" and not seen.has("formation"):
				seen.formation=true;await shot("%df_split"%floor_number)
			if record_sequence and i%3==0:
				await process_frame;await RenderingServer.frame_post_draw
				game.view3d.vp.get_texture().get_image().save_png(OUT+"sequence_frames/%04d.png"%frame_index);frame_index+=1
			elif i%3==0:await process_frame
		if record_sequence:game.view3d.vp.size=DisplayServer.window_get_size()
		if game.view3d!=null:
			for actor in game.tower_brothers.actors.values():
				var entry: Dictionary=game.view3d._sprites.get(actor.get_instance_id(),{})
				if entry.has("sprite") and not check(not entry.sprite.visible,"Hidden source actors must not add extra visible doubles"):quit(1);return
		for i in 900:
			if game.state!="tower_event":break
			game.advance(DT);await process_frame
		var initial: int=Data.BROTHERS[Data.STAGES[floor_number][0]].copies
		if not check(game.world.alive_enemies().size()==initial,"The first brother releases the full group on %dF"%floor_number):quit(1);return
		await shot("%df_copies"%floor_number)
		var positions: Array=[]
		for enemy in game.world.alive_enemies():
			positions.append([enemy.position.x,enemy.position.y])
		var action_frames:=0
		for i in 240:
			game.advance(DT)
			if i%60==0:print("Tower review: %dF AI tick %d, state %s"%[floor_number,i,game.state])
			var active: bool=game.world.alive_enemies().any(func(e):return e.windup_t>0 or e.attack_anim_t>0)
			if active or not game.world.projectiles.is_empty():action_frames+=1
			if i%6==0:await process_frame
		if not check(action_frames>0,"The copies really use attack AI on %dF"%floor_number):quit(1);return
		await shot("%df_combat"%floor_number)
		var intervention_action_frames:=0
		var intervention_shots: Dictionary={}
		for i in 12000:
			var trial=game.tower_brothers
			if trial.phase!="battle":break
			if not check(game.state=="fight" and not game.world.no_skills,"Interventions cannot freeze combat or block commands"):quit(1);return
			if not check(game.world.remaining()<=Data.count(floor_number),"No duplicate projections may exceed the planned total"):quit(1);return
			if trial.spawned and trial.summon_step=="done":
				if not check(game.world.remaining()==Data.count(floor_number) and game.defeated==0,"Timed reinforcements accumulate even without a single defeat"):quit(1);return
				for enemy in game.world.alive_enemies():
					if not check(enemy.max_hp==int(SpeciesDB.stats_at(enemy.species_id,enemy.level,enemy.ivs).hp) and enemy.hp==enemy.max_hp,"Every projection uses full original HP at its configured level"):quit(1);return
					for move_id in enemy.cds:
						if not check(float(game.world.make_hit(enemy,move_id).mult)==1.0,"Every original and intervention projection deals full damage"):quit(1);return
				await shot("%df_challenge"%floor_number)
				for enemy in game.world.alive_enemies():
					game.world.damage(enemy,enemy.hp)
			else:
				if game.world.alive_enemies().any(func(e):return e.windup_t>0 or e.attack_anim_t>0):intervention_action_frames+=1
				if trial.summon_step=="double" and trial.summon_t>trial.double_duration*0.3 and not intervention_shots.has(trial.active_brother):
					intervention_shots[trial.active_brother]=true
					await shot("%df_%s_intervention"%[floor_number,trial.active_brother])
			game.advance(DT)
			if i%6==0:await process_frame
		if Data.STAGES[floor_number].size()>1 and not check(intervention_action_frames>0,"The previous siblings keep attacking during intervention"):quit(1);return
		if not check(game.tower_brothers.created==Data.count(floor_number) and game.tower_brothers.peak_active==Data.count(floor_number),"The full challenge can accumulate without an artificial cap"):quit(1);return
		var joins: Array=game.tower_brothers.summon_log.filter(func(e):return e.event=="intervention")
		for i in joins.size():
			if not check(absf(float(joins[i].battle_time)-Data.INTERVENTION_INTERVAL*float(i+1))<=DT*1.1,"Reinforcements follow the fixed combat clock"):quit(1);return
		for id in Data.STAGES[floor_number]:
			if not check(int(current_defeats.get(id,0))==int(Data.BROTHERS[id].copies),"Correct total copies for sibling "+id):quit(1);return
		if not check(game.events.has(Data.flag(floor_number)),"Victory recorded after the full formation"):quit(1);return
		var next:=floor_number+1 if floor_number<7 else 1
		if not check(SaveData.load_saved().map==Data.floor_id(next),"Victory checkpoints the next floor before dialogue"):quit(1);return
		for i in 60:
			if game.state!="tower_event":break
			game.advance(DT);await process_frame
		if not check(game.state=="talk","The brothers speak after defeat"):quit(1);return
		await shot("%df_defeat"%floor_number)
		fights.append({"floor":floor_number,"count":Data.count(floor_number),"brothers":current_defeats.duplicate(),"initial_positions":positions,"ai_action_frames":action_frames,"intervention_action_frames":intervention_action_frames,
			"peak_active":game.tower_brothers.peak_active,"summoning":game.tower_brothers.summon_log,
			"defeated":game.defeated,"next_checkpoint":SaveData.load_saved().map})
		finish_talk()
		if not await transition(Data.floor_id(next)):quit(1);return
	var expected_fights:=8-start_floor
	if not check(transitions.size()==expected_fights*2+(1 if start_floor==2 else 0) and fights.size()==expected_fights,"The entire requested chain completed through real transitions"):quit(1);return
	if not check(game.events.has(Data.COMPLETE) and game.world.player.exp_total==initial_exp and game.world.player.pid==initial_pid,"Completion preserves identity and grants no projection EXP"):quit(1);return
	await shot("08_complete_lobby")
	var defeats:=0
	for fight in fights:defeats+=int(fight.count)
	var brother_stats: Dictionary={}
	for id in Data.BROTHERS:
		var cfg: Dictionary=Data.BROTHERS[id]
		brother_stats[id]={"species":cfg.species,"level":cfg.level,"copies":cfg.copies,"hp":SpeciesDB.stats_at(cfg.species,int(cfg.level)).hp}
	var report={"actual_scene_transitions":transitions,"battles":fights,"complete":game.events.has(Data.COMPLETE),"exp_before":initial_exp,"exp_after":game.world.player.exp_total,
		"brother_stats":brother_stats,"event_hp_multiplier":1.0,"event_damage_multiplier":1.0,
		"defeats":defeats,"window_size":DisplayServer.window_get_size(),"sequential_summoning":true,"combat_interventions":true,"intervention_interval":Data.INTERVENTION_INTERVAL,"artificial_active_cap":false,"formation":"shallow fan",
		"combat_validation":"No projections are defeated until every timed brother has joined; real AI continues during interventions; normal damage callbacks then complete the stage","passed":not failed}
	var report_name:="checks" if DisplayServer.get_name()!="headless" and start_floor==2 else ("headless_checks" if DisplayServer.get_name()=="headless" else "partial_checks")
	FileAccess.open(OUT+report_name+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("Tower brothers: %d formations, %d copies, %d actual scene transitions, AI, dialogue and persistence passed"%[fights.size(),defeats,transitions.size()])
	quit(1 if failed else 0)
