extends SceneTree

# Controlled movement fixture: actual burst, movement, projectile and Fx update paths.
# Excludes AI, collision pushing and player input so each trajectory is reproducible.
class Idle:
	extends RefCounted
	func move_dir(_w): return Vector2.ZERO
	func aim_point(w): return w.aim_point
	func want_skill(_i,_w): return false
	func want_dodge(_w): return false
	func want_jump(_w): return false
	func want_item(_w): return false

func _init() -> void:
	call_deferred("run")

func run() -> void:
	FxStyle.set_mode("custom")
	var rows := []
	for fps in [30,60]:
		for move in ["ember","flamethrower","dragon_rage"]:
			for direction in 8:
				for motion in ["cross_left","cross_right","approach","retreat"]:
					rows.append(sample(fps,move,direction,motion))
	var f := FileAccess.open("res://docs/moving_target_contact/results.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"method":"Headless controlled trajectories, 48 world pixels/sec; runtime geometry and attachment checks, not rendered screenshots.","samples":rows},"\t")+"\n")
	print("Moving target contact: ",rows.size()," cases; hits ",rows.filter(func(r):return r.hits>0).size())
	quit()

func sample(fps: int, move: String, direction: int, motion: String) -> Dictionary:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var w := World.new()
	root.add_child(w)
	w.setup(7,"charmander",20,[move],Idle.new())
	var forward := Vector2.RIGHT.rotated(direction*PI/4.0)
	var foe := Enemy.new()
	foe.setup_enemy("rattata",20,w.rng)
	foe.hp = 9999
	foe.max_hp = 9999
	foe.position = w.player.position+forward*42
	var velocity := forward*48.0
	if motion=="approach": velocity = -velocity
	elif motion.begins_with("cross"):
		velocity = forward.orthogonal()*48.0*(1.0 if motion=="cross_left" else -1.0)
		foe.position -= velocity*0.15
	w.add_child(foe)
	w.enemies.append(foe)
	w.aim_point = foe.position
	w.cast(w.player,move,forward,foe.position)
	var hits := 0
	var first_hit := -1.0
	var attached := 0
	var max_attachment_error := 0.0
	for frame in fps:
		var dt := 1.0/fps
		# Keep trajectory moving even after impact to test visual attachment under motion.
		foe.hitstop_t = 0.0
		foe.flinch_t = 0.0
		foe.knock = Vector2.ZERO
		foe.vel = velocity
		w._step_bursts(dt)
		w._move_mons(dt)
		var hp := foe.hp
		w._step_projectiles(dt)
		if foe.hp<hp:
			hits += 1
			first_hit = float(frame+1)/fps if first_hit<0 else first_hit
			assert(foe.hit_visual_t>0.0,"Damage starts body feedback on same update")
		for fx in w.fxs:
			fx.step(dt)
			if not fx.dead and fx.follow==foe and fx.speed==0.0 and fx.orbit_r==0.0:
				attached += 1
				max_attachment_error = maxf(max_attachment_error,fx.position.distance_to(foe.position+fx.offset))
		w._cleanup()
	assert(hits==1,"Controlled crossing must hit exactly once per volley")
	assert(max_attachment_error<0.001,"Attached hit art tracks moving target")
	var row := {"fps":fps,"move":move,"direction":direction,"motion":motion,"hits":hits,"first_hit":first_hit,"attachment_samples":attached,"max_attachment_error":max_attachment_error}
	w.free()
	return row
