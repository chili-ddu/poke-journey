extends GutTest

const DT:=1.0/60.0

func before_all() -> void:Controllers.ensure_input_map()

func after_each() -> void:
	for action in Controllers.ACTIONS:Input.action_release(action)
	await get_tree().process_frame

func fixture(move: String="rollout") -> World:
	DungeonDB.set_current("test_meadow");Arena.configure(DungeonDB.theme());Arena.obstacles=[]
	var world:=World.new();add_child_autofree(world)
	world.setup(17,"charmander",30,[move],Controllers.Human.new())
	world.player.position=Vector2(300,170);world.player.facing=Vector2.RIGHT
	world.player.controller.pad_move=Vector2.RIGHT;world.player.controller.pad_active=true
	return world

func foe(world: World,offset: Vector2) -> Enemy:
	var actor:=Enemy.new();actor.setup_trainer_mon("squirtle",30,["tackle"],world.rng)
	actor.position=world.player.position+offset;actor.frozen=true
	world.add_child(actor);world.enemies.append(actor)
	return actor

func press(world: World) -> void:
	world.player.controller.press_gamepad_key(KEY_Q);world._step_player(DT)

func test_attack_dash_does_not_grant_invulnerability_or_erase_existing_protection() -> void:
	var world:=fixture();world.cast(world.player,"rollout",Vector2.RIGHT,world.player.position+Vector2.RIGHT*48)
	assert_eq(world.player.invuln_t,0.0,"Ordinary attacking dashes stay vulnerable")
	world.player.invuln_t=.2
	world.cast(world.player,"rollout",Vector2.RIGHT,world.player.position+Vector2.RIGHT*48)
	assert_eq(world.player.invuln_t,.2,"An attack must not erase a separate hit/dodge grace period")

func test_attack_dash_stops_at_first_body_across_a_long_frame() -> void:
	var world:=fixture();var target:=foe(world,Vector2(38,0));var before:=target.hp
	world.player.acc_stage=6;target.eva_stage=-6
	var start:=world.player.position
	world.cast(world.player,"rollout",Vector2.RIGHT,start+Vector2.RIGHT*48)
	world._step_dash(world.player,.5)
	assert_true(world.player.dash.is_empty())
	assert_lt(world.player.position.x,target.position.x)
	assert_gte(world.player.position.distance_to(target.position),world.player.radius+target.radius-.02)
	assert_lt(target.hp,before,"Swept contact cannot skip a target when the frame is longer than the dash")

func test_attack_dash_stops_at_wall_on_its_line_instead_of_sliding_or_tunneling() -> void:
	var world:=fixture();var start:=world.player.position
	Arena.obstacles=[{"pos":start+Vector2(25,7),"r":8.0}]
	world.cast(world.player,"rollout",Vector2.RIGHT,start+Vector2.RIGHT*48)
	world._step_dash(world.player,.5)
	assert_almost_eq(world.player.position.y,start.y,.001)
	assert_lt(world.player.position.x,start.x+25)
	assert_true(world.player.dash.is_empty())
	assert_false(Arena.blocks(world.player.position,world.player.radius))

func test_dash_preview_matches_locked_path_and_does_not_mutate_combat_or_aim() -> void:
	var world:=fixture();foe(world,Vector2(38,6))
	assert_true(world.has_method("dash_aim_preview"));if not world.has_method("dash_aim_preview"):return
	var controller: Controllers.Human=world.player.controller
	world.aim_point=controller.aim_point(world)
	var pp:=world.player.pp.duplicate();var state:=world.rng.state;var pos:=world.player.position
	var sticky=controller.aim_assist._target
	var preview: Dictionary=world.call("dash_aim_preview")
	assert_false(preview.is_empty())
	assert_eq(world.player.pp,pp);assert_eq(world.rng.state,state);assert_eq(world.player.position,pos)
	assert_eq(controller.aim_assist._target,sticky)
	press(world)
	var active: Dictionary=world.call("dash_aim_preview")
	assert_true(active.active)
	controller.pad_move=Vector2.UP
	assert_eq(world.call("dash_aim_preview").to,active.to,"A moving dash cannot be steered by new aim")
	world._step_dash(world.player,.5)
	assert_lt(world.player.position.distance_to(active.to),.05)

func test_melee_approaches_contact_but_never_crosses_body_or_reorients_mid_attack() -> void:
	var world:=fixture("tackle");var target:=foe(world,Vector2(1,0))
	var start:=world.player.position
	target.position=start+Vector2.RIGHT*(world.player.radius+target.radius+3)
	world.cast(world.player,"tackle",Vector2.RIGHT,target.position)
	world.player.play_attack("Attack",0,true)
	world._step_glide(world.player,1.0)
	assert_gt(world.player.position.x,start.x+2.8,"Approach reaches the front edge instead of discarding an entire blocked frame")
	assert_gte(world.player.position.distance_to(target.position),world.player.radius+target.radius-.02)
	world.player.controller.pad_move=Vector2.UP
	world._step_player(DT)
	assert_eq(world.player.facing,Vector2.RIGHT,"The drawn attack, movement and hit share one fixed direction")
	world.player.tick_status(2.0)
	assert_gte(world.player.position.distance_to(target.position),world.player.radius+target.radius-.02,"The end-of-animation lunge cannot step through the defender")

func test_committed_long_windup_keeps_start_direction_and_blocks_jump_and_other_skills() -> void:
	var world:=fixture("solar_beam");world.player.add_learned("poison_sting");world.player.equip(1,"poison_sting")
	var target:=foe(world,Vector2(70,10));var before:=world.player.pp.duplicate()
	press(world)
	var locked:=world.player.facing
	world.player.controller.release_gamepad_key(KEY_Q)
	world.player.controller.pad_move=Vector2.UP
	world.player.controller.press_gamepad_key(KEY_SPACE)
	world.player.controller.press_gamepad_key(KEY_W)
	world._step_player(.5)
	assert_false(world.player.dash.get("hop",false),"Jump cannot bypass the committed windup")
	assert_eq(world.pending_casts.size(),1)
	assert_eq(world.player.pp[0],int(before[0])-1)
	assert_eq(world.player.pp[1],before[1])
	assert_eq(world.player.facing,locked)
	target.position=world.player.position+Vector2(0,-60)
	world.player.controller.clear_gamepad()
	world.player.position+=Vector2(40,20)
	world._step_pending_casts(3.0)
	assert_eq(world.pending_beams.size(),1)
	assert_eq(world.pending_beams[0].dir,locked,"Moving target/caster and clearing input cannot rotate the committed shot")
	assert_true(world.pending_casts.is_empty())

func test_long_windup_does_not_stack_when_the_same_button_remains_held() -> void:
	var world:=fixture("solar_beam");press(world)
	for _frame in 120:world._step_player(DT)
	assert_eq(world.pending_casts.size(),1,"Use-delay ending must not queue another long preparation")
	assert_eq(world.player.pp[0],MoveDB.pp_of("solar_beam")-1)

func test_committed_preparation_survives_status_but_not_death() -> void:
	var world:=fixture("skull_bash");press(world)
	var locked:=world.player.facing
	world.player.sleep_t=2.0;world.player.flinch_t=1.0
	world._step_pending_casts(3.0)
	assert_false(world.player.dash.is_empty())
	assert_eq(world.player.dash.dir,locked)
	var dead_world:=fixture("solar_beam");press(dead_world);dead_world.player.dead=true
	dead_world._step_pending_casts(3.0)
	assert_true(dead_world.pending_casts.is_empty());assert_true(dead_world.pending_beams.is_empty())

func test_flamethrower_remains_a_finite_cast_after_button_release() -> void:
	var world:=fixture("flamethrower");press(world)
	world.player.controller.release_gamepad_key(KEY_Q)
	for _frame in 60:world._step_bursts(DT)
	assert_true(world.bursts.is_empty())
	assert_eq(world.projectiles.size(),int(MoveDB.get_move("flamethrower").count))
	assert_eq(world.player.pp[0],MoveDB.pp_of("flamethrower")-1)

func test_dash_uses_the_nearest_diagonal_large_body_independent_of_enemy_order() -> void:
	for reverse in [false,true]:
		var world:=fixture();var dir:=Vector2(1,1).normalized();var start:=world.player.position
		var near:=foe(world,dir*36);near.radius=14.0;near.protect_t=2.0
		var far:=foe(world,dir*45);far.protect_t=2.0
		if reverse:world.enemies.reverse()
		world.cast(world.player,"rollout",dir,start+dir*48)
		world._step_dash(world.player,.5)
		var expected:=start+dir*(36-world.player.radius-near.radius-.01)
		assert_lt(world.player.position.distance_to(expected),.01)
		assert_true(world.player.dash.is_empty(),"Protection does not turn a solid body into a passage")
		assert_eq(near.stats,SpeciesDB.stats_at(near.species_id,near.level,near.ivs))

func test_melee_and_dash_can_exit_a_rear_overlap_but_still_stop_at_a_front_body() -> void:
	var world:=fixture();var start:=world.player.position
	foe(world,Vector2(-8,0))
	var front:=foe(world,Vector2(35,0));front.protect_t=2.0
	world.cast(world.player,"rollout",Vector2.RIGHT,start+Vector2.RIGHT*48)
	world._step_dash(world.player,.5)
	assert_gt(world.player.position.x,start.x+5,"A defender behind the caster must not trap forward movement")
	assert_almost_eq(world.player.position.x,front.position.x-world.player.radius-front.radius-.01,.01)

func test_dash_exception_is_explicit_and_dodge_keeps_its_own_invulnerability() -> void:
	var world:=fixture();var move:=MoveDB.get_move("rollout")
	move["dash_invulnerable"]=true
	world.cast(world.player,"rollout",Vector2.RIGHT,world.player.position+Vector2.RIGHT*48)
	move.erase("dash_invulnerable")
	assert_gt(world.player.invuln_t,0.0,"Only an explicit per-move exception grants attacking-dash immunity")
	world.player.invuln_t=0.0;world.player.dash={}
	world._start_dodge(Vector2.RIGHT)
	assert_almost_eq(world.player.invuln_t,Player.DODGE_DURATION+.06,.00001)

func test_recoil_dash_stops_at_front_and_pays_the_original_recoil_once() -> void:
	var world:=fixture("take_down");var target:=foe(world,Vector2(40,0))
	world.player.acc_stage=6;target.eva_stage=-6
	var before:=world.player.hp;var hp_before:=target.hp
	world.cast(world.player,"take_down",Vector2.RIGHT,target.position)
	world._step_dash(world.player,.5)
	var lost:=hp_before-target.hp
	assert_gt(lost,0)
	assert_eq(world.player.hp,before-maxi(1,roundi(lost*.25)))
	assert_true(world.player.dash.is_empty())
	assert_gte(world.player.position.distance_to(target.position),world.player.radius+target.radius-.02)
	assert_eq(world.player.stats,SpeciesDB.stats_at(world.player.species_id,world.player.level,world.player.ivs))

func test_incoming_damage_uses_the_same_formula_during_an_attack_dash() -> void:
	var world:=fixture();var attacker:=foe(world,Vector2(60,0))
	world.cast(world.player,"rollout",Vector2.RIGHT,attacker.position)
	var hit:=world.make_hit(attacker,"water_gun")
	var hp:=world.player.hp;var state:=world.rng.state
	assert_true(world.apply_hit(world.player,hit,attacker.position))
	var dash_loss:=hp-world.player.hp
	assert_gt(dash_loss,0,"The ordinary incoming hit actually reaches the dashing player")
	world.player.dash={};world.player.hp=hp;world.player.invuln_t=0;world.player.hitstop_t=0;world.player.flinch_t=0
	world.rng.state=state
	assert_true(world.apply_hit(world.player,hit,attacker.position))
	assert_eq(hp-world.player.hp,dash_loss,"Dashing never adds a separate damage multiplier")
	assert_eq(world.player.stats,SpeciesDB.stats_at(world.player.species_id,world.player.level,world.player.ivs))

func test_an_interrupted_melee_direction_cannot_leak_into_a_later_projectile() -> void:
	var world:=fixture("tackle")
	world.cast(world.player,"tackle",Vector2.RIGHT,world.player.position+Vector2.RIGHT*60)
	world.player.play_attack("Attack",0,true)
	world._interrupt_melee(world.player)
	world.player.add_learned("poison_sting");world.player.equip(0,"poison_sting")
	world.player.controller.pad_move=Vector2.UP
	press(world);world._step_player(DT)
	assert_eq(world.player.facing,Vector2.UP,"Direction commitment ends with the attack that owned it")
	assert_lt(world.projectiles[0].vel.y,0.0)
