extends "res://tools/skill_shader_review.gd"

const IDENTITY=preload("res://tools/samples/skill_identity_material.gdshader")
const LENS=preload("res://tools/samples/psychic_lens.gdshader")
var identity_materials: Dictionary={}
var identity_frames:=0
var lens_frames:=0
var lens_material: ShaderMaterial

func study_moves() -> Dictionary:return {"electric":"thunder_shock","wind":"gust","psychic":"confusion"}
func study_destination() -> String:return "res://docs/skill_identity_review/native-r%d/"%preview_round
func study_save_path() -> String:return "user://save_skill_identity_review.cfg"
func study_reset(variant: String) -> void:
	super.study_reset(variant)
	identity_materials={};identity_frames=0;lens_frames=0;lens_material=null
func study_metrics() -> Dictionary:
	if lens_material!=null:assert(int(lens_material.get_shader_parameter("lens_count"))==0,"No psychic lens after the shot ends")
	return {"initial_facing_correct":initial_facing_correct,"distance_px":casting_distance,"round":preview_round,"identity_frames":identity_frames,"lens_frames":lens_frames,"prior_shader_frames":shader_frames,"reference":"previous_shader_sample"}
func draw_reference(view: View3D,world: World,kind: String,cast: Sprite3D,age: float) -> void:
	var round_before:=preview_round
	preview_round=4
	super.draw_variant("sample",view,world,kind,cast,age)
	preview_round=round_before

func draw_variant(_variant: String,view: View3D,world: World,kind: String,cast: Sprite3D,_age: float) -> int:
	cast.visible=false
	var count:=0
	var lenses:=PackedVector4Array()
	for p: Projectile in world.projectiles:
		if p.dead or not view._sprites.has(p.get_instance_id()):continue
		var ent: Dictionary=view._sprites[p.get_instance_id()]
		var sprite: Sprite3D=ent.sprite
		if kind=="psychic":
			var center:=view.cam.unproject_position(sprite.position)
			lenses.append(Vector4(center.x/view.vp.size.x,center.y/view.vp.size.y,14.0,p.age))
			sprite.visible=false
			if ent.has("light"):ent.light.visible=false
			lens_frames+=1
		else:
			var id:=p.get_instance_id()
			if not identity_materials.has(id):
				var m:=ShaderMaterial.new();m.shader=IDENTITY;identity_materials[id]=m
			var material: ShaderMaterial=identity_materials[id]
			var flow3:=view.to3d(p.position+p.vel.normalized(),0)-view.to3d(p.position,0)
			var direction:=Vector2(flow3.dot(view.cam.global_basis.x),-flow3.dot(view.cam.global_basis.y)).normalized()
			material.set_shader_parameter("flow",direction)
			material.set_shader_parameter("age",p.age)
			material.set_shader_parameter("phase",p.launch_position.x*.073+p.launch_position.y*.041)
			material.set_shader_parameter("family",0 if kind=="electric" else 2)
			material.set_shader_parameter("shape_aspect",Vector2.ONE if kind=="electric" else Vector2(1,1.35))
			sprite.material_override=material
			sprite.pixel_size*=2.6 if kind=="electric" else 2.8
			if kind=="wind":sprite.position+=view.cam.global_basis.y*sprite.pixel_size*sprite.texture.get_height()*.30
			if ent.has("light"):
				if not light_defaults.has(id):light_defaults[id]=ent.light.light_energy
				ent.light.light_energy=float(light_defaults[id])*(.14 if kind=="electric" else .10)
				ent.light.omni_range=minf(ent.light.omni_range,1.2)
			assert(not sprite.no_depth_test and sprite.alpha_cut==SpriteBase3D.ALPHA_CUT_DISABLED)
			identity_frames+=1
		count+=1
	if kind=="psychic":
		if lens_material==null:
			lens_material=ShaderMaterial.new();lens_material.shader=LENS;view.rect.material=lens_material
		var size:=mini(lenses.size(),4)
		lenses.resize(4)
		lens_material.set_shader_parameter("lens_count",size)
		lens_material.set_shader_parameter("lenses",lenses)
		lens_material.set_shader_parameter("viewport_pixels",Vector2(view.vp.size))
	return count
