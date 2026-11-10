extends GutTest

class Idle:
	extends RefCounted
	func move_dir(_w):return Vector2.ZERO
	func aim_point(w):return w.player.position
	func want_dodge(_w):return false
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_item(_w):return false

func after_each() -> void:
	DungeonDB.set_current(DungeonDB.DEFAULT);Arena.configure(DungeonDB.theme())

func fixture(place: String) -> World:
	DungeonDB.set_current(place);Arena.configure(DungeonDB.theme())
	var w:=World.new();add_child_autofree(w)
	w.setup(29,"charmander",5,["scratch"],Idle.new())
	return w

func enemy(w: World,id: String,level: int) -> Enemy:
	var e:=Enemy.new();e.setup_enemy(id,level,w.rng)
	e.position=w.player.position+Vector2.RIGHT*65
	w.add_child(e);w.enemies.append(e)
	return e

func move_to_area(w: World,area: String) -> bool:
	var rect:=Arena.area_rect(area)
	var cfg:=DungeonDB.area_cfg(area)
	for y in range(rect.position.y,rect.end.y):
		for x in range(rect.position.x,rect.end.x):
			var tile:=Vector2i(x,y);var at:=Arena.tile_center(tile)
			if Arena.terrain_blocked(tile,0) or not Arena.warp_at(at).is_empty():continue
			if cfg.get("encounter_terrain","")!="cave" and not Arena.is_grass(tile):continue
			if Arena.resolve(at,w.player.radius).distance_to(at)>0.1:continue
			w.player.position=at
			if not w._wild_spawn_points(cfg,8.0).is_empty():return true
	return false

func test_all_native_mainland_tables_are_connected_to_their_actual_runtime_area() -> void:
	var data:=KantoWorldWild.data()
	assert_eq(data.tables.size(),65)
	assert_eq(data.species.size(),80)
	var counts={"land":0,"surf":0,"fishing":0,"rocks":0}
	for area in data.tables:
		var owner: String=DungeonDB.WARP_MAPS.get(area,"")
		assert_ne(owner,"",area)
		DungeonDB.set_current(owner)
		var cfg:=DungeonDB.area_cfg(area)
		assert_false(cfg.is_empty(),area)
		# The four-brother trial replaces the tower's original walking encounters.
		if DungeonDB.TowerBrothers.floor_number(area)>0:
			assert_true(cfg.encounters.is_empty(),area+" is a story-only floor")
			assert_eq(int(cfg.encounter_rate),0)
			continue
		for key in data.tables[area]:assert_eq(cfg[key],data.tables[area][key],area+" "+key)
		for pair in [["encounters","land"],["water_encounters","surf"],["rock_smash_encounters","rocks"]]:
			var entries: Array=cfg.get(pair[0],[])
			if entries.is_empty():continue
			counts[pair[1]]+=1
			var total:=0
			for row in entries:total+=int(row[2])
			assert_eq(total,100,area+" "+pair[0])
		if not cfg.fishing.is_empty():
			counts.fishing+=1
			for rod in ["old_rod","good_rod","super_rod"]:
				var total:=0
				for row in cfg.fishing[rod]:total+=int(row[2])
				assert_eq(total,100,area+" "+rod)
	assert_eq(counts,{"land":51,"surf":29,"fishing":29,"rocks":4})

func test_rare_native_species_stay_in_their_own_habitat_and_cities_have_no_land_spawns() -> void:
	DungeonDB.set_current("kanto_world")
	for area in ["pallet_town","viridian_city","cerulean_city","vermilion_city","celadon_city","fuchsia_city","cinnabar_island"]:
		assert_true(DungeonDB.area_cfg(area).encounters.is_empty(),area)
		assert_false(DungeonDB.area_cfg(area).water_encounters.is_empty(),area)
	var safari:=KantoWorldWild.area("safari_zone_center")
	assert_true(safari.encounters.any(func(e):return e[0]=="chansey"))
	assert_true(KantoWorldWild.area("power_plant").encounters.any(func(e):return e[0]=="electabuzz"))
	assert_true(KantoWorldWild.area("pokemon_tower_3f").encounters.any(func(e):return e[0]=="gastly"))
	assert_true(KantoWorldWild.area("seafoam_islands_b4f").encounters.any(func(e):return e[0]=="dewgong"))
	for entry in KantoWorldWild.area("route21_north").water_encounters:assert_eq(entry[0],"tentacool")

func test_every_land_area_has_reachable_spawn_points_and_completes_a_real_spawn() -> void:
	var owners: Dictionary={}
	for area in KantoWorldWild.data().tables:
		if DungeonDB.TowerBrothers.floor_number(area)>0:continue
		if KantoWorldWild.area(area).encounters.is_empty():continue
		var owner: String=DungeonDB.WARP_MAPS[area]
		if not owners.has(owner):owners[owner]=[]
		owners[owner].append(area)
	for owner in owners:
		var w:=fixture(owner)
		for area in owners[owner]:
			# Native Route 17 and the southern Route 21 layout contain no grass,
			# despite sharing original land encounter tables with nearby areas.
			if area in ["route17","route21_south"]:
				var rect:=Arena.area_rect(area)
				for y in range(rect.position.y,rect.end.y):
					for x in range(rect.position.x,rect.end.x):assert_false(Arena.is_grass(Vector2i(x,y)))
				w.player.position=Arena.tile_center(rect.get_center())
				assert_false(w.queue_spawn("pidgey",25),area+" must not invent grass encounters")
				continue
			assert_true(move_to_area(w,area),area)
			var pick:=DungeonDB.roll_table(DungeonDB.area_cfg(area).encounters,w.rng)
			assert_true(w.queue_spawn(pick.species,pick.level),area)
			w._step_spawns(2.0)
			assert_eq(w.enemies.size(),1,area)
			if not w.enemies.is_empty():
				var e: Enemy=w.enemies.pop_back()
				assert_eq(Arena.area_at(e.position),area)
				assert_false(Arena.is_water(Arena.tile_of(e.position)))
				assert_true(Arena.warp_at(e.position).is_empty())
				e.free()

func test_all_native_species_have_normal_shiny_smooth_art_cries_and_valid_minimum_level_actions() -> void:
	var data:=KantoWorldWild.data()
	SmoothSprite.prepare()
	for id in data.species:
		var record: Dictionary=data.species[id]
		for shiny in [false,true]:
			var dir: String="res://assets/sprites/%04d/%s"%[int(record.dex),"shiny/" if shiny else ""]
			assert_true(FileAccess.file_exists(dir+"AnimData.xml"),id+str(shiny))
			var sprites:=MonSprite.load_set(int(record.dex),shiny)
			assert_true(sprites.has("Walk"),id+str(shiny))
			if not sprites.has("Walk"):continue
			assert_eq(sprites.Walk.rows,8,id+str(shiny))
			assert_true(sprites.has("Attack"),id+str(shiny))
			assert_true(sprites.has("Hurt"),id+str(shiny))
			if sprites.Walk.durations.size()>1:
				assert_true(SmoothSprite._manifest.has(sprites.Walk.tex.resource_path),id+" smooth "+str(shiny))
		assert_true(FileAccess.file_exists("res://assets/audio/cry/"+id+".wav"),id)
		var moves:=SpeciesDB.enemy_moves(id,int(record.min_level))
		assert_false(moves.is_empty(),id)
		for move_id in moves:assert_true(MoveDB.is_shaped(move_id),id+" "+move_id)

func test_wild_species_can_act_at_their_lowest_encounter_level() -> void:
	for id in KantoWorldWild.data().species:
		if id in ["metapod","kakuna","abra","magikarp","wobbuffet"]:continue
		var w:=fixture("test_meadow")
		w.player.position=Arena.center()
		var e:=enemy(w,id,int(KantoWorldWild.data().species[id].min_level))
		var before:=w.player.hp
		for _i in 1800:
			w.step(1.0/60.0)
			if w.player.hp<before:break
		assert_lt(w.player.hp,before,id+" lands a legal attack")

func test_all_surf_and_fishing_areas_use_native_water_and_keep_spawns_aquatic() -> void:
	var owners: Dictionary={}
	for area in KantoWorldWild.data().tables:
		if KantoWorldWild.area(area).water_encounters.is_empty():continue
		var owner: String=DungeonDB.WARP_MAPS[area]
		if not owners.has(owner):owners[owner]=[]
		owners[owner].append(area)
	for owner in owners:
		var w:=fixture(owner)
		for area in owners[owner]:
			var rect:=Arena.area_rect(area)
			var chosen:=Vector2.INF
			for y in range(rect.position.y,rect.end.y):
				for x in range(rect.position.x,rect.end.x):
					var tile:=Vector2i(x,y);var at:=Arena.tile_center(tile)
					if not Arena.is_water(tile) or Arena.resolve(at,w.player.radius,false,2).distance_to(at)>0.1:continue
					w.player.position=at;w.player.travel_terrain=2
					if not w._wild_spawn_points(w.wild_cfg(),8.0).is_empty():chosen=at;break
				if chosen!=Vector2.INF:break
			assert_ne(chosen,Vector2.INF,area)
			if chosen==Vector2.INF:continue
			var cfg:=w.wild_cfg()
			assert_eq(cfg.encounter_terrain,"water")
			var pick:=DungeonDB.roll_table(cfg.encounters,w.rng)
			assert_true(w.queue_spawn(pick.species,pick.level),area)
			w._step_spawns(2.0)
			assert_eq(w.enemies.size(),1,area)
			for e in w.enemies:
				assert_eq(e.travel_terrain,1)
				assert_true(Arena.is_water(Arena.tile_of(e.position)))
				e.free()
			w.enemies.clear()
			for rod in FieldWater.RODS:
				assert_true(w.field_water.start_fishing(w,rod),area+" "+rod)
				w.field_water.cancel(w,false)

func test_ditto_copies_form_stats_and_moves_without_changing_identity_hp_or_rewards() -> void:
	var w:=fixture("test_meadow");w.player.position=Arena.center()
	var e:=enemy(w,"ditto",23);e.hp-=7
	var hp:=e.hp;var maximum:=e.max_hp;var pid:=e.pid;var exp:=w.exp_gain(e)
	w.player.atk_stage=2
	assert_true(WildActions.transform(w,e,w.player))
	assert_eq(e.species_id,"ditto")
	assert_eq(e.appearance_id(),"charmander")
	assert_eq(e.hp,hp);assert_eq(e.max_hp,maximum);assert_eq(e.pid,pid);assert_eq(e.level,23)
	assert_eq(e.types(),w.player.types());assert_eq(e.stats.atk,w.player.stats.atk);assert_eq(e.atk_stage,2)
	assert_eq(e.cds.keys(),["scratch"])
	assert_eq(w.exp_gain(e),exp)
	assert_false(WildActions.transform(w,e,w.player),"Transformed forms cannot transform again")

func test_counter_reflects_only_matching_direct_damage_and_never_chains() -> void:
	var w:=fixture("test_meadow");w.player.position=Arena.center()
	var e:=enemy(w,"wobbuffet",55)
	w.player.set_level(50,true)
	for pair in [["physical","scratch"],["special","ember"]]:
		e.hp=e.max_hp;e.invuln_t=0;w.player.invuln_t=0;w.player.hp=w.player.max_hp
		WildActions.stance(w,e,pair[0])
		var hit:=w.make_hit(w.player,pair[1]);hit.fixed=5;hit.mult=1.0
		var before:=w.player.hp
		w.apply_hit(e,hit,w.player.position)
		assert_eq(e.hp,e.max_hp-5)
		assert_eq(w.player.hp,before-10)
		assert_eq(e.counter_t,0.0)
	e.invuln_t=0;w.player.invuln_t=0
	WildActions.stance(w,e,"physical")
	var hit:=w.make_hit(w.player,"ember");hit.fixed=5;hit.mult=1.0
	var before:=w.player.hp
	w.apply_hit(e,hit,w.player.position)
	assert_eq(w.player.hp,before,"Special attack cannot trigger physical Counter")
	assert_gt(e.counter_t,0.0)
	e.hitstop_t=0.0
	e.tick_status(4.0)
	assert_eq(e.counter_t,0.0)
