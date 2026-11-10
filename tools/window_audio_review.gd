extends SceneTree
# Normal visible window, actual game scene and audio; isolated save, no capture parking.
func _init() -> void: call_deferred("run")
func run() -> void:
	SaveData.path = "user://save_window_audio_review.cfg"
	OS.set_environment("BOT","1")
	OS.set_environment("GOD","1")
	OS.set_environment("DUNGEON","viridian_center")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	OS.set_environment("DUNGEON","")
	if OS.get_environment("AUDIO_DEVICE") != "":
		AudioServer.output_device = OS.get_environment("AUDIO_DEVICE")
	if OS.get_environment("AUDIO_FOCUS") == "1":
		DisplayServer.window_move_to_foreground()
		root.grab_focus()
	if OS.get_environment("AUDIO_WAIT_FOCUS") == "1":
		print("WAITING_FOR_FOCUS pid=",OS.get_process_id())
		for attempt in 600:
			if root.has_focus(): break
			await create_timer(0.1).timeout
		print("FOCUS_READY ",root.has_focus())
	Sfx._node()
	await process_frame
	var samples: Array = []
	var device := AudioServer.output_device
	var devices := AudioServer.get_output_device_list()
	print("AUDIO driver=",AudioServer.get_driver_name()," selected=",device," available=",devices)
	for song in ["mus_poke_center","mus_pallet"]:
		Bgm.play(song,false)
		Sfx.play("door")
		var effect: AudioStreamPlayer = Sfx._node()._players[(Sfx._node()._next-1+Sfx.POOL)%Sfx.POOL]
		for i in 4:
			await create_timer(0.5).timeout
			var row := {"song":song,"mix_age":AudioServer.get_time_since_last_mix(),"position":Bgm._node().main.get_playback_position(),"playing":Bgm._node().main.playing,"focused":root.has_focus(),"sfx_position":effect.get_playback_position(),"sfx_playing":effect.playing}
			samples.append(row)
			print("SAMPLE ",row)
	Bgm.stop(false)
	for player in Sfx._node()._players:
		player.stop()
		player.stream = null
	game.queue_free()
	await create_timer(1.0).timeout
	DirAccess.make_dir_recursive_absolute("res://docs/window_audio")
	var suffix := OS.get_environment("AUDIO_RUN")
	if suffix == "": suffix = "dummy" if AudioServer.get_driver_name()=="Dummy" else "coreaudio"
	FileAccess.open("res://docs/window_audio/"+suffix+".json",FileAccess.WRITE).store_string(JSON.stringify({"driver":AudioServer.get_driver_name(),"selected":device,"devices":devices,"samples":samples},"  "))
	quit()
