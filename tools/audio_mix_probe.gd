extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	print("DRIVER ",AudioServer.get_driver_name())
	var p := AudioStreamPlayer.new()
	root.add_child(p)
	p.stream = load("res://assets/audio/se/door.wav")
	for i in 4:
		p.play()
		await create_timer(0.5).timeout
		print("MIX ",AudioServer.get_time_since_last_mix()," position ",p.get_playback_position()," playing ",p.playing)
	p.stop()
	p.stream = null
	p.queue_free()
	await create_timer(1.0).timeout
	quit()
