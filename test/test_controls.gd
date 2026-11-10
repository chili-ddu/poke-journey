extends GutTest

# 조작(사용자 결정 2026-11-02): 기술 Q·W·E·R, 이동은 방향키 또는 마우스 오른쪽 클릭, 도구 편성 1~4.

func before_all() -> void:
	Controllers.ensure_input_map()

func after_each() -> void:
	for a in Controllers.ACTIONS:
		Input.action_release(a)
	# Flush just-pressed edges so a previous jump cannot leak into the next test.
	await get_tree().process_frame

func _world() -> World:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var w := World.new()
	add_child_autofree(w)
	w.setup(7, "charmander", 12, ["scratch", "growl", "ember", "smoke_screen"], Controllers.Human.new())
	w.player.position = Arena.center()
	return w

func _run(w: World, sec: float) -> void:
	var t := 0.0
	while t < sec:
		w.step(1.0 / 60.0)
		t += 1.0 / 60.0

func test_qwer_map_to_four_slots() -> void:
	var c := Controllers.Human.new()
	for i in 4:
		Input.action_press("skill_%d" % i)
		assert_true(c.want_skill(i, null), "%s → %d번 칸" % [Player.SLOT_KEYS[i], i])
		for j in 4:
			if j != i:
				assert_false(c.want_skill(j, null))
		Input.action_release("skill_%d" % i)

func test_right_click_walks_to_point_and_arrows_cancel() -> void:
	var w := _world()
	var c: Controllers.Human = w.player.controller
	var goal := w.player.position + Vector2(60, 0)
	w.aim_override = func() -> Vector2: return goal
	Input.action_press("move_click")
	_run(w, 1.0 / 60.0)
	Input.action_release("move_click")
	assert_true(c.has_target, "오른쪽 클릭한 자리로 간다")
	_run(w, 2.0)
	assert_lt(w.player.position.distance_to(goal), 6.0, "그 자리에 닿는다")
	assert_false(c.has_target, "닿으면 멈춘다")
	# 다시 찍고 방향키를 누르면 그만두고 방향키대로
	goal = w.player.position + Vector2(-80, 0)
	Input.action_press("move_click")
	_run(w, 1.0 / 60.0)
	Input.action_release("move_click")
	Input.action_press("move_up")
	var y0 := w.player.position.y
	_run(w, 0.3)
	Input.action_release("move_up")
	assert_false(c.has_target, "방향키가 클릭 이동을 끊는다")
	assert_lt(w.player.position.y, y0 - 5.0, "방향키로 움직인다")

func test_hotbar_uses_assigned_item() -> void:
	var w := _world()
	var p := w.player
	p.add_item("oran_berry", 2)
	p.hp = 5
	assert_eq(p.hotbar[0], "oran_berry")
	Input.action_press("item_0")
	_run(w, 1.0 / 60.0)
	Input.action_release("item_0")
	assert_eq(p.berries, 1, "1번 = 오랭열매 하나 먹기")
	assert_gt(p.hp, 5)
	var used := []
	w.hotbar_used.connect(func(id: String) -> void: used.append(id))
	p.add_item("potion", 1)
	p.hotbar[1] = "potion"
	Input.action_press("item_1")
	_run(w, 1.0 / 60.0)
	Input.action_release("item_1")
	assert_eq(used, ["potion"], "다른 도구는 Game 이 가방에서 쓴 것처럼")
	p.hotbar[2] = "potion"
	p.bag.erase("potion")
	Input.action_press("item_2")
	_run(w, 1.0 / 60.0)
	assert_eq(used.size(), 1, "가방에 없으면 아무 일 없음")

func test_space_talks_before_jumping() -> void:
	# Space: 앞에 말 걸 사람이 있으면(Game 이 talk_ready 를 켠다) 점프하지 않는다(사용자 결정 2026-11-02).
	var w := _world()
	var c: Controllers.Human = w.player.controller
	w.talk_ready = true
	Input.action_press("jump")
	assert_false(c.want_jump(w), "말 걸 사람이 있으면 대화가 먼저")
	Input.action_release("jump")
	assert_eq(Lang.t("hint_talk").begins_with("Space") or Lang.t("hint_talk").begins_with("SPACE"), true, "안내도 Space")

func test_arrow_keys_aim_forward() -> void:
	# 방향키로 움직이는 중이면 기술은 바라보는 앞쪽으로(사용자 요청 2026-11-02), 마우스를 쓰면 커서 쪽.
	var w := _world()
	var c: Controllers.Human = w.player.controller
	w.aim_override = func() -> Vector2: return w.player.position + Vector2(0, 50)    # 커서는 아래
	Input.action_press("move_right")
	_run(w, 0.1)
	var aim: Vector2 = c.aim_point(w)
	assert_gt(aim.x - w.player.position.x, 40.0, "방향키 → 앞(오른쪽)으로 조준")
	assert_almost_eq(aim.y, w.player.position.y, 1.0)
	Input.action_release("move_right")
	assert_true(c.key_aim, "손을 떼도 마우스를 움직이기 전까지는 앞쪽")
	Input.action_press("move_click")
	c.aim_point(w)
	Input.action_release("move_click")
	assert_false(c.key_aim, "클릭하면 마우스 조준으로")
	assert_eq(Controllers.ACTIONS["move_click"], [MOUSE_BUTTON_LEFT], "이동은 왼쪽 클릭(사용자 2026-11-02)")

func test_skill_stops_click_move() -> void:
	# 기술을 쓰면 클릭 이동을 멈춘다(사용자 2026-11-02).
	var w := _world()
	var c: Controllers.Human = w.player.controller
	var goal := w.player.position + Vector2(120, 0)
	w.aim_override = func() -> Vector2: return goal
	Input.action_press("move_click")
	_run(w, 1.0 / 60.0)
	Input.action_release("move_click")
	assert_true(c.has_target)
	_run(w, 0.1)
	Input.action_press("skill_2")
	_run(w, 1.0 / 60.0)
	Input.action_release("skill_2")
	assert_false(c.has_target, "기술을 쓰면 클릭 이동은 그만")
	var fx_rings := w.fxs.filter(func(f): return f.kind == "dashring")
	assert_eq(fx_rings.size(), 0, "클릭 자리 표시는 없다")

func test_dialogue_hold_releases_without_polling_skills() -> void:
	var w := _world()
	var c: Controllers.Human = w.player.controller
	var goal := w.player.position + Vector2(60, 0)
	w.aim_override = func() -> Vector2: return goal
	c.hold = true
	Input.action_press("move_click")
	assert_eq(c.move_dir(w), Vector2.ZERO, "Closing dialogue click must not move")
	assert_true(c.hold)
	assert_false(c.has_target)
	Input.action_release("move_click")
	c.move_dir(w) # Indoor path: no want_skill call to release the lock.
	assert_false(c.hold)
	Input.action_press("move_click")
	assert_eq(c.move_dir(w), Vector2.RIGHT, "Fresh click works after healing dialogue")
	assert_true(c.has_target)
