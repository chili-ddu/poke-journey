extends GutTest
const Edges = preload("res://tools/samples/sprite_edges.gd")

func test_scale2x_preserves_colors_and_only_rounds_matching_neighbors() -> void:
	var image := Image.create(3,3,false,Image.FORMAT_RGBA8)
	image.set_pixel(1,0,Color.RED)
	image.set_pixel(0,1,Color.RED)
	image.set_pixel(1,1,Color.BLUE)
	var result := Edges.process(image)
	assert_eq(result.get_size(),Vector2i(6,6))
	assert_eq(result.get_pixel(2,2),Color.RED,"Matching upper/left neighbors round this corner")
	assert_eq(result.get_pixel(3,2),Color.BLUE)
	assert_eq(result.get_pixel(3,3),Color(0,0,0,0))
	for y in 6:
		for x in 6:
			assert_true(result.get_pixel(x,y) in [Color(0,0,0,0),Color.RED,Color.BLUE])
	assert_eq(image.get_size(),Vector2i(3,3))
	assert_eq(image.get_pixel(1,1),Color.BLUE)

func test_expansion_keeps_logical_geometry_and_reuses_cached_frame() -> void:
	for dex in [1,4,7,25]:
		for action in ["Walk","Idle","Strike","Hop","Hurt"]:
			var set := MonSprite.load_set(dex)
			if not set.has(action): continue
			var anim: Dictionary=set[action]
			for row in int(anim.rows):
				var visual := MonSprite.display_frame(anim,row,0.07)
				var result := Edges.frame(visual)
				assert_eq(result.tex.get_size(),visual.src.size)
				assert_eq(result.tex.get_image().get_size(),Vector2i(visual.src.size)*2)
				assert_eq(result.src.size,visual.src.size)
				assert_eq(result.body_center,visual.body_center)
				assert_same(Edges.frame(visual).tex,result.tex)
