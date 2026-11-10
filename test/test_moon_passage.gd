extends GutTest
const Game=preload("res://scripts/game.gd")
const Passage=preload("res://scripts/story/moon_passage.gd")
const PATH="user://save_moon_passage_test.cfg"
var old_path: String
var old_events: Array
var old_beaten: Array

func before_each() -> void:
	old_path=SaveData.path;SaveData.path=PATH
	old_events=Game.bot_events.duplicate();Game.bot_events=[]
	old_beaten=Game.bot_beaten.duplicate();Game.bot_beaten=[]

func after_each() -> void:
	SaveData.path=old_path;Game.bot_events=old_events;Game.bot_beaten=old_beaten
	Game.destination={};Game.arena_trip={};Game.carry={}
	if FileAccess.file_exists(PATH):DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func open_game(place: String,entrance: bool=false) -> Node:
	var old_bot:=OS.get_environment("BOT");var old_map:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","1");OS.set_environment("DUNGEON",place)
	Game.destination={"map":place,"warp":{"map":place,"index":3}} if entrance else {}
	Game.arena_trip={};Game.carry={}
	var game=load("res://scenes/main.tscn").instantiate()
	add_child_autofree(game);game.set_process(false);game.bot=false
	OS.set_environment("BOT",old_bot);OS.set_environment("DUNGEON",old_map)
	return game

func greet(game: Node) -> void:
	for i in 90:
		if game.state=="talk":break
		game.advance(1.0/60.0)

func finish_dialogue(game: Node) -> void:
	for i in 20:
		if game.state!="talk":break
		game._talk_next()

func test_western_arrival_greets_before_any_wild_or_trainer_battle() -> void:
	var game=open_game(Passage.PLACE,true)
	assert_eq(game.state,"moon_event")
	assert_eq(game.moon_passage.actor.species_id,"clefairy")
	greet(game)
	assert_eq(game.state,"talk")
	assert_string_contains(game.dialog_text,"R")
	assert_eq(game.talk_focus.get_ref(),game.moon_passage.actor)
	assert_true(game.battle.is_empty())
	assert_true(Game.arena_trip.is_empty())
	assert_eq(game.world.remaining(),0)
	assert_false(game.beaten.has(Game.MOON_GRADUATION),"Bypassing the duo never grants a victory")
	assert_lt(Arena.resolve(game.moon_passage.actor.position,game.moon_passage.actor.radius).distance_to(game.moon_passage.actor.position),0.1)

func test_metronome_waggles_before_release_and_preserves_player_resources() -> void:
	var game=open_game(Passage.PLACE,true)
	greet(game)
	var p: Player=game.world.player
	p.hp=maxi(1,p.max_hp-3)
	var health:=p.hp;var pp:=p.pp.duplicate();var exp_before:=p.exp_total
	finish_dialogue(game)
	assert_eq(game.state,"moon_event")
	assert_eq(game.moon_passage.actor.attack_anim,"Dance")
	for i in 60:game.advance(1.0/60.0)
	assert_eq(game.moon_passage.pulses,3)
	assert_false(game.moon_passage.released)
	for i in 28:game.advance(1.0/60.0)
	assert_true(game.moon_passage.released)
	assert_gt(game.fader.color.a,0.0)
	assert_eq(p.hp,health);assert_eq(p.pp,pp);assert_eq(p.exp_total,exp_before)
	assert_false(game.events.has(Passage.CROSSED),"Completion waits for departure")

func test_return_entry_is_sealed_in_both_mainland_layouts_only_after_crossing() -> void:
	for place in ["kanto_north",KantoWorldTravel.ID]:
		Game.bot_events=[]
		var game=open_game(place)
		var tile:=Arena.warp_tile("route4",1)
		game.world.player.position=Arena.tile_center(tile)
		var warp:=Arena.warp_at(game.world.player.position)
		assert_false(game.moon_passage.check_blocked_entry(warp))
		game.events.append(Passage.CROSSED)
		game.warp_armed=true;game.state="fight";game._check_warp()
		assert_eq(game.state,"talk")
		assert_eq(game.dialog_text,game.moon_passage.text("blocked"))
		assert_true(Game.destination.is_empty())
		finish_dialogue(game)
		game._check_warp()
		assert_eq(game.state,"fight","Holding against the entrance does not reopen dialogue")
		assert_false(game.moon_passage.check_blocked_entry({}))
		game._check_warp();assert_eq(game.state,"talk","Leaving and returning allows another explanation")
		var western:=Arena.warp_at(Arena.tile_center(Arena.warp_tile("route4",0)))
		assert_false(game.moon_passage.check_blocked_entry(western),"Western visitors can ask Clefairy again")

func test_saved_cave_visitors_trigger_near_the_entrance_without_hijacking_deep_saves() -> void:
	var game=open_game(Passage.PLACE)
	game.world.player.position=Arena.tile_center(Vector2i(5,6))
	assert_false(game.moon_passage.check_discovery())
	game.world.player.position=Arena.tile_center(Passage.ENTRANCE+Vector2i.UP)
	assert_true(game.moon_passage.check_discovery())
	assert_false(game.moon_passage.check_discovery(),"One scene cannot start two greetings")

func test_returning_western_visitors_keep_the_short_repeat_dialogue() -> void:
	Game.bot_events=[Passage.CROSSED]
	var game=open_game(Passage.PLACE,true)
	greet(game)
	assert_string_contains(game.dialog_text,game.moon_passage.text("repeat"))
	assert_false(game.dialog_text.contains("R 표시"))

func test_dialogue_and_cast_use_existing_assets_in_both_languages() -> void:
	var keep:=Lang.code
	for code in ["ko","en"]:
		Lang.code=code
		var event=Passage.new()
		for key in Passage.LINES:
			var prefix:=Lang.species_name("clefairy")+": " if key in ["danger","offer","repeat"] else ""
			assert_lte(PixelUi.line_count(prefix+event.text(key),Hud.MSG_W-30.0,1),2,code+" "+key)
	Lang.code=keep
	assert_true(MonSprite.load_set(35).has("Dance"))
	assert_not_null(Fx.sheet("metronome_star"))
