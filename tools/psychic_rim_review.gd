extends "res://tools/skill_identity_review.gd"

const GLASS = preload("res://tools/samples/skill_glass_lens.gdshader")

func study_moves() -> Dictionary:
	return {"psychic": "confusion"}

func study_destination() -> String:
	return "res://docs/psychic_rim_review/native-r%d/" % preview_round

func study_save_path() -> String:
	return "user://save_psychic_rim_review.cfg"

func draw_reference(view: View3D, world: World, kind: String, cast: Sprite3D, age: float) -> void:
	draw_variant("existing", view, world, kind, cast, age)

func draw_variant(variant: String, view: View3D, world: World, kind: String, cast: Sprite3D, age: float) -> int:
	if lens_material == null:
		lens_material = ShaderMaterial.new()
		lens_material.shader = GLASS
		lens_material.set_shader_parameter("rim_tint", 0.70 if variant == "sample" else 0.0)
		view.rect.material = lens_material
	return super.draw_variant(variant, view, world, kind, cast, age)
