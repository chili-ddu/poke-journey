extends "res://tools/gym_leaders_review.gd"

const GROWTH_OUT="res://docs/gym_growth/"
const CASES=[
	["pewter_gym",5],["pewter_gym",30],["cerulean_city_gym",10],
	["vermilion_city_gym",25],["celadon_city_gym",12],["fuchsia_city_gym",32],
	["saffron_city_gym",5],["cinnabar_island_gym",40],["viridian_city_gym",40]]

func shot(name: String) -> void:
	if DisplayServer.get_name()=="headless":return
	game._update_dialogue_focus()
	for i in 8:await render()
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(GROWTH_OUT+name+".png")

func run() -> void:
	await CaptureWindow.park(self)
	AudioServer.set_bus_mute(0,true)
	SaveData.path="user://save_gym_growth_review.cfg"
	OS.set_environment("BOT","0");OS.set_environment("GOD","1");OS.set_environment("SEED","17");OS.set_environment("LANG_CODE","ko")
	for sample in CASES:
		var place:=String(sample[0]);var level:=int(sample[1]);var cfg: Dictionary=Data.GYMS[place]
		var slug:=String(cfg.slug)+"_lv%d"%level
		print("Growing gym preparing: ",slug)
		SaveData.clear();Game.starter="charmander";Game.destination={};Game.carry={};Game.arena_trip={}
		OS.set_environment("DUNGEON",place)
		game=load("res://scenes/main.tscn").instantiate();root.add_child(game);current_scene=game;configure()
		OS.set_environment("DUNGEON","")
		game.world.player.setup("raichu",level,Mon.TEAM_PLAYER)
		game.world.player.exp_total=SpeciesDB.exp_for_level(level,SpeciesDB.get_species("raichu").growth)
		var entrance: Dictionary=Arena.warps()[0]
		game.world.player.position=Arena.tile_center(Vector2i(int(entrance.x),int(entrance.y)-1))
		game.warp_armed=true;game._save_here()
		var member: Npc
		for n in game.world.npcs:
			if Data.NPC_PARTIES.has(n.id):member=n;break
		if not check(member!=null,"Gym has a dialogue-only member"):quit(1);return
		if not await walk_to(member.talk_tile):quit(1);return
		game._talk(game.npc_in_reach());finish_talk()
		if not check(game.state=="town" and game.battle.is_empty(),"Members remain noncombat"):quit(1);return
		var leader_tile: Vector2i=Data.PLACE_OVERRIDES[place].trainers[0].tile+Vector2i.DOWN
		if not await walk_to(leader_tile):quit(1);return
		var lead: Npc=game.npc_in_reach()
		if not check(lead!=null and lead.trainer_id==cfg.leader,"Normal interaction selects the leader"):quit(1);return
		var return_at: Vector2=game.world.player.position
		var initial_exp: int=game.world.player.exp_total
		game._talk(lead);finish_talk()
		var expected:=TrainerDB.for_battle(cfg.leader,level)
		if not check(game.state=="encounter" and game.encounter.kind=="leader" and Game.arena_trip.roster==expected,"Challenge snapshots this player's level"):quit(1);return
		game.advance(0.65);await shot(slug+"_cutin")
		if not await transition(cfg.arena):quit(1);return
		if not check(game.battle_trainer()==expected,"Snapshot survives the actual arena reload"):quit(1);return
		var seen: Array=[];var last_mon:=0;var alive_t:=0.0;var ai_frames:=0
		for tick in 30000:
			if game.battle.is_empty():break
			if game.state=="talk" and game.can_advance():game._talk_next()
			game.advance(DT)
			if game.battle.has("mon") and is_instance_valid(game.battle.mon) and not game.battle.mon.dead and game.sendout.is_empty() and game.state=="fight":
				var mon: Enemy=game.battle.mon;var instance:=mon.get_instance_id()
				if instance!=last_mon:
					alive_t=0;last_mon=instance
					var row: Array=expected.party[seen.size()]
					if not check(mon.species_id==row[0] and mon.level==int(row[1]) and mon.cds.keys()==row[2],"Correct level, evolution and learned moves: "+slug):quit(1);return
					if not check(mon.max_hp==int(SpeciesDB.stats_at(mon.species_id,mon.level,mon.ivs).hp) and game.world._damage_mult(mon)==1.0,"Normal HP and damage"):quit(1);return
					if not check(game.world.exp_gain(mon)==0,"Gym members award zero EXP"):quit(1);return
					seen.append({"species":mon.species_id,"level":mon.level,"moves":mon.cds.keys(),"hp":mon.max_hp})
					await shot(slug+"_party_%d"%seen.size())
				alive_t+=DT
				if mon.windup_t>0 or mon.attack_anim_t>0:ai_frames+=1
				if alive_t>=4.0:game.world.damage(mon,mon.hp)
			if tick%6==0:await render()
		if not check(game.battle.is_empty() and game.beaten.has(cfg.leader) and seen.size()==expected.party.size() and ai_frames>0,"Complete scaled party and victory: "+slug):quit(1);return
		if not check(SaveData.load_saved().trainers.has(cfg.leader),"Victory saved"):quit(1);return
		if not check(game.world.player.level==level and game.world.player.exp_total==initial_exp and not game.exp_display_pending() and game.stat_queue.is_empty(),"Full gym party gives no EXP, gauge animation or level-ups"):quit(1);return
		finish_talk()
		if not await transition(place):quit(1);return
		if not check(game.world.player.position.distance_to(return_at)<0.1,"Return to original challenge position"):quit(1);return
		if not check(SaveData.load_saved().exp==initial_exp,"Returned save preserves the exact starting EXP"):quit(1);return
		for n in game.world.npcs:
			if n.talk in ["gym_member","gym_surprised"] and not check(not n.is_trainer(),"Members remain dialogue-only"):quit(1);return
		game._talk(game.trainers[0]);finish_talk()
		if not check(game.battle.is_empty() and Game.arena_trip.is_empty(),"Defeated leader does not repeat"):quit(1);return
		results.append({"gym":place,"leader":cfg.leader,"reference_level":level,"player_level_after_battle":game.world.player.level,"experience_gained":game.world.player.exp_total-initial_exp,"party":seen,"ai_frames":ai_frames,"snapshot_survived_arena_reload":true,"walked_from_entrance":true,"saved":true,"returned":true})
		print("Growing gym native passed: ",slug," / ",seen.size()," members; EXP gained 0")
		game.queue_free();await process_frame
	FileAccess.open(GROWTH_OUT+"native_checks.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":not failed,"window_size":DisplayServer.window_get_size(),"battles":results,"actual_scene_transitions":transitions,"validation":"Invulnerable non-attacking walker. Actual maze/warp traversal, member dialogue, leader cut-ins, per-challenge scaled/evolved parties, normal AI and damage, controlled defeat callbacks, zero EXP throughout each gym party and in returned saves. Human difficulty is not tested."},"  "))
	SaveData.clear();Game.destination={};Game.arena_trip={};Game.carry={}
	quit(1 if failed else 0)
