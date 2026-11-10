extends SceneTree

# 10분 시뮬레이션: 40초 시전 + 10초 자연 정리, 12회. 렌더는 6틱마다 갱신.
#   godot --path . -s tools/crowded_lifecycle_review.gd -- <출력디렉터리>
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
	# This fixture pauses Game; exclude its unconsumed dialogue queue from FX memory accounting.
	w.status_message.disconnect(game._queue_status_message)
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
	var report := []
	var batch_refs: Array = []
	var material_refs: Array = []
	var cast_count := 0
	for cycle in 12:
		w.start_battle(center,200.0)
		for frame in 3000:
			var phase := frame%120
			if frame<2400 and phase in [0,24,48]:
				for actor in actors:
					var skill := "smoke_screen" if phase==0 else "flamethrower" if phase==24 else "dragon_rage"
					w.cast(actor,skill,actor.position.direction_to(center),center)
					cast_count += 1
			if frame==2400: w.end_battle()
			w.step(DT)
			if frame%6==0:
				game.view3d._process(DT)
				await process_frame
			if frame==60:
				for entry in game.view3d._sprites.values():
					for node in entry.values():
						if node is MultiMeshInstance3D:
							batch_refs.append(weakref(node.multimesh))
							break
		for i in 3:
			game.view3d._process(DT)
			await process_frame
		var sample := _sample(cycle)
		sample["casts"] = cast_count
		sample["simulated_seconds"] = (cycle+1)*50
		sample["fx"] = w.fxs.size()
		sample["projectiles"] = w.projectiles.size()
		sample["zones"] = w.zones.size()
		sample["pending"] = w.bursts.size()+w.pending_calls.size()+w.pending_melee.size()+w.pending_casts.size()
		sample["render_entries"] = game.view3d._sprites.size()
		sample["batch_materials"] = game.view3d._projectile_materials.size()
		sample["live_old_batches"] = batch_refs.filter(func(r): return r.get_ref()!=null).size()
		assert(sample.fx==0 and sample.projectiles==0 and sample.zones==0 and sample.pending==0,"Effects must drain naturally")
		assert(sample.live_old_batches==0,"Old projectile batch resources must be released")
		batch_refs.clear() # Diagnostic WeakRefs must not accumulate across cycles.
		report.append(sample)
		FileAccess.open(out+"/lifecycle.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
		print("LIFECYCLE ",JSON.stringify(sample))
	for material in game.view3d._projectile_materials.values(): material_refs.append(weakref(material))
	game.queue_free()
	for i in 5: await process_frame
	var final := _sample(12)
	final["live_batch_materials_after_scene_free"] = material_refs.filter(func(r): return r.get_ref()!=null).size()
	assert(final.live_batch_materials_after_scene_free==0,"Scene-owned batch materials must be released")
	FileAccess.open(out+"/after_scene_free.json",FileAccess.WRITE).store_string(JSON.stringify(final,"  "))
	print("crowded lifecycle review OK: ",cast_count," casts / 600 simulated seconds")
	quit()

func _sample(cycle: int) -> Dictionary:
	var rss := []
	OS.execute("/bin/ps",["-o","rss=","-p",str(OS.get_process_id())],rss)
	return {"cycle":cycle,"static_bytes":OS.get_static_memory_usage(),"rss_kib":int(str(rss[0]).strip_edges()) if not rss.is_empty() else -1,"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"video_bytes":Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}

func _settle(n: int) -> void:
	for i in n:
		game.world.step_visual(DT)
		await process_frame

func _shot(name: String) -> void:
	for i in 3:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [out, name])
