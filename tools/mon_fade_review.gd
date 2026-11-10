extends "res://tools/arena_camera_review.gd"
func run() -> void:
	out="res://docs/mon_fade_review"
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("SEED","7")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	var script = load("res://scripts/game.gd")
	script.arena_trip={"trainer":"rival_green_squirtle","arena":"arena_route1","back":{"map":"kanto_south"}}
	OS.set_environment("DUNGEON","arena_route1")
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	game.set_process(false)
	game.view3d.set_process(false)
	var guard := 0
	while (game.battle.mon==null or not game.sendout.is_empty() or game.state!="fight") and guard<600:
		await frame()
		guard+=1
	assert(guard<600,"Battle reaches active combat")
	game.bot=false
	game.banner_t=0.0
	for i in 20: await frame(false)
	var material: ShaderMaterial=game.look_rect.material
	assert(int(material.get_shader_parameter("combat_focus_count"))>=2,"Both Pokemon get a sharp-focus mask")
	await shot("01_distant_foe_sharp")
	var foe: Enemy=game.battle.mon
	foe.position=game.world.player.position+Vector2.UP*3.0*Arena.TILE
	for i in 30: await frame(false)
	game.world._faint(foe)
	var id := foe.get_instance_id()
	var previous := 1.0
	for elapsed in [0.0,0.25,0.5,0.75,0.95,1.0]:
		while foe.faint_t>Mon.FAINT_TIME-float(elapsed)+0.0001:
			foe.tick_faint(DT)
			foe.queue_redraw()
			if foe.faint_t>0.02: game.world.step_fx(DT)
			await frame(false)
		await frame(false)
		await frame(false)
		var sprite: Sprite3D=game.view3d._sprites[id].sprite
		assert(sprite.modulate.a<=previous,"3D body fades monotonically")
		if elapsed>0.15 and elapsed<1.0:
			assert(sprite.visible and sprite.modulate.a>0.0 and sprite.modulate.a<1.0,"Intermediate fade remains visible")
			assert(sprite.alpha_cut==SpriteBase3D.ALPHA_CUT_DISABLED,"Fade uses alpha blending rather than a clipping threshold")
		assert(not game.view3d._sprites[id].twin.visible,"No solid shadow remains behind the fading body")
		previous=sprite.modulate.a
		await shot("faint_%03d"%int(float(elapsed)*100))
	assert(not game.view3d._sprites[id].sprite.visible,"Body is hidden when fade completes")
	game.world._cleanup()
	await frame(false)
	assert(not game.view3d._sprites.has(id),"Completed faint releases 3D body and focus")
	print("Pokemon focus and continuous faint fade passed")
	script.arena_trip={}
	game.free()
	quit()
