extends GutTest

# 후딜레이(사용자 정의 2026-10-30): 스킬 동작이 끝난 뒤 다음 다른 스킬을 쓰기까지의 딜레이(Player.skill_lock_t) — 연타를 막는다.
# 움직임은 막지 않고 자세도 붙잡지 않는다.

class Masher:
	extends RefCounted
	var slot := 0
	func move_dir(_w) -> Vector2: return Vector2.RIGHT
	func aim_point(w) -> Vector2: return w.player.position + Vector2.RIGHT * 30.0
	func want_dodge(_w) -> bool: return false
	func want_skill(i, _w) -> bool: return slot >= 0 and (i == slot or slot == 9)
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

class Still:
	extends Masher
	func move_dir(_w) -> Vector2: return Vector2.ZERO

func _world(moves: Array) -> World:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var w := World.new()
	add_child_autofree(w)
	w.setup(7, "charmander", 20, moves, Masher.new())
	w.player.position = Arena.center()
	return w

func _run(w: World, frames: int) -> void:
	for i in frames:
		w.step(1.0 / 60.0)

func test_mashing_waits_for_action_plus_delay() -> void:
	var w := _world(["scratch", "ember"])
	(w.player.controller as Masher).slot = 9        # 두 칸 다 연타
	_run(w, 1)
	var pp0 := int(w.player.pp[0]) + int(w.player.pp[1])
	assert_gt(w.player.skill_lock_t, MoveDB.recover_of("scratch"), "동작 길이 + 후딜레이 동안 잠긴다")
	assert_false(w.player.can_act(), "근접 동작 중엔 제자리(사용자 지적 2026-10-30)")
	_run(w, 30)
	assert_eq(int(w.player.pp[0]) + int(w.player.pp[1]), pp0, "0.5초 동안 다른 칸도 못 쓴다(연타 금지)")
	_run(w, int(ceil(w.player.attack_anim_t * 60.0)) + 1) # Wait through the grounded settle.
	assert_true(w.player.can_act(), "동작이 끝나면 후딜레이 중에도 걸을 수 있다")
	assert_gt(w.player.skill_lock_t, 0.0, "아직 후딜레이")
	w.step(1.0 / 60.0)
	assert_ne(w.player.vel, Vector2.ZERO, "그동안 걸을 수는 있다")
	_run(w, 50)
	assert_lt(int(w.player.pp[0]) + int(w.player.pp[1]), pp0, "동작 + 후딜레이가 지나면 다음 스킬")

func test_dash_stops_on_contact() -> void:
	var w := _world(["facade"])
	(w.player.controller as Masher).slot = -1
	var e := Enemy.new()
	e.setup_enemy("caterpie", 12, w.rng)
	e.position = w.player.position + Vector2(20, 0)
	e.frozen = true
	for k in e.cds:
		e.cds[k] = 999.0
	w.add_child(e)
	w.enemies.append(e)
	w.cast(w.player, "facade", Vector2.RIGHT, e.position)
	_run(w, 3)
	assert_false(w.player.is_dashing(), "포켓몬에 닿으면 돌진이 거기서 끝난다(2칸을 다 가지 않음)")
	assert_lt(w.player.position.x, Arena.center().x + 30.0, "상대를 뚫고 지나가지 않는다")

func test_dash_locks_after_dash_and_charge_after_fire() -> void:
	var w := _world(["facade"])
	_run(w, 1)
	assert_true(w.player.is_dashing(), "돌진 중")
	var lock_during := w.player.skill_lock_t
	_run(w, 20)
	assert_gt(w.player.skill_lock_t, lock_during, "돌진이 끝난 뒤부터 후딜레이")
	var w2 := _world(["giga_drain"])
	_run(w2, 1)
	assert_eq(w2.player.skill_lock_t, 0.0, "모으는 동안(선딜레이)은 아직")
	_run(w2, 36)
	assert_gt(w2.player.skill_lock_t, 0.0, "쏜 뒤 후딜레이")

func test_camera_follows_lunge_without_jump() -> void:
	# 몸통박치기: 달려드는 동안 화면이 몸을 따라가고, 동작이 끝나 자리가 옮겨지는 순간 튀지 않는다(사용자 요청 2026-10-30).
	var w := _world(["tackle"])
	(w.player.controller as Masher).slot = -1
	w.cast(w.player, "tackle", Vector2.RIGHT, w.player.position + Vector2.RIGHT * 20.0)
	var prev := w.player.cam_anchor()
	var biggest := 0.0
	var moved := false
	for i in 60:
		w.step(1.0 / 60.0)
		var now := w.player.cam_anchor()
		biggest = maxf(biggest, now.distance_to(prev))
		if w.cam != null:
			assert_eq(w.cam.position, now.round(), "카메라는 달려드는 몸을 따라간다")
		moved = moved or now.x > prev.x + 0.5
		prev = now
	assert_gt(w.player.position.x, Arena.center().x + 10.0, "자리가 앞으로 옮겨졌다")
	assert_true(moved, "화면이 동작 중에 조금씩 앞으로 갔다")
	assert_lt(biggest, 10.0, "한 프레임에 크게 튀지 않는다(자리 옮김 18px 가 한 번에 오지 않음, 최대 %.1f)" % biggest)
	assert_almost_eq(w.player.cam_anchor().x, w.player.position.x, 0.001, "동작이 끝나면 앵커 = 자리")

func test_scratch_and_tackle_glide_one_tile() -> void:
	# 할퀴기·몸통박치기: 공격하며 앞으로 약 1칸(사용자 요청 2026-11-02) — 미끄러지기(glide) + 도트의 달려듦.
	for mv in ["scratch", "tackle"]:
		var w := _world([mv])
		w.player.controller = Still.new()
		(w.player.controller as Masher).slot = -1
		var x0 := w.player.position.x
		w.cast(w.player, mv, Vector2.RIGHT, w.player.position + Vector2(80, 0))
		var m := MoveDB.get_move(mv)
		w.player.play_attack(String(m.get("anim", "Attack")), 0.0, bool(m.get("lunge", false)))
		_run(w, 3)                                   # _run 은 프레임 수
		assert_almost_eq(w.player.position.x, x0, 0.01, mv + ": 준비 자세에선 제자리(사용자 2026-11-02: 준비하며 미끄러져 어색)")
		_run(w, 12)                                  # 몸통박치기는 0.17초쯤부터 앞으로
		assert_gt(w.player.position.x, x0 + 1.0, mv + ": 팔을 뻗으며 나아간다")
		assert_lt(w.player.position.x, x0 + float(m["glide"]) + 0.01, mv + ": 한 번에 튀지 않는다")
		_run(w, 60)
		var moved := w.player.position.x - x0
		assert_between(moved, Arena.TILE * 0.8, Arena.TILE * 1.3, "%s: 약 1칸 전진(%.1fpx)" % [mv, moved])

func test_melee_hit_lands_on_reach_frame() -> void:
	# 맞는 순간 = 도트가 앞으로 다 나간 프레임(사용자 2026-11-02: 준비 동작에서 이미 데미지가 들어갔다).
	var w := _world(["scratch"])
	w.player.controller = Still.new()
	(w.player.controller as Masher).slot = -1
	var e := Enemy.new()
	e.setup_enemy("caterpie", 5, w.rng)
	e.max_hp = 900
	e.hp = 900
	e.frozen = true
	e.position = w.player.position + Vector2(22, 0)
	w.add_child(e)
	w.enemies.append(e)
	w.player.facing = Vector2.RIGHT
	var tm := w.player.lunge_timing("Strike")
	assert_gt(tm.y, 0.12, "할퀴기 손을 뻗는 프레임은 준비 동작 뒤")
	w.cast(w.player, "scratch", Vector2.RIGHT, e.position)
	w.player.play_attack("Strike", 0.0, true)
	_run(w, int(tm.y * 60.0) - 2)
	assert_eq(e.hp, 900, "준비 동작 동안은 안 맞는다")
	_run(w, 4)
	assert_lt(e.hp, 900, "손을 뻗은 순간 맞는다")

func test_scratch_keeps_recovery_and_eases_slide_in_all_directions() -> void:
	var w := _world(["scratch"])
	w.player.controller = Still.new()
	(w.player.controller as Masher).slot = -1
	for row in 8:
		var direction := Vector2.DOWN.rotated(-row * PI / 4.0)
		w.player.position = Arena.center()
		w.player.facing = direction
		w.cast(w.player, "scratch", direction, w.player.position + direction * 80.0)
		w.player.play_attack("Strike")
		assert_almost_eq(w.player.attack_anim_t, MonSprite.anim_length(w.player._sprites["Strike"]) + Mon.SCRATCH_DOWN_HOLD + Mon.SCRATCH_SETTLE, 0.001, "회복 프레임까지 재생")
		var origin := w.player.position
		var wait := float(w.player.glide["wait"])
		w._step_glide(w.player, wait)
		assert_almost_eq(w.player.position.distance_to(origin), 0.0, 0.001, "준비 중에는 제자리")
		var duration := float(w.player.glide["duration"])
		var previous := origin
		var distances := []
		for part in 4:
			w._step_glide(w.player, duration / 4.0)
			distances.append(w.player.position.distance_to(previous))
			previous = w.player.position
		assert_gt(distances[0], distances[1], "처음에 빠르게 파고든다")
		assert_lt(distances[3], distances[2], "전진 감속")
		assert_almost_eq(w.player.position.distance_to(origin), float(Arena.TILE), 0.01, "방향별 전진 거리 유지")
		w.pending_melee.clear()

func test_scratch_contact_pause_is_brief() -> void:
	var w := _world(["scratch"])
	var target := Mon.new()
	add_child_autofree(target)
	w._hitstop(target, {"move":"scratch", "src":w.player}, 1, false)
	assert_almost_eq(target.hitstop_t, World.HITSTOP_CONTACT, 0.001)
	assert_almost_eq(w.player.hitstop_t, World.HITSTOP_CONTACT, 0.001)

func test_scratch_uses_actual_motion_without_end_teleport() -> void:
	var w := _world(["scratch"])
	w.player.controller = Still.new()
	(w.player.controller as Masher).slot = -1
	w.player.facing = Vector2.RIGHT
	var origin := w.player.position
	w.cast(w.player, "scratch", Vector2.RIGHT, origin + Vector2(80, 0))
	w.player.play_attack("Strike")
	assert_false(w.player.attack_lunge, "도트의 이동을 마지막에 더하지 않는다")
	var follow_through := MonSprite.frame_start(w.player._sprites["Strike"], 4)
	assert_almost_eq(w.player.attack_sheet_time(follow_through + 0.05), follow_through, 0.001, "내려친 낮은 자세 유지")
	var prev := origin
	for i in 60:
		w.step(1.0 / 60.0)
		assert_lt(w.player.position.distance_to(prev), 10.0, "회복 종료에도 좌표가 튀지 않는다")
		prev = w.player.position
	assert_almost_eq(w.player.position.x - origin.x, float(Arena.TILE), 0.01)

func test_scratch_stops_at_first_contact_after_target_knockback() -> void:
	var w := _world(["scratch"])
	w.player.controller = Still.new()
	(w.player.controller as Masher).slot = -1
	w.player.facing = Vector2.RIGHT
	var origin := w.player.position
	var target := Enemy.new()
	target.setup_enemy("caterpie", 5, w.rng)
	target.max_hp = 900
	target.hp = 900
	target.frozen = true
	target.position = origin + Vector2(w.player.radius + target.radius + 0.5, 0)
	var target_start := target.position
	w.add_child(target)
	w.enemies.append(target)
	w.cast(w.player, "scratch", Vector2.RIGHT, target.position)
	w.player.play_attack("Strike")
	for frame in 60:
		w.step(1.0 / 60.0)
		assert_gte(w.player.position.distance_to(target.position), w.player.radius + target.radius - 0.1, "몸을 뚫고 지나가지 않는다")
	assert_lt(target.hp, 900, "접촉 후 적중")
	assert_gt(target.position.x, target_start.x, "상대가 밀려난다")
	assert_almost_eq(w.player.position.x - origin.x, 0.5, 0.02, "처음 몸에 닿은 자리에서 멈추고 밀려난 상대를 뒤쫓지 않는다")

func test_scratch_blocked_step_expires_without_overlap() -> void:
	var w := _world(["scratch"])
	var target := Enemy.new()
	target.setup_enemy("caterpie", 5, w.rng)
	target.position = w.player.position + Vector2(w.player.radius + target.radius, 0)
	w.add_child(target)
	w.enemies.append(target)
	var origin := w.player.position
	w.cast(w.player, "scratch", Vector2.RIGHT, target.position)
	for frame in 60: w._step_glide(w.player, 1.0 / 60.0) if not w.player.glide.is_empty() else null
	assert_true(w.player.glide.is_empty(), "움직이지 않는 상대 앞에서 무한 대기하지 않는다")
	assert_almost_eq(w.player.position.x, origin.x, 0.01)

func test_scratch_downstroke_stays_low_before_settling() -> void:
	var w := _world(["scratch"])
	w.player.facing = Vector2.RIGHT
	w.cast(w.player, "scratch", Vector2.RIGHT, w.player.position + Vector2(80, 0))
	w.player.play_attack("Strike")
	assert_eq(w.player.attack_pose_frame(3), 3, "타격 자세 유지")
	assert_eq(w.player.attack_pose_frame(1), 2, "준비 중 팔을 높이 든다")
	assert_eq(w.player.attack_pose_frame(6), 4, "내려친 낮은 자세 유지")
	assert_eq(w.player.attack_pose_frame(7), 4, "회복 중 팔을 다시 들지 않는다")
	assert_eq(w.player.attack_pose_frame(8), 1, "마지막은 준비 시작과 같은 기본 자세")
	for row in 8:
		var anim: Dictionary = w.player._sprites["Strike"]
		for source_frame in range(6, 9):
			var frame := w.player.attack_pose_frame(source_frame)
			var floor_y := MonSprite.frame_bottom(anim, row, frame)
			assert_gt(floor_y, 0.0, "각 방향 회복 프레임에 접지 픽셀이 있다")
	w.player.species_id = "charmeleon"
	assert_eq(w.player.attack_pose_frame(6), 6, "다른 종의 프레임 순서는 유지")

func test_scratch_settle_rises_smoothly_to_rest() -> void:
	var w := _world(["scratch"])
	w.cast(w.player, "scratch", Vector2.RIGHT, w.player.position + Vector2(80, 0))
	w.player.play_attack("Strike")
	var anim: Dictionary = w.player._sprites["Strike"]
	var start := MonSprite.frame_start(anim, 8)
	var end := MonSprite.anim_length(anim) + Mon.SCRATCH_SETTLE
	var low := w.player.attack_settle_scale(start)
	var middle := w.player.attack_settle_scale((start + end) / 2.0)
	assert_lt(low.y, middle.y)
	assert_lt(middle.y, 1.0)
	assert_eq(w.player.attack_settle_scale(end), Vector2.ONE)

func test_scratch_fast_step_finishes_before_long_low_hold() -> void:
	var w := _world(["scratch"])
	w.player.controller = Still.new()
	(w.player.controller as Masher).slot = -1
	w.player.facing = Vector2.RIGHT
	var origin := w.player.position
	w.cast(w.player, "scratch", Vector2.RIGHT, origin + Vector2(80, 0))
	w.player.play_attack("Strike")
	_run(w, 16)
	assert_almost_eq(w.player.position.x - origin.x, float(Arena.TILE), 0.01, "준비 후 빠르게 한 칸 진입 완료")
	var at := w.player.position
	_run(w, 8)
	assert_eq(w.player.position, at, "끝 자세를 유지할 때 더 미끄러지지 않는다")
	assert_gt(w.player.attack_anim_t, 0.0, "이동이 끝난 뒤에도 동작 유지")
	var low := MonSprite.frame_start(w.player._sprites["Strike"], 4)
	assert_almost_eq(w.player.attack_sheet_time(low + 0.18), low, 0.001)

func test_scratch_impact_camera_is_bounded_local_and_decays() -> void:
	var w := _world(["scratch"])
	var target := Mon.new()
	add_child_autofree(target)
	target.play_hit_feedback("normal", "physical", Vector2.RIGHT)
	w._hitstop(target, {"move":"scratch", "src":w.player}, 1, false)
	assert_gt(w.impact_camera_offset().length(), 0.0)
	assert_lt(target.hit_feedback_scale().y, 1.0)
	for i in 6: w._hitstop(target, {"move":"scratch", "src":w.player}, 1, false)
	assert_almost_eq(w.impact_camera_offset().length(), 1.2, 0.001, "복수 적중도 강도를 합산하지 않는다")
	w._hitstop(target, {"move":"scratch", "src":w.player}, 1, true)
	assert_almost_eq(w.impact_camera_offset().length(), 2.0, 0.001, "급소는 조금 더 강하게")
	w._tick_impact_camera(0.2)
	assert_eq(w.impact_camera_offset(), Vector2.ZERO)
	w._hitstop(target, {"move":"scratch"}, 1, false)
	assert_eq(w.impact_camera_offset(), Vector2.ZERO, "플레이어와 무관한 전투는 화면을 흔들지 않는다")
	w._hitstop(target, {"move":"scratch", "src":w.player}, 0, false)
	assert_eq(w.impact_camera_offset(), Vector2.ZERO, "피해가 없으면 화면 충격도 없다")

func test_tackle_shares_contact_impact_with_directional_camera() -> void:
	var w := _world(["tackle"])
	var target := Mon.new()
	add_child_autofree(target)
	for direction in [Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2.DOWN]:
		w._tick_impact_camera(1.0)
		w.player.facing = direction
		w.player.hitstop_t = 0.0
		target.hitstop_t = 0.0
		target.play_hit_feedback("normal", "physical", direction)
		w._hitstop(target, {"move":"tackle", "src":w.player}, 1, false)
		assert_almost_eq(target.hitstop_t, World.HITSTOP_CONTACT, 0.001)
		assert_almost_eq(w.player.hitstop_t, World.HITSTOP_CONTACT, 0.001)
		assert_lt(target.hit_feedback_scale().y, 1.0)
		assert_eq(w.impact_camera_direction, direction, "몸통이 충돌하는 방향으로 화면 충격")
		assert_almost_eq(w.impact_camera_offset().length(), 1.2, 0.001)
		w._hitstop(target, {"move":"tackle", "src":w.player}, 1, true)
		assert_almost_eq(target.hitstop_t, World.HITSTOP_CONTACT * World.HITSTOP_CRIT, 0.001)
		assert_almost_eq(w.impact_camera_offset().length(), 2.0, 0.001)
		w._hitstop(target, {"move":"tackle", "src":w.player}, 1, true)
		assert_almost_eq(w.impact_camera_offset().length(), 2.0, 0.001, "중첩 상한")
	w._tick_impact_camera(1.0)
	w._hitstop(target, {"move":"tackle", "src":w.player}, 0, false)
	assert_eq(w.impact_camera_offset(), Vector2.ZERO)
	w._hitstop(target, {"move":"tackle"}, 1, false)
	assert_eq(w.impact_camera_offset(), Vector2.ZERO)

func test_tackle_actual_hit_triggers_feedback_after_windup() -> void:
	var w := _world(["tackle"])
	w.player.controller = Still.new()
	(w.player.controller as Masher).slot = -1
	w.player.facing = Vector2.RIGHT
	var target := Enemy.new()
	target.setup_enemy("caterpie", 5, w.rng)
	target.hp = 900
	target.max_hp = 900
	target.frozen = true
	target.position = w.player.position + Vector2(25, 0)
	w.add_child(target)
	w.enemies.append(target)
	w.cast(w.player, "tackle", Vector2.RIGHT, target.position)
	w.player.play_attack("Attack", 0.0, true)
	assert_eq(w.impact_camera_t, 0.0, "준비 동작에는 충격 없음")
	var landed := false
	for frame in 40:
		w.step(1.0 / 60.0)
		if target.hp < 900:
			landed = true
			assert_gt(w.impact_camera_t, 0.0)
			assert_gt(target.hit_visual_squash, 0.0)
			assert_gt(target.knock.x, 0.0)
			break
	assert_true(landed)
