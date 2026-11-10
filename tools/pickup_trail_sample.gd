extends "res://tools/pickup_glint_sample.gd"

const TRAIL_OUT := "res://docs/pickup_trail_sample/"
const FILAMENT = preload("res://tools/shaders/pickup_trail_sample.gdshader")

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_pickup_trail_sample.cfg"
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	for variant in ["current","trail"]:
		var output: String=TRAIL_OUT+variant+"/"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
		await open_fixture("kanto_south")
		game.ui_root.visible=false
		game.view3d.set_process(false)
		game.world.player.position=Arena.tile_center(Vector2i(23,209))
		game.world.player.repel_steps=100000
		game.world.player.bag.clear();game.world.player.reward_reserve.clear()
		walker.target=game.world.player.position
		game.view3d._cam_ready=false
		for i in 12:
			game.world.step_visual(1.0/60.0)
			game.view3d._process(1.0/60.0)
			await process_frame
		var leader: LootItem
		for i in 3:
			var item: LootItem=game.world.spawn_loot("oran_berry",game.world.player.position+Vector2(-30+i*3,2))
			if i==0: leader=item
		var history: Array=[]
		var motes: Array=[]
		var segments: Array[MeshInstance3D]=[]
		for i in 10: segments.append(quad(FILAMENT))
		var emissions := 0
		for frame in 48:
			if frame==22: walker.target=game.world.player.position+Vector2(12,0)
			game.world.step(1.0/30.0)
			if variant=="trail":
				for fx in game.world.fxs:
					if fx.text=="pixelfx_pickup" or (fx.text=="g4_spark" and fx.body_impact): fx.dead=true
			game.view3d._process(1.0/30.0)
			var camera: Camera3D=game.view3d.cam
			for segment in segments: segment.visible=false
			for point in history: point.age+=1.0/30.0
			history=history.filter(func(p): return p.age<0.24)
			if variant=="trail" and is_instance_valid(leader) and leader.flight>=0.0 and not leader.done:
				var sprite: Sprite3D=game.view3d._sprites[leader.get_instance_id()].sprite
				var at := sprite.position+camera.global_basis.z*0.008
				history.append({"position":at,"age":0.0})
				if frame%2==0:
					var star := quad(STAR)
					# Born at a past point on the flight, then left there to fade.
					var offset := camera.global_basis.x*(0.045 if emissions%2==0 else -0.045)+camera.global_basis.y*0.035
					motes.append({"node":star,"position":at+offset,"age":0.0,"size":0.30 if emissions%3==0 else 0.23})
					emissions+=1
			for i in maxi(0,history.size()-1):
				var a: Vector3=history[i].position
				var b: Vector3=history[i+1].position
				var direction := b-a
				var length := direction.length()
				if length<0.005: continue
				var x := direction/length
				var z := camera.global_basis.z.normalized()
				var y := z.cross(x).normalized()
				var fade: float=pow(1.0-float(history[i].age)/0.24,1.5)
				var segment: MeshInstance3D=segments[i]
				segment.basis=Basis(x*(length+0.015),y*0.14,z)
				segment.position=(a+b)*0.5
				segment.visible=true
				(segment.material_override as ShaderMaterial).set_shader_parameter("strength",fade*0.75)
			for mote in motes:
				mote.age+=1.0/30.0
				var age: float=mote.age
				var star: MeshInstance3D=mote.node
				var pulse := clampf(age/0.035,0.0,1.0)*clampf((0.23-age)/0.18,0.0,1.0)
				var scale: float=mote.size*lerpf(0.4,1.0,pulse)
				star.basis=camera.global_basis*Basis.from_scale(Vector3.ONE*scale)
				star.position=mote.position+camera.global_basis.y*age*0.08
				star.visible=age<0.23
				(star.material_override as ShaderMaterial).set_shader_parameter("pulse",pulse)
			assert(history.size()<=9,"The trail is bounded and expires")
			await process_frame
			await RenderingServer.frame_post_draw
			assert(DisplayServer.window_get_size()==Vector2i(384,216))
			root.get_texture().get_image().save_png(output+"%03d.png"%frame)
		assert(game.world.player.bag.oran_berry==3)
		if variant=="trail":
			assert(emissions>3)
			assert(history.is_empty())
			assert(motes.all(func(m): return not m.node.visible))
		print("Pickup trail sample ",variant,": actual 3D history, fading trail, three items received")
	game.free()
	quit()
