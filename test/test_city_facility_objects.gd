extends GutTest
const PLACES := ["cerulean_city_bike_shop","vermilion_city_pokemon_fan_club","cerulean_city_gym","vermilion_city_gym"]
func data(place: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/"+place+"/hd2d_cards.json"))
func after_each() -> void:
	DungeonDB.set_current(DungeonDB.DEFAULT)
	Arena.configure(DungeonDB.theme())
func test_facility_objects_replace_implicit_fragments() -> void:
	for place in PLACES:
		var d := data(place)
		var ids := {}
		assert_eq(d.tables.size(),d.facility_objects.size(),"Only explicitly extracted source objects")
		for o in d.facility_objects:
			assert_false(ids.has(o.id),"Unique object")
			ids[o.id]=true
			var file: String = "res://assets/maps/"+place+"/"+o.tex
			assert_true(ResourceLoader.exists(file+("_edge.png" if o.kind=="table" else "_front.png")),o.id)
		for c in d.cards:
			assert_eq(int(c[5]),0,"Walls stay upright")
			assert_true(int(c[1])==0 or (place=="vermilion_city_gym" and int(c[1])==6),"No leftover furniture strips")
func test_bike_shop_retains_all_eight_original_bicycles() -> void:
	var bikes := 0
	for t in data(PLACES[0]).tables:
		if not String(t.id).begins_with("display_bicycle_"): continue
		bikes+=1
		assert_true(t.card)
		assert_false(t.get("decal",false))
		assert_almost_eq(float(t.h),1.0,0.001)
	assert_eq(bikes,8,"Two red and six blue bicycles in source")
func test_pool_and_bridge_are_preserved_on_the_floor() -> void:
	var dir := "res://assets/maps/cerulean_city_gym/"
	var source := (load(dir+"preview.png") as Texture2D).get_image()
	var floor_image := (load(dir+"hd2d_floor.png") as Texture2D).get_image()
	for p in [Vector2i(40,100),Vector2i(230,100),Vector2i(136,160),Vector2i(80,208)]:
		assert_eq(floor_image.get_pixelv(p+Vector2i(160,160)),source.get_pixelv(p+Vector2i(160,160)),"Native water and bridge pixels")
	var ladders := 0
	for t in data(PLACES[2]).tables:
		if String(t.id).begins_with("pool_ladder_"):ladders+=1
	assert_eq(ladders,4)
func test_trash_cans_and_statue_pedestals_keep_their_collision() -> void:
	DungeonDB.set_current("vermilion_city_gym")
	Arena.configure(DungeonDB.theme())
	var cans := 0
	for t in data(DungeonDB.current).tables:
		if not String(t.id).begins_with("trash_can_"):continue
		cans+=1
		assert_true(t.box)
		assert_lte(float(t.h),0.5)
		var tile := Vector2i(floori((float(t.x0)+float(t.x1))*0.5),floori(float(t.z1)))
		assert_true(Arena.solid_at(tile.x,tile.y),"Can blocks its original cell")
	assert_eq(cans,15)
	for place in ["cerulean_city_gym","vermilion_city_gym"]:
		DungeonDB.set_current(place)
		Arena.configure(DungeonDB.theme())
		for x in ([6,10] if place=="cerulean_city_gym" else [3,7]):
			assert_false(Arena.solid_at(x,16),"Walk behind upper statue image")
			assert_true(Arena.solid_at(x,17),"Pedestal stays solid")
func test_club_table_has_horizontal_top_and_four_corner_legs() -> void:
	for t in data(PLACES[1]).tables:
		if t.id!="club_table":continue
		assert_false(t.get("card",false))
		assert_false(t.get("box",false))
		assert_eq(t.legs.size(),2,"Two leg columns, duplicated front/back by renderer")
		assert_gt(float(t.leg),0.0)
		assert_gt(float(t.z1)-float(t.z0),1.0)
		return
	fail_test("Club table exists")

func test_burgled_house_keeps_its_broken_wall_and_footprints() -> void:
	var dir := "res://assets/maps/cerulean_city_house2/"
	var src := (load(dir+"preview.png") as Texture2D).get_image()
	var floor_image := (load(dir+"hd2d_floor.png") as Texture2D).get_image()
	var wall := (load(dir+"hd2d_atlas.png") as Texture2D).get_image()
	for p in [Vector2i(72,16),Vector2i(64,8),Vector2i(84,12)]:
		assert_eq(wall.get_pixelv(p),src.get_pixelv(p+Vector2i(160,160)),"Original wall breach")
	for p in [Vector2i(88,40),Vector2i(112,96),Vector2i(120,104),Vector2i(152,96)]:
		assert_eq(floor_image.get_pixelv(p+Vector2i(160,160)),src.get_pixelv(p+Vector2i(160,160)),"Original damage trail")
	for t in data("cerulean_city_house2").tables:
		if t.id=="fallen_plant":
			assert_true(t.decal,"Fallen plant stays on the floor")
			return
	fail_test("Original fallen plant is present")

func test_daycare_stools_are_low_plinths_and_pen_floor_survives() -> void:
	var stools := 0
	for t in data("route5_pokemon_day_care").tables:
		if not String(t.id).begins_with("stool_"):continue
		stools+=1
		assert_true(t.box)
		assert_almost_eq(float(t.h),0.25,0.001)
		assert_false(t.has("legs"),"Solid stool base")
	assert_eq(stools,4)
	var dir := "res://assets/maps/route5_pokemon_day_care/"
	var src := (load(dir+"preview.png") as Texture2D).get_image()
	var floor_image := (load(dir+"hd2d_floor.png") as Texture2D).get_image()
	for p in [Vector2i(24,40),Vector2i(40,48),Vector2i(88,56),Vector2i(80,104)]:
		assert_eq(floor_image.get_pixelv(p+Vector2i(160,160)),src.get_pixelv(p+Vector2i(160,160)),"Original pen and carpet")

func test_special_house_tables_have_separate_tops_and_four_legs() -> void:
	var count := 0
	for place in ["cerulean_city_house1","cerulean_city_house2","cerulean_city_house5","route5_pokemon_day_care"]:
		for t in data(place).tables:
			if not t.has("legs"):continue
			count+=1
			assert_eq(t.legs.size(),2)
			assert_almost_eq(float(t.leg),0.5,0.001)
			assert_almost_eq(float(t.z1)-float(t.z0),2.0,0.001)
			assert_true(ResourceLoader.exists("res://assets/maps/"+place+"/"+t.tex+"_leg.png"))
	assert_eq(count,5)
