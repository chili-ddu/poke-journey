extends GutTest
const Game=preload("res://scripts/game.gd")
const Trial=preload("res://scripts/story/tower_brothers.gd")
const Data=Trial.Data
const PATH="user://save_tower_brothers_test.cfg"
const DT:=1.0/60.0
var old_path: String
var old_events: Array
var old_starter: String

class Quiet:
	extends RefCounted
	func move_dir(_w):return Vector2.ZERO
	func aim_point(w):return w.player.position+Vector2.UP*80.0
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func before_each() -> void:
	old_path=SaveData.path;SaveData.path=PATH;SaveData.clear()
	old_events=Game.bot_events.duplicate();Game.bot_events=[]
	old_starter=Game.starter;Game.starter="charmander"

func after_each() -> void:
	SaveData.clear();SaveData.path=old_path
	Game.bot_events=old_events;Game.starter=old_starter
	Game.destination={};Game.arena_trip={};Game.carry={}
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func previous_flags(number: int) -> Array:
	var flags: Array=["visited_area_saffron_city"]
	for n in range(2,number):flags.append(Data.flag(n))
	return flags

func fixture(place: String,number: int=2,human: bool=false,unlocked: bool=true):
	var old_bot:=OS.get_environment("BOT");var old_place:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","0" if human else "1");OS.set_environment("DUNGEON",place)
	Game.destination={};Game.carry={};Game.bot_events=previous_flags(number) if unlocked else []
	Game.arena_trip={"event":Trial.ID,"tower_floor":number,"arena":Data.ARENA,
		"back":{"map":Data.floor_id(number),"pos":Vector2(12,12)*Arena.TILE}} if place==Data.ARENA else {}
	if human:
		for flag in previous_flags(number):SaveData.store_progress("events",flag)
	var game=load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game);game.set_process(false);game.world.god=true
	game.world.player.controller=Quiet.new()
	OS.set_environment("BOT",old_bot);OS.set_environment("DUNGEON",old_place)
	return game

func finish_talk(game) -> void:
	for i in 40:
		if game.state!="talk":break
		game._talk_next()

func split(game) -> void:
	finish_talk(game)
	for i in 900:
		if game.state!="tower_event":break
		game.advance(DT)

func until_step(game,step: String,brother: String="") -> bool:
	for i in 2400:
		var trial=game.tower_brothers
		if trial.summon_step==step and (brother=="" or trial.active_brother==brother):return true
		if trial.phase not in ["cloning","battle"]:return false
		game.advance(DT)
	return false

func finish_floor(game) -> Dictionary:
	var counts: Dictionary={}
	for i in 9000:
		if game.tower_brothers.phase!="battle":return counts
		assert_lte(game.world.remaining(),Data.count(game.tower_brothers.floor_number))
		for enemy in game.world.alive_enemies():
			var id: String=enemy.get_meta("tower_double")
			assert_eq(enemy.max_hp,int(SpeciesDB.stats_at(enemy.species_id,enemy.level,enemy.ivs).hp),"Intervention copies retain normal species HP")
			assert_eq(game.world._damage_mult(enemy),1.0,"Intervention copies deal full original damage")
			counts[id]=int(counts.get(id,0))+1
			game.world.damage(enemy,enemy.hp)
		game.advance(DT)
	fail_test("The event must defeat every scheduled brother group and complete")
	return counts

func test_all_floors_are_story_only_and_original_stairs_still_exist() -> void:
	for n in range(1,8):
		var id:=Data.floor_id(n)
		DungeonDB.set_current(id);Arena.configure(DungeonDB.theme())
		assert_true(DungeonDB.is_indoor());assert_false(DungeonDB.is_overworld())
		assert_true(DungeonDB.encounters().is_empty());assert_eq(DungeonDB.enemy_count(),0)
		assert_eq(DungeonDB.area_cfg(id).get("encounter_rate",-1),0)
		assert_true(DungeonDB.area_cfg(id).get("encounters",["unexpected"]).is_empty())
		assert_true(DungeonDB.DUNGEONS[id].get("npcs",["unexpected"]).is_empty())
		assert_true(DungeonDB.DUNGEONS[id].get("trainers",["unexpected"]).is_empty())
		assert_gt(Arena.warps().size(),0)
		if n>=2:
			var p:=Arena.tile_center(Data.PLAYER_TILES[n])
			assert_lt(Arena.resolve(p,8).distance_to(p),0.1,"Player introduction position is clear: %dF"%n)
			for tile in Data.SPEAKER_TILES[n]:
				assert_false(Arena.solid_at(tile.x,tile.y),"Story actor stands on source floor: %dF %s"%[n,tile])
	DungeonDB.set_current(Data.ARENA);Arena.configure(DungeonDB.theme())
	assert_true(DungeonDB.is_arena());assert_true(Arena.warps().is_empty())

func test_every_floor_introduces_the_correct_siblings_then_enters_the_event_arena() -> void:
	for n in range(2,8):
		var game=fixture(Data.floor_id(n),n);var trial=game.tower_brothers
		assert_not_null(trial);assert_eq(game.mode,"indoor");assert_eq(game.state,"talk")
		assert_eq(trial.floor_number,n);assert_eq(trial.actors.size(),Data.SPEAKERS[n].size())
		assert_true(game.trainers.is_empty());assert_eq(game.world.remaining(),0)
		var pages: Array=game.talk_pages.duplicate();pages.push_front({"text":game.dialog_text})
		for page in pages:assert_false(String(page.text).is_empty())
		trial.arrive();assert_eq(trial.actors.size(),Data.SPEAKERS[n].size(),"Arrival callback is idempotent")
		finish_talk(game)
		assert_eq(game.state,"encounter");assert_eq(Game.arena_trip.tower_floor,n)
		assert_eq(Game.arena_trip.arena,Data.ARENA);assert_false(Game.arena_trip.has("trainer"))
		game.free()

func test_clone_counts_compositions_positions_and_attacks_for_all_six_battles() -> void:
	var expected:=[5,10,15,10,25,10]
	var levels:={"youngest":22,"third":24,"second":29,"eldest":34}
	for id in levels:assert_eq(int(Data.BROTHERS[id].level),int(levels[id]))
	for n in range(2,8):
		var game=fixture(Data.ARENA,n);var trial=game.tower_brothers
		assert_true(game.is_event_battle());assert_null(game.arena_trainer)
		assert_eq(game.total_enemies,expected[n-2]);assert_eq(game.location_name(),"포켓몬타워 %d층"%n)
		finish_talk(game);assert_eq(trial.phase,"cloning");assert_true(game.world.no_skills)
		game.advance(0.2);assert_eq(game.world.remaining(),0,"There is a visible split windup")
		game.state="menu";game.advance(5.0);assert_eq(trial.elapsed,0.2,"Menus pause the split animation")
		game.state="tower_event"
		for i in 900:
			if game.state!="tower_event":break
			game.advance(DT)
		assert_eq(game.state,"fight");assert_false(game.world.no_skills)
		var initial: int=Data.BROTHERS[Data.STAGES[n][0]].copies
		assert_eq(game.world.alive_enemies().size(),initial)
		var counts: Dictionary={};var positions: Dictionary={}
		for enemy in game.world.alive_enemies():
			var brother: String=enemy.get_meta("tower_double")
			counts[brother]=int(counts.get(brother,0))+1
			assert_eq(enemy.species_id,Data.BROTHERS[brother].species)
			assert_eq(enemy.level,int(levels[brother]))
			assert_eq(enemy.max_hp,int(SpeciesDB.stats_at(enemy.species_id,enemy.level,enemy.ivs).hp),"Event battles use normal full species HP")
			assert_eq(enemy.hp,enemy.max_hp)
			assert_eq(game.world.exp_gain(enemy),0)
			assert_true(enemy.trainer_owned,"Projections cannot drop wild loot")
			assert_eq(enemy.appear,1.0);assert_gt(enemy.cds.size(),0)
			assert_true(enemy.display_name().contains(Data.brother_name(brother)))
			assert_false(positions.has(enemy.position),"Every double has a separate position")
			positions[enemy.position]=true
			assert_lt(Arena.resolve(enemy.position,enemy.radius).distance_to(enemy.position),0.1)
			assert_gt(enemy.position.distance_to(game.world.player.position),Arena.TILE*2.0)
			for move_id in enemy.cds:
				assert_true(MoveDB.has_move(move_id));assert_gt(MoveDB.power(move_id),0.0)
				var hit: Dictionary=game.world.make_hit(enemy,move_id)
				assert_eq(float(hit.mult),1.0,"Event projections use the original damage formula without an event multiplier")
		assert_eq(counts.size(),1,"Only the first brother participates at the start")
		trial._begin_split();trial._release_copies(Data.STAGES[n][-1])
		assert_eq(game.world.remaining(),initial,"Repeated callbacks cannot duplicate the first brother")
		assert_true(trial.request_attack());assert_false(trial.request_attack(),"Twenty-five copies cannot all attack at once")
		trial.step_battle(Trial.ATTACK_GAP+0.01);assert_true(trial.request_attack())
		counts=finish_floor(game)
		assert_eq(trial.phase,"aftermath")
		for brother in Data.STAGES[n]:assert_eq(int(counts.get(brother,0)),int(Data.BROTHERS[brother].copies))
		assert_eq(trial.created,expected[n-2]);assert_eq(game.defeated,expected[n-2])
		assert_gte(trial.peak_active,initial)
		game.free()

func test_original_appears_plays_the_full_double_sheet_and_copies_travel_outward() -> void:
	var game=fixture(Data.ARENA,2);var trial=game.tower_brothers
	var actor: Mon=trial.actors.youngest
	assert_eq(game.state,"tower_event");assert_false(actor.visible)
	assert_eq(game.world.remaining(),0)
	assert_true(until_step(game,"entry","youngest"))
	assert_true(actor.visible);assert_eq(actor.appear,0.0)
	assert_true(until_step(game,"pause"));assert_eq(actor.appear,1.0)
	assert_true(until_step(game,"double"))
	assert_eq(actor.attack_anim,"Double")
	assert_almost_eq(trial.double_duration,MonSprite.anim_length(actor._sprites.Double),0.0001)
	var double_started: float=actor.anim_t
	for i in 12:game.advance(DT)
	assert_gt(actor.anim_t,double_started);assert_gt(actor.attack_anim_t,0.0)
	assert_eq(game.world.remaining(),0,"The original gets its Double pose before any copies appear")
	assert_true(until_step(game,"spread"))
	assert_false(actor.visible);assert_eq(game.world.remaining(),5)
	assert_false(trial.request_attack(),"Copies cannot attack while the formation is being introduced")
	var origin: Vector2=actor.position
	for enemy in game.world.alive_enemies():assert_eq(enemy.position,origin,"Copies start at the actual original, not at their destination")
	for i in 15:game.advance(DT)
	assert_true(game.world.alive_enemies().any(func(e):return e.position.distance_to(origin)>Arena.TILE))
	assert_true(trial.flights.any(func(f):return f.mon.position.distance_to(f.to)>1.0),"Spreading uses actual movement across multiple frames")
	split(game)
	assert_eq(trial.phase,"battle");assert_eq(game.world.remaining(),5)
	var events: Array=trial.summon_log
	var posing: Dictionary=events.filter(func(e):return e.event=="double")[0]
	var spreading: Dictionary=events.filter(func(e):return e.event=="spread")[0]
	assert_gte(float(spreading.time)-float(posing.time)+0.001,float(posing.duration),"The original Double sheet completes once at native speed")

func test_timed_siblings_join_without_any_defeats_and_accumulate_to_twenty_five() -> void:
	var game=fixture(Data.ARENA,6);var trial=game.tower_brothers
	split(game)
	assert_eq(trial.released.keys(),["youngest"])
	assert_eq(game.world.remaining(),5);assert_eq(game.enemies_left(),25)
	assert_true(trial.progress_text().contains("전투 중 5"));assert_true(trial.progress_text().contains("남은 분신 25"))
	assert_almost_eq(trial.battle_elapsed,0.0,0.001,"The first entrance animation is not part of the combat clock")
	var targets:=Data.formation(5)
	for enemy in game.world.alive_enemies():assert_true(targets.any(func(p):return p.distance_to(enemy.position)<0.01))
	assert_gt(targets[0].y,targets[2].y);assert_gt(targets[4].y,targets[2].y)
	for enemy in game.world.alive_enemies():enemy.frozen=true
	for i in int(Data.INTERVENTION_INTERVAL/DT)-2:game.advance(DT)
	assert_eq(trial.released.keys(),["youngest"]);assert_eq(trial.summon_step,"done")
	var clock: float=trial.battle_elapsed
	game.state="menu";game.advance(20.0)
	assert_eq(trial.battle_elapsed,clock,"Menus pause scheduled interventions")
	game.state="fight"
	assert_true(until_step(game,"double","third"))
	assert_eq(game.state,"fight");assert_eq(game.world.remaining(),5)
	assert_eq(game.defeated,0,"The third brother joins even when all five youngest doubles survive")
	game._queue_status_message("검증용 전투 메시지")
	assert_true(game.displayed_message().contains("셋째"),"An intervention line stays readable while normal combat messages arrive")
	var still_fighting: Enemy=game.world.alive_enemies()[0]
	still_fighting.position=game.world.player.position+Vector2.UP*Arena.TILE
	still_fighting.cds={"lick":0.0};still_fighting.windup_t=0.0;still_fighting.recover_t=0.0
	trial.attack_t=0.0
	game.advance(DT)
	assert_gt(still_fighting.windup_t,0.0,"The previous brother still attacks during the next brother's Double pose")
	assert_true(until_step(game,"done","third"))
	assert_eq(game.world.remaining(),15,"The ten new doubles join the surviving five")
	assert_true(trial.summon_log.any(func(e):return e.event=="entry" and e.get("brother","")=="third" and e.during_battle))
	for enemy in game.world.alive_enemies():enemy.frozen=true
	assert_true(until_step(game,"done","second"))
	assert_eq(game.world.remaining(),25);assert_eq(game.defeated,0)
	assert_eq(trial.peak_active,25,"There is no artificial five-enemy cap")
	var joins: Array=trial.summon_log.filter(func(e):return e.event=="intervention")
	assert_eq(joins.size(),2)
	assert_almost_eq(float(joins[0].battle_time),Data.INTERVENTION_INTERVAL,DT*1.1)
	assert_almost_eq(float(joins[1].battle_time),Data.INTERVENTION_INTERVAL*2.0,DT*1.1)
	var rest:=finish_floor(game)
	assert_eq(int(rest.youngest),5);assert_eq(int(rest.third),10);assert_eq(int(rest.second),10)
	assert_eq(game.defeated,25)
	var entries: Array=trial.summon_log.filter(func(e):return e.event=="entry")
	assert_eq(entries.map(func(e):return e.brother),["youngest","third","second"])
	assert_true(entries[1].during_battle);assert_true(entries[2].during_battle)
	trial._restore_speakers()
	assert_lt(trial.actors.third.position.y,trial.actors.youngest.position.y)
	assert_lt(trial.actors.third.position.y,trial.actors.second.position.y,"The three originals also stand on a shallow fan")
	assert_ne(Data.brother_position(0,2).y,Data.brother_position(1,2).y,"A duo has a small depth offset instead of a straight horizontal row")

func test_single_brother_releases_all_ten_and_fast_clear_does_not_skip_the_next_timed_brother() -> void:
	var game=fixture(Data.ARENA,3);var trial=game.tower_brothers
	split(game)
	assert_eq(game.world.remaining(),10);assert_eq(trial.created,10)
	for enemy in game.world.alive_enemies():game.world.damage(enemy,enemy.hp)
	game.advance(DT)
	assert_eq(game.defeated,10);assert_true(game.events.has(Data.flag(3)))
	game.free()
	game=fixture(Data.ARENA,4);trial=game.tower_brothers
	split(game)
	for enemy in game.world.alive_enemies():game.world.damage(enemy,enemy.hp)
	for i in 120:game.advance(DT)
	assert_eq(game.world.remaining(),0);assert_eq(trial.summon_step,"done")
	assert_eq(trial.phase,"battle");assert_false(game.events.has(Data.flag(4)))
	assert_true(until_step(game,"done","third"))
	assert_eq(game.world.remaining(),10,"The fixed-time reinforcement still arrives after an early clear")
	assert_almost_eq(float(trial.summon_log.filter(func(e):return e.event=="intervention")[0].battle_time),Data.INTERVENTION_INTERVAL,DT*1.1)

class MoveAndCast:
	extends RefCounted
	func move_dir(_w):return Vector2.RIGHT
	func aim_point(w):return w.player.position+Vector2.RIGHT*100.0
	func want_skill(i,_w):return i==0
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func test_player_keeps_movement_and_skill_input_during_an_intervention() -> void:
	var game=fixture(Data.ARENA,4);var trial=game.tower_brothers
	split(game)
	assert_true(until_step(game,"double","third"))
	game.world.player.learn("ember",0);game.world.player.controller=MoveAndCast.new()
	game.world.player.position=Arena.tile_center(Vector2i(10,17))
	game.world.player.skill_lock_t=0.0;game.world.player.attack_anim_t=0.0
	game.world.player.use_t[0]=0.0;game.world.player.hitstop_t=0.0
	game.world.player.invuln_t=0.5
	game.world.player.para_t=0.0;game.world.player.para_lock_t=0.0
	game.world.player.recover_t=0.0;game.world.player.flinch_t=0.0
	var before: Vector2=game.world.player.position
	var pp: int=game.world.player.pp[0]
	for i in 4:game.advance(DT)
	assert_eq(game.state,"fight");assert_false(game.world.no_skills)
	assert_gt(game.world.player.position.x,before.x)
	assert_lt(int(game.world.player.pp[0]),pp,"The player's command remains live while another brother enters")

func test_clear_requires_all_copies_and_saves_the_next_floor_before_dialogue() -> void:
	var game=fixture(Data.ARENA,6,true);var trial=game.tower_brothers
	split(game)
	var exp_before: int=game.world.player.exp_total
	var bag_before: Dictionary=game.world.player.bag.duplicate()
	for enemy in game.world.alive_enemies():game.world.damage(enemy,enemy.hp)
	trial.step_battle(DT)
	assert_eq(trial.phase,"battle");assert_false(game.events.has(Data.flag(6)))
	finish_floor(game)
	assert_eq(trial.phase,"aftermath");assert_eq(game.state,"tower_event")
	assert_eq(game.defeated,25);assert_eq(game.enemies_left(),0)
	assert_true(game.events.has(Data.flag(6)));assert_false(game.events.has(Data.COMPLETE))
	assert_eq(Game.arena_trip.back.map,Data.floor_id(7))
	assert_eq(SaveData.load_saved().map,Data.floor_id(7))
	assert_true(SaveData.load_saved().events.has(Data.flag(6)))
	assert_eq(game.world.player.exp_total,exp_before);assert_eq(game.world.player.bag,bag_before)
	assert_true(game.world.drops.is_empty(),"Projection defeats cannot be farmed for loot")
	game.advance(Trial.AFTER_TIME+0.1)
	assert_eq(game.state,"talk");assert_eq(trial.phase,"won")
	assert_true((game.dialog_text+str(game.talk_pages)).contains("큰형"))

func test_interrupted_victory_resumes_at_next_floor_without_replaying_earlier_fights() -> void:
	var game=fixture(Data.ARENA,2,true);var trial=game.tower_brothers
	split(game)
	for enemy in game.world.alive_enemies():game.world.damage(enemy,enemy.hp)
	trial.step_battle(DT)
	assert_eq(SaveData.load_saved().map,Data.floor_id(3))
	game.free()
	var resumed=fixture(Data.floor_id(3),3,true)
	assert_eq(resumed.tower_brothers.phase,"intro")
	assert_true(resumed.events.has(Data.flag(2)))
	assert_eq(resumed.tower_brothers.actors.third.species_id,"gastly")
	resumed.free()
	var earlier=fixture(Data.floor_id(2),3,true)
	assert_eq(earlier.state,"warp");assert_eq(Game.destination.map,Data.floor_id(3))
	assert_eq(earlier.world.remaining(),0)

func test_final_victory_is_permanent_and_returns_to_the_lobby() -> void:
	var game=fixture(Data.ARENA,7,true);var trial=game.tower_brothers
	split(game)
	finish_floor(game);trial.step_battle(DT)
	assert_true(game.events.has(Data.COMPLETE));assert_eq(game.events.count(Data.flag(7)),1)
	assert_eq(game.events.count(Data.COMPLETE),1)
	assert_eq(SaveData.load_saved().map,Data.floor_id(1))
	assert_true(SaveData.load_saved().events.has(Data.COMPLETE))
	game.advance(Trial.AFTER_TIME+0.1)
	assert_eq(game.state,"talk");assert_eq(trial.actors.size(),4)
	game.free()
	var lobby=fixture(Data.floor_id(1),8,true)
	assert_eq(lobby.world.remaining(),0);assert_true(lobby.events.has(Data.COMPLETE))
	assert_true(lobby.tower_brothers.block_completed_stairs({"to":Data.floor_id(2)}))
	assert_eq(lobby.state,"talk");assert_eq(lobby.world.remaining(),0)

func test_failed_battle_does_not_unlock_a_floor_or_change_other_enemy_damage() -> void:
	var game=fixture(Data.ARENA,4,true);var trial=game.tower_brothers
	split(game)
	game.world.god=false;game.world.damage(game.world.player,game.world.player.hp)
	trial.step_battle(1.0)
	assert_false(game.events.has(Data.flag(4)));assert_false(game.events.has(Data.COMPLETE))
	assert_eq(trial.phase,"battle")
	var ordinary:=Enemy.new();ordinary.setup_enemy("gastly",18,game.world.rng)
	assert_eq(game.world._damage_mult(ordinary),World.ENEMY_DAMAGE_MULT)
	ordinary.free()

func test_brothers_have_native_animated_art_and_complete_bilingual_story_lines() -> void:
	var smooth: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/smooth/manifest.json"))
	for dex in [92,93,94]:
		for variant in ["","shiny/"]:
			var dir: String="res://assets/sprites/%04d/"%dex+String(variant)
			assert_true(FileAccess.file_exists(dir+"AnimData.xml"))
			assert_true(FileAccess.file_exists(dir+"Walk-Anim.png"))
			assert_true(smooth.has(dir+"Double-Anim.png"),"The split animation uses the shared C in-betweens")
	for species in ["gastly","haunter","gengar"]:assert_true(FileAccess.file_exists("res://assets/audio/cry/"+species+".wav"))
	for n in range(2,8):
		for lines in [Trial.INTRO[n],Trial.OUTRO[n]]:
			for line in lines:
				assert_true(Data.SPEAKERS[n].has(line[0]));assert_false(String(line[1]).is_empty());assert_false(String(line[2]).is_empty())

func test_tower_trials_do_not_appear_before_saffron() -> void:
	var game=fixture(Data.floor_id(2),2,false,false)
	assert_eq(game.tower_brothers.phase,"idle")
	assert_true(game.tower_brothers.actors.is_empty())
	assert_ne(game.state,"talk")
	assert_false(game.events.has(Data.flag(2)))

func test_interrupted_final_outro_resumes_the_one_time_reward_at_lobby() -> void:
	SaveData.store_progress("events",Data.COMPLETE)
	var game=fixture(Data.floor_id(1),8,true)
	assert_eq(game.state,"talk","A completed old/interrupted record receives the closing recognition first")
	assert_false(game.events.has("tower_brothers_rewarded"))
	var before: Dictionary=game.world.player.bag.duplicate()
	finish_talk(game)
	assert_true(game.events.has("tower_brothers_rewarded"))
	assert_eq(int(game.world.player.bag.get("oran_berry",0)),int(before.get("oran_berry",0))+3)
	assert_eq(int(game.world.player.bag.get("leppa_berry",0)),int(before.get("leppa_berry",0))+2)
	var rewarded: Dictionary=game.world.player.bag.duplicate()
	var exp_after: int=game.world.player.exp_total
	game.tower_brothers._award_completion()
	assert_eq(game.world.player.bag,rewarded)
	assert_eq(game.world.player.exp_total,exp_after)
	assert_has(SaveData.load_saved().events,"tower_brothers_rewarded")
