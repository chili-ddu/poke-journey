extends GutTest
const Game=preload("res://scripts/game.gd")
const Access=preload("res://scripts/data/road_access.gd")
var old_path: String

func before_each() -> void:
	old_path=SaveData.path;SaveData.path="user://save_road_gates_test.cfg";SaveData.clear()

func after_each() -> void:
	SaveData.clear();SaveData.path=old_path
	Game.bot_events=[];Game.destination={};Game.carry={};Game.arena_trip={}
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func fixture(flags: Array=[], place: String="kanto_world", at: Vector2=Vector2.INF):
	var location:=OS.get_environment("DUNGEON");var bot:=OS.get_environment("BOT")
	OS.set_environment("BOT","1");OS.set_environment("DUNGEON",place)
	Game.bot_events=flags.duplicate();Game.destination={};Game.carry={};Game.arena_trip={}
	if at!=Vector2.INF:Game.destination={"pos":at,"layout":1}
	var game=load("res://scenes/main.tscn").instantiate();add_child_autofree(game);game.set_process(false)
	OS.set_environment("BOT",bot);OS.set_environment("DUNGEON",location)
	return game

func test_bridge_blocks_both_lanes_and_surf_until_saffron_visit() -> void:
	var game=fixture()
	var region:=Arena.area_rect("route24")
	assert_eq(game.road_gates.construction.size(),6)
	for x in range(region.position.x,region.end.x):
		for terrain in [0,1,2]:
			assert_true(Arena.terrain_blocked(Vector2i(x,region.end.y-1),terrain))
	var lane:=region.position+Vector2i(11,39)
	var at:=Arena.tile_center(lane)
	assert_gt(Arena.resolve(at,game.world.player.radius,true).distance_to(at),0.1,"Jump cannot cross the construction")
	game.events.append(Access.SAFFRON_VISITED);game.road_gates.refresh()
	assert_false(Arena.solid_at(lane.x,lane.y))
	assert_true(game.road_gates.construction.is_empty())
	assert_lt(Arena.resolve(at,game.world.player.radius).distance_to(at),0.1)

func test_saffron_visited_save_loads_open_bridge_but_sleeping_snorlax() -> void:
	var game=fixture([Access.SAFFRON_VISITED])
	assert_true(game.road_gates.bridge_cells.is_empty())
	assert_not_null(game.road_gates.sleeper)
	assert_true(game.road_gates.sleeper.is_asleep())
	assert_false(game.world.enemies.has(game.road_gates.sleeper))

func _reachable(start: Vector2i, bounds: Rect2i) -> Dictionary:
	var queue: Array[Vector2i]=[start]
	var seen: Dictionary={start:true};var cursor:=0
	while cursor<queue.size():
		var at:=queue[cursor];cursor+=1
		for direction in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i=at+direction
			if seen.has(next) or not bounds.has_point(next) or Arena.terrain_blocked(next):continue
			seen[next]=true;queue.append(next)
	return seen

func test_diglett_cave_to_vermilion_lane_stays_open_but_eastern_road_is_blocked() -> void:
	var game=fixture()
	var region:=Arena.area_rect("route11")
	var cave:=region.position+Vector2i(6,7)
	assert_eq(Arena.warp_at(Arena.tile_center(cave)).to,"digletts_cave_south_entrance")
	assert_false(Arena.solid_at(cave.x,cave.y))
	var seen:=_reachable(cave,Rect2i(region.position-Vector2i(2,0),Vector2i(20,20)))
	assert_true(seen.has(region.position+Vector2i(-1,9)),"Cave exit reaches Vermilion")
	assert_false(seen.has(region.position+Vector2i(14,9)),"Cave exit cannot bypass Snorlax")
	for terrain in [0,1,2]:
		for cell in game.road_gates.snorlax_cells:assert_true(Arena.terrain_blocked(cell,terrain))

func test_talking_and_saffron_do_not_wake_snorlax() -> void:
	var game=fixture([Access.SAFFRON_VISITED])
	var actor: Npc=game.road_gates.sleep_talk
	game.world.player.position=actor.position+Vector2.LEFT*Arena.TILE*1.5
	assert_true(actor.can_talk(game.world.player.position),"Hidden interaction proxy remains usable")
	game._talk(actor)
	assert_eq(game.state,"talk")
	assert_false(game.events.has(Access.SNORLAX_AWAKENED))
	assert_not_null(game.road_gates.sleeper)

func test_only_explicit_wake_event_clears_collision_and_persists() -> void:
	var game=fixture()
	var center:=Arena.area_rect("route11").position+Vector2i(10,9)
	game.bot=false
	game.road_gates.complete_snorlax_event()
	game.road_gates.complete_snorlax_event()
	assert_eq(game.events.count(Access.SNORLAX_AWAKENED),1)
	assert_true(SaveData.load_saved().get("events",[]).has(Access.SNORLAX_AWAKENED))
	assert_null(game.road_gates.sleeper)
	assert_false(Arena.solid_at(center.x,center.y))
	var reloaded=fixture([Access.SNORLAX_AWAKENED])
	assert_null(reloaded.road_gates.sleeper)
	assert_false(Arena.solid_at(center.x,center.y))
	assert_false(reloaded.road_gates.bridge_cells.is_empty(),"Snorlax completion never opens Route 24")

func test_old_visited_fly_flags_do_not_bypass_closed_roads() -> void:
	for id in ["route24","route25","route11"]:
		var flags: Array=[FlyDestinations.visit_flag(id)]
		assert_false(FlyDestinations.can_fly(id,flags))
		flags.append(Access.SAFFRON_VISITED)
		assert_eq(FlyDestinations.can_fly(id,flags),id!="route11")
		flags.append(Access.SNORLAX_AWAKENED)
		assert_true(FlyDestinations.can_fly(id,flags))

func test_legacy_local_maps_share_the_same_gates() -> void:
	for place in ["cerulean_north","route11"]:
		var game=fixture([],place)
		if place=="cerulean_north":assert_false(game.road_gates.bridge_cells.is_empty())
		else:assert_not_null(game.road_gates.sleeper)
		game.free()

func test_old_northern_arrival_is_not_stranded_behind_new_construction() -> void:
	var game=fixture([],"kanto_world",Arena.tile_center(Vector2i(287,25)))
	assert_eq(Arena.area_at(game.world.player.position),"cerulean_city")
	assert_false(game.events.has(Access.SAFFRON_VISITED))
	assert_false(game.road_gates.bridge_cells.is_empty())

func test_unlocked_northern_arrival_keeps_its_original_position() -> void:
	var at:=Arena.tile_center(Vector2i(287,25))
	var game=fixture([Access.SAFFRON_VISITED],"kanto_world",at)
	assert_lt(game.world.player.position.distance_to(at),0.1)
