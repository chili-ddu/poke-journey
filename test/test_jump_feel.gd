extends GutTest

class Still:
	extends RefCounted
	func move_dir(_w) -> Vector2: return Vector2.ZERO
	func aim_point(w) -> Vector2: return w.player.position + Vector2.RIGHT * 80.0
	func want_skill(_i, _w) -> bool: return false
	func want_dodge(_w) -> bool: return false
	func want_jump(_w) -> bool: return false
	func want_item(_w) -> bool: return false

func test_descent_uses_approved_timing_without_changing_flight_duration() -> void:
	var hop: Dictionary = MonSprite.load_set(4).Hop
	assert_almost_eq(MonSprite.anim_length(hop), 0.4, 0.00001)
	# The last 12px descent now occupies 70ms instead of a single 60Hz tick.
	assert_almost_eq(MonSprite.hop_sheet_time(hop, 17.8/60.0), 21.0/60.0, 0.00001)
	assert_almost_eq(MonSprite.hop_sheet_time(hop, (17.8+2.1)/60.0), 21.5/60.0, 0.00001)
	assert_almost_eq(MonSprite.hop_sheet_time(hop, 22.0/60.0), 22.0/60.0, 0.00001)
	assert_almost_eq(MonSprite.hop_sheet_time(hop, -1.0), 0.0, 0.00001)
	assert_almost_eq(MonSprite.hop_sheet_time(hop, 0.4), 0.4, 0.00001)
	assert_almost_eq(MonSprite.hop_sheet_time(hop, 1.0), 0.4, 0.00001)
	var future := {"durations": [4, 8, 8, 4]}
	assert_almost_eq(MonSprite.hop_sheet_time(future, 0.21), 0.21, 0.00001, "Unfamiliar Hop layout keeps its authored timing")

func test_installed_normal_and_shiny_hops_keep_monotonic_clocks_and_source_data() -> void:
	var checked := 0
	for id in SpeciesDB.all_ids():
		var dex := int(SpeciesDB.get_species(id).dex)
		var path := MonSprite.ROOT % dex
		if not FileAccess.file_exists(path + "AnimData.xml"): continue
		for shiny in [false, true]:
			if shiny and not FileAccess.file_exists(path + "shiny/AnimData.xml"): continue
			var set := MonSprite.load_set(dex, shiny)
			if not set.has("Hop"): continue
			var hop: Dictionary = set.Hop
			var before: Array = hop.durations.duplicate()
			var duration := MonSprite.anim_length(hop)
			var last := -1.0
			for sample in 49:
				var mapped := MonSprite.hop_sheet_time(hop, duration * float(sample) / 48.0)
				assert_gte(mapped, last - 0.00001, str(id))
				assert_between(mapped, 0.0, duration + 0.00001, str(id))
				last = mapped
			assert_almost_eq(last, duration, 0.00001)
			assert_eq(hop.durations, before, "Visual retiming leaves gameplay metadata immutable")
			checked += 1
	assert_gte(checked, 72, "Includes all 36 installed Hop sheets and shinies; six species have no Hop image")

func test_landing_absorbs_quickly_recovers_and_can_be_interrupted() -> void:
	var mon := Mon.new()
	mon.setup("charmander", 5, Mon.TEAM_PLAYER)
	mon.landing_t = Mon.LANDING_DURATION
	assert_eq(mon.landing_scale(), Vector2.ONE)
	mon.landing_t -= 0.03
	assert_almost_eq(mon.landing_scale().x, 1.08, 0.00001)
	assert_almost_eq(mon.landing_scale().y, 0.90, 0.00001)
	var last_y := mon.landing_scale().y
	for elapsed in [0.06, 0.09, 0.12, 0.15]:
		mon.landing_t = maxf(0.0, Mon.LANDING_DURATION - float(elapsed))
		assert_gte(mon.landing_scale().y, last_y)
		last_y = mon.landing_scale().y
	assert_eq(mon.landing_scale(), Vector2.ONE)
	mon.landing_t = 0.10
	assert_true(mon.can_act(), "Landing adds no recovery or input lock")
	mon.play_hop()
	assert_eq(mon.landing_t, 0.0, "A new jump cancels the old landing squash")
	assert_eq(mon.landing_scale(), Vector2.ONE)
	mon.free()

func test_shadow_tracks_the_same_retimed_subframe_as_the_body() -> void:
	for id in ["bulbasaur", "charmander", "squirtle", "onix"]:
		var mon := Mon.new()
		mon.setup(id, 5, Mon.TEAM_PLAYER)
		mon._anim_name = "Hop"
		mon._anim_start = 0.0
		mon.lift = 3.0
		var hop: Dictionary = mon._sprites.Hop
		for row in 8:
			mon.facing = Vector2.DOWN.rotated(-float(row) * PI / 4.0)
			for elapsed in [0.0, 0.18, 0.325, 0.34, 0.4]:
				mon.anim_t = float(elapsed)
				var time := MonSprite.hop_sheet_time(hop, mon.anim_t)
				var shown := MonSprite.visual_frame(hop, row, time, false)
				var first: Vector2 = hop.centers[row][0]
				var expected := 3.0 + maxf(0.0, (first.y - (shown.body_center as Vector2).y) * mon.sprite_scale)
				assert_almost_eq(View3D.shadow_height(mon), expected, 0.00001, "Shadow and visible C pose share the same height")
				assert_almost_eq(mon.visual_shadow_height(), expected, 0.00001, "Flat and 3D shadows use the same visual clock")
		mon.free()

func test_jump_preserves_flight_distance_and_missing_sheet_fallback() -> void:
	DungeonDB.set_current("test_meadow")
	Arena.configure(DungeonDB.theme())
	for id in ["bulbasaur", "charmander", "squirtle", "onix", "gyarados", "kakuna", "pikachu"]:
		var world := World.new()
		add_child_autofree(world)
		world.setup(7, id, 12, ["scratch"], Still.new())
		var mon := world.player
		mon.position = Arena.center()
		var target := mon.position + Vector2.RIGHT * Player.JUMP_DISTANCE
		var rng_before := world.rng.state
		world._start_hop(target)
		var ticks := 0
		while mon.is_dashing() and ticks < 60:
			mon.tick_status(1.0/60.0)
			world._step_dash(mon, 1.0/60.0)
			ticks += 1
		assert_eq(ticks, 24 if mon._sprites.has("Hop") else 12, str(id))
		assert_lt(mon.position.distance_to(target), 0.01, "Still moves exactly 48px")
		assert_eq(mon.recover_t, 0.0)
		assert_eq(mon.skill_lock_t, 0.0)
		assert_eq(mon.invuln_t, 0.0)
		assert_eq(world.rng.state, rng_before)
	# Missing-pose fallback is an explicit fixture now that previously absent
	# Kakuna/Pikachu Hop sheets can be installed by the mainland asset fetcher.
	var fallback:=World.new();add_child_autofree(fallback)
	fallback.setup(7,"pikachu",12,["scratch"],Still.new())
	fallback.player._sprites=fallback.player._sprites.duplicate()
	fallback.player._sprites.erase("Hop")
	fallback.player.position=Arena.center()
	var target:=fallback.player.position+Vector2.RIGHT*Player.JUMP_DISTANCE
	fallback._start_hop(target)
	var ticks:=0
	while fallback.player.is_dashing() and ticks<60:
		fallback.player.tick_status(1.0/60.0)
		fallback._step_dash(fallback.player,1.0/60.0)
		ticks+=1
	assert_eq(ticks,12)
	assert_lt(fallback.player.position.distance_to(target),0.01)
