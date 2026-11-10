extends GutTest

# 원작 규칙을 옮긴 부분(상성·능력치·데미지)과 레벨업 선택지·조사 처리.

func test_water_is_super_effective_on_fire() -> void:
	assert_eq(TypeChart.effectiveness("water", ["fire"]), 2.0)

func test_fire_is_halved_on_water_flying() -> void:
	assert_eq(TypeChart.effectiveness("fire", ["water", "flying"]), 0.5, "물·비행은 불꽃을 반감한다")

func test_fire_on_grass_poison_is_double() -> void:
	assert_eq(TypeChart.effectiveness("fire", ["grass", "poison"]), 2.0)

func test_unlisted_pair_is_neutral() -> void:
	assert_eq(TypeChart.effectiveness("dragon", ["water", "flying"]), 1.0)

func test_bug_is_weak_to_fire_and_resists_it() -> void:
	assert_eq(TypeChart.effectiveness("fire", ["bug", "poison"]), 2.0, "뿔충이는 불꽃에 2배")
	assert_eq(TypeChart.effectiveness("bug", ["fire"]), 0.5)
	assert_eq(TypeChart.effectiveness("electric", ["fire", "flying"]), 2.0, "리자몽은 전기에 2배")

func test_forest_species_have_extras_and_shaped_moves() -> void:
	# 데이터는 전국 도감 전부지만, 실제로 나오는 종은 액션 값(SpeciesExtras)과 모양 있는 기술이 있어야 한다.
	for id in ["charmander", "charmeleon", "charizard", "caterpie", "metapod", "weedle", "kakuna", "beedrill", "pikachu"]:
		assert_true(SpeciesDB.has_species(id), id)
		assert_true(SpeciesExtras.EXTRAS.has(id), "액션 값이 없다: " + id)
		for mid in SpeciesDB.get_species(id).get("moves", []):
			assert_true(MoveDB.is_shaped(mid), "모양 없는 적 기술: " + mid)
	for mid in MoveShapes.SHAPES:
		assert_true(MoveDB.has_move(mid), "플래티넘 데이터에 없는 기술 id: " + mid)
	DungeonDB.set_current("test_meadow")
	assert_true(DungeonDB.has_encounters())
	assert_false(DungeonDB.DUNGEONS["test_meadow"].has("bosses"), "보스는 없다")
	DungeonDB.set_current(DungeonDB.DEFAULT)

func test_kanto_start_is_route1() -> void:
	# 저장된 자리 없이 바깥 세계로 갈 때(동굴탈출로프 등) 내려서는 자리: 예전처럼 1번도로(재굽기 때 --start 24,170).
	var mj: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/kanto_south/map.json"))
	var t := Vector2i(int(mj["start"][0]) / 16, int(mj["start"][1]) / 16)
	var r1: Dictionary = {}
	for a in mj["areas"]:
		if a["id"] == "route1":
			r1 = a
	assert_true(Rect2i(int(r1["x"]), int(r1["y"]), int(r1["w"]), int(r1["h"])).has_point(t), "시작 칸이 1번도로")
	assert_eq(String(mj["solid"][t.y])[t.x], "0", "막힌 칸이 아님")

func test_tall_grass_lookup_matches_map() -> void:
	# 풀숲 흔들림이 쓰는 칸 조회: 1번도로 풀숲(구역 안 10,6)은 풀숲, 바로 아래 길(10,11)은 아님.
	DungeonDB.set_current("kanto_south")
	Arena.configure(DungeonDB.theme())
	assert_true(Arena.is_grass(Arena.area_tile("route1", Vector2i(10, 6))))
	assert_false(Arena.is_grass(Arena.area_tile("route1", Vector2i(10, 11))))
	DungeonDB.set_current(DungeonDB.DEFAULT)
	Arena.configure(DungeonDB.theme())

func test_forest_uses_original_encounter_table() -> void:
	DungeonDB.set_current("viridian_forest")
	var cfg := DungeonDB.area_cfg("viridian_forest")
	assert_eq(int(cfg["encounter_rate"]), 14, "원작 상록숲 출현율")
	var total := 0
	var species := {}
	for e in cfg["encounters"]:
		total += int(e[2])
		species[e[0]] = true
	assert_eq(total, 100, "12칸 확률의 합은 100%")
	assert_true(species.has("pikachu") and species.has("metapod") and species.has("kakuna"))
	assert_false(species.has("pidgey"), "FRLG 상록숲엔 구구가 없다")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var counts := {}
	for i in 1000:
		var r := DungeonDB.roll_table(cfg["encounters"], rng)
		counts[r["species"]] = int(counts.get(r["species"], 0)) + 1
	assert_gt(int(counts["caterpie"]), int(counts["pikachu"]) * 4, "캐터피(40%)가 피카츄(5%)보다 훨씬 자주")

func test_forest_map_loads_with_trees_and_grass() -> void:
	Arena.configure(DungeonDB.THEMES["forest"])
	assert_true(Arena.has_map())
	assert_true(Arena.blocks(Vector2(8, 8), 2.0), "왼쪽 위 구석은 나무")
	assert_false(Arena.blocks(Arena.center(), 2.0), "시작 지점은 통행 가능")
	assert_gt(Arena.grass_points_near(Arena.center(), 0.0, 400.0).size(), 0, "시작 근처에 풀숲이 있다")
	# 시작 지점에서 위로 올라가다 처음 만나는 나무 칸의 아랫변 안쪽에 원을 두면 길 쪽으로 밀려난다.
	var start := Arena.center()
	var tx := int(floor(start.x / Arena.TILE))
	var ty := int(floor(start.y / Arena.TILE))
	while not Arena.solid_at(tx, ty):
		ty -= 1
	var inside := Vector2(tx * Arena.TILE + Arena.TILE / 2.0, ty * Arena.TILE + Arena.TILE - 3)
	var pushed := Arena.resolve(inside, 6.0)
	assert_false(Arena.blocks(pushed, 2.0), "나무에 겹친 원은 길 쪽으로 밀려난다")
	assert_gt(pushed.y, inside.y, "아래(길) 방향으로 밀려난다")
	Arena.configure(DungeonDB.THEMES["meadow"])

func test_move_ranges_are_in_grass_tiles() -> void:
	assert_eq(MoveDB.get_move("ember")["range"], 3 * Arena.TILE, "불꽃세례는 풀숲 3칸")
	assert_eq(MoveDB.T, float(Arena.TILE), "기술 거리 단위는 지도 한 칸")
	assert_eq(MoveDB.get_move("scratch")["range"], float(Arena.TILE), "할퀴기는 몸 옆 1칸")
	assert_eq(MoveDB.get_move("tackle")["range"], float(Arena.TILE), "몸통박치기는 바로 옆 칸(제자리 Attack 동작)")

func test_pp_magazine_reloads() -> void:
	var p := Player.new()
	p.setup_player("charmander", 5, ["scratch", "ember"])
	assert_eq(p.pp[1], 25, "불꽃세례는 PP 25 로 시작")
	for i in 25:
		p.use_t[1] = 0.0
		assert_true(p.can_use(1))
		p.spend(1)
	assert_eq(p.pp[1], 0)
	assert_false(p.can_use(1), "PP 가 바닥나면 못 쓴다")
	# PP 는 줄어 있는 동안 일정 간격마다 1씩 회복(재장전 폐지, 사용자 결정 2026-10-28).
	var step := MoveDB.regen_interval("ember")
	p.tick_cooldowns(step + 0.001)
	assert_eq(p.pp[1], 1, "한 간격마다 PP 1")
	assert_true(p.can_use(1))
	p.tick_cooldowns(step * 30.0)
	assert_eq(p.pp[1], 25, "가득에서 멈춘다")
	assert_eq(p.regen_t[1], 0.0)
	assert_almost_eq(MoveDB.regen_interval("ember"), 60.0 / 25.0, 0.001, "1분 ÷ 최대 PP")
	assert_gt(MoveDB.regen_interval("flamethrower"), MoveDB.regen_interval("scratch"), "PP 가 적은 기술일수록 느리다")
	# 사용자 예시(간격 12초 기술이라 치면): 두 번 써서 3 → 20초 기다려 4(8초 쌓임) → 쓰면 3, 쌓인 시간 리셋 → 24초 뒤 5.
	var q := Player.new()
	q.setup_player("charmander", 5, ["ember", "scratch"])
	var iv := MoveDB.regen_interval("ember")
	q.pp[0] = 3
	q.tick_cooldowns(iv * (20.0 / 12.0))
	assert_eq(q.pp[0], 4, "한 간격 지나 4")
	assert_almost_eq(q.regen_t[0], iv * (8.0 / 12.0), 0.01, "다음 1 을 향해 시간이 쌓임")
	q.use_t[0] = 0.0
	q.spend(0)
	assert_eq(q.pp[0], 3)
	assert_eq(q.regen_t[0], 0.0, "쓰면 쌓인 시간 리셋")
	q.tick_cooldowns(iv * (23.0 / 12.0))
	assert_eq(q.pp[0], 4, "리셋 뒤 23/12 간격: 아직 4")
	q.tick_cooldowns(iv * (1.01 / 12.0))
	assert_eq(q.pp[0], 5, "리셋 뒤 24/12 간격(= 두 간격)에 5")
	q.free()
	# 교체는 PP 가 가득일 때만.
	p.spend(1)
	assert_false(p.can_swap(1), "PP 가 줄어 있으면 못 뺀다")
	assert_true(p.can_swap(0))
	assert_almost_eq(MoveDB.cooldown("tackle"), 3.2, 0.001, "적 전용 기술은 적어 둔 값")
	p.free()

func test_charmander_level5_stats_match_formula() -> void:
	var s := SpeciesDB.stats_at("charmander", 5)
	assert_eq(s["hp"], 18, "⌊2·39·5/100⌋ + 5 + 10")
	assert_eq(s["atk"], 10, "⌊2·52·5/100⌋ + 5")

func test_starter_slots_reset_and_legacy_migration() -> void:
	# 스타팅마다 세이브 하나(사용자 결정 2026-10-28). 실제 세이브는 건드리지 않게 시험용 이름으로.
	var keep_pattern := SaveData.slot_pattern
	var keep_path := SaveData.path
	SaveData.slot_pattern = "user://test_slot_%s.cfg"
	SaveData.legacy_path = "user://test_legacy.cfg"
	for st in SaveData.STARTERS:
		SaveData.reset_slot(st)
	assert_eq(SaveData.STARTERS, ["bulbasaur", "charmander", "squirtle"], "도감 번호 순서")
	assert_eq(SpeciesDB.base_form("charizard"), "charmander")
	assert_eq(SpeciesDB.base_form("ivysaur"), "bulbasaur")
	assert_eq(SpeciesDB.base_form("squirtle"), "squirtle")
	# 최신 판(스칼렛·바이올렛) 습득표(사용자 결정 2026-11-02): Lv5 에 이미 첫 공격기를 안다.
	assert_eq(SpeciesDB.learnable("bulbasaur", 5), ["tackle", "growl", "vine_whip"], "이상해씨 Lv5 시작 기술")
	assert_eq(SpeciesDB.learnable("squirtle", 5), ["tackle", "tail_whip", "water_gun"], "꼬북이 Lv5 시작 기술")
	assert_eq(SpeciesDB.learnable("charmander", 5), ["scratch", "growl", "ember"], "파이리 Lv5 시작 기술")
	# 칸이 생기기 전 세이브(리자드) → 파이리 칸으로, 원본은 백업으로.
	var cf := ConfigFile.new()
	cf.set_value("mon", "species", "charmeleon")
	cf.set_value("mon", "level", 17)
	cf.save(SaveData.legacy_path)
	SaveData.migrate_legacy()
	assert_true(SaveData.slot_exists("charmander"), "옛 세이브가 파이리 칸으로")
	assert_false(FileAccess.file_exists(SaveData.legacy_path), "원본은 백업 이름으로 바뀜")
	assert_true(FileAccess.file_exists("user://test_legacy_legacy_backup.cfg"))
	assert_eq(SaveData.peek("charmander")["species"], "charmeleon")
	assert_eq(SaveData.path, keep_path, "peek 는 쓰는 경로를 바꾸지 않는다")
	# 리셋은 그 칸만 지운다.
	var p := Player.new()
	p.setup_player("bulbasaur", 6, ["tackle"])
	SaveData.use_slot("bulbasaur")
	SaveData.store(p, [])
	assert_true(SaveData.slot_exists("bulbasaur"))
	SaveData.reset_slot("charmander")
	assert_false(SaveData.slot_exists("charmander"), "파이리 칸만 리셋")
	assert_true(SaveData.slot_exists("bulbasaur"), "다른 칸은 그대로")
	for st in SaveData.STARTERS:
		SaveData.reset_slot(st)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_legacy_legacy_backup.cfg"))
	SaveData.slot_pattern = keep_pattern
	SaveData.legacy_path = SaveData.PATH
	SaveData.path = keep_path
	p.free()

func test_ivs_per_stat_enter_stat_formula() -> void:
	# 원작: ⌊(2·종족값 + 개체값)·L/100⌋ + 5. 파이리 Lv50 공격 52: IV 0 → 57, IV 31 → 72.
	assert_eq(SpeciesDB.stats_at("charmander", 50, {"atk": 0})["atk"], 57)
	assert_eq(SpeciesDB.stats_at("charmander", 50, {"atk": 31})["atk"], 72)
	assert_eq(SpeciesDB.stats_at("charmander", 50, {"atk": 31})["def"], 48, "개체값은 능력치마다 따로(방어 43 → ⌊86·50/100⌋ + 5)")

func test_method1_matches_original_lcrng() -> void:
	# 원작 LCRNG(0x41C64E6D, 0x6073) 손계산: seed 0 → 0x0000_6073 → 0xE97E_7B6A → 0x52713895 → 0x31B0DDE4 → 0x8E425287
	var ind := Individual.method1(0)
	assert_eq(int(ind["pid"]), (0xE97E << 16) | 0x0000, "PID = 위 16비트(둘째) << 16 | 아래(첫째)")
	var a := 0x5271
	var b := 0x31B0
	assert_eq(ind["ivs"], {"hp": a & 31, "atk": (a >> 5) & 31, "def": (a >> 10) & 31,
		"spe": b & 31, "spa": (b >> 5) & 31, "spd": (b >> 10) & 31})
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 200:
		var r := Individual.roll(rng)
		for k in r["ivs"]:
			assert_between(int(r["ivs"][k]), 0, 31)
		assert_between(int(r["pid"]), 0, 0xFFFFFFFF)

func test_shiny_rule_is_original_xor_below_8() -> void:
	Individual.tid = 12345
	Individual.sid = 54321
	var hi := 0xABCD
	var lo := hi ^ 12345 ^ 54321          # XOR 이 0 → 이로치
	assert_true(Individual.is_shiny((hi << 16) | lo))
	assert_true(Individual.is_shiny((hi << 16) | (lo ^ 7)), "7 까지 이로치")
	assert_false(Individual.is_shiny((hi << 16) | (lo ^ 8)), "8 부터 아님")
	# 무작위 PID 로 대략 1/8192.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var n := 0
	for i in 400000:
		if Individual.is_shiny(rng.randi()):
			n += 1
	assert_between(n, 25, 75, "400000 마리 중 약 49")
	Individual.tid = 0
	Individual.sid = 0

func test_damage_formula_reference_case() -> void:
	# 기본 = ⌊⌊⌊2·10/5+2⌋·40·20/10⌋/50⌋+2 = ⌊480/50⌋+2 = 11
	assert_eq(Damage.calc(10, 20, 10, 40.0, false, 1.0, false, 1.0), 11)
	assert_eq(Damage.calc(10, 20, 10, 40.0, true, 2.0, false, 1.0), 33, "자속 1.5 × 상성 2")

func test_damage_immune_is_zero() -> void:
	assert_eq(Damage.calc(10, 20, 10, 40.0, false, 0.0, false, 1.0), 0)

func test_damage_at_least_one() -> void:
	assert_eq(Damage.calc(1, 1, 999, 10.0, false, 0.5, false, 0.85), 1)

func test_exp_curves() -> void:
	assert_eq(SpeciesDB.exp_for_level(16), 4096, "중간빠르기 L³")
	assert_eq(SpeciesDB.exp_for_level(5, "medium_slow"), 135, "느린편 Lv5")
	assert_eq(SpeciesDB.exp_for_level(16, "medium_slow"), 2535, "느린편 Lv16 (원작 표)")
	assert_eq(SpeciesDB.growth_of("charmander"), "medium_slow")

func test_learnable_respects_level() -> void:
	var at7 := SpeciesDB.learnable("charmander", 7)
	assert_true(at7.has("ember"), "불꽃세례는 4")
	assert_false(at7.has("smoke_screen"), "연막은 8")
	assert_true(SpeciesDB.learnable("charmander", 8).has("smoke_screen"))

# 자력기 표는 그 종이 나온 가장 최신 판(사용자 결정 2026-11-02, tools/latest_learnsets.py). 파이리는 스칼렛·바이올렛.
func test_charmander_learnset_matches_latest() -> void:
	assert_eq(String(SpeciesDB.get_species("charmander")["learnset_src"]), "scarlet-violet")
	assert_eq(SpeciesDB.moves_at_level("charmander", 4), ["ember"])
	assert_eq(SpeciesDB.moves_at_level("charmander", 8), ["smoke_screen"])
	assert_eq(SpeciesDB.moves_at_level("charmander", 12), ["dragon_breath"], "용의숨결(A안으로 구현, 2026-11-02)")
	assert_eq(SpeciesDB.moves_at_level("charmander", 17), ["fire_fang"])
	assert_eq(SpeciesDB.moves_at_level("charmander", 24), ["flamethrower"])
	assert_eq(SpeciesDB.moves_at_level("charmander", 13), [], "아무것도 안 배우는 레벨")
	assert_eq(SpeciesDB.learn_level("charmander", "dragon_rage"), -1, "용의분노는 최신 표에 없다")
	assert_true(MoveDB.is_shaped("dragon_rage"), "구현은 남겨 둔다(사용자 2026-11-02)")
	assert_true(MoveDB.is_shaped("bubble"))

func test_charmeleon_learns_fire_fang_later_than_charmander() -> void:
	assert_eq(SpeciesDB.moves_at_level("charmeleon", 17), [])
	assert_eq(SpeciesDB.moves_at_level("charmeleon", 19), ["fire_fang"])
	assert_eq(String(SpeciesDB.get_species("pidgey")["learnset_src"]), "brilliant-diamond-shining-pearl", "스칼렛·바이올렛에 없는 종은 그 다음 최신 판")

func test_generated_data_is_complete() -> void:
	assert_true(SpeciesDB.all_ids().size() >= 490, "전국 도감 전부")
	assert_true(MoveDB.all_ids().size() >= 460, "기술 전부")
	assert_eq(SpeciesDB.get_species("charmander")["dex"], 4)
	assert_eq(MoveDB.get_move("flamethrower")["tm"], "TM35")
	assert_eq(MoveDB.get_move("fire_fang")["burn"], 0.1, "플래티넘 효과(flinch_burn_hit 10%) 에서 화상 확률")
	assert_eq(MoveDB.get_move("tackle")["power"], 35, "4세대 몸통박치기 위력")
	assert_eq(MoveDB.get_move("poison_sting")["poison"], 0.3, "플래티넘 poison_hit 30% → 독")
	assert_eq(int(MoveDB.get_move("ember")["count"]), 7, "불꽃세례는 불씨 일곱 개")
	assert_eq(MoveDB.get_move("ember")["shape"], "burst", "불꽃세례는 한 묶음 연속 발사")
	assert_almost_eq(float(MoveDB.get_move("ember")["cast_delay"]), 0.15, 0.001, "선딜 0.15초")
	# 연발 분류 없음: 여러 발로 보이는 기술도 투사체와 같은 연사 간격.
	assert_almost_eq(MoveDB.use_delay("flamethrower"), MoveDB.use_delay("ember"), 0.001)
	assert_almost_eq(MoveDB.use_delay("dragon_rage"), 0.35, 0.001)
	assert_eq(int(MoveDB.get_move("thunder_shock")["count"]), 1, "전기쇼크는 한 줄기")

func test_smokescreen_lowers_accuracy() -> void:
	var m := MoveDB.get_move("smoke_screen")
	assert_eq(m["shape"], "lob", "장판이 아니라 조준한 자리에 던지는 변화기(사용자 결정)")
	assert_eq(float(m["range"]), 4.0 * Arena.TILE, "사거리 4칸")
	assert_eq(m["stat"], {"acc": -1})
	assert_almost_eq(Mon.stage_acc(-1), 0.75, 0.001, "원작 명중률 −1 = 3/4")
	assert_almost_eq(Mon.stage_acc(-2), 0.6, 0.001)
	assert_almost_eq(Mon.stage_acc(0), 1.0, 0.001)
	for f in ["g4_flame", "g4_smoke", "g4_claw3", "g4_ring", "g4_claw_strike", "g4_scary_face",
			"g4_thread", "g4_needle", "g4_bolt_a", "g4_horn", "g4_hitburst", "g4_star64", "g4_bubble"]:
		assert_true(ResourceLoader.exists("res://assets/fx/%s.png" % f), "플래티넘 연출 텍스처 %s" % f)

func test_fire_fang_is_a_stepping_bite_with_platinum_fx() -> void:
	var old_mode := FxStyle.mode
	FxStyle.set_mode("original")
	var m := MoveDB.get_move("fire_fang")
	assert_eq(m["shape"], "arc", "돌진이 아니라 반 칸 나서며 무는 근접(사용자 결정)")
	assert_eq(float(m["step"]), 0.5 * Arena.TILE)
	assert_eq(m["fx"], "fang")
	var ft := MoveDB.get_move("flamethrower")
	assert_true(bool(ft["one_hit"]), "화염방사는 한 묶음 한 타")
	assert_eq(float(ft["range"]), 4.0 * Arena.TILE)
	for f in ["fang_upper", "fang_lower", "fire_fang_puff", "fire_fang_flame"]:
		assert_true(ResourceLoader.exists("res://assets/fx/%s.png" % f), "플래티넘 fire_fang.spa 텍스처 %s" % f)

	FxStyle.set_mode(old_mode)

func test_korean_names_and_josa() -> void:
	Lang.set_code("ko", false)
	assert_eq(Lang.species_name("charmander"), "파이리")
	assert_eq(Lang.move_name("fire_fang"), "불꽃엄니")
	assert_eq(Lang.type_name("fire"), "불꽃")
	assert_eq(Lang.josa("파이리{은/는} 리자몽{이/가} 불꽃엄니{을/를}"), "파이리는 리자몽이 불꽃엄니를")
	assert_eq(Lang.josa("레벨31{으로/로} 레벨6{으로/로} 레벨10{으로/로} 레벨2{으로/로}"), "레벨31로 레벨6으로 레벨10으로 레벨2로", "숫자 읽은 소리의 받침")
	assert_eq(Lang.t("grew", ["파이리", 6]), "파이리는\n레벨 6으로 올랐다!")
	Lang.set_code("en", false)
	assert_eq(Lang.t("grew", ["CHARMANDER", 6]), "CHARMANDER grew to Lv. 6!")
	assert_eq(MoveDB.move_name("fire_fang"), "FIRE FANG")

func test_overworld_and_save_roundtrip() -> void:
	assert_true(DungeonDB.is_indoor("oaks_lab"))
	assert_true(DungeonDB.is_overworld("kanto_south"))
	assert_true(DungeonDB.is_overworld("viridian_forest"), "상록숲은 던전이 아니라 바깥 세계(사용자 결정)")
	assert_true(DungeonDB.is_overworld("viridian_forest"))
	assert_true(FileAccess.file_exists("res://assets/maps/kanto_south/map.json"), "태초마을·1번도로·상록시티 한 장")
	Arena.configure(DungeonDB.THEMES["kanto_south"])
	assert_eq(Arena.warp_tile("pallet_town", 2), Arena.area_tile("pallet_town", Vector2i(16, 13)), "태초마을 2번 문 = 오박사 연구소 문")
	# 아래층 그림은 사방 pad 칸 더 크다(원작 테두리로 채운 여백 — 화면이 지도보다 넓어도 검게 안 빈다).
	var mj: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/kanto_south/map.json"))
	var pad := int(mj["pad"])
	assert_true(pad >= 6, "여백이 시야 반폭보다 넉넉")
	var img := Image.load_from_file(ProjectSettings.globalize_path("res://assets/maps/kanto_south/bottom.png"))
	assert_eq(img.get_size(), Vector2i((int(mj["width"]) + 2 * pad) * 16, (int(mj["height"]) + 2 * pad) * 16))
	# 1번도로 옆 빈 칸(어느 원작 지도에도 안 속함)도 채워져 있다.
	var r1t := Arena.area_tile("route1", Vector2i(-10, 20))      # 1번도로 왼쪽 바깥(어느 원작 지도에도 안 속함)
	assert_eq(img.get_pixel((r1t.x + pad) * 16 + 8, (r1t.y + pad) * 16 + 8).a, 1.0)
	assert_eq(Arena.area_at(Arena.tile_center(Arena.area_tile("route1", Vector2i(8, 10)))), "route1")
	assert_eq(Arena.area_at(Arena.tile_center(Arena.area_tile("pallet_town", Vector2i(8, 10)))), "pallet_town")
	assert_eq(String(Arena.warp_at(Arena.tile_center(Arena.area_tile("pallet_town", Vector2i(16, 13))))["to"]), "pallet_town_professor_oaks_lab")
	Arena.configure(DungeonDB.THEMES["oaks_lab"])
	assert_eq(Arena.warp_tile("pallet_town_professor_oaks_lab", 0), Vector2i(6, 12))

func test_items_barter_and_held_drops() -> void:
	assert_eq(ItemDB.price("potion"), 300, "원작 가격")
	assert_eq(ItemDB.price("oran_berry"), 20)
	assert_false(ItemDB.shop_items().has("poke_ball"), "몬스터볼은 안 판다(사용자 결정)")
	assert_true(ItemDB.shop_items().has("full_restore"))
	assert_true(ItemDB.icon("potion") != null, "플래티넘 아이콘")
	assert_true(ItemDB.is_trade_good("light_ball") and not ItemDB.is_trade_good("potion"), "교환품은 지닌 물건만")
	# 교환: 넘치는 값이 가장 적은 묶음, 거스름 없음.
	assert_eq(ItemDB.payment({"oran_berry": 5}, 100), {"oran_berry": 5}, "해독제 ₽100 = 오랭열매 5개")
	assert_eq(ItemDB.payment({"oran_berry": 5, "light_ball": 1}, 100), {"light_ball": 1}, "같은 값이면 개수가 적은 쪽")
	assert_eq(ItemDB.payment({"oran_berry": 2, "poison_barb": 2}, 240), {"oran_berry": 2, "poison_barb": 2})
	assert_eq(ItemDB.payment({"oran_berry": 4}, 100), {}, "모자라면 못 바꾼다")
	assert_eq(ItemDB.payment({"potion": 3}, 100), {}, "상점 물건은 교환품이 아니다")
	assert_eq(ItemDB.trade_value({"oran_berry": 2, "light_ball": 1, "potion": 9}), 140)
	# 원작 지닌 물건: 피카츄 오랭 50%·전기구슬 5%, 캐터피는 없음, 꼬렛은 우린 5%.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var got := {}
	for i in 4000:
		var it := ItemDB.roll_held("pikachu", rng)
		got[it] = int(got.get(it, 0)) + 1
	assert_almost_eq(float(got.get("oran_berry", 0)) / 4000.0, 0.5, 0.03)
	assert_almost_eq(float(got.get("light_ball", 0)) / 4000.0, 0.05, 0.015)
	assert_eq(ItemDB.roll_held("caterpie", rng), "")
	# 가방 한도: 거래용 열매는 9999, 다른 도구는 99.
	var p := Player.new()
	p.setup_player("charmander", 5, ["scratch"])
	assert_eq(p.add_item("oran_berry", 9), 9)
	assert_eq(p.berries, 9)
	assert_eq(p.add_item("oran_berry", 10000), 9990)
	assert_eq(p.berries, 9999)
	assert_eq(ItemDB.cap("leppa_berry"), 9999)
	assert_eq(ItemDB.cap("lum_berry"), 9999)
	assert_eq(ItemDB.cap("potion"), 99)
	assert_eq(ItemDB.payment({"oran_berry": 9999}, 100), {"oran_berry": 5})
	assert_eq(ItemDB.payment({"oran_berry": 9999, "light_ball": 1}, 100), {"light_ball": 1})
	assert_eq(p.add_item("oran_berry"), 0)
	assert_eq(p.add_item("potion", 3), 3)
	assert_true(p.take_item("potion", 3))
	assert_false(p.bag.has("potion"), "다 쓰면 칸이 빈다")
	p.free()

func test_wild_chance_follows_frlg_steps() -> void:
	# 1번도로 출현율 21: 직후 막기 6걸음, 그 뒤 걸음당 21%, 살아 있는 마리 수 + 1 로 나눔(사용자 결정).
	assert_almost_eq(DungeonDB.wild_chance(21.0, 10.0, 0.0, 0), 0.21, 0.0001)
	assert_almost_eq(DungeonDB.wild_chance(21.0, 10.0, 0.0, 1), 0.21 / 2.0, 0.0001, "한 마리가 있으면 p ÷ 2")
	assert_almost_eq(DungeonDB.wild_chance(21.0, 10.0, 0.0, 2), 0.21 / 3.0, 0.00001, "두 마리면 p ÷ 3")
	var st := DungeonDB.WILD_STEP
	assert_almost_eq(st, 0.5, 0.0001, "한 걸음 = 0.5초(사용자 결정)")
	assert_almost_eq(DungeonDB.wild_chance(21.0, 5.9 * st, 0.0, 0), 0.21 * 0.05, 0.0001, "6걸음 전엔 5%만")
	assert_almost_eq(DungeonDB.wild_chance(21.0, 6.0 * st, 0.0, 0), 0.21, 0.0001)
	assert_almost_eq(DungeonDB.wild_chance(21.0, 10.0, 200.0, 0), 0.22, 0.0001, "허탕 보정 = 보정/20000")
	assert_almost_eq(DungeonDB.wild_chance(7.0, 7.9 * st, 0.0, 0), 0.07 * 0.05, 0.0001, "동굴(7)은 8걸음 막기")

func test_ledges_block_walking_but_not_hops() -> void:
	Arena.configure(DungeonDB.THEMES["kanto_south"])
	# 1번도로의 남향 언덕 칸 하나를 찾는다.
	var found := Vector2i(-1, -1)
	var r1 := Arena.area_rect("route1")
	for ty in range(r1.position.y, r1.end.y):
		for tx in range(r1.position.x, r1.end.x):
			if Arena.ledge_at(tx, ty) == Arena.LEDGE_CODES["s"] and not Arena.solid_at(tx, ty - 1) and Arena.ledge_at(tx, ty - 1) == 0 and not Arena.solid_at(tx, ty + 1) and Arena.ledge_at(tx, ty + 1) == 0:
				found = Vector2i(tx, ty)
				break
		if found.x >= 0:
			break
	assert_true(found.x >= 0, "1번도로에 남향 언덕이 있다")
	var r := 9.0
	var above := Arena.tile_center(found + Vector2i.UP)
	# 걸어서 언덕 칸으로 들어가면 밀려난다. 점프 중이면 지나간다.
	var into := above + Vector2(0, Arena.TILE * 0.75)
	assert_true(Arena.resolve(into, r).y < above.y + Arena.TILE * 0.5, "걸어서는 막힘")
	assert_eq(Arena.resolve(into, r, true), into, "점프 중엔 통과")
	# 위에서 아래로 걸으면 자동 점프 방향이 남쪽, 아래에서 위로 걸으면 없음(점프 키로만).
	assert_eq(Arena.ledge_drop_ahead(above + Vector2(0, 4), r, Vector2.DOWN), Vector2.DOWN)
	var below := Arena.tile_center(found + Vector2i.DOWN)
	assert_eq(Arena.ledge_drop_ahead(below - Vector2(0, 4), r, Vector2.UP), Vector2.ZERO)
	assert_eq(SpeciesDB.enemy_moves("rattata", 3), ["tackle", "tail_whip"], "꼬렛 Lv3: 전광석화(4)는 아직")
	assert_eq(SpeciesDB.enemy_moves("pidgey", 5), ["tackle", "sand_attack"])
	SaveData.path = "user://save_test.cfg"   # 실제 저장(save.cfg)은 건드리지 않는다
	var p := Player.new()
	var ind := Individual.method1(99)
	p.setup_player("charmander", 9, ["scratch", "growl", "ember"], ind)
	p.exp_total += 7
	p.berries = 3
	SaveData.store(p, ["viridian_forest"], "kanto_south", Vector2(300, 400))
	var s := SaveData.load_saved()
	assert_eq(s["map"], "kanto_south")
	assert_eq(s["pos"], Vector2(300, 400))
	assert_eq(s["species"], "charmander")
	assert_eq(s["level"], 9)
	assert_eq(s["exp"], p.exp_total)
	assert_eq(s["slots"], ["scratch", "growl", "ember", ""], "끼운 네 칸(Q·W·E·R, 빈 칸은 \"\")")
	assert_eq(s["hotbar"], ["oran_berry", "", "", ""], "도구 편성도 저장")
	assert_eq(s["learned"], ["scratch", "growl", "ember"], "배운 기술 목록도 저장")
	assert_eq(s["cleared"], ["viridian_forest"])
	assert_eq(s["bag"], {"oran_berry": 3}, "가방도 저장")
	assert_eq(s["pid"], int(ind["pid"]), "PID 저장")
	assert_eq(s["ivs"], ind["ivs"], "개체값 저장")
	assert_eq(p.stats, SpeciesDB.stats_at("charmander", 9, ind["ivs"]), "능력치에 개체값 반영")
	SaveData.store_respawn("viridian_center", Vector2(180, 108))
	s = SaveData.load_saved()
	assert_eq(s["respawn_map"], "viridian_center", "부활 자리(마지막으로 회복한 센터)")
	assert_eq(s["respawn_pos"], Vector2(180, 108))
	SaveData.clear()
	assert_false(SaveData.exists())
	SaveData.path = SaveData.PATH
	p.free()

func test_player_four_slots_and_learned_pool() -> void:
	var p := Player.new()
	p.setup_player("charmander", 5, ["scratch", "growl", "ember", "smoke_screen"])
	assert_eq(Player.SLOT_COUNT, 4, "기술은 네 칸 Q·W·E·R(사용자 결정 2026-11-02)")
	assert_eq(p.slots, ["scratch", "growl", "ember", "smoke_screen"])
	assert_eq(p.first_empty_slot(), -1)
	assert_true(p.add_learned("dragon_rage"), "새 기술은 배운 목록에")
	assert_false(p.add_learned("dragon_rage"))
	assert_eq(p.slots, ["scratch", "growl", "ember", "smoke_screen"], "칸이 차 있으면 목록에만")
	assert_eq(p.spare_moves(), ["dragon_rage"])
	p.equip(1, "dragon_rage")
	assert_eq(p.slots, ["scratch", "dragon_rage", "ember", "smoke_screen"])
	assert_eq(p.spare_moves(), ["growl"], "뺀 기술은 목록으로")
	assert_eq(p.pp[1], MoveDB.pp_of("dragon_rage"), "새로 끼운 기술은 PP 가득")
	p.equip(0, "ember")
	assert_eq(p.slots, ["ember", "dragon_rage", "scratch", "smoke_screen"], "다른 칸에 있으면 맞바꿈")
	assert_eq(p.known_moves(), ["scratch", "growl", "ember", "smoke_screen", "dragon_rage"])
	assert_eq(p.hotbar[0], "oran_berry", "도구 편성 1번은 처음에 오랭열매")
	p.free()

func test_player_gain_exp_counts_levels() -> void:
	var p := Player.new()
	p.setup_player("charmander", 5, ["scratch"])
	assert_eq(p.gain_exp(179 - 135), 1, "느린편 Lv.6 경계(179)까지 정확히 채우면 1레벨")
	p.free()

func test_move_speed_grows_with_speed_stat() -> void:
	var p := Player.new()
	p.setup_player("charmander", 5, ["scratch"])
	var slow := p.move_speed()
	p.set_level(15)
	assert_gt(p.move_speed(), slow, "레벨이 올라 스피드가 오르면 더 빨리 달린다")
	# 높은 스피드에서도 차이를 유지하고 계속 빨라진다.
	p.stats["spe"] = 100
	var fast := p.move_speed()
	p.stats["spe"] = 200
	assert_gt(p.move_speed(), fast, "높은 스피드에서도 상한 없이 계속 빨라진다")
	p.free()

func test_speed_curve_covers_full_species_range_without_capping() -> void:
	var p := Player.new()
	p.setup_player("charmander", 5, ["scratch"])
	p.stats["spe"] = 12
	assert_almost_eq(p.move_speed(),58.4,0.001,"저레벨 이동감 유지")
	p.stats["spe"] = 28
	var join := p.move_speed()
	assert_almost_eq(join,77.6,0.001)
	p.stats["spe"] = 29
	assert_between(p.move_speed()-join,1.1,1.2,"분기점에서 속도가 튀지 않는다")
	var maximum := 0
	for id in SpeciesDB.all_ids():
		maximum=maxi(maximum,int(SpeciesDB.stats_at(id,100,{"spe":31})["spe"]))
	p.stats["spe"] = maximum
	var fastest := p.move_speed()
	assert_between(fastest / Arena.TILE,5.0,5.5,"수록 데이터 최대 능력치로 이동 범위 확인")
	p.stats["spe"] = maximum+100
	assert_gt(p.move_speed(),fastest,"현재 데이터 최대보다 높은 능력치도 제한하지 않는다")
	p.stats["spe"] = maximum
	p.spe_stage=6
	assert_almost_eq(p.move_speed(),fastest*4.0,0.001,"전투 랭크는 기존 배율 유지")
	p.free()

func test_harden_stage_multiplier() -> void:
	assert_almost_eq(Mon.stage_mult(1), 1.5, 0.001)
	assert_almost_eq(Mon.stage_mult(6), 4.0, 0.001)
	assert_almost_eq(Mon.stage_mult(-1), 2.0 / 3.0, 0.001)
	assert_eq(SpeciesDB.get_species("metapod")["moves"], ["harden"])

func test_player_evolves_at_16() -> void:
	var p := Player.new()
	p.setup_player("charmander", 15, ["scratch"])
	assert_eq(p.evolution_target(), "")
	p.set_level(16)
	assert_eq(p.evolution_target(), "charmeleon")
	p.free()

func test_pmd_direction_rows() -> void:
	assert_eq(MonSprite.dir_row(Vector2.DOWN), 0)
	assert_eq(MonSprite.dir_row(Vector2(1, 1)), 1)
	assert_eq(MonSprite.dir_row(Vector2.RIGHT), 2)
	assert_eq(MonSprite.dir_row(Vector2.UP), 4)
	assert_eq(MonSprite.dir_row(Vector2.LEFT), 6)
