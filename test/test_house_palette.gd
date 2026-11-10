extends GutTest
const Palette = preload("res://scripts/view/house_palette.gd")

func test_roofs_keep_tiles_without_wall_strip() -> void:
	for index in 3:
		var source: Image = load("res://assets/maps/kanto_south/hd2d_house%d_rooftop.png" % index).get_image()
		var bytes := source.get_data()
		var roof := Palette.roof(source)
		assert_eq(roof.get_width(), source.get_width())
		assert_lt(roof.get_height(), source.get_height())
		assert_eq(source.get_data(), bytes)
		assert_eq(roof.get_data(), source.get_region(Rect2i(Vector2i.ZERO, roof.get_size())).get_data())
		var edge := Palette.eave(source)
		assert_gt(edge.get_pixel(0, 0).r, edge.get_pixel(0, 1).r)
		assert_gt(edge.get_pixel(0, 1).r, edge.get_pixel(0, 2).r)

func test_wall_preserves_windows_below_join_and_alpha() -> void:
	var source: Image = load("res://assets/maps/kanto_south/hd2d_house1_side.png").get_image()
	var result := Palette.wall(source)
	var body := Rect2i(0, 2, source.get_width(), source.get_height() - 2)
	assert_eq(result.get_region(body).get_data(), source.get_region(body).get_data())
	for y in 2:
		for x in source.get_width():
			assert_eq(result.get_pixel(x, y).a, source.get_pixel(x, y).a)
