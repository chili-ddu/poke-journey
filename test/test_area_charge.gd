extends GutTest

const DT:=1.0/60.0

func before_all() -> void:Controllers.ensure_input_map()

func after_each() -> void:
	for action in Controllers.ACTIONS:Input.action_release(action)
	await get_tree().process_frame

func fixture(move: String="smoke_screen") -> World:
	DungeonDB.set_current("test_meadow");Arena.configure(DungeonDB.theme());Arena.obstacles=[]
	var world:=World.new();add_child_autofree(world)
	world.setup(17,"charmander",30,[move],Controllers.Human.new())
	world.player.position=Vector2(300,170)
	world.player.controller.pad_move=Vector2.RIGHT;world.player.controller.pad_active=true
	return world

func test_pressing_area_skill_begins_aiming_without_spending_or_casting() -> void:
	var world:=fixture()
	var before: int=world.player.pp[0]
	world.player.controller.press_gamepad_key(KEY_Q)
	world._step_player(DT)
	assert_eq(world.player.pp[0],before,"Holding the button aims; only release commits PP")
	assert_eq(world.pending_casts.size(),0,"Pressing does not queue an automatic throw")
	assert_eq(world.zones.size()+world.projectiles.size(),0)
	assert_eq(world.area_charge_preview().range,24.0)
	assert_eq(world.area_charge_preview().progress,0.0)

func press(world: World) -> void:
	world.player.controller.press_gamepad_key(KEY_Q)
	world._step_player(DT)

func test_charge_distance_increases_and_maximum_waits_for_release_indefinitely() -> void:
	var world:=fixture();var pp: int=world.player.pp[0]
	press(world);world._step_player(.4)
	assert_almost_eq(world.area_charge_preview().range,60.0,.001)
	assert_almost_eq(world.area_charge_preview().progress,.5,.001)
	for _i in 20:world._step_player(.2)
	assert_almost_eq(world.area_charge_preview().range,96.0,.001)
	assert_eq(world.area_charge_preview().progress,1.0)
	assert_eq(world.player.pp[0],pp)
	assert_eq(world.pending_casts.size()+world.pending_calls.size(),0)
	world.player.controller.release_gamepad_key(KEY_Q);world._step_player(DT)
	assert_eq(world.player.pp[0],pp-1)
	assert_true(world.area_charge_preview().is_empty())
	assert_eq(world.pending_casts.size(),0,"Long charge already satisfied minimum windup")
	var calls:=world.pending_calls.size()
	for _i in 5:world._step_player(DT)
	assert_eq(world.pending_calls.size(),calls,"Release fires once")
	assert_eq(world.player.pp[0],pp-1)

func test_hold_preserves_normal_movement_and_updates_direction_and_caster_position() -> void:
	var world:=fixture();press(world)
	world.player.controller.pad_move=Vector2.UP
	world._step_player(.2)
	assert_eq(world.player.vel,Vector2.UP*world.player.move_speed())
	var first: Dictionary=world.area_charge_preview()
	assert_almost_eq(first.center.x,world.player.position.x,.001)
	assert_lt(first.center.y,world.player.position.y)
	world.player.position+=Vector2(12,6)
	var moved: Dictionary=world.area_charge_preview()
	assert_eq(moved.center-first.center,Vector2(12,6))

func test_short_tap_commits_once_then_uses_remaining_original_windup_and_locked_point() -> void:
	var world:=fixture();var pp: int=world.player.pp[0]
	press(world)
	world.player.controller.release_gamepad_key(KEY_Q);world._step_player(DT)
	assert_eq(world.player.pp[0],pp-1)
	assert_eq(world.pending_casts.size(),1)
	assert_almost_eq(world.pending_casts[0].t,.3-DT,.00001)
	var point: Vector2=world.pending_casts[0].locked_point
	var target:=Enemy.new();target.setup_trainer_mon("squirtle",30,["tackle"],world.rng)
	target.position=point;target.frozen=true;world.add_child(target);world.enemies.append(target)
	world.player.position+=Vector2(150,30)
	world.player.controller.pad_move=Vector2.UP
	world._step_pending_casts(.31);world._step_pending_calls(1.0)
	assert_eq(target.acc_stage,-1,"A released throw keeps the original ground point")
	assert_eq(world.player.pp[0],pp-1)
	assert_true(world.pending_casts.is_empty())

func test_cancelled_hold_context_status_or_move_change_spends_nothing_and_does_not_restart_held() -> void:
	for reason in ["menu","focus","sleep","flinch","no_skills","jump","dead","changed_move"]:
		var world:=fixture();var pp: int=world.player.pp[0]
		press(world);world._step_player(.3)
		match reason:
			"menu":world.player.controller.hold=true
			"focus":world.player.controller.clear_gamepad()
			"sleep":world.player.sleep_t=1.0
			"flinch":world.player.flinch_t=1.0
			"no_skills":world.no_skills=true
			"jump":world.player.hop_t=.2
			"dead":world.player.dead=true
			"changed_move":world.player.slots[0]="scratch"
		world._step_player(DT)
		assert_true(world.area_charge_preview().is_empty(),reason)
		assert_eq(world.player.pp[0],pp,reason)
		assert_true(world.pending_casts.is_empty(),reason)
		world.player.sleep_t=0;world.player.flinch_t=0;world.no_skills=false;world.player.hop_t=0;world.player.dead=false
		world._step_player(DT)
		assert_true(world.area_charge_preview().is_empty(),"Held key cannot restart a canceled charge: "+reason)
		assert_eq(world.player.pp[0],pp,reason)

func test_touch_cancel_is_not_a_throw_and_fresh_press_after_release_can_charge() -> void:
	var world:=fixture();var pp: int=world.player.pp[0]
	world.player.controller.press_touch_key(KEY_Q);world._step_player(DT);world._step_player(.2)
	world.player.controller.release_touch_key(KEY_Q,true);world._step_player(DT)
	assert_eq(world.player.pp[0],pp)
	assert_true(world.area_charge_preview().is_empty())
	world.player.controller.press_touch_key(KEY_Q);world._step_player(DT)
	assert_false(world.area_charge_preview().is_empty())

func test_normal_quick_tap_between_ticks_throws_once_for_each_input_source() -> void:
	for source in ["touch","gamepad","keyboard"]:
		var world:=fixture();var pp: int=world.player.pp[0]
		var controller: Controllers.Human=world.player.controller
		match source:
			"touch":controller.press_touch_key(KEY_Q);controller.release_touch_key(KEY_Q)
			"gamepad":controller.press_gamepad_key(KEY_Q);controller.release_gamepad_key(KEY_Q)
			"keyboard":
				Input.action_press("skill_0");controller.record_skill_event(0,world);Input.action_release("skill_0")
		world._step_player(DT)
		assert_eq(world.player.pp[0],pp-1,source)
		assert_true(world.area_charge_preview().is_empty(),source)
		assert_eq(world.pending_casts.size(),1,source)
		if world.pending_casts.size()==1:
			assert_almost_eq(world.pending_casts[0].locked_point.distance_to(world.player.position),24.0,.001,source)
		world._step_player(DT)
		assert_eq(world.player.pp[0],pp-1,"No duplicate buffered tap: "+source)
		assert_eq(world.pending_casts.size(),1,source)

func test_cancelled_quick_tap_before_first_tick_does_not_throw() -> void:
	for source in ["touch","gamepad"]:
		var world:=fixture();var pp: int=world.player.pp[0]
		if source=="touch":
			world.player.controller.press_touch_key(KEY_Q);world.player.controller.release_touch_key(KEY_Q,true)
		else:
			world.player.controller.press_gamepad_key(KEY_Q);world.player.controller.release_gamepad_key(KEY_Q,true)
		world._step_player(DT)
		assert_eq(world.player.pp[0],pp,source)
		assert_true(world.pending_casts.is_empty(),source)

func test_release_and_repress_between_world_ticks_starts_a_fresh_charge_after_cancel() -> void:
	var world:=fixture();press(world)
	world.player.flinch_t=1.0;world._step_player(DT)
	assert_true(world.area_charge_preview().is_empty())
	world.player.flinch_t=0.0
	world.player.controller.release_gamepad_key(KEY_Q)
	world.player.controller.press_gamepad_key(KEY_Q)
	world._step_player(DT)
	assert_false(world.area_charge_preview().is_empty(),"A fresh press is not the previously suppressed hold")

func test_jump_input_cancels_charge_without_spending_or_redirecting_jump() -> void:
	var world:=fixture();var pp: int=world.player.pp[0]
	press(world);world._step_player(.2)
	world.player.controller.press_gamepad_key(KEY_SPACE)
	world._step_player(DT)
	assert_true(world.area_charge_preview().is_empty())
	assert_eq(world.player.pp[0],pp)
	assert_true(world.player.dash.get("hop",false))
	assert_gt(world.player.dash.dir.x,.99,"Jump uses movement, not the area correction")

func test_ordinary_projectiles_still_cast_on_press_and_hold_to_fire() -> void:
	var world:=fixture("poison_sting")
	var pp: int=world.player.pp[0]
	press(world)
	assert_true(world.area_charge_preview().is_empty())
	assert_eq(world.player.pp[0],pp-1)
	assert_eq(world.projectiles.size(),1)

func test_other_skill_presses_cannot_stack_casts_while_area_button_is_held() -> void:
	var world:=fixture();world.player.add_learned("ember");world.player.equip(1,"ember")
	var pp: Array=world.player.pp.duplicate();press(world)
	world.player.controller.press_gamepad_key(KEY_W);world._step_player(.2)
	assert_eq(world.player.pp,pp)
	assert_eq(world.pending_casts.size()+world.pending_calls.size()+world.projectiles.size(),0)
	assert_false(world.area_charge_preview().is_empty())

func test_all_targeted_moves_have_range_only_charge_and_unchanged_cadence() -> void:
	for move in ["smoke_screen","fire_spin","rock_throw","rock_tomb","sleep_powder","poison_powder","leech_seed","worry_seed","seed_bomb","sludge_bomb"]:
		var world:=fixture(move);press(world);world._step_player(2.0)
		var preview: Dictionary=world.area_charge_preview()
		assert_almost_eq(preview.range,float(MoveDB.get_move(move).range),.001,move)
		assert_eq(preview.radius,float(MoveDB.get_move(move).get("area_radius",MoveDB.get_move(move).get("radius",Arena.TILE))),move)
		assert_eq(world.player.pp[0],MoveDB.pp_of(move),move)
	assert_eq(MoveDB.use_delay("rock_throw"),.35)
	assert_eq(MoveDB.recover_of("rock_throw"),.45)
	assert_eq(MoveDB.use_delay("sleep_powder"),.8)
	assert_eq(MoveDB.recover_of("sleep_powder"),.6)
