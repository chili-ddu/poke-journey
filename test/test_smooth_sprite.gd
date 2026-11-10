extends GutTest

func after_each() -> void:
	SmoothSprite.enabled = true

func test_visual_subframes_preserve_logical_clock_and_source_keys() -> void:
	var anim: Dictionary = MonSprite.load_set(4).Walk
	var duration := float(anim.durations[0]) * MonSprite.TICK
	var length := MonSprite.anim_length(anim)
	var row := 2
	for phase in 4:
		var t := duration * (float(phase) + 0.1) / 4.0
		var sample := MonSprite.visual_frame(anim, row, t)
		assert_eq(MonSprite.frame_at(anim, t), 0)
		assert_eq(sample.src.size, Vector2(anim.fw, anim.fh))
		# The native two-step walk holds its key through the first third,
		# then shows one passing pose; NPC/UI effects still use four steps.
		if phase < 2: assert_same(sample.tex, anim.tex)
		else: assert_ne(sample.tex, anim.tex, "Intermediate phase uses the baked atlas")
		assert_eq(MonSprite.anim_length(anim), length, "No attack/movement clock changes")
	var end := MonSprite.visual_frame(anim, row, length - duration * 0.1, false)
	assert_same(end.tex, anim.tex, "One-shots hold their last key; no reverse morph")
	assert_eq(MonSprite.frame_at(anim, length + 2.0, false), anim.durations.size()-1)
	var at_end := MonSprite.visual_frame(anim, row, length + 2.0, false)
	assert_same(at_end.tex, anim.tex)
	var looped := MonSprite.visual_frame(anim, row, length + duration * 0.6)
	var initial := MonSprite.visual_frame(anim, row, duration * 0.6)
	assert_same(looped.tex, initial.tex)
	assert_eq(looped.src, initial.src)

func test_attack_hold_and_disabled_mode_use_the_exact_original_pose() -> void:
	var anim: Dictionary = MonSprite.load_set(4).Strike
	var duration := float(anim.durations[0]) * MonSprite.TICK
	var sample := MonSprite.visual_frame(anim, 2, duration * 0.8, false, 0, 0)
	assert_same(sample.tex, anim.tex, "Truncated lunge cannot blend into a discarded frame")
	sample = MonSprite.visual_frame(anim, 2, duration * 0.8, false, 2)
	assert_same(sample.tex, anim.tex, "An attack override is a held key")
	assert_eq(sample.src.position.x, float(anim.fw * 2))
	SmoothSprite.enabled = false
	sample = MonSprite.visual_frame(anim, 2, duration * 0.8)
	assert_same(sample.tex, anim.tex)

func test_npc_both_directions_and_cropped_icons_resolve_atlas_frames() -> void:
	var npc := Npc.new()
	npc._tex = load("res://assets/npcs/prof_oak.png")
	npc.face = "right"
	npc.walk_target = Vector2(50, 0)
	npc._walk_t = 0.1
	var sample := npc.visual_frame()
	assert_ne(sample.tex, npc._tex)
	assert_eq(sample.src.size, Npc.FRAME)
	npc._walk_t += 1.0/6.0
	var back := npc.visual_frame()
	assert_ne(back.src, sample.src, "Reverse half of the walk has its own flow")
	npc.walk_target = Vector2.INF
	assert_same(npc.visual_frame().tex, npc._tex, "Standing NPCs keep their original key")
	npc.free()
	var icon := PixelUi.ui_tex("plat/icons/charmander")
	var crop := Rect2(4, 7, 23, 24)
	var target := Rect2(4, 39, 23, 24)
	var whole := SmoothSprite.vertical(icon, Vector2(32,32), 0, 1, 0.6)
	var cropped := SmoothSprite.between(icon, crop, target, 0.6)
	assert_ne(cropped.tex, icon)
	assert_same(cropped.tex, whole.tex)
	assert_eq(cropped.src.position, whole.src.position + crop.position)
	assert_eq(cropped.src.size, crop.size)

func test_fx_lifetime_snap_and_grass_cutout_stay_intact() -> void:
	var fx := Fx.new()
	fx.kind = "anim"
	fx.text = "g4_scary_face"
	fx.frames = 4
	fx.lifetime = 0.8
	var tex := Fx.sheet(fx.text)
	assert_ne(fx.anim_visual(0.15).tex, tex)
	assert_eq(fx.lifetime, 0.8)
	fx.scare_snap = true
	assert_same(fx.anim_visual(0.59).tex, tex, "Do not anticipate the authored surprise cut")
	assert_eq(fx.anim_frame_at(Fx.SCARE_SNAP_START), 3)
	assert_same(fx.anim_visual(1.0).tex, tex)
	fx.kind = "tallgrass"
	fx.age = Fx.GRASS_FRAME_T * 0.6
	var sample := fx.grass_visual()
	assert_ne(sample.tex, Fx.grass_cutout_texture())
	assert_eq(sample.src.size, Vector2(16,16))
	fx.settled = true
	assert_same(fx.grass_visual().tex, Fx.grass_cutout_texture())
	fx.free()

func test_texture_swaps_and_missing_assets() -> void:
	var a := Fx.sheet("g4_bolt_a")
	var b := Fx.sheet("g4_bolt_b")
	var region := Rect2(Vector2.ZERO, a.get_size())
	var sample := SmoothSprite.between(a, region, region, 0.6, b)
	assert_ne(sample.tex, a)
	var missing := ImageTexture.create_from_image(Image.create(8,8,false,Image.FORMAT_RGBA8))
	var original := Rect2(0,0,4,4)
	sample = SmoothSprite.between(missing, original, Rect2(4,0,4,4), 0.7)
	assert_same(sample.tex, missing, "Unbaked future assets safely keep their original drawing")
	assert_eq(sample.src, original)

func test_scratch_remapped_transitions_use_c_frames_and_holds_stay_still() -> void:
	for shiny in [false, true]:
		var anim: Dictionary = MonSprite.load_set(4, shiny).Strike
		for row in 8:
			for logical in [0, 2, 3, 7]:
				var time := MonSprite.frame_start(anim, logical) + float(anim.durations[logical])*MonSprite.TICK*0.6
				var sample := MonSprite.visual_frame(anim, row, time, false, -1, -1, Mon.SCRATCH_POSE_ORDER)
				assert_ne(sample.tex, anim.tex, "Mapped 0->2 and 4->1 transitions must not skip C interpolation")
			for logical in [1, 4, 5, 6, 8]:
				var time := MonSprite.frame_start(anim, logical) + float(anim.durations[logical])*MonSprite.TICK*0.6
				var sample := MonSprite.visual_frame(anim, row, time, false, -1, -1, Mon.SCRATCH_POSE_ORDER)
				assert_same(sample.tex, anim.tex, "Authored contact holds stay still")

func test_hurt_pacing_and_attack_resume_do_not_change_gameplay_clocks() -> void:
	var mon := Mon.new()
	mon.setup("charmander", 5, Mon.TEAM_PLAYER)
	mon.anim_t = 2.0
	mon.play_attack("Attack")
	var duration := mon.attack_anim_t
	mon.hurt_t = Mon.HURT_ANIM
	mon._anim_name = "Hurt"
	mon._anim_start = 2.10
	mon.anim_t = 2.20
	assert_almost_eq(mon.attack_visual_elapsed(), 0.20, 0.0001, "Attack does not replay preparation after Hurt")
	mon._anim_name = "Attack"
	mon._anim_start = mon.anim_t
	assert_almost_eq(mon.attack_visual_elapsed(), 0.20, 0.0001)
	assert_eq(mon.attack_anim_t, duration, "Visual sampling cannot extend the action lock")
	assert_eq(mon.hurt_t, Mon.HURT_ANIM)
	var length := MonSprite.anim_length(mon._sprites.Hurt)
	assert_almost_eq(mon.hurt_sheet_time(0.0), 0.0, 0.0001)
	assert_almost_eq(mon.hurt_sheet_time(Mon.HURT_ANIM), length, 0.0001)
	assert_lt(mon.hurt_sheet_time(0.1), 0.1, "Short hurt sheet uses the existing display interval")
	mon.hurt_t = 0.0
	mon.recover_t = 0.0
	assert_true(mon.can_act(), "The cosmetic reaction adds no input lock")
	mon.play_attack("Attack")
	assert_almost_eq(mon.attack_visual_elapsed(), 0.0, 0.0001, "A new attack always restarts even if the clip name is unchanged")
	mon.free()

func test_grounded_attack_subframes_share_walk_origin_and_true_support() -> void:
	for shiny in [false, true]:
		var mon := Mon.new()
		mon.shiny = shiny
		mon.setup("charmander", 5, Mon.TEAM_PLAYER)
		mon.attack_full_recovery = true
		var anim: Dictionary = mon._sprites.Strike
		var walk: Dictionary = mon._sprites.Walk
		for row in 8:
			mon.facing = Vector2.DOWN.rotated(-float(row)*PI/4.0)
			var walk_x: float = (walk.centers[row][0] as Vector2).x - MonSprite.anchor_of(mon._sprites, walk).x
			for logical in [0, 2, 3, 4, 7, 8]:
				for progress in [0.0, 0.3, 0.6, 0.9]:
					var time := MonSprite.frame_start(anim, logical) + float(anim.durations[logical])*MonSprite.TICK*float(progress)
					var visual := MonSprite.visual_frame(anim, row, time, false, -1, -1, Mon.SCRATCH_POSE_ORDER)
					var center := mon.grounded_attack_anchor(anim, row, visual)
					assert_almost_eq((visual.body_center as Vector2).x-center.x, walk_x, 0.001, "No sideways drift, including up-facing interpolated poses")
					var image: Image = visual.tex.get_image().get_region(Rect2i(visual.src))
					var bottom := image.get_used_rect().end.y-1
					assert_almost_eq(float(bottom)-center.y, float(mon._sprites.feet_dy)-1.0, 0.001, "The rendered feet remain grounded between source keys")
		mon.free()
