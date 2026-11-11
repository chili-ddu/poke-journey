extends GutTest

const AimAssist = preload("res://scripts/battle/aim_assist.gd")

func before_all() -> void:Controllers.ensure_input_map()
func after_each() -> void:
	for action in Controllers.ACTIONS:Input.action_release(action)
	MoveDB.clear_cache()
	await get_tree().process_frame

func fixture(move_id: String="smoke_screen") -> World:
	DungeonDB.set_current("test_meadow");Arena.configure(DungeonDB.theme());Arena.obstacles=[]
	var world:=World.new();add_child_autofree(world)
	world.setup(17,"charmander",20,[move_id],Controllers.Human.new())
	world.player.position=Vector2(300,170);world.player.facing=Vector2.RIGHT
	world.player.controller.pad_move=Vector2.RIGHT;world.player.controller.pad_active=true
	return world

func foe(world: World,offset: Vector2) -> Enemy:
	var enemy:=Enemy.new();enemy.setup_trainer_mon("squirtle",20,["tackle"],world.rng)
	enemy.position=world.player.position+offset;enemy.frozen=true
	world.add_child(enemy);world.enemies.append(enemy)
	return enemy

func test_area_assist_never_replaces_the_player_controlled_throw_distance() -> void:
	var world:=fixture()
	foe(world,Vector2(72,12))
	var point: Vector2=world.player.controller.aim_assist.resolve_area(world,world.player,MoveDB.get_move("smoke_screen"),world.player.position+Vector2.RIGHT*24)
	assert_almost_eq(point.distance_to(world.player.position),24.0,0.0001,"Direction correction must retain the short manual distance instead of snapping to the enemy")
	assert_gt(point.y,world.player.position.y,"Light aim assistance may still turn toward the foe")

func point(world: World,distance: float=24.0,precise: bool=false) -> Vector2:
	return world.player.controller.aim_assist.resolve_area(world,world.player,MoveDB.get_move("smoke_screen"),world.player.position+Vector2.RIGHT*distance,precise)

func test_behind_outside_cone_and_out_of_range_do_not_redirect_manual_throw() -> void:
	for offset in [Vector2(-30,0),Vector2(30,30),Vector2(100,5)]:
		var world:=fixture();foe(world,offset)
		assert_eq(point(world),world.player.position+Vector2.RIGHT*24,str(offset))

func test_area_direction_uses_existing_precise_and_movement_angle_limits() -> void:
	var world:=fixture()
	var target:=foe(world,Vector2.RIGHT.rotated(deg_to_rad(25))*60)
	var assisted:=point(world)-world.player.position
	assert_almost_eq(rad_to_deg(assisted.angle()),18.0,0.001)
	assert_almost_eq(assisted.length(),24.0,0.001)
	target.position=world.player.position+Vector2.RIGHT.rotated(deg_to_rad(12))*60
	assisted=point(world,24,true)-world.player.position
	assert_almost_eq(rad_to_deg(assisted.angle()),8.0,0.001)
	assert_almost_eq(assisted.length(),24.0,0.001)
	target.position=world.player.position+Vector2.RIGHT.rotated(deg_to_rad(20))*60
	assert_eq(point(world,24,true),world.player.position+Vector2.RIGHT*24)

func test_area_direction_retains_the_existing_angle_score_and_small_hysteresis() -> void:
	var world:=fixture()
	var aligned:=foe(world,Vector2.RIGHT.rotated(deg_to_rad(5))*70)
	var closer:=foe(world,Vector2.RIGHT.rotated(deg_to_rad(-22))*35)
	assert_gt(point(world).y,world.player.position.y,"The existing direction score wins over a closer peripheral enemy")
	closer.position=world.player.position+Vector2.RIGHT.rotated(deg_to_rad(-4.5))*70
	assert_gt(point(world).y,world.player.position.y)
	aligned.position=world.player.position+Vector2(0,60)
	assert_lt(point(world).y,world.player.position.y)

func test_area_candidate_range_remains_strict_and_does_not_add_body_radius() -> void:
	var world:=fixture()
	var target:=foe(world,Vector2(97,5))
	assert_eq(point(world),world.player.position+Vector2.RIGHT*24)
	target.position=world.player.position+Vector2(90,5)
	assert_gt(point(world).y,world.player.position.y)
	world.player.controller.aim_assist.settings.range_cap_tiles=2.0
	assert_eq(point(world),world.player.position+Vector2.RIGHT*24)

func test_walls_friends_hidden_dead_spawning_and_bystanders_are_ignored() -> void:
	var world:=fixture()
	foe(world,Vector2(35,5))
	Arena.obstacles=[{"pos":world.player.position+Vector2(18,3),"r":6.0}]
	var friend:=foe(world,Vector2(6,1));friend.team=Mon.TEAM_PLAYER
	var dead:=foe(world,Vector2(7,1));dead.dead=true
	var hidden:=foe(world,Vector2(8,1));hidden.hide()
	var arriving:=foe(world,Vector2(9,1));arriving.appear=0.2
	var bystander:=Mon.new();bystander.setup("bulbasaur",20,Mon.TEAM_ENEMY)
	bystander.position=world.player.position+Vector2(5,1)
	world.add_child(bystander);world.bystanders.append(bystander)
	var target:=foe(world,Vector2(50,-15))
	assert_lt(point(world).y,world.player.position.y)
	assert_eq(world.player.controller.aim_assist._target.get_ref(),target)

func test_area_velocity_prediction_is_bounded_and_only_changes_direction() -> void:
	var world:=fixture();var target:=foe(world,Vector2(60,0))
	var stats:=target.stats.duplicate();var hp:=target.hp
	target.vel=Vector2(0,1000)
	var assisted:=point(world)-world.player.position
	assert_almost_eq(assisted.angle(),atan2(8.0,60.0),0.0001)
	assert_almost_eq(assisted.length(),24.0,0.0001)
	assert_eq(target.stats,stats);assert_eq(target.hp,hp)
	Arena.obstacles=[{"pos":target.position+Vector2(0,8),"r":3.0}]
	assert_eq(point(world),world.player.position+Vector2.RIGHT*24,"Prediction cannot aim through a blocked point")

func test_manual_distance_caps_at_range_with_or_without_assistance() -> void:
	var world:=fixture();foe(world,Vector2(60,8))
	for length in [24.0,48.0,96.0,200.0]:
		assert_almost_eq(point(world,length).distance_to(world.player.position),minf(length,96.0),0.001)
	world.player.controller.aim_assist.settings.enabled=false
	assert_eq(point(world,32),world.player.position+Vector2.RIGHT*32)
	assert_eq(point(world,200),world.player.position+Vector2.RIGHT*96)
	Arena.obstacles=[{"pos":world.player.position+Vector2(40,0),"r":8.0}]
	var safe:=point(world,96)
	assert_lt(safe.x,world.player.position.x+32)
	assert_false(Arena.blocks(safe,0))

func test_freed_target_releases_without_changing_throw_length() -> void:
	var world:=fixture();var old:=foe(world,Vector2(50,8))
	assert_gt(point(world).y,world.player.position.y)
	world.enemies.erase(old);old.free()
	var target:=foe(world,Vector2(50,-8))
	assert_lt(point(world).y,world.player.position.y)
	assert_almost_eq(point(world).distance_to(world.player.position),24.0,0.001)
	assert_eq(world.player.controller.aim_assist._target.get_ref(),target)

func test_zero_distance_is_not_automatically_replaced_with_enemy_distance() -> void:
	var world:=fixture();foe(world,Vector2(50,8))
	assert_eq(point(world,0),world.player.position)

func test_enemy_caster_uses_the_same_direction_only_distance_rule() -> void:
	var world:=fixture();var caster:=foe(world,Vector2(60,0))
	var assist:=AimAssist.new()
	var result:=assist.resolve_area(world,caster,MoveDB.get_move("smoke_screen"),caster.position+Vector2.LEFT*20)
	assert_eq(result,caster.position+Vector2.LEFT*20)
	assert_ne(result,world.player.position)

func test_keyboard_touch_and_pad_hold_state_excludes_transient_quick_tap() -> void:
	var world:=fixture();var human: Controllers.Human=world.player.controller
	var revision:=human.skill_input_revision()
	Input.action_press("skill_0");assert_true(human.skill_is_held(0))
	Input.action_release("skill_0");assert_false(human.skill_is_held(0))
	assert_eq(human.skill_input_revision(),revision)
	for method in ["touch","gamepad"]:
		human.call("press_%s_key"%method,KEY_Q)
		assert_true(human.skill_is_held(0),method)
		human.call("release_%s_key"%method,KEY_Q)
		human.consume_skill_presses(world)
		assert_false(human.skill_is_held(0),method)
		assert_true(human.want_skill(0,world),"A quick tap starts a charge but is already released: "+method)
		assert_eq(human.skill_input_revision(),revision)
		human.consume_skill_presses(world)
	assert_false(human.skill_is_held(-1));assert_false(human.skill_is_held(4))

func test_cancelled_release_clear_and_modal_hold_invalidate_charge_revision() -> void:
	var world:=fixture();var human: Controllers.Human=world.player.controller
	for method in ["touch","gamepad"]:
		var revision:=human.skill_input_revision()
		human.call("press_%s_key"%method,KEY_Q)
		human.call("release_%s_key"%method,KEY_Q,true)
		human.consume_skill_presses(world)
		assert_gt(human.skill_input_revision(),revision,method)
		assert_false(human.skill_is_held(0));assert_false(human.want_skill(0,world))
	var revision:=human.skill_input_revision();human.clear_touch()
	assert_gt(human.skill_input_revision(),revision)
	revision=human.skill_input_revision();human.clear_gamepad()
	assert_gt(human.skill_input_revision(),revision)
	human.press_touch_key(KEY_Q);revision=human.skill_input_revision();human.hold=true
	assert_gt(human.skill_input_revision(),revision);assert_false(human.skill_is_held(0))

func test_precision_mode_and_camera_transform_preserve_manual_distance_and_movement() -> void:
	for mode in ["pad","touch","mouse","camera"]:
		var world:=fixture();var human: Controllers.Human=world.player.controller
		var offset:=Vector2(60,12)
		if mode=="touch":
			human.pad_move=Vector2.ZERO;human.pad_active=false;human.touch_owned=true
			human.touch_active=true;human.touch_move=Vector2.RIGHT
		elif mode=="mouse":
			human.pad_move=Vector2.ZERO;human.pad_active=false;human.key_aim=false
			world.aim_override=func() -> Vector2:return world.player.position+Vector2.RIGHT*80
		elif mode=="camera":
			world.move_override=func(v: Vector2) -> Vector2:return v.rotated(PI/2)
			offset=offset.rotated(PI/2)
		foe(world,offset)
		var movement: Vector2=human.move_dir(world)
		var raw: Vector2=human.aim_point(world)-world.player.position
		var corrected: Vector2=human.skill_aim(world,"smoke_screen",world.player.position+raw.normalized()*24)-world.player.position
		assert_almost_eq(corrected.length(),24.0,0.001,mode)
		assert_gt(raw.angle_to(corrected),0.0,mode)
		assert_lte(absf(raw.angle_to(corrected)),deg_to_rad(8 if human.skill_aim_precise() else 18)+0.001)
		assert_eq(human.move_dir(world),movement)

func test_every_production_charged_area_move_keeps_the_manual_distance() -> void:
	for move_id in ["smoke_screen","fire_spin","rock_throw","rock_tomb","sleep_powder","poison_powder","leech_seed","worry_seed","seed_bomb","sludge_bomb"]:
		var world:=fixture(move_id)
		assert_true(AimAssist.is_area_move(MoveDB.get_move(move_id)),move_id+" uses production charged-area metadata")
		foe(world,Vector2(35,6))
		var raw:=world.player.position+Vector2.RIGHT*24
		var corrected: Vector2=world.player.controller.skill_aim(world,move_id,raw)
		assert_almost_eq(corrected.distance_to(world.player.position),24.0,0.001,move_id)
		assert_gt(corrected.y,world.player.position.y,move_id)

func test_self_moves_and_old_auto_nearest_metadata_are_not_charged_area() -> void:
	assert_false(AimAssist.is_area_move({"targeting":"nearest_area"}))
	assert_true(AimAssist.is_area_move({"targeting":"charged_area"}))
	var world:=fixture("protect");foe(world,Vector2(50,8))
	assert_false(AimAssist.is_area_move(MoveDB.get_move("protect")))
	var raw:=world.player.position+Vector2.RIGHT*24
	assert_eq(world.player.controller.skill_aim(world,"protect",raw),raw)

func test_skill_preview_does_not_change_real_aim_or_input_state() -> void:
	var world:=fixture();var human: Controllers.Human=world.player.controller
	foe(world,Vector2(60,12))
	assert_true(human.has_method("peek_aim_point"))
	assert_true(human.has_method("peek_skill_aim"))
	if not human.has_method("peek_aim_point") or not human.has_method("peek_skill_aim"):return
	var raw:=world.player.position+Vector2.RIGHT*24
	var revision:=human.skill_input_revision()
	var before:={"pad":human.pad_active,"touch":human.touch_active,"key":human.key_aim,"mouse":human._last_mouse,"manual":human._skill_manual_direction,"corrected":human._skill_corrected_direction,"target":human.aim_assist._target}
	var first: Vector2=human.peek_skill_aim(world,"smoke_screen",raw)
	for _index in 5:
		assert_eq(human.peek_skill_aim(world,"smoke_screen",raw),first)
		human.peek_aim_point(world)
	assert_eq(human.skill_input_revision(),revision)
	assert_eq(human.pad_active,before.pad);assert_eq(human.touch_active,before.touch)
	assert_eq(human.key_aim,before.key);assert_eq(human._last_mouse,before.mouse)
	assert_eq(human._skill_manual_direction,before.manual);assert_eq(human._skill_corrected_direction,before.corrected)
	assert_eq(human.aim_assist._target,before.target)
	assert_eq(human.skill_aim(world,"smoke_screen",raw),first,"The real cast receives the same correction as a read-only preview")

func test_preview_matches_mouse_takeover_without_switching_real_pad_mode() -> void:
	var world:=fixture();var human: Controllers.Human=world.player.controller
	human.pad_move=Vector2.ZERO;human.pad_active=true;human.key_aim=false
	human._last_mouse=Vector2(-1000,-1000)
	world.aim_override=func() -> Vector2:return world.player.position+Vector2.RIGHT*80
	foe(world,Vector2(60,12))
	var raw: Vector2=human.peek_aim_point(world)
	var preview: Vector2=human.peek_skill_aim(world,"smoke_screen",raw)
	assert_true(human.pad_active,"Read-only preview cannot consume a mouse takeover")
	assert_eq(human._last_mouse,Vector2(-1000,-1000))
	var actual_raw: Vector2=human.aim_point(world)
	var actual: Vector2=human.skill_aim(world,"smoke_screen",actual_raw)
	assert_false(human.pad_active)
	assert_eq(preview,actual,"Preview and first real mouse cast need the same precise correction")
