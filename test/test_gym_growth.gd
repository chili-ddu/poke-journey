extends GutTest

const Game=preload("res://scripts/game.gd")
const Growth=TrainerDB.GymGrowth
const Data=Growth.Data
const DT=1.0/60.0
const PATH="user://save_gym_growth_test.cfg"
var previous_path: String
var previous_events: Array
var previous_beaten: Array

class Still:
	extends RefCounted
	func move_dir(_w):return Vector2.ZERO
	func aim_point(w):return w.player.position+Vector2.UP*80
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func before_each() -> void:
	previous_path=SaveData.path;SaveData.path=PATH;SaveData.clear()
	previous_events=Game.bot_events.duplicate();previous_beaten=Game.bot_beaten.duplicate()
	Game.bot_events=[RoadAccess.SAFFRON_VISITED];Game.bot_beaten=[]

func after_each() -> void:
	SaveData.clear();SaveData.path=previous_path
	Game.bot_events=previous_events;Game.bot_beaten=previous_beaten
	Game.destination={};Game.carry={};Game.arena_trip={}
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func open(place: String,trip: Dictionary={}):
	var bot:=OS.get_environment("BOT");var map:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","1");OS.set_environment("DUNGEON",place)
	Game.destination={};Game.carry={};Game.arena_trip=trip.duplicate(true)
	var game=load("res://scenes/main.tscn").instantiate();add_child_autofree(game)
	game.set_process(false);game.world.god=true;game.world.player.controller=Still.new()
	OS.set_environment("BOT",bot);OS.set_environment("DUNGEON",map)
	return game

func finish_talk(game) -> void:
	for i in 60:
		if game.state!="talk":break
		game._talk_next()

func test_all_eight_leaders_use_player_plus_three_to_seven_with_the_original_party_size() -> void:
	assert_eq(Data.LEADERS.size(),8)
	for id in Data.LEADERS:
		var source:=TrainerDB.get_trainer(id)
		for level in [1,5,12,20,35,60,90,99,100]:
			var tr:=TrainerDB.for_battle(id,level);var low:=100;var high:=1
			assert_eq(tr.party.size(),source.party.size());assert_eq(tr.reference_level,level)
			for row in tr.party:
				var lv:=int(row[1]);low=mini(low,lv);high=maxi(high,lv)
				assert_between(lv,mini(100,level+3),mini(100,level+7))
				if level<100:assert_gt(lv,level)
			assert_eq(low,mini(100,level+3));assert_eq(high,mini(100,level+7))

func test_brocks_training_party_has_four_distinct_families_and_aerodactyl_ace() -> void:
	assert_eq(Data.LEADERS.leader_brock.slots,["geodude","kabuto","onix","aerodactyl"])
	var early:=TrainerDB.for_battle("leader_brock",12)
	assert_eq(early.party.map(func(row):return row[0]),["geodude","kabuto","onix","aerodactyl"])
	assert_eq(early.party.map(func(row):return int(row[1])),[15,16,17,19])
	var late:=TrainerDB.for_battle("leader_brock",40)
	assert_eq(late.party.map(func(row):return row[0]),["graveler","kabutops","onix","aerodactyl"])
	assert_eq(late.party.map(func(row):return int(row[1])),[43,44,45,47])
	assert_false(early.party[3][2].has("stone_edge"))
	assert_false(early.party[3][2].has("hyper_beam"))
	assert_true(late.party[3][2].has("stone_edge"))
	assert_true(TrainerDB.for_battle("leader_brock",48).party[3][2].has("hyper_beam"))

func test_brocks_training_dialogue_names_both_new_partners_and_fits() -> void:
	var trainer:=TrainerDB.get_trainer("leader_brock")
	for code in ["ko","en"]:
		for page in trainer.intro[code]:assert_lte(PixelUi.line_count(page,Hud.MSG_W-30.0,1),2,code+" "+page)
	assert_true(str(trainer.intro.ko).contains("수련"))
	assert_true(str(trainer.intro.ko).contains("투구와 프테라"))

func test_other_leaders_use_four_unique_families_and_giovanni_has_five() -> void:
	var expected: Dictionary={
		"leader_misty":["psyduck","horsea","poliwag","staryu"],
		"leader_lt_surge":["voltorb","magnemite","elekid","pikachu"],
		"leader_erika":["bellsprout","tangela","exeggcute","oddish"],
		"leader_koga":["ekans","zubat","grimer","koffing"],
		"leader_sabrina":["drowzee","mr_mime","venonat","abra"],
		"leader_blaine":["vulpix","ponyta","magby","growlithe"],
		"leader_giovanni":["meowth","diglett","nidoran_f","nidoran_m","rhyhorn"]}
	for id in expected:
		assert_eq(Data.LEADERS[id].slots,expected[id])
		var party: Array=TrainerDB.for_battle(id,12).party
		assert_eq(party.size(),5 if id=="leader_giovanni" else 4)
		assert_eq(party.map(func(row):return int(row[1])),[15,16,17,18,19] if id=="leader_giovanni" else [15,16,17,19])
		assert_eq(party.back()[0],"kadabra" if id=="leader_sabrina" else expected[id].back(),"The representative family stays last")

func test_electric_and_fire_babies_grow_into_the_planned_kanto_forms_only() -> void:
	for data in [["leader_lt_surge","elekid","electabuzz"],["leader_blaine","magby","magmar"]]:
		assert_eq(Growth.lineage(data[0],2,29).back().species,data[1])
		assert_eq(Growth.lineage(data[0],2,30).back().species,data[2])
		assert_eq(Growth.lineage(data[0],2,100).back().species,data[2])
	assert_eq(TrainerDB.for_battle("leader_misty",55).party.map(func(row):return row[0]),["golduck","seadra","poliwrath","starmie"])
	assert_eq(TrainerDB.for_battle("leader_giovanni",55).party.map(func(row):return row[0]),["persian","dugtrio","nidoqueen","nidoking","rhydon"])

func test_every_evolution_boundary_uses_the_native_or_documented_gym_readiness_level() -> void:
	for id in Data.LEADERS:
		var cfg: Dictionary=Data.LEADERS[id]
		for index in cfg.slots.size():
			var family: Array=cfg.families[cfg.slots[index]]
			for i in range(1,family.size()):
				var stage: Dictionary=family[i];var at:=int(stage.level)
				assert_eq(Growth.lineage(id,index,at).back().species,stage.species)
				assert_eq(Growth.lineage(id,index,at-1).back().species,family[i-1].species)
	assert_eq(Growth.lineage("leader_brock",0,24).back().species,"geodude")
	assert_eq(Growth.lineage("leader_brock",0,25).back().species,"graveler")
	assert_eq(Growth.lineage("leader_brock",1,39).back().species,"kabuto")
	assert_eq(Growth.lineage("leader_brock",1,40).back().species,"kabutops")
	assert_eq(Growth.lineage("leader_brock",2,100).back().species,"onix")
	assert_eq(Growth.lineage("leader_brock",3,100).back().species,"aerodactyl")
	assert_eq(Growth.lineage("leader_giovanni",4,42).back().species,"rhydon")
	assert_eq(Growth.lineage("leader_sabrina",3,15).back().species,"abra")
	assert_eq(Growth.lineage("leader_sabrina",3,16).back().species,"kadabra")
	assert_eq(Growth.lineage("leader_sabrina",3,43).back().species,"alakazam")
	assert_eq(Growth.lineage("leader_erika",0,21).back().species,"weepinbell")
	assert_eq(Growth.lineage("leader_erika",0,29).back().species,"victreebel")

func test_scaled_forms_have_legal_level_or_tm_moves_and_at_least_one_attack() -> void:
	for id in Data.LEADERS:
		for level in [1,5,12,20,30,45,65,90,100]:
			var tr:=TrainerDB.for_battle(id,level)
			for i in tr.party.size():
				var row: Array=tr.party[i];var line:=Growth.lineage(id,i,int(row[1]))
				assert_eq(row[0],line.back().species);assert_between(row[2].size(),1,4)
				assert_true(row[2].any(func(move):return MoveDB.power(move)>0.0),id+" / "+str(row))
				for move in row[2]:
					assert_true(Growth.supported(move))
					var legal:=false
					for stage in line:
						if SpeciesDB.learnset(stage.species).any(func(pair):return pair[1]==move and int(pair[0])<=int(row[1])):legal=true
						var tm=MoveDB.get_move(move).get("tm")
						if tm!=null and tm in SpeciesDB.get_species(stage.species).tms:legal=true
					assert_true(legal,id+" / "+str(row[0])+" / "+str(move))

func test_authoring_data_and_fixed_story_battles_are_not_mutated_by_gym_growth() -> void:
	for id in Data.LEADERS:
		var original:=TrainerDB.get_trainer(id).duplicate(true)
		var low:=TrainerDB.for_battle(id,5);var high:=TrainerDB.for_battle(id,70)
		low.party[0][0]="ditto";high.party[0][1]=1
		assert_eq(TrainerDB.get_trainer(id),original)
	for id in ["rival_green_squirtle","rival_cerulean_squirtle","bill_vaporeon","mt_moon_jessie_james"]:
		assert_eq(TrainerDB.for_battle(id,80),TrainerDB.get_trainer(id))
	var raw: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/gym_leaders.json"))
	for id in raw.origins:
		var party: Array=TrainerDB.GymData.TRAINERS[id].party
		for i in party.size():
			assert_eq(party[i][0],raw.origins[id].party[i][0]);assert_eq(int(party[i][1]),int(raw.origins[id].party[i][1]))

func test_real_challenge_snapshots_the_whole_party_and_next_challenge_uses_current_level() -> void:
	var game=open("pewter_gym");game.beaten=[]
	game.world.player.set_level(20,true);game._talk(game.trainers[0]);finish_talk(game)
	assert_eq(game.state,"encounter")
	var roster: Dictionary=Game.arena_trip.roster.duplicate(true)
	assert_eq(roster,TrainerDB.for_battle("leader_brock",20))
	game.world.player.set_level(40,true)
	assert_eq(Game.arena_trip.roster,roster,"The current cut-in keeps its snapshot")
	game.free()
	var arena=open("arena_pewter_gym",{"trainer":"leader_brock","arena":"arena_pewter_gym","roster":roster,"back":{"map":"pewter_gym"}})
	arena.world.player.set_level(60,true)
	assert_eq(arena.battle_trainer(),roster,"Arena reload preserves the challenge")
	finish_talk(arena);arena.battle.idx=1;arena._send_next()
	var mon: Enemy=arena.battle.mon
	assert_eq(mon.species_id,roster.party[1][0]);assert_eq(mon.level,int(roster.party[1][1]))
	assert_eq(mon.max_hp,int(SpeciesDB.stats_at(mon.species_id,mon.level,mon.ivs).hp));assert_eq(arena.world._damage_mult(mon),1.0)
	assert_eq(arena.battle_trainer(),roster,"A player level-up cannot strengthen a reserve")
	arena.free()
	var retry=open("pewter_gym");retry.beaten=[];retry.world.player.set_level(30,true)
	retry._talk(retry.trainers[0]);finish_talk(retry)
	assert_eq(Game.arena_trip.roster,TrainerDB.for_battle("leader_brock",30))
	assert_ne(Game.arena_trip.roster.party,roster.party)

func test_scaled_party_moves_really_execute_and_have_full_unmodified_stats() -> void:
	var game=open("arena_pewter_gym");var w: World=game.world
	w.player.setup("raichu",80,Mon.TEAM_PLAYER);w.player.position=Arena.center();w.no_skills=false
	for id in Data.LEADERS:
		for level in [5,40,70]:
			var tr:=TrainerDB.for_battle(id,level)
			for i in tr.party.size():
				var row: Array=tr.party[i];var iv:=int(tr.ivs[i]) if tr.has("ivs") else 0
				var mon:=w.send_out(row[0],int(row[1]),row[2],w.player.position+Vector2.UP*Arena.TILE*2,false,iv)
				assert_eq(mon.stats,SpeciesDB.stats_at(row[0],int(row[1]),mon.ivs));assert_eq(mon.hp,mon.max_hp);assert_eq(w._damage_mult(mon),1.0)
				for move in mon.cds:mon.cds[move]=0.0
				var acted:=false
				for frame in 300:
					w.step(DT)
					if mon.windup_t>0.0 or mon.attack_anim_t>0.0:acted=true
				assert_true(acted,id+" / "+str(row)+" executes a legal attack")
				w.enemies.erase(mon);mon.free();w.clear_enemy_projectiles()

func test_all_growth_forms_have_original_shiny_cries_and_c_interpolation_assets() -> void:
	var forms: Dictionary={}
	for cfg in Data.LEADERS.values():
		for family in cfg.families.values():
			for stage in family:forms[stage.species]=true
	assert_eq(forms.size(),68)
	for id in forms:
		var dex:=int(SpeciesDB.get_species(id).dex)
		var motion: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/motion_2x/%04d.json"%dex))
		for variant in ["","shiny/"]:
			var path:="res://assets/sprites/%04d/"%dex+String(variant)
			assert_true(ResourceLoader.exists(path+"Walk-Anim.png"));assert_true(FileAccess.file_exists(path+"AnimData.xml"))
			assert_true(motion.has(path+"Walk-Anim.png"),id+" has native passing poses")
			assert_eq(int(motion[path+"Walk-Anim.png"].steps),2)
			assert_true(FileAccess.file_exists(motion[path+"Walk-Anim.png"].sheet))
		assert_true(ResourceLoader.exists("res://assets/audio/cry/"+String(id)+".wav"))

func test_every_gym_party_grants_zero_exp_but_still_advances_to_victory() -> void:
	for place in TrainerDB.GymData.GYMS:
		var cfg: Dictionary=TrainerDB.GymData.GYMS[place]
		var roster:=TrainerDB.for_battle(cfg.leader,5)
		var game=open(cfg.arena,{"trainer":cfg.leader,"roster":roster,"back":{"map":place}})
		game.beaten=[];finish_talk(game)
		var p: Player=game.world.player
		p.set_level(5,true)
		p.exp_total=SpeciesDB.exp_for_level(6,SpeciesDB.growth_of(p.species_id))-1
		var initial_exp:=p.exp_total;var learned:=p.known_moves().duplicate()
		for i in roster.party.size():
			game.battle.next_t=0.0
			game._send_next()
			var mon: Enemy=game.battle.mon
			assert_eq(game.world.exp_gain(mon),0,"Gym sendouts have no EXP reward")
			game.world.damage(mon,mon.hp)
			assert_eq(p.exp_total,initial_exp);assert_eq(p.level,5);assert_eq(p.known_moves(),learned)
			assert_false(game.exp_display_pending());assert_true(game.stat_queue.is_empty());assert_true(game.growth_learns.is_empty())
			assert_eq(game.battle.then,"next" if i<roster.party.size()-1 else "done")
			game.sendout={};game.dialog_text="";game.talk_pages=[];game.talk_after=Callable();game.state="fight"
		game.battle.faint_t=0.0;game._after_foe_fainted();game._step_battle(Game.WIN_TEXT_DELAY+0.1)
		assert_true(game.battle.is_empty());assert_true(game.beaten.has(cfg.leader),"Zero EXP cannot stop the final victory callback")
		assert_eq(p.exp_total,initial_exp);game.free()

func test_gym_callback_rejects_exp_while_wild_and_ordinary_trainer_rewards_still_work() -> void:
	var roster:=TrainerDB.for_battle("leader_brock",20)
	var game=open("arena_pewter_gym",{"trainer":"leader_brock","roster":roster,"back":{"map":"pewter_gym"}})
	finish_talk(game);game._send_next()
	var initial_exp: int=game.world.player.exp_total
	game._on_enemy_defeated(game.battle.mon,99999)
	assert_eq(game.world.player.exp_total,initial_exp,"A positive callback cannot bypass the gym rule")
	assert_false(game.exp_display_pending());game.free()
	var other=open("arena_route1")
	other.world.player.set_level(20,true)
	var before: int=other.world.player.exp_total
	var wild:=Enemy.new();wild.setup_enemy("caterpie",5,other.world.rng);add_child_autofree(wild)
	other._on_enemy_defeated(wild,7)
	assert_eq(other.world.player.exp_total,before+7,"Wild EXP stays enabled")
	var trainer:=Npc.new();trainer.setup({"id":"ordinary_reward","trainer":"rival_green_squirtle","tile":Vector2i(3,3)});add_child_autofree(trainer)
	var foe:=Enemy.new();foe.setup_trainer_mon("squirtle",5,["tackle"],other.world.rng);add_child_autofree(foe)
	other.battle={"trainer":trainer,"mon":foe,"idx":1}
	other._on_enemy_defeated(foe,10)
	assert_eq(other.world.player.exp_total,before+7+15,"Normal trainer EXP retains its existing 1.5 multiplier")
