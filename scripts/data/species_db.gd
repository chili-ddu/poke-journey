class_name SpeciesDB
extends RefCounted

# 포켓몬 종족 사전. 원작 데이터·액션 값·공통 크기를 합친다:
#   1. 플래티넘 데이터 assets/data/species.json (tools/gen_gen4.py 가 pret/pokeplatinum 에서 생성, 전국 도감 전부) —
#      이름·도감 번호·타입·종족값·기초 경험치·경험치 곡선·진화(레벨)·자력기(레벨 순서대로)·TM·가르침 목록
#   2. 액션 게임 값 SpeciesExtras.EXTRAS — AI·적일 때 쓰는 기술·자리표시 색. 없으면 기본값.
#   3. PokemonSize — 원작 키·몸길이 기준 8단계, 화면 몸체 크기·접지 반경.
# 경험치 표는 assets/data/exp_tables.json(원작 표 그대로, 레벨 0~100 누적).

const DATA_PATH := "res://assets/data/species.json"
const EXP_PATH := "res://assets/data/exp_tables.json"

static var _raw := {}
static var _exp := {}
static var _cache := {}

static func _load() -> void:
	if not _raw.is_empty():
		return
	var f := FileAccess.open(DATA_PATH, FileAccess.READ)
	assert(f != null, "assets/data/species.json 이 없다 — tools/gen_gen4.py 를 돌릴 것")
	_raw = JSON.parse_string(f.get_as_text())
	var e := FileAccess.open(EXP_PATH, FileAccess.READ)
	_exp = JSON.parse_string(e.get_as_text()) if e != null else {}

static func has_species(id: String) -> bool:
	_load()
	return _raw.has(id)

static func all_ids() -> Array:
	_load()
	return _raw.keys()

static func get_species(id: String) -> Dictionary:
	if _cache.has(id):
		return _cache[id]
	_load()
	assert(_raw.has(id), "모르는 포켓몬 " + id)
	var s: Dictionary = (_raw[id] as Dictionary).duplicate()
	s["id"] = id
	var extra: Dictionary = SpeciesExtras.EXTRAS.get(id, {})
	for k in SpeciesExtras.DEFAULT:
		s[k] = extra.get(k, SpeciesExtras.DEFAULT[k])
	for k in extra:
		s[k] = extra[k]
	# Every registered species shares the same eight height/length tiers.
	s.merge(PokemonSize.profile(id),true)
	# 적으로 나올 때 쓰는 기술: 적어 둔 것이 없으면 Lv100 까지 아는 자력기 중 모양 있는 것. 레벨 제한은 enemy_moves 가.
	if not s.has("moves"):
		s["moves"] = []
	if s["evolve"] == null:
		s.erase("evolve")
	_cache[id] = s
	return s

# 진화 전 첫 단계(리자드·리자몽 → 파이리). 스타팅 세이브 칸을 고를 때 쓴다.
static func base_form(id: String) -> String:
	_load()
	var cur := id
	for _i in 4:
		var prev := ""
		for sid in _raw:
			var e = (_raw[sid] as Dictionary).get("evolve", null)
			var evo: Dictionary = e if e is Dictionary else {}
			if not evo.is_empty() and String(evo.get("to", "")) == cur:
				prev = String(sid)
				break
		if prev == "":
			return cur
		cur = prev
	return cur

# 원작 능력치 공식(노력치·성격 없음): ⌊(2·종족값 + 개체값)·L/100⌋ + 5, HP 는 + L + 10. ivs: {능력치: 0~31}(Individual).
static func stats_at(id: String, level: int, ivs: Dictionary = {}) -> Dictionary:
	var base: Dictionary = get_species(id)["base"]
	var out := {}
	for key in base:
		var core := int(floor((2.0 * float(base[key]) + int(ivs.get(key, 0))) * level / 100.0))
		out[key] = core + level + 10 if key == "hp" else core + 5
	return out

# 자력기 표 [[레벨, 기술], …] (원작 순서).
static func learnset(id: String) -> Array:
	return get_species(id)["learnset"]

# 지금 레벨까지 배울 수 있는 자력기(모양 있는 것만 — 아직 액션으로 안 만든 기술은 건너뛴다).
static func learnable(id: String, level: int) -> Array:
	var out: Array = []
	for pair in learnset(id):
		var mid := String(pair[1])
		if int(pair[0]) <= level and MoveDB.is_shaped(mid) and not out.has(mid):
			out.append(mid)
	return out

# 딱 그 레벨에 배우는 자력기(원작 순서, 모양 있는 것만).
static func moves_at_level(id: String, level: int) -> Array:
	var out: Array = []
	for pair in learnset(id):
		var mid := String(pair[1])
		if int(pair[0]) == level and MoveDB.is_shaped(mid) and not out.has(mid):
			out.append(mid)
	return out

# 적이 그 레벨에 쓰는 기술: SpeciesExtras 에 적은 목록이 있으면 그중 그 레벨에 아는 것, 없으면 아는 자력기 전부(모양 있는 것).
static func enemy_moves(id: String, level: int) -> Array:
	var sp := get_species(id)
	var known := learnable(id, level)
	var listed: Array = sp.get("moves", [])
	if listed.is_empty():
		return known
	var out: Array = []
	for mid in listed:
		# 자력기 표에 있는 기술은 그 레벨이 돼야 쓴다(Lv3 꼬렛은 전광석화(4) 아직). 표에 없는 기술은 진화 전 종에서 배운 것(독침붕의 독침)이라 그대로.
		var at := learn_level(id, mid)
		if at < 0 or at <= level:
			out.append(mid)
	return out

# 자력기 표에서 그 기술을 처음 배우는 레벨. 표에 없으면 -1.
static func learn_level(id: String, mid: String) -> int:
	for pair in learnset(id):
		if String(pair[1]) == mid:
			return int(pair[0])
	return -1

# 경험치 곡선: 원작 표 그대로.
static func exp_for_level(level: int, growth: String = "medium_fast") -> int:
	_load()
	var table: Array = _exp.get(growth, _exp.get("medium_fast", []))
	if table.is_empty():
		return level * level * level
	return int(table[clampi(level, 0, table.size() - 1)])

static func growth_of(id: String) -> String:
	return String(get_species(id).get("growth", "medium_fast"))
