extends GutTest

const Palette = preload("res://scripts/view/map_palette.gd")

func test_map_palette_preserves_pixel_layout_alpha_and_source() -> void:
	var image := Image.create(4,1,false,Image.FORMAT_RGBA8)
	for x in 4: image.set_pixel(x,0,Color(0.2,0.8,0.3,float(x)/3.0))
	var before := image.get_data()
	var result := Palette.surface(image)
	assert_eq(result.get_size(),image.get_size())
	assert_eq(image.get_data(),before,"Source asset stays unchanged")
	for x in 4: assert_eq(result.get_pixel(x,0).a,image.get_pixel(x,0).a)
	assert_lt(result.get_pixel(3,0).s,image.get_pixel(3,0).s,"Reduce neon greens")

func test_texture_cache_and_original_comparison_switch() -> void:
	var source := ImageTexture.create_from_image(Image.create(2,2,false,Image.FORMAT_RGBA8))
	var previous := Palette.enabled
	Palette.enabled=true
	assert_same(Palette.texture(source),Palette.texture(source))
	assert_ne(Palette.texture(source),source)
	var polished := Palette.texture(source)
	assert_same(Palette.texture(polished),polished,"Animated foliage cannot receive the palette twice")
	Palette.enabled=false
	assert_same(Palette.texture(source),source)
	Palette.enabled=previous
