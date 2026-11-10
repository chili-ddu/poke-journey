extends SceneTree
# Diagnostic prototype only: production renderer remains unchanged.
var game: Node
var out := "res://docs/smoke_batch_overlap_probe"
func _init() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("DUNGEON","kanto_south")
	FxStyle.set_mode("custom")
	# Keep the individual-sprite reference even after guarded batching ships.
	var diagnostic := GDScript.new()
	diagnostic.source_code = FileAccess.get_file_as_string("res://scripts/game.gd").replace('view3d = View3D.new()', 'view3d = preload("res://tools/smoke_comparison_view.gd").new()')
	assert(diagnostic.reload()==OK)
	game = Node2D.new()
	game.set_script(diagnostic)
	root.add_child(game)
	game.set_process(false)
	await process_frame
	var w: World = game.world
	var v: View3D = game.view3d
	v.set_process(false)
	w.player.position = Arena.tile_center(Vector2i(23,209))
	var report := []
	for scenario in ["plain","fire","wall_front","wall_back"]:
		for count in [1,6]:
			var age := 0.35
			for f in w.fxs: f.free()
			w.fxs.clear()
			for i in count:
				var offset := Vector2.from_angle(i*TAU/count)*12.0 if count>1 else Vector2.ZERO
				w._smoke_cloud_custom(w.player.position+offset,48,10)
			var wall: MeshInstance3D = null
			if scenario.begins_with("wall"):
				wall = MeshInstance3D.new()
				var box := BoxMesh.new()
				box.size = Vector3(3,2,0.15)
				wall.mesh = box
				var mat := StandardMaterial3D.new()
				mat.albedo_color = Color(0.65,0.55,0.35)
				wall.material_override = mat
				v.root3d.add_child(wall)
				wall.position = View3D.to3d(w.player.position,1.0)+Vector3(0,0,2 if scenario=="wall_front" else -2)
			w.step_visual(age)
			if scenario=="fire":
				for i in 5:
					w._spawn_projectile(w.player,w.make_hit(w.player,"flamethrower"),MoveDB.get_move("flamethrower"),Vector2.RIGHT*200)
					var p: Projectile = w.projectiles.back()
					p.position = w.player.position+Vector2((i-2)*14,(i-2)*8)
					p.range_left = 48
					p.age = 0.25
			v._process(0.0)
			await settle()
			var name := "%s_%d" % [scenario,count]
			root.get_texture().get_image().save_png(out+"/"+name+"_before.png")
			var before := Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
			var sprites: Array[Sprite3D] = []
			for f in w.fxs:
				if not f.smoke_veil or f.age<f.delay or f.dead: continue
				var ent: Dictionary = v._sprites.get(f.get_instance_id(),{})
				if ent.has("sprite"): sprites.append(ent.sprite)
			assert(not sprites.is_empty())
			# Sort inside the batch, but other transparent scene objects still sort as whole nodes.
			sprites.sort_custom(func(a,b):return a.position.dot(v.cam.global_basis.z)<b.position.dot(v.cam.global_basis.z))
			var center := Vector3.ZERO
			for s in sprites: center+=s.position
			center /= sprites.size()
			var batch_entry := {}
			var batch := v._projectile_batch(batch_entry,"smoke",Fx.sheet("g4_smoke"),sprites.size())
			batch_entry.smoke.position = center
			for i in sprites.size():
				var s := sprites[i]
				var size := Vector2(s.texture.get_size())*s.pixel_size
				batch.set_instance_transform(i,Transform3D(s.basis*Basis.from_scale(Vector3(size.x,size.y,1)),s.position-center))
				batch.set_instance_color(i,s.modulate)
				s.visible = false
			await settle()
			root.get_texture().get_image().save_png(out+"/"+name+"_after.png")
			report.append({"case":name,"puffs":sprites.size(),"draw_calls_before":before,"draw_calls_after":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})
			batch_entry.smoke.free()
			for s in sprites: s.visible = true
			if wall!=null: wall.free()
			for p in w.projectiles: p.free()
			w.projectiles.clear()
	FileAccess.open(out+"/metrics.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	print(JSON.stringify(report))
	game.free()
	quit()
func settle() -> void:
	for i in 4:
		await process_frame
		await RenderingServer.frame_post_draw
