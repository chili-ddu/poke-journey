class_name MoveDB
extends RefCounted

# 기술 사전. 두 겹을 합친다:
#   1. 플래티넘 데이터 assets/data/moves.json (tools/gen_gen4.py 가 pret/pokeplatinum 에서 생성) — 이름·타입·분류·위력·명중·PP·효과·확률·설명·TM 번호
#   2. 액션 게임 모양 MoveShapes.SHAPES — 사거리·탄·판정·연출·도트 동작·적 쿨타임. 없으면 분류별 기본 모양.
# 플래티넘 효과는 게임 안 부가 효과로 옮긴다: burn_hit → burn, poison_hit → poison, flinch → flinch, paralyze → slow(마비 대신 둔화), high_critical → crit 1/8,
# multi_hit → hits 2~5, *_damage_flat → fixed. 모양에 직접 적은 값이 있으면 그것이 우선.
#
# 플레이어 기술은 원작 PP 를 탄창처럼 쓴다(사용자 결정): PP 만큼 연달아 쓰고, 다 쓰면 재장전 시간이 지난 뒤 PP 가 다시 찬다.
#   한 발 사이 간격 = USE_DELAY[모양]. PP 는 줄어 있는 동안 REGEN_FULL_TIME ÷ 최대 PP 마다 1씩 회복한다 — 0 에서 가득까지 늘 1분
#   (사용자 결정 2026-10-28: 재장전 폐지, 최대 PP 기준). 회복 도중 기술을 쓰면 쌓이던 시간은 0 으로(Player.spend).
#   장판·회오리는 하나가 남아 있는 동안 다시 못 쓴다(World 가 막는다). 적은 "cooldown"(모양에 적은 값)을 쓴다.

const Targeting = preload("res://scripts/data/move_targeting.gd")
const DATA_PATH := "res://assets/data/moves.json"
const T := MoveShapes.T
# 근접은 Strike 동작(0.4초)이 끝나야 다음 발. 끊기지 않게 동작 길이보다 길게.
# 연발 분류는 없다(사용자 결정 2026-10-28): 여러 발로 보이는 기술(burst: 화염방사·용의분노)도 투사체와 같은 간격, 타격은 묶음당 1회.
const USE_DELAY := {"arc": 0.42, "projectile": 0.35, "cone": 0.6, "dash": 0.8, "status_cone": 0.8,
	"zone": 1.0, "ring": 1.0, "lob": 0.8, "beam": 0.8, "buff": 0.8, "heal": 1.0, "protect": 1.0, "weather": 1.0,
	"burrow": 1.2, "drain": 0.8}
# 기술 한 번의 세 단계(사용자 정의 2026-10-30): 선딜레이 = 동작 준비(cast_delay·hit_delay), 동작 = 스킬 동작(공격 도트 한 번),
# 후딜레이 = 스킬 동작이 끝난 뒤 다음 다른 스킬을 쓰기까지의 딜레이(RECOVER, Player.skill_lock_t) — 연타를 막는 값. 움직임은 막지 않고
# 자세도 붙잡지 않는다(동작은 제 길이만). 돌진은 돌진이 끝난 뒤부터, 모으는 기술은 쏜 뒤부터. 구멍파기는 솟구친 뒤 제 값(recover)만큼 서 있기도 한다.
const RECOVER := {"arc": 0.55, "projectile": 0.45, "burst": 0.55, "cone": 0.6, "dash": 0.5, "status_cone": 0.6,
	"zone": 0.6, "ring": 0.5, "lob": 0.6, "beam": 0.6, "buff": 0.45, "heal": 0.45, "protect": 0.0, "weather": 0.45, "drain": 0.6, "radial": 0.6, "spiral": 0.6}
const REGEN_FULL_TIME := 60.0   # 0 → 가득 1분: PP 35 할퀴기 1.71초, PP 25 불꽃세례 2.4초, PP 15 화염방사 4초, PP 10 용의분노 6초, PP 5 는 12초마다 1
const GEN4_CRIT_HIGH := 1.0 / 8.0

static var _raw := {}        # moves.json
static var _cache := {}      # id → 합친 사전

static func _load() -> void:
	if not _raw.is_empty():
		return
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	assert(f != null, "assets/data/moves.json 이 없다 — tools/gen_gen4.py 를 돌릴 것")
	_raw = JSON.parse_string(f.get_as_text())

static func has_move(id: String) -> bool:
	_load()
	return _raw.has(id)

static func all_ids() -> Array:
	_load()
	return _raw.keys()

# 모양이 적혀 있는(= 액션으로 쓸 수 있게 다듬은) 기술인가.
static func is_shaped(id: String) -> bool:
	return MoveShapes.SHAPES.has(id)

# 기술 설명: 영어는 플래티넘(moves.json desc), 한국어는 PokeAPI 의 한국어가 있는 가장 이른 판(assets/data/move_desc_ko.json, tools/plat_summary.py).
static var _desc_ko := {}
static func desc_of(id: String) -> String:
	if Lang.is_ko():
		if _desc_ko.is_empty():
			var d = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/move_desc_ko.json"))
			_desc_ko = d if d is Dictionary else {"_": ""}
		if _desc_ko.has(id):
			return String(_desc_ko[id])
	return String(get_move(id).get("desc", ""))

static func clear_cache() -> void:
	_cache.clear()

static func get_move(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	_load()
	assert(_raw.has(id), "모르는 기술 " + id)
	var m: Dictionary = (_raw[id] as Dictionary).duplicate()
	m["id"] = id
	var shape: Dictionary = MoveShapes.SHAPES.get(id, MoveShapes.default_shape(m))
	for k in shape:
		m[k] = shape[k]
	Targeting.configure(m)
	_melee_default(m)
	# 커스텀 연출(FxStyle): 그림 키만 바꾼다.
	if FxStyle.custom(id):
		var cfx: Dictionary = MoveShapes.CUSTOM_FX[id]
		for k in cfx:
			m[k] = cfx[k]
	# 모으기 기술: 선딜 + 원작 턴 수 × 한 턴 길이(솔라빔·로케트박치기 = 0.25 + 1.5초).
	if m.has("charge_turns"):
		m["cast_delay"] = float(m.get("cast_delay", 0.0)) + float(m["charge_turns"]) * Mon.TURN
	_apply_effect(m)
	_cache[id] = m
	return m

# 물리 근접기의 기본형 = 몸통박치기(사용자 결정 2026-11-02: '이 몸통박치기의 줌과 공격방식은 모든 물리공격의 기본형'):
# 도트의 달려드는 동작으로 앞으로 나가며(lunge) 때리는 순간까지 앞으로 미끄러지고(glide), 끝나면 그 자리에 남는다(돌아오지 않음).
# 카메라는 앞으로 나간 몸을 따라간다(Mon.cam_anchor). 처음엔 몸통박치기·할퀴기 등 몇 개만 그랬고, 모양을 따로 안 적은 물리기와
# 베어가르기·메탈클로·마구찌르기 등은 몸 중심을 발밑에 고정한 채 동작만 재생해 '치고 제자리로 돌아오는' 것처럼 보였다(사용자 지적).
# 빼는 것: 제자리에서 도는·구르는 360° 기술(고속스핀·땅고르기), 따로 step 으로 나서는 기술(불꽃엄니·전광석화 — glide 없이 step),
# 모양에 "lunge": false 를 적은 기술. glide 는 Strike(손을 뻗는 동작 11px) 13px, 그 밖(Attack 등 18px 안팎) 6px — 합쳐 약 1칸.
const MELEE_GLIDE_STRIKE := 13.0
const MELEE_GLIDE := 6.0

static func _melee_default(m: Dictionary) -> void:
	if String(m.get("shape", "")) != "arc" or String(m.get("cat", "")) != "physical" or float(m.get("arc_deg", 0.0)) >= 360.0:
		return
	if m.has("lunge") and not bool(m["lunge"]):
		return
	m["lunge"] = true
	if not m.has("glide") and not m.has("step"):
		m["glide"] = MELEE_GLIDE_STRIKE if String(m.get("anim", "Attack")) == "Strike" else MELEE_GLIDE

# 플래티넘 효과 → 게임 부가 효과. 모양에 이미 적힌 키는 건드리지 않는다.
static func _apply_effect(m: Dictionary) -> void:
	var eff := String(m.get("effect", "hit"))
	var chance := float(m.get("effect_chance", 0)) / 100.0
	# 이상해씨·꼬북이 기술(사용자 결정 2026-10-28) — 변화기의 상태는 확실히, 부가 효과는 원작 확률로.
	match eff:
		"status_sleep":
			if not m.has("sleep"): m["sleep"] = 1.0
		"status_poison":
			if not m.has("poison"): m["poison"] = 1.0
		"status_leech_seed":
			m["leech"] = true
		"bind_hit":
			if not m.has("bind"): m["bind"] = true
		"set_ability_to_insomnia":
			m["insomnia"] = true
		"confuse_hit":
			if not m.has("confuse"): m["confuse"] = chance
		"lower_speed_hit":
			if not m.has("stat_hit"):
				m["stat_hit"] = {"spe": -1}
				m["stat_hit_chance"] = chance
		"lower_sp_def_hit":
			if not m.has("stat_hit"):
				m["stat_hit"] = {"spd": -1}
				m["stat_hit_chance"] = chance
		"recoil_quarter":
			if not m.has("recoil"): m["recoil"] = 0.25
		"recoil_half":
			m["recoil"] = 0.5
		"recoil_third","recoil_burn_hit","recoil_paralyze_hit":
			if not m.has("recoil"): m["recoil"] = 1.0 / 3.0
	if eff in ["bind_hit", "status_sleep", "status_poison", "status_leech_seed", "set_ability_to_insomnia", "confuse_hit", "lower_speed_hit", "lower_sp_def_hit"]:
		return
	# Later learnsets supply these moves with a generic hit effect.
	if m.id=="wave_crash": m.recoil=1.0/3
	if m.id=="wild_charge": m.recoil=.25
	if eff.contains("burn") and not m.has("burn"):
		m["burn"] = chance
	if eff.contains("poison") and not m.has("poison"):
		m["poison"] = chance
	if eff.contains("flinch") and not m.has("flinch"):
		m["flinch"] = chance
	if eff.contains("paralyze") and not m.has("paralyze"):
		m["paralyze"] = chance if chance > 0.0 else 1.0      # paralyze_hit 30% / status_paralyze 는 확정
	if eff == "high_critical" and not m.has("crit"):
		m["crit"] = GEN4_CRIT_HIGH
	if eff.ends_with("multi_hit") and not m.has("hits"):
		m["hits"] = [2, 5]
	if eff.ends_with("_damage_flat") and not m.has("fixed"):
		m["fixed"] = int(eff.get_slice("_", 0))

# 화면에 쓰는 이름(언어 옵션 반영). 데이터의 "name" 은 영문 그대로 둔다.
static func move_name(id: String) -> String:
	return Lang.move_name(id)

static func power(id: String) -> float:
	return float(get_move(id).get("power", 0))

# 적 전용 기술의 쿨타임(모양에 적은 값).
static func cooldown(id: String) -> float:
	return float(get_move(id).get("cooldown", 0.0))

static func pp_of(id: String) -> int:
	return int(get_move(id).get("pp", 0))

static func recover_of(id: String) -> float:
	var m := get_move(id)
	return float(m.get("recover_after", RECOVER.get(String(m["shape"]), 0.3)))

static func use_delay(id: String) -> float:
	var shape := String(get_move(id)["shape"])
	if shape == "burst":
		shape = "projectile"
	return float(USE_DELAY.get(shape, 0.3))

# PP 1 이 회복되는 간격(초) = 1분 ÷ 최대 PP.
static func regen_interval(id: String) -> float:
	return REGEN_FULL_TIME / float(maxi(1, pp_of(id)))
