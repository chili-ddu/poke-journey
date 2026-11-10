extends SceneTree

func _init() -> void:
	await process_frame
	var audio := Sfx.new()
	root.add_child(audio)
	Sfx._silent = false # Run with --audio-driver Dummy; exercise voices without speaker output.
	var samples := []
	audio._play(Sfx.SE_DIR+"decide.wav",1.0,-6.0)
	var ui_voice: AudioStreamPlayer = audio._players[0]
	var ui_stream := ui_voice.stream
	for name in ["ember","flamethrower","dragon_rage","scratch","fire_fang","smoke_screen","scary_face","tackle"]:
		audio._play(Sfx.SE_DIR+"mv_"+name+".wav",1.0,-6.0)
	samples.append({"case":"ui_under_burst","ui_preserved":ui_voice.stream==ui_stream,"active":audio._players.filter(func(p):return p.playing).size()})
	for p in audio._players: p.stop(); p.stream=null
	for i in 6: audio._play(Sfx.SE_DIR+"kouka_m.wav",1.0,-6.0)
	samples.append({"case":"six_simultaneous_hits","active":audio._players.filter(func(p):return p.playing).size()})
	await create_timer(1.0).timeout
	samples.append({"case":"after_playback","active":audio._players.filter(func(p):return p.playing).size(),"retained_streams":audio._players.filter(func(p):return p.stream!=null).size()})
	FileAccess.open(OS.get_cmdline_user_args()[0],FileAccess.WRITE).store_string(JSON.stringify(samples,"  "))
	print("sfx pool review OK ",samples)
	quit()
