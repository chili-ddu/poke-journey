extends SceneTree

# 독립 3D 차폐 검증. 앞의 불투명 벽은 엄니를 가리고 뒤의 벽은 가리지 않아야 한다.
# godot --path . -s tools/fang_occlusion_review.gd -- <출력디렉터리>
var view: View3D
var out: String

func _init() -> void:
	out = OS.get_cmdline_user_args()[0]
	await CaptureWindow.park(self)
	view = View3D.new()
	root.add_child(view)
	view.root3d = Node3D.new()
	view.add_child(view.root3d)
	view.cam = Camera3D.new()
	view.root3d.add_child(view.cam)
	view.cam.position = Vector3(0,0,8)
	view.cam.current = true
	var fx := Fx.new()
	fx.kind = "fang_directional"
	fx.size = 54
	fx.lifetime = 0.8
	fx.age = 0.2
	fx.fang_row = 2
	view.add_child(fx)
	fx.visible = false # 2D 경로는 이 3D 비교에서 제외
	var wall := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(8,8,0.2)
	wall.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.12,0.2,0.28)
	wall.material_override = material
	view.root3d.add_child(wall)
	var captures := {}
	for state in ["front_base","front_fixed","front_old","behind_base","behind_fixed"]:
		view._sync_fx_fang(fx,{})
		wall.position.z = 2.0 if state.begins_with("front") else -2.0
		var ent: Dictionary = view._sprites[fx.get_instance_id()]
		for jaw in 2:
			var sprite: Sprite3D = ent["jaw%d"%jaw]
			sprite.visible = not state.ends_with("base")
			sprite.no_depth_test = state.ends_with("old")
		for i in 5: await process_frame
		var capture := root.get_texture().get_image()
		capture.save_png(out+"/"+state+".png")
		captures[state] = capture.get_data()
	assert(captures["front_base"] == captures["front_fixed"],"Front wall fully hides jaws")
	assert(captures["front_base"] != captures["front_old"],"Old depth bypass reproduces bleed-through")
	assert(captures["behind_base"] != captures["behind_fixed"],"Jaws remain visible in front of wall")
	print("fang occlusion capture OK: 3 rendered image assertions passed")
	quit()
