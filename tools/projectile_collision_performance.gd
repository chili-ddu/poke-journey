extends SceneTree

# CPU-only isolated collision benchmark; single endpoint is a diagnostic baseline,
# not a safe replacement for substeps. All targets are alive and off the flight path.
class BenchWorld:
	extends World
	func endpoint(dt: float) -> void:
		for p in projectiles:
			_advance_projectile(p,dt,{},opponents(p.team))

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var rows := []
	for count in [64,128]:
		for targets in [6,24]:
			for dt in [1.0/60.0,0.5]:
				for mode in ["endpoint","substeps"]:
					rows.append(bench(count,targets,dt,mode))
	var out := OS.get_cmdline_user_args()[0]
	FileAccess.open(out,FileAccess.WRITE).store_string(JSON.stringify({"method":"Headless CPU collision-only timing; 30 warmup + 200 measured samples, 3px radius/200px per sec, reset positions outside timer. Synthetic off-path targets force candidate scanning; no renderer or audio.","samples":rows},"\t")+"\n")
	print(JSON.stringify(rows))
	quit()

func bench(count: int, targets: int, dt: float, mode: String) -> Dictionary:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var w := BenchWorld.new()
	root.add_child(w)
	w.setup(7,"charmander",20,["ember"],null)
	var origin := Arena.center()-Vector2(60,0)
	for i in targets:
		var foe := Enemy.new()
		foe.setup_enemy("rattata",20,w.rng)
		foe.position = origin+Vector2(60,40+i*2)
		w.add_child(foe)
		w.enemies.append(foe)
	for i in count:
		var p := Projectile.new()
		p.vel = Vector2.RIGHT*200
		p.radius = 3
		p.hit = w.make_hit(w.player,"ember")
		w.add_child(p)
		w.projectiles.append(p)
	var values := []
	for frame in 230:
		for p in w.projectiles:
			p.position = origin
			p.range_left = 120.0
			p.dead = false
		var start := Time.get_ticks_usec()
		if mode=="endpoint": w.endpoint(dt)
		else: w._step_projectiles(dt)
		var elapsed := (Time.get_ticks_usec()-start)/1000.0
		if frame>=30: values.append(elapsed)
	values.sort()
	w.free()
	return {"projectiles":count,"targets":targets,"dt":dt,"mode":mode,"median_ms":values[100],"p95_ms":values[190],"max_ms":values[199]}
