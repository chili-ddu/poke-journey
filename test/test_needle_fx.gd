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
func test_needle_layers_keep_single_projectile_in_eight_directions():
	var p := Projectile.new()
	add_child_autofree(p)
	p.radius=2.0;p.range_full=120.0;p.range_left=120.0
	for row in 8:
		p.vel=Vector2.RIGHT.rotated(row*PI/4.0)*120.0
		var layers := p.needle_layers()
		assert_eq(layers.size(),2)
		assert_eq(String(layers[1].texture),"poison_needle")
		assert_not_null(Fx.sheet(layers[1].texture))
		assert_almost_eq(float(layers[1].size),9.6,0.001)
		assert_lt(Vector2(layers[0].offset).dot(p.vel.normalized()),0.0)
		assert_eq(p.radius,2.0)
		assert_eq(p.range_left,120.0)
		assert_almost_eq(p.vel.length(),120.0,0.001)
func test_needle_hit_particles_follow_victim_without_combat_side_effects():
	var w := fixture()
	var target := enemy(w,Vector2.RIGHT*40)
	var state := w.rng.state
	var hp: int=target.hp
	Effects.needle_hit(w,target,Vector2.RIGHT)
	assert_eq(w.fxs.size(),6)
	target.position+=Vector2(12,9)
	for f in w.fxs:
		assert_eq(f.follow,target)
		assert_true(f.body_impact)
		f.step(0.03)
		if f.text=="poison_needle":assert_eq(f.position,target.position+f.offset)
	assert_eq(w.rng.state,state)
	assert_eq(target.hp,hp)
	assert_eq(target.poison_t,0.0,"A poison-colored puff does not inflict poison")
func test_needle_cast_keeps_speed_range_poison_and_one_damage_hit():
	var w := fixture()
	var target := enemy(w,Vector2.RIGHT*60)
	target.hp=900;target.max_hp=900
	var m := MoveDB.get_move("poison_sting")
	assert_eq(float(m.poison),0.3)
	w.cast(w.player,"poison_sting",Vector2.RIGHT,target.position)
	assert_eq(w.projectiles.size(),1)
	assert_eq(w.projectiles[0].radius,2.0)
	assert_eq(w.projectiles[0].range_full,120.0)
	assert_eq(w.projectiles[0].vel.length(),120.0)
	for i in 40:
		w._tick_status(1.0/60.0)
		w._step_projectiles(1.0/60.0)
	assert_lt(target.hp,900)
	var after: int=target.hp
	for i in 10:
		w._tick_status(1.0/60.0)
		w._step_projectiles(1.0/60.0)
	assert_eq(target.hp,after)
	var needles := 0
	for f in w.fxs:
		if f.text=="poison_needle":needles+=1
	assert_eq(needles,1)
func test_needle_3d_uses_thin_needle_and_aims_with_projected_velocity():
	var view := View3D.new()
	view.set_process(false)
	add_child_autofree(view)
	view.root3d=Node3D.new();view.add_child(view.root3d)
	view.cam=Camera3D.new();view.root3d.add_child(view.cam)
	view.cam.rotation_degrees=Vector3(-40,35,0)
	var p := Projectile.new()
	add_child_autofree(p)
	p.style="needle";p.radius=2.0;p.position=Vector2(100,100)
	var original := Sprite3D.new();view.root3d.add_child(original)
	var ent := {"sprite":original}
	for row in 8:
		p.vel=Vector2.RIGHT.rotated(row*PI/4.0)*120
		view._sync_layered_projectile(p,ent)
		var head: Sprite3D=ent.needle_1
		assert_eq(head.texture,Fx.sheet("poison_needle"))
		assert_false(original.visible)
		assert_false(head.no_depth_test)
		assert_eq(head.billboard,BaseMaterial3D.BILLBOARD_DISABLED,"Keep the computed flight rotation")
		var vector := View3D.to3d(p.position+p.vel.normalized(),0)-View3D.to3d(p.position,0)
		var expected := Vector2(vector.dot(view.cam.global_basis.x),vector.dot(view.cam.global_basis.y)).normalized()
		var up := head.basis.y
		var actual := Vector2(up.dot(view.cam.global_basis.x),up.dot(view.cam.global_basis.y)).normalized()
		assert_gt(expected.dot(actual),0.999)
func test_needle_range_end_does_not_damage_distant_target():
	var w := fixture()
	var target := enemy(w,Vector2.RIGHT*180)
	var hp: int=target.hp
	w.cast(w.player,"poison_sting",Vector2.RIGHT,target.position)
	for i in 80:w._step_projectiles(1.0/60.0)
	assert_eq(target.hp,hp)
	assert_eq(target.poison_t,0.0)
	for p in w.projectiles:assert_true(p.dead)
func test_needle_art_is_a_thin_shaft_without_a_wide_horn_base():
	var texture := Fx.sheet("poison_needle")
	assert_not_null(texture)
	var image := texture.get_image()
	var widest := 0
	var rows := 0
	for y in image.get_height():
		var left := image.get_width()
		var right := -1
		for x in image.get_width():
			if image.get_pixel(x,y).a>0.1:
				left=mini(left,x);right=maxi(right,x)
		if right>=left:
			rows+=1
			widest=maxi(widest,right-left+1)
	assert_lte(widest,4,"No broad triangular base")
	assert_gte(float(rows)/maxi(widest,1),6.0,"Long slender shaft")
