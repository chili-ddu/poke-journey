extends GutTest

func after_each() -> void:
	for action in Controllers.ACTIONS:Input.action_release(action)
	await get_tree().process_frame

func world() -> World:
	Controllers.ensure_input_map()
	DungeonDB.set_current("test_meadow");Arena.configure(DungeonDB.theme())
	var w := World.new();add_child_autofree(w)
	w.setup(7,"charmander",12,["scratch","growl","ember","smoke_screen"],Controllers.Human.new())
	w.player.position = Arena.center()
	return w

func test_virtual_skills_hold_and_tap_without_mutating_keyboard_state() -> void:
	var w := world()
	var c: Controllers.Human = w.player.controller
	c.press_touch_key(KEY_E)
	assert_false(Input.is_action_pressed("skill_2"))
	var before: int = w.player.pp[2]
	w._step_player(1.0/60)
	assert_eq(w.player.pp[2],before-1)
	assert_true(c.want_skill(2,w))
	c.release_touch_key(KEY_E)
	c.consume_skill_presses(w)
	assert_false(c.want_skill(2,w))
	Input.action_press("skill_2")
	c.press_touch_key(KEY_E);c.release_touch_key(KEY_E)
	c.consume_skill_presses(w)
	assert_true(c.want_skill(2,w),"A virtual release cannot release a physical key")
	Input.action_release("skill_2")
	c.press_touch_key(KEY_Q);c.release_touch_key(KEY_Q)
	c.consume_skill_presses(w)
	assert_true(c.want_skill(0,w),"A tap between ticks gets one opportunity")
	c.consume_skill_presses(w)
	assert_false(c.want_skill(0,w))
	c.press_touch_key(KEY_E);c.press_touch_key(KEY_Q)
	c.consume_skill_presses(w)
	assert_eq(w.player.pp_focus_slot,0,"Latest touch press wins selection, like physical keys")

func test_blocked_virtual_press_has_feedback_and_does_not_queue_for_later() -> void:
	var w := world()
	var c: Controllers.Human = w.player.controller
	w.player.use_t[2] = 0.1
	var pp: int = w.player.pp[2]
	c.press_touch_key(KEY_E);c.release_touch_key(KEY_E)
	w._step_player(1.0/60)
	assert_gt(w.player.skill_denied_t,0.0)
	for i in 90:w._step_player(1.0/60)
	assert_eq(w.player.pp[2],pp)
	w.player.use_t[2] = 0
	c.press_touch_key(KEY_E);c.release_touch_key(KEY_E,true)
	w._step_player(1.0/60)
	assert_eq(w.player.pp[2],pp,"OS cancellation removes an unconsumed virtual press")

func test_virtual_hotbar_actually_uses_one_item_per_press() -> void:
	var w := world()
	var c: Controllers.Human = w.player.controller
	w.player.add_item("oran_berry",2);w.player.hp = 5
	c.press_touch_key(KEY_1)
	w.step(1.0/60)
	assert_eq(w.player.berries,1)
	assert_gt(w.player.hp,5)
	for i in 90:w.step(1.0/60)
	assert_eq(w.player.berries,1,"Holding a tool button cannot consume the next item")
	c.release_touch_key(KEY_1)

func test_jump_dodge_and_tools_are_edges_and_cleanup_drops_them() -> void:
	var w := world()
	var c: Controllers.Human = w.player.controller
	for key in [KEY_SPACE,KEY_SHIFT,KEY_1]:c.press_touch_key(key)
	c.consume_skill_presses(w)
	assert_true(c.want_jump(w));assert_true(c.want_dodge(w))
	assert_true(c.want_hotbar(0,w));assert_false(c.want_hotbar(0,w))
	c.consume_skill_presses(w)
	assert_false(c.want_jump(w));assert_false(c.want_dodge(w))
	c.press_touch_key(KEY_Q);c.hold = true
	c.consume_skill_presses(w)
	assert_false(c.want_skill(0,w))

func test_portrait_and_landscape_keys_stay_below_the_display_without_overlap() -> void:
	for surface in [Vector2(360,800),Vector2(390,844),Vector2(844,390),Vector2(384,216)]:
		var screen := MobileScreenLayout.calculate(surface,Vector2(384,216))
		var pad := MobilePadLayout.calculate(screen.controls)
		for key in pad.hits:
			var rect: Rect2 = pad.hits[key]
			assert_true(screen.controls.grow(0.01).encloses(rect),key)
			assert_false(rect.intersects(screen.display),key)
		for pair in [[pad.stick,pad.radius],[pad.aim,pad.aim_radius]]:
			var stick := Rect2(pair[0]-Vector2.ONE*float(pair[1]),Vector2.ONE*float(pair[1])*2)
			assert_true(screen.controls.grow(0.01).encloses(stick))
			assert_false(stick.intersects(screen.display))
			for key in pad.hits:assert_false(stick.intersects(pad.hits[key]),"Stick/button touch regions: "+key)
		var names: Array = pad.hits.keys()
		for i in names.size():
			for j in range(i+1,names.size()):assert_false(pad.hits[names[i]].intersects(pad.hits[names[j]]),"%s/%s"%[names[i],names[j]])

func test_all_auxiliary_keys_route_without_writing_real_preferences() -> void:
	var capture := Node.new();add_child_autofree(capture)
	var router := MobileKeyRouter.new();router.target = capture
	var pressed: Array[int] = []
	router.event_sink = func(event: InputEventKey) -> void:
		if event.pressed:pressed.append(event.physical_keycode)
	for key in ["language","view_minus","view_plus","look","map","fullscreen"]:router.press(key)
	assert_eq(pressed,[KEY_L,KEY_MINUS,KEY_EQUAL,KEY_F8,KEY_F9,KEY_F11])
