extends "res://tools/charmander_skill_review.gd"

const Heat = preload("res://scripts/view/ember_heat.gd")
const DEST := "res://docs/ember_clarity_review/"

func set_legacy_post(game: Node, indoor: bool) -> void:
	var post := game.look_rect.material as ShaderMaterial
	post.set_shader_parameter("band_top",0.12 if indoor else 0.3)
	post.set_shader_parameter("band_bottom",0.10 if indoor else 0.2)
	post.set_shader_parameter("blur_px",3.0 if indoor else 9.0)
	post.set_shader_parameter("bloom_strength",0.2 if indoor else 0.5)
	post.set_shader_parameter("bloom_px",14.0)
	post.set_shader_parameter("bloom_threshold",0.95)

func run() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1");OS.set_environment("GOD","1");OS.set_environment("SEED","7")
	OS.set_environment("STARTER","charmander")
	SaveData.path="user://save_ember_clarity_review.cfg"
	var report := []
	for fixture in [{"id":"ember","place":"kanto_south","tile":Vector2i(23,209)},
		{"id":"forest","place":"viridian_forest","tile":Vector2i(5,16)},
		{"id":"city","place":"saffron_city","tile":Vector2i(24,40)},
		{"id":"lab","place":"oaks_lab","tile":Vector2i(-1,-1)}]:
		for variant in ["legacy","crisp"]:
			OS.set_environment("DUNGEON",fixture.place)
			var game=load("res://scenes/main.tscn").instantiate()
			root.add_child(game);current_scene=game
			game.set_process(false);game.view3d.set_process(false)
			game.stream.clear();game.banner_t=0;game.ui_root.visible=false
			var world: World=game.world
			world.player.repel_steps=100000
			if fixture.tile.x>=0: world.player.position=Arena.resolve(Arena.tile_center(fixture.tile),world.player.radius)
			var input := ReviewInput.new()
			world.player.controller=input
			var target: Enemy
			if fixture.id=="ember":
				world.no_skills=false;world.player.add_learned("ember");world.player.equip(0,"ember")
				target=Enemy.new();target.setup_enemy("chansey",25,world.rng)
				target.position=world.player.position+Vector2.RIGHT*72
				target.frozen=true
				for move in target.cds: target.cds[move]=99999.0
				world.add_child(target);world.enemies.append(target);input.target=target
			if variant=="legacy": set_legacy_post(game,DungeonDB.is_indoor(fixture.place))
			game.view3d._cam_ready=false
			for i in 24:
				world.step_visual(1.0/60.0);game.view3d._process(1.0/60.0)
				await process_frame
			var output: String=DEST+fixture.id+"/"+variant+"/"
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
			var seen_heat := false
			for frame in (54 if fixture.id=="ember" else 1):
				if fixture.id=="ember":
					if frame==4: input.requested=true
					world.step(1.0/30.0)
				else: world.step_visual(1.0/30.0)
				game.view3d._process(1.0/30.0)
				for p in world.projectiles:
					if p.dead or p.style!="ember_c" or not game.view3d._sprites.has(p.get_instance_id()): continue
					var sprite: Sprite3D=game.view3d._sprites[p.get_instance_id()].sprite
					assert(sprite.material_override is ShaderMaterial)
					assert((sprite.material_override as ShaderMaterial).shader==Heat.SHADER)
					assert(not sprite.no_depth_test)
					seen_heat=true
				await process_frame
				await RenderingServer.frame_post_draw
				assert(DisplayServer.window_get_size()==Vector2i(384,216))
				root.get_texture().get_image().save_png(output+"%03d.png"%frame)
			if fixture.id=="ember": assert(seen_heat and target.hp<target.max_hp)
			report.append({"fixture":fixture.id,"variant":variant,"damage":target.max_hp-target.hp if target!=null else 0})
			print("EMBER / CLARITY ",fixture.id," ",variant)
			game.free();current_scene=null;await process_frame
	FileAccess.open(DEST+"checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	quit()
