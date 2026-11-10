extends GutTest
const Game = preload("res://scripts/game.gd")
const Bill = preload("res://scripts/story/bill_event.gd")
const Regional = preload("res://scripts/story/regional_quests.gd")
const PATH := "user://save_bill_rescue_test.cfg"
var old_path: String
var old_events: Array
var old_beaten: Array

func before_each() -> void:
	old_path=SaveData.path;SaveData.path=PATH;SaveData.clear()
	old_events=Game.bot_events.duplicate();old_beaten=Game.bot_beaten.duplicate()
	Game.bot_events=[];Game.bot_beaten=[]

func after_each() -> void:
	SaveData.clear();SaveData.path=old_path
	Game.bot_events=old_events;Game.bot_beaten=old_beaten
	Game.destination={};Game.arena_trip={};Game.carry={}
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func open_house():
	var old_bot:=OS.get_environment("BOT");var old_map:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","1");OS.set_environment("DUNGEON",Bill.PLACE)
	Game.destination={};Game.arena_trip={};Game.carry={}
	var game=load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game);game.set_process(false)
	OS.set_environment("BOT",old_bot);OS.set_environment("DUNGEON",old_map)
	return game

func finish_dialogue(game) -> void:
	for i in 30:
		if game.state!="talk":break
		game._talk_next()

func test_house_has_reciprocal_doors_and_reachable_research_pc() -> void:
	var game=open_house()
	assert_eq(game.mode,"indoor")
	assert_eq(Arena.warp_at(Arena.tile_center(Vector2i(7,9))).to,"route25")
	assert_false(Arena.solid_at(4,6))
	game._talk(game.bill_event.computer);finish_dialogue(game)
	assert_eq(game.state,"town")
	assert_true(Game.arena_trip.is_empty())
	assert_eq(game.world.player.bag.get("ss_ticket",0),0)

func test_old_separator_and_trainer_victory_flags_never_restart_capture_battle() -> void:
	Game.bot_events=["bill_in_separator","bill_restored","bill_ss_ticket"]
	Game.bot_beaten=[TrainerDB.bill_for(Game.starter)]
	var game=open_house()
	assert_eq(game.bill_event.phase,"idle")
	assert_eq(game.state,"town")
	assert_null(game.bill_event.actor,"The retired trainer actor is not silently reintroduced")
	for actor in game.world.npcs:
		assert_false(actor.is_trainer(),"BILL no longer catches the player for a research battle")
	assert_true(Game.arena_trip.is_empty())

func test_new_bill_quest_fights_rockets_and_reveals_silph_without_transport_destination() -> void:
	var quest: Dictionary={}
	for candidate in Regional.quests():
		if candidate.id=="bill_rescue":quest=candidate
	assert_false(quest.is_empty())
	assert_has(quest.requires,"visited_area_saffron_city")
	assert_eq(quest.stages[0].sprite,"rocket_m")
	assert_gt(quest.stages[0].battle.size(),0)
	assert_eq(quest.stages[1].flag,"bill_silph_research_tip")
	var lines: String=" ".join(quest.stages[1].intro)
	assert_true(lines.contains("실프"))
	assert_false(lines.contains("게임코너"),"The destination clue belongs to Silph, not BILL")
