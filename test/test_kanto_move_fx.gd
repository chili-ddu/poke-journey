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
func test_original_particle_assets_are_available():
	for key in ["kanto_absorb_2","kanto_absorb_3","kanto_mega_drain_2","kanto_mega_drain_3","kanto_acid_1","kanto_supersonic_0"]:
		assert_not_null(Fx.sheet(key),key)
func test_fx_do_not_consume_combat_rng_or_change_hp():
	var w := fixture()
	var e := enemy(w,Vector2.RIGHT*40)
	var state := w.rng.state
	var hp: int=e.hp
	Effects.drain(w,w.player,e,false)
	Effects.sonic(w,w.player,w.player.position,Vector2.RIGHT,72.0)
	Effects.acid_hit(w,e,Vector2.RIGHT)
	assert_eq(w.rng.state,state)
	assert_eq(e.hp,hp)
func test_absorb_and_mega_drain_keep_damage_and_half_damage_healing():
	for id in ["absorb","mega_drain"]:
		var w := fixture()
		var target := enemy(w,Vector2.RIGHT*40)
		w.player.hp=1
		var before: int=target.hp
		w.cast(w.player,id,Vector2.RIGHT,target.position)
		var damage: int=before-target.hp
		assert_gt(damage,0)
		assert_eq(w.player.hp,1)
		var seeking := 0
		for f in w.fxs:
			if f.seek_target==w.player:seeking+=1
		assert_eq(seeking,8 if id=="mega_drain" else 5)
		w._step_pending_calls(0.5)
		assert_eq(w.player.hp,mini(w.player.max_hp,1+maxi(1,int(round(damage*0.5)))))
func test_return_particles_follow_moving_caster_and_stop_safely_if_removed():
	var source := Mon.new()
	add_child_autofree(source)
	source.position=Vector2(60,0)
	var f := Fx.new()
	add_child_autofree(f)
	f.kind="sprite";f.lifetime=0.4
	f.seek_target=source;f.seek_from=Vector2.ZERO;f.seek_offset=Vector2(0,-4);f.seek_bend=12
	f.step(0.2)
	assert_gt(f.position.x,0.0)
	source.position=Vector2(100,20)
	f.step(0.2)
	assert_lt(f.position.distance_to(source.position+f.seek_offset),0.001)
	var orphan := Fx.new()
	add_child_autofree(orphan)
	orphan.seek_target=source
	source.free()
	orphan.step(0.1)
	assert_true(orphan.dead)
func test_supersonic_confuses_only_targets_in_unchanged_front_cone():
	var w := fixture()
	var front := enemy(w,Vector2.RIGHT*40)
	var back := enemy(w,Vector2.LEFT*40)
	var before: int=front.hp
	w._status_cone(w.player,MoveDB.get_move("supersonic"),Vector2.RIGHT)
	assert_gt(front.confuse_t,0.0)
	assert_eq(back.confuse_t,0.0)
	assert_eq(front.hp,before)
	var fractures := 0
	for f in w.fxs:
		if f.sound_fracture:fractures+=1
	assert_eq(fractures,18)
func test_acid_droplets_share_one_hitbox_and_visuals_are_direction_independent():
	var p := Projectile.new()
	add_child_autofree(p)
	p.radius=5.0;p.range_left=96.0;p.range_full=96.0
	for row in 8:
		p.vel=Vector2.RIGHT.rotated(row*PI/4.0)*135.0
		p.age=0.1
		var layers := p.acid_layers()
		assert_eq(layers.size(),4)
		assert_eq(p.radius,5.0)
		assert_eq(p.range_left,96.0)
		for layer in layers:
			assert_gt(float(layer.size),0.0)
			assert_lte(Vector2(layer.offset).dot(p.vel.normalized()),0.001)
