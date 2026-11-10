extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	OS.set_environment("CAP_AUDIO","1") # This diagnostic must exercise real playback.
	await CaptureWindow.park(self)
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	SaveData.path = "user://save_resource_review.cfg"
	if OS.get_environment("RESOURCE_SILENT") == "1":
		Bgm._node()._silent = true
		Sfx._node()
		Sfx._silent = true
	var samples: Array = []
	for cycle in 6:
		for place in ["players_house_1f","players_house_2f","viridian_center"]:
			OS.set_environment("DUNGEON",place)
			var game = load("res://scenes/main.tscn").instantiate()
			root.add_child(game)
			game.set_process(false)
			await process_frame
			OS.set_environment("DUNGEON","")
			Sfx.play("door")
			await create_timer(0.15).timeout
			game.queue_free()
			await process_frame
			await process_frame
		await create_timer(0.2).timeout
		var sample := {"cycle":cycle,"mix_age":AudioServer.get_time_since_last_mix(),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)}
		samples.append(sample)
		print("LIFECYCLE ",sample)
	DirAccess.make_dir_recursive_absolute("res://docs/resource_lifecycle")
	var name := OS.get_environment("RESOURCE_RUN")
	FileAccess.open("res://docs/resource_lifecycle/"+name+".json",FileAccess.WRITE).store_string(JSON.stringify(samples,"  "))
	Bgm.stop(false)
	for player in Sfx._node()._players:
		player.stop()
		player.stream = null
	await create_timer(2.0).timeout
	print("DRAINED objects=",Performance.get_monitor(Performance.OBJECT_COUNT))
	quit()
