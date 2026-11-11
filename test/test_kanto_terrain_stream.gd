extends GutTest

const Stream = preload("res://scripts/view/kanto_terrain_stream.gd")
const MAP := "res://assets/maps/kanto_world"

func after_each() -> void:
	DungeonDB.set_current(DungeonDB.DEFAULT)
	Arena.configure(DungeonDB.theme())

func test_door_boundary_fast_travel_and_negative_continent_coordinates() -> void:
	DungeonDB.set_current("kanto_world")
	Arena.configure(DungeonDB.theme())
	var bounds := Rect2i(0, 0, Arena.map.width, Arena.map.height).grow(Arena._pad)
	var first := Stream.cell_at(bounds.position)
	var last := Stream.cell_at(bounds.end - Vector2i.ONE)
	for y in range(first.y, last.y+1):
		for x in range(first.x, last.x+1):
			assert_true(ResourceLoader.exists(Stream.mesh_path(Vector2i(x, y)), "PackedScene"))
	var view := View3D.new()
	add_child_autofree(view)
	view.root3d = Node3D.new()
	view.add_child(view.root3d)
	var stream := Stream.new()
	view.root3d.add_child(stream)
	stream.setup(view, MAP, JSON.parse_string(FileAccess.get_file_as_string(MAP.path_join("hd2d_cards.json"))))
	assert_eq(stream.shows_grass_at(Vector2i(72, 259)), not View3D.HgssEnvironment.enabled, "Open seam on Route 1")
	assert_true(stream.shows_grass_at(Vector2i(72, 258)), "Adjacent visible grass")
	stream.stream(Vector2(76, 275))
	assert_eq(stream.active.size(), 9)
	var middle: Node3D = stream.active[Vector2i(2, 8)]
	assert_true(middle.has_node("RoadElevationFloor"))
	_check_nearby_models(stream)
	for i in 5: stream.stream(Vector2(96, 275))
	assert_eq(stream.active.size(), 9)
	assert_same(middle, stream.active[Vector2i(2, 8)], "Neighbors are reused across the boundary")
	assert_false(stream.active.has(Vector2i(1, 8)))
	assert_true(stream.active.has(Vector2i(4, 9)), "Diagonal ahead is ready")
	_check_nearby_models(stream)
	stream.stream(Vector2(414, 405))
	assert_true(stream.active.has(Vector2i(12, 12)), "Teleport draws the destination on its first frame")
	assert_true(stream.active.has(Vector2i(13, 12)), "Partial padding cell is included")
	assert_false(stream.active.has(Vector2i(2, 8)))
	assert_lte(stream.active.size(), 9)
	stream.stream(Vector2(-100, 275))
	assert_true(stream.active.is_empty())
	stream.stream(Vector2(-1, 0))
	assert_true(stream.active.has(Vector2i(-1, 0)))
	assert_true(stream.active.has(Vector2i(0, 0)))
	assert_eq(Stream.cell_at(Vector2(-0.1, -0.1)), -Vector2i.ONE)
	var floor_node: MeshInstance3D = stream.active[Vector2i(-1, 0)].get_node("RoadElevationFloor")
	var material := floor_node.material_override as StandardMaterial3D
	assert_eq(material.albedo_texture.get_size(), Vector2(Arena._pad * Arena.SRC_TILE, Stream.CELL * Arena.SRC_TILE))

func _check_nearby_models(stream: Stream) -> void:
	var expected := {}
	for spec in View3D.HgssEnvironment.replacements(MAP).get("buildings", []):
		var door := Vector2(spec.door[0], spec.door[1])
		if stream.active.has(Stream.cell_at(door)): expected[door] = true
	var actual := {}
	for group: Node3D in stream.active.values():
		for child in group.get_children():
			if child.has_meta("hgss_door"): actual[child.get_meta("hgss_door")] = true
	assert_eq(actual, expected)

func test_compact_atlas_keeps_each_source_strip_in_both_art_sets() -> void:
	var atlas := load(MAP.path_join("card_atlas.res"))
	var offsets: Dictionary = atlas.get_meta("offsets")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAP.path_join("hd2d_cards.json")))
	var heights := {}
	for card in data.cards:
		var origin := Vector2i(card[3], card[4])
		heights[origin] = maxi(heights.get(origin, 0), int(card[2]) * int(data.tile))
	var sources := {"original_png":MAP.path_join("hd2d_atlas.png"), "hgss_png":View3D.HgssEnvironment.manifest().terrain.kanto_world["hd2d_atlas.png"]}
	for key in sources:
		var compact := Image.new()
		assert_eq(compact.load_png_from_buffer(atlas.get_meta(key)), OK)
		var source := Image.new()
		assert_eq(source.load_png_from_buffer(FileAccess.get_file_as_bytes(sources[key])), OK)
		source.convert(Image.FORMAT_RGBA8)
		assert_lt(compact.get_width()*compact.get_height(), source.get_width()*source.get_height())
		for origin: Vector2i in heights:
			var size := Vector2i(data.tile, heights[origin])
			if not offsets.has(origin) or source.get_region(Rect2i(origin, size)).get_data() != compact.get_region(Rect2i(offsets[origin], size)).get_data():
				fail_test("Changed source pixels for %s strip at %s" % [key, origin])
				return
