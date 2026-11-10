extends GutTest

const DT := 1.0/60.0

func before_all() -> void:
	Controllers.ensure_input_map()

func after_each() -> void:
	for action in Controllers.ACTIONS: Input.action_release(action)
	await get_tree().process_frame

func fixture() -> World:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	var world := World.new()
	add_child_autofree(world)
	world.setup(7,"charmander",12,["scratch","growl","ember","smoke_screen"],Controllers.Human.new())
	world.player.position = Arena.center()
	return world

func test_fresh_blocked_press_acknowledges_all_input_gates_without_casting() -> void:
	for reason in ["recover","flinch","sleep","hitstop","dash","hop","skill_lock","paralysis_lock","rampage","no_skills","pp","cooldown","empty","fishing"]:
		var world := fixture()
		var p := world.player
		match reason:
			"recover": p.recover_t = 1.0
			"flinch": p.flinch_t = 1.0
			"sleep": p.sleep_t = 1.0
			"hitstop": p.hitstop_t = 1.0
			"dash": p.dash = {"hop":true}
			"hop": p.hop_t = 0.3
			"skill_lock": p.skill_lock_t = 1.0
			"paralysis_lock": p.para_lock_t = 1.0
			"rampage": p.rampage_t = 1.0
			"no_skills": world.no_skills = true
			"pp": p.pp[0] = 0
			"cooldown": p.use_t[0] = 1.0
			"empty": p.slots[0] = ""
			"fishing": world.field_water.fishing = {"test":true}
		var pp := p.pp.duplicate()
		var origin := p.position
		var rng := world.rng.state
		assert_true(world.skill_input_blocked(0),reason)
		Input.action_press("skill_0")
		world._step_player(DT)
		assert_gt(p.skill_denied_t,0.0,reason)
		assert_eq(p.pp,pp,"Rejected command spends no PP: "+reason)
		assert_eq(p.position,origin,"Feedback cannot move collision: "+reason)
		assert_eq(world.rng.state,rng,"Read-only gate check consumes no RNG: "+reason)
		assert_eq(world.pending_casts.size()+world.pending_melee.size()+world.projectiles.size(),0,reason)
		Input.action_release("skill_0")

func test_holding_rejected_key_does_not_retrigger_but_repress_does() -> void:
	var world := fixture()
	var p := world.player
	p.skill_lock_t = 3.0
	Input.action_press("skill_0")
	world._step_player(DT)
	for i in 30: world._step_player(DT)
	assert_eq(p.skill_denied_t,0.0,"No continuous shake while held")
	Input.action_release("skill_0")
	world._step_player(DT)
	Input.action_press("skill_0")
	world._step_player(DT)
	assert_almost_eq(p.skill_denied_t,Player.SKILL_DENIED_DURATION,0.00001)
	# Another rejected input during the pulse cannot keep extending it.
	p.tick_cooldowns(0.05)
	var remaining := p.skill_denied_t
	p.play_skill_denied_feedback()
	assert_eq(p.skill_denied_t,remaining)

func test_physical_release_repress_between_world_ticks_is_not_lost() -> void:
	var world := fixture()
	var c: Controllers.Human = world.player.controller
	world.player.skill_lock_t = 3.0
	Input.action_press("skill_0")
	world._step_player(DT)
	for i in 20: world._step_player(DT)
	assert_eq(world.player.skill_denied_t,0.0)
	Input.action_release("skill_0")
	Input.action_press("skill_0")
	c.record_skill_event(0,world)
	world._step_player(DT)
	assert_gt(world.player.skill_denied_t,0.0,"Event bridge preserves a fresh press even without a polled release")

func test_available_command_and_held_auto_fire_still_work() -> void:
	var world := fixture()
	var p := world.player
	var pp := int(p.pp[1])
	Input.action_press("skill_1")
	world._step_player(DT)
	assert_eq(p.pp[1],pp-1)
	assert_eq(world.pending_casts.size(),1)
	assert_eq(p.skill_denied_t,0.0,"Successful input does not shake")
	Input.action_release("skill_1")
	world = fixture()
	p = world.player
	p.use_t[0] = 0.08
	pp = int(p.pp[0])
	Input.action_press("skill_0")
	for i in 11: world._step_player(DT)
	assert_eq(p.pp[0],pp-1,"Held key still fires when its cooldown clears")
	for i in int(ceil(Player.SKILL_DENIED_DURATION/DT)): world._step_player(DT)
	assert_eq(p.skill_denied_t,0.0,"Auto-fire creates no extra rejection pulses")

func test_modal_hold_discards_queued_events_and_held_keys() -> void:
	var world := fixture()
	var c: Controllers.Human = world.player.controller
	world.player.skill_lock_t = 2.0
	c.record_skill_event(0,world)
	c.hold = true
	Input.action_press("skill_0")
	world._step_player(DT)
	assert_eq(world.player.skill_denied_t,0.0)
	Input.action_release("skill_0")
	world._step_player(DT)
	assert_false(c.hold)
	assert_eq(world.player.skill_denied_t,0.0,"No delayed shake from before the modal")
	Input.action_press("skill_0")
	world._step_player(DT)
	assert_gt(world.player.skill_denied_t,0.0)

func test_feedback_is_readable_cosmetic_and_expires_even_in_hitstop() -> void:
	var world := fixture()
	var p := world.player
	p.hitstop_t = 0.5
	var at := p.position
	var anchor := p.cam_anchor()
	Input.action_press("skill_0")
	world._step_player(DT)
	p.tick_cooldowns(DT)
	var offset := p.command_feedback_offset()
	assert_gt(absf(offset.x),2.0,"The opening shake must be visible at gameplay scale")
	assert_lte(absf(offset.x),Player.SKILL_DENIED_STRENGTH)
	assert_eq(offset.y,0.0)
	assert_eq(p.position,at)
	assert_eq(p.cam_anchor(),anchor)
	for i in int(ceil(Player.SKILL_DENIED_DURATION/DT))+1:
		p.tick_status(DT)
		world._step_player(DT)
	assert_gt(p.hitstop_t,0.0)
	assert_eq(p.command_feedback_offset(),Vector2.ZERO,"Rejection feedback must not freeze with the hurt pose")
	var enemy := Enemy.new()
	assert_eq(enemy.command_feedback_offset(),Vector2.ZERO)
	enemy.free()

func test_zone_restriction_and_burrow_emergence_match_real_gates() -> void:
	var world := fixture()
	world.player.equip(3,"fire_spin")
	world.cast(world.player,"fire_spin",Vector2.RIGHT,world.player.position+Vector2.RIGHT*30.0)
	assert_true(world._has_own_zone("fire_spin"))
	assert_true(world.skill_input_blocked(3))
	Input.action_press("skill_3")
	world._step_player(DT)
	assert_gt(world.player.skill_denied_t,0.0)
	world.player.burrow = {"slot":0,"sink":0.0,"t":0.5,"under":2.0}
	world.player.pp[0] = 0
	assert_false(world.skill_input_blocked(0),"The original burrow key can surface even with empty PP")
	assert_true(world.skill_input_blocked(1),"Other skills remain blocked underground")
	world.player.burrow.sink = 0.1
	assert_true(world.skill_input_blocked(0),"Still sinking")

func test_actual_paralysis_failure_is_acknowledged_without_spending_pp() -> void:
	var world := fixture()
	world.player.para_t = 1.0
	for seed in range(100):
		var trial := RandomNumberGenerator.new()
		trial.seed = seed
		if trial.randf()<Mon.PARA_FAIL:
			world.rng.seed = seed
			break
	var pp := world.player.pp.duplicate()
	Input.action_press("skill_1")
	world._step_player(DT)
	assert_eq(world.player.pp,pp)
	assert_eq(world.player.para_lock_t,Mon.TURN)
	assert_gt(world.player.skill_denied_t,0.0)

func test_dead_actor_does_not_acknowledge_or_replay_old_input() -> void:
	var world := fixture()
	world.player.dead = true
	world.player.skill_lock_t = 2.0
	Input.action_press("skill_0")
	world._step_player(DT)
	assert_eq(world.player.skill_denied_t,0.0)
	world.player.dead = false
	world._step_player(DT)
	assert_eq(world.player.skill_denied_t,0.0,"Held input from the dead state is not a new press")
