extends SceneTree

func _init() -> void:
	await CaptureWindow.park(self)
	var view := View3D.new()
	root.add_child(view)
	view.root3d = Node3D.new()
	view.add_child(view.root3d)
	view.cam = Camera3D.new()
	view.root3d.add_child(view.cam)
	for style in ["flame_c","dragon_c"]:
		var p := Projectile.new()
		view.add_child(p)
		p.style = style
		p.position = Vector2(100,200)
		p.vel = Vector2(200,0)
		p.radius = 5
		p.range_full = 96
		p.range_left = 48
		p.age = 0.2
		view._sync_projectile(p,{})
		var key := "stream_batch" if style=="flame_c" else "dragon_batch"
		var node: MultiMeshInstance3D = view._sprites[p.get_instance_id()][key]
		var layers := p.stream_layers() if style=="flame_c" else p.dragon_layers().slice(0,4)
		if style=="dragon_c":
			layers.sort_custom(func(a,b): return View3D.to3d(a.offset,0).dot(view.cam.global_basis.z)<View3D.to3d(b.offset,0).dot(view.cam.global_basis.z))
		for i in layers.size():
			var layer: Dictionary = layers[i]
			var actual := node.multimesh.get_instance_color(i)
			var expected_color: Color = layer.color
			for channel in 4: assert(absf(actual[channel]-expected_color[channel])<=1.0/255.0,"Packed GPU colour tolerance")
			var extent: float = layer.get("width",layer.get("size",0.0))/Arena.TILE
			assert(absf(node.multimesh.get_instance_transform(i).basis.x.length()-extent)<0.001)
			if style=="dragon_c":
				var expected := View3D.to3d(p.position+layer.offset+Vector2(0,6),6.0/Arena.TILE*view.k)
				assert((node.position+node.multimesh.get_instance_transform(i).origin).is_equal_approx(expected))
	print("projectile batch GPU data review OK")
	quit()
