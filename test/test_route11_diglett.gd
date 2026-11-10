extends GutTest
const Data=preload("res://scripts/data/route11_diglett.gd")
const Road=preload("res://scripts/data/road_trainer_db.gd")
const NEW={"raticate":20,"nidorino":33,"vulpix":37,"diglett":50,"dugtrio":51,"growlithe":58,"magneton":82,"drowzee":96}

class Idle:
	extends RefCounted
	func move_dir(_w):return Vector2.ZERO
	func aim_point(w):return w.player.position
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func after_each() -> void:
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func source(place: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(DungeonDB.THEMES[DungeonDB.DUNGEONS[place].theme].map+"/map.json"))

func test_all_new_maps_have_open_reciprocal_exits_and_safe_spawns() -> void:
	assert_eq(Data.DUNGEONS.size(),8)
	for place in Data.DUNGEONS:
		DungeonDB.set_current(place);Arena.configure(DungeonDB.theme())
		assert_true(View3D.supported(DungeonDB.theme().map),place)
		assert_lt(Arena.resolve(Arena.map.start,8.0).distance_to(Arena.map.start),0.1,place)
		assert_true(ResourceLoader.exists(Bgm.DIR+Bgm.place(place)+".wav"),place)
		for warp in Arena.warps():
			assert_true(DungeonDB.WARP_MAPS.has(warp.to),place+str(warp))
			assert_false(Arena.solid_at(int(warp.x),int(warp.y)))
			var dest:=source(DungeonDB.warp_destination(warp))
			assert_true(dest.warps.any(func(other):return other.map==warp.to and int(other.index)==int(warp.to_warp)),"Destination exists: "+place)

func test_city_boundary_uses_native_lanes_and_preserves_existing_coordinates() -> void:
	var town:=source("kanto_east")
	var road:=source("route11")
	assert_eq(Vector2i(int(town.width),int(town.height)),Vector2i(48,80))
	var lanes: Array=town.warps.filter(func(w):return w.get("route11_link",false))
	assert_eq(lanes.size(),4)
	for warp in lanes:
		assert_eq(int(warp.x),47)
		var back: Dictionary=road.warps.filter(func(w):return w.get("route11_link",false) and int(w.index)==int(warp.to_warp))[0]
		assert_eq(int(back.x),0)
		assert_eq(int(warp.y),int(back.y)+50)
		assert_eq(back.to,"vermilion_city")
		assert_eq(int(back.to_warp),int(warp.index))
		assert_eq(Vector2(warp.arrival_dir[0],warp.arrival_dir[1]),Vector2.LEFT)
		assert_eq(Vector2(back.arrival_dir[0],back.arrival_dir[1]),Vector2.RIGHT)
	assert_eq(source("kanto_south").areas.filter(func(a):return a.id=="route2")[0].y,60.0)

func test_cave_ladders_connect_both_sides_along_clear_floor() -> void:
	DungeonDB.set_current("digletts_cave_b1f");Arena.configure(DungeonDB.theme())
	var grid:=AStarGrid2D.new()
	grid.region=Rect2i(0,0,int(Arena.map.width),int(Arena.map.height))
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_NEVER;grid.update()
	for y in int(Arena.map.height):
		for x in int(Arena.map.width):
			var at:=Arena.tile_center(Vector2i(x,y))
			grid.set_point_solid(Vector2i(x,y),Arena.resolve(at,8.0).distance_to(at)>0.1)
	var north:=Arena.warp_tile("digletts_cave_b1f",0)
	var south:=Arena.warp_tile("digletts_cave_b1f",1)
	var path:=grid.get_id_path(north,south)
	assert_gt(path.size(),100)
	assert_eq(grid.get_id_path(south,north).size(),path.size())
	for tile in path:assert_false(grid.is_point_solid(tile))
	var cards: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DungeonDB.theme().map+"/hd2d_cards.json"))
	assert_eq(cards.terrain,"heightfield_cave_cliffs")
	assert_true(cards.cards.is_empty(),"Long cave walls are terrain, not stretched billboards")

func test_native_wild_tables_spawn_on_grass_and_cave_floor() -> void:
	for place in ["route11","digletts_cave_b1f"]:
		DungeonDB.set_current(place);Arena.configure(DungeonDB.theme())
		var cfg:=DungeonDB.area_cfg(place)
		assert_eq(cfg.encounters.size(),12)
		var totals: Dictionary={}
		for entry in cfg.encounters:totals[entry[0]]=int(totals.get(entry[0],0))+int(entry[2])
		assert_eq(totals,{"ekans":40,"spearow":35,"drowzee":25} if place=="route11" else {"diglett":95,"dugtrio":5})
		var world:=World.new();add_child_autofree(world)
		world.setup(7,"charmander",5,["scratch"],Idle.new())
		var points: Array=[]
		for y in int(Arena.map.height):
			for x in int(Arena.map.width):
				if Arena.solid_at(x,y):continue
				world.player.position=Arena.tile_center(Vector2i(x,y))
				points=world._wild_spawn_points(cfg,8.0)
				if not points.is_empty():break
			if not points.is_empty():break
		assert_false(points.is_empty(),place)
		for at in points:
			assert_lt(Arena.resolve(at,8.0).distance_to(at),0.1)
			assert_eq(Arena.area_at(at),place)
			if place=="route11":assert_true(Arena.is_grass(Arena.tile_of(at)))
		assert_true(world.queue_spawn("drowzee" if place=="route11" else "diglett",15))
		world._step_spawns(1.0)
		assert_eq(world.alive_enemies().size(),1)

func test_new_species_have_normal_shiny_smooth_sprites_cries_and_usable_attacks() -> void:
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/smooth/manifest.json"))
	var rng:=RandomNumberGenerator.new();rng.seed=7
	for id in NEW:
		for shiny in [false,true]:
			var sprites:=MonSprite.load_set(NEW[id],shiny)
			assert_true(sprites.has("Walk"),id)
			assert_eq(int(sprites.Walk.rows),8,id)
			if sprites.Walk.durations.size()>1:assert_true(manifest.has(sprites.Walk.tex.resource_path),id+" uses C interpolation")
		assert_true(ResourceLoader.exists("res://assets/audio/cry/"+id+".wav"),id)
		var enemy:=Enemy.new();add_child_autofree(enemy);enemy.setup_enemy(id,15,rng)
		assert_eq(enemy.ai,"wild",id)
		assert_false(enemy.cds.is_empty(),id+" has active moves")
		assert_true(SpeciesDB.enemy_moves(id,15).any(func(move):return MoveDB.power(move)>0),id)

func test_route11_coast_uses_existing_fishing_and_surf() -> void:
	DungeonDB.set_current("route11");Arena.configure(DungeonDB.theme())
	var cfg:=DungeonDB.area_cfg("route11")
	assert_eq(cfg.water_encounters.size(),5)
	assert_eq(cfg.fishing.old_rod.size(),2)
	var world:=World.new();add_child_autofree(world)
	world.setup(7,"charmander",5,["scratch"],Idle.new())
	world.player.position=Arena.tile_center(Vector2i(8,10));world.player.facing=Vector2.DOWN
	assert_true(Arena.is_water(Vector2i(8,11)))
	assert_true(world.field_water.start_fishing(world,"old_rod"))
	world.field_water.cancel(world,false)
	assert_true(world.field_water.surf(world))
	assert_eq(world.player.travel_terrain,2)
	assert_true(Arena.is_water(Arena.tile_of(world.player.position)))

func test_route11_original_trainers_and_visited_fly_destination() -> void:
	assert_eq(Road.POOLS.route11.size(),10)
	assert_eq(TrainerDB.get_trainer("road11_balding_man_bernie").party,[["magnemite",18],["magnemite",18],["magneton",18]])
	for id in Road.POOLS.route11:
		assert_true(ResourceLoader.exists("res://assets/npcs/"+TrainerDB.sprite(id)+".png"))
		for mon in TrainerDB.get_trainer(id).party:assert_true(MonSprite.load_set(int(SpeciesDB.get_species(mon[0]).dex)).has("Walk"))
	var entry:=FlyDestinations.find("route11")
	assert_eq(entry.map,"kanto_world")
	assert_false(FlyDestinations.can_fly("route11",[]))
	assert_false(FlyDestinations.can_fly("route11",[FlyDestinations.visit_flag("route11")]))
	assert_true(FlyDestinations.can_fly("route11",[FlyDestinations.visit_flag("route11"),RoadAccess.SNORLAX_AWAKENED]))
	DungeonDB.set_current("kanto_world");Arena.configure(DungeonDB.theme())
	var landing:=FlyDestinations.position_of(entry)
	assert_lt(Arena.resolve(landing,8.0).distance_to(landing),0.1)
	assert_true(Arena.warp_at(landing).is_empty())
