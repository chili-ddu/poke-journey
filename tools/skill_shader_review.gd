extends "res://tools/skill_delivery_study_review.gd"

const FLOW_SHADER = preload("res://tools/samples/skill_flow_material.gdshader")
const FAMILIES := {"electric":0,"leaf":1,"wind":2,"psychic":3}
var materials := {}
var shader_frames := 0
var initial_facing_correct := false
var casting_distance := 48.0

func study_moves() -> Dictionary:
	return {"electric":"thunder_shock","leaf":"razor_leaf","wind":"gust","psychic":"confusion"}
func study_variants() -> Array: return ["existing","sample"]
func study_destination() -> String: return "res://docs/skill_shader_review/native-r%d/"%preview_round
func study_save_path() -> String: return "user://save_skill_shader_review.cfg"
func study_frame_count() -> int: return 36 if preview_round<3 else 60
func study_distance(_kind: String="") -> float: return 48.0
func load_study(_kind: String,_stage: String) -> Array[Texture2D]: return []
func study_prepare(world: World,target: Mon,direction: Vector2) -> void:
	world.player.facing=direction
	target.facing=-direction
	casting_distance=world.player.position.distance_to(target.position)
	initial_facing_correct=world.player.facing==direction
	assert(initial_facing_correct)
func study_reset(_variant: String) -> void:
	materials={};shader_frames=0
func study_metrics() -> Dictionary:
	return {"shader_frames":shader_frames,"projectile_materials":materials.size(),"original_texture_tint_alpha":true,"initial_facing_correct":initial_facing_correct,"distance_px":casting_distance,"round":preview_round}
func snapshot(world: World,target: Mon) -> Array:
	var result:=super.snapshot(world,target)
	result.append([world.player.facing.x,world.player.facing.y,target.facing.x,target.facing.y])
	return result

func draw_variant(_variant: String,view: View3D,world: World,kind: String,cast: Sprite3D,_age: float) -> int:
	cast.visible=false
	var count:=0
	for p: Projectile in world.projectiles:
		if p.dead or not view._sprites.has(p.get_instance_id()):continue
		var ent: Dictionary=view._sprites[p.get_instance_id()]
		var sprite: Sprite3D=ent.sprite
		var original_texture:=sprite.texture
		var original_tint:=sprite.modulate
		var original_transform:=sprite.transform
		var light_energy: float=ent.light.light_energy if ent.has("light") else -1.0
		var id:=p.get_instance_id()
		if not materials.has(id):
			var material:=ShaderMaterial.new()
			material.shader=FLOW_SHADER
			materials[id]=material
		var material: ShaderMaterial=materials[id]
		material.set_shader_parameter("effect_tex",original_texture)
		material.set_shader_parameter("tint",original_tint)
		material.set_shader_parameter("age",p.age)
		material.set_shader_parameter("phase",p.launch_position.x*.073+p.launch_position.y*.041)
		material.set_shader_parameter("family",FAMILIES[kind])
		var strength: float={"electric":1.1,"leaf":0.9,"wind":1.0,"psychic":0.85}[kind] if preview_round>=3 else 1.0
		material.set_shader_parameter("strength",strength)
		var flow3:=view.to3d(p.position+p.vel.normalized(),0)-view.to3d(p.position,0)
		var direction:=Vector2(flow3.dot(view.cam.global_basis.x),-flow3.dot(view.cam.global_basis.y)).normalized()
		material.set_shader_parameter("flow",direction)
		sprite.material_override=material
		assert(sprite.texture==original_texture and sprite.modulate==original_tint and sprite.transform==original_transform)
		assert(sprite.alpha_cut==SpriteBase3D.ALPHA_CUT_DISABLED and not sprite.no_depth_test)
		assert(material.get_shader_parameter("effect_tex")==original_texture and material.get_shader_parameter("tint")==original_tint)
		assert(not ent.has("light") or is_equal_approx(ent.light.light_energy,light_energy))
		shader_frames+=1;count+=1
	return count
