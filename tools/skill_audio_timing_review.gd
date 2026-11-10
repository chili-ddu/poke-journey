extends SceneTree

var elapsed := 0.0
var events: Array = []
class Idle:
	extends RefCounted
	func move_dir(_w): return Vector2.ZERO
	func aim_point(w): return w.player.position+Vector2.RIGHT*30
	func want_skill(_i,_w): return false
	func want_dodge(_w): return false
	func want_jump(_w): return false
	func want_item(_w): return false

func _init() -> void:
	await process_frame
	var audio := Sfx._node()
	await process_frame
	audio.sound_requested.connect(func(path,pitch,db,duration):events.append({"at":elapsed,"path":path,"pitch":pitch,"db":db,"max_duration":duration}))
	var report := []
	FxStyle.set_mode("custom")
	for move in ["scratch","fire_fang","ember","flamethrower","dragon_rage","growl"]:
		DungeonDB.set_current("test_meadow")
		Arena.configure(DungeonDB.theme())
		var w := World.new()
		root.add_child(w)
		w.setup(7,"charmander",20,[move],Idle.new())
		w.player.position = Arena.center()
		var foe := Enemy.new()
		foe.setup_enemy("rattata",20,w.rng)
		foe.hp = 9999; foe.max_hp = 9999
		foe.position = w.player.position+Vector2.RIGHT*30
		foe.frozen = true
		for key in foe.cds: foe.cds[key] = 999.0
		w.add_child(foe)
		w.enemies.append(foe)
		events = []
		elapsed = 0.0
		var impacts := []
		w.cast(w.player,move,Vector2.RIGHT,foe.position)
		for frame in 120:
			elapsed = (frame+1)/60.0
			var hp := foe.hp
			w.step(1.0/60.0)
			if foe.hp<hp: impacts.append(elapsed)
		report.append({"move":move,"events":events.duplicate(true),"damage_times":impacts})
		w.queue_free()
		await process_frame
	FileAccess.open(OS.get_cmdline_user_args()[0]+"/timing.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("skill audio timing review OK")
	quit()
