extends GutTest

# 화면 느낌(Look, 사용자 요청 2026-11-02 HD-2D 시제품): 켜고 끄기·장소 밝기·조명 세기·발광 규칙.

func after_each() -> void:
	Look.mode = Look.DEFAULT_MODE
	Look.ambient_now = Color.WHITE
	Look.sprite_tone = true
	Look.selout = true
	Look._selout_cache.clear()
	Look._sprite_images.clear()

func test_visible_cell_shading_matches_whole_sheet_and_keeps_source_intact() -> void:
	for dex in [4, 7, 95]:
		var anim: Dictionary = MonSprite.load_set(dex).Walk
		for phase in [0.0, 0.6]:
			var visual := MonSprite.visual_frame(anim, 2, float(anim.durations[0])*MonSprite.TICK*phase)
			var before: PackedByteArray = visual.tex.get_image().get_data()
			var whole := Look.selout_texture(visual.tex, "forest").get_image().get_region(Rect2i(visual.src))
			var cell := Look.selout_frame(visual.tex, visual.src, "forest")
			assert_eq(cell.src, Rect2(Vector2.ZERO, visual.src.size))
			assert_eq(cell.tex.get_image().get_data(), whole.get_data(), "Visible colors and outline stay identical")
			assert_eq(visual.tex.get_image().get_data(), before, "Source atlas is immutable")
			assert_same(Look.selout_frame(visual.tex, visual.src, "forest").tex, cell.tex, "A repeated pose reuses its small texture")

func test_visible_cell_cache_distinguishes_crop_profile_and_tone() -> void:
	var anim: Dictionary = MonSprite.load_set(4).Walk
	var src := Rect2(0,64,32,32)
	var day := Look.selout_frame(anim.tex, src, "day")
	var indoor := Look.selout_frame(anim.tex, src, "indoor")
	assert_ne(day.tex.get_image().get_data(), indoor.tex.get_image().get_data())
	var next := Look.selout_frame(anim.tex, Rect2(32,64,32,32), "day")
	assert_ne(day.tex, next.tex)
	Look.sprite_tone = false
	assert_ne(Look.selout_frame(anim.tex, src, "day").tex, day.tex)
	Look.selout = false
	var original := Look.selout_frame(anim.tex, src)
	assert_same(original.tex, anim.tex)
	assert_eq(original.src, src)

func test_toggle_and_flat_is_untouched() -> void:
	Look.mode = "hd2d"
	Look.toggle()
	assert_eq(Look.mode, "flat")
	assert_eq(Look.ambient("viridian_forest"), Color.WHITE, "flat 은 화면을 물들이지 않는다")
	assert_false(Look.emissive("g4_flame", Color(1.0, 0.6, 0.2)), "flat 은 가산 합성도 없다")
	Look.toggle()
	assert_true(Look.hd2d())

func test_forest_is_darker_and_lights_stronger() -> void:
	Look.mode = "hd2d"
	var day := Look.ambient("kanto_south")
	var forest := Look.ambient("viridian_forest")
	var lum := func(c: Color) -> float: return c.r * 0.299 + c.g * 0.587 + c.b * 0.114
	assert_lt(lum.call(forest), lum.call(day), "숲 그늘이 낮 바깥보다 어둡다")
	Look.ambient_now = day
	var g_day := Look.light_gain()
	Look.ambient_now = forest
	assert_gt(Look.light_gain(), g_day, "어두운 곳일수록 꼬리불·불꽃 조명이 세다")

func test_emissive_rules() -> void:
	Look.mode = "hd2d"
	assert_true(Look.emissive("g4_flame", Color(1.0, 0.6, 0.2)))
	assert_false(Look.emissive("g4_glow", Color(0.12, 0.06, 0.02, 0.45)), "그을음(어두운 색)은 가산 합성하지 않는다")
	assert_false(Look.emissive("g4_smoke", Color(0.9, 0.9, 0.9)), "연기는 빛나지 않는다")

func test_mon_sprites_are_not_lit() -> void:
	var m := Enemy.new()
	m.setup_enemy("charmander", 5, RandomNumberGenerator.new())
	assert_eq(m.light_mask, Look.UNLIT_MASK, "조명이 포켓몬 도트를 하얗게 날리지 않게")
	var l := Look.make_light(Color.WHITE, 1.0, 32.0)
	assert_eq(l.range_item_cull_mask, 1, "조명은 바닥·사람만")
	m.free()
	l.free()

func test_selout_recolors_outer_outline_only() -> void:
	# 셀아웃(사용자 2026-11-02): 바깥 테두리(투명과 맞닿은 검은 선)만 이웃 몸 색의 어두운/밝은 톤으로, 안쪽 검은 점(눈)은 그대로.
	var img := Image.create(7, 7, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(1, 6):
		for x in range(1, 6):
			img.set_pixel(x, y, Color(0, 0, 0, 1) if x in [1, 5] or y in [1, 5] else Color(1.0, 0.5, 0.3, 1))
	img.set_pixel(3, 3, Color(0, 0, 0, 1))          # 눈
	var tex := ImageTexture.create_from_image(img)
	Look.selout = true
	var out := Look.selout_texture(tex).get_image()
	var left := out.get_pixel(1, 3)
	var right := out.get_pixel(5, 3)
	assert_gt(left.r, 0.2, "왼쪽 테두리는 더 이상 검지 않다(몸 색의 어두운 톤)")
	assert_gt(right.r, left.r, "빛 쪽(오른쪽) 테두리가 더 밝다")
	assert_eq(out.get_pixel(3, 3), Color(0, 0, 0, 1), "안쪽 검은 점(눈)은 그대로")
	assert_eq(out.get_pixel(0, 0).a, 0.0, "바깥 투명은 그대로")

func test_body_tone_preserves_palette_steps_and_alpha() -> void:
	var src := Image.create(12, 2, false, Image.FORMAT_RGBA8)
	src.fill(Color(0.6, 0.4, 0.3, 0.75))
	var out: Image = src.duplicate()
	Look.sprite_tone = true
	Look.SpritePalette.shade_body(src, out, true)
	var palette := {}
	for x in 12:
		var c := out.get_pixel(x, 0)
		palette[c] = true
		assert_eq(c.a, src.get_pixel(x, 0).a, "반투명 픽셀도 알파 보존")
	assert_eq(palette.size(), 3, "연속 그라데이션 대신 세 단계")
	assert_lt(out.get_pixel(0, 0).r, src.get_pixel(0, 0).r)
	assert_gt(out.get_pixel(11, 0).r, src.get_pixel(11, 0).r)
	assert_eq(out.get_pixel(6, 0), src.get_pixel(6, 0), "중간 몸색 보존")

func test_body_tone_does_not_relight_outline_or_flame_core() -> void:
	var src := Image.create(12, 1, false, Image.FORMAT_RGBA8)
	src.fill(Color(0.6, 0.4, 0.3, 1))
	src.set_pixel(0, 0, Color.BLACK)
	src.set_pixel(11, 0, Look.FLAME_COLOR)
	var out: Image = src.duplicate()
	var edge := Color(0.3, 0.2, 0.1, 1)
	out.set_pixel(0, 0, edge)
	Look.sprite_tone = true
	Look.SpritePalette.shade_body(src, out, true)
	assert_almost_eq(out.get_pixel(0, 0).r, edge.r, 0.005, "윤곽선 중복 음영 금지")
	assert_eq(out.get_pixel(11, 0), src.get_pixel(11, 0), "불꽃 핵 보존")

func test_sprite_cache_distinguishes_tone_modes_and_bypass() -> void:
	var source := Image.create(12, 2, false, Image.FORMAT_RGBA8)
	source.fill(Color(0.6, 0.4, 0.3, 1))
	var tex := ImageTexture.create_from_image(source)
	Look.selout = true
	Look.sprite_tone = true
	var stepped := Look.selout_texture(tex)
	assert_eq(Look.selout_texture(tex), stepped, "같은 모드는 텍스처 재사용")
	Look.sprite_tone = false
	var legacy := Look.selout_texture(tex)
	assert_ne(legacy.get_image().get_data(), stepped.get_image().get_data(), "모드 변경은 다른 픽셀 결과")
	Look.sprite_tone = true
	assert_eq(Look.selout_texture(tex), stepped, "돌아오면 기존 모드 캐시 재사용")
	Look.selout = false
	assert_eq(Look.selout_texture(tex), tex, "보정 끄기는 원본 반환")
	assert_eq(tex.get_image().get_data(), source.get_data(), "원본 이미지 보존")

func test_sprite_palette_is_independent_of_look_settings() -> void:
	var source := Image.create(12, 2, false, Image.FORMAT_RGBA8)
	source.fill(Color(0.6, 0.4, 0.3, 0.75))
	var before := source.get_data()
	var first := Look.SpritePalette.process(source, true)
	Look.sprite_tone = false
	Look.selout = false
	Look.ambient_now = Color.BLACK
	var second := Look.SpritePalette.process(source, true)
	assert_eq(first.get_data(), second.get_data(), "명시적으로 전달한 설정만 사용")
	assert_eq(source.get_data(), before, "변환은 입력 이미지를 수정하지 않는다")

func test_location_profiles_preserve_midtones_and_cache_on_return() -> void:
	var source := Image.create(12, 2, false, Image.FORMAT_RGBA8)
	source.fill(Color(0.6, 0.4, 0.3, 0.75))
	source.set_pixel(11, 1, Look.FLAME_COLOR)
	var tex := ImageTexture.create_from_image(source)
	Look.selout = true
	Look.sprite_tone = true
	var day := Look.selout_texture(tex, "day")
	for profile in ["indoor", "forest"]:
		var result := Look.selout_texture(tex, profile)
		assert_ne(result.get_image().get_data(), day.get_image().get_data(), "장소별 음영 구분")
		assert_eq(result.get_image().get_pixel(6, 0), source.get_pixel(6, 0), "원본 중간색과 알파 보존")
		assert_eq(result.get_image().get_pixel(11, 1), Look.FLAME_COLOR, "불꽃 핵 보존")
		assert_eq(Look.selout_texture(tex, profile), result, "매 프레임 재가공하지 않는다")
	assert_eq(Look.selout_texture(tex, "day"), day, "야외로 돌아오면 야외 보정 복원")
	assert_eq(Look.selout_texture(tex, "unknown"), day, "미등록 장소는 기본값")
	Look.sprite_tone = false
	assert_eq(Look.selout_texture(tex, "forest"), Look.selout_texture(tex, "day"), "기존 모드는 장소 보정 없음")

func test_flame_center_stays_in_one_connected_cluster() -> void:
	var points := [Vector2(1.5, 1.5), Vector2(2.5, 1.5), Vector2(2.5, 2.5), Vector2(9.5, 9.5), Vector2(10.5, 9.5)]
	var result := Look._flame_cluster_center(points, Vector2(8, 8))
	assert_true(result in points.slice(0, 3), "배와 꼬리의 중간이 아니라 먼 연결 덩어리")
	assert_eq(Look._flame_cluster_center([], Vector2.ZERO), Vector2(-1, -1), "가려진 불꽃은 없음")
	assert_eq(Look._flame_cluster_center([Vector2(3.5, 4.5)], Vector2.ZERO), Vector2(3.5, 4.5))
