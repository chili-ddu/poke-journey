extends GutTest

const Motion = preload("res://scripts/view/charmander_motion.gd")

func test_walking_cadence_tracks_distance_and_hitstop_freezes_it() -> void:
	var slow := Mon.new()
	var fast := Mon.new()
	for mon in [slow, fast]: mon.setup("charmander", 5, Mon.TEAM_PLAYER)
	slow.vel = Vector2(24, 0)
	fast.vel = Vector2(48, 0)
	slow.tick_status(0.1)
	fast.tick_status(0.05)
	assert_almost_eq(slow.motion_sheet_time("Walk", 0.0), fast.motion_sheet_time("Walk", 0.0), 0.00001, "Equal travel yields the same footfall phase")
	var phase := slow.motion_sheet_time("Walk", 0.0)
	slow.hitstop_t = 0.1
	slow.tick_status(0.05)
	assert_eq(slow.motion_sheet_time("Walk", 0.0), phase, "Hit-stop freezes feet with the body")
	slow.hitstop_t = 0.0
	slow.vel = Vector2.ZERO
	slow.tick_status(0.1)
	assert_eq(slow.motion_sheet_time("Walk", 0.0), phase, "A stationary actor accumulates no steps")
	slow.dash = {"speed": 320.0}
	slow.tick_status(0.02)
	assert_gt(slow.motion_sheet_time("Walk", 0.0), phase, "Dodge has zero velocity but still animates its running feet")
	slow.free()
	fast.free()

func test_loops_are_continuous_and_never_extend_action_locks() -> void:
	var mon := Mon.new()
	mon.setup("charmander", 5, Mon.TEAM_PLAYER)
	mon.play_attack("Charge", 0.8)
	var lock_time := mon.attack_anim_t
	var durations: Array = mon._sprites.Charge.durations.duplicate()
	for pair in [["Idle", Motion.IDLE_SECONDS], ["Charge", Motion.CHARGE_SECONDS]]:
		assert_almost_eq(mon.motion_sheet_time(pair[0], pair[1]), 0.0, 0.00001)
		assert_almost_eq(mon.motion_sheet_time(pair[0], pair[1] + 0.1), mon.motion_sheet_time(pair[0], 0.1), 0.00001)
		assert_eq(Motion.stance_scale(pair[0], 0.0), Vector2.ONE)
		assert_eq(Motion.stance_scale(pair[0], pair[1]), Vector2.ONE)
	assert_eq(mon.attack_anim_t, lock_time)
	assert_eq(mon._sprites.Charge.durations, durations)
	assert_eq(mon.motion_sheet_time("Hop", 0.23), 0.23, "Approved jump clock is untouched")
	mon.free()

func test_scratch_preserves_the_entire_approved_display_clock() -> void:
	var anim: Dictionary = MonSprite.load_set(4).Strike
	var previous := -1.0
	for i in 401:
		var time := MonSprite.anim_length(anim) * float(i) / 400.0
		var shown := Motion.strike_time(anim, time, false)
		assert_eq(shown,time,"Every subframe retains the approved timing, not only contact keys")
		assert_gte(shown, previous - 0.000001)
		assert_eq(MonSprite.frame_at(anim, shown, false), MonSprite.frame_at(anim, time, false), "Contact keys stay on their existing timestamps")
		previous = shown
	for key in anim.durations.size():
		var time := MonSprite.frame_start(anim, key)
		assert_almost_eq(Motion.strike_time(anim, time, false), time, 0.000001)

func test_other_species_keep_their_existing_clock() -> void:
	var mon := Mon.new()
	mon.setup("squirtle", 5, Mon.TEAM_PLAYER)
	for name in ["Idle", "Walk", "Charge", "Hop"]:
		assert_eq(mon.motion_sheet_time(name, 0.23), 0.23)
	mon.free()
