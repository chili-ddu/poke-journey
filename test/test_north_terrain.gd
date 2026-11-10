extends GutTest
func image_at(path: String) -> Image:
	return (load(path) as Texture2D).get_image()
func test_road_cliffs_preserve_original_rock_pixels() -> void:
	var dir := "res://assets/maps/kanto_north/"
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir+"hd2d_cards.json"))
	var raw := image_at(dir+"preview.png")
	var atlas := image_at(dir+"hd2d_atlas.png")
	var browns := [Color8(222,197,164),Color8(189,148,139),Color8(148,106,106),Color8(123,74,74),Color8(90,57,65)]
	var checked := 0
	var missing := 0
	var columns := 0
	for c in data.cards:
		if c.size()<11 or int(c[9])!=2:continue
		columns+=1
		assert_eq(int(c[2])-int(c[5]),1,"Consistent outdoor cliff height")
		assert_between(int(c[10]),0,15,"Side samples source rock pixels")
		for y in int(c[2])*16:
			for x in 16:
				var original := raw.get_pixel(int(c[0])*16+160+x,int(c[1])*16+160+y)
				if original not in browns:continue
				checked+=1
				if atlas.get_pixel(int(c[3])+x,int(c[4])+y)!=original:missing+=1
	assert_gt(columns,100)
	assert_gt(checked,100000)
	assert_eq(missing,0,"Rock shading cannot be mistaken for transparent ground")
func test_cave_floor_donors_cannot_duplicate_ladders_or_thresholds() -> void:
	for place in ["mt_moon_1f","mt_moon_b1f","mt_moon_b2f"]:
		var dir: String = "res://assets/maps/"+place+"/"
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir+"hd2d_cards.json"))
		assert_eq(int(data.floor_donor_mid),0x281,"Native plain floor")
		var raw := image_at(dir+"preview.png")
		var floor_image := image_at(dir+"hd2d_floor.png")
		var donor := Vector2i(int(data.floor_donor_tile[0]),int(data.floor_donor_tile[1]))*16+Vector2i(160,160)
		for item in data.terrain_objects:
			var tile := Vector2i(int(item.tile[0]),int(item.tile[1]))*16+Vector2i(160,160)
			var differences := 0
			for y in 16:
				for x in 16:
					if floor_image.get_pixelv(tile+Vector2i(x,y))!=raw.get_pixelv(donor+Vector2i(x,y)):differences+=1
			assert_eq(differences,0,"Clean floor under standalone source rock/sign")
func test_small_cave_rocks_are_not_tall_cliff_columns() -> void:
	var rocks := 0
	var signs := 0
	for place in ["mt_moon_1f","mt_moon_b1f","mt_moon_b2f"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/"+place+"/hd2d_cards.json"))
		for item in data.terrain_objects:
			if int(item.mid)==0x2cd:signs+=1
			else:rocks+=1
		for obj in data.tables:
			assert_true(obj.card)
			assert_lte(float(obj.h),0.875,"Native small rock scale")
	assert_eq(rocks,70)
	assert_eq(signs,1)
