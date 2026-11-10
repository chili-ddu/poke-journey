extends SceneTree

# 동시 시전: 1/3/6 연막과 6마리 연막·화염방사·용의분노 중첩 비교.
#   godot --path . -s tools/crowded_performance_review.gd -- <출력디렉터리>
const DT := 1.0 / 60.0
var out := "."
var game: Node

class Still:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	var direction := Vector2.RIGHT
	func aim_point(w) -> Vector2: return w.player.position + direction * 80.0
	func want_skill(_i: int, _w) -> bool: return false
	func want_dodge(_w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

func _init() -> void:
	out = OS.get_cmdline_user_args()[0]
	OS.set_environment("BOT", "1"); OS.set_environment("GOD", "1"); OS.set_environment("SEED", "1")
	await CaptureWindow.park(self)
	FxStyle.set_mode("custom")
	OS.set_environment("DUNGEON", "kanto_south")
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	game.set_process(false)
	await process_frame
	OS.set_environment("DUNGEON", "")
	var w = game.world
	var p: Player = w.player
	p.controller = Still.new()
	game.banner_t = 0.0
	game.stream.clear()
	p.position = Arena.tile_center(Vector2i(23, 209))
	p.facing = Vector2.RIGHT
	var actors: Array = []
	var center := p.position
	for i in 6:
		var actor := Enemy.new()
		actor.setup_enemy("charmander",30,w.rng)
		actor.max_hp = 99999
		actor.hp = 99999
		actor.position = center+Vector2.from_angle(TAU*i/6.0)*52.0
		actor.frozen = true
		actor.facing = actor.position.direction_to(center)
		for key in actor.cds: actor.cds[key] = 999.0
		w.add_child(actor)
		w.enemies.append(actor)
		actors.append(actor)
	await _settle(30)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	game.view3d.set_process(false)
	if OS.get_environment("PERF_RENDER_SCALE") == "0.5":
		game.view3d.vp.size = game.view3d.vp.size/2
	var report := []
	for round_index in 3:
		for scenario in ["idle","mixed_6"]:
			seed(1234)
			for list in [w.fxs,w.projectiles,w.zones]:
				for node in list: node.queue_free()
				list.clear()
			for list in [w.bursts,w.pending_calls,w.pending_melee,w.pending_casts]: list.clear()
			var samples := []
			for frame in 240:
				var started := Time.get_ticks_usec()
				var phase := frame%120
				if scenario=="mixed_6" and phase in [0,24,48]:
					for actor in actors:
						var skill := "smoke_screen" if phase==0 else "flamethrower" if phase==24 else "dragon_rage"
						w.cast(actor,skill,actor.position.direction_to(center),center)
				w.step(DT)
				var world_end := Time.get_ticks_usec()
				game.view3d._process(DT)
				if OS.get_environment("PERF_NO_PROJECTILE_LIGHTS") == "1":
					for projectile in w.projectiles:
						var entry: Dictionary = game.view3d._sprites.get(projectile.get_instance_id(),{})
						if entry.has("light"): entry["light"].visible = false
				var sync_end := Time.get_ticks_usec()
				await process_frame
				await RenderingServer.frame_post_draw
				var ended := Time.get_ticks_usec()
				if frame>=120:
					samples.append({"frame_ms":(ended-started)/1000.0,"world_ms":(world_end-started)/1000.0,"view_ms":(sync_end-world_end)/1000.0,"fx":w.fxs.size(),"projectiles":w.projectiles.size(),"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT)})
			report.append({"round":round_index,"scenario":scenario,"samples":samples})
	var file := FileAccess.open(out+"/performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"projectile_lights_disabled":OS.get_environment("PERF_NO_PROJECTILE_LIGHTS")=="1","renderer":RenderingServer.get_current_rendering_method(),"viewport":str(game.view3d.vp.size),"vsync":DisplayServer.window_get_vsync_mode(),"rounds":report},"  "))
	print("crowded performance review OK")
	quit()

func _settle(n: int) -> void:
	for i in n:
		game.world.step_visual(DT)
		await process_frame

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
