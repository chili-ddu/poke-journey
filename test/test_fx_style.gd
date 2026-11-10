extends GutTest

# 기술 연출 모드(FxStyle, 사용자 요청 2026-11-02): 커스텀은 그림 키만 바꾸고 판정·위력·타이밍은 원작 모드와 같아야 한다.

const VISUAL := ["fx", "hit_fx"]

class Idle:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position + Vector2.RIGHT * 30.0
	func want_dodge(_w) -> bool: return false
	func want_skill(_i, _w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

class OneSkill:
	extends Idle
	var requested := true
	func want_skill(index, _w) -> bool:
		if index != 0 or not requested: return false
		requested = false
		return true

func after_each() -> void:
	FxStyle.set_mode(FxStyle.DEFAULT_MODE)

func test_custom_only_touches_visual_keys() -> void:
	for id in MoveShapes.CUSTOM_FX:
		for k in MoveShapes.CUSTOM_FX[id]:
			assert_true(k in VISUAL, "%s 의 커스텀 키 %s 는 그림 키여야 한다" % [id, k])
		FxStyle.set_mode("original")
		var orig := MoveDB.get_move(id).duplicate()
		FxStyle.set_mode("custom")
		var cust := MoveDB.get_move(id).duplicate()
		for k in orig:
			if k in VISUAL:
				continue
			assert_eq(cust.get(k), orig[k], "%s.%s 는 두 모드가 같다" % [id, k])

func test_switch_and_revert() -> void:
	FxStyle.set_mode("custom")
	assert_eq(MoveDB.get_move("scratch")["fx"], "claw_c")
	assert_eq(MoveDB.get_move("ember")["fx"], "ember_c")
	assert_eq(MoveDB.get_move("smoke_screen")["fx"], "smoke_c")
	assert_true(FxStyle.custom("ember"))
	assert_false(FxStyle.custom("tackle"), "커스텀이 없는 기술은 원작 그대로")
	FxStyle.set_mode("original")
	assert_eq(MoveDB.get_move("scratch")["fx"], "claw", "원작으로 돌아간다")
	assert_eq(MoveDB.get_move("ember")["fx"], "ember")
	assert_eq(MoveDB.get_move("smoke_screen")["fx"], "smoke")
	assert_false(FxStyle.custom("ember"))

func _world() -> World:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var w := World.new()
	add_child_autofree(w)
	w.setup(7, "charmander", 12, ["scratch", "ember"], Idle.new())
	w.player.position = Arena.center()
	return w

func _foe(w: World, off: Vector2) -> Enemy:
	var e := Enemy.new()
	e.setup_enemy("caterpie", 5, w.rng)
	e.max_hp = 900
	e.hp = 900
	e.position = w.player.position + off
	e.frozen = true
	w.add_child(e)
	w.enemies.append(e)
	return e

func _run(w: World, sec: float) -> void:
	var t := 0.0
	while t < sec:
		w.step(1.0 / 60.0)
		t += 1.0 / 60.0

func test_custom_moves_work_in_world() -> void:
	for mode in ["original", "custom"]:
		FxStyle.set_mode(mode)
		var w := _world()
		var e := _foe(w, Vector2(24, 0))
		w.cast(w.player, "scratch", Vector2.RIGHT, e.position)
		_run(w, 0.5)
		assert_lt(e.hp, 900, mode + ": 할퀴기 맞음")
		e.position = w.player.position + Vector2(50, 0)
		e.knock = Vector2.ZERO                         # 할퀴기에 밀려나던 기세를 지우고(안 지우면 불꽃세례가 따라잡지 못한다)
		var hp := e.hp
		w.cast(w.player, "ember", Vector2.RIGHT, e.position)
		_run(w, 0.8)
		assert_lt(e.hp, hp, mode + ": 불꽃세례 맞음")
		e.position = w.player.position + Vector2(60, 0)
		e.knock = Vector2.ZERO
		w.cast(w.player, "smoke_screen", Vector2.RIGHT, e.position)
		_run(w, 1.0)
		assert_eq(e.acc_stage, -1, mode + ": 연막 명중 −1")
		# 헛친 불꽃세례(사거리 끝)도 문제없이 사라진다
		w.cast(w.player, "ember", Vector2.LEFT, w.player.position + Vector2(-90, 0))
		_run(w, 0.8)
		assert_eq(w.projectiles.filter(func(p): return not p.dead).size(), 0, mode + ": 투사체 정리")

func test_ember_dense_flames_share_one_damage_volley() -> void:
	FxStyle.set_mode("custom")
	var w := _world()
	w.cast(w.player,"ember",Vector2.RIGHT,w.player.position+Vector2.RIGHT*60)
	var emitted_at: Array = []
	var previous := 0
	for frame in 30:
		w._step_bursts(1.0/60)
		if w.projectiles.size()>previous:
			emitted_at.append(frame)
			previous=w.projectiles.size()
	assert_eq(w.projectiles.size(),7,"Seven distinct flames")
	assert_eq(emitted_at.size(),7,"Sequential emission, not one simultaneous flash")
	assert_lte(emitted_at[-1]-emitted_at[0],14,"Dense volley finishes within 0.24s at 60fps")
	var shapes := {}
	for flame in w.projectiles:
		shapes[str(flame.flame_aspect)] = true
		assert_eq(flame.radius,3.0,"Visual shape does not randomize collision radius")
	assert_gt(shapes.size(),1,"Flames have distinct silhouettes")
	var e := _foe(w,Vector2(50,0))
	w.apply_hit(e,w.projectiles[0].hit,w.player.position)
	var after_first := e.hp
	assert_lt(after_first,900)
	for p in w.projectiles:
		assert_eq(p.hit["volley"],w.projectiles[0].hit["volley"])
		assert_eq(p.emitter.get_ref(),w.player)
		w.apply_hit(e,p.hit,w.player.position)
	assert_eq(e.hp,after_first,"One target takes damage once per cast")

func test_ember_starts_small_and_blooms_without_changing_hit_radius() -> void:
	var p := Projectile.new()
	p.radius = 3.0
	p.range_full = 72.0
	p.grow = 1.6
	for phase in [0.0,1.5,3.5,5.5]:
		p.flame_phase = phase
		p.range_left = 72.0
		p.age = 0.0
		var start := p.flame_envelope()
		assert_almost_eq(start,0.22,0.001,"Small mouth spark in every phase")
		p.range_left = 36.0
		p.age = 0.24
		assert_gt(p.flame_envelope(),start*3.0,"Bloom in flight")
		var collision := p.hit_radius()
		p.age += 0.07
		p.flame_envelope()
		assert_eq(p.hit_radius(),collision,"Flicker never changes collision")
		for frame in 30:
			p.range_left = maxf(0.0,72.0-frame*2.5)
			p.age = frame/60.0
			assert_gt(p.flame_envelope(),0.0)
			assert_lt(p.flame_envelope(),1.21,"Avoid oversized flashes")
	p.free()

func test_ember_landing_spreads_laterally_then_expires() -> void:
	for direction in [Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT,Vector2.UP]:
		var w := _world()
		var origin := w.player.position
		w._ember_burn(origin,direction)
		var flames: Array = w.fxs.filter(func(f): return f.grounded_flame)
		assert_eq(flames.size(),5)
		assert_eq(w.zones.size(),0,"No lingering damage zone")
		for flame in flames: flame.step(0.25)
		var left := 0
		var right := 0
		for flame in flames:
			var offset: Vector2 = flame.position-origin
			var lateral := offset.dot(direction.orthogonal())
			if lateral < -0.1: left += 1
			if lateral > 0.1: right += 1
			assert_lt(absf(offset.dot(direction)),2.0,"Mostly lateral motion")
		assert_eq(left,2)
		assert_eq(right,2)
		for flame in flames:
			flame.step(1.0)
			assert_true(flame.dead,"Flare expires")

func test_ember_misses_share_one_landing_flare() -> void:
	var w := _world()
	FxStyle.set_mode("custom")
	w.cast(w.player,"ember",Vector2.RIGHT,w.player.position+Vector2.RIGHT*60)
	for frame in 30: w._step_bursts(1.0/60)
	for p in w.projectiles: w._projectile_fizzle(p)
	assert_eq(w.fxs.filter(func(f): return f.grounded_flame).size(),5,"Seven misses do not create 35 flames")
	assert_eq(w.zones.size(),0)

class EmberMovingInput:
	extends Idle
	var aim := Vector2.RIGHT
	func move_dir(_w) -> Vector2: return Vector2.DOWN
	func aim_point(w) -> Vector2: return w.player.position+aim*100
	func want_skill(i,_w) -> bool: return i==1

func test_ember_moving_recast_keeps_face_with_each_volley() -> void:
	var w := _world()
	var input := EmberMovingInput.new()
	w.player.controller = input
	var seen := {}
	var volleys := {}
	var wrong_face := 0
	var start := w.player.position
	for frame in 180:
		w.step(1.0/60)
		for p in w.projectiles:
			if seen.has(p.get_instance_id()): continue
			seen[p.get_instance_id()] = true
			var id: int = p.hit.get("volley",0)
			if not volleys.has(id): volleys[id] = []
			volleys[id].append(p.vel.normalized())
			if w.player.facing.dot(p.vel.normalized())<0.98: wrong_face += 1
			input.aim = Vector2.UP # Turn after first emitted flame, while moving.
	assert_eq(wrong_face,0,"Mouth faces the current volley even after aim changes")
	assert_gte(volleys.size(),2,"Held input recasts through normal cooldown/PP path")
	var ids := volleys.keys()
	if ids.size()>=2:
		assert_eq(volleys[ids[0]].size(),7)
		assert_eq(volleys[ids[1]].size(),7)
		for d in volleys[ids[0]]: assert_gt(d.dot(Vector2.RIGHT),0.98)
		for d in volleys[ids[1]]: assert_gt(d.dot(Vector2.UP),0.98)
	assert_gt(w.player.position.distance_to(start),2.0,"Player actually moves while firing")

func test_ember_wall_flare_stays_on_open_ground() -> void:
	var w := _world()
	FxStyle.set_mode("custom")
	var edge := Arena.RECT.position.x
	var p := Projectile.new()
	p.position = Vector2(edge+0.5, Arena.center().y)
	p.vel = Vector2.LEFT*150
	p.style = "ember_c"
	p.radius = 3.0
	p.range_full = 72.0
	p.range_left = 72.0
	w.add_child(p)
	w.projectiles.append(p)
	w._step_projectiles(1.0/60)
	assert_true(p.dead, "Projectile stops at the wall")
	var flames := 0
	for f in w.fxs:
		if not f.grounded_flame: continue
		flames += 1
		assert_false(Arena.blocks(f.position,0), "Landing starts outside the wall")
		for frame in 45:
			f.step(1.0/60)
			assert_false(Arena.blocks(f.position,0), "Spreading flame stays outside the wall")
	assert_eq(flames,5,"One complete landing flare")

func test_scratch_custom_cut_follows_attacker_on_hit_and_miss() -> void:
	FxStyle.set_mode("custom")
	var w := _world()
	var target := _foe(w, Vector2.RIGHT*30)
	var hp := target.hp
	w.cast(w.player, "scratch", Vector2.RIGHT, target.position)
	var cut: Fx = w.fxs.filter(func(f): return f.kind == "forward_cut")[0]
	assert_eq(cut.follow, w.player)
	assert_eq(cut.dir, Vector2.RIGHT)
	assert_eq(target.hp, hp)
	_run(w, cut.cut_delay + 1.0/60)
	assert_lt(target.hp, hp)
	assert_true(w.fxs.filter(func(f): return f.text == "g4_streak").is_empty())
	_run(w, 0.6)
	assert_true(w.fxs.filter(func(f): return f.kind == "forward_cut").is_empty())
	target.position = w.player.position + Vector2.RIGHT*200
	hp = target.hp
	w.cast(w.player, "scratch", Vector2.LEFT, w.player.position + Vector2.LEFT*30)
	var miss: Fx = w.fxs.filter(func(f): return f.kind == "forward_cut")[0]
	assert_eq(miss.dir, Vector2.LEFT)
	_run(w, miss.cut_delay + 1.0/60)
	assert_eq(target.hp, hp)
	assert_true(w.fxs.filter(func(f): return f.text in ["g4_streak","g4_hitburst"]).is_empty())

func test_smoke_cloud_expands_and_clears_edges_first() -> void:
	var w := _world()
	var at := w.player.position
	var radius := 36.0
	w._smoke_cloud_custom(at,radius,w.player.radius)
	var clouds := w.fxs.filter(func(f): return f.text=="g4_smoke")
	assert_eq(clouds.size(),15)
	assert_eq(w.zones.size(),0,"Cloud visuals add no persistent gameplay zone")
	for frame in 48:
		for f in clouds: f.step(1.0/60)
	var outer_dead := 0
	var inner_alive := 0
	for f in clouds:
		if f.delay>0.1:
			if f.dead: outer_dead+=1
			assert_gt(f.position.distance_to(at),radius*0.5,"Outer wisps expand outward")
		elif not f.dead: inner_alive+=1
	assert_eq(outer_dead,8,"Outer ring clears before center and inner ring")
	assert_eq(inner_alive,7)
	for f in clouds:
		f.step(0.3)
		assert_true(f.dead,"Cloud finishes within 1.1 seconds")

func test_smoke_body_shade_is_local_bounded_and_temporary() -> void:
	var w := _world()
	var at := w.player.position
	w._smoke_cloud_custom(at,36.0,w.player.radius)
	assert_eq(w.smoke_body_shade(at),0.0,"No veil before smoke appears")
	for f in w.fxs: f.step(0.2)
	var shade := w.smoke_body_shade(at)
	assert_gt(shade,0.1,"Visible smoke dims the body")
	assert_lte(shade,0.32,"Body retains at least 68 percent brightness")
	assert_eq(w.smoke_body_shade(at+Vector2(200,0)),0.0,"Leaving smoke restores brightness")
	w._smoke_cloud_custom(at,36.0,w.player.radius)
	for f in w.fxs: f.step(0.2)
	assert_lte(w.smoke_body_shade(at),0.32,"Overlapping clouds cannot black out the body")
	for f in w.fxs: f.step(1.1)
	assert_eq(w.smoke_body_shade(at),0.0,"Brightness restores as smoke disappears")

func test_growl_custom_marks_only_successful_attack_drop() -> void:
	for mode in ["original","custom"]:
		var w := _world()
		FxStyle.set_mode(mode)
		var front := _foe(w,Vector2.RIGHT*30)
		var behind := _foe(w,Vector2.LEFT*30)
		var protected := _foe(w,Vector2(35,5))
		protected.protect_t=1.0
		var minimum := _foe(w,Vector2(35,-5))
		minimum.atk_stage=-6
		w.cast(w.player,"growl",Vector2.RIGHT,front.position)
		assert_eq(front.atk_stage,-1)
		assert_eq(behind.atk_stage,0)
		assert_eq(protected.atk_stage,0)
		assert_eq(minimum.atk_stage,-6)
		var marks := w.fxs.filter(func(f): return f.text=="g4_streak" and not f.sound_fracture)
		assert_eq(marks.size(),2 if mode=="custom" else 0)
		for f in marks: assert_eq(f.follow,front)
		var waves := w.fxs.filter(func(f): return f.sound_fracture if mode=="custom" else f.text=="g4_ring")
		assert_eq(waves.size(),30 if mode=="custom" else 3)
		if mode=="custom": assert_true(w.fxs.filter(func(f): return f.text=="g4_ring").is_empty(),"Custom sound has no circular rings")
		if mode=="custom":
			for f in waves: assert_almost_eq(f.lifetime-f.delay,0.34,0.001,"Every wave has equal travel time")

func test_sound_fractures_stop_at_wall() -> void:
	var w := _world()
	var f := w.add_fx("sprite",Vector2(Arena.RECT.position.x+1,Arena.center().y),{
		"text":"g4_streak","sound_fracture":true,"dir":Vector2.LEFT,"speed":150.0})
	assert_false(View3D.sound_refraction_clear(f.position))
	assert_true(View3D.sound_refraction_clear(w.player.position))
	f.step(1.0/60)
	assert_true(f.dead,"Visual wave stops at wall")

func test_status_prose_goes_to_dialogue_signal_but_numbers_float() -> void:
	var w := _world()
	var messages: Array[String] = []
	w.status_message.connect(func(message): messages.append(message))
	w.float_text(w.player.position,"공격력이 떨어졌다!",Color.WHITE,7)
	w.float_text(w.player.position,"효과가 없다!",Color.WHITE,7)
	w.float_text(w.player.position,"12",Color.WHITE,8)
	w.float_text(w.player.position,"+5",Color.WHITE,8)
	assert_eq(messages.size(),2)
	assert_eq(messages[0],"공격력이 떨어졌다!")
	var texts := w.fxs.filter(func(f): return f.kind=="text")
	assert_eq(texts.size(),2)
	for f in texts: assert_true(f.text.is_valid_int())

func test_status_dialogue_waits_for_story_and_preserves_order() -> void:
	var game = load("res://scripts/game.gd").new()
	game.state="talk"
	game.dialog_text="진행 중인 대화"
	game._queue_status_message("첫 상태")
	game._queue_status_message("다음 상태")
	assert_eq(game.dialog_text,"진행 중인 대화")
	game.state="fight"
	game.dialog_text=""
	game._show_next_status_message()
	assert_eq(game.dialog_text,"다음 상태","Latest event replaces the backlog")
	game._advance_timed_message()
	assert_true(game.dialog_text.is_empty())
	game.free()

func test_rank_overlay_covers_all_stats_and_expires() -> void:
	var w := _world()
	var overlay := w.player.stat_overlay
	for stat in ["atk","def","spa","spd","spe","acc","eva"]:
		for suffix in ["_up","_down"]:
			w.player.play_stat(stat+suffix)
			assert_not_null(overlay.pattern,stat+suffix)
			assert_eq(overlay.up,suffix=="_up")
			assert_eq(overlay.rank_strength(),0.0)
			overlay.step(0.4)
			assert_almost_eq(overlay.rank_strength(),StatOverlay.PEAK,0.001)
			overlay.step(0.7)
			assert_eq(overlay.rank_strength(),0.0)

func test_multi_target_rank_dialogue_keeps_each_original_sentence() -> void:
	var w := _world()
	var game = load("res://scripts/game.gd").new()
	game.state="fight"
	var emitted: Array = []
	w.status_message.connect(func(text): emitted.append(text))
	w.status_message.connect(game._queue_status_message)
	var first := _foe(w,Vector2(30,0))
	var second := _foe(w,Vector2(32,5))
	var third := _foe(w,Vector2(34,-5))
	third.trainer_owned=true
	w.cast(w.player,"growl",Vector2.RIGHT,first.position)
	assert_eq(emitted.size(),3)
	var expected := []
	for target in [first,second,third]:
		expected.append(Lang.t("stat_fell",[w._rank_subject(target,"atk")]))
	assert_eq(emitted,expected)
	assert_eq(game.dialog_text,expected.back())
	assert_true(game.status_messages.is_empty())
	game.free()

func test_sv_rank_messages_use_actual_change_and_limits() -> void:
	var old_language := Lang.code
	Lang.set_code("ko",false)
	var w := _world()
	var target := _foe(w,Vector2.RIGHT*30)
	var messages: Array[String] = []
	w.status_message.connect(func(message): messages.append(message))
	var subject := "야생 "+target.display_name()+"의\n공격"
	w._apply_stat(target,{"atk":3},false)
	assert_eq(messages.pop_back(),subject+"이 매우 크게 올라갔다!")
	target.atk_stage=5
	w._apply_stat(target,{"atk":2},false)
	assert_eq(messages.pop_back(),subject+"이 올라갔다!","Clipped +2 is really +1")
	w._apply_stat(target,{"atk":1},false)
	assert_eq(messages.pop_back(),subject+"은 더 올라가지 않는다!")
	target.atk_stage=-6
	w._apply_stat(target,{"atk":-1},false)
	assert_eq(messages.pop_back(),subject+"은 더 떨어지지 않는다!")
	Lang.set_code(old_language,false)

func test_sv_status_events_notify_once_and_recover() -> void:
	var w := _world()
	var messages: Array[String] = []
	w.status_message.connect(func(message): messages.append(message))
	var old_poison := Mon.poison_unlocked
	var old_burn := Mon.burn_unlocked
	Mon.poison_unlocked=true
	Mon.burn_unlocked=true
	for kind in ["poison","burn"]:
		messages.clear()
		w._inflict_status(w.player,kind)
		assert_eq(messages.size(),1,"New status has one notification")
		w._inflict_status(w.player,kind)
		assert_eq(messages.size(),1,"Existing status is not announced again")
		w._cure(kind)
		assert_eq(messages.size(),2,"Cure notifies once")
		w._cure(kind)
		assert_eq(messages.size(),2,"No cure message when already healthy")
	messages.clear()
	w.player.sleep_t=0.01
	w.player.confuse_t=0.01
	w._tick_status(0.02)
	assert_eq(messages.size(),2,"Wake and confusion ending both notify")
	w._tick_status(0.02)
	assert_eq(messages.size(),2,"Expiry messages do not repeat")
	Mon.poison_unlocked=old_poison
	Mon.burn_unlocked=old_burn

func test_sv_blocked_hits_keep_each_target_and_volley_notice() -> void:
	var w := _world()
	var a := _foe(w, Vector2(30, 0))
	var b := _foe(w, Vector2(35, 0))
	b.trainer_owned = true
	a.protect_t = 1.0
	b.protect_t = 1.0
	var messages: Array[String] = []
	w.status_message.connect(func(message): messages.append(message))
	var hit := w.make_hit(w.player, "ember")
	hit["volley"] = 501
	w._text_cd = 1.0
	for target in [a,b,a,b]:
		w.apply_hit(target, hit, w.player.position)
	assert_eq(messages.size(), 2, "One protected result per target in the same volley")
	assert_eq(messages[0], Lang.t("protected", [w._battle_name(a)]))
	assert_eq(messages[1], Lang.t("protected", [w._battle_name(b)]))
	assert_eq(a.hp, 900)
	assert_eq(b.hp, 900)
	w.cast(w.player, "growl", Vector2.RIGHT, a.position)
	assert_eq(messages.size(), 4, "A separate status move announces both blocked targets")

func test_sv_miss_and_immunity_results() -> void:
	var old_language := Lang.code
	Lang.set_code("en", false)
	var w := _world()
	var target := _foe(w, Vector2(30, 0))
	var messages: Array[String] = []
	w.status_message.connect(func(message): messages.append(message))
	var hit := w.make_hit(w.player, "scratch")
	hit["type"] = "electric"
	target.species_id = "geodude"
	hit["crit"] = 1.0
	w.apply_hit(target, hit, w.player.position)
	assert_eq(messages[0], "It doesn’t affect the wild GEODUDE...", "Immunity is not overwritten by a critical-roll message")
	assert_eq(target.hp, 900)
	messages.clear()
	target.invuln_t = 0.0
	hit["team"] = Mon.TEAM_ENEMY
	hit["acc_stage"] = -6
	var seed_value := 0
	var probe := RandomNumberGenerator.new()
	while true:
		probe.seed = seed_value
		if probe.randf() > Mon.stage_acc(-6): break
		seed_value += 1
	w.rng.seed = seed_value
	w.apply_hit(target, hit, w.player.position)
	assert_eq(messages[0], "The wild GEODUDE avoided the attack!")
	assert_eq(target.hp, 900)
	Lang.set_code(old_language, false)

func test_sv_critical_and_effectiveness_dialogue_order() -> void:
	var old_language := Lang.code
	var w := _world()
	var game = load("res://scripts/game.gd").new()
	game.state = "fight"
	var emitted: Array = []
	w.status_message.connect(func(text): emitted.append(text))
	w.status_message.connect(game._queue_status_message)
	# Fire against bug, fire, and normal covers weakness, resistance, and neutral.
	for language in ["ko", "en"]:
		Lang.set_code(language, false)
		for species in ["caterpie", "charmander", "rattata"]:
			for critical in [false, true]:
				emitted.clear()
				game.dialog_text = ""
				var target := _foe(w, Vector2(30, 0))
				target.species_id = species
				var hit := w.make_hit(w.player, "ember")
				hit["crit"] = 1.0 if critical else 0.0
				hit["burn"] = 0.0
				w._text_cd = 1.0
				w.apply_hit(target, hit, w.player.position)
				var expected: Array[String] = []
				var subject := w._battle_object_name(target)
				if critical: expected.append(Lang.t("crit", [subject]))
				if species == "caterpie": expected.append(Lang.t("super_effective", [subject]))
				if species == "charmander": expected.append(Lang.t("not_very_effective", [subject]))
				assert_eq(emitted,expected,language+" "+species)
				assert_lt(target.hp,900)
				if not expected.is_empty(): assert_eq(game.dialog_text,expected.back())
				assert_true(game.status_messages.is_empty())
	game.free()
	Lang.set_code(old_language, false)

func test_sv_multi_target_critical_volley_keeps_both_results() -> void:
	var w := _world()
	var messages: Array[String] = []
	w.status_message.connect(func(message): messages.append(message))
	var a := _foe(w, Vector2(30, 0))
	var b := _foe(w, Vector2(35, 0))
	b.trainer_owned = true
	var hit := w.make_hit(w.player, "ember")
	hit["crit"] = 1.0
	hit["burn"] = 0.0
	hit["volley"] = 601
	for target in [a, b, a, b]:
		target.invuln_t = 0.0
		w.apply_hit(target, hit, w.player.position)
	var expected: Array[String] = []
	for target in [a, b]:
		expected.append(Lang.t("crit", [w._battle_object_name(target)]))
		expected.append(Lang.t("super_effective", [w._battle_object_name(target)]))
	assert_eq(messages, expected, "Each target keeps both messages; extra volley projectiles do not repeat them")

func test_sv_fixed_damage_does_not_claim_weakness_or_critical() -> void:
	var w := _world()
	var messages: Array[String] = []
	w.status_message.connect(func(message): messages.append(message))
	var target := _foe(w, Vector2(30, 0))
	var hit := w.make_hit(w.player, "ember")
	hit["fixed"] = 40
	hit["crit"] = 1.0
	hit["burn"] = 0.0
	w.apply_hit(target, hit, w.player.position)
	assert_eq(target.hp, 860)
	assert_true(messages.is_empty(), "Fixed damage does not use critical or weakness multipliers")

func test_sv_recovery_notifies_only_actual_healing_and_faint_once() -> void:
	var w := _world()
	var messages: Array[String] = []
	w.status_message.connect(func(message): messages.append(message))
	w.player.hp = w.player.max_hp - 3
	w.heal(w.player, 10)
	assert_eq(w.player.hp, w.player.max_hp)
	assert_eq(messages, [Lang.t("hp_restored", [w._battle_name(w.player)])])
	w.heal(w.player, 10)
	assert_eq(messages.size(), 1)
	w._faint(w.player)
	w._faint(w.player)
	assert_eq(messages.size(), 2)
	assert_eq(messages[1], Lang.t("fainted", [w._battle_name(w.player)]))

func test_end_screen_waits_for_last_dialogue_to_expire() -> void:
	for outcome in ["victory", "gameover"]:
		var w := _world()
		var game = load("res://scripts/game.gd").new()
		game.world = w
		game.panel = ChoicePanel.new()
		add_child_autofree(game.panel)
		game.bot = true
		game.state = "fight"
		game._queue_status_message("First outcome")
		game._queue_status_message("Fainted outcome")
		if outcome == "victory": game._win()
		else: game._on_player_fainted()
		game.advance(0.01)
		assert_eq(game.state, "fight")
		assert_eq(game.dialog_text, "Fainted outcome")
		game.advance(0.1)
		assert_eq(game.state, "fight", "The latest page still remains visible")
		assert_eq(game.dialog_text, "Fainted outcome")
		game.advance(game.SAY_TIME + 0.01)
		assert_eq(game.state, outcome)
		assert_true(game.status_messages.is_empty())
		assert_true(game.pending_battle_end.is_empty())
		game.free()

func test_trainer_faint_page_waits_for_attack_result() -> void:
	var w := _world()
	var game = load("res://scripts/game.gd").new()
	game.world = w
	game.state = "fight"
	game.battle = {"faint_t": 0.01, "faint_name": "TEST", "then": "done"}
	game._queue_status_message("Critical outcome")
	game._step_battle(1.0)
	assert_eq(game.state, "fight")
	game._show_next_status_message()
	game._step_battle(1.0)
	assert_eq(game.dialog_text, "Critical outcome")
	game.dialog_text = ""
	game._step_battle(1.0)
	assert_eq(game.state, "talk")
	assert_eq(game.dialog_text, Lang.t("foe_fainted", ["TEST"]))
	game.free()

func test_growth_pages_and_multiple_learns_finish_before_victory() -> void:
	var w := _world()
	var game = load("res://scripts/game.gd").new()
	game.world = w
	game.panel = ChoicePanel.new()
	add_child_autofree(game.panel)
	game.bot = true
	game.state = "fight"
	var foe := _foe(w, Vector2(30, 0))
	game._on_enemy_defeated(foe, 1)
	assert_eq(game.dialog_text, Lang.t("fainted", [w._battle_name(foe)]))
	assert_true(game.exp_display_pending())
	game.stat_queue.append({"level":12,"delta":{},"after":w.player.stats.duplicate()})
	game.pending_learns = ["protect", "solar_beam"]
	game._win()
	var seen: Array[String] = [game.dialog_text]
	for frame in 1200:
		game.advance(1.0/60)
		if not game.dialog_text.is_empty() and game.dialog_text != seen.back(): seen.append(game.dialog_text)
		if game.state=="victory": break
	assert_eq(seen,[Lang.t("fainted",[w._battle_name(foe)]),Lang.t("grew",[w.player.display_name(),12]),Lang.t("learned",[w.player.display_name(),MoveDB.move_name("protect")]),Lang.t("learned",[w.player.display_name(),MoveDB.move_name("solar_beam")])])
	assert_eq(game.state,"victory")
	assert_true(w.player.known_moves().has("protect"))
	assert_true(w.player.known_moves().has("solar_beam"))
	game.free()

func test_trainer_transition_waits_for_pending_growth() -> void:
	var w := _world()
	var game = load("res://scripts/game.gd").new()
	game.world = w
	game.state = "fight"
	game.battle = {"faint_t":0.0,"next_t":0.01,"done_t":0.0,"then":"next","exp_text":"EXP outcome"}
	game._after_foe_fainted()
	assert_true(game.status_messages.is_empty(), "Experience is shown only by the gauge")
	game.status_messages.clear()
	game.status_message_times.clear()
	game.pending_learns = ["protect"]
	var delay: float = game.battle["next_t"]
	game._step_battle(5.0)
	assert_eq(game.battle["next_t"], delay)
	game._open_next_menu()
	assert_eq(game.dialog_text, Lang.t("learned", [w.player.display_name(), MoveDB.move_name("protect")]))
	game._step_battle(5.0)
	assert_eq(game.battle["next_t"], delay, "Current learned page also holds the next opponent")
	game.free()

func test_multi_level_growth_announces_each_levels_moves_before_next_level() -> void:
	for species in ["charmander", "bulbasaur", "squirtle"]:
		var w := _world()
		w.player.setup_player(species, 12, [])
		w.player.hold = "everstone"
		var game = load("res://scripts/game.gd").new()
		game.world = w
		game.panel = ChoicePanel.new()
		add_child_autofree(game.panel)
		game.bot = true
		game.state = "fight"
		var foe := _foe(w, Vector2(30, 0))
		var amount := SpeciesDB.exp_for_level(20, SpeciesDB.growth_of(species)) - w.player.exp_total
		var expected: Array[String] = [Lang.t("fainted", [w._battle_name(foe)])]
		var known := w.player.known_moves()
		for level in range(13, 21):
			expected.append(Lang.t("grew", [w.player.display_name(), level]))
			for move in SpeciesDB.moves_at_level(species, level):
				if not known.has(move):
					known.append(move)
					expected.append(Lang.t("learned", [w.player.display_name(), MoveDB.move_name(move)]))
		game._on_enemy_defeated(foe, amount)
		assert_eq(w.player.level, 20)
		assert_eq(game.stat_queue.size(), 8)
		game._win()
		var seen: Array[String] = [game.dialog_text]
		for frame in 200:
			game.advance(10.0)
			if not game.dialog_text.is_empty(): seen.append(game.dialog_text)
			if game.state == "victory": break
		assert_eq(seen, expected, species + " learns each intermediate move after its own level page")
		assert_eq(w.player.known_moves(), known)
		assert_eq(game.state, "victory")
		assert_true(game.growth_learns.is_empty())
		game.free()

func test_experience_stops_at_level_100() -> void:
	var p := Player.new()
	add_child_autofree(p)
	p.setup_player("charmander", 98, ["scratch"])
	assert_eq(p.gain_exp(2000000000), 2)
	assert_eq(p.exp_total, SpeciesDB.exp_for_level(100, SpeciesDB.growth_of("charmander")))
	p.set_level(100)
	assert_eq(p.gain_exp(1000), 0)
	var before := p.exp_total
	assert_eq(p.gain_exp(-100), 0)
	assert_eq(p.exp_total, before)

func test_large_combat_queue_keeps_duplicates_and_auto_order() -> void:
	var w := _world()
	var game = load("res://scripts/game.gd").new()
	game.world = w
	game.panel = ChoicePanel.new()
	add_child_autofree(game.panel)
	game.bot = true
	game.state = "fight"
	var expected: Array[String] = []
	for i in 60:
		var message := "Target %d result" % (i % 6)
		expected.append(message)
		game._queue_status_message(message)
	game._win()
	game.advance(0.01)
	assert_eq(game.dialog_text,expected.back())
	game.advance(game.SAY_TIME+0.01)
	assert_true(game.status_messages.is_empty())
	assert_eq(game.dialog_text, "")
	assert_eq(game.state, "victory")
	game.free()

func test_story_interruption_restores_current_combat_notice() -> void:
	var w := _world()
	var game = load("res://scripts/game.gd").new()
	game.world = w
	game.state = "fight"
	game._queue_status_message("First combat notice")
	game._queue_status_message("Second combat notice")
	game._show_next_status_message()
	game._say_pages(["NPC page"])
	assert_eq(game.dialog_text, "NPC page")
	assert_eq(game.status_messages, ["Second combat notice"])
	game._talk_next()
	game._show_next_status_message()
	assert_eq(game.dialog_text, "Second combat notice")
	game.pending_battle_end = "victory"
	game.advance(0.1)
	assert_eq(game.dialog_text, "Second combat notice")
	game.free()

func test_message_height_and_position_remain_fixed_for_long_text() -> void:
	var game = load("res://scripts/game.gd").new()
	var hud := Hud.new()
	add_child_autofree(hud)
	hud.game = game
	hud.size = Vector2(512,288)
	for state in ["fight", "talk"]:
		game.state = state
		game.dialog_text = "Short"
		hud._layout()
		var expected := hud.msg_rect()
		var health := hud.PLAYER_BOX
		game.dialog_text = "Long battle message that wraps onto several lines. ".repeat(4)
		hud._layout()
		assert_eq(hud.msg_rect(), expected)
		assert_eq(hud.PLAYER_BOX, health)
	hud.game = null
	game.free()

func test_fixed_dialogue_pages_preserve_text_and_fit_two_lines() -> void:
	for text in ["상대 알로라 나인테일은\n라이트닝서프라이드를 배웠다!", "The opposing Alolan Ninetales learned\nTen Million Volt Thunderbolt!", "가나다라마바사아자차카타파하".repeat(8)]:
		var pages := PixelUi.dialogue_pages(text, Hud.MSG_W - 30.0)
		var restored := ""
		for page in pages:
			assert_lte(PixelUi.line_count(page, Hud.MSG_W - 30.0), 2)
			restored += page.replace(" ", "").replace("\n", "")
		assert_eq(restored, text.replace(" ", "").replace("\n", ""))

func test_paged_notice_auto_advance_before_next_notice() -> void:
	var w := _world()
	var game = load("res://scripts/game.gd").new()
	game.world = w
	game.panel = ChoicePanel.new()
	add_child_autofree(game.panel)
	game.bot = true
	game.state = "fight"
	var text := "The opposing Alolan Ninetales learned\nTen Million Volt Thunderbolt!"
	var pages := PixelUi.dialogue_pages(text, Hud.MSG_W - 30.0)
	assert_gt(pages.size(), 1)
	game._queue_status_message(text)
	assert_eq(game.dialog_text,pages[0])
	game._queue_status_message("Next target")
	assert_eq(game.dialog_text,"Next target")
	assert_true(game.timed_dialog_pages.is_empty())
	game._win()
	game.advance(game.SAY_TIME+0.01)
	assert_eq(game.state,"victory")
	# Without story interruption, timed continuation must also keep each page.
	game.state = "fight"
	game._queue_status_message(text)
	game._win()
	game.advance(0.01)
	for i in range(1, pages.size()):
		game.advance(game.SAY_TIME + 0.01)
		assert_eq(game.dialog_text, pages[i])
		assert_eq(game.state, "fight")
	game.advance(game.SAY_TIME + 0.01)
	assert_eq(game.state, "victory")
	game.free()

func test_few_combat_pages_keep_normal_timer() -> void:
	var w := _world()
	var game = load("res://scripts/game.gd").new()
	game.world = w
	game.state = "fight"
	game.pending_battle_end = "victory"
	game._queue_status_message("The opposing Alolan Ninetales learned\nTen Million Volt Thunderbolt!")
	game._show_next_status_message()
	assert_eq(game.dialog_t, 2.8)
	assert_false(game.timed_dialog_pages.is_empty())
	var first: String = game.dialog_text
	game.advance(2.79)
	assert_eq(game.dialog_text, first)
	game.advance(0.02)
	assert_ne(game.dialog_text, first)
	assert_eq(game.dialog_t, 2.8)
	game._say("Learned a move")
	assert_eq(game.dialog_t, game.SAY_TIME)
	game.free()

func test_combat_queue_uses_three_speed_bands_and_restores_speed() -> void:
	var game = load("res://scripts/game.gd").new()
	game.state="fight"
	for i in 60:
		game._queue_status_message("Notice %d" % i)
		assert_eq(game.dialog_text,"Notice %d" % i)
		assert_eq(game.dialog_t,game.COMBAT_MESSAGE_TIME)
	assert_true(game.status_messages.is_empty(),"No backlog survives a new event")
	game.free()

func test_old_notice_stays_fast_across_story_interruption_and_pages() -> void:
	var w := _world()
	var game = load("res://scripts/game.gd").new()
	game.world = w
	game.state = "fight"
	game._queue_status_message("The opposing Alolan Ninetales learned\nTen Million Volt Thunderbolt!")
	game.combat_message_clock = 3.0
	game.dialog_t = game._combat_message_duration()
	game._show_next_status_message()
	assert_eq(game.dialog_t, 0.6)
	assert_false(game.timed_dialog_pages.is_empty())
	game._say_pages(["Story"])
	for created in game.status_message_times: assert_eq(created, 0.0)
	game._talk_next()
	game._show_next_status_message()
	assert_eq(game.dialog_t, 0.6)
	game.pending_battle_end = "victory"
	game.advance(0.61)
	assert_eq(game.dialog_t, 0.6, "Continuation keeps its original event time")
	game.free()

func test_identical_new_notice_does_not_inherit_old_notice_age() -> void:
	var game = load("res://scripts/game.gd").new()
	game.state = "fight"
	game._queue_status_message("Same text")
	game.combat_message_clock = 3.0
	game._queue_status_message("Same text")
	game._show_next_status_message()
	assert_eq(game.dialog_t, 2.8,"New event is displayed immediately with fresh timing")
	game.dialog_text = ""
	game._show_next_status_message()
	assert_eq(game.dialog_t, 2.8, "The later event is fresh despite identical wording")
	game.free()

func test_custom_fire_fang_keeps_damage_and_single_bite_timing() -> void:
	var damage: Array[int] = []
	for mode in ["original", "custom"]:
		FxStyle.set_mode(mode)
		var w := _world()
		var target := _foe(w,Vector2(30,0))
		var hit := w.make_hit(w.player,"fire_fang")
		hit["crit"] = 0.0
		hit["burn"] = 0.0
		w.rng.seed = 123
		w.apply_hit(target,hit,w.player.position)
		damage.append(900-target.hp)
		var bites := 0
		var flashes := 0
		for f in w.fxs:
			if f.kind == "fang": bites += 1
			if mode == "custom" and f.kind == "sprite" and f.text == "g4_hitburst":
				flashes += 1
				assert_eq(f.delay,0.0)
		assert_eq(bites,0 if mode == "custom" else 1)
		if mode == "custom": assert_eq(flashes,1)
	assert_eq(damage[0],damage[1])
	assert_gt(damage[0],0)

func test_eight_direction_fangs_follow_caster_and_cast_once_without_target() -> void:
	FxStyle.set_mode("custom")
	for row in 8:
		var w := _world()
		var direction := Vector2.UP.rotated(row*PI/4.0)
		w.cast(w.player,"fire_fang",direction,w.player.position+direction*30.0)
		var jaws: Array = w.fxs.filter(func(f): return f.kind == "fang_directional")
		assert_eq(jaws.size(),1,"One jaw pair per cast, even on a miss")
		var jaw: Fx = jaws[0]
		assert_eq(jaw.fang_row,row)
		assert_eq(jaw.size,float(MoveDB.get_move("fire_fang")["range"])*1.5)
		assert_eq(jaw.follow,w.player)
		assert_gt((jaw.offset+Vector2(0,w.player.radius*0.5)).dot(direction),w.player.radius)
		w.player.position += Vector2(10,5)
		jaw.step(0.01)
		assert_eq(jaw.position,w.player.position+jaw.offset)
		jaw.step(jaw.lifetime)
		assert_true(jaw.dead)

func test_fire_fang_holds_then_moves_and_hits_at_closure() -> void:
	FxStyle.set_mode("custom")
	var w := _world()
	var target := _foe(w,Vector2(45,0))
	var start := w.player.position
	w.cast(w.player,"fire_fang",Vector2.RIGHT,target.position)
	assert_eq(w.player.position,start,"No instant step on cast")
	var duration: float = w.pending_melee[0]["t"]
	var jaw: Fx = w.fxs.filter(func(f): return f.kind=="fang_directional")[0]
	w._step_pending_melee(duration*0.5)
	jaw.age = duration*0.5
	assert_eq(w.player.position,start)
	assert_eq(jaw.fang_close_progress(),0.0)
	assert_eq(target.hp,900)
	w._step_pending_melee(duration*0.3)
	jaw.age = duration*0.8
	assert_gt(w.player.position.x,start.x)
	assert_lt(w.player.position.x,start.x+12.0)
	assert_almost_eq(jaw.fang_close_progress(),0.5,0.001)
	assert_eq(target.hp,900,"No damage while jaws are still closing")
	w._step_pending_melee(duration*0.2+0.001)
	jaw.age = duration
	assert_almost_eq(w.player.position.x,start.x+12.0,0.01)
	assert_eq(jaw.fang_close_progress(),1.0)
	assert_lt(target.hp,900,"Damage happens at closure")
	assert_true(w.pending_melee.is_empty())

func test_dragon_rage_custom_preserves_fixed_damage_and_impact() -> void:
	for mode in ["original","custom"]:
		FxStyle.set_mode(mode)
		var w := _world()
		var target := _foe(w,Vector2(30,0))
		var hit := w.make_hit(w.player,"dragon_rage")
		hit["crit"] = 0.0
		w.apply_hit(target,hit,w.player.position)
		assert_eq(900-target.hp,40,"용의분노 고정 피해 유지")
		if mode == "custom":
			var flashes := w.fxs.filter(func(f): return f.text=="g4_hitburst")
			assert_eq(flashes.size(),1)
			assert_eq(flashes[0].delay,0.0)

func test_scary_face_custom_keeps_cone_protection_and_rank_limit() -> void:
	for mode in ["original","custom"]:
		FxStyle.set_mode(mode)
		var w := _world()
		var target := _foe(w,Vector2(35,0))
		var protected := _foe(w,Vector2(40,10))
		protected.protect_t = 1.0
		var behind := _foe(w,Vector2(-35,0))
		var capped := _foe(w,Vector2(40,-10))
		capped.spe_stage = -6
		w.cast(w.player,"scary_face",Vector2.RIGHT,target.position)
		if mode == "custom":
			assert_eq(target.spe_stage,0,"No rank change during the stare")
			w._step_pending_calls(0.543)
			assert_eq(target.spe_stage,0)
			w._step_pending_calls(0.002)
		assert_eq(target.spe_stage,-2)
		assert_eq(protected.spe_stage,0)
		assert_eq(behind.spe_stage,0)
		assert_eq(capped.spe_stage,-6)
		assert_eq(target.hp,900)
		if mode == "custom":
			assert_eq(w.fxs.filter(func(f): return f.kind=="dim").size(),0)
			var eyes := w.fxs.filter(func(f): return f.text=="g4_scary_face")
			assert_eq(eyes.size(),1)
			assert_eq(eyes[0].follow,w.player)
			assert_not_null(Fx.sheet("g4_scary_face"))
			var face: Fx = eyes[0]
			assert_true(face.scare_snap)
			var lights := w.fxs.filter(func(f): return f.kind=="light")
			assert_eq(lights.size(),1)
			assert_eq(lights[0].delay,0.544)
			assert_eq(lights[0].lifetime,face.lifetime)
			assert_eq(face.anim_frame_at(0.1),0)
			assert_eq(face.anim_frame_at(0.5),1)
			assert_eq(face.anim_frame_at(0.6),2)
			assert_eq(face.anim_frame_at(0.7),3)
			assert_eq(face.anim_scale_at(0.67),0.85)
			assert_almost_eq(face.anim_scale_at(0.76),1.55,0.001)
			assert_eq(face.anim_alpha_at(0.8),1.0)
			assert_eq(face.anim_alpha_at(1.0),0.0)
		w.step_visual(1.0)
		assert_eq(w.fxs.filter(func(f): return f.text in ["g4_scary_face","g4_streak","g4_glow"] and not f.dead).size(),0)

func test_flamethrower_stream_keeps_single_hit_and_piercing() -> void:
	var damages: Array = []
	for mode in ["original","custom"]:
		FxStyle.set_mode(mode)
		var w := _world()
		w.cast(w.player,"flamethrower",Vector2.RIGHT,w.player.position+Vector2(80,0))
		for frame in 40: w._step_bursts(1.0/60.0)
		assert_eq(w.projectiles.size(),10)
		var front := _foe(w,Vector2(35,0))
		var rear := _foe(w,Vector2(65,0))
		w.rng.seed = 321
		for p in w.projectiles:
			p.hit["crit"] = 0.0
			p.hit["burn"] = 0.0
			assert_true(p.pierce)
			assert_eq(p.radius,5.0)
			assert_eq(p.range_full,4.0*Arena.TILE)
		w.apply_hit(front,w.projectiles[0].hit,w.player.position)
		w.apply_hit(rear,w.projectiles[0].hit,w.player.position)
		var hp := [front.hp,rear.hp]
		assert_lt(front.hp,900)
		assert_lt(rear.hp,900)
		for p in w.projectiles:
			w.apply_hit(front,p.hit,w.player.position)
			w.apply_hit(rear,p.hit,w.player.position)
		assert_eq([front.hp,rear.hp],hp,"Overlapping flames cannot repeat damage")
		damages.append(hp)
	assert_eq(damages[0],damages[1],"Custom visuals preserve damage")

func test_flamethrower_visual_width_grows_without_hitbox_growth() -> void:
	var p := Projectile.new()
	p.radius = 5.0
	p.range_full = 96.0
	p.range_left = 96.0
	var narrow: float = p.stream_layers()[0]["width"]
	var hit_radius := p.hit_radius()
	p.range_left = 16.0
	assert_gt(float(p.stream_layers()[0]["width"]),narrow*3.0)
	assert_eq(p.hit_radius(),hit_radius)
	p.free()

func test_large_species_scary_face_visual_size_is_bounded() -> void:
	FxStyle.set_mode("custom")
	for species in ["charmander","charizard","bulbasaur","onix","blastoise"]:
		var w := _world()
		w.player.setup_player(species,30,["scary_face"])
		assert_false(w.player._sprites.is_empty())
		w.cast(w.player,"scary_face",Vector2.RIGHT,w.player.position+Vector2(40,0))
		var faces := w.fxs.filter(func(f): return f.scare_snap)
		assert_eq(faces.size(),1)
		assert_lte(faces[0].size,48.0)

func test_species_change_drops_previous_render_frame() -> void:
	var w := _world()
	w.player.stat_overlay.tex = Fx.sheet("g4_flame")
	w.player.setup_player("snorlax",30,["scratch"])
	assert_null(w.player.stat_overlay.tex,"Missing sprites must not render the old species")

func test_species_without_tail_hides_previous_tail_effects() -> void:
	var w := _world()
	var p := w.player
	p._tail_light = PointLight2D.new()
	p.add_child(p._tail_light)
	p._tail_halo = Sprite2D.new()
	p.add_child(p._tail_halo)
	p.setup_player("bulbasaur",30,["scratch"])
	p._step_tail_light()
	assert_false(p._tail_light.visible)
	assert_false(p._tail_halo.visible)

class MovingSkillInput:
	extends Idle
	var aim := Vector2.RIGHT
	func move_dir(_w) -> Vector2: return Vector2.DOWN
	func aim_point(w) -> Vector2: return w.player.position+aim*100.0
	func want_skill(i,_w) -> bool: return i==0

func test_moving_flame_turns_new_shots_without_steering_old_ones() -> void:
	FxStyle.set_mode("custom")
	for species in ["charmander","charizard","onix"]:
		var w := _world()
		w.player.setup_player(species,30,["flamethrower"])
		var input := MovingSkillInput.new()
		w.player.controller = input
		var seen := {}
		var velocities := {}
		var right_count := 0
		var up_count := 0
		var volleys := {}
		for frame in 180:
			input.aim = Vector2.RIGHT if frame<15 else Vector2.UP
			w.step(1.0/60.0)
			for p in w.projectiles:
				var key: int = p.get_instance_id()
				if velocities.has(key): assert_eq(p.vel,velocities[key],"Old shots never turn with the caster")
				velocities[key] = p.vel
				if seen.has(key): continue
				seen[key] = true
				volleys[int(p.hit.get("volley",0))] = true
				if p.vel.normalized().dot(Vector2.RIGHT)>0.98: right_count+=1
				if p.vel.normalized().dot(Vector2.UP)>0.98: up_count+=1
		assert_gt(right_count,0)
		assert_gt(up_count,0)
		assert_gte(volleys.size(),2,"Held input recasts normally")

func test_smoke_density_shares_opacity_only_between_nearby_casts() -> void:
	var w := _world()
	var at := w.player.position
	w._smoke_cloud_custom(at,36.0,10.0)
	for f in w.fxs: f.age = 0.2
	w._update_smoke_density()
	for f in w.fxs: assert_eq(f.smoke_alpha_gain,1.0,"Single cast remains unchanged")
	for i in 5: w._smoke_cloud_custom(at,36.0,10.0)
	for f in w.fxs: f.age = 0.2
	w._update_smoke_density()
	assert_eq(w.fxs.filter(func(f): return f.smoke_veil).size(),90,"Each cast retains all fifteen veil particles")
	var releases := w.fxs.filter(func(f): return f.text == "pixelfx_smoke")
	assert_eq(releases.size(),6,"One short release puff per cast")
	for f in w.fxs: assert_almost_eq(f.smoke_alpha_gain,1.0/6.0,0.001,"Six overlapping casts share density")
	for f in releases: assert_almost_eq(f.anim_alpha_at(0.4),f.color.a/6.0,0.001,"Animated release shares the veil's density budget")
	w._smoke_cloud_custom(at+Vector2(200,0),36.0,10.0)
	for f in w.fxs: f.age = 0.2
	w._update_smoke_density()
	for f in w.fxs:
		if f.smoke_group==7: assert_eq(f.smoke_alpha_gain,1.0,"Distant cast is unaffected")
	for f in w.fxs:
		if f.smoke_group in [2,3,4,5,6]: f.age = f.lifetime
	w._update_smoke_density()
	for f in w.fxs:
		if f.smoke_group==1: assert_eq(f.smoke_alpha_gain,1.0,"Expired neighbours release their density share")

func test_launched_smoke_survives_removed_caster() -> void:
	for mode in ["original","custom"]:
		FxStyle.set_mode(mode)
		var w := _world()
		var caster := _foe(w,Vector2(24,0))
		w.cast(caster,"smoke_screen",Vector2.LEFT,w.player.position)
		assert_gt(w.pending_calls.size(),0)
		w.enemies.erase(caster)
		caster.free()
		w._step_pending_calls(0.6)
		assert_eq(w.player.acc_stage,-1,"Already launched smoke keeps its original team")
		assert_eq(w.pending_calls.size(),0)
		assert_gt(w.fxs.size(),0)

func test_fainting_stops_unlaunched_burst_and_melee_but_not_projectiles() -> void:
	FxStyle.set_mode("custom")
	var w := _world()
	var caster := _foe(w,Vector2(24,0))
	w.cast(caster,"ember",Vector2.LEFT,w.player.position)
	w._step_bursts(0.04)
	assert_gt(w.projectiles.size(),0)
	var launched := w.projectiles.size()
	w.cast(caster,"fire_fang",Vector2.LEFT,w.player.position)
	assert_gt(w.pending_melee.size(),0)
	var hp := w.player.hp
	caster.dead = true
	w._step_bursts(1.0)
	w._step_pending_melee(1.0)
	assert_eq(w.bursts.size(),0)
	assert_eq(w.pending_melee.size(),0)
	assert_eq(w.projectiles.size(),launched,"Flying projectiles are independent")
	assert_eq(w.player.hp,hp,"No post-faint melee hit")

func test_freeing_world_discards_pending_attacks() -> void:
	FxStyle.set_mode("custom")
	var w := _world()
	var caster := _foe(w,Vector2(24,0))
	w.cast(caster,"smoke_screen",Vector2.LEFT,w.player.position)
	w.cast(caster,"ember",Vector2.LEFT,w.player.position)
	w._step_bursts(0.04)
	var effect: WeakRef = weakref(w.fxs[0])
	var projectile: WeakRef = weakref(w.projectiles[0])
	w.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(effect.get_ref())
	assert_null(projectile.get_ref())
	var next_world := _world()
	_run(next_world,1.0)
	assert_eq(next_world.player.acc_stage,0,"Old scene smoke never lands in a new world")
	assert_eq(next_world.pending_calls.size(),0)

func test_removed_caster_cancels_waiting_attacks() -> void:
	FxStyle.set_mode("custom")
	var w := _world()
	var caster := _foe(w,Vector2(24,0))
	w.cast(caster,"ember",Vector2.LEFT,w.player.position)
	w.cast(caster,"fire_fang",Vector2.LEFT,w.player.position)
	w.pending_casts.append({"mon":caster,"move":"ember","t":0.1})
	w.enemies.erase(caster)
	caster.free()
	w._step_bursts(1.0)
	w._step_pending_melee(1.0)
	w._step_pending_casts(1.0)
	assert_eq(w.bursts.size(),0)
	assert_eq(w.pending_melee.size(),0)
	assert_eq(w.pending_casts.size(),0)

class MovementSkillInput:
	extends Idle
	var frame := 0
	var action := "jump"
	func move_dir(_w) -> Vector2: return Vector2.DOWN
	func want_skill(i,_w) -> bool: return i==0
	func want_jump(_w) -> bool: return action=="jump" and frame==0
	func want_dodge(_w) -> bool: return action=="dodge" and frame==0

func test_jump_and_dodge_block_new_cast_until_movement_finishes() -> void:
	var previous_unlock := Player.dodge_unlocked
	Player.dodge_unlocked = true
	for action in ["jump","dodge"]:
		var w := _world()
		var input := MovementSkillInput.new()
		input.action = action
		w.player.controller = input
		w.player.setup_player("charmander",30,["ember"])
		var initial_pp: int = w.player.pp[0]
		w.step(1.0/60.0)
		assert_true(w.player.is_dashing())
		assert_eq(int(w.player.pp[0]),initial_pp,"Movement takes priority over simultaneous attack input")
		var cast_seen := false
		for frame in range(1,90):
			input.frame = frame
			var was_moving := w.player.is_dashing()
			var before: int = w.player.pp[0]
			w.step(1.0/60.0)
			if was_moving: assert_eq(int(w.player.pp[0]),before,"No fresh cast during dash/hop")
			if w.player.pp[0]<before: cast_seen=true
		assert_true(cast_seen,"Held attack resumes after landing/recovery")
	Player.dodge_unlocked = previous_unlock

func test_fang_after_jump_hits_only_at_jaw_closure() -> void:
	FxStyle.set_mode("custom")
	var w := _world()
	w.player.setup_player("charmander",30,["fire_fang"])
	var input := MovementSkillInput.new()
	w.player.controller = input
	var foe := _foe(w,Vector2.ZERO)
	foe.position = w.player.position+Vector2.DOWN*Player.JUMP_DISTANCE+Vector2.RIGHT*(w.player.radius+foe.radius+4)
	var landed_hit := false
	var pending_seen := false
	for frame in 80:
		input.frame = frame
		var hp := foe.hp
		var remaining := 999.0
		for attack in w.pending_melee:
			remaining = minf(remaining,float(attack.t))
			pending_seen = true
		w.step(1.0/60.0)
		if foe.hp<hp:
			assert_lte(w.player.hop_t,0.0,"No hit before landing")
			assert_lte(remaining,1.0/60.0,"Damage occurs on the closing tick")
			landed_hit = true
			break
	assert_true(pending_seen)
	assert_true(landed_hit)

func test_hop_landing_is_cosmetic_once_and_short_lived() -> void:
	var w := _world()
	var p := w.player
	var destination := p.position+Vector2.DOWN*Player.JUMP_DISTANCE
	var rng_before := w.rng.state
	w._start_hop(destination)
	for i in 90:
		p.tick_status(1.0/60.0)
		if not p.is_dashing(): break
		w._step_dash(p,1.0/60.0)
	assert_almost_eq(p.position.distance_to(destination),0.0,0.01,"Landing keeps jump distance")
	assert_gt(p.landing_t,0.0)
	assert_eq(p.recover_t,0.0,"No added landing recovery")
	assert_eq(p.skill_lock_t,0.0,"No added skill lock")
	assert_eq(w.rng.state,rng_before,"Cosmetic effect does not consume combat RNG")
	var dust := w.fxs.filter(func(f):return f.landing_dust)
	assert_eq(dust.size(),4,"Emit once at landing")
	p.hop_t = 0.0
	p.landing_t = Mon.LANDING_DURATION - Mon.LANDING_COMPRESS_TIME
	assert_almost_eq(p.landing_scale().x,1.08,0.001)
	assert_almost_eq(p.landing_scale().y,0.90,0.001)
	p.tick_status(0.5)
	w.step_fx(0.5)
	assert_eq(p.landing_scale(),Vector2.ONE)
	assert_eq(w.fxs.filter(func(f):return f.landing_dust).size(),0)

func test_indoor_landing_dust_is_restrained_and_jump_resets_recoil() -> void:
	var w := _world()
	var previous := DungeonDB.current
	DungeonDB.set_current("players_house_1f")
	w._hop_land_fx(w.player)
	var dust := w.fxs.filter(func(f):return f.landing_dust)
	assert_eq(dust.size(),2)
	for f in dust: assert_lte(f.color.a,0.25)
	w.player.play_hop()
	assert_eq(w.player.landing_t,0.0,"No leftover squash on the next jump")
	DungeonDB.set_current(previous)

func test_hit_feedback_is_cosmetic_and_type_specific() -> void:
	var w := _world()
	var foe := _foe(w,Vector2(24,0))
	var at := foe.position
	var hp := foe.hp
	var state := w.rng.state
	for kind in ["normal","fire","dragon"]:
		foe.play_hit_feedback(kind,"physical" if kind=="normal" else "special",Vector2.RIGHT)
		assert_eq(foe.position,at)
		assert_eq(foe.hp,hp)
		assert_eq(foe.flinch_t,0.0)
		assert_eq(foe.knock,Vector2.ZERO)
		assert_eq(w.rng.state,state)
		var tint := foe.hit_feedback_tint()
		if kind=="fire": assert_gt(tint.r,tint.b)
		if kind=="dragon": assert_gt(tint.b,tint.r)
		foe.hit_visual_t *= 0.5
		assert_lt(foe.hit_feedback_offset().length(),1.6)
		foe.tick_status(0.5)
		assert_eq(foe.hit_feedback_tint(),Color.WHITE)
		assert_eq(foe.hit_feedback_offset(),Vector2.ZERO)

func test_protect_and_status_moves_do_not_play_damage_feedback() -> void:
	var w := _world()
	var foe := _foe(w,Vector2(24,0))
	foe.protect_t = 1.0
	w.apply_hit(foe,w.make_hit(w.player,"ember"),w.player.position)
	assert_eq(foe.hit_visual_t,0.0)
	foe.protect_t = 0.0
	w.cast(w.player,"growl",Vector2.RIGHT,foe.position)
	assert_eq(foe.hit_visual_t,0.0)
	w.apply_hit(foe,w.make_hit(w.player,"ember"),w.player.position)
	assert_gt(foe.hit_visual_t,0.0)
	assert_gt(foe.hit_feedback_tint().r,foe.hit_feedback_tint().b)

func test_scary_face_surprise_cancels_on_faint_and_rechecks_cone() -> void:
	FxStyle.set_mode("custom")
	for reason in ["faint","freed","out_of_range"]:
		var w := _world()
		var caster := _foe(w,Vector2(35,0))
		w.cast(caster,"scary_face",Vector2.LEFT,w.player.position)
		assert_eq(w.player.spe_stage,0)
		if reason=="faint": caster.dead = true
		elif reason=="freed":
			w.enemies.erase(caster)
			caster.free()
		else: w.player.position += Vector2.LEFT*200
		w._step_pending_calls(0.55)
		assert_eq(w.player.spe_stage,0,reason)
		assert_true(w.pending_calls.is_empty())

func test_scratch_real_input_starts_full_strike_instead_of_gliding_idle() -> void:
	var w := _world()
	w.player.controller = OneSkill.new()
	var pp_before: int = w.player.pp[0]
	w.step(1.0/60.0)
	assert_eq(w.player.attack_anim,"Strike")
	assert_true(w.player.attack_full_recovery)
	assert_false(w.player.attack_lunge,"The attack is not a truncated body lunge")
	assert_gt(w.player.attack_anim_t,0.0)
	assert_eq(w.player.pp[0],pp_before-1,"The complete input/spend path ran")
	assert_false(w.pending_melee.is_empty())
	assert_true(w.player._scratch_downstroke(),"The raised-arm/downstroke pose order is active")

func test_ember_contact_uses_depth_layered_flames_without_hit_sparks() -> void:
	var w := _world()
	var target := _foe(w,Vector2.RIGHT*30)
	var hp := target.hp
	w._ember_hit_custom(target,w.player.position)
	var flames := w.fxs.filter(func(f): return f.ember_coat)
	assert_eq(flames.size(),6)
	assert_eq(flames.filter(func(f): return f.body_depth<0.0).size(),3,"Back flames can be occluded by the body")
	assert_eq(flames.filter(func(f): return f.body_depth>0.0).size(),3,"Front flames wrap around the silhouette")
	assert_true(w.fxs.filter(func(f): return f.text=="pixelfx_ember").is_empty(),"Special fire has no physical hit-star")
	target.position+=Vector2(5,3)
	for flame in flames:
		assert_eq(flame.text,"g4_flame","Uses the original Platinum flame artwork")
		assert_true(flame.body_impact)
		flame.step(0.0)
		assert_eq(flame.position,target.position+flame.offset)
		flame.step(0.6)
		assert_true(flame.dead,"No persistent fire/status is added by the artwork")
	assert_eq(target.hp,hp)
	assert_eq(target.burn_t,0.0)

func test_scratch_strokes_draw_downward_in_all_directions_and_follow_motion() -> void:
	var w := _world()
	var target := _foe(w, Vector2.RIGHT * 30)
	for row in 8:
		var start := w.fxs.size()
		w._scratch_hit_custom(target, Vector2.DOWN.rotated(-row * PI / 4.0))
		for i in 3:
			var cut: Fx = w.fxs[start + i]
			assert_true(cut.claw_downstroke)
			assert_gt(Vector2.DOWN.rotated(cut.rot).y, 0.95, "모든 방향에서 아래로 긋는다")
			cut.age = cut.delay
			assert_almost_eq(cut.sprite_stretch_at(), 0.0, 0.001)
			var upper_start := cut.sprite_draw_offset(1.0, 1.0)
			cut.age += Fx.CLAW_DRAW_TIME
			var upper_end := cut.sprite_draw_offset(1.0, 1.0) - Vector2.DOWN.rotated(cut.rot) * cut.size * cut.sprite_stretch_at() * 0.5
			assert_almost_eq(upper_start.distance_to(upper_end), 0.0, 0.001, "시작점은 고정하고 아래쪽으로 길어진다")
			target.position += Vector2(2, 1)
			cut.step(0.0)
			assert_eq(cut.position, target.position + cut.offset, "밀려난 몸을 따라간다")
