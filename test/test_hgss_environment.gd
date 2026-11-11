extends GutTest
const EnvironmentArt = preload("res://scripts/view/hgss_environment.gd")

func test_original_card_and_house_geometry_is_removed_before_native_replacement() -> void:
	var dir := "res://assets/maps/kanto_world"
	var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(dir+"/hd2d_cards.json"))
	var specs: Dictionary=EnvironmentArt.replacements(dir)
	var remaining: Array=EnvironmentArt.remaining_cards(dir,metadata.cards)
	assert_eq(remaining.size(),metadata.cards.size()-specs.skip_cards.size(),"JSON float indices must remove actual original cards")
	for value in specs.skip_houses:assert_true(EnvironmentArt.replaces_house(dir,int(value)))

func test_native_shells_fit_existing_solid_envelopes_and_keep_gameplay_doors() -> void:
	var count := 0
	for id in EnvironmentArt.manifest().maps:
		var dir: String = "res://assets/maps/"+String(id)
		var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(dir+"/map.json"))
		for spec in EnvironmentArt.replacements(dir).buildings:
			var at := Vector2i(int(floor(spec.door[0])),int(floor(spec.door[1])))
			assert_true(metadata.warps.any(func(w):return int(w.x)==at.x and int(w.y)==at.y),id)
			var lo: Array=spec.bounds[0]
			var hi: Array=spec.bounds[1]
			assert_gte(float(spec.position[0]+lo[0]*spec.scale[0]),float(spec.envelope[0])-0.001,id)
			assert_lte(float(spec.position[0]+hi[0]*spec.scale[0]),float(spec.envelope[2])+0.001,id)
			assert_gte(float(spec.position[2]+lo[2]*spec.scale[2]),float(spec.envelope[1])-0.001,id)
			assert_lte(float(spec.position[2]+hi[2]*spec.scale[2]),float(spec.envelope[3])+0.001,id)
			assert_true(FileAccess.file_exists(spec.asset))
			count+=1
	assert_gt(count,50)

func test_native_ground_resources_keep_original_dimensions_and_alpha() -> void:
	for map in ["viridian_forest","mt_moon_1f","oaks_lab"]:
		var file: String=EnvironmentArt.manifest().terrain[map]["hd2d_floor.png"]
		var native:=Image.load_from_file(file)
		var original: Image=(load("res://assets/maps/"+map+"/hd2d_floor.png") as Texture2D).get_image()
		if original.is_compressed(): original.decompress()
		assert_eq(native.get_size(),original.get_size())
		assert_ne(native.get_data(),original.get_data(),map+" uses HGSS surface art")
		for y in range(0,native.get_height(),7):
			for x in range(0,native.get_width(),7):
				assert_eq(native.get_pixel(x,y).a,original.get_pixel(x,y).a,map)

func test_native_foliage_preserves_tree_roots_and_uses_an_alpha_cutout() -> void:
	const Canopy=preload("res://scripts/view/tree_canopy_3d.gd")
	var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/viridian_forest/hd2d_cards.json"))
	var texture:=EnvironmentArt.tree_texture()
	assert_not_null(texture)
	var trees=Canopy.groups(metadata.cards)
	var node=Canopy.build(metadata.cards,texture,1.0,false,0.8,texture)
	assert_eq(int(node.get_meta("trees")),trees.size())
	assert_true(node.get_meta("native_hgss"))
	assert_same(node.material_override.albedo_texture,texture)
	assert_true(texture.get_image().detect_alpha()!=Image.ALPHA_NONE)
	node.free()

func test_celadon_restaurant_only_replaces_its_four_facade_columns() -> void:
	var dir := "res://assets/maps/kanto_world"
	var replacements := EnvironmentArt.replacements(dir)
	var restaurant := Vector2(217.5, 149.5)
	var matches := 0
	for spec in replacements.buildings:
		if Vector2(spec.door[0], spec.door[1]) == restaurant:
			matches += 1
			assert_eq(int(spec.envelope[0]), 216)
			assert_eq(int(spec.envelope[2]), 220)
	assert_eq(matches, 1)
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir + "/hd2d_cards.json"))
	var row := {}
	for card in EnvironmentArt.remaining_cards(dir, metadata.cards):
		if int(card[1]) == 145 and int(card[2]) == 5:
			row[int(card[0])] = true
	for x in range(212, 232):
		assert_eq(row.has(x), x < 216 or x >= 220, "Celadon facade column %d" % x)

func test_house_projects_sun_shadow_without_the_painted_floor_surface() -> void:
	var path := "res://assets/maps/hgss_game_source/models/prop_field_313_017/mst_rdh.glb"
	var house := EnvironmentArt.model(path).instantiate()
	var surfaces: Array[String] = []
	for node: MeshInstance3D in house.find_children("*", "MeshInstance3D", true, false):
		assert_eq(node.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		for i in node.mesh.get_surface_count():
			surfaces.append(node.mesh.surface_get_material(i).resource_name)
	surfaces.sort()
	assert_eq(surfaces, ["h_in", "h_mado_lm1", "mt_rdh01", "mt_rdh02"])
	house.free()
