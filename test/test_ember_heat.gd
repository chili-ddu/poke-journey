extends GutTest
const Heat = preload("res://scripts/view/ember_heat.gd")

func test_heat_updates_reuse_material_and_keep_source_geometry() -> void:
	var sprite := Sprite3D.new()
	sprite.texture=Fx.sheet("g4_flame")
	sprite.position=Vector3(1,2,3)
	sprite.modulate=Color(1,0.55,0.15,0.7)
	sprite.no_depth_test=false
	var source := sprite.texture
	Heat.apply(sprite,0.1,0.4,1.0)
	var material := sprite.material_override as ShaderMaterial
	Heat.apply(sprite,0.2,0.6,0.5)
	assert_same(sprite.material_override,material,"Per-frame heat does not allocate another material")
	assert_same(sprite.texture,source)
	assert_eq(sprite.position,Vector3(1,2,3))
	assert_false(sprite.no_depth_test)
	assert_eq(material.get_shader_parameter("flame_tex"),source)
	assert_eq(material.get_shader_parameter("tint"),sprite.modulate)
	assert_eq(material.get_shader_parameter("age"),0.2)
	sprite.free()
