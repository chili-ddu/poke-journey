extends GutTest
const SPECIES := {"psyduck":54,"poliwag":60,"poliwhirl":61,"tentacool":72,"shellder":90,"krabby":98,"horsea":116,"seadra":117,"goldeen":118,"magikarp":129,"gyarados":130}
const PLACES := {"pallet_town":"kanto_south","viridian_city":"kanto_south","route4":"kanto_north","cerulean_city":"kanto_north","route6":"kanto_east","vermilion_city":"kanto_east"}
class Idle:
	extends RefCounted
	var moving := Vector2.ZERO
	func move_dir(_w): return moving
	func aim_point(w): return w.player.position+w.player.facing*80
	func want_dodge(_w): return false
	func want_skill(_i,_w): return false
	func want_jump(_w): return false
	func want_item(_w): return false
func fixture(place: String) -> World:
	DungeonDB.set_current(place)
	Arena.configure(DungeonDB.theme())
	var w := World.new()
	add_child_autofree(w)
	w.setup(17,"charmander",5,["scratch","ember"],Idle.new())
	return w
func after_each():
	DungeonDB.set_current(DungeonDB.DEFAULT)
	Arena.configure(DungeonDB.theme())
func shore(w: World,area: String) -> Dictionary:
	for water in Arena._water:
		var pos := Arena.tile_center(water)
		if Arena.area_at(pos)!=area or Arena.resolve(pos,11.0,false,1).distance_to(pos)>0.1: continue
		for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
			var land: Vector2i=water+d
			var at := Arena.tile_center(land)
			if Arena.is_water(land) or Arena.solid_at(land.x,land.y) or Arena.area_at(at)!=area:continue
			if Arena.resolve(at,w.player.radius).distance_to(at)>0.1:continue
			w.player.position=at
			w.player.facing=-Vector2(d)
			return {"land":at,"water":pos}
	return {}
func test_native_rods_ranges_and_water_tables_for_six_areas():
	var found := {}
	var rng := RandomNumberGenerator.new()
	rng.seed=123
	for area in PLACES:
		DungeonDB.set_current(PLACES[area])
		var cfg := DungeonDB.area_cfg(area)
		assert_eq(cfg.water_encounters.size(),5,area)
		assert_eq(cfg.water_encounter_rate,2 if area in ["route4","route6"] else 1,area)
		for rod in FieldWater.RODS:
			var table: Array=cfg.fishing[rod]
			assert_eq(table.size(),2 if rod=="old_rod" else (3 if rod=="good_rod" else 5))
			var sum := 0
			for e in table:
				sum+=int(e[2]); found[e[0]]=true
				assert_lte(int(e[1]),int(e[3]))
			assert_eq(sum,100)
			for i in 100:
				var pick := DungeonDB.roll_table(table,rng)
				var valid := false
				for e in table:
					if e[0]==pick.species and pick.level>=int(e[1]) and pick.level<=int(e[3]): valid=true
				assert_true(valid)
		for e in cfg.water_encounters:found[e[0]]=true
	assert_eq(found.size(),SPECIES.size())
	for id in SPECIES:assert_true(found.has(id),id)
func test_surf_shore_and_land_collision_for_every_water_area():
	for area in PLACES:
		if area=="route4": continue # Native water is cliff-bound; enter from Cerulean by surfing.
		var w := fixture(PLACES[area])
		var at := shore(w,area)
		assert_false(at.is_empty(),area)
		assert_true(w.field_water.can_use(w))
		assert_gt(Arena.resolve(at.water,w.player.radius).distance_to(at.water),1.0,"Land cannot enter water")
		assert_lt(Arena.resolve(at.water,w.player.radius,false,1).distance_to(at.water),0.1)
		assert_gt(Arena.resolve(at.land,w.player.radius,false,1).distance_to(at.land),1.0,"Water-only wild cannot walk ashore")
		assert_true(w.field_water.surf(w))
		assert_eq(w.player.travel_terrain,2)
		assert_eq(w.wild_cfg().encounter_terrain,"water")
		w.player.controller.moving=(at.land-at.water).normalized()
		for i in 90:w.step(1.0/60.0)
		assert_false(Arena.is_water(Arena.tile_of(w.player.position)),area)
		assert_eq(w.player.travel_terrain,0,area+" auto dismount")
func test_fishing_automatically_spawns_water_wild_and_repel_does_not_block_rod():
	var w := fixture("kanto_east")
	shore(w,"vermilion_city")
	w.player.repel_steps=50
	var caught := false
	for i in 20:
		assert_true(w.field_water.start_fishing(w,"old_rod"))
		w.field_water.step(w,3.0)
		w._step_spawns(1.0)
		if not w.enemies.is_empty():caught=true;break
	assert_true(caught)
	assert_eq(w.enemies[0].species_id,"magikarp")
	assert_eq(w.enemies[0].travel_terrain,1)
	assert_true(Arena.is_water(Arena.tile_of(w.enemies[0].position)))
	assert_false(w.field_water.start_fishing(w,"good_rod"),"Cannot cast during combat")
func test_fishing_movement_damage_and_menu_cancellation():
	var w := fixture("kanto_east")
	shore(w,"vermilion_city")
	assert_true(w.field_water.start_fishing(w,"good_rod"))
	w.player.controller.moving=Vector2.RIGHT
	w.field_water.step(w,0.1)
	assert_true(w.field_water.fishing.is_empty())
	w.player.controller.moving=Vector2.ZERO
	assert_true(w.field_water.start_fishing(w,"good_rod"))
	w.player.hp-=1
	w.field_water.step(w,0.1)
	assert_true(w.field_water.fishing.is_empty())
	assert_true(w.field_water.start_fishing(w,"good_rod"))
	w.field_water.cancel(w,false)
	assert_true(w.field_water.fishing.is_empty())
func test_water_spawn_candidates_do_not_use_land_and_projectiles_cross_water():
	var w := fixture("kanto_east")
	shore(w,"vermilion_city")
	assert_true(w.field_water.surf(w))
	var points := w._wild_spawn_points(w.wild_cfg(),8.0)
	assert_false(points.is_empty())
	for pos in points:
		assert_true(Arena.is_water(Arena.tile_of(pos)))
		assert_eq(Arena.area_at(pos),"vermilion_city")
		assert_false(Arena.blocks(pos,4.0),"Water is not a projectile wall")
	assert_true(w.queue_spawn("tentacool",10))
	w._step_spawns(2.0)
	assert_eq(w.enemies[0].travel_terrain,1)
func test_city_fished_enemy_survives_land_only_encounter_check():
	var w := fixture("kanto_east")
	var at := shore(w,"vermilion_city")
	var enemy := Enemy.new()
	enemy.setup_enemy("magikarp",5,w.rng)
	enemy.travel_terrain=1
	enemy.position=at.water
	w.add_child(enemy)
	w.enemies.append(enemy)
	var game=load("res://scripts/game.gd").new()
	game.world=w;game.mode="overworld";game.state="fight";game.bot=true
	game._step_wild(0.1)
	assert_false(enemy.dead)
	assert_eq(w.remaining(),1)
	game.free()
func test_native_sprite_sets_and_minimum_level_behavior():
	for id in SPECIES:
		for shiny in [false,true]:
			var set := MonSprite.load_set(SPECIES[id],shiny)
			assert_true(set.has("Walk"),id)
			assert_eq(set.Walk.rows,8,id)
		var lv := 15 if id=="gyarados" else (20 if id=="poliwhirl" else (25 if id=="seadra" else 5))
		var moves := SpeciesDB.enemy_moves(id,lv)
		assert_false(moves.is_empty(),id)
		var attack := false
		for mid in moves:
			assert_lte(SpeciesDB.learn_level(id,mid),lv)
			if MoveDB.power(mid)>0:attack=true
		if id=="magikarp":assert_eq(moves,["splash"],"Low level Magikarp only splashes")
		else:assert_true(attack,id)

func test_route4_cliff_water_is_reached_by_surfing_from_cerulean():
	var w := fixture("kanto_north")
	var border := Arena.tile_center(Arena.area_tile("cerulean_city", Vector2i(0,17)))
	assert_eq(Arena.area_at(border),"cerulean_city")
	assert_true(Arena.is_water(Arena.tile_of(border)))
	w.player.position=border
	w.player.travel_terrain=2
	w.player.controller.moving=Vector2.LEFT
	for i in 24:w.step(1.0/60.0)
	assert_eq(Arena.area_at(w.player.position),"route4")
	assert_eq(w.player.travel_terrain,2)
	assert_eq(w.wild_cfg().encounter_terrain,"water")

func test_all_water_species_ai_can_fight_on_water_except_low_level_magikarp():
	for id in SPECIES:
		var w := fixture("kanto_east")
		shore(w,"vermilion_city")
		assert_true(w.field_water.surf(w))
		var lv := 15 if id=="gyarados" else (20 if id=="poliwhirl" else (25 if id=="seadra" else 5))
		assert_true(w.queue_spawn(id,lv))
		w._step_spawns(2.0)
		var enemy: Enemy=w.enemies[0]
		var before: int=w.player.hp
		for i in 1500:
			w.step(1.0/60.0)
			if w.player.hp<before:break
		assert_true(Arena.is_water(Arena.tile_of(enemy.position)),id+" stays aquatic")
		if id=="magikarp":assert_eq(w.player.hp,before,"Splash deals no damage")
		else:assert_lt(w.player.hp,before,id+" AI attack across water")
