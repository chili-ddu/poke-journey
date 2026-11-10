extends SceneTree
# Real Godot mixer capture, silent Dummy output. No microphone/speaker recording.
func _init() -> void:
	call_deferred("run")

func run() -> void:
	var before := AudioEffectCapture.new()
	var after := AudioEffectCapture.new()
	before.buffer_length = 5.0
	after.buffer_length = 5.0
	assert(AudioServer.get_bus_effect_count(0) == 1, "Project limiter must load")
	assert(AudioServer.get_bus_effect(0, 0) is AudioEffectHardLimiter)
	AudioServer.add_bus_effect(0, before, 0)
	AudioServer.add_bus_effect(0, after)
	var audio := Sfx._node()
	await process_frame
	Sfx._silent = false
	var music := AudioStreamPlayer.new()
	root.add_child(music)
	music.stream = load("res://assets/audio/seq_ba_train.wav")
	music.volume_db = Bgm.BATTLE_VOLUME_DB
	var rows := []
	for scenario in ["single", "mixed_eight", "staggered_impacts"]:
		music.play(8.0)
		before.clear_buffer()
		after.clear_buffer()
		for cycle in 3:
			if scenario == "single":
				Sfx.move("ember")
			elif scenario == "mixed_eight":
				for move in ["ember", "flamethrower", "scratch", "fire_fang", "dragon_rage", "smoke_screen", "scary_face"]:
					Sfx.move(move, 0.84 if move == "flamethrower" else -1.0)
				Sfx.play("kouka_m")
			else:
				for i in 8:
					Sfx.play("kouka_m")
					await create_timer(0.05).timeout
			await create_timer(0.6).timeout
		music.stop()
		for voice in audio._players: voice.stop()
		await create_timer(0.2).timeout
		var raw := measure(before)
		var limited := measure(after)
		rows.append({"scenario":scenario,"before":raw,"after":limited})
		assert(int(raw.frames)>0 and int(limited.frames)>0, "Mixer must actually render samples")
		assert(int(raw.discarded_frames)==0 and int(limited.discarded_frames)==0, "No capture overflow")
		if scenario == "single":
			assert(absf(float(raw.peak)-float(limited.peak))<0.001, "Quiet peak unchanged")
		assert(float(limited.peak)<=db_to_linear(-1.0)+0.001, "Output ceiling")
	var out := "res://docs/audio_balance/crowded_mix.json"
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify({"driver":AudioServer.get_driver_name(),"method":"Actual Godot mixer float samples before/after limiter; no listening. Three cycles per scenario; music starts at 8 seconds.","results":rows},"\t")+"\n")
	print(JSON.stringify(rows))
	music.stream = null
	music.queue_free()
	quit()

func measure(capture: AudioEffectCapture) -> Dictionary:
	var frames := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	var over := 0
	for frame in frames:
		peak = maxf(peak,maxf(absf(frame.x),absf(frame.y)))
		if absf(frame.x)>1.0 or absf(frame.y)>1.0: over+=1
	return {"frames":frames.size(),"peak":peak,"peak_dbfs":linear_to_db(peak),"over_full_scale_frames":over,"discarded_frames":capture.get_discarded_frames()}
