extends "res://tools/material_hit_fx_review.gd"

const EXPECTED_RECOIL := {
	"take_down":.25,"submission":.25,"wild_charge":.25,
	"brave_bird":1.0/3,"double_edge":1.0/3,"flare_blitz":1.0/3,
	"volt_tackle":1.0/3,"wood_hammer":1.0/3,"wave_crash":1.0/3,"head_smash":.5,
}

const CONTACT_OUTPUT="res://docs/contact_moves_live/"

const SHAPES={
	"water_gun":["squirtle",Vector2(35,0),Vector2(68,0),Vector2(30,-39)],
	"icy_wind":["glaceon",Vector2(64,-23),Vector2(64,23),Vector2(-32,2)],
	"bulldoze":["geodude",Vector2(32,0),Vector2(-26,10),Vector2(75,0)]
}

func opponent(w: World,offset: Vector2) -> Enemy:
	var e:=Enemy.new()
	e.setup_enemy("chansey",45,w.rng)
	e.frozen=true
	for cd in e.cds: e.cds[cd]=9999
	e.position=w.player.position+offset
	w.add_child(e)
	w.enemies.append(e)
	return e

var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	if not ok:
		failures.append(label)
		printerr(label)

func verify() -> void:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var w:=World.new()
	root.add_child(w)
	w.setup(7,"charmander",40,["fire_spin","flare_blitz"],Still.new())
	w.god=false
	w.player.position=Arena.center()
	var origin:=w.player.position
	var far:=opponent(w,Vector2(58,0))
	var near:=opponent(w,Vector2(31,0))
	# The farther candidate is deliberately registered first.
	w.cast(w.player,"fire_spin",Vector2.RIGHT,origin+Vector2.RIGHT*10)
	var z:=w.zones.back() as World.FireField
	var hp:=near.hp
	for i in 8: w._step_zones(.025)
	check(z.landed and z.position.is_equal_approx(near.position) and near.hp<hp and far.hp==far.max_hp,"First hit and stationary position")
	check(near.bind_t==0 and z.turns in [4,5],"No duplicate attached binding")
	var hp_after:=near.hp
	var landing:=z.position
	near.position+=Vector2.UP*70
	far.position=landing
	for i in 60: w._step_zones(Mon.TURN/60)
	check(z.pulses==1 and near.hp==hp_after and far.hp==far.max_hp-far.residual(),"The turn pulse affects current occupants only")
	far.position=origin+Vector2(100,85)
	w._step_zones(Mon.TURN*(z.turns-1))
	check(z.dead and z.pulses==z.turns and z.position==landing,"Final pulse and expiry")
	w.cast(w.player,"fire_spin",Vector2.RIGHT,origin+Vector2.RIGHT*9)
	z=w.zones.back()
	w._step_zones(.45)
	check(z.landed and z.position.distance_to(origin+Vector2.RIGHT*72)<.01,"Miss reaches maximum even on a short aim")
	# A wall blocks the travelling field before its maximum range.
	var old_obstacles:=Arena.obstacles
	Arena.obstacles=[{"pos":origin+Vector2.RIGHT*48,"r":10.0}]
	w.cast(w.player,"fire_spin",Vector2.RIGHT,origin+Vector2.RIGHT*72)
	z=w.zones.back()
	w._step_zones(.45)
	check(z.landed and not Arena.blocks(z.position,2) and Arena.blocks(z.position+Vector2.RIGHT*2,2),"Wall stops field on the last free step")
	Arena.obstacles=old_obstacles
	for move in EXPECTED_RECOIL.keys()+["struggle"]:
		var attacker:=w.player
		attacker.dead=false
		attacker.hp=attacker.max_hp
		attacker.knock=Vector2.ZERO
		attacker.facing=Vector2.RIGHT
		near.dead=false
		near.hp=12
		near.invuln_t=0
		near.protect_t=0
		var hit:=w.make_hit(attacker,move)
		hit.fixed=100
		w.apply_hit(near,hit,attacker.position)
		var expected:=maxi(1,roundi(attacker.max_hp*.25)) if move=="struggle" else maxi(1,roundi(12*float(EXPECTED_RECOIL[move])))
		check(attacker.max_hp-attacker.hp==expected and attacker.knock.x<0,"Overkill cap and recoil: "+move)
		attacker.knock=Vector2.ZERO
		near.dead=false
		near.hp=near.max_hp
		near.protect_t=1
		var before:=attacker.hp
		w.apply_hit(near,w.make_hit(attacker,move),attacker.position)
		check(attacker.hp==before and attacker.knock==Vector2.ZERO,"Protected: "+move)
	var shared:=w.make_hit(w.player,"flare_blitz")
	shared.fixed=10
	w.player.hp=w.player.max_hp
	for target in [near,far]:
		target.dead=false
		target.hp=target.max_hp
		target.protect_t=0
		target.invuln_t=0
		w.apply_hit(target,shared,origin)
	check(shared.recoil_state.paid==7 and w.player.max_hp-w.player.hp==7,"One cast aggregates both contacts without rounding twice")
	w.player.position=origin
	w.player.knock=Vector2.ZERO
	near.position=origin+Vector2.UP*60
	far.position=origin+Vector2.UP*70
	var hp_start:=w.player.hp
	w.cast(w.player,"flare_blitz",Vector2.RIGHT,origin)
	for i in 20:
		if not w.player.dash.is_empty():w._step_dash(w.player,1.0/30)
	check(w.player.hp==hp_start and w.player.knock==Vector2.ZERO,"Empty dash has no recoil")
	# Exercise actual dash entry points, including the two moves formerly charged in _step_dash.
	for id in ["flare_blitz","take_down","double_edge"]:
		w.player.hp=w.player.max_hp
		w.player.dead=false
		w.player.position=origin
		w.player.knock=Vector2.ZERO
		near.dead=false
		near.position=origin+Vector2.RIGHT*33
		near.hp=near.max_hp
		near.invuln_t=0
		near.protect_t=0
		var old_hp:=near.hp
		w.cast(w.player,id,Vector2.RIGHT,near.position)
		for i in 30:
			if not w.player.dash.is_empty(): w._step_dash(w.player,1.0/30)
		var dealt:=old_hp-near.hp
		check(dealt>0 and w.player.max_hp-w.player.hp==maxi(1,roundi(dealt*float(EXPECTED_RECOIL[id]))),"Dash recoil is billed once: "+id)
		check(w.player.knock.x<0 and w.player.dash.is_empty(),"Dash reverses at first contact: "+id)
	near.hp=near.max_hp
	near.dead=false
	near.facing=Vector2.LEFT
	w.player.invuln_t=0
	w.player.protect_t=0
	var enemy_hit:=w.make_hit(near,"head_smash")
	enemy_hit.fixed=8
	w.apply_hit(w.player,enemy_hit,near.position)
	check(near.max_hp-near.hp==4 and near.knock.x>0,"Enemy cast uses the same opposite-facing recoil")
	w.free()
	print("Contact checks: ",failures)

func run() -> void:
	SaveData.path="user://save_contact_study_private.cfg"
	for pair in [["BOT","1"],["GOD","0"],["SEED","7"],["STARTER","charmander"],["DUNGEON","kanto_south"]]:
		OS.set_environment(pair[0],pair[1])
	if DisplayServer.get_name()=="headless":
		verify()
		quit(0 if failures.is_empty() else 1)
		return
	await CaptureWindow.park(self)
	for scene_id in ["dash_hit","dash_miss","spin_hit","spin_miss","take_down","double_edge","water_gun","icy_wind","bulldoze"]:
		await capture(scene_id)
	quit(0 if failures.is_empty() else 1)

func capture(id: String) -> void:
	var spin:=id.begins_with("spin")
	var study:=SHAPES.has(id)
	var move:=id if study or id in ["take_down","double_edge"] else ("fire_spin" if spin else "flare_blitz")
	MoveDB.clear_cache()
	FxStyle.set_mode("custom")
	seed(7)
	var game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene=game
	game.set_process(false)
	game.stream.clear()
	game.ui_root.visible=false
	game.view3d.set_process(false)
	var old: World=game.world
	var w:=World.new()
	game.add_child(w)
	game.world=w
	game.view3d.world=w
	old.free()
	var input:=ReviewInput.new()
	w.setup(7,String(SHAPES[id][0]) if study else "charmander",40,[move],input)
	w.god=false
	w.visibility_layer|=Look.GROUND_LAYER
	w.player.position=open_cross()-Vector2.RIGHT*26
	w.player.facing=Vector2.RIGHT
	w.player.repel_steps=100000
	var foe: Enemy
	var subjects: Array[Enemy]=[]
	var start_hp: Array[int]=[]
	if study:
		for pos in SHAPES[id].slice(1):
			var target:=opponent(w,pos)
			subjects.append(target)
			start_hp.append(target.hp)
	elif not id.ends_with("miss"): foe=opponent(w,Vector2(40,0))
	var origin: Vector2=w.player.position
	game.view3d._cam_ready=false
	var dest:=CONTACT_OUTPUT+id+"/"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dest))
	var rows:=[]
	var frames:=137 if spin else 48
	var fps:=16 if spin else 30
	for i in frames:
		if i==5: input.requested=true
		for sub in 4: w.step(1.0/(fps*4))
		game.view3d._process(1.0/fps)
		await process_frame
		await RenderingServer.frame_post_draw
		check(root.size==Vector2i(384,216),"Minimum capture size")
		root.get_texture().get_image().save_png(dest+"%03d.png"%i)
		if study:
			rows.append(subjects.map(func(e):return e.hp))
		else:
			rows.append([w.player.hp,foe.hp if foe else -1,w.player.position.x-origin.x])
	if study:
		check(subjects[0].hp<start_hp[0] and subjects[1].hp<start_hp[1] and subjects[2].hp==start_hp[2],"Two inside, one outside: "+id)
	FileAccess.open(dest+"trace.json",FileAccess.WRITE).store_string(JSON.stringify(rows))
	print(id," ",rows[0]," -> ",rows.back())
	game.free()
	await process_frame
