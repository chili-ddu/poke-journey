extends GutTest

const Data=preload("res://scripts/data/road_trainer_db.gd")
const Search=preload("res://scripts/battle/trainer_search.gd")
const Exposure=preload("res://scripts/battle/trainer_exposure.gd")
const Game=preload("res://scripts/game.gd")

class Idle:
	extends RefCounted
	func move_dir(_w):return Vector2.ZERO
	func aim_point(w):return w.player.position+Vector2.UP*80
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func after_each() -> void:
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())
	Game.destination={};Game.arena_trip={};Game.carry={}

func field_world() -> World:
	DungeonDB.set_current("kanto_world");Arena.configure(DungeonDB.theme())
	var w:=World.new();add_child_autofree(w)
	w.setup(11,"charmander",5,["ember"],Idle.new());w.god=true;w.overworld=true
	w.cam.zoom=Vector2(3,3)
	return w

func find_search(w: World,area: String,terrain: int):
	var search=Search.new();search.area=area;search.terrain=terrain
	var bounds:=Arena.area_rect(area)
	var options: Array[Vector2i]=[]
	for y in range(bounds.position.y+1,bounds.end.y-1,3):
		for x in range(bounds.position.x+1,bounds.end.x-1,3):
			var tile:=Vector2i(x,y)
			if search.walkable(tile) and Arena.area_at(Arena.tile_center(tile))==area:options.append(tile)
	options.sort_custom(func(a,b):return Vector2(a).distance_squared_to(bounds.get_center())<Vector2(b).distance_squared_to(bounds.get_center()))
	for tile in options.slice(0,60):
		w.player.position=Arena.tile_center(tile)
		w.player.travel_terrain=2 if terrain==1 else 0
		w.cam.position=w.player.position;w.cam.reset_smoothing();w.cam.force_update_scroll()
		if search.spawn(w,null,[]):return search
	return null

func test_native_road_coverage_parties_and_pair_deduplication() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/road_trainers.json"))
	var constants: Dictionary={}
	for area in manifest.coverage:
		var cfg: Dictionary=manifest.coverage[area]
		assert_eq(Data.POOLS.get(area,[]).size(),cfg.trainers.size(),area)
		for id in cfg.trainers:
			assert_true(TrainerDB.has_trainer(id));assert_false(constants.has(manifest.origins[id].trainer))
			constants[manifest.origins[id].trainer]=true
			var native: Dictionary=manifest.origins[id]
			var tr: Dictionary=TrainerDB.get_trainer(id)
			assert_eq(tr.party.size(),native.party.size())
			assert_eq(TrainerDB.sprite(id),String(native.sprite))
			assert_eq(int(tr.terrain),int(native.terrain))
			assert_false(TrainerDB.berry_rewards(id).is_empty())
			for i in tr.party.size():
				assert_eq(tr.party[i][0],native.party[i][0]);assert_eq(int(tr.party[i][1]),int(native.party[i][1]))
				if native.party[i].size()>2:assert_eq(tr.party[i][2],native.party[i][2])
	assert_eq(constants.size(),172)
	for empty in ["route1","route2","route4","route5","route7","route22","route23"]:assert_false(Data.POOLS.has(empty))
	assert_eq(TrainerDB.get_trainer("route4_lass_crissy").party,[["paras",31],["paras",31],["parasect",31]])
	assert_eq(Data.POOLS.route8.size(),12);assert_eq(Data.POOLS.route12.size(),8)
	assert_eq(Data.POOLS.route19.size(),11)
	assert_eq(TrainerDB.get_trainer("road8_little_girl_eli").partner_sprite,"little_girl")
	assert_eq(TrainerDB.get_trainer("road19_swimmer_f_water_lia").partner_sprite,"tuber_m_water")

func test_every_party_has_normal_stats_damage_moves_and_complete_assets() -> void:
	var w:=field_world()
	var smooth: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/smooth/manifest.json"))
	var count:=0
	for id in Data.TRAINERS:
		var tr: Dictionary=TrainerDB.get_trainer(id)
		for i in tr.party.size():
			var entry: Array=tr.party[i]
			var iv:=int(tr.ivs[i]) if tr.has("ivs") else 0
			var mon:=Enemy.new()
			mon.setup_trainer_mon(entry[0],int(entry[1]),entry[2] if entry.size()>2 else [],w.rng,iv)
			assert_eq(mon.stats,SpeciesDB.stats_at(entry[0],int(entry[1]),mon.ivs))
			assert_eq(mon.hp,mon.max_hp);assert_eq(mon.max_hp,int(mon.stats.hp))
			assert_eq(w._damage_mult(mon),1.0)
			assert_false(mon.cds.is_empty(),id+" has usable moves")
			for key in mon.stats:assert_eq(int(mon.ivs.get(key,0)),iv)
			for move in mon.cds:
				assert_true(MoveDB.has_move(move));assert_false(String(MoveDB.get_move(move).shape).is_empty())
			var dex:=int(SpeciesDB.get_species(entry[0]).dex)
			for variant in ["","shiny/"]:
				var dir:="res://assets/sprites/%04d/"%dex+String(variant)
				assert_true(ResourceLoader.exists(dir+"Walk-Anim.png"),entry[0])
				assert_true(smooth.has(dir+"Walk-Anim.png"),entry[0]+" C interpolation")
			assert_true(ResourceLoader.exists("res://assets/audio/cry/"+entry[0]+".wav"))
			mon.free();count+=1
	assert_eq(count,421)

func test_native_npc_frame_sizes_and_walk_interpolation() -> void:
	for sprite in Data.SPRITE_FRAMES:
		var n:=Npc.new();add_child_autofree(n)
		n.setup({"id":"review","sprite":sprite,"tile":Vector2i.ZERO})
		var size: Array=Data.SPRITE_FRAMES[sprite]
		assert_eq(n.frame_size,Vector2(size[0],size[1]));assert_not_null(n._tex)
		assert_eq(n.visual_frame().src.size,n.frame_size)
		n.walk_target=Vector2(10,10);n.step(0.05)
		var frame: Dictionary=n.visual_frame()
		assert_not_null(frame.tex);assert_eq(frame.src.size,n.frame_size)
		assert_true(Rect2(Vector2.ZERO,frame.tex.get_size()).encloses(frame.src),sprite+" native frame stays inside the sheet")

func test_each_road_terrain_spawns_a_connected_offscreen_trainer() -> void:
	var w:=field_world()
	for area in Data.POOLS:
		if not String(area).begins_with("route"):continue
		var terrains: Dictionary={}
		for id in Data.POOLS[area]:terrains[int(Data.TRAINERS[id].terrain)]=true
		for terrain in terrains:
			var search=find_search(w,area,int(terrain))
			assert_not_null(search,"Connected searchable terrain: %s / %d"%[area,terrain])
			if search==null:continue
			assert_eq(int(TrainerDB.get_trainer(search.actor.trainer_id).terrain),int(terrain))
			assert_false(search.visible_at(w,null,search.actor.position))
			assert_false(search.route(Arena.tile_of(search.actor.position),Arena.tile_of(w.player.position)).is_empty())
			assert_true(search.path.all(func(tile):return search.walkable(tile)))
			search.clear(w)

func test_swimming_search_restore_and_shoreline_retirement() -> void:
	var w:=field_world()
	var driver=find_search(w,"route19",1)
	assert_not_null(driver)
	if driver==null:return
	var e=Exposure.new();e.sync_visit("route19");e.terrain=1
	e.pursuits.append(driver);e.deployed.append(driver.actor.trainer_id);e.attention=100.0
	var snap: Dictionary=e.snapshot()
	driver.clear(w)
	var restored=Exposure.new();restored.restore_visit(w,snap)
	assert_eq(restored.terrain,1);assert_eq(restored.pursuits.size(),1)
	assert_true(restored.remaining_ids(5).all(func(id):return Data.TRAINERS[id].terrain==1))
	var swimmer=restored.pursuits[0]
	assert_eq(swimmer.terrain,1);assert_true(swimmer.walkable(Arena.tile_of(swimmer.actor.position)))
	var land=find_search(w,"route19",0)
	assert_not_null(land)
	if land==null:return
	assert_false(swimmer.walkable(Arena.tile_of(w.player.position)))
	swimmer.step(w,null,0.0,[],false)
	assert_true(swimmer.phase in ["leaving","idle"],"Swimmers retire or leave immediately when the player reaches land")
	land.clear(w)

func test_paired_trainer_throws_from_each_owner_and_passes_native_ivs() -> void:
	var old_bot:=OS.get_environment("BOT");var old_map:=OS.get_environment("DUNGEON")
	OS.set_environment("BOT","1");OS.set_environment("DUNGEON","arena_route1")
	Game.arena_trip={"trainer":"road15_black_belt_ron","arena":"arena_route1","back":{"map":"kanto_world","pos":Vector2.ZERO}}
	var game=load("res://scenes/main.tscn").instantiate();add_child_autofree(game)
	game.set_process(false);game.world.god=true;game.world.player.controller=Idle.new()
	OS.set_environment("BOT",old_bot);OS.set_environment("DUNGEON",old_map)
	var lead: Npc=game.arena_trainer
	var partner: Npc=lead.get_meta("trainer_partner").get_ref()
	assert_not_null(partner);assert_ne(lead.position,partner.position)
	for index in 2:
		game.battle={"trainer":lead,"idx":index,"resume":"fight"};game._send_next()
		var mon: Enemy=game.battle.mon
		assert_eq(int(mon.ivs.hp),6)
		assert_eq(game.sendout.ball.from, (lead if index==0 else partner).position+Vector2(0,-Arena.TILE*0.4))
		game.world.enemies.erase(mon);mon.queue_free();game.sendout={}
