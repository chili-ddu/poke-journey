extends GutTest
const Exposure = preload("res://scripts/battle/trainer_exposure.gd")
const Data = preload("res://scripts/data/road_trainer_db.gd")
class Idle:
	extends RefCounted
	func move_dir(_w):return Vector2.ZERO
	func aim_point(w):return w.player.position
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false

func after_each() -> void:
	DungeonDB.set_current(DungeonDB.DEFAULT)
	Arena.configure(DungeonDB.theme())

func cave_world(place: String) -> World:
	DungeonDB.set_current(place)
	Arena.configure(DungeonDB.theme())
	var w:=World.new()
	add_child_autofree(w)
	w.setup(17,"charmander",5,["scratch"],Idle.new())
	if place.begins_with("mt_moon"):
		w.player.position=Arena.tile_center(Vector2i(24,20)) # Open main chamber, clear of ladders and isolated side rooms.
	w.cam.zoom=Vector2(3,3) # Match a gameplay-sized view inside the larger test viewport.
	w.cam.position=w.player.position
	w.cam.reset_smoothing()
	w.cam.force_update_scroll()
	return w

func test_cave_rosters_use_original_parties_and_cave_arena() -> void:
	assert_eq(Data.POOLS.mt_moon_1f.size(),7)
	assert_eq(Data.POOLS.mt_moon_b2f.size(),4)
	assert_false(Data.POOLS.has("mt_moon_b1f"),"The original connecting floor has no roaming trainers")
	assert_eq(TrainerDB.get_trainer("mt_moon_1f_scientist_jovan").party,[["magnemite",11],["voltorb",11]])
	assert_eq(TrainerDB.get_trainer("mt_moon_b2f_rocket_m_grunt1").party,[["rattata",13],["zubat",13]])
	for place in ["mt_moon_1f","mt_moon_b2f"]:
		for id in Data.POOLS[place]:
			assert_eq(TrainerDB.arena_of(id),"arena_mt_moon")
			assert_true(ResourceLoader.exists("res://assets/npcs/%s.png"%TrainerDB.sprite(id)))
			assert_false(TrainerDB.berry_rewards(id).is_empty())
			for member in TrainerDB.get_trainer(id).party:
				var dex:=int(SpeciesDB.get_species(member[0]).dex)
				assert_true(MonSprite.load_set(dex,false).has("Walk"),member[0])
				assert_true(MonSprite.load_set(dex,true).has("Walk"),member[0]+" shiny")

func test_exposure_spawns_connected_offscreen_trainers_on_both_cave_floors() -> void:
	for place in ["mt_moon_1f","mt_moon_b2f"]:
		var w:=cave_world(place)
		var e=Exposure.new()
		e.sync_visit(place)
		assert_false(e.remaining_ids(5).is_empty())
		assert_true(e.gauge_visible(5))
		e.step(w,null,33.0,[],true)
		assert_almost_eq(e.attention,99.0,0.001)
		assert_true(e.pursuits.is_empty(),"No trainer before the gauge fills")
		e.step(w,null,1.0,[],true)
		assert_eq(e.attention,100.0)
		assert_eq(e.pursuits.size(),1,place+" begins a search when exposure reaches 100")
		if e.pursuits.is_empty():continue
		var driver=e.pursuits[0]
		assert_false(driver.visible_at(w,null,driver.actor.position),"Trainer enters from offscreen")
		assert_eq(Arena.area_at(driver.actor.position),place)
		assert_false(driver.route(Arena.tile_of(driver.actor.position),Arena.tile_of(w.player.position)).is_empty())
		assert_eq(driver.phase,"search")
		assert_true(e.deployed.has(driver.actor.trainer_id))
		var saved: Dictionary=e.snapshot()
		var restored=Exposure.new()
		restored.restore_visit(w,saved)
		assert_eq(restored.deployed,e.deployed)
		assert_eq(restored.pursuits.size(),1,"Search survives returning from a trainer battle")
		assert_eq(restored.attention,100.0)
		var caught=restored.pursuits[0]
		caught.actor.position=Arena.tile_center(caught.player_cell(w))
		assert_eq(caught.step(w,null,0.0,[],false),caught.actor,"Finding the player starts the trainer encounter")
		assert_eq(caught.phase,"engaged")

func test_cave_arena_keeps_battle_field_clear_and_uses_indoor_lighting() -> void:
	cave_world("arena_mt_moon")
	assert_true(DungeonDB.is_arena())
	assert_true(View3D.supported("res://assets/maps/arena_mt_moon"))
	assert_eq(View3D.sky_kind("arena_mt_moon"),"indoor")
	var field: Array=Arena.map.arena.field
	for y in range(int(field[1]),int(field[1])+int(field[3])):
		for x in range(int(field[0]),int(field[0])+int(field[2])):
			assert_false(Arena.solid_at(x,y))
