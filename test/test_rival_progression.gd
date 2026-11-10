extends GutTest

const Game=preload("res://scripts/game.gd")
const Story=preload("res://scripts/story/rival_progression.gd")
const Data=Story.Data
const PATH="user://save_rival_progression_test.cfg"
const DT=1.0/60.0
var previous: Dictionary={}

class Still:
	extends RefCounted
	func move_dir(_w):return Vector2.ZERO
	func aim_point(w):return w.player.position+Vector2.UP*80
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func before_each() -> void:
	previous={"path":SaveData.path,"starter":Game.starter,"beaten":Game.bot_beaten.duplicate(),"events":Game.bot_events.duplicate()}
	SaveData.path=PATH;SaveData.clear()

func after_each() -> void:
	SaveData.clear();SaveData.path=previous.path;Game.starter=previous.starter;Game.bot_beaten=previous.beaten;Game.bot_events=previous.events
	Game.destination={};Game.carry={};Game.arena_trip={};Game.rival_leaving=""
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func flags(stage: Dictionary) -> Array:
	var result: Array=[]
	if stage.rule=="all_leaders":
		for cfg in TrainerDB.GymData.GYMS.values():result.append(cfg.leader)
	return result

func fixture(stage: Dictionary,starter: String="charmander",won: Array=[],leaving: String=""):
	var bot:=OS.get_environment("BOT");var map:=OS.get_environment("DUNGEON")
	var place:=String(stage.map) if String(stage.map)!="" else "kanto_world"
	DungeonDB.set_current(place);Arena.configure(DungeonDB.theme())
	var region:=Arena.area_rect(stage.area)
	var tile:=region.position+Vector2i(int(stage.rect[0]),int(stage.rect[1]))
	OS.set_environment("BOT","1");OS.set_environment("DUNGEON",place)
	Game.starter=starter;Game.bot_beaten=won.duplicate();Game.bot_events=[];Game.carry={};Game.arena_trip={};Game.rival_leaving=leaving
	Game.destination={"map":place,"pos":Arena.tile_center(tile),"layout":1,"source_region":true}
	var game=load("res://scenes/main.tscn").instantiate();add_child_autofree(game)
	game.set_process(false);game.world.god=true;game.world.player.controller=Still.new()
	OS.set_environment("BOT",bot);OS.set_environment("DUNGEON",map)
	return game

func finish_talk(game) -> void:
	for i in 60:
		if game.state!="talk":break
		game._talk_next()

func test_native_parties_all_starter_branches_and_legacy_battles() -> void:
	var native: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/rival_progression.json"))
	var count:=0;var ids: Dictionary={}
	for stage in Data.STAGES:
		for starter in ["charmander","squirtle","bulbasaur"]:
			var id:=Story.trainer_id(stage.id,starter)
			assert_false(ids.has(id));ids[id]=true;assert_true(TrainerDB.has_trainer(id))
			var tr: Dictionary=TrainerDB.get_trainer(id);var raw: Dictionary=native.origins[id]
			assert_eq(tr["class"],"rival");assert_eq(TrainerDB.arena_of(id),stage.arena)
			assert_eq(tr.party.size(),raw.party.size());assert_eq(Story.stage_for(id).id,stage.id)
			for i in tr.party.size():
				assert_eq(tr.party[i][0],raw.party[i][0]);assert_eq(int(tr.party[i][1]),int(raw.party[i][1]))
				if tr.party[i].size()>2:assert_eq(tr.party[i][2],raw.party[i][2])
				assert_eq(int(tr.ivs[i]),int(raw.native_ivs[i])*31/255);count+=1
	assert_eq(ids.size(),12);assert_eq(count,54)
	for starter in ["charmander","squirtle","bulbasaur"]:
		assert_eq(TrainerDB.get_trainer(TrainerDB.rival_for(starter)).party.size(),3)
		assert_eq(TrainerDB.get_trainer(TrainerDB.cerulean_rival_for(starter)).party.size(),4)
		assert_eq(Story.trainer_id("silph",starter),Story.trainer_id("silph",SpeciesDB.get_species(starter).evolve.to))

func test_all_trigger_points_approach_on_walkable_paths_and_open_the_correct_arena() -> void:
	for stage in Data.STAGES:
		for starter in ["charmander","squirtle","bulbasaur"]:
			var game=fixture(stage,starter,flags(stage));var event=game.rival_progression
			var id:=Story.trainer_id(stage.id,starter)
			assert_true(event.check(),stage.id+" triggers for "+starter)
			assert_eq(game.state,"rival");assert_eq(game.rival.npc.trainer_id,id)
			var population: int=game.world.npcs.size()
			assert_false(event.check());assert_eq(game.world.npcs.size(),population)
			assert_false(game.beaten.has(id),"Approaching never records a victory")
			for point in game.rival.path:
				assert_lt(Arena.resolve(point,Npc.BODY_R).distance_to(point),0.1)
				assert_eq(Arena.ledge_at(Arena.tile_of(point).x,Arena.tile_of(point).y),0)
			for frame in 2400:
				if game.state!="rival":break
				game.advance(DT)
			assert_eq(game.state,"talk");finish_talk(game)
			assert_eq(game.state,"encounter");assert_eq(Game.arena_trip.trainer,id)
			assert_eq(Game.arena_trip.arena,stage.arena)
			assert_eq(Game.arena_trip.back.map,String(stage.map) if String(stage.map)!="" else "kanto_world")
			game.free()

func test_early_and_late_route22_encounters_follow_leader_progress_and_do_not_repeat() -> void:
	var early: Dictionary=Data.STAGES[0];var late: Dictionary=Data.STAGES[3]
	var game=fixture(early);var event=game.rival_progression
	assert_true(event.eligible(early));assert_false(event.eligible(late))
	game.beaten.append("leader_brock")
	assert_false(event.eligible(early));assert_false(event.check())
	var required:=flags(late)
	game.beaten=required.slice(0,7)
	assert_false(event.eligible(late))
	game.world.player.set_level(100,true)
	assert_false(event.eligible(late),"Level does not replace the eight leader victories")
	game.beaten=required.duplicate()
	assert_true(event.eligible(late));assert_true(event.check())
	assert_eq(game.rival.npc.trainer_id,Story.trainer_id(late.id,"charmander"))
	game.free()
	var id:=Story.trainer_id(late.id,"charmander")
	var won=fixture(late,"charmander",required+[id])
	assert_false(won.rival_progression.check());assert_false(is_instance_valid(won.rival_progression.waiting))

func test_route22_triggers_cover_all_three_original_entry_lanes() -> void:
	for row in [5,6]:
		var stage: Dictionary=Data.STAGES[0]
		var game=fixture(stage)
		game.world.player.position=Arena.tile_center(Arena.area_rect(stage.area).position+Vector2i(33,row))
		assert_true(game.rival_progression.check(),"Route22 lane "+str(row))
		for frame in 2400:
			if game.state!="rival":break
			game.advance(DT)
		assert_eq(game.state,"talk");game.free()

func test_partial_tile_entry_keeps_green_clear_of_the_players_body() -> void:
	var stage: Dictionary=Data.STAGES[1];var game=fixture(stage)
	game.world.player.position+=Vector2.LEFT*(Arena.TILE*0.5-0.1)
	assert_true(game.rival_progression.check())
	var actor: Npc=game.rival.npc
	for point in game.rival.path:assert_ne(Arena.tile_of(point),Arena.tile_of(game.world.player.position))
	for frame in 2400:
		if game.state!="rival":break
		game.advance(DT)
	assert_eq(game.state,"talk")
	assert_gte(actor.position.distance_to(game.world.player.position),Npc.BODY_R+game.world.player.radius+2.0)

func test_waiting_rival_can_be_spoken_to_and_cleans_up_outside_the_area() -> void:
	var stage: Dictionary=Data.STAGES[1]
	var game=fixture(stage);var event=game.rival_progression
	var region:=Arena.area_rect(stage.area)
	game.world.player.position=Arena.tile_center(region.position+Vector2i(15,10))
	assert_false(event.check());assert_true(is_instance_valid(event.waiting))
	var actor: Npc=event.waiting
	game.world.player.position=actor.position+Vector2.DOWN*Arena.TILE
	assert_true(actor.can_talk(game.world.player.position));game._talk(actor);finish_talk(game)
	assert_eq(game.state,"encounter");assert_eq(Game.arena_trip.trainer,Story.trainer_id(stage.id,"charmander"))
	game.free()
	var other=fixture(stage)
	other.world.player.position=Arena.tile_center(region.position+Vector2i(15,10))
	other.rival_progression.check()
	assert_true(is_instance_valid(other.rival_progression.waiting))
	var elsewhere:=Arena.area_rect("route12")
	other.world.player.position=Arena.tile_center(elsewhere.get_center())
	other.rival_progression.check()
	assert_false(is_instance_valid(other.rival_progression.waiting))

func test_pause_airborne_and_defeated_states_cannot_start_a_new_rival_encounter() -> void:
	var game=fixture(Data.STAGES[1]);var event=game.rival_progression
	game.state="menu";assert_false(event.check())
	game.state="fight";game.world.player.hop_t=0.2;assert_false(event.check())
	game.world.player.hop_t=0;game.world.player.dead=true;assert_false(event.check())
	game.world.player.dead=false
	assert_true(event.check());var elapsed: float=game.rival.t
	game.state="menu";game.advance(3.0);assert_eq(game.rival.t,elapsed)

func test_victory_resume_uses_safe_exit_paths_and_restores_the_map_state() -> void:
	for stage in Data.STAGES:
		var id:=Story.trainer_id(stage.id,"charmander")
		var game=fixture(stage,"charmander",flags(stage)+[id],id)
		assert_eq(game.state,"leave",stage.id+" returns into a departure scene")
		assert_eq(Game.rival_leaving,"")
		for point in game.rival_exit.path:
			assert_lt(Arena.resolve(point,Npc.BODY_R).distance_to(point),0.1)
		for frame in 2400:
			if game.state!="leave":break
			game.advance(DT)
		assert_eq(game.state,"town" if game.mode=="indoor" else "fight")
		assert_true(game.rival_exit.is_empty());assert_false(game.rival_progression.check())
		game.free()

func test_new_rival_party_stats_moves_assets_and_silph_indoor_arena() -> void:
	var game=fixture(Data.STAGES[0]);var w: World=game.world
	var smooth: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/smooth/manifest.json"))
	for id in Data.TRAINERS:
		var tr: Dictionary=TrainerDB.get_trainer(id)
		for i in tr.party.size():
			var row: Array=tr.party[i]
			var mon:=Enemy.new();mon.setup_trainer_mon(row[0],int(row[1]),row[2] if row.size()>2 else [],w.rng,int(tr.ivs[i]))
			assert_eq(mon.stats,SpeciesDB.stats_at(row[0],int(row[1]),mon.ivs));assert_eq(mon.max_hp,int(mon.stats.hp));assert_eq(mon.hp,mon.max_hp)
			assert_eq(w._damage_mult(mon),1.0);assert_false(mon.cds.is_empty())
			for move in mon.cds:assert_true(MoveDB.has_move(move))
			var dex:=int(SpeciesDB.get_species(row[0]).dex)
			for variant in ["","shiny/"]:
				var dir:="res://assets/sprites/%04d/"%dex+String(variant)
				assert_true(FileAccess.file_exists(dir+"Walk-Anim.png"));assert_true(smooth.has(dir+"Walk-Anim.png"))
			assert_true(ResourceLoader.exists("res://assets/audio/cry/"+row[0]+".wav"));mon.free()
	DungeonDB.set_current("arena_silph_rival");Arena.configure(DungeonDB.theme())
	assert_true(DungeonDB.is_arena());assert_eq(View3D.sky_kind(DungeonDB.current),"indoor")
	assert_true(FileAccess.file_exists("res://assets/maps/arena_silph_rival/hd2d_cards.json"))

func test_tower_interiors_remain_exclusive_to_the_four_brothers() -> void:
	var stage: Dictionary=Data.STAGES[1]
	var game=fixture(stage)
	for floor in range(1,8):
		DungeonDB.set_current("pokemon_tower_%df"%floor);Arena.configure(DungeonDB.theme())
		assert_false(game.rival_progression._here(stage))
		assert_true(DungeonDB.DUNGEONS[DungeonDB.current].get("trainers",[]).is_empty())
