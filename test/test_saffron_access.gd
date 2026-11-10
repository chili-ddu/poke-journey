extends GutTest
const Game=preload("res://scripts/game.gd")
const Bird=preload("res://scripts/story/bird_event.gd")
var old_path: String
var old_events: Array

func before_each() -> void:
	old_path=SaveData.path;SaveData.path="user://save_saffron_access_test.cfg";SaveData.clear()
	old_events=Game.bot_events.duplicate();Game.bot_events=[]
	Game.destination={};Game.carry={};Game.arena_trip={}

func after_each() -> void:
	SaveData.clear();SaveData.path=old_path;Game.bot_events=old_events
	Game.destination={};Game.carry={};Game.arena_trip={}
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func fixture(place: String):
	var bot:=OS.get_environment("BOT");var location:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","1");OS.set_environment("DUNGEON",place)
	var game=load("res://scenes/main.tscn").instantiate();add_child_autofree(game);game.set_process(false)
	OS.set_environment("BOT",bot);OS.set_environment("DUNGEON",location)
	return game

func test_both_gates_enter_saffron_with_no_items_or_story_progress() -> void:
	for place in ["route5_south_entrance","route6_north_entrance"]:
		var game=fixture(place)
		game.events.clear();game.beaten.clear();game.world.player.bag.clear()
		game._lock_doors()
		var exits: Array=Arena.warps().filter(func(w):return w.to=="saffron_city")
		assert_eq(exits.size(),2)
		for exit in exits:
			var tile:=Vector2i(int(exit.x),int(exit.y))
			assert_false(Arena.solid_at(tile.x,tile.y),"No Tea, badge, Bill or Silph condition blocks the gate")
			assert_lt(Arena.resolve(Arena.tile_center(tile),game.world.player.radius).distance_to(Arena.tile_center(tile)),0.1)
		game.world.player.position=Arena.tile_center(Vector2i(int(exits[0].x),int(exits[0].y)))
		game.warp_armed=true;game._check_warp()
		assert_eq(game.state,"warp");assert_eq(Game.destination.map,"saffron_city")
		game.free();Game.destination={}

func test_city_north_and_south_gates_are_connected_on_foot() -> void:
	var game=fixture("saffron_city")
	var start:=Arena.warp_tile("saffron_city",9)
	var goal:=Arena.warp_tile("saffron_city",11)
	var seen: Dictionary={start:true};var queue: Array[Vector2i]=[start];var cursor:=0
	while cursor<queue.size() and not seen.has(goal):
		var at:=queue[cursor];cursor+=1
		for direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
			var next: Vector2i=at+direction
			if seen.has(next) or Arena.solid_at(next.x,next.y):continue
			var point:=Arena.tile_center(next)
			if Arena.resolve(point,game.world.player.radius).distance_to(point)>0.1:continue
			if next!=goal and not Arena.warp_at(point).is_empty():continue
			seen[next]=true;queue.append(next)
	assert_true(seen.has(goal),"Walk through Saffron from Route 5 to Route 6 without Underground Path")
	assert_eq(Arena.warp_at(Arena.tile_center(start)).to,"route5_south_entrance")
	assert_eq(Arena.warp_at(Arena.tile_center(goal)).to,"route6_north_entrance")

func test_native_city_and_services_load_with_reciprocal_supported_doors() -> void:
	for place in DungeonDB.Saffron.DUNGEONS:
		var game=fixture(place)
		assert_true(View3D.supported(DungeonDB.theme().map))
		for warp in Arena.warps():
			if not DungeonDB.WARP_MAPS.has(warp.to):continue
			var dest: String=DungeonDB.WARP_MAPS[warp.to]
			var cfg: Dictionary=DungeonDB.THEMES[DungeonDB.DUNGEONS[dest].theme]
			var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(cfg.map+"/map.json"))
			assert_true(data.warps.any(func(other):return other.map==warp.to and int(other.index)==int(warp.to_warp)))
		if place.ends_with("pokemon_center_1f"):
			var nurse: Npc=game.world.npcs.filter(func(n):return n.talk=="nurse")[0]
			assert_ne(nurse.heal_spot,Vector2.INF)
			assert_false(Arena.warps().any(func(w):return String(w.to).ends_with("_2f")))
		elif place.ends_with("mart"):
			assert_true(game.world.npcs.any(func(n):return n.talk=="shop"))
		assert_ne(Bgm.place(place),"")
		game.free()

func test_fly_requires_a_visit_and_can_be_called_inside_the_open_city() -> void:
	assert_true(FlyDestinations.find("saffron_city").enabled)
	assert_false(FlyDestinations.can_fly("saffron_city",[Bird.FRIEND]))
	assert_true(FlyDestinations.can_fly("saffron_city",[Bird.FRIEND,FlyDestinations.visit_flag("saffron_city")]))
	var game=fixture("saffron_city")
	game.events.append(Bird.FRIEND)
	game.world.player.position=FlyDestinations.position_of(FlyDestinations.find("saffron_city"))
	assert_true(game.bird_event.can_land(game.world.player.position))
	game.world._start_hop(game.world.player.position+Vector2.UP*Arena.TILE)
	assert_true(game.bird_event.press_space())
	assert_eq(game.menu,"fly")
