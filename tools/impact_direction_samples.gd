extends SceneTree

# Art-direction study only. All new particles/streams live in this review.
const OUT := "res://docs/impact_direction_samples/"
const Still = preload("res://tools/charmander_skill_review.gd").Still
const OldSparkFan = preload("res://tools/ember_spark_samples.gd").SparkFan

class LooseSparks:
	extends OldSparkFan
	func burst(at: Vector2, _strength: int) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 827
		for i in 17:
			var angle := rng.randf_range(-PI, PI)
			var speed := rng.randf_range(55, 205)
			var life := rng.randf_range(0.12, 0.38)
			particles.append({"position":at+Vector2(rng.randf_range(-3,3),rng.randf_range(-3,3)),
				"velocity":Vector2.from_angle(angle)*speed+Vector2(0,-20), "age":0.0,
				"life":life, "floor":at.y+24, "large":i in [0,5,11], "tail":rng.randi_range(2,8)})
		emitted += 17
		queue_redraw()

class FireCoat:
	extends Node2D
	var sheets := {}
	var mouth := Vector2.ZERO
	var target := Vector2.ZERO
	var feet := Vector2.ZERO
	var time := -1.0
	var impact_time := -1.0
	func _init() -> void:
		for name in ["fire-breath", "spirit-flame"]:
			var path: String = OUT + "source/fire/" + name + "/" + name
			var meta: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path+".json")).meta.pixelfx
			sheets[name] = {"texture":ImageTexture.create_from_image(Image.load_from_file(path+".png")),"meta":meta}
	func draw_frame(name: String, clock: float, at: Vector2, scaling: Vector2, angle: float, alpha: float, reveal: float = 1.0) -> void:
		var sheet: Dictionary = sheets[name]
		var meta: Dictionary = sheet.meta
		var index := int(maxf(0,clock)*float(meta.fps)) % int(meta.frames)
		var size := Vector2(meta.frameSize[0],meta.frameSize[1])
		var pivot := Vector2(meta.pivot[0],meta.pivot[1])
		var origin := Vector2(index % int(meta.columns),index / int(meta.columns))*size
		size.x *= reveal
		draw_set_transform(at,angle,scaling)
		draw_texture_rect_region(sheet.texture,Rect2(-pivot,size),Rect2(origin,size),Color(1,1,1,alpha))
		draw_set_transform(Vector2.ZERO)
	func _draw() -> void:
		if time < 0.0: return
		# Continuous flow starts at the mouth, widening toward the victim.
		if time < 0.55:
			var axis := target-mouth
			var scale := axis.length()/124.0
			var reveal := lerpf(0.10,1.0,smoothstep(0.0,0.11,time))
			var fade := 1.0-smoothstep(0.42,0.55,time)
			draw_frame("fire-breath",time,mouth,Vector2(scale,scale*1.35),axis.angle(),fade,reveal)
		if impact_time < 0.0 or impact_time > 0.8: return
		var envelope := smoothstep(0.0,0.08,impact_time)*(1.0-smoothstep(0.45,0.8,impact_time))
		# Three differently phased tongues surround the silhouette. The front
		# tongue stays translucent so the victim remains readable inside the fire.
		for lane in 3:
			var offset: Vector2 = [Vector2(-8,2),Vector2(8,0),Vector2(0,4)][lane]
			var alpha := (0.85 if lane < 2 else 0.45)*envelope
			var scale := Vector2(0.95 if lane<2 else 1.05,0.75 if lane<2 else 0.62)
			var tilt: float = [-0.25,0.18,-0.08][lane]
			draw_frame("spirit-flame",impact_time*1.8+float(lane)*0.71,feet+offset,scale,tilt,alpha)

func _init() -> void: call_deferred("run")

func projected_center(view: View3D, mon: Mon) -> Vector2:
	var body: Sprite3D = view._sprites[mon.get_instance_id()].sprite
	return view.cam.unproject_position(body.position+Vector3.UP*body.offset.y*body.pixel_size*body.scale.y)

func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","7")
	OS.set_environment("STARTER","charmander")
	OS.set_environment("DUNGEON","kanto_south")
	SaveData.path="user://save_impact_direction_samples.cfg"
	for variant in 2:
		seed(7)
		var game=load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		current_scene=game
		game.set_process(false)
		game.banner_t=0.0
		game.stream.clear()
		game.hud.visible=false
		var world: World=game.world
		world.player.controller=Still.new()
		world.player.position=Arena.tile_center(Vector2i(23,209))
		world.player.facing=Vector2.RIGHT
		var enemy:=Enemy.new()
		enemy.setup_enemy("chansey",25,world.rng)
		enemy.position=world.player.position+Vector2.RIGHT*(28 if variant==0 else 48)
		enemy.facing=Vector2.LEFT
		enemy.frozen=true
		world.add_child(enemy)
		world.enemies.append(enemy)
		var overlay:=CanvasLayer.new()
		overlay.layer=100
		root.add_child(overlay)
		var sparks:=LooseSparks.new()
		var fire:=FireCoat.new()
		overlay.add_child(sparks)
		overlay.add_child(fire)
		var title:=Label.new()
		title.text="PHYSICAL / LOOSE SPARKS" if variant==0 else "SPECIAL / FIRE BREATH + ENVELOP"
		title.position=Vector2(8,8)
		title.add_theme_font_size_override("font_size",11)
		title.add_theme_color_override("font_shadow_color",Color.BLACK)
		title.add_theme_constant_override("shadow_offset_x",1)
		title.add_theme_constant_override("shadow_offset_y",1)
		overlay.add_child(title)
		for i in 12:
			world.step_visual(1.0/60)
			await process_frame
		var impact_at:=-1.0
		var cast_at:=0.2
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT+str(variant)))
		for frame in 60:
			var clock:=float(frame)/30.0
			if frame==6: world.cast(world.player,"scratch" if variant==0 else "ember",Vector2.RIGHT,enemy.position)
			world.step(1.0/30)
			sparks.step(1.0/30)
			await process_frame
			var view: View3D=game.view3d
			for effect in world.fxs:
				var hit: bool=effect.claw_downstroke if variant==0 else effect.text=="pixelfx_ember"
				if hit and impact_at<0:
					impact_at=clock
					if variant==0: sparks.burst(projected_center(view,enemy),1)
				if variant==1 and effect.kind!="text":
					effect.visibility_layer=0
					if view._sprites.has(effect.get_instance_id()) and view._sprites[effect.get_instance_id()].has("sprite"):
						(view._sprites[effect.get_instance_id()].sprite as Sprite3D).layers=0
			if variant==1:
				for projectile in world.projectiles:
					if view._sprites.has(projectile.get_instance_id()):
						(view._sprites[projectile.get_instance_id()].sprite as Sprite3D).layers=0
				fire.mouth=projected_center(view,world.player)+Vector2(8,-1)
				fire.target=projected_center(view,enemy)
				fire.feet=view.cam.unproject_position(view.to3d(enemy.position))
				fire.time=clock-cast_at
				fire.impact_time=clock-impact_at if impact_at>=0 else -1
				fire.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUT+str(variant)+"/%03d.png"%frame)
		assert(impact_at>=0)
		assert(DisplayServer.window_get_size()==Vector2i(384,216))
		assert(sparks.particles.is_empty())
		print(title.text,"; contact ",impact_at,"; sparks ",sparks.emitted,"; HP ",enemy.hp,"/",enemy.max_hp)
		overlay.free()
		game.free()
		current_scene=null
		await process_frame
	quit()
