extends GutTest
func test_vermilion_rear_sand_is_not_a_roof_height_occluder() -> void:
	var dir := "res://assets/maps/kanto_east/"
	var d := data("kanto_east")
	var atlas := (load(dir+"hd2d_atlas.png") as Texture2D).get_image()
	var source := (load(dir+"preview.png") as Texture2D).get_image()
	var checked := 0
	for card in d.cards:
		if card.size()<10 or int(card[9])!=3 or int(card[1])!=54 or int(card[0]) not in [20,21]:continue
		checked+=1
		for y in 8:
			for x in 16:
				assert_eq(atlas.get_pixel(int(card[3])+x,int(card[4])+y).a,0.0,"Sandy rear margin cannot hide feet")
		for y in range(16,44):
			for x in 16:
				assert_eq(atlas.get_pixel(int(card[3])+x,int(card[4])+y),source.get_pixel(int(card[0])*16+160+x,54*16+160+y),"Native gold roof remains opaque and unchanged")
	assert_eq(checked,2)

func data(place: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/"+place+"/hd2d_cards.json"))
func test_building_columns_share_the_measured_pixel_fold() -> void:
	var buildings := 0
	for place in ["kanto_north","kanto_east","saffron_city"]:
		var d := data(place)
		for building in d.city_exteriors.buildings:
			buildings+=1
			var rect: Array = building.world_rect
			var count := 0
			for card in d.cards:
				if card.size()<11 or int(card[9])!=3:continue
				if int(card[0])<int(rect[0]) or int(card[0])>=int(rect[0])+int(rect[2]) or int(card[1])!=int(rect[1]):continue
				count+=1
				assert_almost_eq(float(card[5])*16,float(building.roof_px),0.001,"Continuous roof/front seam")
				assert_eq(int(card[2]),int(rect[3]))
				assert_between(int(card[10]),0,15)
				assert_between(float(card[11]),0.0,float(card[5]),"Side wall ends at visible rear roof edge")
			assert_eq(count,int(rect[2]))
	assert_eq(buildings,47)
func test_center_and_mart_badges_keep_original_pixels_upright() -> void:
	var badges := 0
	for place in ["kanto_north","kanto_east","saffron_city"]:
		var dir: String = "res://assets/maps/"+place+"/"
		var d := data(place)
		var raw := (load(dir+"preview.png") as Texture2D).get_image()
		for building in d.city_exteriors.buildings:
			if not building.has("badge"):continue
			badges+=1
			var image := (load(dir+"hd2d_city_"+building.id+"_badge_front.png") as Texture2D).get_image()
			var x0 := int(building.world_rect[0])*16+int(building.badge[0])+160
			var y0 := int(building.world_rect[1])*16+int(building.badge[1])+160
			var changed := 0
			for y in image.get_height():
				for x in image.get_width():
					var pixel := image.get_pixel(x,y)
					if pixel.a>0 and pixel!=raw.get_pixel(x0+x,y0+y):changed+=1
			assert_eq(changed,0,"Native logo pixels are not redrawn")
			assert_gt(image.get_pixel(image.get_width()/2,0).a,0.0,"Full badge crown survives the roof fold")
	assert_eq(badges,6)
func test_auto_house_does_not_duplicate_the_center_roof() -> void:
	var d := data("kanto_north")
	for building in d.city_exteriors.buildings:
		if building.id!="pokemon_center":continue
		var r: Array = building.world_rect
		for house in d.houses:
			var overlap: bool = float(house.x)<float(r[0])+float(r[2]) and float(house.x)+float(house.w)>float(r[0]) and float(house.z)>=float(r[1]) and float(house.z)<=float(r[1])+float(r[3])
			assert_false(overlap,"One center body and roof")
func test_coastal_water_is_flat_and_retains_original_floor_pixels() -> void:
	for place in ["kanto_north","kanto_east"]:
		var dir: String = "res://assets/maps/"+place+"/"
		var d := data(place)
		var water := {}
		for xy in d.city_exteriors.water_tiles:water[Vector2i(int(xy[0]),int(xy[1]))]=true
		assert_gt(water.size(),100)
		for card in d.cards:
			if card.size()>9 and int(card[9]) in [1,3]:continue
			for row in int(card[2]):
				assert_false(water.has(Vector2i(int(card[0]),int(card[1])+row)),"No upright ocean wall")
		var source := (load(dir+"preview.png") as Texture2D).get_image()
		var floor_image := (load(dir+"hd2d_floor.png") as Texture2D).get_image()
		for tile in water:
			var p: Vector2i = tile*16+Vector2i(168,168)
			assert_eq(floor_image.get_pixelv(p),source.get_pixelv(p),"Native water shading")
func test_rear_door_thresholds_remain_at_original_warp_centers() -> void:
	var dir := "res://assets/maps/kanto_north/"
	var d := data("kanto_north")
	assert_eq(d.city_exteriors.back_steps.size(),2)
	var map_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir+"map.json"))
	var source := (load(dir+"preview.png") as Texture2D).get_image()
	var floor_image := (load(dir+"hd2d_floor.png") as Texture2D).get_image()
	for warp in map_data.warps:
		if warp.map!="cerulean_city" or int(warp.index) not in [8,9]:continue
		var center := Vector2i(int(warp.x)*16+168,int(warp.y)*16+168)
		assert_eq(floor_image.get_pixelv(center),source.get_pixelv(center),"Rear-door landing remains visible")
