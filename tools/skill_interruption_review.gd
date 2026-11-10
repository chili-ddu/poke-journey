extends SceneTree

# Scene disposal while attacks are live: real 3D renderer, no manual effect cleanup.
func _init() -> void:
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("DUNGEON","kanto_south")
	FxStyle.set_mode("custom")
	var report := []
	for cycle in 8:
		var game = load("res://scenes/main.tscn").instantiate()
		root.add_child(game)
		game.set_process(false)
		await process_frame
		var w: World = game.world
		assert(w.pending_calls.is_empty() and w.bursts.is_empty() and w.pending_melee.is_empty())
		w.player.position = Arena.tile_center(Vector2i(23,209))
		var aim := w.player.position+Vector2(30,0)
		for move in ["smoke_screen","flamethrower","fire_fang"]:
			w.cast(w.player,move,Vector2.RIGHT,aim)
		w._step_bursts(0.04)
		for i in 3: await process_frame
		var refs := [weakref(w),weakref(game.view3d)]
		for fx in w.fxs: refs.append(weakref(fx))
		for projectile in w.projectiles: refs.append(weakref(projectile))
		for entry in game.view3d._sprites.values():
			for node in entry.values(): refs.append(weakref(node))
		var sample := {"cycle":cycle,"fx_before":w.fxs.size(),"projectiles_before":w.projectiles.size(),"pending_before":w.pending_calls.size()+w.pending_melee.size()+w.bursts.size(),"tracked":refs.size()}
		assert(sample.pending_before>0 and sample.projectiles_before>0)
		game.queue_free()
		for i in 5: await process_frame
		sample["remaining_tracked"] = refs.filter(func(r):return r.get_ref()!=null).size()
		assert(sample.remaining_tracked==0)
		report.append(sample)
		print("INTERRUPTION ",JSON.stringify(sample))
	FileAccess.open(OS.get_cmdline_user_args()[0]+"/scene_cycles.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("skill interruption scene review OK")
	quit()
