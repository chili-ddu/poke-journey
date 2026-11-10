extends "res://tools/skill_delivery_study_review.gd"

# Preserve the actual game material, alpha masks, colours and lights. Only
# gentle directional breathing is added to the existing rendered layers.
const Heat = preload("res://scripts/view/ember_heat.gd")
var checked_fire := 0
var checked_water := 0
var preserved := {}

func study_moves() -> Dictionary: return {"fire":"ember","water":"water_gun"}
func study_variants() -> Array: return ["existing","crisp","sample"]
func study_destination() -> String: return "res://docs/skill_softness_review/native/"
func study_save_path() -> String: return "user://save_skill_softness_review.cfg"
func study_reset(_variant: String) -> void:
	checked_fire=0;checked_water=0;preserved={}
func study_metrics() -> Dictionary:
	return {"original_heat_shader_frames":checked_fire,"original_water_layer_frames":checked_water,"preserved_projectiles":preserved.size()}

func draw_variant(variant: String,view: View3D,world: World,kind: String,cast: Sprite3D,age: float) -> int:
	if variant=="crisp":return super.draw_delivery(view,world,kind,cast,age)
	cast.visible=false
	var seen:=0
	for p: Projectile in world.projectiles:
		if p.dead or not view._sprites.has(p.get_instance_id()):continue
		var ent: Dictionary=view._sprites[p.get_instance_id()]
		if kind=="fire":
			var sprite: Sprite3D=ent.sprite
			var original_texture:=sprite.texture
			var original_material:=sprite.material_override
			var tint:=sprite.modulate
			var mat:=original_material as ShaderMaterial
			assert(mat!=null and mat.shader==Heat.SHADER,"Keep the real EmberHeat material")
			var flow:=view.to3d(p.position+p.vel.normalized(),0)-view.to3d(p.position,0)
			var angle:=atan2(flow.dot(view.cam.global_basis.y),flow.dot(view.cam.global_basis.x))
			var rotation:=Basis(Vector3.BACK,angle)
			var breathe:=1.0+sin(p.age*12.0+p.flame_phase)*.025
			var warp:=rotation*Basis.from_scale(Vector3(1.28*breathe,.98,1.0))*rotation.inverse()
			sprite.basis=view.cam.global_basis*warp*view.cam.global_basis.inverse()*sprite.basis
			assert(sprite.texture==original_texture and sprite.material_override==original_material and sprite.modulate==tint)
			assert(mat.get_shader_parameter("flame_tex")==sprite.texture)
			assert(is_equal_approx(float(mat.get_shader_parameter("age")),p.age))
			assert(is_equal_approx(float(mat.get_shader_parameter("phase")),p.flame_phase))
			assert(is_equal_approx(float(mat.get_shader_parameter("heat")),1.0))
			checked_fire+=1
		elif kind=="water":
			var layers:=p.water_layers()
			for i in 3:
				var sprite: Sprite3D=ent["water_%d"%i]
				var material:=sprite.material_override
				var tint:=sprite.modulate
				var texture:=sprite.texture
				assert(texture==Fx.sheet("g4_glow") and tint==layers[i].color)
				var stretch:=1.24 if i==0 else 1.06 if i==1 else 1.13
				var breathe:=1.0+sin(p.age*10.0+float(i)*1.1)*.025
				sprite.basis=sprite.basis.scaled_local(Vector3(breathe,stretch,1))
				assert(sprite.texture==texture and sprite.material_override==material and sprite.modulate==tint)
				assert(sprite.alpha_cut==SpriteBase3D.ALPHA_CUT_DISABLED and not sprite.no_depth_test)
				checked_water+=1
		preserved[p.get_instance_id()]=true
		seen+=1
	return seen
