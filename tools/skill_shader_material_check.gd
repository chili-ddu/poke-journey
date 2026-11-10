extends SceneTree

const FLOW_SHADER=preload("res://tools/samples/skill_flow_material.gdshader")

func _init() -> void:call_deferred("run")
func run() -> void:
	await CaptureWindow.park(self)
	var scene:=Node3D.new();root.add_child(scene)
	var camera:=Camera3D.new();scene.add_child(camera)
	camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=5.0
	camera.position=Vector3(0,4,5);camera.look_at(Vector3.ZERO);camera.current=true
	for i in 2:
		var sprite:=Sprite3D.new();scene.add_child(sprite)
		sprite.texture=Fx.sheet("g4_glow");sprite.pixel_size=.04
		sprite.shaded=false;sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		sprite.alpha_cut=SpriteBase3D.ALPHA_CUT_DISABLED
		sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.position=Vector3(-1.5 if i==0 else 1.5,0,0)
		sprite.modulate=Color(.4,.7,.9,1)
		if i==1:
			var material:=ShaderMaterial.new();material.shader=FLOW_SHADER
			material.set_shader_parameter("effect_tex",sprite.texture)
			material.set_shader_parameter("tint",sprite.modulate)
			material.set_shader_parameter("strength",0.0)
			sprite.material_override=material
	for i in 4:await process_frame
	await RenderingServer.frame_post_draw
	assert(DisplayServer.window_get_size()==Vector2i(384,216))
	var suffix:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--tag="):suffix=arg.trim_prefix("--tag=")
	root.get_texture().get_image().save_png("res://docs/skill_shader_review/material-zero"+suffix+".png")
	quit()
