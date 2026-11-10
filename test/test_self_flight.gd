extends GutTest
const Game=preload("res://scripts/game.gd")
const Bird=preload("res://scripts/story/bird_event.gd")
const Flight=preload("res://scripts/data/pokemon_flight.gd")
var old_path: String
var old_events: Array
var old_starter: String

class Still:
	extends RefCounted
	func move_dir(_w):return Vector2.ZERO
	func aim_point(w):return w.player.position+Vector2.UP*80.0
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func before_each() -> void:
	old_path=SaveData.path;SaveData.path="user://save_self_flight_test.cfg";SaveData.clear()
	old_events=Game.bot_events.duplicate();old_starter=Game.starter
	Game.bot_events=[Bird.FRIEND,FlyDestinations.visit_flag("route24"),RoadAccess.SAFFRON_VISITED];Game.starter="charmander"

func after_each() -> void:
	SaveData.clear();SaveData.path=old_path;Game.bot_events=old_events;Game.starter=old_starter
	Game.destination={};Game.arena_trip={};Game.carry={}
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func fixture(species: String="charizard", place: String="kanto_south"):
	var bot:=OS.get_environment("BOT");var where:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","1");OS.set_environment("DUNGEON",place)
	Game.destination={};Game.arena_trip={};Game.carry={}
	var game=load("res://scenes/main.tscn").instantiate();add_child_autofree(game);game.set_process(false)
	OS.set_environment("BOT",bot);OS.set_environment("DUNGEON",where)
	game.world.player.setup_player(species,10,["scratch"],{});game.world.player.controller=Still.new()
	game.bot=false;game.world.god=true;game.dialog_text="";game.dialog_t=0.0
	return game

func space(game) -> void:
	var key:=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true;game._unhandled_input(key)

func hop(game) -> void:
	game.world.player.position=Arena.tile_center(Arena.area_tile("pallet_town",Vector2i(11,9)))
	game.world._start_hop(game.world.player.position+Vector2.UP*24.0)

func test_capability_uses_species_not_flying_type_or_a_learned_move() -> void:
	for id in ["charizard","pidgeotto","butterfree","beedrill","scyther","flygon","mew","garchomp"]:assert_true(Flight.can_fly(id),id)
	for id in ["charmander","charmeleon","blastoise","venusaur","doduo","dodrio","gyarados","mantine","natu","scizor"]:assert_false(Flight.can_fly(id),id)
	for id in SpeciesDB.all_ids():assert_typeof(Flight.can_fly(id),TYPE_BOOL)
	for list in [Flight.rules().additional,Flight.rules().excluded,Flight.rules().hover]:
		for id in list:assert_true(SpeciesDB.has_species(id),id)

func test_native_wing_cycle_keeps_direction_and_does_not_modify_combat_animation() -> void:
	for id in ["charizard","butterfree","pidgeotto","pidgeot"]:
		var mon:=Mon.new();mon.setup(id,10,Mon.TEAM_PLAYER)
		var source:=Flight.animation(mon)
		var original: Array=mon._sprites[source].durations.duplicate()
		var order: Array=[0,1] if source=="Shoot" or original.size()==18 else [0,1,2,1]
		if id in ["pidgeotto","pidgeot"]:assert_eq(source,"Shoot")
		assert_eq(Flight.prepare_animation(mon),"Flight")
		var pose: Dictionary=mon._sprites.Flight
		for i in order.size():
			var visual:=MonSprite.visual_frame(pose,3,MonSprite.frame_start(pose,i),true)
			assert_eq(int(visual.src.position.x/float(pose.fw)),order[i])
			assert_eq(int(visual.src.position.y/float(pose.fh)),3,"A wingbeat cannot turn the body to another direction")
		assert_eq(mon._sprites[source].durations,original)
		assert_false(MonSprite.load_set(int(SpeciesDB.get_species(id).dex)).has("Flight"),"Flight timing stays local to the actor")
		mon.free()

func test_confirmation_flaps_then_launches_without_a_carrier_and_preserves_source_save() -> void:
	var game=fixture();var p: Player=game.world.player
	hop(game);var at:=p.position
	var hp:=p.hp;var pp:=p.pp.duplicate();var exp_before:=p.exp_total;var bag:=p.bag.duplicate(true)
	assert_false(p.known_moves().has("fly"))
	space(game);assert_eq(game.menu,"fly")
	assert_true(p.known_moves().has("fly"),"A compatible species learns the unlocked HM")
	game.bird_event.choose_destination("route24")
	var bird=game.bird_event
	assert_true(bird.self_flight);assert_null(bird.helper);assert_eq(bird.phase,"self_ready")
	assert_eq(p.attack_anim,"Flight");assert_eq(p.get_meta("loop_animation"),"Flight")
	assert_false(p.get_meta("carried",false));assert_true(bird.camera_locked)
	game.advance(Bird.SELF_READY_TIME+0.01)
	assert_eq(bird.phase,"self_depart")
	var before:=p.position;var lift:=p.lift;var camera: Vector2=game.world.cam.position
	game.advance(0.10)
	assert_gt(p.position.x,before.x);assert_lt(p.position.y,before.y);assert_gt(p.lift,lift)
	assert_eq(game.world.cam.position,camera)
	game.advance(Bird.SELF_DEPART_TIME)
	assert_eq(game.state,"warp");assert_eq(Game.destination.fly_arrival,"route24")
	assert_null(bird.helper);assert_gt(p.lift,0.0,"Remain airborne through the fade")
	assert_eq(SaveData.load_saved().pos,at,"Save the original safe ground, not the off-screen flight position")
	assert_eq(p.hp,hp);assert_eq(p.pp,pp);assert_eq(p.exp_total,exp_before);assert_eq(p.bag,bag)

func test_self_arrival_lands_without_a_bird_and_cleans_up_the_flight_pose() -> void:
	for id in ["charizard","pidgeotto","pidgeot"]:
		var game=fixture(id,"cerulean_north");var p: Player=game.world.player
		p.hp-=3;var hp:=p.hp;var pp:=p.pp.duplicate();var exp_before:=p.exp_total
		game.bird_event.arrive("route24")
		var bird=game.bird_event;var at:=p.position
		assert_true(bird.self_flight);assert_null(bird.helper);assert_false(p.get_meta("carried",false))
		game.advance(Bird.ARRIVE_TIME*0.5)
		assert_gt(p.lift,0.0);assert_eq(p.position,at)
		game.advance(Bird.ARRIVE_TIME*0.5+0.01)
		assert_eq(bird.phase,"landing_release");assert_eq(p.lift,0.0)
		assert_false(p.has_meta("loop_animation"));assert_eq(p.attack_anim_t,0.0)
		game.advance(Bird.RELEASE_TIME+0.01)
		assert_eq(bird.phase,"idle");assert_eq(game.state,"fight");assert_null(bird.helper)
		assert_false(p.get_meta("self_flight_pose",false));assert_false(p.get_meta("screen_facing",false))
		assert_eq(p.hp,hp);assert_eq(p.pp,pp);assert_eq(p.exp_total,exp_before)
		assert_eq(SaveData.load_saved().pos,at)
		game.free()

func test_cancelling_map_preserves_the_jump_without_starting_a_flight_pose() -> void:
	var game=fixture();hop(game)
	var p: Player=game.world.player;var dash:=p.dash.duplicate(true);var hop_before:=p.hop_t
	space(game)
	var key:=InputEventKey.new();key.physical_keycode=KEY_ESCAPE;key.pressed=true
	game.fly_screen._unhandled_input(key)
	assert_eq(game.bird_event.phase,"idle");assert_false(game.bird_event.self_flight)
	assert_eq(p.dash,dash);assert_eq(p.hop_t,hop_before);assert_false(p.get_meta("self_flight_pose",false))
	assert_null(game.bird_event.helper)

func test_first_kidnapping_still_precedes_friendship_and_grounded_species_keep_the_carrier() -> void:
	var game=fixture();game.events.erase(Bird.FRIEND);hop(game);space(game)
	assert_eq(game.bird_event.phase,"swoop");assert_false(game.bird_event.self_flight)
	assert_eq(game.bird_event.helper.species_id,"pidgeotto")
	game.free()
	Game.bot_events=[Bird.FRIEND,FlyDestinations.visit_flag("route24"),RoadAccess.SAFFRON_VISITED]
	game=fixture("blastoise");hop(game);space(game);game.bird_event.choose_destination("route24")
	assert_eq(game.bird_event.phase,"calling");assert_false(game.bird_event.self_flight)
	assert_eq(game.bird_event.helper.species_id,"pidgeot")
