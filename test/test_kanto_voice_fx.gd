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
func test_original_notes_and_hypnotic_textures_load():
	for key in ["kanto_sing_1","kanto_sing_2","kanto_sing_3","kanto_hypnosis_2","kanto_disarming_voice_0","kanto_disarming_voice_1"]:
		assert_not_null(Fx.sheet(key),key)
func test_visuals_do_not_consume_combat_rng_or_affect_health():
	var w := fixture()
	var target := enemy(w,Vector2.RIGHT*40)
	var before := w.rng.state
	var hp: int=target.hp
	Effects.sing(w,w.player,w.player.position,Vector2.RIGHT,72.0)
	Effects.hypnosis(w,w.player,Vector2.RIGHT,72.0)
	Effects.voice_hit(w,target)
	assert_eq(w.rng.state,before)
	assert_eq(target.hp,hp)
	var notes := 0
	var aura := 0
	for f in w.fxs:
		if f.text.begins_with("kanto_sing_") and f.follow==null:notes+=1
		if f.caster_aura and f.follow==w.player:aura+=1
	assert_eq(notes,6)
	assert_eq(aura,7)
func test_sleep_moves_keep_front_cone_and_immunity_rules():
	for id in ["sing","hypnosis"]:
		var w := fixture()
		var front := enemy(w,Vector2.RIGHT*40)
		var back := enemy(w,Vector2.LEFT*40)
		var immune := enemy(w,Vector2(40,8))
		immune.insomnia=true
		var before: int=front.hp
		w._status_cone(w.player,MoveDB.get_move(id),Vector2.RIGHT)
		assert_gt(front.sleep_t,0.0,id)
		assert_eq(back.sleep_t,0.0,id)
		assert_eq(immune.sleep_t,0.0,id)
		assert_eq(front.hp,before)
func test_voice_layers_keep_one_hitbox_in_eight_directions():
	var p := Projectile.new()
	add_child_autofree(p)
	p.radius=5.0;p.range_full=96.0;p.range_left=96.0
	for row in 8:
		p.vel=Vector2.RIGHT.rotated(row*PI/4.0)*135
		p.age=0.13
		var layers := p.voice_layers()
		assert_eq(layers.size(),5)
		for layer in layers:
			assert_gt(float(layer.size),0.0)
			assert_lte(Vector2(layer.offset).dot(p.vel.normalized()),0.001)
		assert_eq(p.radius,5.0)
		assert_eq(p.range_left,96.0)
func test_disarming_voice_hits_once_despite_multiple_visual_bands():
	var w := fixture()
	var target := enemy(w,Vector2.RIGHT*60)
	var before: int=target.hp
	w.cast(w.player,"disarming_voice",Vector2.RIGHT,target.position)
	var move := MoveDB.get_move("disarming_voice")
	assert_eq(move.target_pattern, "fan")
	assert_eq(w.projectiles.size(), int(move.count))
	for shot in w.projectiles:
		assert_true(is_same(shot.hit, w.projectiles[0].hit), "The fan shares one cast and one hit per target")
	for i in 30:
		w._tick_status(1.0/60.0)
		w._step_projectiles(1.0/60.0)
	assert_lt(target.hp,before)
	var after: int=target.hp
	for i in 30:
		w._tick_status(1.0/60.0)
		w._step_projectiles(1.0/60.0)
	assert_eq(target.hp,after)
	var impacts := 0
	for f in w.fxs:
		if f.text=="kanto_disarming_voice_0":impacts+=1
	assert_eq(impacts,1)
func test_sing_combines_purple_notes_with_three_aimed_wave_fronts():
	var w := fixture()
	Effects.sing(w,w.player,w.player.position,Vector2.RIGHT,72)
	var waves := 0
	var notes := 0
	for f in w.fxs:
		if f.aimed_wave:
			waves+=1
			assert_eq(f.text,"g4_ring_q")
			assert_eq(f.dir,Vector2.RIGHT)
			assert_gt(f.color.b,f.color.r)
			assert_gt(f.color.r,f.color.g)
		elif f.text.begins_with("kanto_sing_"):
			notes+=1
			assert_gt(f.color.b,f.color.r)
	assert_eq(waves,3);assert_eq(notes,6)
func test_voice_notes_stay_upright_while_rings_face_eight_aim_directions():
	var view := View3D.new();view.set_process(false);add_child_autofree(view)
	view.root3d=Node3D.new();view.add_child(view.root3d)
	view.cam=Camera3D.new();view.root3d.add_child(view.cam)
	view.cam.rotation_degrees=Vector3(-40,35,0)
	var p := Projectile.new();add_child_autofree(p)
	p.style="voice";p.radius=5;p.age=0.15;p.position=Vector2(100,100)
	var original := Sprite3D.new();view.root3d.add_child(original)
	var ent := {"sprite":original}
	for row in 8:
		p.vel=Vector2.RIGHT.rotated(row*PI/4.0)*135
		view._sync_layered_projectile(p,ent)
		var layers := p.voice_layers()
		var rings := 0
		var notes := 0
		for i in layers.size():
			var layer: Dictionary=layers[i]
			var sprite: Sprite3D=ent["voice_%d"%i]
			assert_eq(sprite.billboard,BaseMaterial3D.BILLBOARD_DISABLED)
			assert_eq(sprite.texture,Fx.sheet(layer.texture))
			assert_false(sprite.no_depth_test)
			if layer.aimed:
				rings+=1
				var vector := View3D.to3d(p.position+p.vel.normalized(),0)-View3D.to3d(p.position,0)
				var expected := Vector2(vector.dot(view.cam.global_basis.x),vector.dot(view.cam.global_basis.y)).normalized()
				var up := sprite.basis.y.normalized()
				var actual := Vector2(up.dot(view.cam.global_basis.x),up.dot(view.cam.global_basis.y)).normalized()
				assert_gt(actual.dot(expected),0.999)
			else:
				notes+=1
				assert_gt(sprite.basis.y.normalized().dot(view.cam.global_basis.y),0.99,"Notes remain upright")
		assert_eq(rings,2);assert_eq(notes,3)
func test_sing_wave_projection_matches_its_travel_in_eight_directions():
	var w := fixture()
	var view := View3D.new();view.set_process(false);add_child_autofree(view)
	view.cam=Camera3D.new();view.add_child(view.cam)
	view.cam.rotation_degrees=Vector3(-40,35,0)
	for row in 8:
		var dir := Vector2.RIGHT.rotated(row*PI/4.0)
		var f := w.add_fx("sprite",Vector2(100,100),{"text":"g4_ring_q","aimed_wave":true,"dir":dir,"size":16.0,"stretch":0.5,"lifetime":0.5})
		var state := view._fx_sprite_state(f,Fx.sheet(f.text))
		var vector := View3D.to3d(f.position+dir,0)-View3D.to3d(f.position,0)
		var expected := Vector2(vector.dot(view.cam.global_basis.x),vector.dot(view.cam.global_basis.y)).normalized()
		var basis: Basis=state.basis
		var up := basis.y.normalized()
		var actual := Vector2(up.dot(view.cam.global_basis.x),up.dot(view.cam.global_basis.y)).normalized()
		assert_gt(expected.dot(actual),0.999)
func test_hypnosis_is_a_source_bound_blue_and_lavender_aura():
	var w := fixture()
	var source := enemy(w,Vector2.RIGHT*40)
	Effects.hypnosis(w,source,Vector2.LEFT,72.0)
	var rings := 0
	var crescents := 0
	for f in w.fxs:
		assert_true(f.caster_aura)
		assert_true(f.body_impact)
		assert_eq(f.follow,source)
		assert_eq(f.speed,0.0,"No eye beams sent across the arena")
		if f.text=="g4_ring_q":
			rings+=1
			assert_gt(f.color.b,f.color.g)
			assert_gt(f.color.g,f.color.r)
		elif f.text=="g4_vine_arc":
			crescents+=1
			assert_gt(f.color.b,f.color.r)
			assert_gt(f.orbit_r,0.0)
	assert_eq(rings,3);assert_eq(crescents,4)
func test_hypnosis_aura_follows_varied_bodies_and_stays_local():
	for species in ["poliwag","poliwhirl","psyduck","onix"]:
		var w := fixture()
		var source := enemy(w,Vector2.RIGHT*40)
		source.setup_enemy(species,20,w.rng)
		Effects.hypnosis(w,source,Vector2.RIGHT,72)
		source.position+=Vector2(28,13)
		for f in w.fxs:
			f.step(0.2)
			assert_lte(f.position.distance_to(source.position),source.radius*1.7)
			if f.orbit_r<=0.0:assert_eq(f.position,source.position+f.offset)
			assert_false(f.dead)
func test_hypnosis_aura_ends_when_source_faints_or_is_freed():
	for freed in [false,true]:
		var w := fixture()
		var source := enemy(w,Vector2.RIGHT*40)
		Effects.hypnosis(w,source,Vector2.LEFT,72)
		if freed:
			w.enemies.erase(source);source.free()
		else:source.dead=true
		for f in w.fxs:
			f.step(0.02)
			assert_true(f.dead)
