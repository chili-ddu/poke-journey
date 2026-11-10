extends GutTest
func data(place: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/"+place+"/hd2d_cards.json"))
func after_each() -> void:
	DungeonDB.set_current(DungeonDB.DEFAULT)
	Arena.configure(DungeonDB.theme())
func test_surface_stairs_are_floor_openings_with_low_rails() -> void:
	for place in ["underground_path_north_entrance","underground_path_south_entrance"]:
		var d := data(place)
		assert_eq(d.underground.stair_direction,"down")
		var opening := false
		var rails := 0
		for obj in d.tables:
			if obj.id=="stairs_down_opening":
				opening=true
				assert_true(obj.decal,"Downstairs must not become an upright wall")
			if String(obj.id).begins_with("stair_rail_"):
				rails+=1
				assert_lte(float(obj.h),0.25)
		assert_true(opening)
		assert_eq(rails,4)
		DungeonDB.set_current(place)
		Arena.configure(DungeonDB.theme())
		assert_eq(Arena.warp_tile(place,3),Vector2i(7,4),"Native stair trigger")
		assert_false(Arena.solid_at(7,4))
func test_road_fences_are_not_merged_into_tall_columns() -> void:
	for place in ["kanto_north","kanto_east"]:
		var d := data(place)
		assert_gt(d.road_facilities.fence_tiles.size(),40)
		var floor_image := (load("res://assets/maps/"+place+"/hd2d_floor.png") as Texture2D).get_image()
		var lawn := [Color8(115,205,164),Color8(65,180,139),Color8(164,230,197),Color8(24,164,106)]
		var leftover := 0
		for xy in d.road_facilities.fence_tiles:
			for y in 16:
				for x in 16:
					if floor_image.get_pixel(int(xy[0])*16+160+x,int(xy[1])*16+160+y) not in lawn:leftover+=1
		assert_eq(leftover,0,"No flat fence artwork remains under upright posts")
		for tile in d.road_facilities.fence_tiles:
			var count := 0
			for c in d.cards:
				if c.size()>9 and int(c[9])==1:continue
				if int(c[0])==int(tile[0]) and int(c[1])<=int(tile[1]) and int(c[1])+int(c[2])>int(tile[1]):
					count+=1
					assert_eq(int(c[2]),1,"A native fence cell is one short object")
			assert_eq(count,1,"No duplicate fence fragment")
		for building in d.road_facilities.buildings:
			var count := 0
			for c in d.cards:
				if int(c[0])>=int(building.world_x) and int(c[0])<int(building.world_x)+int(building.w) and int(c[1])==int(building.world_y):
					count+=1
					assert_eq(int(c[2]),int(building.h))
					assert_eq(int(c[5]),int(building.roof),"One continuous roof/front seam")
			assert_eq(count,int(building.w))
func test_tunnel_keeps_native_floor_and_has_cutaway_side_walls() -> void:
	var dir := "res://assets/maps/underground_path_north_south_tunnel/"
	var d := data("underground_path_north_south_tunnel")
	assert_eq(d.underground.stair_direction,"up")
	for side in d.corner_walls:assert_lte(float(side.h),0.75,"Side walls leave corridor visible")
	var original := (load(dir+"preview.png") as Texture2D).get_image()
	var floor_image := (load(dir+"hd2d_floor.png") as Texture2D).get_image()
	for p in [Vector2i(40,136),Vector2i(88,264),Vector2i(40,488),Vector2i(88,808)]:
		assert_eq(floor_image.get_pixelv(p+Vector2i(160,160)),original.get_pixelv(p+Vector2i(160,160)),"Original colored floor bands")
	DungeonDB.set_current("underground_path_north_south_tunnel")
	Arena.configure(DungeonDB.theme())
	assert_eq(Arena.warp_tile("underground_path_north_south_tunnel",0),Vector2i(4,3))
	assert_eq(Arena.warp_tile("underground_path_north_south_tunnel",1),Vector2i(3,60))
func test_city_gate_partitions_keep_native_return_doors() -> void:
	for place in ["route5_south_entrance","route6_north_entrance"]:
		var d := data(place)
		var partitions := 0
		for obj in d.tables:
			if not String(obj.id).begins_with("gate_partition_"):continue
			partitions+=1
			assert_true(obj.box)
			assert_almost_eq(float(obj.h),0.5,0.001)
		assert_eq(partitions,2)
		DungeonDB.set_current(place)
		Arena.configure(DungeonDB.theme())
		var expected := Vector2i(4,1) if place=="route5_south_entrance" else Vector2i(4,9)
		assert_false(Arena.solid_at(expected.x,expected.y))
		assert_false(Arena.warp_at(Arena.tile_center(expected)).is_empty())
	assert_true(DungeonDB.WARP_MAPS.has("saffron_city"),"Both native gates now continue into the open city")

func test_city_gate_foliage_keeps_native_pixels_without_floor_or_flat_pots() -> void:
	for place in ["route5_south_entrance","route6_north_entrance"]:
		var d:=data(place)
		var dir: String="res://assets/maps/"+place+"/"
		var source: Image=(load(dir+"preview.png") as Texture2D).get_image()
		assert_eq(d.gate_facility.plants.size(),6)
		for plant in d.gate_facility.plants:
			var item: Dictionary=d.tables.filter(func(o):return o.id==plant.id)[0]
			assert_true(item.planter,"Solid pot below the foliage")
			assert_eq(float(item.base),float(plant.pot_height),"Stem touches the soil without a gap")
			var foliage: Image=(load(dir+item.tex+"_front.png") as Texture2D).get_image()
			assert_eq(foliage.get_size(),Vector2i(16,16),"Only foliage and stem; no old flat pot")
			var transparent:=0
			for y in 16:
				for x in 16:
					var c:=foliage.get_pixel(x,y)
					if c.a==0:
						transparent+=1
						continue
					assert_eq(c,source.get_pixel(160+int(plant.source[0])+x,160+int(plant.source[1])+y),"Native leaf colors")
					assert_false(c.r>=c.g and c.g>c.b+25.0/255.0,"Gold floor cannot stand behind leaves")
			assert_gt(transparent,30)

func test_city_gate_plant_floor_matches_the_original_shaded_side_strip() -> void:
	for place in ["route5_south_entrance","route6_north_entrance"]:
		var d:=data(place)
		var dir: String="res://assets/maps/"+place+"/"
		var source: Image=(load(dir+"preview.png") as Texture2D).get_image()
		var floor_image: Image=(load(dir+"hd2d_floor.png") as Texture2D).get_image()
		for plant in d.gate_facility.plants:
			var x0:=int(plant.source[0]);var y0:=int(plant.source[1])
			for y in range(y0,int(plant.source[3])):
				for x in range(x0,int(plant.source[2])):
					assert_eq(floor_image.get_pixel(160+x,160+y),source.get_pixel(160+x0+x%16,160+4*16+y%16),"No flat plant or rectangular floor patch")
