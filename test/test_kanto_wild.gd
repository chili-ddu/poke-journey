extends GutTest
const NEW := {"spearow":21,"ekans":23,"nidoran_f":29,"nidoran_m":32,"clefairy":35,"jigglypuff":39,"zubat":41,"oddish":43,"paras":46,"meowth":52,"mankey":56}
const LOCATIONS := {"kanto_north":["route3","route4","route5"],"kanto_east":["route6"],"mt_moon_1f":["mt_moon_1f"],"mt_moon_b1f":["mt_moon_b1f"],"mt_moon_b2f":["mt_moon_b2f"]}
class Idle:
	extends RefCounted
	func move_dir(_w): return Vector2.ZERO
	func aim_point(w): return w.player.position
	func want_dodge(_w): return false
	func want_skill(_i,_w): return false
	func want_jump(_w): return false
	func want_item(_w): return false
func after_each():
	DungeonDB.set_current(DungeonDB.DEFAULT)
	Arena.configure(DungeonDB.theme())
func fixture(place: String) -> World:
	DungeonDB.set_current(place)
	Arena.configure(DungeonDB.theme())
	var w := World.new()
	add_child_autofree(w)
	w.setup(17,"charmander",5,["scratch"],Idle.new())
	return w
func move_to_encounter(w: World,area: String) -> Array:
	var r := Arena.area_rect(area)
	for y in range(r.position.y,r.end.y):
		for x in range(r.position.x,r.end.x):
			var p := Arena.tile_center(Vector2i(x,y))
			if Arena.solid_at(x,y) or not Arena.warp_at(p).is_empty(): continue
			w.player.position=p
			var points := w._wild_spawn_points(DungeonDB.area_cfg(area),8.0)
			if not points.is_empty(): return points
	return []
func test_native_land_tables_and_cities():
	var all := {}
	for place in LOCATIONS:
		DungeonDB.set_current(place)
		for area in LOCATIONS[place]:
			var cfg := DungeonDB.area_cfg(area)
			assert_eq(cfg.encounters.size(),12,area)
			var sum := 0
			for e in cfg.encounters:
				sum+=int(e[2]); all[e[0]]=true
			assert_eq(sum,100,area)
			if area.begins_with("mt_moon"): assert_eq(cfg.encounter_terrain,"cave")
	for id in NEW: assert_true(all.has(id),id)
	DungeonDB.set_current("kanto_north")
	assert_eq(DungeonDB.area_cfg("route3").encounters[7],["jigglypuff",3,5])
	assert_true(DungeonDB.area_cfg("cerulean_city").get("encounters",[]).is_empty())
	DungeonDB.set_current("kanto_east")
	assert_true(DungeonDB.area_cfg("vermilion_city").get("encounters",[]).is_empty())
	DungeonDB.set_current("mt_moon_b1f")
	for e in DungeonDB.area_cfg("mt_moon_b1f").encounters: assert_eq(e[0],"paras")
func test_every_new_species_has_native_eight_direction_sprites_and_legal_attacks():
	for id in NEW:
		for shiny in [false,true]:
			var sprites := MonSprite.load_set(NEW[id],shiny)
			assert_true(sprites.has("Walk"),id+str(shiny))
			assert_eq(sprites.Walk.rows,8,id)
			assert_true(FileAccess.file_exists("res://assets/sprites/%04d/%sAnimData.xml"%[NEW[id],"shiny/" if shiny else ""]))
		var minimum: int = {"spearow":6,"ekans":6,"nidoran_f":6,"nidoran_m":6,"clefairy":8,"jigglypuff":3,"zubat":7,"oddish":13,"paras":5,"meowth":10,"mankey":7}[id]
		var moves := SpeciesDB.enemy_moves(id,minimum)
		var offense := false
		for mid in moves:
			assert_lte(SpeciesDB.learn_level(id,mid),minimum,id+mid)
			if MoveDB.power(mid)>0: offense=true
		assert_true(offense,id+" can attack at its lowest encounter level")
func test_reachable_local_spawn_candidates_for_every_new_area():
	for place in LOCATIONS:
		var w := fixture(place)
		for area in LOCATIONS[place]:
			var points := move_to_encounter(w,area)
			assert_false(points.is_empty(),area)
			for pos in points:
				assert_eq(Arena.area_at(pos),area)
				assert_lt(Arena.resolve(pos,8.0).distance_to(pos),0.1)
				assert_true(Arena.warp_at(pos).is_empty())
				assert_eq(Arena.ledge_at(Arena.tile_of(pos).x,Arena.tile_of(pos).y),0)
				if not area.begins_with("mt_moon"): assert_true(Arena.is_grass(Arena.tile_of(pos)))
			assert_true(w.queue_spawn("zubat" if area.begins_with("mt_moon") else "spearow",8))
			w._step_spawns(2.0)
			assert_true(w.pending_spawns.is_empty())
			assert_gt(w.enemies.size(),0)
func test_city_spawn_and_pending_route_crossing_are_blocked():
	var w := fixture("kanto_north")
	assert_false(move_to_encounter(w,"route5").is_empty())
	assert_true(w.queue_spawn("oddish",13))
	w.player.position=Arena.tile_center(Arena.area_rect("cerulean_city").get_center())
	w._step_spawns(2.0)
	assert_true(w.enemies.is_empty())
	assert_false(w.queue_spawn("oddish",13))
func test_repel_cancels_pending_wild_spawn():
	var w := fixture("mt_moon_1f")
	move_to_encounter(w,"mt_moon_1f")
	assert_true(w.queue_spawn("zubat",7))
	w.player.repel_steps=10
	w._step_spawns(2.0)
	assert_true(w.enemies.is_empty())

func test_all_new_wild_ai_can_land_damage_without_player_input():
	for id in NEW:
		var w := fixture("test_meadow")
		w.player.position=Arena.center()
		var enemy := Enemy.new()
		enemy.setup_enemy(id,16,w.rng)
		enemy.position=w.player.position+Vector2.RIGHT*65.0
		w.add_child(enemy)
		w.enemies.append(enemy)
		var before: int=w.player.hp
		for i in 1800:
			w.step(1.0/60.0)
			if w.player.hp<before: break
		assert_lt(w.player.hp,before,id+" AI lands an attack")
func test_absorb_heals_and_supersonic_inflicts_confusion():
	var w := fixture("test_meadow")
	w.player.position=Arena.center()
	var enemy := Enemy.new()
	enemy.setup_enemy("zubat",10,w.rng)
	enemy.position=w.player.position+Vector2.RIGHT*40
	w.add_child(enemy)
	w.enemies.append(enemy)
	enemy.hp=1
	var before: int=w.player.hp
	w.cast(enemy,"absorb",Vector2.LEFT,w.player.position)
	for i in 90:
		w._step_pending_casts(1.0/60.0)
		w._step_pending_calls(1.0/60.0)
	assert_lt(w.player.hp,before)
	assert_gt(enemy.hp,1)
	w.cast(enemy,"supersonic",Vector2.LEFT,w.player.position)
	for i in 90: w._step_pending_casts(1.0/60.0)
	assert_gt(w.player.confuse_t,0.0)
