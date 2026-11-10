extends GutTest

# 이상해씨·꼬북이 계열 기술(사용자 요청 2026-10-28)을 실제 World 에서 써 본다. 시험용 풀밭 아레나, 상대는 제자리에 세운 캐터피.

const BULBA := ["leech_seed", "vine_whip", "poison_powder", "sleep_powder", "take_down", "razor_leaf", "sweet_scent", "growth",
	"double_edge", "worry_seed", "synthesis", "seed_bomb", "solar_beam", "petal_dance"]
const SQUIRT := ["bubble", "withdraw", "water_gun", "bite", "rapid_spin", "protect", "water_pulse", "aqua_tail", "skull_bash",
	"iron_defense", "rain_dance", "hydro_pump", "flash_cannon"]

class Idle:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position + Vector2.RIGHT * 30.0
	func want_dodge(_w) -> bool: return false
	func want_skill(_i, _w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

func _world(species: String = "bulbasaur") -> World:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var w := World.new()
	add_child_autofree(w)
	w.setup(7, species, 20, ["tackle"], Idle.new())
	w.player.position = Arena.center()
	return w

func _enemy(w: World, species: String = "caterpie", off: Vector2 = Vector2(30, 0)) -> Enemy:
	var e := Enemy.new()
	e.setup_enemy(species, 12, w.rng)
	e.position = w.player.position + off
	e.frozen = true
	for k in e.cds:
		e.cds[k] = 999.0
	w.add_child(e)
	w.enemies.append(e)
	return e

func _run(w: World, sec: float) -> void:
	var t := 0.0
	while t < sec:
		w.step(1.0 / 60.0)
		t += 1.0 / 60.0

func test_all_new_moves_are_shaped_and_learnable() -> void:
	for id in BULBA + SQUIRT:
		assert_true(MoveDB.is_shaped(id), "모양 있음: " + id)
	# 최신 표(사용자 결정 2026-11-02): 거품·로켓박치기는 꼬북이 표에서 빠졌고 껍질깨기·웨이브태클은 아직 모양이 없다. 구현은 남긴다.
	assert_eq(SpeciesDB.learnable("bulbasaur", 40).size(), 14, "이상해씨 습득 기술 전부(몸통박치기·울음소리 포함)")
	assert_eq(SpeciesDB.learnable("squirtle", 40).size(), 12, "꼬북이 습득 기술 전부")
	assert_true(SpeciesDB.learnable("ivysaur", 50).has("solar_beam"))
	assert_true(SpeciesDB.learnable("venusaur", 32).has("petal_dance"))
	assert_true(SpeciesDB.learnable("blastoise", 1).has("flash_cannon"))

func test_each_damaging_move_hurts_and_status_moves_apply() -> void:
	for id in BULBA + SQUIRT:
		var w := _world("squirtle" if SQUIRT.has(id) else "bulbasaur")
		var e := _enemy(w)
		w.player.hp = w.player.max_hp - 10
		var hp0 := e.hp
		w.cast(w.player, id, Vector2.RIGHT, e.position)
		_run(w, 2.4)     # 씨뿌리기는 심긴 뒤 한 턴(1.5초)에 첫 흡수
		var m := MoveDB.get_move(id)
		if float(m.get("power", 0)) > 0.0:
			assert_lt(e.hp, hp0, "피해: " + id)
		match id:
			"sleep_powder": assert_gt(e.sleep_t + float(e.sleep_t == 0.0 and e.hp < hp0), 0.0, "잠: " + id)
			"poison_powder": assert_eq(e.poison_t, 0.0, "독은 잠겨 있다(Mon.poison_unlocked)")
			"leech_seed": assert_true(e.hp < hp0, "씨뿌리기로 HP 가 빠진다")
			"worry_seed": assert_true(e.insomnia, "불면")
			"sweet_scent": assert_eq(e.eva_stage, -1, "회피 −1")
			"growth": assert_eq(w.player.spa_stage, 1)
			"withdraw": assert_eq(w.player.def_stage, 1)
			"iron_defense": assert_eq(w.player.def_stage, 2)
			"synthesis": assert_eq(w.player.hp, w.player.max_hp, "광합성 회복")
			"rain_dance": assert_eq(w.weather, "rain")
		w.queue_free()

func test_sleep_stops_acting_and_insomnia_blocks() -> void:
	var w := _world()
	var e := _enemy(w)
	w.cast(w.player, "sleep_powder", Vector2.RIGHT, e.position)
	_run(w, 0.5)
	assert_gt(e.sleep_t, 0.0, "잠들었다")
	assert_false(e.can_act(), "자는 동안 못 움직인다")
	var e2 := _enemy(w, "weedle", Vector2(0, 30))
	e2.insomnia = true
	w.cast(w.player, "sleep_powder", Vector2.DOWN, e2.position)
	_run(w, 0.5)
	assert_eq(e2.sleep_t, 0.0, "불면이면 안 잔다")

func test_protect_blocks_and_chain_fails_half() -> void:
	var w := _world("squirtle")
	var e := _enemy(w)
	w.cast(w.player, "protect", Vector2.RIGHT, e.position)
	var hp0 := w.player.hp
	w.apply_hit(w.player, w.make_hit(e, "tackle"), e.position)
	w.apply_hit(w.player, w.make_hit(e, "tackle"), e.position)
	assert_eq(w.player.hp, hp0, "방어 중(한 턴)엔 몇 발이든 피해 없음")
	assert_gt(w.player.protect_t, 0.0, "막아도 시간이 남아 있으면 계속 방어")
	var ok := 0
	for i in 400:
		w.player.protect_chain = 1
		w.player.protect_gap = 0.5
		w.player.protect_t = 0.0
		w._protect(w.player)
		if w.player.protect_t > 0.0:
			ok += 1
	assert_between(ok, 150, 250, "연달아 쓰면 1/2 확률")

func test_rain_boosts_water_halves_fire_and_solar_beam() -> void:
	var w := _world()
	w.start_weather("rain", 5.0)
	assert_eq(w.weather_mult("water"), 1.5)
	assert_eq(w.weather_mult("fire"), 0.5)
	assert_eq(float(w.make_hit(w.player, "solar_beam")["power"]), 60.0, "비 오면 솔라빔 절반")
	_run(w, 7.6)
	assert_eq(w.weather, "", "5턴(7.5초) 뒤 그친다")
	assert_eq(float(w.make_hit(w.player, "solar_beam")["power"]), 120.0)

func test_recoil_leech_and_spa_stage() -> void:
	var w := _world()
	var e := _enemy(w, "metapod")
	var hp0 := w.player.hp
	w.cast(w.player, "double_edge", Vector2.RIGHT, e.position)
	_run(w, 0.6)
	assert_lt(w.player.hp, hp0, "이판사판태클 반동")
	# 남은 HP 보다 큰 피해여도 반동은 상대가 실제로 잃은 HP 의 1/3(원작).
	var w3 := _world()
	var e3 := _enemy(w3, "caterpie")
	e3.hp = 6
	var hp3 := w3.player.hp
	w3.cast(w3.player, "double_edge", Vector2.RIGHT, e3.position)
	_run(w3, 0.6)
	assert_eq(hp3 - w3.player.hp, 2, "6 잃었으면 반동 2")
	# 씨뿌리기: 한 턴마다 최대 HP 1/8 을 빼앗아 쓴 쪽이 회복.
	var w2 := _world()
	var e2 := _enemy(w2, "metapod")
	w2.player.hp = 5
	e2.inflict("leech")
	e2.leech_by = w2.player
	_run(w2, 2.0)
	assert_gt(w2.player.hp, 5, "흡수로 회복")
	assert_lt(e2.hp, e2.max_hp)
	# 성장: 특수공격 랭크가 특수 기술의 공격에 곱해진다.
	var a0 := int(w2.make_hit(w2.player, "solar_beam")["atk"])
	w2.player.spa_stage = 2
	assert_eq(int(w2.make_hit(w2.player, "solar_beam")["atk"]), a0 * 2, "+2 = 2배")

func test_confusion_self_hit_half_and_petal_dance_confuses() -> void:
	var w := _world()
	w.god = true
	var e := _enemy(w)
	w.player.confuse_t = 999.0
	var selfhits := 0
	for i in 300:
		if w.confusion_self_hit(w.player):
			selfhits += 1
	assert_between(selfhits, 110, 190, "혼란 중 약 50% 자신을 친다")
	w.player.confuse_t = 0.0
	w.cast(w.player, "petal_dance", Vector2.RIGHT, e.position)
	assert_gt(w.player.rampage_t, 2.9, "난동 2~3턴(3~4.5초)")
	_run(w, 4.7)
	assert_gt(w.player.confuse_t, 0.0, "난동이 끝나면 혼란")

func test_sweet_scent_is_a_circle_around_the_user() -> void:
	var w := _world()
	var front := _enemy(w, "caterpie", Vector2(30, 0))
	var back := _enemy(w, "weedle", Vector2(-30, 0))
	var far := _enemy(w, "metapod", Vector2(0, 4 * MoveShapes.T))
	w.cast(w.player, "sweet_scent", Vector2.RIGHT, front.position)
	_run(w, 0.5)
	assert_eq(front.eva_stage, -1, "앞")
	assert_eq(back.eva_stage, -1, "뒤도 맞는다(원형)")
	assert_eq(far.eva_stage, 0, "2.5칸 밖은 안 맞는다")

func test_stages_reset_when_no_enemies_left() -> void:
	var w := _world()
	var e := _enemy(w)
	w.player.spa_stage = 2
	w.player.def_stage = 1
	_run(w, 0.2)
	assert_eq(w.player.spa_stage, 2, "적이 있는 동안은 그대로")
	w.damage(e, 9999)
	_run(w, 1.5)
	assert_eq(w.player.spa_stage, 0, "적이 없어지면(배틀 끝) 초기화")
	assert_eq(w.player.def_stage, 0)

func test_poison_burn_leech_tick_once_per_turn_and_last() -> void:
	Mon.poison_unlocked = true      # 잠금을 풀었을 때의 규칙(지금은 잠겨 있다)
	Mon.burn_unlocked = true
	var w := _world()
	var e := _enemy(w, "metapod")
	e.max_hp = 80
	e.hp = 80
	e.inflict("poison")
	_run(w, Mon.TURN - 0.1)
	assert_eq(e.hp, 80, "한 턴이 지나기 전엔 안 깎인다")
	_run(w, 0.2)
	assert_eq(e.hp, 70, "한 턴에 최대 HP 1/8(80 → 10)")
	_run(w, Mon.TURN * 3)
	assert_eq(e.hp, 40, "고칠 때까지 계속(턴마다 10)")
	assert_gt(e.poison_t, 0.0)
	# 화상도 1/8(4세대), 최소 1.
	var e2 := _enemy(w, "caterpie", Vector2(0, 40))
	e2.max_hp = 5
	e2.hp = 5
	e2.inflict("burn")
	_run(w, Mon.TURN + 0.05)
	assert_eq(e2.hp, 4, "최대 HP 5 의 1/8 은 최소 1")
	# 씨뿌리기는 오래 지나도 안 풀린다(쓰러질 때까지).
	var w3 := _world()
	var e3 := _enemy(w3, "metapod")
	e3.max_hp = 800
	e3.hp = 800
	e3.inflict("leech")
	e3.leech_by = w3.player
	_run(w3, Mon.TURN * 6 + 0.1)
	assert_eq(e3.hp, 200, "6턴 × 100")
	assert_gt(e3.leech_t, 0.0, "아직 심겨 있다")
	Mon.poison_unlocked = false
	Mon.burn_unlocked = false

func test_poison_and_burn_are_locked() -> void:
	var w := _world()
	var e := _enemy(w, "metapod")
	e.inflict("poison")
	e.inflict("burn")
	assert_eq(e.poison_t, 0.0)
	assert_eq(e.burn_t, 0.0)
	w.apply_status_move(e, w.make_hit(w.player, "poison_powder"))
	assert_eq(e.poison_t, 0.0, "독가루도 효과 없음")

func test_leech_ends_when_seeder_faints() -> void:
	var w := _world()
	var seeder := _enemy(w, "caterpie", Vector2(0, 40))
	var e := _enemy(w, "metapod")
	e.inflict("leech")
	e.leech_by = seeder
	_run(w, Mon.TURN + 0.1)
	assert_lt(e.hp, e.max_hp, "심겨서 빼앗긴다")
	w.damage(seeder, 9999)
	_run(w, 0.1)
	assert_eq(e.leech_t, 0.0, "심은 쪽이 쓰러지면 풀린다")

func test_charge_moves_are_windup_plus_one_turn() -> void:
	assert_almost_eq(float(MoveDB.get_move("solar_beam")["cast_delay"]), 0.25 + Mon.TURN, 0.001)
	assert_almost_eq(float(MoveDB.get_move("skull_bash")["cast_delay"]), 0.25 + Mon.TURN, 0.001)

func test_string_shot_lowers_speed_stage_only() -> void:
	var w := _world()
	var e := _enemy(w, "caterpie", Vector2(60, 0))
	var sp0 := w.player.move_speed()
	w.cast(e, "string_shot", Vector2.LEFT, w.player.position)
	_run(w, 1.0)
	assert_eq(w.player.spe_stage, -1, "스피드 랭크 −1")
	assert_eq(w.player.slow_t, 0.0, "따로 느려지지 않는다")
	assert_almost_eq(w.player.move_speed(), sp0 * Mon.stage_mult(-1), 0.5, "랭크만큼 이동 속도가 준다")

func test_gym_moves_defense_curl_bind_rock_tomb() -> void:
	var w := _world("charmander")
	w.player.max_hp = 160
	w.player.hp = 160
	var onix := Enemy.new()
	onix.setup_trainer_mon("onix", 14, ["tackle", "bind", "rock_tomb"], w.rng)
	onix.position = w.player.position + Vector2(20, 0)
	onix.frozen = true
	for k in onix.cds:
		onix.cds[k] = 999.0      # 스스로는 안 쓰게(테스트가 직접 쓴다)
	w.add_child(onix)
	w.enemies.append(onix)
	assert_true(onix.trainer_owned and onix.ivs.is_empty() and not onix.shiny, "트레이너 포켓몬: 개체값 0, 이로치 아님")
	# 웅크리기
	var geo := _enemy(w, "geodude", Vector2(0, 60))
	w.cast(geo, "defense_curl", Vector2.UP, w.player.position)
	assert_eq(geo.def_stage, 1, "웅크리기 방어 +1")
	# 조이기: 2~5턴, 턴마다 1/16, 조인 쪽이 쓰러지면 풀림
	var hits := 0
	for i in 20:
		w.cast(onix, "bind", Vector2.LEFT, w.player.position)
		_run(w, 0.4)
		if w.player.bind_t > 0.0:
			break
		hits += 1
	assert_gt(w.player.bind_t, 0.0, "조이기에 걸렸다(명중 75)")
	assert_between(w.player.bind_t, 2.0 * Mon.TURN - 0.5, 5.0 * Mon.TURN, "2~5턴")
	var hp0 := w.player.hp
	_run(w, Mon.TURN + 0.05)
	assert_eq(hp0 - w.player.hp, 160 / 16, "한 턴에 최대 HP 1/16")
	w.damage(onix, 9999)
	_run(w, 0.1)
	assert_eq(w.player.bind_t, 0.0, "조인 쪽이 쓰러지면 풀린다")
	# 암석봉인: 조준한 자리에 떨어져 피해 + 스피드 −1
	var w2 := _world("charmander")
	var o2 := Enemy.new()
	o2.setup_trainer_mon("onix", 14, ["rock_tomb"], w2.rng)
	o2.position = w2.player.position + Vector2(70, 0)
	o2.frozen = true
	for k in o2.cds:
		o2.cds[k] = 999.0
	w2.add_child(o2)
	w2.enemies.append(o2)
	var got := false
	for i in 10:
		var h := w2.player.hp
		w2.cast(o2, "rock_tomb", Vector2.LEFT, w2.player.position)
		_run(w2, 0.8)
		if w2.player.hp < h:
			got = true
			break
	assert_true(got, "암석봉인이 맞는다(명중 80)")
	assert_eq(w2.player.spe_stage, -1, "스피드 −1(100%)")

# ── 기술머신 기술(사용자 결정 2026-10-30, C안): 구멍파기·소금물·기가드레인·깨뜨리다·오물폭탄·객기 ──

func _dmg(w: World, e: Enemy, id: String, sec: float = 1.2) -> int:
	var hp0 := e.hp
	w.cast(w.player, id, Vector2.RIGHT, e.position)
	_run(w, sec)
	return hp0 - e.hp

func test_dig_hides_then_hits_with_recovery() -> void:
	var w := _world("charmander")
	var e := _enemy(w)
	var hp0 := e.hp
	w.cast(w.player, "dig", Vector2.RIGHT, e.position)
	_run(w, 0.5)
	assert_false(w.player.burrow.is_empty(), "땅속")
	assert_gt(w.player.invuln_t, 0.0, "땅속에선 무적")
	var hit := w.make_hit(e, "tackle")
	assert_false(w.apply_hit(w.player, hit, e.position), "땅속에선 맞지 않는다")
	assert_eq(e.hp, hp0, "땅속에 있는 동안은 피해 없음")
	_run(w, 2.0)      # 0.25 가라앉기 + 2초 뒤 솟구침
	assert_true(w.player.burrow.is_empty(), "솟구쳤다")
	assert_lt(e.hp, hp0, "솟구치며 둘레 상대에게 피해")
	assert_gt(w.player.recover_t, 0.0, "후딜")
	_run(w, 1.0)
	assert_eq(w.player.recover_t, 0.0, "후딜 끝")

func test_brine_doubles_below_half() -> void:
	var w := _world("squirtle")
	var e := _enemy(w, "caterpie", Vector2(40, 0))
	e.max_hp = 400
	e.hp = 400
	var full := _dmg(w, e, "brine")
	e.hp = 150
	var low := _dmg(w, e, "brine")
	assert_gt(full, 0, "소금물 피해")
	assert_gt(float(low), float(full) * 1.5, "HP 절반 이하면 2배(%d → %d)" % [full, low])

func test_giga_drain_heals_from_forward_target() -> void:
	var w := _world("bulbasaur")
	var far := _enemy(w, "caterpie", Vector2(80, 0))
	var near := _enemy(w, "caterpie", Vector2(-30, 10))
	w.player.hp = 10
	var hp0 := far.hp
	w.cast(w.player, "giga_drain", Vector2.RIGHT, far.position)
	_run(w, 1.0)
	assert_lt(far.hp,hp0,"조준 방향의 상대에게서 흡수")
	assert_eq(near.hp,near.max_hp,"시전자 뒤쪽은 범위 밖")
	assert_gt(w.player.hp, 10, "준 피해의 절반 회복")

func test_brick_break_ignores_defense_boost() -> void:
	var w := _world("charmander")
	var e := _enemy(w, "caterpie", Vector2(22, 0))
	e.max_hp = 400
	e.hp = 400
	var plain := _dmg(w, e, "brick_break")
	e.position = w.player.position + Vector2(22, 0)     # 맞고 밀려난 자리에서 다시 앞으로
	e.def_stage = 6
	var boosted := _dmg(w, e, "brick_break")
	assert_gt(float(boosted), float(plain) * 0.75, "방어 +6 이어도 거의 그대로(%d → %d)" % [plain, boosted])
	e.position = w.player.position + Vector2(22, 0)
	var scratch := _dmg(w, e, "scratch")
	assert_lt(float(scratch), float(plain) * 0.6, "할퀴기는 방어 +6 에 막힌다(%d)" % scratch)

func test_sludge_bomb_and_facade() -> void:
	var w := _world("bulbasaur")
	var e := _enemy(w, "caterpie", Vector2(40, 0))
	e.max_hp = 400
	e.hp = 400
	assert_gt(_dmg(w, e, "sludge_bomb"), 0, "오물폭탄 피해")
	var w2 := _world("charmander")
	var e2 := _enemy(w2, "caterpie", Vector2(30, 0))
	e2.max_hp = 400
	e2.hp = 400
	var plain := _dmg(w2, e2, "facade")
	e2.position = w2.player.position + Vector2(30, 0)     # 밀려난 자리에서 다시 앞으로(넉백이 돌진 2칸보다 길어졌다)
	w2.player.poison_t = 1.0
	var statused := _dmg(w2, e2, "facade")
	assert_gt(float(statused), float(plain) * 1.5, "독이면 객기 2배(%d → %d)" % [plain, statused])
	assert_eq(MoveDB.pp_of("facade"), 20, "PP 는 원작 그대로")

# 물대포는 앞의 상대가 쓰러져도 직선 경로를 계속 진행한다.
func test_water_gun_hits_the_second_target_in_line() -> void:
	var w := _world("squirtle")
	var near := _enemy(w, "caterpie", Vector2(40, 0))
	near.hp = 1
	var far := _enemy(w, "caterpie", Vector2(75, 0))
	w.cast(w.player, "water_gun", Vector2.RIGHT, near.position)
	_run(w, 1.0)
	assert_true(near.dead, "첫 방울에 쓰러진다")
	assert_lt(far.hp,far.max_hp,"직선 위 두 번째 상대에게도 명중")

# ── 최신 습득표로 들어온 기술(사용자 결정 2026-11-02, A안) ──
const LATEST := ["dragon_breath", "bug_bite", "thunder_wave", "rollout", "rock_polish", "rock_throw", "smack_down", "bulldoze"]

func test_latest_moves_shaped_with_data() -> void:
	for id in LATEST:
		assert_true(MoveDB.is_shaped(id), "모양 있음: " + id)
	assert_eq(MoveDB.get_move("bulldoze")["type"], "ground", "5세대 기술은 PokeAPI 값으로 보충")
	assert_eq(int(MoveDB.get_move("bulldoze")["power"]), 60)
	assert_eq(int(MoveDB.get_move("bulldoze")["gen"]), 5)
	assert_eq(MoveDB.get_move("smack_down")["cat"], "physical")
	assert_almost_eq(float(MoveDB.get_move("dragon_breath")["paralyze"]), 0.3, 0.001, "용의숨결 30% 마비")
	assert_almost_eq(float(MoveDB.get_move("thunder_wave")["paralyze"]), 1.0, 0.001, "전기자석파는 확정")
	assert_eq(Lang.move_name("bulldoze"), "땅고르기" if Lang.is_ko() else "BULLDOZE")

func test_dragon_breath_and_rocks_hit() -> void:
	var w := _world("charmander")
	var e := _enemy(w, "caterpie", Vector2(40, 0))
	e.max_hp = 400
	e.hp = 400
	assert_gt(_dmg(w, e, "dragon_breath"), 0, "용의숨결 피해")
	e.position = w.player.position + Vector2(40, 0)
	assert_gt(_dmg(w, e, "rock_throw"), 0, "돌떨구기 피해")
	e.position = w.player.position + Vector2(40, 0)      # 돌떨구기 넉백으로 밀려난 자리에서 다시 앞으로
	assert_gt(_dmg(w, e, "smack_down"), 0, "떨어뜨리기 피해")
	e.position = w.player.position + Vector2(22, 0)
	assert_gt(_dmg(w, e, "bug_bite"), 0, "벌레먹음 피해")

func test_thunder_wave_paralyzes_but_not_ground() -> void:
	var w := _world("charmander")
	var e := _enemy(w, "caterpie", Vector2(30, 0))
	var normal := e.move_speed()
	w.cast(w.player, "thunder_wave", Vector2.RIGHT, e.position)
	_run(w, 0.5)
	assert_gt(e.para_t, 0.0, "마비(원작 그대로, 사용자 결정 2026-11-02): 고칠 때까지")
	assert_almost_eq(e.move_speed(), normal * Mon.PARA_SPEED, 0.01, "이동 속도 1/4(4세대)")
	assert_eq(e.status_name(), "paralyze")
	var g := _enemy(w, "geodude", Vector2(30, 0))
	e.position = w.player.position + Vector2(-60, 0)
	w.cast(w.player, "thunder_wave", Vector2.RIGHT, g.position)
	_run(w, 0.5)
	assert_eq(g.para_t, 0.0, "땅 타입엔 안 걸린다(전기 무효)")
	_run(w, 3.0)
	assert_gt(e.para_t, 0.0, "시간이 지나도 안 풀린다")

func test_full_paralysis_blocks_skill_sometimes() -> void:
	var w := _world("charmander")
	var e := _enemy(w, "caterpie", Vector2(30, 0))
	e.inflict("paralyze")
	var fails := 0
	for i in 400:
		e.para_lock_t = 0.0
		if w.full_paralysis(e):
			fails += 1
			assert_almost_eq(e.para_lock_t, Mon.TURN, 0.001, "막히면 한 턴 동안 기술 못 씀")
	assert_between(fails, 60, 140, "25%% 쯤 몸이 저린다(%d/400)" % fails)
	e.para_t = 0.0
	assert_false(w.full_paralysis(e), "마비가 아니면 늘 나간다")
	# 내 포켓몬: 저린 동안은 연타해도 PP 가 줄지 않고, 풀리면 다시 나간다.
	w.player.controller = Masher.new()
	w.player.inflict("paralyze")
	w.player.para_lock_t = 1.0
	var pp0 := int(w.player.pp[0])
	_run(w, 0.9)
	assert_eq(int(w.player.pp[0]), pp0, "저린 동안은 기술이 안 나간다")
	w.player.para_t = 0.0
	w.player.para_lock_t = 0.0
	_run(w, 0.6)
	assert_lt(int(w.player.pp[0]), pp0, "풀리면 쓴다")

class Masher:
	extends Idle
	func want_skill(i: int, _w) -> bool: return i == 0

func test_rock_polish_and_bulldoze() -> void:
	var w := _world("charmander")
	var a := _enemy(w, "caterpie", Vector2(28, 0))      # 적이 없으면 '배틀 끝' 으로 랭크가 바로 초기화된다
	var b := _enemy(w, "caterpie", Vector2(-28, 0))
	a.max_hp = 400; a.hp = 400; b.max_hp = 400; b.hp = 400
	w.cast(w.player, "rock_polish", Vector2.RIGHT, w.player.position)
	_run(w, 1.0)
	assert_eq(w.player.spe_stage, 2, "록커트 스피드 +2")
	w.cast(w.player, "bulldoze", Vector2.RIGHT, a.position)
	_run(w, 0.6)
	assert_lt(a.hp, 400, "앞쪽도")
	assert_lt(b.hp, 400, "뒤쪽도 맞는다(360도)")
	assert_eq(a.spe_stage, -1, "스피드 −1 확정")

func test_rollout_ramps_when_chained() -> void:
	var w := _world("charmander")
	var e := _enemy(w, "caterpie", Vector2(30, 0))
	e.max_hp = 900
	e.hp = 900
	var first := _dmg(w, e, "rollout")
	assert_gt(first, 0)
	e.position = w.player.position + Vector2(30, 0)
	var second := _dmg(w, e, "rollout")
	assert_eq(w.player.ramp_n, 1, "3초 안에 이어 쓰면 누적")
	assert_gt(float(second), float(first) * 1.5, "두 번째는 2배쯤(%d → %d)" % [first, second])
	w.player.ramp_t = 0.0
	e.position = w.player.position + Vector2(30, 0)
	_dmg(w, e, "rollout")
	assert_eq(w.player.ramp_n, 0, "끊기면 처음부터")

func test_overlapping_casts_keep_independent_recipients() -> void:
	var w:=_world("squirtle")
	var foe:=_enemy(w,"chansey",Vector2(24,0))
	foe.hp=100
	foe.max_hp=100
	var packets: Array[Dictionary]=[]
	for i in 2:
		w.cast(w.player,"water_gun",Vector2.RIGHT,foe.position)
		var hit: Dictionary=w.bursts.back().hit
		hit.fixed=5
		packets.append(hit)
	for index in [0,1,0,1]:
		foe.invuln_t=0
		w.apply_hit(foe,packets[index],w.player.position)
	assert_eq(foe.hp,90,"두 시전이 교차해도 같은 시전의 뒷방울은 재타격하지 않는다")
