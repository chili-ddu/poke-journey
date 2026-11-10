extends GutTest
const Game=preload("res://scripts/game.gd")
const Johto=preload("res://scripts/data/johto_maps.gd")
var old_path: String
var old_bot: String
var old_map: String

func before_each() -> void:
	old_path=SaveData.path;old_bot=OS.get_environment("BOT");old_map=OS.get_environment("DUNGEON")
	SaveData.path="user://johto_border_test_only.cfg";SaveData.clear()
	Game.destination={};Game.carry={};Game.arena_trip={};Game.skip_opening=true;Game.bot_events=[]
	OS.set_environment("BOT","1")

func after_each() -> void:
	SaveData.clear();SaveData.path=old_path
	OS.set_environment("BOT",old_bot);OS.set_environment("DUNGEON",old_map)
	Game.destination={};Game.carry={};Game.arena_trip={};Game.bot_events=[]
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func test_border_reuses_existing_art_and_leaves_original_collection_unchanged() -> void:
	var original:=HgssMapCollection.new()
	assert_eq(original.manifest.headers.size(),301)
	assert_eq(Johto.collection().manifest.headers.size(),311)
	assert_false(original.manifest.headers.has("31"))
	for h in [30,31,32,126,296,297,298,299,322,510]:
		assert_true(DungeonDB.has_location(Johto.id(h)))
		assert_true(DungeonDB.DUNGEONS[Johto.id(h)].get("map_only",false))
		assert_eq(Johto.collection().manifest.headers[str(h)].constant,
			JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/hgss_game_source/manifest.json")).headers[str(h)].constant)
	var source:=original.scene_data(original.scene_for(60))
	var joined:=Johto.collection().scene_data(Johto.collection().scene_for(60))
	assert_eq(source.chunks.size(),99)
	assert_eq(joined.chunks.size(),111)

func test_old_gate_doors_and_saves_promote_once_without_mutating_the_input() -> void:
	for index in [0,1,2,3]:
		var input: Dictionary={"map":Johto.LEGACY_GATE,"warp":{"map":Johto.LEGACY_GATE,"index":index}}
		var result:=KantoWorldTravel.promote(Johto.LEGACY_GATE,input)
		assert_eq(result.map,"johto_299")
		assert_eq(result.destination.warp.index,1 if index==0 else 2)
		assert_eq(input.warp.index,index)
	var old: Dictionary={"map":Johto.LEGACY_GATE,"pos":Vector2(180,156),"layout":1}
	var moved:=KantoWorldTravel.promote(Johto.LEGACY_GATE,old)
	assert_eq(moved.destination.pos,Vector2(20.5,8.5)*Arena.TILE)
	assert_eq(KantoWorldTravel.promote(moved.map,moved.destination).destination,moved.destination)
	DungeonDB.set_current(moved.map);Arena.configure(DungeonDB.theme())
	assert_lt(Arena.resolve(moved.destination.pos,8.0).distance_to(moved.destination.pos),0.01)

func test_junction_uses_existing_frlg_route22_and_route23_and_original_south_west_anchors() -> void:
	DungeonDB.set_current("johto_299");Arena.configure(DungeonDB.theme())
	var checks: Array=[]
	for w in Arena.warps():
		checks.append([int(w.index),String(w.to),int(w.to_warp),DungeonDB.warp_destination(w)])
	assert_has(checks,[0,"johto_030",2,"johto_030"])
	assert_has(checks,[1,"route23",2,"kanto_world"])
	assert_has(checks,[2,"route22",0,"kanto_world"])
	assert_has(checks,[3,"johto_032",0,"johto_032"])
	DungeonDB.set_current("kanto_world");Arena.configure(DungeonDB.theme())
	for source in [["route22",0],["route23",2]]:
		var tile:=Arena.warp_tile(source[0],source[1])
		assert_ne(tile,Vector2i(-1,-1))
		assert_false(Arena.terrain_blocked(tile))

func test_falls_map_stage_permission_keeps_surf_required_and_original_source_intact() -> void:
	DungeonDB.set_current("johto_126");Arena.configure(DungeonDB.theme())
	assert_eq(Arena.native_data.permission_patches.size(),10)
	var original:=HgssMapCollection.new("res://assets/maps/hgss_game_source/")
	var raw:=original.scene_data(original.scene_for(126))
	for p in Arena.native_data.permission_patches:
		var tile:=Vector2i(int(p.x),int(p.z))
		assert_eq(original.attributes(raw,tile),0x8013)
		assert_eq(Johto.collection().attributes(Arena.native_data,tile),0x13)
		assert_true(Arena.terrain_blocked(tile),"Cannot walk on the waterfall")
		assert_false(Arena.terrain_blocked(tile,2),"Current map-stage passage uses existing surf")

func test_legacy_gate_save_load_preserves_growth_items_and_progress() -> void:
	var p:=Player.new();p.setup_player("charmander",12,["scratch","ember"],{"pid":123456,"ivs":{"hp":1,"atk":2,"def":3,"spe":4,"spa":5,"spd":6}})
	p.bag={"oran_berry":19};p.exp_total+=4
	SaveData.store(p,[],Johto.LEGACY_GATE,Vector2(180,156))
	SaveData.store_progress("events","border_save_sentinel")
	var expected:=SaveData.load_saved();p.free()
	OS.set_environment("BOT","0");OS.set_environment("DUNGEON","")
	var game=load("res://scenes/main.tscn").instantiate();add_child(game);game.set_process(false)
	assert_eq(DungeonDB.current,"johto_299")
	assert_lt(game.world.player.position.distance_to(Vector2(20.5,8.5)*Arena.TILE),0.1)
	assert_eq(game.world.player.exp_total,expected.exp)
	assert_eq(game.world.player.pid,expected.pid)
	assert_eq(game.world.player.ivs,expected.ivs)
	assert_eq(game.world.player.bag,expected.bag)
	assert_has(game.events,"border_save_sentinel")
	game._save_here()
	assert_eq(SaveData.load_saved().map,"johto_299")
	game.free()

func test_falls_culls_back_faces_without_mutating_shared_models_or_other_maps() -> void:
	var renderer=preload("res://scripts/johto/game_map_renderer.gd").new()
	var data:=Johto.collection().scene_data(Johto.collection().scene_for(126))
	assert_true(data.cull_back_faces)
	renderer.setup(Johto.collection(),data)
	var node:=MeshInstance3D.new();node.mesh=QuadMesh.new()
	var original:=StandardMaterial3D.new();original.cull_mode=BaseMaterial3D.CULL_DISABLED
	node.mesh.material=original
	renderer._apply_scene_culling(node)
	assert_eq((node.get_surface_override_material(0) as BaseMaterial3D).cull_mode,BaseMaterial3D.CULL_BACK)
	assert_eq(original.cull_mode,BaseMaterial3D.CULL_DISABLED,"Shared original stays intact")
	renderer.setup(Johto.collection(),Johto.collection().scene_data(Johto.collection().scene_for(60)))
	var outdoor:=MeshInstance3D.new();outdoor.mesh=QuadMesh.new();outdoor.mesh.material=original
	renderer._apply_scene_culling(outdoor)
	assert_null(outdoor.get_surface_override_material(0),"Other maps keep their existing rendering")
	node.free();outdoor.free();renderer.free()

func test_cave_arrival_uses_the_native_anchor_without_outdoor_step_past_the_wall() -> void:
	OS.set_environment("DUNGEON","")
	Game.destination={"map":"johto_126","warp":{"map":"johto_126","index":1}}
	var game=load("res://scenes/main.tscn").instantiate();add_child(game);game.set_process(false)
	assert_eq(DungeonDB.current,"johto_126")
	assert_eq(game.mode,"overworld","Keeps existing surf and save controls")
	assert_lt(game.world.player.position.distance_to(Arena.tile_center(Vector2i(45,20))),0.01)
	assert_false(game.warp_armed,"Arrival remains latched on its original anchor")
	game.free()
