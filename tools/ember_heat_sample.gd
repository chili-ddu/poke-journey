extends "res://tools/charmander_skill_review.gd"

const HEAT = preload("res://tools/shaders/ember_heat_sample.gdshader")
const DEST := "res://docs/ember_heat_sample/"

func heat_sprite(sprite: Sprite3D, age: float, phase: float, heat: float) -> void:
	var material := sprite.material_override as ShaderMaterial
	if material==null:
		material=ShaderMaterial.new()
		material.shader=HEAT
		sprite.material_override=material
	material.set_shader_parameter("flame_tex",sprite.texture)
	material.set_shader_parameter("tint",sprite.modulate)
	material.set_shader_parameter("age",age)
	material.set_shader_parameter("phase",phase)
	material.set_shader_parameter("heat",heat)
	assert(not sprite.no_depth_test)

func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	OS.set_environment("STARTER","charmander");OS.set_environment("DUNGEON","kanto_south")
	SaveData.path="user://save_ember_heat_sample.cfg"
	var results := []
	for distance in [48.0,72.0]:
		for variant in ["current","heat"]:
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
			for move in target.cds: target.cds[move]=99999.0
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
			var hp := target.hp
			for frame in 54:
				if frame==4: input.requested=true
				world.step(1.0/30.0)
				game.view3d._process(1.0/30.0)
				for projectile in world.projectiles:
					if projectile.dead or projectile.style!="ember_c": continue
					seen_flight=true
					if variant=="heat" and game.view3d._sprites.has(projectile.get_instance_id()):
						var sprite: Sprite3D=game.view3d._sprites[projectile.get_instance_id()].sprite
						heat_sprite(sprite,projectile.age,projectile.flame_phase,1.0)
				for fx in world.fxs:
					if fx.dead or fx.age<fx.delay or fx.text!="g4_flame": continue
					if fx.ember_coat: seen_coat=true
					if variant=="heat" and game.view3d._sprites.has(fx.get_instance_id()):
						var sprite: Sprite3D=game.view3d._sprites[fx.get_instance_id()].sprite
						var t := clampf((fx.age-fx.delay)/maxf(0.001,fx.lifetime-fx.delay),0.0,1.0)
						heat_sprite(sprite,fx.age-fx.delay,fx.ember_phase,1.0-t*0.85)
				await process_frame
				await RenderingServer.frame_post_draw
				assert(DisplayServer.window_get_size()==Vector2i(384,216))
				root.get_texture().get_image().save_png(output+"%03d.png"%frame)
			assert(seen_flight and seen_coat and target.hp<hp)
			results.append({"distance":distance,"variant":variant,"hp_before":hp,"hp_after":target.hp,
				"native_depth":true,"source":"g4_flame","input":"controller -> cast -> play_attack"})
			print("EMBER HEAT SAMPLE ",distance," ",variant," HP ",target.hp,"/",target.max_hp)
			game.free();current_scene=null;await process_frame
	FileAccess.open(DEST+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(results,"  "))
	quit()
