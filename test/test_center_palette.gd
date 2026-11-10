extends GutTest
const Palette = preload("res://scripts/view/center_palette.gd")

func test_only_tile_palette_changes_without_mutating_source() -> void:
	var source := Image.create(8, 1, false, Image.FORMAT_RGBA8)
	var colors: Array = Palette.FLOOR_COLORS.keys() + [Color.WHITE, Color.TRANSPARENT, Color8(205, 82, 65)]
	for x in colors.size():
		source.set_pixel(x, 0, colors[x])
	var bytes := source.get_data()
	var out := Palette.floor_surface(source)
	assert_eq(source.get_data(), bytes)
	assert_eq(out.get_size(), source.get_size())
	for x in colors.size():
		var c := source.get_pixel(x, 0)
		assert_eq(out.get_pixel(x, 0), Palette.FLOOR_COLORS.get(c, c))
		assert_eq(out.get_pixel(x, 0).a, c.a)
	for x in 4:
		assert_gt(out.get_pixel(x, 0).r, out.get_pixel(x + 1, 0).r)

func test_counter_preserves_red_and_limits_application_to_centers() -> void:
	assert_true(Palette.applies("res://assets/maps/viridian_center"))
	assert_true(Palette.applies("res://assets/maps/pewter_center"))
	assert_false(Palette.applies("res://assets/maps/oaks_lab"))
	var source := Image.create(3, 1, false, Image.FORMAT_RGBA8)
	source.set_pixel(0, 0, Color8(255, 131, 115))
	source.set_pixel(1, 0, Color.WHITE)
	var out := Palette.counter(source, true)
	assert_eq(out.get_pixel(0, 0), source.get_pixel(0, 0))
	assert_lt(out.get_pixel(1, 0).r, source.get_pixel(1, 0).r)
