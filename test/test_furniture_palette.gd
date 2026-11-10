extends GutTest

const Palette = preload("res://scripts/view/furniture_palette.gd")

func test_preserves_source_alpha_and_colored_details() -> void:
	var original: Image = load("res://assets/maps/oaks_lab/hd2d_table3_front.png").get_image()
	var bytes := original.get_data()
	var result := Palette.surface(original, false)
	assert_eq(original.get_data(), bytes)
	assert_eq(result.get_size(), original.get_size())
	for y in original.get_height():
		for x in original.get_width():
			var c := original.get_pixel(x, y)
			var changed := result.get_pixel(x, y)
			assert_eq(c.a, changed.a)
			if maxf(c.r, maxf(c.g, c.b)) - minf(c.r, minf(c.g, c.b)) >= 0.12:
				assert_eq(c, changed, "Colored books stay unchanged")

func test_top_inset_and_highlight_headroom() -> void:
	var original := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	original.fill(Color(0.2, 0.2, 0.2))
	original.fill_rect(Rect2i(1, 1, 6, 6), Color.WHITE)
	var top := Palette.surface(original, true)
	var front := Palette.surface(original, false)
	assert_lt(top.get_pixel(3, 3).r, 0.9)
	assert_lt(top.get_pixel(1, 1).r, top.get_pixel(3, 3).r)
	assert_eq(front.get_pixel(1, 1), front.get_pixel(3, 3))
	assert_eq(top.get_pixel(0, 0), original.get_pixel(0, 0))
