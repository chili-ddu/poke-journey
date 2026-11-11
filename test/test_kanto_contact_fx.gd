extends "res://test/test_kanto_voice_fx.gd"

const CASES := [["pound","clefairy"],["pound","poliwag"],["pound","poliwhirl"],["peck","spearow"],["peck","nidoran_m"],["peck","goldeen"],["astonish","zubat"],["wrap","ekans"]]
func caster(w: World,species: String) -> Enemy:
	var e := Enemy.new()
	e.setup_enemy(species,20,w.rng)
	e.team=0
	e.position=w.player.position+Vector2(0,100)
	w.add_child(e)
	return e
func test_native_contact_textures_and_no_combat_side_effects():
	var w := fixture()
	var target := enemy(w,Vector2.RIGHT*30)
	var before := w.rng.state
	var hp: int=target.hp
	for id in ["pound","peck","astonish"]:
		for index in 2:assert_not_null(Fx.sheet("kanto_%s_%d"%[id,index]))
		Effects.contact_hit(w,target,id,Vector2.RIGHT)
	assert_eq(w.rng.state,before)
	assert_eq(target.hp,hp)
func test_contact_step_and_held_pose_across_species_and_eight_directions():
	var w := fixture()
	for entry in CASES:
		var e := caster(w,entry[1])
		var m := MoveDB.get_move(entry[0])
		for row in 8:
			var dir := Vector2.RIGHT.rotated(row*PI/4.0)
			e.position=Arena.center()+Vector2(0,100)
			e.facing=dir
			w.cast(e,entry[0],dir,e.position+dir*80)
			e.play_attack(String(m.anim))
			assert_false(e.attack_lunge, str(entry))
			var impact := e.attack_contact_time
			assert_almost_eq(e.attack_sheet_time(impact+e.attack_contact_hold*0.5),impact,0.001,str(entry))
			assert_almost_eq(e.attack_sheet_time(impact+e.attack_contact_hold+0.05),impact+0.05,0.001)
			var origin := e.position
			var wait: float=e.glide.wait
			w._step_glide(e,wait)
			assert_almost_eq(e.position.distance_to(origin),0.0,0.001)
			var duration: float=e.glide.duration
			w._step_glide(e,duration*0.5)
			assert_gt(e.position.distance_to(origin),float(m.glide)*0.8,"Fast entry")
			w._step_glide(e,duration*0.5)
			assert_almost_eq(e.position.distance_to(origin),float(m.glide),0.01)
			assert_almost_eq(e.hop_t,0.0,0.001,"Grounded")
			w.pending_melee.clear()
func test_contact_damage_is_delayed_single_and_has_distinct_particles():
	for id in ["pound","peck","astonish"]:
		var w := fixture()
		var target := enemy(w,Vector2.RIGHT*30)
		target.max_hp=900;target.hp=900
		w.player.facing=Vector2.RIGHT
		w.cast(w.player,id,Vector2.RIGHT,target.position)
		w.player.play_attack(String(MoveDB.get_move(id).anim))
		var delay: float=w.pending_melee[0].t
		w._step_pending_melee(delay*0.5)
		assert_eq(target.hp,900,id+" anticipation")
		w._step_pending_melee(delay*0.5+0.001)
		assert_lt(target.hp,900,id)
		var after: int=target.hp
		w._step_pending_melee(1.0)
		assert_eq(target.hp,after,id+" one hit")
		var count := 0
		for f in w.fxs:
			if f.text.begins_with("kanto_"+id+"_"):count+=1
		assert_gt(count,0,id+" native impact")
func test_contact_miss_has_no_impact_or_camera_kick():
	var w := fixture()
	for id in ["pound","peck","astonish"]:
		w.cast(w.player,id,Vector2.RIGHT,w.player.position+Vector2.RIGHT*80)
		w._step_pending_melee(1.0)
		assert_eq(w.fxs.size(),0)
		assert_eq(w.impact_camera_t,0.0)
func test_contact_step_stops_at_body_and_expires():
	var w := fixture()
	var target := enemy(w,Vector2.RIGHT*(w.player.radius+8))
	for id in ["pound","peck","astonish"]:
		var origin := w.player.position
		var gap := maxf(0.0,origin.distance_to(target.position)-w.player.radius-target.radius-.01)
		w.cast(w.player,id,Vector2.RIGHT,target.position)
		for i in 60:
			if not w.player.glide.is_empty():w._step_glide(w.player,1.0/60.0)
		assert_true(w.player.glide.is_empty())
		assert_almost_eq(w.player.position.distance_to(origin),gap,0.01,"Approach only the remaining gap")
		assert_lt(w.player.position.x,target.position.x)
		assert_gte(w.player.position.distance_to(target.position),w.player.radius+target.radius-.001)
		var stopped := w.player.position
		w._move_mons(1.0/60.0)
		assert_eq(w.player.position,stopped,"Expired contact step cannot keep drifting")
func test_contact_hold_resets_for_next_move():
	var w := fixture()
	w.cast(w.player,"pound",Vector2.RIGHT,w.player.position+Vector2.RIGHT*80)
	assert_gt(w.player.attack_contact_hold,0.0)
	w.cast(w.player,"ember",Vector2.RIGHT,w.player.position+Vector2.RIGHT*80)
	assert_eq(w.player.attack_contact_hold,0.0)
	assert_almost_eq(w.player.attack_sheet_time(0.2),0.2,0.001)
func test_contact_impact_uses_rendered_body_and_keeps_depth_testing():
	var w := fixture()
	var target := enemy(w,Vector2.RIGHT*30)
	var view := View3D.new()
	view.set_process(false)
	add_child_autofree(view)
	view.cam=Camera3D.new()
	view.add_child(view.cam)
	var body := Sprite3D.new()
	view.add_child(body)
	body.position=Vector3(7,2,4)
	view._sprites[target.get_instance_id()]={"sprite":body}
	Effects.contact_hit(w,target,"astonish",Vector2.RIGHT)
	for f in w.fxs:
		if not f.body_impact:continue
		var state := view._fx_sprite_state(f,Fx.sheet(f.text))
		var expected: Vector3 = body.position+view.cam.basis.x*f.offset.x/Arena.TILE+view.cam.basis.y*(target.feet_offset()-f.offset.y)/Arena.TILE+view.cam.basis.z*0.025
		assert_lt(Vector3(state.position).distance_to(expected),0.001)
		assert_eq(f.follow,target)
