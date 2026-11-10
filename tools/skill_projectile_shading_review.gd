extends "res://tools/skill_identity_review.gd"

const SHADED=preload("res://tools/samples/skill_projectile_shading.gdshader")
const GLASS=preload("res://tools/samples/skill_glass_lens.gdshader")
var shading_frames:=0

func study_destination() -> String:return "res://docs/skill_projectile_shading_review/native-r%d/"%preview_round
func study_save_path() -> String:return "user://save_skill_projectile_shading_review.cfg"
func study_reset(variant: String) -> void:
	super.study_reset(variant);shading_frames=0
func study_metrics() -> Dictionary:
	var result:=super.study_metrics()
	result.reference="previous_identity_sample";result.shading_frames=shading_frames
	return result
func draw_reference(view: View3D,world: World,kind: String,cast: Sprite3D,age: float) -> void:
	super.draw_variant("sample",view,world,kind,cast,age)

func swap_shader(material: ShaderMaterial,shader: Shader,keys: Array) -> void:
	if material.shader==shader:return
	var saved:={}
	for key in keys:
		var value=material.get_shader_parameter(key)
		if value!=null:saved[key]=value
	material.shader=shader
	for key in saved:material.set_shader_parameter(key,saved[key])

func draw_variant(variant: String,view: View3D,world: World,kind: String,cast: Sprite3D,age: float) -> int:
	var count:=super.draw_variant(variant,view,world,kind,cast,age)
	if kind=="psychic":
		swap_shader(lens_material,GLASS,["fracture_count","fractures","viewport_pixels","lens_count","lenses","lens_strength"])
		assert(lens_material.shader==GLASS)
	else:
		for p: Projectile in world.projectiles:
			if p.dead or not identity_materials.has(p.get_instance_id()):continue
			var material: ShaderMaterial=identity_materials[p.get_instance_id()]
			swap_shader(material,SHADED,["flow","age","phase","family","strength","shape_aspect"])
			assert(material.shader==SHADED)
	shading_frames+=count
	return count
