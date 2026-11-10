extends GutTest

class Harness:
	extends Node
	var world: World
	var bot := false
	var state := "fight"
	var cinematic := false
	var encounter = null
	var menu := ""
	var codes: Array[int] = []

class LoadingCover:
	extends Node
	var active := true

func before_all() -> void:Controllers.ensure_input_map()

func after_each() -> void:
	for action in Controllers.ACTIONS:Input.action_release(action)
	await get_tree().process_frame

func fixture() -> Dictionary:
	DungeonDB.set_current("test_meadow");Arena.configure(DungeonDB.theme())
	var game := Harness.new();add_child_autofree(game)
	var world := World.new();game.add_child(world);game.world = world
	world.setup(7,"charmander",12,["scratch","growl","ember","smoke_screen"],Controllers.Human.new())
	world.player.position = Arena.center()
	var pad := GamepadControls.new();pad.track_window_focus = false;pad.target_override = game
	game.add_child(pad);pad.set_process(false)
	pad.router.event_sink = func(event: InputEventKey) -> void:
		if event.pressed:game.codes.append(event.physical_keycode)
	pad.refresh_target()
	return {"game":game,"world":world,"pad":pad,"c":world.player.controller}

func button(f: Dictionary, index: int, pressed: bool, device: int=7) -> void:
	var event := InputEventJoypadButton.new();event.button_index = index;event.pressed = pressed;event.device = device
	assert_true(f.pad.handle_event(event))

func axis(f: Dictionary, index: int, value: float, device: int=7) -> void:
	var event := InputEventJoypadMotion.new();event.axis = index;event.axis_value = value;event.device = device
	assert_true(f.pad.handle_event(event))

func test_xy_shoulders_cast_all_four_slots_without_mutating_keyboard() -> void:
	for slot in 4:
		var f := fixture()
		var before: int = f.world.player.pp[slot]
		button(f,[JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER][slot],true)
		button(f,[JOY_BUTTON_X,JOY_BUTTON_Y,JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER][slot],false)
		f.world._step_player(1.0/60)
		assert_eq(f.world.player.pp[slot],before-1)
		assert_false(Input.is_action_pressed("skill_%d"%slot))
	var f := fixture()
	Input.action_press("skill_0")
	button(f,JOY_BUTTON_X,true);button(f,JOY_BUTTON_X,false)
	assert_true(Input.is_action_pressed("skill_0"))
	f.c.press_touch_key(KEY_Q);f.c.consume_skill_presses(f.world)
	f.c.clear_gamepad();assert_true(f.c.want_skill(0,f.world))
	Input.action_release("skill_0");f.c.clear_touch()
	button(f,JOY_BUTTON_X,true);f.c.clear_touch()
	assert_true(f.c.want_skill(0,f.world),"Touch cleanup cannot release a physical controller")

func test_blocked_pad_skill_uses_feedback_and_does_not_cast_later() -> void:
	var f := fixture()
	f.world.player.use_t[2] = 0.1
	var before: int = f.world.player.pp[2]
	button(f,JOY_BUTTON_LEFT_SHOULDER,true);button(f,JOY_BUTTON_LEFT_SHOULDER,false)
	f.world._step_player(1.0/60)
	assert_gt(f.world.player.skill_denied_t,0.0)
	for i in 90:f.world._step_player(1.0/60)
	assert_eq(f.world.player.pp[2],before)

func test_a_starts_a_real_jump_and_respects_talk_priority() -> void:
	var f := fixture()
	button(f,JOY_BUTTON_A,true);button(f,JOY_BUTTON_A,false)
	f.world._step_player(1.0/60)
	assert_gt(f.world.player.hop_t,0.0)
	f.world.talk_ready = true
	f.c.press_gamepad_key(KEY_SPACE);f.c.consume_skill_presses(f.world)
	assert_false(f.c.want_jump(f.world),"Talking takes priority over a controller jump")

func test_release_during_scene_gap_is_not_lost() -> void:
	var f := fixture();button(f,JOY_BUTTON_X,true)
	f.pad.target_override = null;f.pad.refresh_target()
	var release := InputEventJoypadButton.new();release.device = 7;release.button_index = JOY_BUTTON_X;release.pressed = false
	assert_false(f.pad.handle_event(release),"Unrelated scenes keep their input, while old controller releases are tracked")
	f.pad.target_override = f.game;f.pad.refresh_target()
	var before: int = f.world.player.pp[0]
	button(f,JOY_BUTTON_X,true);button(f,JOY_BUTTON_X,false)
	f.world._step_player(1.0/60)
	assert_eq(f.world.player.pp[0],before-1)

func test_loading_cover_tracks_releases_and_suppresses_new_commands() -> void:
	var f := fixture();button(f,JOY_BUTTON_X,true)
	var cover := LoadingCover.new();cover.name = "TitleGameTransition"
	get_tree().root.add_child(cover)
	f.pad.refresh_target()
	button(f,JOY_BUTTON_X,false);button(f,JOY_BUTTON_LEFT_SHOULDER,true);button(f,JOY_BUTTON_LEFT_SHOULDER,false)
	var pp: Array = f.world.player.pp.duplicate()
	f.world._step_player(1.0/60)
	assert_eq(f.world.player.pp,pp,"The loading cover cannot queue gameplay input")
	cover.active = false;f.pad.refresh_target()
	button(f,JOY_BUTTON_X,true);button(f,JOY_BUTTON_X,false)
	f.world._step_player(1.0/60)
	assert_eq(f.world.player.pp[0],int(pp[0])-1,"A is usable after its covered release")
	cover.queue_free();await get_tree().process_frame

func test_stick_deadzone_strength_camera_aim_and_release() -> void:
	var f := fixture()
	f.world.move_override = func(v: Vector2) -> Vector2:return v.rotated(PI/2)
	axis(f,JOY_AXIS_LEFT_X,0.1)
	assert_eq(f.c.move_dir(f.world),Vector2.ZERO)
	axis(f,JOY_AXIS_LEFT_X,0.6)
	assert_almost_eq(f.c.move_dir(f.world).y,0.5,0.001)
	f.world.player.facing = Vector2.LEFT
	assert_almost_eq((f.c.aim_point(f.world)-f.world.player.position).y,Controllers.Human.KEY_AIM_REACH,0.001)
	axis(f,JOY_AXIS_RIGHT_Y,-1.0)
	var aim: Vector2 = f.c.aim_point(f.world)-f.world.player.position
	assert_almost_eq(aim.x,Controllers.Human.KEY_AIM_REACH,0.001)
	axis(f,JOY_AXIS_RIGHT_Y,0.0)
	assert_almost_eq((f.c.aim_point(f.world)-f.world.player.position).y,Controllers.Human.KEY_AIM_REACH,0.001,"R release restores the current L direction")
	axis(f,JOY_AXIS_LEFT_X,0.0)
	f.world.player.facing = Vector2.DOWN
	assert_eq(f.c.aim_point(f.world),f.world.player.position+Vector2.DOWN*Controllers.Human.KEY_AIM_REACH)
	axis(f,JOY_AXIS_LEFT_X,0.0)
	assert_eq(f.c.move_dir(f.world),Vector2.ZERO)
	assert_false(f.c.has_target)

func test_menu_ab_confirm_back_and_dpad_or_stick_repeat_without_items() -> void:
	var f := fixture();f.game.state = "menu";f.pad.refresh_target()
	button(f,JOY_BUTTON_A,true);button(f,JOY_BUTTON_A,false)
	button(f,JOY_BUTTON_B,true);button(f,JOY_BUTTON_B,false)
	button(f,JOY_BUTTON_DPAD_DOWN,true);f.pad._process(0.4)
	button(f,JOY_BUTTON_DPAD_DOWN,false);f.pad._process(0.4)
	axis(f,JOY_AXIS_LEFT_Y,-1.0);f.pad._process(0.4)
	axis(f,JOY_AXIS_LEFT_Y,0.0)
	assert_eq(f.game.codes,[KEY_ENTER,KEY_ESCAPE,KEY_DOWN,KEY_DOWN,KEY_UP,KEY_UP])
	f.c.consume_skill_presses(f.world)
	assert_false(f.c.want_hotbar(2,f.world));assert_false(f.c.want_skill(0,f.world))

func test_l_stick_guides_first_projectile_before_facing_updates() -> void:
	var f:=fixture();f.world.player.facing=Vector2.UP
	# Instant projectile: Ember waits for its normal charge before emitting.
	f.world.player.slots[2]="poison_sting"
	axis(f,JOY_AXIS_LEFT_X,1.0)
	button(f,JOY_BUTTON_LEFT_SHOULDER,true);button(f,JOY_BUTTON_LEFT_SHOULDER,false)
	f.world._step_player(1.0/60)
	assert_false(f.world.projectiles.is_empty())
	for projectile in f.world.projectiles:
		assert_gt(projectile.vel.normalized().dot(Vector2.RIGHT),0.99,"First-frame casts must follow L, not the previous facing")

func test_trigger_hysteresis_and_only_active_commands_have_bindings() -> void:
	var f := fixture()
	for value in [0.4,0.6,0.8,0.45]:axis(f,JOY_AXIS_TRIGGER_LEFT,value)
	assert_eq(f.game.codes,[KEY_B],"Holding LT cannot repeatedly toggle the bag")
	axis(f,JOY_AXIS_TRIGGER_LEFT,0.3);axis(f,JOY_AXIS_TRIGGER_LEFT,0.6)
	axis(f,JOY_AXIS_TRIGGER_LEFT,0.0)
	axis(f,JOY_AXIS_TRIGGER_RIGHT,0.8);axis(f,JOY_AXIS_TRIGGER_RIGHT,0.0)
	button(f,JOY_BUTTON_A,true);button(f,JOY_BUTTON_A,false)
	button(f,JOY_BUTTON_B,true);button(f,JOY_BUTTON_B,false)
	button(f,JOY_BUTTON_BACK,true);button(f,JOY_BUTTON_BACK,false)
	button(f,JOY_BUTTON_START,true);button(f,JOY_BUTTON_START,false)
	assert_eq(f.game.codes,[KEY_B,KEY_B,KEY_C,KEY_SPACE,KEY_M,KEY_ESCAPE])
	assert_false(GamepadBindings.BUTTONS.has(JOY_BUTTON_LEFT_STICK))
	assert_false(GamepadBindings.BUTTONS.has(JOY_BUTTON_RIGHT_STICK))
	assert_false(GamepadBindings.BUTTONS.values().has("dodge"))

func test_bag_rt_plus_dpad_assigns_tool_slot_without_navigation_or_repeat() -> void:
	var f := fixture();f.game.state = "menu";f.game.menu = "bag";f.pad.refresh_target()
	axis(f,JOY_AXIS_TRIGGER_RIGHT,0.8)
	button(f,JOY_BUTTON_DPAD_RIGHT,true);f.pad._process(0.5)
	button(f,JOY_BUTTON_DPAD_RIGHT,false);axis(f,JOY_AXIS_TRIGGER_RIGHT,0.0)
	button(f,JOY_BUTTON_DPAD_DOWN,true);button(f,JOY_BUTTON_DPAD_DOWN,false)
	assert_eq(f.game.codes,[KEY_2,KEY_DOWN])

func test_b_cancels_active_fishing_instead_of_opening_a_menu() -> void:
	var f:=fixture();f.world.field_water.fishing={"phase":"wait"}
	button(f,JOY_BUTTON_B,true);button(f,JOY_BUTTON_B,false)
	assert_eq(f.game.codes,[KEY_F])

func test_scene_context_drops_held_axes_and_skills_but_accepts_fresh_back() -> void:
	var f := fixture()
	axis(f,JOY_AXIS_LEFT_X,1.0);button(f,JOY_BUTTON_LEFT_SHOULDER,true)
	var before: int = f.world.player.pp[2]
	f.game.state = "menu";f.pad.refresh_target()
	assert_eq(f.c.pad_move,Vector2.ZERO)
	button(f,JOY_BUTTON_B,true);button(f,JOY_BUTTON_B,false)
	assert_eq(f.game.codes,[KEY_ESCAPE],"Fresh B works while the old movement stick is still held")
	f.game.state = "fight";f.pad.refresh_target();f.pad._process(0.1)
	f.world._step_player(1.0/60)
	assert_eq(f.world.player.pp[2],before)
	assert_eq(f.c.pad_move,Vector2.ZERO)
	axis(f,JOY_AXIS_LEFT_X,0.0);axis(f,JOY_AXIS_LEFT_X,1.0)
	assert_eq(f.c.pad_move,Vector2.RIGHT)
	button(f,JOY_BUTTON_LEFT_SHOULDER,false);button(f,JOY_BUTTON_LEFT_SHOULDER,true)
	f.world._step_player(1.0/60)
	assert_eq(f.world.player.pp[2],before-1)

func test_focus_and_disconnect_clear_pending_input_without_touch_or_keyboard_release() -> void:
	var f := fixture()
	var before: int = f.world.player.pp[0]
	axis(f,JOY_AXIS_LEFT_X,1.0);button(f,JOY_BUTTON_X,true)
	f.pad.set_focused(false);f.pad.set_focused(true)
	f.world._step_player(1.0/60)
	assert_eq(f.world.player.pp[0],before)
	assert_eq(f.c.pad_move,Vector2.ZERO)
	button(f,JOY_BUTTON_X,false);axis(f,JOY_AXIS_LEFT_X,0.0)
	button(f,JOY_BUTTON_X,true)
	f.c.press_touch_key(KEY_E);Input.action_press("skill_1")
	f.pad.connection_changed(7,false)
	assert_eq(f.pad.active_device,-1)
	assert_true(f.c.touch_keys.has(KEY_E));assert_true(Input.is_action_pressed("skill_1"))
	f.world._step_player(1.0/60)
	assert_eq(f.world.player.pp[0],before,"Disconnect removes an unconsumed controller tap")

func test_second_controller_cannot_steal_live_axes_and_can_take_over_when_idle() -> void:
	var f := fixture()
	axis(f,JOY_AXIS_LEFT_X,1.0,7);axis(f,JOY_AXIS_LEFT_X,-1.0,8)
	assert_eq(f.pad.active_device,7);assert_eq(f.c.pad_move,Vector2.RIGHT)
	axis(f,JOY_AXIS_LEFT_X,0.0,7);axis(f,JOY_AXIS_LEFT_X,-1.0,8)
	assert_eq(f.pad.active_device,8);assert_eq(f.c.pad_move,Vector2.LEFT)
	f.pad.connection_changed(7,false);assert_eq(f.c.pad_move,Vector2.LEFT)
	f.pad.connection_changed(8,false);assert_eq(f.c.pad_move,Vector2.ZERO)
