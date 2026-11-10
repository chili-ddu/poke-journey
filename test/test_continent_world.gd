extends GutTest
const Continent=preload("res://scripts/data/continent_world.gd")
const Game=preload("res://scripts/game.gd")
var previous_path: String
var previous_map: String
var previous_bot: String
var previous_skip: bool

func before_each() -> void:
	previous_path=SaveData.path;previous_map=OS.get_environment("DUNGEON");previous_bot=OS.get_environment("BOT");previous_skip=Game.skip_opening
	SaveData.path="user://continent_tests_only.cfg";SaveData.clear()
	Game.destination={};Game.carry={};Game.arena_trip={};Game.bot_events=[];Game.skip_opening=true
	OS.set_environment("BOT","1");OS.set_environment("DUNGEON","")
	DungeonDB.set_current("kanto_world");Arena.configure(DungeonDB.theme())

func after_each() -> void:
	SaveData.clear();SaveData.path=previous_path
	OS.set_environment("DUNGEON",previous_map);OS.set_environment("BOT",previous_bot)
	Game.destination={};Game.carry={};Game.arena_trip={};Game.bot_events=[];Game.skip_opening=previous_skip
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func test_all_original_exterior_areas_and_doors_share_one_field_without_changing_kanto() -> void:
	assert_true(Arena.is_continent());assert_false(Arena.is_native())
	var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/kanto_world/map.json"))
	for area in original.areas:
		assert_eq(Arena.area_rect(area.id),Rect2i(int(area.x),int(area.y),int(area.w),int(area.h)))
	for warp in original.warps:
		assert_eq(Arena.warp_at(Arena.tile_center(Vector2i(int(warp.x),int(warp.y)))),warp)
	for area in Continent.scene().areas:
		var tile:=Vector2i(int(area.x),int(area.z))+Continent.offset()
		assert_eq(Arena.area_at(Arena.tile_center(tile)),"johto_%03d" % int(area.header))
	for warp in Continent.scene().warps:
		assert_eq(Arena.warp_tile("johto_%03d" % int(warp.header),int(warp.index)),Vector2i(int(warp.x),int(warp.z))+Continent.offset())
	assert_true(Arena.bounds().has_point(Arena.tile_center(Continent.offset()+Vector2i(64,32))))
	assert_true(Arena.bounds().has_point(Arena.tile_center(Vector2i(407,399))))

func test_shifted_hgss_collision_water_grass_and_ledges_match_original_permissions() -> void:
	var source:=Continent.scene()
	for chunk in source.chunks:
		for i in range(0,1024,17):
			var raw:=Vector2i(int(chunk.x)*32+i%32,int(chunk.z)*32+i/32)
			var tile:=raw+Continent.offset()
			assert_eq(Arena.native_attributes(tile),Continent.collection().attributes(source,raw))
			assert_eq(Arena.is_water(tile),(int(chunk.attributes[i])&255) in [16,17,18,19,20,21,25,42])
			assert_eq(Arena.is_grass(tile),(int(chunk.attributes[i])&255) in [2,3])
			assert_eq(Arena.ledge_at(tile.x,tile.y),(int(chunk.attributes[i])&255)-55 if (int(chunk.attributes[i])&255) in [56,57,58,59] else 0)
			if Arena.ledge_at(tile.x,tile.y)==0:
				assert_eq(not Arena.terrain_blocked(tile,2),Continent.collection().can_stand(source,raw,true))
	assert_true(Arena.terrain_blocked(Vector2i(-500,-80),2),"New decorative mountains never create shortcuts")

func test_legacy_johto_saves_promote_once_and_rooms_stay_original() -> void:
	for place in ["johto_060","johto_073","johto_030","johto_031","johto_032","johto_090"]:
		var pos:=Continent.collection().spawn(int(place.trim_prefix("johto_")))*Arena.TILE
		var original: Dictionary={"map":place,"pos":pos,"layout":1}
		var moved:=KantoWorldTravel.promote(place,original)
		assert_eq(moved.map,"kanto_world")
		assert_eq(moved.destination.pos,pos+Vector2(Continent.offset())*Arena.TILE)
		assert_eq(original.pos,pos)
		assert_eq(KantoWorldTravel.promote(moved.map,moved.destination).destination,moved.destination)
	for place in ["johto_061","johto_126","johto_299","johto_330"]:
		assert_eq(KantoWorldTravel.promote(place,{"map":place}).map,place)

func test_normal_game_restores_negative_save_coordinates_and_growth_on_repeated_continue() -> void:
	var p:=Player.new();p.setup_player("charmander",12,["scratch","ember"],{"pid":123456,"ivs":{"hp":1,"atk":2,"def":3,"spe":4,"spa":5,"spd":6}})
	p.bag={"oran_berry":17};p.exp_total+=3
	var raw:=Vector2(684.5,394.5)*Arena.TILE
	SaveData.store(p,["pewter_gym"],"johto_060",raw);p.free()
	SaveData.store_progress("events","continent_sentinel")
	var before:=SaveData.load_saved()
	OS.set_environment("BOT","0")
	for i in 2:
		var game=load("res://scenes/main.tscn").instantiate();add_child(game);game.set_process(false)
		assert_eq(DungeonDB.current,"kanto_world")
		assert_lt(game.world.player.position.distance_to(raw+Vector2(Continent.offset())*Arena.TILE),0.1)
		assert_eq(game.world.player.pid,before.pid);assert_eq(game.world.player.ivs,before.ivs)
		assert_eq(game.world.player.exp_total,before.exp);assert_eq(game.world.player.bag,before.bag)
		assert_has(game.events,"continent_sentinel");assert_has(game.cleared,"pewter_gym")
		assert_eq(game.location_name(),"연두마을" if Lang.is_ko() else "NEW BARK")
		game._save_here();game.free()
		assert_eq(SaveData.load_saved().map,"kanto_world")

func test_negative_door_arrival_and_surf_use_real_world_body() -> void:
	Game.destination={"map":"johto_060","warp":{"map":"johto_060","index":0}}
	var game=load("res://scenes/main.tscn").instantiate();add_child(game);game.set_process(false)
	assert_eq(DungeonDB.current,"kanto_world")
	var at:=Arena.warp_tile("johto_060",0)
	assert_lt(at.x,0);assert_true(Arena.has_warp("johto_060",0))
	assert_lt(game.world.player.position.distance_to(Arena.tile_center(at)),Arena.TILE*1.5)
	var found:=false
	for chunk in Continent.scene().chunks:
		if found:break
		for i in 1024:
			if found:break
			var tile:=Vector2i(int(chunk.x)*32+i%32,int(chunk.z)*32+i/32)+Continent.offset()
			if Arena.is_water(tile) or Arena.terrain_blocked(tile) or Arena.ledge_at(tile.x,tile.y)!=0:continue
			for d in [Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP]:
				if not Arena.is_water(tile+d) or Arena.terrain_blocked(tile+d,2):continue
				game.world.player.position=Arena.tile_center(tile);game.world.player.facing=Vector2(d)
				if not game.world.field_water.can_use(game.world):continue
				assert_true(game.world.field_water.surf(game.world));assert_eq(game.world.player.travel_terrain,2)
				found=true;break
	assert_true(found,"Original water remains reachable at translated shoreline")
	game.free()
