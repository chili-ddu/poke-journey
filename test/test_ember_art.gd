extends GutTest

const Art = preload("res://scripts/view/ember_art.gd")

func test_every_exported_flame_frame_is_nonempty_and_loops_cleanly() -> void:
	for i in Art.COUNT:
		var texture := Art.texture(float(i)/Art.FPS)
		assert_eq(texture.get_size(),Vector2(Art.FRAME))
		assert_true(texture.get_image().get_used_rect().has_area(),"No empty/incorrectly cropped flame frames")
	assert_same(Art.texture(0),Art.texture(3.0),"Loops reuse the same cached native pixel frame")
	assert_same(Art.texture(0),Art.texture(0,TAU))

func test_flight_and_contact_use_original_flame_artwork() -> void:
	var projectile := Projectile.new()
	projectile.style="ember_c"
	projectile.age=0.32
	projectile.flame_phase=0.7
	var flame := Fx.new()
	flame.text="g4_flame"
	flame.age=projectile.age
	flame.ember_phase=projectile.flame_phase
	assert_same(projectile.visual_flame_texture(),flame.sprite_texture())
	flame.delay=0.1
	flame.age+=0.1
	assert_same(projectile.visual_flame_texture(),flame.sprite_texture(),"Delayed contact starts its own visual clock")
	projectile.free()
	flame.free()
