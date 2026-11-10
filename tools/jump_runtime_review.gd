extends SceneTree

# Native 2D/3D integration capture. Uses a test game with BOT save isolation.
const DT := 1.0 / 60.0
const OUT := "res://docs/jump_feel_preview/runtime/"

class Still:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position + Vector2.RIGHT * 80.0
	func want_skill(_i, _w) -> bool: return false
	func want_dodge(_w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

func _init() -> void: call_deferred("run")

func run() -> void:
	OS.set_environment("BOT", "1")
	OS.set_environment("GOD", "1")
	OS.set_environment("SEED", "7")
	OS.set_environment("DUNGEON", "kanto_south")
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
	var mon: Player = world.player
	var metrics: Array = []
	for species in ["charmander", "bulbasaur", "squirtle"]:
		mon.setup_player(species,12,["scratch"])
		mon.controller = Still.new()
		mon.facing = Vector2.RIGHT
		var plan := {}
		for y in range(180,190):
			for x in range(20,30):
				var start := Arena.tile_center(Vector2i(x,y))
				if Arena.resolve(start,mon.radius).distance_to(start)>0.1: continue
				var target := start+Vector2.RIGHT*Player.JUMP_DISTANCE
				if Arena.resolve(target,mon.radius).distance_to(target)>0.1: continue
				var candidate := world.plan_hop(start,Vector2.RIGHT)
				if candidate.ok:
					mon.position = start
					plan = candidate
					break
			if not plan.is_empty(): break
		assert(not plan.is_empty(), "Open path for jump capture")
		game.view3d._cam_ready = false
		for i in 3:
			mon.queue_redraw()
			await process_frame
			game.view3d._process(DT)
		var origin := mon.position
		world._start_hop(plan.to)
		var landed_at := -1
		for frame in 37:
			if frame>0: world.step(DT)
			mon.queue_redraw()
			await process_frame
			game.view3d._process(DT)
			await process_frame
			await RenderingServer.frame_post_draw
			if mon._anim_name == "Hop":
				var hop: Dictionary = mon._sprites.Hop
				var time := MonSprite.hop_sheet_time(hop,mon.anim_t-mon._anim_start)
				var expected := MonSprite.visual_frame(hop,MonSprite.row_for(hop,mon.facing),time,false)
				assert(mon.stat_overlay.tex==expected.tex and mon.stat_overlay.src==expected.src,"Actual drawing uses retimed C pose")
			if landed_at<0 and not mon.is_dashing(): landed_at=frame
			if frame in [0,6,12,18,22,24,26,30,36]:
				root.get_texture().get_image().save_png(OUT+"%s_%02d.png"%[species,frame])
		assert(landed_at==24,"Flight still ends at 0.4 seconds")
		assert(mon.position.distance_to(origin+Vector2.RIGHT*48.0)<0.1,"Travel still 48px")
		assert(mon.recover_t==0.0 and mon.skill_lock_t==0.0,"No landing action lock")
		metrics.append({"species":species,"landing_tick":landed_at,"distance":mon.position.distance_to(origin),"render_pose_verified":true})
		print("Jump native renderer passed: ",species)
	var file := FileAccess.open(OUT+"metrics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(metrics,"\t"))
	quit()
