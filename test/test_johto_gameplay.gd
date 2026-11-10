extends GutTest
const Johto = preload("res://scripts/data/johto_maps.gd")
const Travel = preload("res://scripts/johto/region_travel.gd")
const Rules = preload("res://scripts/johto/visual_style_rules.gd")
const Game = preload("res://scripts/game.gd")
var old_bot: String
var old_map: String
var old_path: String
var old_events: Array
var old_skip: bool

func before_each() -> void:
	old_bot=OS.get_environment("BOT");old_map=OS.get_environment("DUNGEON")
	old_path=SaveData.path;old_events=Game.bot_events;old_skip=Game.skip_opening
	SaveData.path="user://johto_gameplay_tests_only.cfg"
	OS.set_environment("BOT","1")
	Game.skip_opening=true;Game.bot_events=[]
	Game.destination={};Game.carry={};Game.arena_trip={}

func after_each() -> void:
	SaveData.clear();SaveData.path=old_path
	OS.set_environment("BOT",old_bot);OS.set_environment("DUNGEON",old_map)
	Game.destination={};Game.carry={};Game.arena_trip={};Game.bot_events=old_events;Game.skip_opening=old_skip
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func open_game(place: String):
	OS.set_environment("DUNGEON",place)
	var game=load("res://scenes/main.tscn").instantiate()
	add_child(game);game.set_process(false)
	return game

func test_all_301_maps_are_registered_with_original_geometry_and_clear_start() -> void:
	for key in Johto.collection().manifest.headers:
		var place := Johto.id(int(key))
		assert_true(DungeonDB.has_location(place))
		DungeonDB.set_current(place);Arena.configure(DungeonDB.theme())
		assert_true(Arena.is_native(),place)
		assert_true(DungeonDB.is_hub(place),place+" can save/resume")
		assert_eq(Arena.native_data.id,Johto.collection().scene_for(int(key)))
		assert_false(Arena.terrain_blocked(Arena.tile_of(Arena.center())),place+" clear start")
		assert_eq(Arena.area_at(Arena.center()),place)
		assert_true(DungeonDB.encounters().is_empty(),"Map-only does not invent encounters")

func test_game_warps_keep_all_original_anchors_and_canonical_shared_entrances() -> void:
	var count := 0
	for sid in Johto.collection().manifest.scenes:
		var scene := Johto.collection().scene_data(sid)
		var place := Johto.id(int(scene.headers[0]))
		DungeonDB.set_current(place);Arena.configure(DungeonDB.theme())
		for tile in scene.portal_index:
			var raw: Dictionary=scene.portal_index[tile]
			var warp := Arena.warp_at(Arena.tile_center(tile))
			assert_eq(warp.index,int(raw.index))
			if String(raw.to).is_empty():
				assert_eq(DungeonDB.warp_destination(warp),"")
				continue
			var expected: String = DungeonDB.WARP_MAPS.get(String(raw.game_to),"") if raw.has("game_to") else Johto.id(int(raw.to_header))
			assert_eq(DungeonDB.warp_destination(warp),expected)
			assert_eq(warp.to_warp,int(raw.get("game_to_warp",raw.to_index)))
			var anchor := Johto.collection().arrival(int(raw.header),int(raw.index))
			assert_eq(Arena.warp_tile(place if int(raw.header)==Johto.header(place) else Johto.id(int(raw.header)),int(raw.index)),tile)
			assert_eq(Vector2i(int(anchor.x),int(anchor.z)),tile)
			count+=1
	assert_gt(count,750)

func test_native_water_wall_and_ledge_permissions_feed_normal_world_collision() -> void:
	DungeonDB.set_current("johto_060");Arena.configure(DungeonDB.theme())
	var checked := 0
	for chunk in Arena.native_data.chunks:
		for index in range(0,1024,13):
			var tile := Vector2i(int(chunk.x)*32+index%32,int(chunk.z)*32+index/32)
			if Arena.ledge_at(tile.x,tile.y)!=0:
				assert_gt(Arena.resolve(Arena.tile_center(tile),8.0).distance_to(Arena.tile_center(tile)),0.1,"Ledge blocks ordinary walking")
				continue
			assert_eq(not Arena.terrain_blocked(tile),Johto.collection().can_stand(Arena.native_data,tile),str(tile))
			assert_eq(not Arena.terrain_blocked(tile,2),Johto.collection().can_stand(Arena.native_data,tile,true),"surf "+str(tile))
			checked+=1
	assert_gt(checked,1000)
	assert_true(Arena.terrain_blocked(Vector2i(-1,-1),2))
	Arena.set_dynamic_solid(Vector2i(684,394),true)
	assert_true(Arena.terrain_blocked(Vector2i(684,394),2))

func test_normal_game_uses_native_map_and_preserves_mon_between_real_door_requests() -> void:
	var game=open_game("johto_060")
	assert_eq(game.mode,"overworld")
	game.world.player.hp=7
	game.world.player.position=Arena.tile_center(Vector2i(684,393));game.warp_armed=true
	game._check_warp()
	assert_eq(game.state,"warp")
	assert_eq(Game.destination.map,"johto_061")
	assert_eq(Game.carry.hp,7)
	game.free()
	OS.set_environment("DUNGEON","")
	game=load("res://scenes/main.tscn").instantiate();add_child(game);game.set_process(false)
	assert_eq(DungeonDB.current,"johto_061")
	assert_eq(game.mode,"indoor")
	assert_eq(game.world.player.hp,7)
	assert_eq(Arena.tile_of(game.world.player.position),Arena.warp_tile("johto_061",0))
	game.free()

func test_ferry_endpoints_are_clear_cancellation_is_reversible_and_flight_stays_visit_only() -> void:
	for side in ["kanto","johto"]:
		var cfg: Dictionary=Travel.data()[side]
		var game=open_game(cfg.map)
		var ferry: Npc
		for n in game.world.npcs:
			if n.talk=="johto_ferry":ferry=n
		assert_not_null(ferry)
		assert_false(Arena.terrain_blocked(ferry.tile))
		assert_false(Arena.terrain_blocked(ferry.talk_tile))
		assert_true(ferry.can_talk(Arena.tile_center(ferry.talk_tile)))
		var target := Travel.destination_for("johto" if side=="kanto" else "kanto")
		assert_eq(target.map,cfg.map)
		assert_false(Arena.terrain_blocked(Arena.tile_of(target.pos)))
		game.region_travel.open_menu();game._resolve_menu(1)
		assert_true(Game.destination.is_empty())
		assert_true(Game.carry.is_empty())
		assert_eq(game.state,"town" if game.mode=="indoor" else "fight")
		game.free()
	assert_false(FlyDestinations.can_fly("goldenrod_city",[]))
	assert_false(FlyDestinations.can_fly("vermilion_city",[]))

func test_region_profiles_and_existing_kanto_map_restore_cleanly() -> void:
	assert_eq(Rules.game_profile("johto_117"),"forest")
	assert_eq(Rules.game_profile("johto_099"),"cave")
	assert_eq(Rules.game_profile("johto_061"),"indoor")
	DungeonDB.set_current("johto_060");Arena.configure(DungeonDB.theme())
	DungeonDB.set_current("kanto_world");Arena.configure(DungeonDB.theme())
	assert_false(Arena.is_native())
	assert_false(Arena.native_height.is_valid())
	assert_eq(Arena.area_at(Arena.tile_center(Vector2i(76,275))),"pallet_town")

func test_normal_world_walks_two_clear_tiles_into_elms_lab_door() -> void:
	var game=open_game("johto_060")
	var start:=Arena.tile_center(Vector2i(684,395))
	var goal:=Arena.tile_center(Vector2i(684,393))
	game.world.player.position=start
	for i in 180:
		var delta: Vector2=goal-game.world.player.position
		game.world.player.vel=delta.normalized()*minf(90.0,delta.length()*10.0)
		game.world._move_mons(1.0/60.0)
	assert_lt(game.world.player.position.distance_to(goal),2.0,"Actual movement arrives: "+str(game.world.player.position))
	game.free()

func test_native_directional_ledges_allow_the_existing_hop_but_never_ordinary_walking() -> void:
	var game=open_game("johto_060")
	for fixture in [[Vector2i(501,81),Vector2i.DOWN,4],[Vector2i(304,175),Vector2i.RIGHT,1],[Vector2i(312,175),Vector2i.LEFT,2]]:
		var mid: Vector2i=fixture[0];var dir: Vector2i=fixture[1]
		var start:=Arena.tile_center(mid-dir);var land:=Arena.tile_center(mid+dir)
		assert_eq(Arena.ledge_at(mid.x,mid.y),fixture[2])
		assert_false(Arena.solid_at(mid.x,mid.y),"Ledge is handled by the hop layer, not a second solid wall")
		assert_gt(Arena.resolve(Arena.tile_center(mid),game.world.player.radius).distance_to(Arena.tile_center(mid)),1.0)
		game.world.player.position=start
		var plan: Dictionary=game.world.plan_hop(start,Vector2(dir))
		assert_true(plan.ok,"Native ledge can be crossed in the original direction")
		if not plan.ok:continue
		assert_lt(plan.to.distance_to(land),0.1)
		game.world._start_hop(plan.to)
		for i in 60:game.world._move_mons(1.0/60.0)
		assert_lt(game.world.player.position.distance_to(land),0.1,"Real dash/hop reaches the far side")
	game.free()
