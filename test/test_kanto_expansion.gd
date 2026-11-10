extends GutTest

func after_each() -> void:
	DungeonDB.set_current(DungeonDB.DEFAULT)
	Arena.configure(DungeonDB.theme())

func test_departed_harbor_is_connected_and_has_no_boarding_triggers() -> void:
	assert_eq(DungeonDB.WARP_MAPS.ssanne_exterior,"vermilion_harbor")
	assert_eq(Bgm.place("ssanne_exterior"),"mus_vermillion")
	DungeonDB.set_current("vermilion_harbor");Arena.configure(DungeonDB.theme())
	assert_true(DungeonDB.is_overworld())
	assert_true(View3D.supported(DungeonDB.theme().map))
	var exits:=Arena.warps().duplicate(true)
	assert_eq(exits.size(),3)
	for warp in exits:assert_eq(warp.to,"vermilion_city","Only town exits remain after departure")
	for y in range(6,14):
		var tile:=Vector2i(32,y)
		assert_false(Arena.solid_at(tile.x,tile.y))
		var at:=Arena.tile_center(tile)
		assert_lt(Arena.resolve(at,8.0).distance_to(at),0.1,"Walkable pier to the empty berth")
	for tile in [Vector2i(32,14),Vector2i(33,15)]:
		assert_true(Arena.solid_at(tile.x,tile.y),"Former boarding tiles cannot lead into the sea")
		assert_true(Arena.warp_at(Arena.tile_center(tile)).is_empty())
	assert_true(Arena.is_water(Vector2i(20,15)))
	assert_true(Arena.solid_at(20,15),"Sea is not walking ground")
	DungeonDB.set_current("kanto_east");Arena.configure(DungeonDB.theme())
	var entrances: Array=Arena.warps().filter(func(w):return w.to=="ssanne_exterior")
	assert_eq(entrances.size(),3)
	for warp in entrances:
		assert_false(Arena.solid_at(int(warp.x),int(warp.y)))
		assert_true(exits.any(func(w):return int(w.index)==int(warp.to_warp)))
		assert_true(exits.any(func(w):return int(w.to_warp)==int(warp.index)),"Each town lane has a return exit")
	var cards: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(DungeonDB.theme().map+"/hd2d_cards.json"))
	for card in cards.cards:
		if int(card[0]) not in [22,23,24]:continue
		assert_false(int(card[1])<80 and int(card[1])+int(card[2])>74,"No building roof over the pier entrance")

func test_all_expansion_locations_have_hd2d_and_registered_source_maps() -> void:
	assert_eq(DungeonDB.Expansion.DUNGEONS.size(),28)
	for place in DungeonDB.Expansion.DUNGEONS:
		assert_true(DungeonDB.has_location(place),place)
		DungeonDB.set_current(place)
		var dir := String(DungeonDB.theme().map)
		assert_true(View3D.supported(dir),place+" HD-2D")
		Arena.configure(DungeonDB.theme())
		assert_true(Arena.has_map(),place)
		var start: Vector2 = Arena.map.start
		assert_lt(Arena.resolve(start,6.0).distance_to(start),0.1,place+" start is traversable")

func test_every_supported_door_resolves_to_an_open_destination() -> void:
	var maps := {}
	for place in DungeonDB.DUNGEONS:
		var cfg: Dictionary = DungeonDB.THEMES[DungeonDB.DUNGEONS[place].theme]
		if not cfg.has("map"): continue
		maps[place]=JSON.parse_string(FileAccess.get_file_as_string(cfg.map+"/map.json"))
	for place in DungeonDB.Expansion.DUNGEONS:
		DungeonDB.set_current(place)
		Arena.configure(DungeonDB.theme())
		for warp in Arena.warps():
			if not DungeonDB.WARP_MAPS.has(warp.to): continue
			var dest: String = DungeonDB.warp_destination(warp)
			var match_warp := false
			for other in maps[dest].warps:
				if other.map==warp.to and int(other.index)==int(warp.to_warp): match_warp=true;break
			assert_true(match_warp,place+" -> "+warp.to+":"+str(warp.to_warp))
			var tile := Vector2i(int(warp.x),int(warp.y))
			assert_false(Arena.solid_at(tile.x,tile.y),place+" source doorway")

func test_pewter_route3_share_a_field_without_edge_warps() -> void:
	for place in ["kanto_south", "kanto_north"]:
		DungeonDB.set_current(place)
		Arena.configure(DungeonDB.theme())
		for warp in Arena.warps():
			# The new northern region has explicit reciprocal links; the old field seam stays continuous.
			if warp.get("cerulean_north_link",false):
				assert_eq(warp.to,"route24")
				continue
			if warp.get("rock_pass_link",false):
				assert_eq(warp.to,"route9")
				var city:=Arena.area_rect("cerulean_city")
				assert_eq(int(warp.x),city.end.x-1,"New region links start at the city's eastern boundary")
				continue
			assert_false(warp.get("edge_transition", false), "No teleport strip inside the existing field")
		for y in [40, 41]:
			for x in range(45, 52):
				var tile := Vector2i(x, y)
				assert_false(Arena.solid_at(x, y), "Continuous walking lane")
				assert_true(Arena.warp_at(Arena.tile_center(tile)).is_empty())
				assert_lt(Arena.resolve(Arena.tile_center(tile), 6.0).distance_to(Arena.tile_center(tile)), 0.1)
		assert_eq(Arena.area_at(Arena.tile_center(Vector2i(47, 40))), "pewter_city")
		assert_eq(Arena.area_at(Arena.tile_center(Vector2i(48, 40))), "route3")
		assert_false(DungeonDB.area_cfg("route3").is_empty())
		assert_false(DungeonDB.area_cfg("route1").is_empty())
	assert_eq(DungeonDB.WARP_MAPS.route3, DungeonDB.WARP_MAPS.pewter_city)

func test_new_centers_keep_local_services_and_no_link_floor() -> void:
	for place in ["route4_pokemon_center_1f","cerulean_city_pokemon_center_1f","vermilion_city_pokemon_center_1f"]:
		DungeonDB.set_current(place)
		assert_true(DungeonDB.is_indoor())
		assert_eq(DungeonDB.DUNGEONS[place].npcs[0].talk,"nurse")
		Arena.configure(DungeonDB.theme())
		for warp in Arena.warps(): assert_false(String(warp.to).ends_with("_2f"))
	for place in ["cerulean_city_mart","vermilion_city_mart"]:
		assert_eq(DungeonDB.DUNGEONS[place].npcs[0].talk,"shop")

func test_expanded_places_use_original_location_music() -> void:
	assert_eq(Bgm.place("cerulean_city"),"mus_fuchsia")
	assert_eq(Bgm.place("vermilion_city"),"mus_vermillion")
	assert_eq(Bgm.place("mt_moon_b2f"),"mus_mt_moon")
	for song in DungeonDB.Expansion.MUSIC.values():
		assert_true(ResourceLoader.exists(Bgm.DIR+song+".wav"),song)

func test_cave_heightfield_preserves_source_footprints_and_open_paths() -> void:
	for place in ["mt_moon_1f","mt_moon_b1f","mt_moon_b2f"]:
		var dir: String = DungeonDB.Expansion.THEMES[place].map
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir+"/hd2d_cards.json"))
		var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir+"/map.json"))
		assert_eq(data.terrain,"heightfield_cave_cliffs")
		assert_true(data.cards.is_empty(),"No flattened cliff billboards")
		var field: Dictionary = data.heightfield
		var occupied := {}
		var expected_walls := 0
		for cell in field.tiles:
			var tile := Vector2i(int(cell[0]),int(cell[1]))
			assert_false(occupied.has(tile),"One top surface per cell")
			occupied[tile]=true
			assert_eq(float(field.heights[tile.y][tile.x]),1.0,"Explicit cliff elevation")
			for d in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
				var n: Vector2i = tile+d
				if n.x>=0 and n.y>=0 and n.x<int(source.width) and n.y<int(source.height) and float(field.heights[n.y][n.x])==0:expected_walls+=1
		for item in data.terrain_objects:
			var tile := Vector2i(int(item.tile[0]),int(item.tile[1]))
			assert_false(occupied.has(tile),"Rock is separate from cliff")
			occupied[tile]=true
		for flat in data.flat_terrain_tiles:
			occupied[Vector2i(int(flat[0]),int(flat[1]))]=true
			assert_eq(float(field.heights[int(flat[1])][int(flat[0])]),0.0,"Ladder shaft/threshold artwork is not a cliff cube")
		for y in int(source.height):
			for x in int(source.width):
				assert_eq(occupied.has(Vector2i(x,y)),source.solid[y][x]=="1","Original collision footprint")
		for warp in source.warps:
			assert_eq(float(field.heights[int(warp.y)][int(warp.x)]),0.0,"Exit and ladder remain at floor height")
		var view := View3D.new()
		view.k=1.8 # Camera-dependent sprite scaling must not change terrain elevation.
		view.root3d=Node3D.new()
		view.add_child(view.root3d)
		view._build_cards(dir)
		var mesh: MeshInstance3D = view.root3d.get_node("TerrainHeightfield")
		assert_eq(int(mesh.get_meta("boundary_faces")),expected_walls,"Every exposed side closed; no internal walls")
		assert_eq(mesh.mesh.surface_get_array_len(0),(int(mesh.get_meta("top_faces"))+expected_walls)*6)
		var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for v in vertices:
			assert_true(is_zero_approx(v.y) or is_equal_approx(v.y,1.0),"Mesh uses shared floor/top elevations")
		view.free()
