extends GutTest

# 넉백·경직(사용자 결정 2026-10-30): 물리기는 (공격 ÷ 방어) × √(내 몸무게 ÷ 상대 몸무게) 를 포화 곡선 2x/(1+x) 에 넣은 만큼 밀고,
# 특수기는 밀지 않고 (특공 ÷ 특방) 을 같은 곡선에 넣은 만큼(같으면 0.4초, 최대 0.8초) 굳는다.
# 쓰러질 때: 물리기면 다 밀려난 뒤 넘어지고, 특수기면 경직 자세로 0.3초 버틴 뒤 넘어진다.

class Idle:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position + Vector2.RIGHT * 30.0
	func want_dodge(_w) -> bool: return false
	func want_skill(_i, _w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

class Mover:
	extends Idle
	func move_dir(_w) -> Vector2: return Vector2.RIGHT

func _world() -> World:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var w := World.new()
	add_child_autofree(w)
	w.setup(7, "charmander", 12, ["scratch", "ember"], Idle.new())
	w.player.position = Arena.center()
	return w

func _foe(w: World, id: String, level: int) -> Enemy:
	var e := Enemy.new()
	e.setup_enemy(id, level, w.rng)
	e.position = w.player.position + Vector2(20, 0)
	e.max_hp = 400       # 한 방에 쓰러지지 않게(쓰러짐 시험은 hp 를 따로 1 로 둔다)
	e.hp = 400
	e.frozen = true
	w.add_child(e)
	w.enemies.append(e)
	return e

func test_curve_saturates() -> void:
	assert_almost_eq(World.knock_factor(10.0, 10.0, 10.0, 10.0), 1.0, 0.001, "힘·몸무게가 같으면 1")
	assert_lt(World.knock_factor(100.0, 1.0, 10.0, 0.1), 2.0, "아무리 차이 나도 2 를 넘지 않는다(최대값 없이 포화)")
	assert_gt(World.knock_factor(1.0, 100.0, 1.0, 210.0), 0.0, "롱스톤도 0 은 아니다")
	assert_gt(World.knock_factor(19.0, 7.0, 8.5, 1.8), World.knock_factor(19.0, 51.0, 8.5, 210.0), "구구가 롱스톤보다 멀리 밀린다")
	assert_almost_eq(World.knock_speed(75.0), sqrt(2.0 * Mon.KNOCK_DECEL * 75.0), 0.001)

func test_weight_from_platinum() -> void:
	assert_almost_eq(float(SpeciesDB.get_species("charmander")["weight"]), 8.5, 0.01)
	assert_almost_eq(float(SpeciesDB.get_species("onix")["weight"]), 210.0, 0.01)
	assert_gt(float(SpeciesDB.get_species("charmeleon")["weight"]), float(SpeciesDB.get_species("charmander")["weight"]), "진화하면 무거워진다")

func test_physical_knock_scales_with_foe() -> void:
	var w := _world()
	var light := _foe(w, "pidgey", 3)
	var heavy := _foe(w, "onix", 14)
	w.apply_hit(light, w.make_hit(w.player, "scratch"), w.player.position)
	w.apply_hit(heavy, w.make_hit(w.player, "scratch"), w.player.position)
	assert_gt(light.knock.length(), heavy.knock.length(), "가벼운 구구가 롱스톤보다 세게 밀린다")
	assert_gt(heavy.knock.length(), 0.0, "롱스톤도 조금은 밀린다")
	assert_lt(light.knock.length(), World.knock_speed(2.0 * World.KNOCK_TILES * Arena.TILE) + 0.01, "두 배(6칸)를 넘지 않는다")
	assert_eq(light.flinch_t, 0.0, "물리기는 경직이 없다")

func test_special_stuns_instead_of_knocking() -> void:
	var w := _world()
	var e := _foe(w, "pidgey", 3)
	var hp0 := e.hp
	w.apply_hit(e, w.make_hit(w.player, "ember"), w.player.position)
	assert_eq(e.knock, Vector2.ZERO, "특수기는 밀지 않는다")
	assert_gt(e.flinch_t, World.STUN_BASE, "특공이 특방보다 높으니 0.4초보다 오래 굳는다(파이리 Lv12 vs 구구 Lv3)")
	assert_lt(e.flinch_t, 2.0 * World.STUN_BASE, "0.8초는 넘지 않는다")
	assert_false(e.can_act(), "경직 중엔 움직이지도 기술을 쓰지도 못한다")
	assert_almost_eq(World.stun_time(10.0, 10.0, false), World.STUN_BASE, 0.001, "특공·특방이 같으면 0.4초")
	assert_almost_eq(World.stun_time(10.0, 10.0, true), World.STUN_BASE * 0.5, 0.001, "내가 맞으면 절반")
	assert_lt(World.stun_time(1000.0, 1.0, false), 2.0 * World.STUN_BASE, "상한 0.8초(포화)")
	assert_gt(World.stun_time(1.0, 1000.0, false), 0.0, "0 은 아니다")

func test_ranged_physical_halves_distance_without_changing_damage() -> void:
	for move in ["razor_leaf", "poison_sting", "rock_throw", "smack_down", "seed_bomb", "rock_tomb"]:
		var w := _world()
		var reference := _foe(w, "pidgey", 3)
		var ranged := _foe(w, "pidgey", 3)
		ranged.stats = reference.stats.duplicate()
		var hit := w.make_hit(w.player, move)
		assert_eq(hit.cat, "physical", move)
		hit.crit = 0.0
		# Same attack/defense/type/power, with the old melee-distance rule as the control.
		var control := hit.duplicate()
		control.move = "scratch"
		var state := w.rng.state
		assert_true(w.apply_hit(reference, control, w.player.position))
		w.rng.state = state
		assert_true(w.apply_hit(ranged, hit, w.player.position))
		var old_distance := reference.knock.length_squared() / (2.0 * Mon.KNOCK_DECEL)
		var new_distance := ranged.knock.length_squared() / (2.0 * Mon.KNOCK_DECEL)
		assert_gt(old_distance, 0.0, move)
		assert_almost_eq(new_distance, old_distance * 0.5, 0.001, move + " 밀리는 거리가 절반")
		assert_eq(ranged.hp, reference.hp, move + " 피해량은 같다")
		assert_eq(ranged.knock.normalized(), Vector2.RIGHT, move + " 밀리는 방향은 같다")

func test_enemy_ranged_physical_uses_same_half_distance() -> void:
	var w := _world()
	var attacker := _foe(w, "geodude", 12)
	w.player.max_hp = 400
	w.player.hp = 400
	var hit := w.make_hit(attacker, "rock_throw")
	var old_distance := World.KNOCK_TILES * Arena.TILE * World.knock_factor(float(hit.atk), float(w.player.stats.def), attacker.weight_kg(), w.player.weight_kg())
	assert_true(w.apply_hit(w.player, hit, attacker.position))
	var new_distance := w.player.knock.length_squared() / (2.0 * Mon.KNOCK_DECEL)
	assert_almost_eq(new_distance, old_distance * 0.5, 0.001, "플레이어 피격에도 같은 거리 보정")
	assert_eq(w.player.knock.normalized(), Vector2.LEFT)

func test_ranged_fixed_knock_halves_distance_and_keeps_zero() -> void:
	var w := _world()
	var e := _foe(w, "pidgey", 3)
	var hit := w.make_hit(w.player, "poison_sting")
	hit.knock = 30.0
	assert_true(w.apply_hit(e, hit, w.player.position))
	assert_almost_eq(e.knock.length_squared(), 30.0 * 30.0 * 0.5, 0.001, "개별 속도 지정도 거리 절반")
	var e2 := _foe(w, "pidgey", 3)
	hit.knock = 0.0
	assert_true(w.apply_hit(e2, hit, w.player.position))
	assert_eq(e2.knock, Vector2.ZERO, "넉백 없는 기술은 그대로")

func test_physical_kill_slides_then_falls() -> void:
	var w := _world()
	var e := _foe(w, "pidgey", 3)
	e.hp = 1
	var x0 := e.position.x
	w.apply_hit(e, w.make_hit(w.player, "scratch"), w.player.position)
	assert_true(e.dead, "쓰러졌다")
	assert_gt(e.dying_t, 0.0, "바로 넘어지지 않고 밀려나는 중")
	for i in 20:
		w.step(1.0 / 60.0)      # 마무리 타 히트스톱(0.2초, 급소면 0.3)을 지나
	for i in 6:
		w.step(1.0 / 60.0)
	assert_gt(e.position.x, x0 + 5.0, "죽은 뒤에도 기세대로 미끄러진다")
	assert_almost_eq(e.faint_t, Mon.FAINT_TIME, 0.001, "다 밀릴 때까지 넘어지는 동작은 시작하지 않는다")
	for i in 60:
		w.step(1.0 / 60.0)
	assert_eq(e.dying_t, 0.0, "다 밀렸다")
	assert_lt(e.faint_t, Mon.FAINT_TIME, "이제 넘어지는 동작")
	assert_eq(e.knock, Vector2.ZERO, "넘어진 자리에서 더 밀리지 않는다")

func test_special_kill_holds_then_falls() -> void:
	var w := _world()
	var e := _foe(w, "pidgey", 3)
	e.hp = 1
	var p0 := e.position
	w.apply_hit(e, w.make_hit(w.player, "ember"), w.player.position)
	assert_true(e.dead)
	assert_almost_eq(e.dying_t, Mon.DIE_STUN, 0.001, "경직 자세로 0.3초")
	for i in 20:
		w.step(1.0 / 60.0)      # 히트스톱(0.2~0.3초) 동안도 그 자리
	assert_eq(e.position, p0, "그 자리 그대로")
	assert_almost_eq(e.faint_t, Mon.FAINT_TIME, 0.001, "아직 안 넘어졌다")
	for i in 24:
		w.step(1.0 / 60.0)
	assert_eq(e.dying_t, 0.0)
	assert_lt(e.faint_t, Mon.FAINT_TIME, "0.3초 안에 넘어진다")

func test_per_move_knock_kept() -> void:
	var w := _world()
	var e := _foe(w, "pidgey", 3)
	var hit := w.make_hit(w.player, "scratch")
	hit["knock"] = 30.0
	w.apply_hit(e, hit, w.player.position)
	assert_almost_eq(e.knock.length(), 30.0, 0.01, "기술이 정한 넉백(연속찌르기)은 그대로")

func test_knocked_player_ignores_move_keys() -> void:
	# 밀려나는 동안·경직 중엔 이동 키를 눌러도 걷지 않는다(사용자 지적 2026-10-30: 누른 채 밀리면 순간이동처럼 튀었다).
	var w := _world()
	w.player.controller = Mover.new()
	var e := _foe(w, "geodude", 12)
	w.step(1.0 / 60.0)
	assert_ne(w.player.vel, Vector2.ZERO, "평소엔 걷는다")
	w.apply_hit(w.player, w.make_hit(e, "tackle"), e.position)
	assert_ne(w.player.knock, Vector2.ZERO, "밀린다")
	w.step(1.0 / 60.0)
	assert_eq(w.player.vel, Vector2.ZERO, "밀리는 동안은 이동 입력 무시")
	for i in 90:
		w.step(1.0 / 60.0)
	assert_eq(w.player.knock, Vector2.ZERO, "다 밀렸다")
	assert_ne(w.player.vel, Vector2.ZERO, "끝나면 다시 걷는다")
	w.apply_hit(w.player, w.make_hit(e, "ember"), e.position)
	assert_gt(w.player.flinch_t, 0.0, "특수기엔 경직")
	w.step(1.0 / 60.0)
	assert_eq(w.player.vel, Vector2.ZERO, "경직 중에도 이동 입력 무시")

func test_hitstop_melee_freezes_both() -> void:
	# 히트스톱(사용자 결정 2026-11-02): 근접기는 때린 쪽·맞은 쪽이 0.14초(급소 ×1.5) 멈추고, 그동안 넉백도 흐르지 않는다.
	var w := _world()
	var e := _foe(w, "pidgey", 3)
	w.apply_hit(e, w.make_hit(w.player, "slash"), w.player.position)
	assert_between(e.hitstop_t, World.HITSTOP_MELEE - 0.001, World.HITSTOP_MELEE * World.HITSTOP_CRIT + 0.001, "맞은 쪽 0.14초")
	assert_almost_eq(w.player.hitstop_t, e.hitstop_t, 0.001, "때린 쪽도 같이")
	var p0 := e.position
	var k0 := e.knock
	for i in 6:
		w.step(1.0 / 60.0)
	assert_eq(e.position, p0, "멈춘 동안 밀리지 않는다")
	assert_eq(e.knock, k0, "넉백도 줄지 않는다")
	assert_false(w.player.can_act(), "멈춘 동안은 행동 불가")
	for i in 20:
		w.step(1.0 / 60.0)
	assert_eq(e.hitstop_t, 0.0)
	assert_ne(e.position, p0, "풀리면 그대로 밀려난다")

func test_hitstop_ranged_only_target() -> void:
	var w := _world()
	var e := _foe(w, "pidgey", 3)
	w.apply_hit(e, w.make_hit(w.player, "ember"), w.player.position)
	assert_between(e.hitstop_t, World.HITSTOP_RANGED - 0.001, World.HITSTOP_RANGED * World.HITSTOP_CRIT + 0.001, "투사체·특수기 0.07초")
	assert_eq(w.player.hitstop_t, 0.0, "원거리는 쏜 쪽은 안 멈춘다")
	var e2 := _foe(w, "pidgey", 3)
	e2.hp = 1
	w.apply_hit(e2, w.make_hit(w.player, "scratch"), w.player.position)
	assert_gte(e2.hitstop_t, World.HITSTOP_KILL - 0.001, "쓰러뜨리는 타는 0.2초")
	var e3 := _foe(w, "pidgey", 3)
	var hit := w.make_hit(w.player, "scratch")
	hit["knock"] = 30.0
	w.apply_hit(e3, hit, w.player.position)
	assert_lte(e3.hitstop_t, World.HITSTOP_MULTI * World.HITSTOP_CRIT + 0.001, "연타기는 짧게")

func _run(w: World, frames: int) -> void:
	for i in frames:
		w.step(1.0 / 60.0)

func test_melee_clash_works_with_a_third_unrelated_strike() -> void:
	var w := _world()
	var opponent := _foe(w, "meowth", 12)
	var bystander := _foe(w, "meowth", 12)
	bystander.position += Vector2.DOWN * Arena.TILE * 4
	w.cast(bystander, "scratch", Vector2.DOWN, bystander.position + Vector2.DOWN)
	w.cast(w.player, "slash", Vector2.RIGHT, opponent.position)
	w.cast(opponent, "scratch", Vector2.LEFT, w.player.position)
	# Line up the active frames, independent of each species' wind-up.
	for strike in w.pending_melee: strike.t = 0.005
	var slash: Dictionary = w.pending_melee[1].hit
	var scratch: Dictionary = w.pending_melee[2].hit
	var hp := w.player.hp
	var old_hp := opponent.hp
	w._step_pending_melee(0.01)
	assert_eq(slash.power, 30.0)
	assert_eq(scratch.power, 0.0)
	assert_eq(opponent.hp, old_hp)
	w._step_pending_melee(World.ProjectileClashes.PAUSE)
	assert_lt(opponent.hp, old_hp)
	assert_eq(w.player.hp, hp)
	assert_eq(w.player.knock, Vector2.ZERO)
	var distance := opponent.knock.length_squared() / (2.0 * Mon.KNOCK_DECEL)
	var base := World.KNOCK_TILES * Arena.TILE * World.knock_factor(slash.atk, opponent.stats.def, w.player.weight_kg(), opponent.weight_kg())
	assert_almost_eq(distance, base * 30.0/70.0, 0.001)
	assert_true(w.pending_melee.is_empty())

func test_overlapping_timers_alone_do_not_clash() -> void:
	var w := _world()
	var opponent := _foe(w, "meowth", 12)
	opponent.position = w.player.position + Vector2.RIGHT * Arena.TILE * 6
	w.cast(w.player, "scratch", Vector2.RIGHT, opponent.position)
	w.cast(opponent, "scratch", Vector2.RIGHT, opponent.position + Vector2.RIGHT)
	var hits := w.pending_melee.map(func(strike): return strike.hit)
	for strike in w.pending_melee: strike.t = 0.01
	w._step_pending_melee(0.02)
	for hit in hits: assert_false(hit.has("clash_fraction"))
	assert_true(w.fxs.filter(func(f): return f.kind == "clash_chip").is_empty())

func test_first_hit_wins_melee_trade() -> void:
	# 먼저 맞힌 쪽 우선(사용자 결정 2026-11-02): 둘이 거의 같이 몸통박치기·할퀴기를 쓰면 먼저 닿은 쪽만 피해를 준다.
	var w := _world()
	var e := _foe(w, "rattata", 5)
	e.position = w.player.position + Vector2(26, 0)
	e.facing = Vector2.LEFT
	w.player.facing = Vector2.RIGHT
	var p_hp := w.player.hp
	var e_hp := e.hp
	# 내가 먼저(할퀴기), 적은 2틱 늦게 몸통박치기
	w.cast(w.player, "scratch", Vector2.RIGHT, e.position)
	w.player.play_attack("Strike", 0.0, true)
	_run(w, 2)
	w.cast(e, "tackle", Vector2.LEFT, w.player.position)
	e.play_attack("Attack", 0.0, true)
	_run(w, 90)
	assert_lt(e.hp, e_hp, "먼저 친 내 할퀴기는 맞는다")
	assert_eq(w.player.hp, p_hp, "늦게 친 적의 몸통박치기는 끊겨 피해가 없다")
	assert_true(w.pending_melee.is_empty(), "끊긴 근접기는 남지 않는다")

func test_first_hit_wins_enemy_first() -> void:
	var w := _world()
	var e := _foe(w, "rattata", 5)
	e.position = w.player.position + Vector2(26, 0)
	e.facing = Vector2.LEFT
	w.player.facing = Vector2.RIGHT
	var p_hp := w.player.hp
	var e_hp := e.hp
	w.cast(e, "tackle", Vector2.LEFT, w.player.position)
	e.play_attack("Attack", 0.0, true)
	_run(w, 2)
	w.cast(w.player, "tackle", Vector2.RIGHT, e.position)
	w.player.play_attack("Attack", 0.0, true)
	_run(w, 90)
	assert_lt(w.player.hp, p_hp, "먼저 친 적이 맞힌다")
	assert_eq(e.hp, e_hp, "늦게 친 내 몸통박치기는 끊긴다")

func test_fainted_body_fades_smoothly_after_the_fall_begins() -> void:
	var mon := Mon.new()
	autofree(mon)
	mon.dead=true
	mon.faint_t=Mon.FAINT_TIME
	assert_eq(mon.faint_alpha(),1.0)
	mon.dying_t=0.2
	mon.faint_t=0.1
	assert_eq(mon.faint_alpha(),1.0,"Knockback/stun stays opaque before the fall")
	mon.dying_t=0.0
	var last := 1.0
	for remaining in [0.85,0.75,0.5,0.25,0.1,0.0]:
		mon.faint_t=remaining
		var alpha := mon.faint_alpha()
		assert_lte(alpha,last,"Opacity decreases throughout the fall")
		if remaining>0.0 and remaining<0.8: assert_gt(alpha,0.0,"No sudden cutoff halfway through fading")
		last=alpha
	assert_eq(last,0.0)
	mon.dead=false
	assert_eq(mon.faint_alpha(),1.0,"Living Pokemon stay opaque")
