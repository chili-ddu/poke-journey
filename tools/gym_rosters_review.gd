extends "res://tools/gym_leaders_review.gd"
const REVIEW_OUT="res://docs/gym_rosters/"
const CASES=[
	["cerulean_city_gym",12],["cerulean_city_gym",55],
	["vermilion_city_gym",12],["vermilion_city_gym",55],
	["celadon_city_gym",12],["celadon_city_gym",55],
	["fuchsia_city_gym",12],["fuchsia_city_gym",55],
	["saffron_city_gym",12],["saffron_city_gym",55],
	["cinnabar_island_gym",12],["cinnabar_island_gym",55],
	["viridian_city_gym",12],["viridian_city_gym",55]]
var reports: Array=[]

func shot(name: String) -> void:
	game._update_dialogue_focus()
	for i in 8:await render()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(REVIEW_OUT+name+".png")

func run() -> void:
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_OUT))
	SaveData.path="user://save_gym_rosters_review.cfg"
	OS.set_environment("BOT","0");OS.set_environment("GOD","1");OS.set_environment("SEED","17")
	for sample in CASES:
		var place: String=sample[0];var level: int=sample[1]
		var cfg: Dictionary=Data.GYMS[place];var label:="%s_lv%d"%[cfg.slug,level]
		print("Roster review: ",label)
		SaveData.clear();Game.starter="charmander";Game.bot_beaten=[];Game.bot_events=[]
		Game.destination={};Game.carry={};Game.arena_trip={}
		OS.set_environment("DUNGEON",place)
		game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game;configure()
		OS.set_environment("DUNGEON","")
		var p: Player=game.world.player
		p.set_level(level,true);p.exp_total=SpeciesDB.exp_for_level(level,SpeciesDB.growth_of(p.species_id))
		var lead: Npc=game.trainers[0]
		p.position=Arena.tile_center(lead.tile+Vector2i.DOWN);p.facing=Vector2.UP
		game.world.cam.position=p.position;game.view3d._cam_ready=false
		game.dialog_text="";game.dialog_t=0;game._save_here()
		var return_at:=p.position;var experience:=p.exp_total
		assert(game.npc_in_reach()==lead)
		var key:=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true
		game._unhandled_input(key);await shot(label+"_challenge");finish_talk()
		var expected:=TrainerDB.for_battle(cfg.leader,level)
		assert(game.state=="encounter" and Game.arena_trip.roster==expected)
		assert(expected.party.size()==(5 if cfg.leader=="leader_giovanni" else 4))
		if not await transition(cfg.arena):quit(1);return
		assert(game.battle_trainer()==expected)
		var seen: Array=[];var last_mon:=0;var alive_time:=0.0
		for tick in 16000:
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
					await shot(label+"_party_%d_%s"%[seen.size(),mon.species_id])
				alive_time+=DT
				if alive_time>=2.0:game.world.damage(mon,mon.hp)
			if tick%6==0:await render()
		assert(seen.size()==expected.party.size() and game.beaten.has(cfg.leader))
		assert(game.world.player.exp_total==experience)
		await shot(label+"_victory");finish_talk()
		if not await transition(place):quit(1);return
		assert(game.world.player.position.distance_to(return_at)<0.1)
		assert(SaveData.load_saved().trainers.has(cfg.leader) and SaveData.load_saved().exp==experience)
		if cfg.leader in Game.GymFieldFriends.REWARDS:
			var move: String=Game.GymFieldFriends.REWARDS[cfg.leader].move
			assert(game.events.has(Game.FieldHMs.SOURCES[move]))
		game._talk(game.trainers[0]);finish_talk()
		assert(game.battle.is_empty() and Game.arena_trip.is_empty())
		reports.append({"gym":place,"leader":cfg.leader,"player_level":level,"party":seen,"exp_gain":0,"normal_stats":true,"snapshot":true,"saved":true,"returned":true})
		game.queue_free();await process_frame
	assert(DisplayServer.window_get_size()==Vector2i(384,216))
	FileAccess.open(REVIEW_OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"window":"384x216","battles":reports,"actual_scene_transitions":transitions,"validation":"Normal Space interaction, full party sendouts, actual arena and return, and controlled defeats through normal damage/faint callbacks. Existing gym navigation and human difficulty not tested."},"  "))
	SaveData.clear();Game.destination={};Game.carry={};Game.arena_trip={}
	print("Gym rosters: fourteen battles, 58 sendouts, 28 real scene transitions; normal stats, zero EXP, victory and field rewards passed")
	quit()
