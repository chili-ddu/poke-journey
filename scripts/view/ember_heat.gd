extends RefCounted

const SHADER = preload("res://assets/shaders/ember_heat.gdshader")

static func apply(sprite: Sprite3D, age: float, phase: float, heat: float) -> void:
	var material := sprite.material_override as ShaderMaterial
	if material==null or material.shader!=SHADER:
		material=ShaderMaterial.new()
		material.shader=SHADER
		sprite.material_override=material
	material.set_shader_parameter("flame_tex",sprite.texture)
	material.set_shader_parameter("tint",sprite.modulate)
	material.set_shader_parameter("age",age)
	material.set_shader_parameter("phase",phase)
	material.set_shader_parameter("heat",heat)
