extends "res://tools/gym_leaders_review.gd"
const TRAINING_OUT="res://docs/brock_training/"
var cases: Array=[]

func shot(name: String) -> void:
	game._update_dialogue_focus()
	for i in 8:await render()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(TRAINING_OUT+name+".png")

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TRAINING_OUT))
	SaveData.path="user://save_brock_training_review.cfg"
	OS.set_environment("BOT","0");OS.set_environment("GOD","1");OS.set_environment("SEED","17")
	for level in [12,40]:
		SaveData.clear();Game.starter="charmander";Game.bot_beaten=[];Game.bot_events=[]
		Game.destination={};Game.carry={};Game.arena_trip={}
		OS.set_environment("DUNGEON","pewter_gym")
		game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game;configure()
		OS.set_environment("DUNGEON","")
		var p: Player=game.world.player
		p.set_level(level,true);p.exp_total=SpeciesDB.exp_for_level(level,SpeciesDB.growth_of(p.species_id))
		var leader: Npc=game.trainers[0]
		p.position=Arena.tile_center(leader.tile+Vector2i.DOWN);p.facing=Vector2.UP
		game.world.cam.position=p.position;game.view3d._cam_ready=false
		game.dialog_text="";game.dialog_t=0;game._save_here()
		var return_at:=p.position;var experience:=p.exp_total
		assert(game.npc_in_reach()==leader)
		var key:=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true
		game._unhandled_input(key)
		var training_seen:=false
		for i in 40:
			if game.state!="talk":break
			if game.dialog_text.contains("투구와 프테라"):
				training_seen=true;await shot("lv%d_training_partners"%level)
			game._talk_next()
		assert(training_seen and game.state=="encounter")
		var expected:=TrainerDB.for_battle("leader_brock",level)
		assert(Game.arena_trip.roster==expected and expected.party.size()==4)
		if not await transition("arena_pewter_gym"):quit(1);return
		assert(game.battle_trainer()==expected)
		var seen: Array=[];var last_mon:=0;var alive_time:=0.0;var active_frames:=0
		for tick in 12000:
			if game.battle.is_empty():break
			if game.state=="talk" and game.can_advance():game._talk_next()
			game.advance(DT)
			if game.battle.has("mon") and is_instance_valid(game.battle.mon) and not game.battle.mon.dead and game.sendout.is_empty() and game.state=="fight":
				var mon: Enemy=game.battle.mon
				if mon.get_instance_id()!=last_mon:
					last_mon=mon.get_instance_id();alive_time=0.0
					var row: Array=expected.party[seen.size()]
					assert(mon.species_id==row[0] and mon.level==int(row[1]))
					assert(mon.max_hp==int(SpeciesDB.stats_at(mon.species_id,mon.level,mon.ivs).hp))
					assert(game.world._damage_mult(mon)==1.0 and game.world.exp_gain(mon)==0)
					seen.append({"species":mon.species_id,"level":mon.level,"moves":mon.cds.keys(),"hp":mon.max_hp})
					await shot("lv%d_party_%d_%s"%[level,seen.size(),mon.species_id])
				alive_time+=DT
				if mon.windup_t>0.0 or mon.attack_anim_t>0.0:active_frames+=1
				if alive_time>=2.0:game.world.damage(mon,mon.hp)
			if tick%6==0:await render()
		assert(seen.size()==4 and game.battle.is_empty() and game.beaten.has("leader_brock"))
		assert(game.world.player.exp_total==experience and active_frames>0)
		await shot("lv%d_victory"%level);finish_talk()
		if not await transition("pewter_gym"):quit(1);return
		assert(game.world.player.position.distance_to(return_at)<0.1)
		assert(SaveData.load_saved().trainers.has("leader_brock") and SaveData.load_saved().exp==experience)
		game._talk(game.trainers[0]);finish_talk()
		assert(game.battle.is_empty() and Game.arena_trip.is_empty())
		cases.append({"player_level":level,"party":seen,"normal_stats":true,"exp_gain":0,"training_dialogue":true,"saved":true,"returned":true,"ai_frames":active_frames})
		game.queue_free();await process_frame
	assert(DisplayServer.window_get_size()==Vector2i(384,216))
	FileAccess.open(TRAINING_OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"window":"384x216","cases":cases,"actual_scene_transitions":transitions,"validation":"Normal interaction, actual arena and return, all four sendouts and AI; controlled damage through ordinary faint callbacks. Human difficulty not tested."},"  "))
	SaveData.clear();Game.destination={};Game.carry={};Game.arena_trip={}
	print("Brock training party: two challenge levels, eight sendouts, normal stats, zero EXP and four actual scene transitions passed")
	quit()
