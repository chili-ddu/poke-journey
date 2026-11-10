extends "res://tools/skill_identity_review.gd"

const BOLT = preload("res://tools/samples/skill_projectile_shading.gdshader")

func study_moves() -> Dictionary:
	return {"electric": "thunder_shock"}

func study_destination() -> String:
	return "res://docs/thunder_shock_arc_review/native-r%d/" % preview_round

func study_save_path() -> String:
	return "user://save_thunder_shock_arc_review.cfg"

func study_metrics() -> Dictionary:
	var result := super.study_metrics()
	result.reference = "previous_shaded_projectile"
	return result

func draw_reference(view: View3D, world: World, kind: String, cast: Sprite3D, age: float) -> void:
	draw_variant("existing", view, world, kind, cast, age)

func draw_variant(variant: String, view: View3D, world: World, kind: String, cast: Sprite3D, age: float) -> int:
	for projectile: Projectile in world.projectiles:
		var id := projectile.get_instance_id()
		if projectile.dead or identity_materials.has(id):
			continue
		var material := ShaderMaterial.new()
		material.shader = BOLT
		material.set_shader_parameter("compact_bolt", variant == "sample")
		identity_materials[id] = material
	return super.draw_variant(variant, view, world, kind, cast, age)
