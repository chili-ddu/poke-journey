extends GutTest
const Game=preload("res://scripts/game.gd")
const Travel=preload("res://scripts/data/kanto_world_travel.gd")
var old_path: String

func before_each() -> void:
	old_path=SaveData.path;SaveData.path="user://save_kanto_world_test.cfg";SaveData.clear()

func after_each() -> void:
	SaveData.clear();SaveData.path=old_path
	Game.destination={};Game.carry={};Game.arena_trip={};Game.bot_events=[]
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func fixture():
	var place:=OS.get_environment("DUNGEON");var bot:=OS.get_environment("BOT")
	OS.set_environment("BOT","1");OS.set_environment("DUNGEON","kanto_world")
	Game.starter="charmander";Game.destination={};Game.carry={};Game.arena_trip={};Game.bot_events=[]
	var game=load("res://scenes/main.tscn").instantiate();add_child_autofree(game);game.set_process(false)
	OS.set_environment("DUNGEON",place);OS.set_environment("BOT",bot)
	return game

func test_mainland_contains_every_native_road_and_outdoor_city_without_edge_warps() -> void:
	DungeonDB.set_current(Travel.ID);Arena.configure(DungeonDB.theme())
	assert_eq(Vector2i(Arena.map.width,Arena.map.height),Vector2i(408,400))
	assert_eq(Arena._areas.filter(func(a):return not String(a.id).begins_with("johto_")).size(),36)
	for i in range(1,26):
		var id: String="route"+str(i)
		assert_true(DungeonDB.WARP_MAPS.has(id) or i==21)
		if i==21:
			assert_ne(Arena.area_rect("route21_north").size,Vector2i.ZERO)
			assert_ne(Arena.area_rect("route21_south").size,Vector2i.ZERO)
		else:
			assert_eq(DungeonDB.WARP_MAPS[id],Travel.ID)
			assert_ne(Arena.area_rect(id).size,Vector2i.ZERO)
	for id in ["pallet_town","viridian_city","pewter_city","cerulean_city","vermilion_city","lavender_town","celadon_city","fuchsia_city","cinnabar_island","indigo_plateau_exterior"]:
		assert_ne(Arena.area_rect(id).size,Vector2i.ZERO)
	assert_eq(DungeonDB.WARP_MAPS.saffron_city,"saffron_city","Actual Saffron stays connected through its original gates")
	for warp in Arena.warps():assert_false(warp.get("edge_transition",false),"Outdoor travel never uses synthetic scene transitions")
	assert_eq(Arena.warps().filter(func(w):return not String(w.map).begins_with("johto_")).size(),129)

func test_legacy_saves_translate_once_after_their_existing_layout_migrations() -> void:
	for place in ["kanto_south","kanto_north","kanto_east","cerulean_north","kanto_rock_pass","route11"]:
		var version:=int(DungeonDB.LAYOUTS.get(place,1))
		var original={"pos":Vector2(40,80),"layout":version}
		var moved:=Travel.promote(place,original)
		var offset: Array=DungeonDB.KantoWorld.LEGACY_OFFSETS[place]
		assert_eq(moved.map,Travel.ID)
		assert_eq(moved.destination.pos,Vector2(40,80)+Vector2(offset[0],offset[1])*Arena.TILE)
		assert_eq(original.pos,Vector2(40,80),"Migration cannot mutate the saved input")
		assert_eq(Travel.promote(Travel.ID,moved.destination).destination,moved.destination,"No second translation")
	var old:=Travel.promote("kanto_south",{"pos":Vector2(12,24),"layout":1})
	assert_eq(old.destination.pos,Vector2(12,24)+Vector2(48,180)*Arena.TILE)
	assert_eq(Travel.promote("saffron_city",{"pos":Vector2(12,24)}).map,"saffron_city")

func test_route1_rival_keeps_native_position_and_route10_rescue_is_removed() -> void:
	var game=fixture()
	var route1:=Arena.area_rect("route1")
	var shift:=route1.position-Vector2i(12,180)
	game.world.player.position=Arena.tile_center(Game.RIVAL_ZONE.position+shift)
	game._check_rival()
	assert_eq(game.state,"rival")
	assert_eq(game.rival.npc.tile,Game.RIVAL_FROM+shift)
	assert_null(game.pikachu_rescue)
	assert_true(game.world.npcs.filter(func(n):return n.talk=="route10_pikachu_rescue").is_empty())

func test_normal_continue_and_resave_keep_growth_and_move_the_legacy_position_once() -> void:
	var source=fixture()
	var p: Player=source.world.player
	p.exp_total+=17;p.bag={"oran_berry":7,"potion":3}
	var landing:=FlyDestinations.position_of(FlyDestinations.find("vermilion_city"))
	var old_position:=landing-Vector2(264,160)*Arena.TILE
	SaveData.store(p,["pewter_gym"],"kanto_east",old_position)
	SaveData.store_progress("events","world_migration_event")
	SaveData.store_progress("trainers","world_migration_trainer")
	var before:=SaveData.load_saved()
	var place:=OS.get_environment("DUNGEON");var bot:=OS.get_environment("BOT")
	OS.set_environment("BOT","0");OS.set_environment("DUNGEON","")
	for _reload in 2:
		Game.destination={};Game.carry={};Game.arena_trip={};Game.bot_events=[]
		var game=load("res://scenes/main.tscn").instantiate();add_child_autofree(game);game.set_process(false)
		assert_eq(DungeonDB.current,Travel.ID)
		assert_lt(game.world.player.position.distance_to(landing),0.1)
		assert_eq(game.world.player.pid,before.pid)
		assert_eq(game.world.player.ivs,before.ivs)
		assert_eq(game.world.player.exp_total,before.exp)
		assert_eq(game.world.player.bag,before.bag)
		assert_true(game.events.has("world_migration_event"))
		assert_true(game.beaten.has("world_migration_trainer"))
		assert_true(game.cleared.has("pewter_gym"))
		game._save_here()
		var saved:=SaveData.load_saved()
		assert_eq(saved.map,Travel.ID)
		assert_lt(saved.pos.distance_to(landing),0.1)
	OS.set_environment("DUNGEON",place);OS.set_environment("BOT",bot)

func test_split_route_and_plateau_visits_unlock_only_the_matching_fly_destination() -> void:
	var game=fixture()
	for id in ["route21","indigo_plateau"]:
		var entry:=FlyDestinations.find(id)
		game.world.player.position=FlyDestinations.position_of(entry)
		game._record_area_visit()
		assert_true(FlyDestinations.can_fly(id,game.events))
	assert_false(FlyDestinations.can_fly("celadon_city",game.events))

func test_new_cave_ladders_and_water_are_at_floor_height() -> void:
	for place in ["seafoam_islands_1f","seafoam_islands_b1f","seafoam_islands_b2f","seafoam_islands_b3f","seafoam_islands_b4f","cerulean_cave_1f","cerulean_cave_2f","cerulean_cave_b1f","victory_road_1f","victory_road_2f","victory_road_3f"]:
		var dir: String="res://assets/maps/"+place+"/"
		var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(dir+"map.json"))
		var geometry: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(dir+"hd2d_cards.json"))
		var water: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(dir+"water.json"))
		assert_eq(geometry.terrain,"heightfield_cave_cliffs")
		for warp in source.warps:assert_eq(float(geometry.heightfield.heights[int(warp.y)][int(warp.x)]),0.0,"Native ladder remains open: "+place)
		for y in water.water.size():
			for x in String(water.water[y]).length():
				if water.water[y][x]=="1":assert_eq(float(geometry.heightfield.heights[y][x]),0.0,"Water cannot become a rock cliff")

func test_new_center_talk_tiles_fit_the_original_room_layout() -> void:
	for place in DungeonDB.KantoWorld.DUNGEONS:
		if not String(place).ends_with("pokemon_center_1f"):continue
		DungeonDB.set_current(place);Arena.configure(DungeonDB.theme())
		var cfg: Dictionary=DungeonDB.DUNGEONS[place].npcs[0]
		assert_eq(cfg.talk,"nurse")
		assert_true(cfg.heal_spot is Vector2)
		assert_false(Arena.solid_at(cfg.talk_tile.x,cfg.talk_tile.y),"Nurse counter approach: "+place)
