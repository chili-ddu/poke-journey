extends GutTest
const Game=preload("res://scripts/game.gd")
const Rewards=Game.GymFieldFriends
const Campaign=preload("res://scripts/story/campaign_director.gd")
const PATH="user://save_gym_field_friends_test.cfg"
var previous: Dictionary

func before_each() -> void:
	previous={"path":SaveData.path,"starter":Game.starter,"events":Game.bot_events.duplicate(),"beaten":Game.bot_beaten.duplicate(),"campaign":Campaign.bot_campaign.duplicate(true)}
	SaveData.path=PATH;SaveData.clear();Game.bot_events=[];Game.bot_beaten=[];Campaign.bot_campaign={}

func after_each() -> void:
	SaveData.clear();SaveData.path=previous.path;Game.starter=previous.starter
	Game.bot_events=previous.events;Game.bot_beaten=previous.beaten;Campaign.bot_campaign=previous.campaign
	Game.destination={};Game.carry={};Game.arena_trip={}
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func open(place: String,species: String="charmander",human: bool=false) -> Node:
	var bot:=OS.get_environment("BOT");var where:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","0" if human else "1");OS.set_environment("DUNGEON",place)
	Game.starter=species;Game.destination={};Game.carry={};Game.arena_trip={}
	var game=load("res://scenes/main.tscn").instantiate();add_child_autofree(game);game.set_process(false)
	OS.set_environment("BOT",bot);OS.set_environment("DUNGEON",where)
	return game

func test_surge_win_grants_pikachu_or_compatible_flash_without_equipping() -> void:
	assert_true(Game.FieldHMs.compatible("bulbasaur","flash"))
	assert_false(Game.FieldHMs.compatible("squirtle","flash"))
	for species in ["bulbasaur","squirtle"]:
		SaveData.clear();Game.bot_beaten=[]
		Game.bot_events=[RoadAccess.SAFFRON_VISITED]
		var game=open("vermilion_city_gym",species);game.bot=false
		assert_false(game.events.has(Game.PikachuRescue.FRIEND))
		var slots: Array=game.world.player.slots.duplicate()
		var pp: Array=game.world.player.pp.duplicate()
		var exp_before: int=game.world.player.exp_total
		game._begin_battle(game.trainers[0]);game._trainer_defeated()
		assert_true(game.events.has(Game.PikachuRescue.FRIEND))
		assert_eq(game.world.player.known_moves().has("flash"),species=="bulbasaur")
		assert_eq(game.world.player.slots,slots);assert_eq(game.world.player.pp,pp)
		assert_eq(game.world.player.exp_total,exp_before)
		var saved:=SaveData.load_saved()
		assert_has(saved.events,Game.PikachuRescue.FRIEND)
		assert_has(saved.trainers,"leader_lt_surge")
		assert_eq((saved.learned as Array).has("flash"),species=="bulbasaur")
		assert_eq(saved.slots,slots);assert_eq(saved.exp,exp_before)
		assert_true(game.talk_pages.any(func(page):return (String(page.get("text","")) if page is Dictionary else String(page)).contains("피카츄") or (String(page.get("text","")) if page is Dictionary else String(page)).contains("PIKACHU")),"Surge explains Pikachu's cave assistance")
		assert_true(game._gym_field_help_pages("leader_lt_surge").is_empty())
		game._begin_battle(game.trainers[0]);game._trainer_defeated()
		assert_eq(game.events.count(Game.PikachuRescue.FRIEND),1)
		assert_eq(game.world.player.known_moves().count("flash"),1 if species=="bulbasaur" else 0)
		assert_false(Rewards.grant(game,"leader_lt_surge"),"The retired generic reward path remains inert")
		game.free()

func test_misty_win_grants_her_lapras_or_compatible_surf_without_equipping() -> void:
	for species in ["squirtle","charmander"]:
		SaveData.clear();Game.bot_beaten=[]
		Game.bot_events=[RoadAccess.SAFFRON_VISITED,"quest_moon_mining_complete"]
		var game=open("cerulean_city_gym",species);game.bot=false
		assert_false(game.events.has(Game.LaprasEscape.FRIEND))
		var slots: Array=game.world.player.slots.duplicate()
		var pp: Array=game.world.player.pp.duplicate()
		game._begin_battle(game.trainers[0]);game._trainer_defeated()
		assert_true(game.events.has(Game.LaprasEscape.FRIEND))
		assert_eq(game.world.player.known_moves().has("surf"),species=="squirtle")
		assert_eq(game.world.player.slots,slots);assert_eq(game.world.player.pp,pp)
		var saved:=SaveData.load_saved()
		assert_has(saved.events,Game.LaprasEscape.FRIEND)
		assert_has(saved.trainers,"leader_misty")
		assert_eq((saved.learned as Array).has("surf"),species=="squirtle")
		game._begin_battle(game.trainers[0]);game._trainer_defeated()
		assert_eq(game.events.count(Game.LaprasEscape.FRIEND),1)
		game.free()

func test_old_gym_wins_recover_both_helper_sources_but_only_compatible_techniques() -> void:
	var source=open("kanto_world","squirtle");source.bot=false;source._save_here()
	for leader in Rewards.REWARDS:SaveData.store_progress("trainers",leader)
	var before:=SaveData.load_saved()
	var game=open("kanto_world","squirtle",true)
	var after:=SaveData.load_saved()
	assert_true(after.events.has(Game.FieldHMs.SOURCES.surf))
	assert_true(game.world.player.known_moves().has("surf"))
	assert_true(after.events.has(Game.FieldHMs.SOURCES.flash))
	assert_false(game.world.player.known_moves().has("flash"))
	for key in ["species","level","exp","pid","ivs","slots","bag"]:assert_eq(after[key],before[key])
	assert_false(Rewards.sync(game))

func test_old_friends_survive_without_requiring_a_new_gym_win() -> void:
	Game.bot_events=[Game.LaprasEscape.FRIEND,Game.PikachuRescue.FRIEND]
	var game=open("rock_tunnel_1f")
	assert_true(game.beaten.is_empty())
	assert_eq(game.pikachu_rescue.helper.species_id,"pikachu")
	assert_true(game.events.has(Game.LaprasEscape.FRIEND))
	assert_false(Rewards.sync(game))

func test_unrelated_leaders_and_retired_battle_flags_do_not_unlock_friends() -> void:
	Game.bot_beaten=["leader_brock","leader_erika"]
	Game.bot_events=["pikachu_rescue_won","lapras_escape_started","lapras_escape_won"]
	var game=open("kanto_world")
	assert_false(game.events.has(Game.LaprasEscape.FRIEND))
	assert_false(game.events.has(Game.PikachuRescue.FRIEND))
	assert_false(Rewards.grant(game,"leader_brock"))
	assert_false(DungeonDB.has_location("arena_lapras_escape"))
	assert_false(DungeonDB.has_location("arena_pikachu_rescue"))

func test_reward_pages_fit_the_dialogue_box_in_both_languages() -> void:
	for reward in Rewards.REWARDS.values():
		for language in 2:
			for key in ["intro","joined"]:
				assert_lte(PixelUi.line_count(reward[key][language],Hud.MSG_W-30.0,1),2,reward[key][language])

func test_legacy_surge_win_saved_inside_rock_tunnel_lights_cave_immediately() -> void:
	for species in ["bulbasaur","squirtle"]:
		SaveData.clear();Game.bot_events=[];Game.bot_beaten=[]
		var source=open("rock_tunnel_1f",species);source.bot=false;source._save_here()
		assert_false(source.events.has(Game.PikachuRescue.FRIEND))
		assert_null(source.pikachu_rescue.helper)
		assert_false(source.pikachu_rescue.self_flash)
		SaveData.store_progress("trainers","leader_lt_surge")
		var before:=SaveData.load_saved();source.free()
		var game=open("rock_tunnel_1f",species,true)
		var after:=SaveData.load_saved()
		assert_true(game.events.has(Game.PikachuRescue.FRIEND))
		assert_true(after.events.has(Game.PikachuRescue.FRIEND))
		assert_eq(game.world.player.known_moves().has("flash"),species=="bulbasaur")
		assert_eq(game.pikachu_rescue.self_flash,species=="bulbasaur")
		if species=="bulbasaur":
			assert_null(game.pikachu_rescue.helper)
			assert_eq(game.pikachu_rescue.helper_lamp.get_parent(),game.world.player)
		else:
			assert_not_null(game.pikachu_rescue.helper)
			assert_eq(game.pikachu_rescue.helper.species_id,"pikachu")
			assert_true(game.world.bystanders.has(game.pikachu_rescue.helper))
		assert_not_null(game.pikachu_rescue.veil)
		assert_true(game.learn_field_hms().is_empty())
		for key in ["species","level","exp","pid","ivs","slots","bag"]:assert_eq(after[key],before[key])
		game.free()
		var again=open("rock_tunnel_1f",species,true)
		assert_eq(again.events.count(Game.PikachuRescue.FRIEND),1)
		assert_eq(again.world.player.known_moves().count("flash"),1 if species=="bulbasaur" else 0)
		assert_eq(again.world.player.slots,before.slots)
		assert_eq(again.world.player.exp_total,before.exp)
		assert_false(again._restore_gym_field_help(),"A repeated reload does not grant the source again")
		again.free()
