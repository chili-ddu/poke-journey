extends GutTest
const Ribbon = preload("res://scripts/battle/wrap_fx.gd")
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
	w.player.max_hp=160;w.player.hp=160
	return w
func source(w: World) -> Enemy:
	var e := Enemy.new()
	e.setup_enemy("ekans",20,w.rng)
	e.position=w.player.position+Vector2.RIGHT*24
	e.frozen=true
	w.add_child(e);w.enemies.append(e)
	return e
func bind(w: World,e: Mon) -> Fx:
	var hit := w.make_hit(e,"wrap")
	w._apply_extra_status(w.player,hit)
	for f in w.fxs:
		if f.kind=="wrap":return f
	return null
func test_native_wrap_mask_loads_and_ribbon_winds_in():
	assert_not_null(Fx.sheet("kanto_wrap_0"))
	assert_not_null(Fx.sheet("kanto_wrap_soft"))
	assert_eq(Ribbon.ribbon(0,8,3,0).size(),0)
	assert_gt(Ribbon.ribbon(0.15,8,3,0).size(),0)
	assert_lt(Ribbon.ribbon(0.15,8,3,0).size(),60)
	assert_eq(Ribbon.ribbon(0.31,8,3,0.3).size(),60)
func test_ribbon_has_front_back_depth_and_tightens_on_damage_tick():
	for radius in [5.0,8.0,18.0,26.0]:
		var rest := Ribbon.ribbon(1.0,radius,3.0,0.7)
		var pulse := Ribbon.ribbon(1.0,radius,3.0,0.0)
		var front := 0
		var back := 0
		var max_rest := 0.0
		var max_pulse := 0.0
		for i in rest.size():
			var a: Vector3=rest[i].a
			assert_true(a.is_finite())
			max_rest=maxf(max_rest,absf(a.x))
			max_pulse=maxf(max_pulse,absf(Vector3(pulse[i].a).x))
			if rest[i].front:front+=1
			else:back+=1
		assert_gt(front,0);assert_gt(back,0)
		assert_lt(max_pulse,max_rest)
		assert_gt(float(pulse[0].width),float(rest[0].width))
func test_wrap_keeps_existing_duration_and_residual_damage():
	var w := fixture()
	var e := source(w)
	var f := bind(w,e)
	assert_not_null(f)
	assert_between(w.player.bind_t,2.0*Mon.TURN,5.0*Mon.TURN)
	var hp: int=w.player.hp
	w._tick_status(Mon.TURN)
	assert_eq(hp-w.player.hp,160/Mon.BIND_DIV)
	assert_true(f.binding_live())
func test_ribbon_follows_motion_without_rng_or_health_changes():
	var w := fixture()
	var e := source(w)
	var f := bind(w,e)
	var state := w.rng.state
	var hp: int=w.player.hp
	w.player.position+=Vector2(35,17)
	f.step(0.4)
	assert_eq(f.position,w.player.position+f.offset)
	assert_eq(f.binding_ribbon().size(),60)
	assert_eq(w.rng.state,state)
	assert_eq(w.player.hp,hp)
func test_repeated_bind_does_not_stack_or_reset_duration():
	var w := fixture()
	var e := source(w)
	bind(w,e)
	w.player.bind_t=1.2
	w._apply_extra_status(w.player,w.make_hit(e,"wrap"))
	var count := 0
	for f in w.fxs:
		if f.kind=="wrap":count+=1
	assert_eq(count,1)
	assert_eq(w.player.bind_t,1.2)
func test_ribbon_ends_when_binding_caster_or_target_is_gone():
	for cause in ["expiry","caster_faint","caster_freed","target_faint"]:
		var w := fixture()
		var e := source(w)
		var f := bind(w,e)
		match cause:
			"expiry":w.player.bind_t=0.0
			"caster_faint":e.dead=true
			"caster_freed":w.enemies.erase(e);e.free()
			"target_faint":w.player.dead=true
		f.step(0.01)
		assert_true(f.dead,cause)
		assert_eq(f.binding_ribbon().size(),0,cause)
func test_ribbon_uses_live_binding_time_when_hitstop_pauses_target():
	var w := fixture()
	var e := source(w)
	var f := bind(w,e)
	w.player.hitstop_t=0.1
	var remaining: float=w.player.bind_t
	w._tick_status(0.05)
	assert_eq(w.player.bind_t,remaining)
	f.step(f.lifetime+0.1)
	assert_false(f.dead,"Cosmetic elapsed time must not end a live binding")
	assert_true(f.binding_live())
func test_protected_or_out_of_range_target_has_no_wrap_ribbon():
	var w := fixture()
	var e := source(w)
	w.player.protect_t=1.0
	var hp: int=w.player.hp
	w.apply_hit(w.player,w.make_hit(e,"wrap"),e.position)
	assert_eq(w.player.hp,hp)
	assert_eq(w.player.bind_t,0.0)
	w.player.protect_t=0.0
	e.position=w.player.position+Vector2.RIGHT*150
	w.cast(e,"wrap",Vector2.LEFT,w.player.position)
	w._step_pending_melee(1.0)
	assert_eq(w.player.bind_t,0.0)
	for f in w.fxs:assert_ne(f.kind,"wrap")
func test_wrap_needs_close_contact_and_does_not_throw_target_away():
	var w := fixture()
	var e := source(w)
	var m := MoveDB.get_move("wrap")
	# Barely beyond the new contact gap: the old one-tile arc used to hit here.
	e.position=w.player.position+Vector2.RIGHT*(e.radius+w.player.radius+5.0)
	var before: int=w.player.hp
	var hit := w.make_hit(e,"wrap")
	w._melee_arc(e,m,hit,Vector2.LEFT)
	assert_eq(w.player.hp,before)
	assert_eq(w.player.bind_t,0.0)
	# Within the body-contact gap: repeated deterministic attempts account for
	# ordinary accuracy while retaining the production damage/status path.
	e.position=w.player.position+Vector2.RIGHT*(e.radius+w.player.radius+3.0)
	for i in 10:
		w.player.invuln_t=0.0
		w._melee_arc(e,m,hit,Vector2.LEFT)
		if w.player.bind_t>0.0:break
	assert_lt(w.player.hp,before)
	assert_gt(w.player.bind_t,0.0)
	assert_eq(w.player.knock,Vector2.ZERO)
	assert_eq(w.projectiles.size(),0)
func test_wrap_advances_to_body_contact_without_overshoot():
	var w := fixture()
	var e := source(w)
	for row in 8:
		var dir := Vector2.RIGHT.rotated(row*PI/4.0)
		e.position=w.player.position-dir*(e.radius+w.player.radius+3.0)
		e.facing=dir
		var origin := e.position
		w.cast(e,"wrap",dir,w.player.position)
		e.play_attack("Attack")
		w._step_glide(e,float(e.glide.wait)+float(e.glide.duration))
		assert_almost_eq(e.position.distance_to(origin),2.99,0.02)
		assert_gte(e.position.distance_to(w.player.position),e.radius+w.player.radius)
		assert_true(e.glide.is_empty())
		assert_false(e.attack_lunge)
		w.pending_melee.clear()
