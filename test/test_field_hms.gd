extends GutTest

const Game=preload("res://scripts/game.gd")
const HMs=Game.FieldHMs
const Cut=preload("res://scripts/story/forest_rescue.gd")
const Surf=preload("res://scripts/story/lapras_escape.gd")
const Flash=preload("res://scripts/story/pikachu_rescue.gd")
const Bird=preload("res://scripts/story/bird_event.gd")
const DT=1.0/60.0
const PATH="user://save_direct_field_hm_test.cfg"
var previous: Dictionary={}

class Still:
	extends RefCounted
	var moving:=Vector2.ZERO
	func move_dir(_w):return moving
	func aim_point(w):return w.player.position+Vector2.UP*80
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func before_each() -> void:
	previous={"path":SaveData.path,"events":Game.bot_events.duplicate(),"starter":Game.starter}
	SaveData.path=PATH;SaveData.clear()

func after_each() -> void:
	SaveData.clear();SaveData.path=previous.path;Game.bot_events=previous.events;Game.starter=previous.starter
	Game.destination={};Game.carry={};Game.arena_trip={}
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func open(species: String="charmander",place: String="kanto_world",flags: Array=[],human: bool=false):
	var bot:=OS.get_environment("BOT");var where:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","0" if human else "1");OS.set_environment("DUNGEON","" if human else place)
	for flag in flags:SaveData.store_progress("events",flag)
	Game.starter=species;Game.bot_events=flags.duplicate();Game.destination={};Game.carry={};Game.arena_trip={}
	var game=load("res://scenes/main.tscn").instantiate();add_child_autofree(game);game.set_process(false)
	OS.set_environment("BOT",bot);OS.set_environment("DUNGEON",where)
	game.world.god=true;game.world.player.controller=Still.new()
	if game.state in ["fight","town"]:game.dialog_text="";game.dialog_t=0.0
	game.status_messages.clear();game.status_message_active=false
	return game

func tree_near(game) -> Npc:
	for tree: Npc in game.field_friends.trees:
		for d in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]:
			var at:=Arena.tile_center(tree.tile+d)
			if Arena.is_water(Arena.tile_of(at)) or Arena.resolve(at,game.world.player.radius).distance_to(at)>0.1:continue
			game.world.player.position=at;game.world.player.facing=(tree.position-at).normalized()
			if game.npc_in_reach()==tree:return tree
	return null

func shore(game) -> void:
	game.world.player.position=Arena.tile_center(Arena.area_rect("route19").position+Surf.Data.BEACH_PLAYER)
	game.world.player.facing=Vector2.DOWN

func space(game) -> void:
	var key:=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true;game._unhandled_input(key)

func test_water_object_without_surf_uses_action_menu_instead_of_jump() -> void:
	var game=open();shore(game)
	var pp: Array=game.world.player.pp.duplicate()
	space(game)
	assert_eq(game.state,"menu");assert_eq(game.menu,"water")
	assert_eq(game.world.player.hop_t,0.0)
	assert_eq(game.world.player.pp,pp)

func test_compatibility_uses_native_machine_data_including_gen4_flash_tm70() -> void:
	for sid in SpeciesDB.all_ids():
		var machines: Array=SpeciesDB.get_species(sid).tms
		for move in HMs.MACHINES:assert_eq(HMs.compatible(sid,move),HMs.MACHINES[move] in machines)
	assert_true(HMs.compatible("bulbasaur","flash"));assert_false(HMs.compatible("charmander","flash"))
	assert_true(HMs.compatible("doduo","fly"));assert_false(HMs.compatible("butterfree","fly"))
	assert_false(HMs.compatible("charmander","not_a_move"))

func test_friend_progress_teaches_only_compatible_moves_without_equipping_or_changing_pp() -> void:
	for sid in ["bulbasaur","charmander","squirtle","charizard"]:
		var p:=Player.new();p.setup_player(sid,5,["tackle"],{})
		var slots:=p.slots.duplicate();var pp:=p.pp.duplicate()
		assert_true(HMs.sync(p,[]).is_empty())
		var moves:=HMs.sync(p,HMs.SOURCES.values())
		for move in HMs.SOURCES:assert_eq(p.known_moves().has(move),HMs.compatible(sid,move))
		assert_eq(p.slots,slots);assert_eq(p.pp,pp);assert_true(HMs.sync(p,HMs.SOURCES.values()).is_empty())
		assert_false(moves.is_empty());p.free()

func test_actual_friend_reward_hooks_teach_and_save_the_move() -> void:
	var game=open("charmander",Cut.PLACE,[RoadAccess.SAFFRON_VISITED]);game.bot=false;game.forest_rescue._befriend()
	assert_true(game.world.player.known_moves().has("cut"));assert_true(SaveData.load_saved().learned.has("cut"));game.free()
	SaveData.clear();game=open("bulbasaur","vermilion_city_gym");game.bot=false
	game._begin_battle(game.trainers[0]);game._trainer_defeated()
	assert_true(game.world.player.known_moves().has("flash"));assert_true(SaveData.load_saved().learned.has("flash"));game.free()
	SaveData.clear();game=open("squirtle","cerulean_city_gym",[RoadAccess.SAFFRON_VISITED,"quest_moon_mining_complete"]);game.bot=false
	game._begin_battle(game.trainers[0]);game._trainer_defeated()
	assert_true(game.events.has(Surf.FRIEND));assert_true(game.world.player.known_moves().has("surf"));assert_true(SaveData.load_saved().learned.has("surf"));game.free()
	SaveData.clear();game=open("charizard");game.bot=false
	game.bird_event._spawn_helper("pidgeotto",game.world.player.position);game.bird_event._befriend()
	assert_true(game.world.player.known_moves().has("fly"));assert_true(SaveData.load_saved().learned.has("fly"))

func test_legacy_friend_save_is_migrated_once_without_losing_growth_or_slots() -> void:
	var game=open("charmander","kanto_world",[Cut.FRIEND]);game.bot=false
	game.world.player.learned.erase("cut");game._save_here()
	var before:=SaveData.load_saved();game.free()
	var resumed=open("charmander","kanto_world",[],true)
	var after:=SaveData.load_saved()
	assert_true(resumed.world.player.known_moves().has("cut"));assert_true(after.learned.has("cut"))
	for key in ["level","exp","pid","ivs","slots","bag"]:assert_eq(after[key],before[key])
	assert_true(resumed.learn_field_hms().is_empty())
	resumed.free()
	var again=open("charmander","kanto_world",[],true)
	assert_eq(again.world.player.slots,before.slots,"A later reload cannot auto-equip a field HM into empty slots")
	assert_true(again.world.player.spare_moves().has("cut"),"The move remains available for optional combat equipment")

func test_self_cut_uses_normal_space_without_a_helper_or_combat_slot() -> void:
	var game=open("charmander","kanto_world",[Cut.FRIEND]);var p: Player=game.world.player
	var tree:=tree_near(game);assert_not_null(tree)
	var id:=tree.id;var tile:=tree.tile;var at:=p.position;var pp:=p.pp.duplicate()
	assert_false(p.slots.has("cut"));space(game)
	assert_eq(game.field_friends.phase,"self_cut");assert_null(game.field_friends.helper)
	for frame in 240:
		if game.state!="field_cut":break
		game.advance(DT)
	assert_false(Arena.solid_at(tile.x,tile.y));assert_true(game.events.has(id))
	assert_eq(p.position,at);assert_eq(p.pp,pp);assert_eq(p.attack_contact_hold,0.0)
	assert_eq(game.field_friends.phase,"idle");assert_null(game.field_friends.helper)

func test_incompatible_cut_still_calls_scyther() -> void:
	var game=open("squirtle","kanto_world",[Cut.FRIEND])
	var tree:=tree_near(game);assert_not_null(tree);space(game)
	assert_false(game.world.player.known_moves().has("cut"));assert_eq(game.field_friends.phase,"calling")
	game.advance(0.6);assert_eq(game.field_friends.helper.species_id,"scyther")
	for frame in 480:
		if game.state!="field_cut":break
		game.advance(DT)
	assert_eq(game.field_friends.phase,"idle");assert_null(game.field_friends.helper)

func test_self_surf_crosses_the_shore_and_resumes_from_water_without_lapras() -> void:
	var game=open("squirtle","kanto_world",[Surf.FRIEND]);game.bot=false;shore(game)
	var p: Player=game.world.player;var pp:=p.pp.duplicate();var at:=p.position
	assert_false(p.slots.has("surf"));assert_true(game.lapras_escape.can_call());space(game)
	assert_eq(game.lapras_escape.phase,"self_surf");assert_null(game.lapras_escape.helper)
	game.advance(0.2);assert_gt(p.position.distance_to(at),0.0)
	game.advance(0.3)
	assert_eq(p.travel_terrain,2);assert_true(Arena.is_water(Arena.tile_of(p.position)))
	assert_true(p.get_meta("self_surf",false));assert_false(p.has_meta("lapras_ride"));assert_eq(p.pp,pp)
	game._save_here();var water_at:=p.position;game.free()
	var resumed=open("squirtle","kanto_world",[],true);resumed.advance(DT)
	assert_eq(resumed.world.player.position,water_at);assert_eq(resumed.world.player.travel_terrain,2)
	assert_true(resumed.world.player.known_moves().has("surf"));assert_null(resumed.lapras_escape.helper)
	assert_false(resumed.world.player.has_meta("lapras_ride"))

func test_incompatible_surf_still_calls_and_rides_lapras() -> void:
	var game=open("charmander","kanto_world",[Surf.FRIEND]);shore(game);space(game)
	assert_eq(game.lapras_escape.phase,"calling");assert_false(game.world.player.known_moves().has("surf"))
	game.advance(0.4);game.advance(0.7)
	assert_true(is_instance_valid(game.lapras_escape.helper));assert_true(game.world.player.has_meta("lapras_ride"))

func test_self_flash_centers_both_light_and_vision_on_the_player() -> void:
	var game=open("bulbasaur","rock_tunnel_1f",[Flash.FRIEND]);var event=game.pikachu_rescue
	assert_true(game.world.player.known_moves().has("flash"));assert_true(event.self_flash);assert_null(event.helper)
	assert_eq(event.helper_lamp.get_parent(),game.world.player)
	for frame in 50:game.advance(DT)
	event.update_light();assert_eq(event.brightness,1.0)
	var material: ShaderMaterial=event.veil.material
	assert_eq(material.get_shader_parameter("helper_center"),event._screen(game.world.player))
	assert_eq(material.get_shader_parameter("helper_strength"),1.0)
	assert_true(game.world.player.get_meta("flash_helper",false))
	game.free()
	var fallback=open("charmander","rock_tunnel_1f",[Flash.FRIEND])
	assert_false(fallback.pikachu_rescue.self_flash);assert_eq(fallback.pikachu_rescue.helper.species_id,"pikachu")

func test_fly_learning_and_carrier_choice_follow_hm_compatibility_not_visible_wings() -> void:
	for species in ["charizard","butterfree"]:
		var game=open(species,"kanto_world",[Bird.FRIEND,FlyDestinations.visit_flag("route24"),RoadAccess.SAFFRON_VISITED])
		game.world.player.position=Arena.tile_center(Arena.area_rect("pallet_town").position+Vector2i(11,9))
		game.world._start_hop(game.world.player.position+Vector2.UP*24);space(game)
		assert_eq(game.menu,"fly");game.bird_event.choose_destination("route24")
		assert_eq(game.world.player.known_moves().has("fly"),species=="charizard")
		assert_eq(game.bird_event.self_flight,species=="charizard")
		if species=="charizard":assert_null(game.bird_event.helper)
		else:assert_true(is_instance_valid(game.bird_event.helper))
		game.free()

func test_evolution_unlocks_a_previously_incompatible_hm_and_saves_it() -> void:
	var game=open("charmeleon","kanto_world",[Bird.FRIEND]);game.bot=false
	assert_false(game.world.player.known_moves().has("fly"))
	game.world.player.evolve_to("charizard")
	var slots: Array=game.world.player.slots.duplicate();var pp: Array=game.world.player.pp.duplicate()
	game.resume_state="fight";game._on_evolve_finished(true)
	assert_true(game.world.player.known_moves().has("fly"));assert_true(SaveData.load_saved().learned.has("fly"))
	assert_eq(game.world.player.slots,slots);assert_eq(game.world.player.pp,pp)
