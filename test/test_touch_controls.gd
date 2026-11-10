extends GutTest

const ScreenControls = preload("res://scripts/ui/touch_controls.gd")

class Harness:
	extends Node
	var world: World
	var bot := false
	var state := "fight"
	var menu := ""
	var cinematic := false
	var encounter = null
	var codes: Array[int] = []

func before_all() -> void:Controllers.ensure_input_map()

func after_each() -> void:
	for action in Controllers.ACTIONS:Input.action_release(action)
	await get_tree().process_frame

func fixture() -> Dictionary:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var game := Harness.new()
	add_child_autofree(game)
	var world := World.new()
	game.world = world;game.add_child(world)
	world.setup(7,"charmander",12,["scratch","growl","ember","smoke_screen"],Controllers.Human.new())
	world.player.position = Arena.center()
	var ui := ScreenControls.new()
	ui.game = game;ui.mobile_override = 1
	ui.control_area = Rect2(0,110,384,106)
	game.add_child(ui);ui.set_process(false);ui.refresh()
	ui.router.event_sink = func(event: InputEventKey) -> void:
		if event.pressed:game.codes.append(event.physical_keycode)
	return {"game":game,"world":world,"ui":ui,"c":world.player.controller}

func test_desktop_has_no_stick_or_pointer_capture() -> void:
	var f := fixture()
	f.ui.mobile_override = 0;f.ui.refresh()
	assert_false(f.ui.visible)
	assert_false(f.ui.pointer(0,f.ui.stick_center,"press"))
	assert_eq(f.c.touch_move,Vector2.ZERO)
	assert_false(f.c.touch_owned)
	if OS.has_feature("pc"):assert_false(ScreenControls.mobile_platform())

func test_mobile_pad_has_all_keys_and_stays_available_in_menus() -> void:
	var f := fixture()
	assert_true(f.ui.visible)
	assert_eq(f.ui.get_child_count(),0,"Controls are drawn in the separate lower area")
	for key in ["bag","summary","menu","town_map","action","cancel","skill_0","skill_1","skill_2","skill_3","item_0","item_1","item_2","item_3"]:
		assert_true(f.ui.deck.hits.has(key),key)
	for key in ["dodge","extras","language","look","map","fullscreen","view_minus","view_plus"]:
		assert_false(f.ui.deck.hits.has(key),key)
	for state in ["talk","menu","evolve","gameover","bird_event"]:
		f.game.state = state;f.ui.refresh()
		assert_true(f.ui.visible,state)
		f.ui.pointer(0,f.ui.stick_center,"press")
		f.ui.pointer(0,f.ui.stick_center,"release")
		assert_eq(f.c.touch_move,Vector2.ZERO,state)
	f.game.state = "town";f.ui.refresh()
	assert_true(f.ui.visible)
	f.game.cinematic = true;f.ui.refresh()
	assert_true(f.ui.visible)

func test_controller_faces_and_direction_cross_follow_menu_context() -> void:
	var f := fixture()
	for slot in 4:assert_eq(f.ui.deck.glyphs["skill_%d"%slot],["X","Y","LB","RB"][slot])
	for i in 4:assert_eq(f.ui.deck.glyphs[GamepadBindings.SHOULDERS[i]],["LT","RT","LB","RB"][i])
	var idle_back: Vector2 = f.ui.deck.hits.cancel.get_center()
	f.ui.pointer(6,idle_back,"press");f.ui.pointer(6,idle_back,"release")
	assert_true(f.game.codes.is_empty(),"B cannot open the Start menu during gameplay")
	f.game.state = "menu";f.ui.refresh()
	for command in ["action","cancel","item_0"]:
		var at: Vector2 = f.ui.deck.hits[command].get_center()
		f.ui.pointer(7,at,"press")
		if command=="item_0":
			f.ui._process(0.4)
			f.ui.pointer(7,at+Vector2(80,0),"drag")
			f.ui._process(0.4)
		f.ui.pointer(7,at,"release")
	assert_eq(f.game.codes,[KEY_ENTER,KEY_ESCAPE,KEY_UP,KEY_UP],"A confirms, B returns, d-pad repeats then stops on drag-off")
	assert_eq(f.c.touch_move,Vector2.ZERO)
	assert_false(f.c.want_hotbar(0,f.world),"Menu directions cannot consume a tool")

func test_two_sticks_move_and_aim_independently_and_release_to_facing() -> void:
	var f := fixture()
	f.world.move_override = func(v: Vector2) -> Vector2:return v.rotated(PI/2)
	var left: Vector2 = f.ui.stick_center
	var right: Vector2 = f.ui.aim_center
	f.ui.pointer(0,left,"press");f.ui.pointer(0,left+Vector2.RIGHT*f.ui.stick_radius(),"drag")
	f.world.player.facing = Vector2.LEFT
	var primary: Vector2 = f.c.aim_point(f.world)-f.world.player.position
	assert_almost_eq(primary.y,Controllers.Human.KEY_AIM_REACH,0.001,"L-stick aim uses current movement before facing catches up")
	f.ui.pointer(1,right,"press");f.ui.pointer(1,right+Vector2.UP*f.ui.aim_radius(),"drag")
	assert_almost_eq(f.c.move_dir(f.world).y,1.0,0.001)
	var aim: Vector2 = f.c.aim_point(f.world)-f.world.player.position
	assert_almost_eq(aim.x,Controllers.Human.KEY_AIM_REACH,0.001,"Right stick uses camera transform once, independently from movement")
	f.ui.pointer(2,right,"press");f.ui.pointer(2,right+Vector2.DOWN*50,"drag")
	assert_eq(f.c.touch_aim,Vector2.UP,"A second finger cannot steal right-stick ownership")
	f.ui.pointer(2,right,"release")
	f.ui.pointer(1,right,"release")
	assert_eq(f.c.touch_aim,Vector2.ZERO)
	assert_eq(f.c.touch_move,Vector2.RIGHT)
	assert_almost_eq((f.c.aim_point(f.world)-f.world.player.position).y,Controllers.Human.KEY_AIM_REACH,0.001,"R release immediately restores L-stick aim")
	f.ui.pointer(0,left,"release")
	f.world.player.facing = Vector2.DOWN
	assert_eq(f.c.aim_point(f.world),f.world.player.position+Vector2.DOWN*Controllers.Human.KEY_AIM_REACH)
	f.ui.pointer(3,right,"press");f.ui.pointer(3,right+Vector2.UP*50,"drag")
	f.ui.cancel_all()
	assert_eq(f.c.touch_aim,Vector2.ZERO)
	assert_eq(f.c.touch_move,Vector2.ZERO)

func test_bag_rt_plus_direction_assigns_hotbar_without_navigating() -> void:
	var f := fixture();f.game.state = "menu";f.game.menu = "bag";f.ui.refresh()
	var rt: Vector2 = f.ui.deck.hits.summary.get_center()
	var right: Vector2 = f.ui.deck.hits.item_1.get_center()
	f.ui.pointer(0,rt,"press");f.ui.pointer(1,right,"press")
	f.ui._process(0.5)
	f.ui.pointer(1,right,"release");f.ui.pointer(0,rt,"release")
	assert_eq(f.game.codes,[KEY_2],"RT + right assigns tool slot 2 and does not switch pockets")
	f.ui.pointer(2,rt,"press");f.ui.pointer(2,rt+Vector2(90,0),"drag")
	f.ui.pointer(3,right,"press");f.ui.pointer(3,right,"release");f.ui.pointer(2,rt,"release")
	assert_eq(f.game.codes,[KEY_2,KEY_RIGHT],"Dragging off RT cancels the assignment modifier")

func test_touch_l_stick_aims_first_projectile_with_r_idle() -> void:
	var f:=fixture();f.world.player.facing=Vector2.UP
	f.world.player.slots[2]="poison_sting" # Inspect the initial cast, without Ember's charge.
	var left: Vector2=f.ui.stick_center
	f.ui.pointer(0,left,"press");f.ui.pointer(0,left+Vector2.RIGHT*f.ui.stick_radius(),"drag")
	var skill: Vector2=f.ui.deck.hits.skill_2.get_center()
	f.ui.pointer(1,skill,"press");f.world._step_player(1.0/60)
	assert_false(f.world.projectiles.is_empty())
	for projectile in f.world.projectiles:assert_gt(projectile.vel.normalized().dot(Vector2.RIGHT),0.99)
	f.ui.pointer(1,skill,"release");f.ui.pointer(0,left,"release")

func test_stick_deadzone_strength_diagonal_and_release() -> void:
	var f := fixture()
	var center: Vector2 = f.ui.stick_center
	f.ui.pointer(0,center,"press")
	f.ui.pointer(0,center+Vector2(2,1),"drag")
	assert_eq(f.c.move_dir(f.world),Vector2.ZERO)
	f.ui.pointer(0,center+Vector2(f.ui.stick_radius()*0.5,0),"drag")
	assert_gt(f.c.move_dir(f.world).x,0.3)
	assert_lt(f.c.move_dir(f.world).x,0.6)
	f.ui.pointer(0,center+Vector2(90,-90),"drag")
	assert_almost_eq(f.c.move_dir(f.world).length(),1.0,0.001)
	assert_lte(f.ui.stick_knob.length()+f.ui.stick_radius()*0.4,f.ui.stick_radius()+0.01,"Dragging cannot draw the thumb cap over the game display")
	assert_lt(f.c.move_dir(f.world).y,0.0)
	f.ui.pointer(0,center+Vector2(90,-90),"release")
	assert_eq(f.c.move_dir(f.world),Vector2.ZERO)
	assert_eq(f.ui.stick_knob,Vector2.ZERO)
	assert_false(f.c.has_target)

func test_other_finger_cannot_steal_movement_and_passes_to_existing_ui() -> void:
	var f := fixture()
	var center: Vector2 = f.ui.stick_center
	f.ui.pointer(1,center,"press")
	f.ui.pointer(1,center+Vector2.RIGHT*f.ui.stick_radius(),"drag")
	assert_true(f.ui.pointer(2,center,"press"))
	assert_true(f.ui.pointer(2,center+Vector2.LEFT*29,"drag"))
	assert_true(f.ui.pointer(2,center,"release"))
	assert_eq(f.c.touch_move,Vector2.RIGHT)
	assert_true(f.c.touch_owned)
	f.ui.pointer(1,center,"cancel")
	assert_eq(f.c.touch_move,Vector2.ZERO)
	assert_false(f.ui.pointer(3,Vector2(200,80),"press"),"Only the stick consumes touches")

func test_blank_control_panel_does_not_become_global_click_to_walk() -> void:
	var f := fixture()
	var blank: Vector2 = f.ui.control_area.position+Vector2(8,8)
	Input.action_press("move_click")
	assert_true(f.ui.pointer(0,blank,"press"))
	assert_eq(f.c.move_dir(f.world),Vector2.ZERO)
	assert_false(f.c.has_target)
	Input.action_release("move_click")
	f.ui.pointer(0,blank,"release")
	assert_eq(f.c.move_dir(f.world),Vector2.ZERO)

func test_keyboard_independence_and_camera_direction_transform() -> void:
	var f := fixture()
	f.world.move_override = func(v: Vector2) -> Vector2:return v.rotated(PI/2)
	f.ui.pointer(0,f.ui.stick_center,"press")
	f.ui.pointer(0,f.ui.stick_center+Vector2.RIGHT*f.ui.stick_radius(),"drag")
	assert_almost_eq(f.c.move_dir(f.world).y,1.0,0.001)
	Input.action_press("move_left")
	f.ui.pointer(0,f.ui.stick_center,"release")
	assert_almost_eq(f.c.move_dir(f.world).y,-1.0,0.001,"Releasing a finger cannot release a keyboard key")
	Input.action_release("move_left")
	assert_eq(f.c.move_dir(f.world),Vector2.ZERO)

func test_emulated_mouse_does_not_become_click_to_walk() -> void:
	var f := fixture()
	Input.action_press("move_click")
	f.ui.pointer(0,f.ui.stick_center,"press")
	assert_eq(f.c.move_dir(f.world),Vector2.ZERO)
	assert_false(f.c.has_target)
	Input.action_release("move_click")
	f.ui.pointer(0,f.ui.stick_center,"release")
	assert_eq(f.c.move_dir(f.world),Vector2.ZERO)

func test_focus_menu_and_viewport_cleanup_drop_old_contacts() -> void:
	var f := fixture()
	var at: Vector2 = f.ui.stick_center
	f.ui.pointer(0,at,"press")
	f.ui.pointer(0,at+Vector2.RIGHT*29,"drag")
	f.ui.cancel_all()
	assert_eq(f.c.touch_move,Vector2.ZERO)
	assert_eq(f.ui.finger,-1)
	f.ui.pointer(1,at,"press")
	f.game.state = "menu";f.ui.refresh()
	assert_true(f.ui.visible)
	assert_false(f.c.touch_owned)
	assert_false(f.ui.pointer(1,at,"release"))
	f.game.state = "fight";f.ui.refresh()
	assert_eq(f.c.move_dir(f.world),Vector2.ZERO)

func test_new_scene_waits_for_old_primary_touch_release() -> void:
	var old := fixture()
	old.ui.pointer(0,old.ui.stick_center,"press")
	Input.action_press("move_click")
	old.ui.queue_free();await get_tree().process_frame
	var fresh := fixture()
	assert_true(fresh.c.hold)
	assert_eq(fresh.c.move_dir(fresh.world),Vector2.ZERO)
	assert_false(fresh.c.has_target)
	Input.action_release("move_click")
	fresh.c.move_dir(fresh.world)
	assert_false(fresh.c.hold)
