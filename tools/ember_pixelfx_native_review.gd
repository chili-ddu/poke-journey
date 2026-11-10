extends "res://tools/charmander_skill_review.gd"

const DEST := "res://docs/ember_pixelfx_review/native/"
var flight_frames: Array[Texture2D]=[]
var coat_frames: Array[Texture2D]=[]

func frames(kind: String) -> Array[Texture2D]:
	var id := "ember-study-r3-b-"+kind
	var folder := "res://docs/ember_pixelfx_review/round3/local-review/"+id+"/"
	var metadata: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(folder+id+".json"))
	var image := Image.load_from_file(folder+id+".png")
	var out: Array[Texture2D]=[]
	for entry in metadata.frames:
		var r: Dictionary=entry.frame
		out.append(ImageTexture.create_from_image(image.get_region(Rect2i(int(r.x),int(r.y),int(r.w),int(r.h)))))
	return out

func apply_preview(world: World,view: View3D) -> Dictionary:
	var counts := {"flight":0,"coat":0,"ground":0}
	for projectile in world.projectiles:
		if projectile.dead or projectile.style!="ember_c" or not view._sprites.has(projectile.get_instance_id()):continue
		var ent: Dictionary=view._sprites[projectile.get_instance_id()]
		if not ent.has("sprite"):continue
		var sprite: Sprite3D=ent.sprite
		var frame := int(fposmod(projectile.age+projectile.flame_phase*0.05,1.2)*30.0)%flight_frames.size()
		sprite.texture=flight_frames[frame];sprite.region_enabled=false
		sprite.material_override=null;sprite.modulate=Color.WHITE
		var v: Vector3=view.to3d(projectile.position+projectile.vel.normalized(),0)-view.to3d(projectile.position,0)
		var angle := atan2(v.dot(view.cam.global_basis.y),v.dot(view.cam.global_basis.x))
		# The new horizontal mask occupies less of its canvas than the old
		# vertical flame. Restore visible thickness without changing hit_radius.
		sprite.basis=view.cam.global_basis*Basis(Vector3.BACK,angle)*Basis.from_scale(Vector3(projectile.flame_aspect.x,projectile.flame_aspect.y*2.0,1))
		assert(not sprite.no_depth_test)
		counts.flight+=1
	for fx in world.fxs:
		if fx.dead or fx.age<fx.delay or fx.text!="g4_flame" or not (fx.ember_coat or fx.grounded_flame):continue
		if not view._sprites.has(fx.get_instance_id()):continue
		var ent: Dictionary=view._sprites[fx.get_instance_id()]
		if not ent.has("sprite"):continue
		var sprite: Sprite3D=ent.sprite
		var frame := int(fposmod(fx.age-fx.delay+fx.ember_phase*0.05,1.2)*30.0)%coat_frames.size()
		sprite.texture=coat_frames[frame];sprite.region_enabled=false
		sprite.material_override=null;sprite.modulate=Color(1,1,1,sprite.modulate.a)
		sprite.pixel_size*=1.25 if fx.ember_coat else 1.10
		assert(not sprite.no_depth_test)
		if fx.ember_coat:counts.coat+=1
		else:counts.ground+=1
	return counts

func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	OS.set_environment("STARTER","charmander");OS.set_environment("DUNGEON","kanto_south")
	SaveData.path="user://save_ember_pixelfx_native_review.cfg"
	flight_frames=frames("flight");coat_frames=frames("coat")
	var report := []
	for distance in [48.0,72.0]:
		var matched_damage := -1
		for variant in ["current","pixelfx"]:
			var game=load("res://scenes/main.tscn").instantiate()
			root.add_child(game);current_scene=game
			game.set_process(false);game.view3d.set_process(false)
			game.stream.clear();game.banner_t=0;game.ui_root.visible=false
			var world: World=game.world
			world.player.position=Arena.tile_center(Vector2i(23,209))
			world.player.add_learned("ember");world.player.equip(0,"ember")
			world.no_skills=false;world.player.repel_steps=100000
			var target := Enemy.new()
			target.setup_enemy("chansey",25,world.rng)
			target.position=world.player.position+Vector2.RIGHT*distance
			target.frozen=true
			for move in target.cds:target.cds[move]=99999.0
			world.add_child(target);world.enemies.append(target)
			var input := ReviewInput.new()
			input.target=target;world.player.controller=input
			game.view3d._cam_ready=false
			for i in 12:
				world.step_visual(1.0/60.0);game.view3d._process(1.0/60.0)
				await process_frame
			var output: String=DEST+str(int(distance))+"/"+variant+"/"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
			var seen_flight := false
			var seen_coat := false
			var seen_attack := false
			var hp := target.hp
			for frame in 54:
				if frame==4:input.requested=true
				world.step(1.0/30.0);game.view3d._process(1.0/30.0)
				seen_attack=seen_attack or world.player.attack_anim_t>0.0
				if variant=="pixelfx":
					var seen := apply_preview(world,game.view3d)
					seen_flight=seen_flight or seen.flight>0
					seen_coat=seen_coat or seen.coat>0
				await process_frame
				await RenderingServer.frame_post_draw
				assert(DisplayServer.window_get_size()==Vector2i(384,216))
				root.get_texture().get_image().save_png(output+"%03d.png"%frame)
			var damage: int=hp-target.hp
			assert(seen_attack and damage>0)
			if variant=="current":matched_damage=damage
			else:assert(damage==matched_damage and seen_flight and seen_coat)
			report.append({"distance":distance,"variant":variant,"damage":damage,"max_hp":target.max_hp,
				"source_attack":seen_attack,"window":[384,216],"depth_test":true,"production_changes":false})
			print("EMBER PIXELFX ",distance," ",variant," damage ",damage," HP ",target.hp,"/",target.max_hp)
			game.free();current_scene=null;await process_frame
	FileAccess.open(DEST+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
