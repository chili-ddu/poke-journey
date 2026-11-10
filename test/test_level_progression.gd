extends GutTest
const Game=preload("res://scripts/game.gd")
const Policy=preload("res://scripts/data/level_progression.gd")
const VISITED="visited_area_saffron_city"
var old_path: String

func before_each() -> void:
	old_path=SaveData.path;SaveData.path="user://save_level_progression_test.cfg";SaveData.clear()

func after_each() -> void:
	SaveData.clear();SaveData.path=old_path
	Game.bot_events=[];Game.bot_beaten=[];Game.destination={};Game.carry={};Game.arena_trip={}
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func fixture(flags: Array=[],place: String="kanto_world"):
	var where:=OS.get_environment("DUNGEON");var bot:=OS.get_environment("BOT")
	OS.set_environment("DUNGEON",place);OS.set_environment("BOT","1")
	Game.bot_events=flags.duplicate();Game.bot_beaten=[];Game.destination={};Game.carry={};Game.arena_trip={}
	var game=load("res://scenes/main.tscn").instantiate();add_child_autofree(game);game.set_process(false)
	OS.set_environment("DUNGEON",where);OS.set_environment("BOT",bot)
	return game

func test_tutorial_caps_land_water_and_cave_tables_without_mutating_sources() -> void:
	for area in KantoWorldWild.data().tables:
		var cfg:=KantoWorldWild.area(area)
		for key in ["encounters","water_encounters"]:
			for row in cfg.get(key,[]):
				var native:=int(row[3] if row.size()>3 else row[1])
				var window:=Policy.encounter_window(area,native,40,[])
				assert_lte(window.y,10,area);assert_gte(window.x,1)
	assert_eq(Policy.encounter_window("route1",3,12,[]),Vector2i(3,3))
	assert_eq(KantoWorldWild.area("digletts_cave_b1f").encounters.back()[1],31)

func test_post_saffron_bands_and_player_offsets() -> void:
	for row in [["route5",10,25],["route24",12,30],["rock_tunnel_1f",12,30],
		["route15",20,40],["safari_zone_east",20,40],["seafoam_islands_b4f",30,50],
		["pokemon_mansion_b1f",30,50],["route23",40,65],["victory_road_2f",40,65],["cerulean_cave_b1f",55,80]]:
		assert_eq(Policy.band(row[0]),[float(row[1]),float(row[2])])
		assert_eq(Policy.encounter_window(row[0],5,1,[VISITED]),Vector2i(row[1],row[1]))
		assert_eq(Policy.encounter_window(row[0],5,100,[VISITED]),Vector2i(row[2],row[2]))
	assert_eq(Policy.encounter_window("route5",18,12,[VISITED]),Vector2i(10,14))
	assert_eq(Policy.encounter_window("route24",8,12,[VISITED]),Vector2i(12,14))
	assert_eq(Policy.encounter_window("route12",24,12,[VISITED]),Vector2i(20,20))
	assert_eq(Policy.encounter_window("route1",4,50,[VISITED]),Vector2i(4,4))

func test_experience_halves_original_and_applies_all_overlevel_steps() -> void:
	for row in [[5,39],[10,39],[11,29],[12,19],[13,9],[14,0],[40,0]]:
		assert_eq(Policy.experience(55,10,row[0]),row[1])
	var game=fixture()
	var e:=Enemy.new();e.setup_enemy("pidgey",10,game.world.rng);add_child_autofree(e)
	game.world.player.level=12
	assert_eq(game.world.exp_gain(e),19)
	e.trainer_owned=true;assert_eq(game.world.exp_gain(e),19)
	e.set_meta("no_exp",true);assert_eq(game.world.exp_gain(e),0)

func test_actual_wild_spawn_is_capped_and_remains_fixed_after_level_up() -> void:
	var game=fixture([],"digletts_cave_b1f")
	game.world.player.level=9
	assert_true(game.world.queue_spawn("diglett",25))
	assert_eq(game.world.pending_spawns[0].level,10)
	game.world.player.level=30;game.world._step_spawns(2.0)
	assert_eq(game.world.enemies.size(),1)
	assert_eq(game.world.enemies[0].level,10)
	assert_eq(game.world.enemies[0].species_id,"diglett")

func test_fishing_uses_the_same_tutorial_policy() -> void:
	var game=fixture()
	for i in 50:assert_lte(game.world.wild_level("route6",40),10)
	game.events.append(VISITED);game.world.player.level=22
	for i in 50:assert_between(game.world.wild_level("route6",40),19,24)

func test_ordinary_trainers_cap_then_follow_source_region_and_snapshot() -> void:
	var id: String=TrainerDB.RoadData.POOLS.route11[0]
	var source:=TrainerDB.get_trainer(id).duplicate(true)
	var early:=TrainerDB.for_battle(id,12,{"area":"route11","events":[]})
	assert_lte(early.party.size(),2)
	for row in early.party:assert_lte(int(row[1]),10)
	var later:=TrainerDB.for_battle(id,35,{"area":"route11","events":[VISITED]})
	for row in later.party:assert_eq(int(row[1]),30)
	assert_eq(TrainerDB.get_trainer(id),source)
	var game=fixture([VISITED]);game.world.player.level=25
	game.world.player.position=Arena.tile_center(Arena.area_rect("route11").position+Vector2i(8,9))
	var npc:=Npc.new();npc.setup({"id":id,"trainer":id,"tile":Arena.tile_of(game.world.player.position)})
	game.world.add_child(npc);game._begin_battle(npc)
	var snapshot: Dictionary=game.battle_trainer().duplicate(true)
	game.world.player.level=50
	assert_eq(game.battle_trainer(),snapshot)
	for row in snapshot.party:assert_between(int(row[1]),22,27)

func test_leaders_and_story_rosters_keep_their_existing_rules() -> void:
	var context:={"area":"route5","events":[]}
	assert_eq(TrainerDB.for_battle("leader_brock",12,context),TrainerDB.for_battle("leader_brock",12))
	assert_eq(TrainerDB.for_battle("bill_vaporeon",12,context),TrainerDB.get_trainer("bill_vaporeon"))

func test_gyms_block_entry_and_loaded_inside_leader_talk_before_saffron() -> void:
	var game=fixture()
	var door: Dictionary=Arena.warps().filter(func(w):return DungeonDB.warp_destination(w)=="pewter_gym")[0]
	game.world.player.position=Arena.tile_center(Vector2i(door.x,door.y));game.warp_armed=true
	game._check_warp();assert_ne(game.state,"warp");assert_true(Game.destination.is_empty())
	game.events.append(VISITED);game.warp_armed=true;game._check_warp()
	assert_eq(game.state,"warp");assert_eq(Game.destination.map,"pewter_gym")
	game=fixture([],"pewter_gym")
	game._talk(game.trainers[0]);assert_eq(game.state,"talk")
	assert_true(game.battle.is_empty());assert_true(Game.arena_trip.is_empty())
	assert_string_contains(game.dialog_text,"노랑시티")

func test_saffron_visit_activates_scaling_without_overwriting_growth() -> void:
	var game=fixture([],"saffron_city")
	assert_true(Policy.unlocked(game.events))
	assert_true(game.world.progression_events.has(VISITED))
	var before: int=game.world.player.exp_total
	game.world.player.level=12
	assert_between(game.world.wild_level("route24",8),12,14)
	assert_eq(game.world.player.exp_total,before)
