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
	for sample in 16:
		var move: String = ["scratch","fire_fang","ember","flamethrower","dragon_rage","growl","smoke_screen","scary_face"][sample%8]
		var fps := 30 if sample<8 else 60
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
		var changes := []
		var previous := state(foe)
		var snap_at := -1.0
		w.cast(w.player,move,Vector2.RIGHT,foe.position)
		for frame in range(fps*2+1):
			elapsed = float(frame)/fps
			if frame>0: w.step(1.0/fps)
			var current := state(foe)
			var faces := w.fxs.filter(func(f):return f.scare_snap)
			if snap_at<0 and not faces.is_empty() and faces[0].anim_frame_at(faces[0].age/faces[0].lifetime)==3:
				snap_at = elapsed
			if current!=previous:
				var markers := []
				for f in w.fxs:
					if f.dead or f.age<f.delay: continue
					if f.kind=="fang_directional": markers.append({"kind":f.kind,"closure":f.fang_close_progress()})
					elif f.scare_snap: markers.append({"kind":"scary_face","frame":f.anim_frame_at(f.age/f.lifetime)})
					elif f.smoke_veil: markers.append({"kind":"smoke_cloud"})
					elif f.follow==foe: markers.append({"kind":f.kind,"texture":f.text})
				changes.append({"at":elapsed,"state":current,"visible_effect_state":markers})
				previous = current
		assert(not changes.is_empty(), "Every fixture must produce damage or rank change")
		if move=="scary_face":
			assert(absf(float(changes[0].at)-snap_at)<=1.0/fps+0.0001)
		report.append({"move":move,"fps":fps,"changes":changes,"surprise_at":snap_at})
		w.queue_free()
		await process_frame
	FileAccess.open("res://docs/skill_visual_timing/timing.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("skill visual timing review OK")
	quit()

func state(foe: Mon) -> Array:
	return [foe.hp,foe.atk_stage,foe.acc_stage,foe.spe_stage]
