extends "res://tools/kanto_expansion_review.gd"

const DEST := "res://docs/pickup_glint_sample/"
const GLINT = preload("res://tools/shaders/pickup_glint_sample.gdshader")
const STAR = preload("res://tools/shaders/pickup_star_sample.gdshader")

func quad(shader: Shader) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size=Vector2.ONE
	node.mesh=mesh
	var material := ShaderMaterial.new()
	material.shader=shader
	node.material_override=material
	node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.view3d.root3d.add_child(node)
	return node

func run() -> void:
	await CaptureWindow.park(self)
	SaveData.path="user://save_pickup_glint_sample.cfg"
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	for variant in ["current","glint"]:
		var output: String=DEST+variant+"/"
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
		var sheen := quad(GLINT)
		var stars: Array[MeshInstance3D]=[quad(STAR),quad(STAR)]
		var arrival := quad(STAR)
		var arrival_age := -1.0
		var arrival_started := false
		var seen := false
		for frame in 48:
			if frame==22: walker.target=game.world.player.position+Vector2(12,0)
			game.world.step(1.0/30.0)
			if variant=="glint":
				for fx in game.world.fxs:
					if fx.text=="pixelfx_pickup" or (fx.text=="g4_spark" and fx.body_impact): fx.dead=true
			game.view3d._process(1.0/30.0)
			sheen.visible=false;arrival.visible=false
			for star in stars: star.visible=false
			var camera: Camera3D=game.view3d.cam
			if variant=="glint" and is_instance_valid(leader) and leader.flight>=0.0 and not leader.done:
				seen=true
				var sprite: Sprite3D=game.view3d._sprites[leader.get_instance_id()].sprite
				var progress := leader.flight/LootItem.FLY_TIME
				var material := sheen.material_override as ShaderMaterial
				material.set_shader_parameter("icon_tex",leader.texture)
				material.set_shader_parameter("progress",progress)
				material.set_shader_parameter("opacity",leader.alpha)
				var size: Vector2=leader.texture.get_size()*sprite.pixel_size
				sheen.transform=Transform3D(sprite.basis*Basis.from_scale(Vector3(size.x,size.y,1)),sprite.position+camera.global_basis.z*0.003)
				sheen.visible=true
				for i in 2:
					var pulse := maxf(0.0,1.0-absf(progress-(0.28+i*0.30))/0.15)
					var star: MeshInstance3D=stars[i]
					star.visible=pulse>0.0
					var scale := 0.25*lerpf(0.35,1.0,pulse)
					star.basis=camera.global_basis*Basis.from_scale(Vector3.ONE*scale)
					star.position=sprite.position+camera.global_basis.x*(0.18 if i==0 else -0.17)+camera.global_basis.y*(0.14 if i==0 else -0.04)+camera.global_basis.z*0.008
					(star.material_override as ShaderMaterial).set_shader_parameter("pulse",pulse*leader.alpha)
				if progress>=0.80 and not arrival_started:
					arrival_started=true;arrival_age=0.0
			if arrival_age>=0.0 and variant=="glint":
				arrival_age+=1.0/30.0
				var pulse := maxf(0.0,1.0-absf(arrival_age-0.07)/0.09)
				var body: Sprite3D=game.view3d._sprites[game.world.player.get_instance_id()].sprite
				arrival.visible=pulse>0.0
				arrival.basis=camera.global_basis*Basis.from_scale(Vector3.ONE*lerpf(0.10,0.36,pulse))
				arrival.position=body.position+Vector3.UP*body.offset.y*body.pixel_size*body.scale.y+camera.global_basis.x*0.08+camera.global_basis.z*0.04
				(arrival.material_override as ShaderMaterial).set_shader_parameter("pulse",pulse)
			await process_frame
			await RenderingServer.frame_post_draw
			assert(DisplayServer.window_get_size()==Vector2i(384,216))
			root.get_texture().get_image().save_png(output+"%03d.png"%frame)
		assert(game.world.player.bag.oran_berry==3)
		if variant=="glint": assert(seen)
		print("Pickup shader sample ",variant,": native depth, unchanged pickup and icon silhouette")
	game.free()
	quit()
