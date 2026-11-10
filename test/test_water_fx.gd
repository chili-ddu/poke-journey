extends GutTest
const Effects=preload("res://scripts/battle/kanto_move_fx.gd")
class Idle:
	extends RefCounted
	func move_dir(_w):return Vector2.ZERO
	func aim_point(w):return w.player.position+Vector2.RIGHT*80
	func want_skill(_i,_w):return false
	func want_jump(_w):return false
	func want_dodge(_w):return false
	func want_item(_w):return false
func fixture() -> World:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var w := World.new()
	add_child_autofree(w)
	w.setup(7,"charmander",20,["scratch"],Idle.new())
	w.player.position=Arena.center()
	return w
func enemy(w: World,offset: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup_enemy("rattata",20,w.rng)
	e.position=w.player.position+offset
	w.add_child(e);w.enemies.append(e)
	return e
func test_jet_and_pulse_have_distinct_native_layers_in_eight_directions():
	var p := Projectile.new()
	add_child_autofree(p)
	for row in 8:
		p.vel=Vector2.RIGHT.rotated(row*PI/4.0)*200
		p.radius=4.0;p.style="water";p.age=0.15
		var jet := p.layered_layers()
		assert_eq(jet.size(),3)
		assert_gt(float(jet[0].stretch),2.0)
		assert_lt(Vector2(jet[0].offset).dot(p.vel.normalized()),0.0)
		p.radius=6.0;p.style="pulse";p.range_full=96.0;p.range_left=60.0
		var wave := p.layered_layers()
		assert_eq(wave.size(),4)
		assert_eq(String(wave[1].texture),"g4_ring_q")
		for layer in jet+wave:assert_not_null(Fx.sheet(layer.texture))
func test_water_shapes_animate_without_touching_collision_or_rng():
	var w := fixture()
	var p := Projectile.new()
	add_child_autofree(p)
	p.radius=4.0;p.vel=Vector2.RIGHT*200;p.range_left=84;p.range_full=84
	var state := w.rng.state
	p.age=0.0
	var small: float=p.water_layers()[1].size
	p.age=0.1
	assert_gt(float(p.water_layers()[1].size),small)
	var swell: float=p.pulse_layers()[1].size
	p.age=0.25
	assert_ne(float(p.pulse_layers()[1].size),swell)
	assert_eq(p.radius,4.0);assert_eq(p.range_left,84.0);assert_eq(p.vel,Vector2.RIGHT*200)
	assert_eq(w.rng.state,state)
func test_water_hit_effects_are_distinct_and_follow_target_without_damage():
	for pulse in [false,true]:
		var w := fixture()
		var target := enemy(w,Vector2.RIGHT*40)
		var hp: int=target.hp
		var state := w.rng.state
		Effects.water_hit(w,target,Vector2.RIGHT,pulse)
		assert_eq(w.fxs.size(),8 if pulse else 5)
		target.position+=Vector2(13,7)
		var rings := 0
		for f in w.fxs:
			assert_true(f.body_impact)
			assert_eq(f.follow,target)
			f.step(0.02)
			if f.text=="g4_ring_q":rings+=1
		assert_eq(rings,2 if pulse else 0)
		assert_eq(target.hp,hp);assert_eq(w.rng.state,state)
		assert_eq(target.confuse_t,0.0)
func test_water_gun_stays_five_varied_bodies_with_one_volley():
	var w := fixture()
	w.aim_point=w.player.position+Vector2.RIGHT*100
	w.cast(w.player,"water_gun",Vector2.RIGHT,w.aim_point)
	for i in 5:w._step_bursts(0.031)
	assert_eq(w.projectiles.size(),5)
	var volley: int=w.projectiles[0].hit.volley
	assert_gt(volley,0)
	for p in w.projectiles:
		assert_eq(p.style,"water")
		assert_eq(int(p.hit.volley),volley)
		assert_between(p.radius,4.0*0.8,4.0*1.25)
		assert_between(p.vel.length(),200.0*0.88-0.01,200.0*1.12+0.01)
		assert_eq(p.range_full,84.0)
func test_water_pulse_stays_single_hit_with_existing_confusion_chance():
	var w := fixture()
	var target := enemy(w,Vector2.RIGHT*60)
	target.max_hp=900;target.hp=900
	assert_eq(float(MoveDB.get_move("water_pulse").confuse),0.2)
	w.cast(w.player,"water_pulse",Vector2.RIGHT,target.position)
	assert_eq(w.projectiles.size(),1)
	assert_eq(w.projectiles[0].radius,6.0)
	assert_eq(w.projectiles[0].range_full,96.0)
	assert_almost_eq(w.projectiles[0].vel.length(),150.0,0.001)
	for i in 30:w._step_projectiles(1.0/60.0)
	assert_lt(target.hp,900)
	var after: int=target.hp
	for i in 30:w._step_projectiles(1.0/60.0)
	assert_eq(target.hp,after)
func test_water_3d_uses_layer_textures_stretch_and_camera_projected_aim():
	var view := View3D.new();view.set_process(false);add_child_autofree(view)
	view.root3d=Node3D.new();view.add_child(view.root3d)
	view.cam=Camera3D.new();view.root3d.add_child(view.cam)
	view.cam.rotation_degrees=Vector3(-40,35,0)
	var p := Projectile.new();add_child_autofree(p)
	p.position=Vector2(100,100);p.age=0.25;p.range_full=96.0;p.range_left=58.5
	for style in ["water","pulse"]:
		p.style=style;p.radius=4.0 if style=="water" else 6.0
		var original := Sprite3D.new();view.root3d.add_child(original)
		var ent := {"sprite":original}
		for row in 8:
			p.vel=Vector2.RIGHT.rotated(row*PI/4.0)*200
			view._sync_layered_projectile(p,ent)
			assert_false(original.visible)
			var layer: Sprite3D=ent[style+"_1"]
			assert_eq(layer.texture,Fx.sheet("g4_glow" if style=="water" else "g4_ring_q"))
			assert_eq(layer.billboard,BaseMaterial3D.BILLBOARD_DISABLED)
			assert_false(layer.no_depth_test)
			if style in ["water","pulse"]:
				var vector := View3D.to3d(p.position+p.vel.normalized(),0)-View3D.to3d(p.position,0)
				var expected := Vector2(vector.dot(view.cam.global_basis.x),vector.dot(view.cam.global_basis.y)).normalized()
				var up := layer.basis.y
				var actual := Vector2(up.dot(view.cam.global_basis.x),up.dot(view.cam.global_basis.y)).normalized()
				assert_gt(actual.dot(expected),0.999,"Rings face along the projected shot axis")
func test_water_pulse_rings_form_a_column_without_reaching_behind_launch():
	var p := Projectile.new();add_child_autofree(p)
	p.style="pulse";p.radius=6.0;p.range_full=96.0
	for row in 8:
		var dir := Vector2.RIGHT.rotated(row*PI/4.0)
		p.vel=dir*150
		for traveled in [0.0,3.0,15.0,40.0,80.0]:
			p.range_left=96.0-traveled;p.age=traveled/150.0
			var rings := p.pulse_layers()
			assert_eq(rings.size(),4)
			var previous := -INF
			for ring in rings:
				var along := Vector2(ring.offset).dot(dir)
				assert_gte(along,-traveled-0.001,"Never behind launch point")
				assert_lte(along,0.001,"Never ahead of the collision front")
				assert_gte(along,previous-0.001,"Rings ordered along the shot")
				assert_almost_eq(Vector2(ring.offset).dot(dir.orthogonal()),0.0,0.001)
				previous=along
			if traveled>=40.0:
				assert_gt(float(rings[0].size),float(rings[3].size),"Older rear rings are wider")
				for ring in rings:assert_gt(Color(ring.color).a,0.0)
func test_water_pulse_reveals_rings_only_after_front_has_passed():
	var p := Projectile.new();add_child_autofree(p)
	p.style="pulse";p.radius=6.0;p.vel=Vector2.RIGHT*150;p.range_full=96
	p.range_left=96;p.age=0
	for ring in p.pulse_layers():assert_eq(Color(ring.color).a,0.0)
	p.range_left=90;p.age=0.04
	var early := p.pulse_layers()
	assert_gt(Color(early[3].color).a,0.0,"Front appears first")
	assert_eq(Color(early[0].color).a,0.0,"Rear not shown before launch")
	p.range_left=58.5;p.age=0.25
	for ring in p.pulse_layers():assert_gt(Color(ring.color).a,0.5)
