extends GutTest
const Game=preload("res://scripts/game.gd")
const Puzzle=preload("res://scripts/story/seafoam_puzzle.gd")
const Data=Puzzle.Data
const SOLUTIONS="res://test/fixtures/seafoam_puzzle_solutions.json"
var old_path: String
var old_bot_puzzles: Dictionary
var old_flags: Array
class Still:
	extends RefCounted
	func move_dir(_w):return Vector2.ZERO
	func aim_point(w):return w.player.position+Vector2.UP*80
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func before_each() -> void:
	old_path=SaveData.path;SaveData.path="user://save_seafoam_puzzle_test.cfg";SaveData.clear()
	old_bot_puzzles=Game.bot_puzzles;old_flags=Game.bot_events
	Game.bot_puzzles={};Game.bot_events=[]

func after_each() -> void:
	SaveData.clear();SaveData.path=old_path;Game.bot_puzzles=old_bot_puzzles;Game.bot_events=old_flags
	Game.destination={};Game.carry={};Game.arena_trip={}
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func fixture(place: String="seafoam_islands_1f",puzzles: Dictionary={},human: bool=false):
	var bot:=OS.get_environment("BOT");var where:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","0" if human else "1");OS.set_environment("DUNGEON",place)
	Game.starter="charmander";Game.bot_puzzles=puzzles.duplicate(true);Game.destination={};Game.carry={};Game.arena_trip={}
	var game=load("res://scenes/main.tscn").instantiate();add_child_autofree(game);game.set_process(false)
	game.world.player.controller=Still.new();game.world.player.repel_steps=999999
	game.dialog_text="";game.dialog_t=0;game.status_messages.clear();game.status_message_active=false
	OS.set_environment("BOT",bot);OS.set_environment("DUNGEON",where)
	return game

func action(game,entry: Dictionary) -> bool:
	var p: Player=game.world.player
	p.position=Arena.tile_center(Data.vec(entry.stand));p.facing=Vector2(Data.vec(entry.direction))
	if Arena.resolve(p.position,p.radius).distance_to(p.position)>0.1:return false
	var key:=InputEventKey.new();key.physical_keycode=KEY_SPACE;key.pressed=true
	game._unhandled_input(key)
	if game.state!="seafoam_event":return false
	game.advance(0.23)
	if game.seafoam.phase=="rock_fall":game.advance(0.31)
	return game.state=="fight"

func solved() -> Dictionary:
	var result:=Data.initial()
	for record in result.boulders.values():
		while Data.data().objects[record.stage].reveal!="":
			var next: Dictionary=Data.data().objects[Data.data().objects[record.stage].reveal]
			record.stage=next.flag;record.floor=next.floor;record.tile=next.tile.duplicate()
	result.stopped=["seafoam_islands_b3f","seafoam_islands_b4f"]
	return {Data.ID:result}

func test_native_six_roots_eight_holes_and_arrival_tiles_are_preserved() -> void:
	assert_eq(Data.initial().boulders.size(),6)
	var total:=0
	for floor in Data.data().floors.values():total+=floor.holes.size()
	assert_eq(total,8)
	var game=fixture("seafoam_islands_b1f")
	assert_eq(game.seafoam.rocks.size(),0,"Lower boulders appear only after falling from above")
	assert_true(Arena.warp_at(Arena.tile_center(Vector2i(21,8))).is_empty(),"Fall arrivals never act as stairs back upward")
	assert_false(Arena.warp_at(Arena.tile_center(Vector2i(23,8))).is_empty(),"Actual fall hole remains active")
	assert_true(ResourceLoader.exists("res://assets/npcs/strength_boulder.png"))

func test_space_pushes_one_tile_and_moves_player_without_growth_or_resource_cost() -> void:
	var game=fixture();var entries: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOLUTIONS))
	var first: Dictionary=entries.seafoam_islands_1f[0]
	var hp: int=game.world.player.hp;var pp: Array=game.world.player.pp.duplicate();var exp: int=game.world.player.exp_total
	assert_true(action(game,first))
	assert_eq(game.world.player.position,Arena.tile_center(Data.vec(first.from)))
	assert_eq(game.world.player.hp,hp);assert_eq(game.world.player.pp,pp);assert_eq(game.world.player.exp_total,exp)
	assert_true(Arena._dynamic_solid.has(Data.vec(first.to)))
	assert_false(Arena._dynamic_solid.has(Data.vec(first.from)))

func test_original_board_solutions_really_complete_both_current_puzzles() -> void:
	var solutions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOLUTIONS))
	var progress: Dictionary={}
	var pushes:=0
	for floor in ["seafoam_islands_1f","seafoam_islands_b1f","seafoam_islands_b2f","seafoam_islands_b3f"]:
		var game=fixture(floor,progress)
		for entry in solutions[floor]:
			assert_true(action(game,entry),floor+": "+str(entry));pushes+=1
		progress=game.puzzles.duplicate(true)
	assert_gt(pushes,20)
	assert_true(progress[Data.ID].stopped.has("seafoam_islands_b3f"))
	assert_true(progress[Data.ID].stopped.has("seafoam_islands_b4f"))
	var game=fixture("seafoam_islands_b4f",progress)
	assert_true(String(Arena.theme.map).ends_with("_calm"))
	assert_eq(game.seafoam.rocks.size(),2)
	for rock in game.seafoam.rocks:assert_false(rock.pushable)

func test_boulders_block_walking_swimming_and_water_only_enemies() -> void:
	var game=fixture("seafoam_islands_b4f",solved())
	for rock in game.seafoam.rocks:
		for terrain in [0,1,2]:assert_true(Arena.terrain_blocked(rock.tile,terrain))
		assert_gt(Arena.resolve(rock.position,6,false,2).distance_to(rock.position),1.0)
	var outside=fixture("kanto_world")
	assert_eq(Arena._dynamic_solid.size(),outside.road_gates.bridge_cells.size()+outside.road_gates.snorlax_cells.size(),"Only this map's road gates remain; cave boulders are cleared")

func test_walls_and_other_boulders_cannot_be_pushed_through() -> void:
	var game=fixture("seafoam_islands_b3f");var event=game.seafoam
	var rock=event.rocks.filter(func(n):return n.tile==Vector2i(12,16))[0]
	game.world.player.position=Arena.tile_center(Vector2i(12,17));game.world.player.facing=Vector2.UP
	assert_true(event.push(rock));game.advance(0.23)
	# The upper shaft ends at a wall. A blocked push must retain the last position.
	game.world.player.position=Arena.tile_center(Vector2i(12,16));game.world.player.facing=Vector2.UP
	assert_true(event.push(rock));game.advance(0.23)
	var before: Vector2=rock.position
	game.world.player.position=Arena.tile_center(Vector2i(12,15));game.world.player.facing=Vector2.UP
	assert_false(event.push(rock));assert_eq(rock.position,before)
	event.reset_floor()
	rock=event.rocks.filter(func(n):return n.tile==Vector2i(12,16))[0]
	game.world.player.position=Arena.tile_center(Vector2i(11,16));game.world.player.facing=Vector2.RIGHT
	assert_false(event.push(rock),"The neighboring boulder occupies the destination")

func test_menu_pause_and_invalid_states_do_not_advance_or_start_a_push() -> void:
	var game=fixture();var rock=game.seafoam.rocks[0]
	game.world.player.position=Arena.tile_center(rock.tile+Vector2i.DOWN);game.world.player.facing=Vector2.UP
	game.state="menu";assert_false(game.seafoam.push(rock))
	game.state="fight";game.world.player.travel_terrain=2;assert_false(game.seafoam.push(rock))
	game.world.player.travel_terrain=0;game.world.player.dead=true;assert_false(game.seafoam.push(rock))
	game.world.player.dead=false;assert_true(game.seafoam.push(rock))
	game.state="menu";game.advance(3.0)
	assert_eq(game.seafoam.elapsed,0.0)
	assert_eq(rock.position,game.seafoam.from)

func test_saved_positions_and_fallen_progress_survive_without_touching_other_events() -> void:
	SaveData.store_progress("events","friend_lapras_surf")
	var game=fixture("seafoam_islands_1f",{},true)
	var solutions: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOLUTIONS))
	for entry in solutions.seafoam_islands_1f:assert_true(action(game,entry))
	var saved:=SaveData.load_saved()
	assert_true(saved.events.has("friend_lapras_surf"))
	assert_eq(saved.field_puzzles[Data.ID],game.puzzles[Data.ID])
	var resumed=fixture("seafoam_islands_b1f",{},true)
	assert_eq(resumed.seafoam.rocks.size(),2)
	game._carry_out();assert_eq(Game.carry.field_puzzles,game.puzzles)

func test_reset_menu_restores_current_floor_and_preserves_completed_water_blocks() -> void:
	var progress:=solved();var game=fixture("seafoam_islands_b3f",progress)
	var moving=game.seafoam.rocks.filter(func(n):return n.pushable)[0]
	var original: Vector2i=moving.tile
	# Simulate an inconvenient saved position, then use the actual game menu.
	game.seafoam.state.boulders[moving.root].tile=[original.x,original.y+1]
	game.seafoam._spawn_rocks();game._open_game_menu()
	var reset_index: int=game.menu_ids.find("reset")
	assert_gte(reset_index,0,"The boulder reset action is available")
	game._resolve_menu(reset_index)
	assert_eq(game.state,"fight")
	assert_true(game.seafoam.state.stopped.has("seafoam_islands_b3f"))
	assert_eq(game.seafoam.rocks.filter(func(n):return not n.pushable).size(),2)
	assert_eq(Data.vec(game.seafoam.state.boulders[moving.root].tile),original)

func test_strong_b4_current_returns_swimmer_to_safe_land_until_boulders_arrive() -> void:
	var game=fixture("seafoam_islands_b4f");var p: Player=game.world.player
	p.position=Arena.tile_center(Vector2i(8,16));p.travel_terrain=2
	assert_true(game.seafoam.check_environment())
	assert_eq(game.state,"seafoam_event")
	assert_eq(game.seafoam.path.back(),Arena.tile_center(Vector2i(12,12)))
	game.advance(30.0)
	assert_eq(game.state,"fight");assert_eq(p.travel_terrain,0)
	assert_lt(Arena.resolve(p.position,p.radius).distance_to(p.position),0.1)
	var calm=fixture("seafoam_islands_b4f",solved())
	calm.world.player.position=Arena.tile_center(Vector2i(8,16));calm.world.player.travel_terrain=2
	assert_false(calm.seafoam.check_environment())

func test_b3_current_reaches_the_native_lower_floor_outlet() -> void:
	var game=fixture("seafoam_islands_b3f")
	game.world.player.position=Arena.tile_center(Vector2i(23,9));game.world.player.travel_terrain=2
	assert_true(game.seafoam.check_environment())
	assert_eq(game.seafoam.path.back(),Arena.tile_center(Vector2i(26,18)))
	for point in game.seafoam.path:assert_true(Arena.is_water(Arena.tile_of(point)) or Arena.tile_of(point) in [Vector2i(23,8),Vector2i(24,8)])

func test_player_holes_fall_downward_and_save_from_a_safe_previous_tile() -> void:
	var game=fixture();var p: Player=game.world.player
	p.position=Arena.tile_center(Vector2i(21,8));p.facing=Vector2.UP
	game._check_warp()
	assert_eq(game.state,"seafoam_event");assert_eq(game.seafoam.phase,"player_fall")
	assert_eq(game.seafoam.fall_target.floor,"seafoam_islands_b1f")
	assert_eq(Data.vec(game.seafoam.fall_target.arrival),Vector2i(21,8))
	game.advance(0.1);assert_lt(p.modulate.a,1.0)

func test_calm_layouts_keep_water_at_floor_height_and_ladders_open() -> void:
	for place in ["seafoam_islands_b3f","seafoam_islands_b4f"]:
		var game=fixture(place,solved());var path: String=Arena.theme.map
		assert_true(path.ends_with("_calm"))
		var geometry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path+"/hd2d_cards.json"))
		for tile in Arena._water:assert_eq(float(geometry.heightfield.heights[tile.y][tile.x]),0.0)
		assert_true(game.seafoam.stopped())
