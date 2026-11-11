extends GutTest

func before_all() -> void:
	Controllers.ensure_input_map()

func after_each() -> void:
	for action in Controllers.ACTIONS: Input.action_release(action)
	await get_tree().process_frame

func fixture(move: String = "poison_sting") -> World:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	Arena.obstacles = []
	var world := World.new()
	add_child_autofree(world)
	world.setup(17, "charmander", 12, [move], Controllers.Human.new())
	world.player.position = Vector2(300,170)
	world.player.facing = Vector2.RIGHT
	world.player.controller.pad_move = Vector2.RIGHT
	world.player.controller.pad_active = true
	return world

func foe(world: World, offset: Vector2) -> Enemy:
	var enemy := Enemy.new()
	enemy.setup_trainer_mon("squirtle",12,["tackle"],world.rng)
	enemy.position = world.player.position + offset
	enemy.frozen = true
	world.add_child(enemy)
	world.enemies.append(enemy)
	return enemy

func test_l_stick_cast_gently_turns_toward_a_nearby_off_axis_enemy() -> void:
	var world := fixture()
	foe(world, Vector2(60,15))
	world.player.controller.press_gamepad_key(KEY_Q)
	world._step_player(1.0/60.0)
	assert_false(world.projectiles.is_empty())
	assert_gt(world.projectiles[0].vel.normalized().y,0.15,"A nearby off-axis foe should receive light aim correction")
	assert_gt(world.projectiles[0].vel.normalized().x,0.94,"Movement intent remains the main direction")

func aim(world: World, move: String = "poison_sting") -> Vector2:
	var human: Controllers.Human = world.player.controller
	return (human.skill_aim(world, move, human.aim_point(world)) - world.player.position).normalized()

func test_no_foe_or_disabled_assistance_preserves_manual_direction() -> void:
	var world := fixture()
	assert_eq(aim(world), Vector2.RIGHT)
	foe(world,Vector2(60,15))
	world.player.controller.aim_assist.settings.enabled = false
	assert_eq(aim(world),Vector2.RIGHT)

func test_behind_outside_cone_and_out_of_move_range_are_not_selected() -> void:
	for offset in [Vector2(-40,0), Vector2(40,40), Vector2(160,10)]:
		var world := fixture()
		foe(world,offset)
		assert_eq(aim(world),Vector2.RIGHT)
	var melee := fixture("scratch")
	foe(melee,Vector2(110,12))
	assert_eq(aim(melee,"scratch"),Vector2.RIGHT,"Melee cannot lock onto a distant target")

func test_wall_blocks_assistance() -> void:
	var world := fixture()
	foe(world,Vector2(60,15))
	Arena.obstacles = [{"pos":world.player.position+Vector2(30,7.5),"r":10.0}]
	assert_eq(aim(world),Vector2.RIGHT)

func test_bystanders_friends_hidden_dead_and_spawning_foes_are_ignored() -> void:
	var world := fixture()
	var friend := foe(world,Vector2(55,12));friend.team = Mon.TEAM_PLAYER
	var dead := foe(world,Vector2(56,13));dead.dead = true
	var hidden := foe(world,Vector2(57,14));hidden.hide()
	var arriving := foe(world,Vector2(58,15));arriving.appear = 0.5
	var watching := Mon.new();watching.setup("bulbasaur",12,Mon.TEAM_ENEMY)
	watching.position = world.player.position+Vector2(60,15)
	world.add_child(watching);world.bystanders.append(watching)
	assert_eq(aim(world),Vector2.RIGHT)

func test_pad_correction_ignores_legacy_r_aim_fields() -> void:
	var world := fixture()
	var enemy := foe(world,Vector2.RIGHT.rotated(deg_to_rad(25))*60)
	assert_almost_eq(rad_to_deg(aim(world).angle()),18.0,0.001)
	world.player.controller.pad_aim = Vector2.LEFT
	world.player.controller.touch_aim = Vector2.UP
	assert_false(world.player.controller.skill_aim_precise())
	assert_almost_eq(rad_to_deg(aim(world).angle()),18.0,0.001,"Legacy R values cannot select direct-aim precision or direction")
	enemy.position = world.player.position+Vector2.RIGHT.rotated(deg_to_rad(20))*60
	assert_almost_eq(rad_to_deg(aim(world).angle()),18.0,0.001)

func test_mouse_aim_is_precise_and_click_destination_is_unchanged() -> void:
	var world := fixture()
	var human: Controllers.Human = world.player.controller
	human.pad_move = Vector2.ZERO;human.pad_active = false;human.key_aim = false
	var point := world.player.position+Vector2.RIGHT*80
	world.aim_override = func() -> Vector2: return point
	human.target = point;human.has_target = true
	foe(world,Vector2(60,12))
	assert_almost_eq(rad_to_deg(aim(world).angle()),8.0,0.001)
	assert_eq(human.target,point,"Aim assistance cannot move the clicked destination")
	assert_eq(human.aim_point(world),point,"Raw aim remains unmodified")

func test_mobile_and_keyboard_use_current_manual_direction() -> void:
	var world := fixture()
	var human: Controllers.Human = world.player.controller
	human.pad_move = Vector2.ZERO;human.pad_active = false
	human.touch_move = Vector2.RIGHT;human.touch_active = true;human.touch_owned = true
	foe(world,Vector2(60,15))
	assert_gt(aim(world).y,0.15)
	human.clear_touch();human.key_aim = true
	Input.action_press("move_right")
	assert_gt(aim(world).y,0.15)

func test_camera_rotation_is_applied_once_before_assistance() -> void:
	var world := fixture()
	world.move_override = func(v: Vector2) -> Vector2: return v.rotated(PI/2)
	foe(world,Vector2(15,60))
	var corrected := aim(world)
	assert_gt(corrected.y,0.94)
	assert_gt(corrected.x,0.15)

func test_target_score_prefers_direction_and_small_hysteresis_prevents_switching() -> void:
	var world := fixture()
	var centered := foe(world,Vector2.RIGHT.rotated(deg_to_rad(5))*70)
	var closer := foe(world,Vector2.RIGHT.rotated(deg_to_rad(-22))*35)
	assert_gt(aim(world).y,0.0,"An aligned foe wins over a closer peripheral foe")
	closer.position = world.player.position+Vector2.RIGHT.rotated(deg_to_rad(-4.5))*70
	assert_gt(aim(world).y,0.0,"Small candidate score changes do not flicker targets")
	centered.position = world.player.position+Vector2(0,60)
	assert_lt(aim(world).y,0.0,"Leaving the cone immediately releases the old target")

func test_freed_target_is_released_and_another_foe_can_be_selected() -> void:
	var world := fixture()
	var old := foe(world,Vector2(60,10))
	assert_gt(aim(world).y,0.0)
	world.enemies.erase(old);old.free()
	foe(world,Vector2(60,-10))
	assert_lt(aim(world).y,0.0)

func test_small_velocity_lead_is_bounded_and_does_not_change_stats() -> void:
	var world := fixture()
	var enemy := foe(world,Vector2(60,5))
	var stats := enemy.stats.duplicate()
	var hp := enemy.hp
	var stationary := aim(world).angle()
	enemy.vel = Vector2(0,500)
	var moving := aim(world).angle()
	assert_gt(moving,stationary)
	assert_lte(moving,atan2(13.0,60.0)+0.001,"Prediction is limited to 8px")
	assert_eq(enemy.stats,stats)
	assert_eq(enemy.hp,hp)

func test_self_moves_keep_their_original_aim() -> void:
	var world := fixture()
	foe(world,Vector2(60,15))
	for move in ["protect","growth"]:
		assert_eq(aim(world,move),Vector2.RIGHT,move)

func test_charge_completion_tracks_the_current_target_position() -> void:
	var world := fixture("ember")
	var enemy := foe(world,Vector2(50,3))
	world.player.controller.press_gamepad_key(KEY_Q)
	world._step_player(1.0/60.0)
	assert_eq(world.pending_casts.size(),1)
	world.player.controller.release_gamepad_key(KEY_Q)
	enemy.position = world.player.position+Vector2(50,16)
	world._step_pending_casts(0.2)
	world._step_bursts(0.001)
	assert_false(world.projectiles.is_empty())
	assert_gt(world.projectiles[0].vel.normalized().y,0.15,"The charge uses the updated position, not the initial aim")

func test_stream_updates_aim_without_bending_already_fired_projectiles() -> void:
	var world := fixture("flamethrower")
	var enemy := foe(world,Vector2(60,3))
	world.player.controller.press_gamepad_key(KEY_Q)
	world._step_player(1.0/60.0)
	world._step_bursts(0.001)
	var first: Projectile = world.projectiles[0]
	var original := first.vel
	enemy.position = world.player.position+Vector2(60,18)
	world._step_bursts(0.05)
	assert_gt(world.projectiles.size(),1)
	assert_gt(world.projectiles[-1].vel.angle(),original.angle()+deg_to_rad(5))
	assert_eq(first.vel,original)

func test_ember_volley_keeps_its_original_spread_axis_after_first_emission() -> void:
	var world := fixture("ember")
	var enemy := foe(world,Vector2(50,3))
	world.player.controller.press_gamepad_key(KEY_Q)
	world._step_player(1.0/60.0)
	world._step_pending_casts(0.2);world._step_bursts(0.001)
	var first_axis: Vector2 = world.bursts[0].dir
	enemy.position = world.player.position+Vector2(50,18)
	world._step_bursts(0.04)
	assert_eq(world.bursts[0].dir,first_axis)

func test_actual_damage_and_pp_use_the_common_combat_path() -> void:
	var world := fixture()
	var enemy := foe(world,Vector2(55,12))
	var initial_hp := enemy.hp
	var initial_pp := int(world.player.pp[0])
	world.player.controller.press_gamepad_key(KEY_Q)
	world._step_player(1.0/60.0)
	world.player.controller.release_gamepad_key(KEY_Q)
	for frame in 30: world._step_projectiles(1.0/60.0)
	assert_lt(enemy.hp,initial_hp,"A slightly off-axis enemy is actually hit")
	assert_eq(int(world.player.pp[0]),initial_pp-1)
	assert_eq(enemy.max_hp,int(SpeciesDB.stats_at(enemy.species_id,enemy.level,enemy.ivs).hp))

func test_mouse_on_player_keeps_the_normal_facing_fallback() -> void:
	var world := fixture()
	var human: Controllers.Human = world.player.controller
	human.pad_move = Vector2.ZERO;human.pad_active = false
	world.aim_override = func() -> Vector2: return world.player.position
	human.press_touch_key(KEY_Q)
	world._step_player(1.0/60.0)
	assert_eq(world.player.facing,Vector2.RIGHT)
	assert_gt(world.projectiles[0].vel.x,0.0)

func test_idle_facing_cannot_accumulate_assistance_until_it_turns_behind() -> void:
	var world := fixture()
	var human: Controllers.Human = world.player.controller
	human.pad_move = Vector2.ZERO
	var enemy := foe(world,Vector2.RIGHT.rotated(deg_to_rad(20))*60)
	var first := aim(world)
	world.player.facing = first
	enemy.position = world.player.position+Vector2.RIGHT.rotated(deg_to_rad(40))*60
	assert_eq(aim(world),Vector2.RIGHT,"Assist retains the original manual heading while both sticks are idle")

func test_context_clear_discards_target_and_manual_anchor() -> void:
	var world := fixture()
	var human: Controllers.Human = world.player.controller
	foe(world,Vector2(60,15));aim(world)
	assert_ne(human._skill_manual_direction,Vector2.ZERO)
	human.clear_gamepad()
	assert_eq(human._skill_manual_direction,Vector2.ZERO)
	assert_eq(human.aim_assist._target,null)
	human.touch_active = true;human.touch_move = Vector2.RIGHT;aim(world)
	human.clear_touch()
	assert_eq(human._skill_corrected_direction,Vector2.ZERO)
	assert_eq(human.aim_assist._target,null)

func test_aim_assistance_does_not_steer_jump_or_change_movement() -> void:
	var world := fixture()
	foe(world,Vector2(60,15))
	var human: Controllers.Human = world.player.controller
	assert_eq(human.move_dir(world),Vector2.RIGHT)
	human.press_gamepad_key(KEY_SPACE)
	world._step_player(1.0/60.0)
	assert_false(world.player.dash.is_empty())
	assert_almost_eq(Vector2(world.player.dash.dir).y,0.0,0.001)
