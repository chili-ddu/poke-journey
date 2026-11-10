extends SceneTree

const DT := 1.0/60.0
const OUT := "res://docs/skill_denied_feedback/stronger/"

func _init() -> void: call_deferred("run")

func run() -> void:
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("DUNGEON","kanto_south")
	await CaptureWindow.park(self)
	DirAccess.make_dir_recursive_absolute(OUT)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	game.view3d.set_process(false)
	game.bot = false
	game.hud.visible = false
	game.stream.clear()
	game.banner_t = 0.0
	var world: World = game.world
	var p: Player = world.player
	p.setup_player("charmander",12,["scratch"])
	p.controller = Controllers.Human.new()
	p.position = Arena.tile_center(Vector2i(24,182))
	p.facing = Vector2.RIGHT
	world.aim_override = func() -> Vector2: return p.position+Vector2.RIGHT*80.0
	game.view3d._cam_ready = false
	var metrics: Array = []
	for reason in ["pp","cooldown","recover","hitstop"]:
		Input.action_release("skill_0")
		p.controller.consume_skill_presses(world)
		p.skill_denied_t = 0.0
		p.recover_t = 0.0
		p.hitstop_t = 0.0
		p.pp[0] = MoveDB.pp_of("scratch")
		p.use_t[0] = 0.0
		match reason:
			"pp": p.pp[0] = 0
			"cooldown": p.use_t[0] = 3.0
			"recover": p.recover_t = 1.0
			"hitstop": p.hitstop_t = 1.0
		for i in 4:
			p.queue_redraw()
			await process_frame
			game.view3d._process(DT)
		var origin := p.position
		var cam_anchor := p.cam_anchor()
		var sprite: Sprite3D = game.view3d._sprites[p.get_instance_id()].sprite
		var center: Vector2 = game.view3d.cam.unproject_position(sprite.position+Vector3.UP*sprite.offset.y*sprite.pixel_size)
		var crop := Rect2i(Vector2i(center)-Vector2i(256,180),Vector2i(512,360))
		var pp := p.pp.duplicate()
		Input.action_press("skill_0")
		var peak := 0.0
		var frames := int(ceil(Player.SKILL_DENIED_DURATION/DT))+6
		for frame in frames:
			world._step_player(DT)
			p.queue_redraw()
			await process_frame
			game.view3d._process(DT)
			await process_frame
			await RenderingServer.frame_post_draw
			var offset := p.command_feedback_offset()
			peak = maxf(peak,absf(offset.x))
			assert(absf(p.stat_overlay.xform.origin.x-offset.x)<0.001,"Actual sprite transform includes rejection feedback")
			assert(p.position==origin and p.cam_anchor()==cam_anchor,"Physics and camera target remain stationary")
			assert(p.pp==pp,"No PP spent by rejected input")
			if reason=="pp" or frame in [0,1,3,9,frames-1]:
				var image := root.get_texture().get_image()
				image.get_region(crop).save_png(OUT+"%s_%02d.png"%[reason,frame])
		assert(peak>3.0 and peak<=Player.SKILL_DENIED_STRENGTH,"Rejection motion is visibly stronger than the old one-pixel pulse")
		assert(p.skill_denied_t==0.0,"Holding a blocked key does not retrigger")
		metrics.append({"reason":reason,"peak_offset_px":peak,"duration_s":Player.SKILL_DENIED_DURATION,"position_unchanged":true,"camera_anchor_unchanged":true,"pp_unchanged":true,"held_key_retriggered":false})
		print("Rejected input native render passed: ",reason)
	Input.action_release("skill_0")
	var file := FileAccess.open(OUT+"metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	quit()
