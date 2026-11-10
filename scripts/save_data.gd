class_name SaveData
extends RefCounted

# 던전 사이에 들고 다니는 성장(사용자 결정 2026-10-28: 유지 + 저장). user://save.cfg 한 파일.
#   [trainer]  tid, sid — 트레이너 ID·비밀 ID(새 게임 때 한 번 정함, Individual). 이로치 판정에 쓴다
#   [mon]      species, level, exp, slots(끼운 기술 4칸 Q·W·E·R, 빈 칸은 ""; 예전 저장은 2칸), hotbar(도구 편성 1~4), learned(지금까지 배운 기술), pid, ivs(개체 정보 — 원작처럼 한 번 정하면 그대로)
#   [progress] cleared(클리어한 던전 id 목록), trainers(이긴 트레이너 id 목록), events(한 번뿐인 이벤트 id). 예전 저장의 badges 는 읽지 않는다(배지 없음, 2026-10-30)
#   [bag]      items({도구 id: 개수}; 예전 저장의 berries 도 읽는다)
#   [respawn]  map, x, y — 쓰러지면 다시 시작할 자리(마지막으로 들른 포켓몬센터). 없으면 오박사 연구소
#   [where]    map(장소 id), x, y(월드 px) — 바깥 세계·건물 안에서 마지막으로 있던 자리
# 던전을 클리어하거나 마을에서 날아갈 때 저장한다. 쓰러지면 저장하지 않으므로 마지막 저장(그 던전에 들어가기 전)으로 돌아간다.
# 봇·도구(BOT=1)는 읽지도 쓰지도 않는다.

const PATH := "user://save.cfg"
static var path := PATH          # 테스트는 다른 파일로 바꿔 쓴다(실제 저장을 건드리지 않게)

# 스타팅별 복수 기록. 기록 1은 기존 파일 경로를 유지하고 이후 기록만 _2, _3 등을 붙인다.
# 도감 번호 순서: 이상해씨 · 파이리 · 꼬북이. 진화해도 같은 칸(첫 단계 이름으로 파일).
const RECORD_LIMIT := 5
const STARTERS := ["bulbasaur", "charmander", "squirtle"]
static var slot_pattern := "user://save_%s.cfg"   # 시험·캡처 도구는 다른 이름으로 바꿔 실제 세이브를 건드리지 않는다
static var allow_migrate := true
static var legacy_path := PATH                    # 칸이 생기기 전 세이브(테스트는 다른 파일로)
const LEGACY_BACKUP := "user://save_legacy_backup.cfg"

static func slot_path(starter: String, record: int = 1) -> String:
	var base := slot_pattern % starter
	return base if record<=1 else base.get_basename()+"_%d."%record+base.get_extension()

static func use_slot(starter: String, record: int = 1) -> bool:
	if record<1 or record>RECORD_LIMIT:return false
	path=slot_path(starter,record)
	return true

static func slot_exists(starter: String, record: int = 1) -> bool:
	return FileAccess.file_exists(slot_path(starter,record))

# Include unreadable files too: new records must never overwrite an existing file.
static func record_ids(starter: String) -> Array[int]:
	var ids: Array[int] = []
	var base := slot_path(starter)
	if FileAccess.file_exists(base):ids.append(1)
	var prefix := base.get_file().get_basename()+"_"
	var ending := "."+base.get_extension()
	for file in DirAccess.get_files_at(base.get_base_dir()):
		if not file.begins_with(prefix) or not file.ends_with(ending):continue
		var suffix := file.trim_prefix(prefix).trim_suffix(ending)
		if suffix.is_valid_int():
			var id := int(suffix)
			if id>1 and str(id)==suffix:ids.append(id)
	ids.sort()
	return ids

static func next_record_id(starter: String) -> int:
	for id in range(1,RECORD_LIMIT+1):
		if not slot_exists(starter,id):return id
	return 0  # All five slots are occupied; never allocate or overwrite a sixth.

# Read a summary without switching the active game save.
static func peek(starter: String, record: int = 1) -> Dictionary:
	var keep := path
	path=slot_path(starter,record)
	var d := load_saved()
	path=keep
	return d

# Delete only the chosen record; the title asks for confirmation first.
static func reset_slot(starter: String, record: int = 1) -> void:
	var p := slot_path(starter,record)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

# 칸이 생기기 전의 세이브(user://save.cfg, 파이리 하나뿐이던 시절)를 그 포켓몬의 칸으로 옮긴다.
# 칸이 이미 있으면 덮어쓰지 않는다. 원본은 지우지 않고 save_legacy_backup.cfg 로 이름만 바꿔 둔다.
static func migrate_legacy() -> void:
	if not allow_migrate or not FileAccess.file_exists(legacy_path):
		return
	var cf := ConfigFile.new()
	if cf.load(legacy_path) != OK:
		return
	var sp := String(cf.get_value("mon", "species", ""))
	if sp == "" or not SpeciesDB.has_species(sp):
		return
	var starter := SpeciesDB.base_form(sp)
	if not STARTERS.has(starter):
		return
	if not slot_exists(starter):
		cf.save(slot_path(starter))
	var bak := legacy_path.get_basename() + "_legacy_backup.cfg" if legacy_path != PATH else LEGACY_BACKUP
	var abs_old := ProjectSettings.globalize_path(legacy_path)
	var abs_bak := ProjectSettings.globalize_path(bak)
	if FileAccess.file_exists(bak):
		DirAccess.remove_absolute(abs_bak)
	DirAccess.rename_absolute(abs_old, abs_bak)

static func exists() -> bool:
	return FileAccess.file_exists(path)

# 없으면 빈 사전.
static func load_saved() -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return {}
	var slots: Array = cf.get_value("mon", "slots", [])   # 예전 저장은 2칸 — Game 이 빈 칸을 배운 기술로 채운다
	return {"species": String(cf.get_value("mon", "species", "")), "level": int(cf.get_value("mon", "level", 0)),
		"evolution_declined_level": int(cf.get_value("mon", "evolution_declined_level", 0)),
		"exp": int(cf.get_value("mon", "exp", 0)), "slots": slots,
		"learned": Array(cf.get_value("mon", "learned", [])),
		"pid": int(cf.get_value("mon", "pid", -1)), "ivs": _ivs_of(cf),
		"cleared": Array(cf.get_value("progress", "cleared", [])),
		"trainers": Array(cf.get_value("progress", "trainers", [])),
		"events": Array(cf.get_value("progress", "events", [])), "hold": String(cf.get_value("mon", "hold", "")),
		"field_puzzles":cf.get_value("progress","field_puzzles",{}),
		"status": String(cf.get_value("mon", "status", "")),       # 고칠 때까지 남는 상태이상(마비·독·화상) — 원작처럼 저장에도 남는다
		"hotbar": Array(cf.get_value("mon", "hotbar", [])),         # 도구 편성 1~4(없던 예전 저장은 1번에 오랭열매)
		"pp_focus_slot":int(cf.get_value("mon","pp_focus_slot",0)), "bag": _bag_of(cf), "reward_reserve": cf.get_value("bag","reward_reserve",{}),
		"respawn_map": String(cf.get_value("respawn", "map", "")),
		"respawn_pos": Vector2(float(cf.get_value("respawn", "x", -1.0)), float(cf.get_value("respawn", "y", -1.0))),
		"map": String(cf.get_value("where", "map", "")), "layout": int(cf.get_value("where", "layout", 1)), "pos": Vector2(float(cf.get_value("where", "x", -1.0)), float(cf.get_value("where", "y", -1.0)))}

static func store(p: Player, cleared: Array, map_id: String = "", pos: Vector2 = Vector2(-1, -1)) -> void:
	var cf := ConfigFile.new()
	cf.load(path)
	if map_id != "":
		cf.set_value("where", "map", map_id)
		cf.set_value("where", "layout", int(DungeonDB.LAYOUTS.get(map_id, 1)))
		cf.set_value("where", "x", pos.x)
		cf.set_value("where", "y", pos.y)
	cf.set_value("trainer", "tid", Individual.tid)
	cf.set_value("trainer", "sid", Individual.sid)
	cf.set_value("mon", "species", p.species_id)
	cf.set_value("mon", "level", p.level)
	cf.set_value("mon", "exp", p.exp_total)
	cf.set_value("mon", "evolution_declined_level", p.evolution_declined_level)
	cf.set_value("mon", "slots", p.slots.duplicate())
	cf.set_value("mon", "learned", p.learned.duplicate())
	cf.set_value("mon", "pid", p.pid)
	cf.set_value("mon", "ivs", p.ivs.duplicate())
	cf.set_value("mon", "hold", p.hold)
	cf.set_value("mon", "status", p.status_name())
	cf.set_value("mon", "hotbar", p.hotbar.duplicate())
	cf.set_value("mon", "pp_focus_slot", p.pp_focus_slot)
	cf.set_value("progress", "cleared", cleared.duplicate())
	cf.set_value("bag", "items", p.bag.duplicate())
	cf.set_value("bag", "reward_reserve", p.reward_reserve.duplicate())
	if cf.has_section_key("bag", "berries"):
		cf.erase_section_key("bag", "berries")
	cf.save(path)

static func _ivs_of(cf: ConfigFile) -> Dictionary:
	var v = cf.get_value("mon", "ivs", {})
	return v.duplicate() if v is Dictionary else {}

# 트레이너 ID·비밀 ID [tid, sid]. 저장에 없으면(새 게임·예전 저장) 새로 정한다 — 파일엔 다음 store 때 적힌다(Individual.tid·sid).
static func trainer(rng: RandomNumberGenerator) -> Array:
	var cf := ConfigFile.new()
	if cf.load(path) == OK and cf.has_section_key("trainer", "tid") and cf.has_section_key("trainer", "sid"):
		return [int(cf.get_value("trainer", "tid")), int(cf.get_value("trainer", "sid"))]
	return Individual.new_trainer(rng)

static func _bag_of(cf: ConfigFile) -> Dictionary:
	var items = cf.get_value("bag", "items", {})
	var out: Dictionary = items.duplicate() if items is Dictionary else {}
	var old := int(cf.get_value("bag", "berries", 0))
	if old > 0 and not out.has("oran_berry"):
		out["oran_berry"] = old
	return out

# 이긴 트레이너·받은 배지를 [progress] 목록에 더한다(이미 있으면 그대로).
static func store_puzzle(id: String,state: Dictionary) -> void:
	var cf:=ConfigFile.new();cf.load(path)
	var puzzles: Dictionary=cf.get_value("progress","field_puzzles",{})
	puzzles[id]=state.duplicate(true);cf.set_value("progress","field_puzzles",puzzles);cf.save(path)

static func store_progress(key: String, id: String) -> void:
	var cf := ConfigFile.new()
	cf.load(path)
	var list: Array = Array(cf.get_value("progress", key, []))
	if not list.has(id):
		list.append(id)
	cf.set_value("progress", key, list)
	cf.save(path)

# 포켓몬센터에서 회복하면 그 자리를 부활 자리로.
static func store_respawn(map_id: String, pos: Vector2) -> void:
	var cf := ConfigFile.new()
	cf.load(path)
	cf.set_value("respawn", "map", map_id)
	cf.set_value("respawn", "x", pos.x)
	cf.set_value("respawn", "y", pos.y)
	cf.save(path)

static func clear() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

# Narrative payload is deliberately separate from mon/progress. Old saves load
# an empty dictionary, and unrelated save slots never share a father's record.
static func load_campaign() -> Dictionary:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:return {}
	var value: Variant = cf.get_value("campaign","state",{})
	return value.duplicate(true) if value is Dictionary else {}

static func store_campaign(state: Dictionary) -> void:
	var cf := ConfigFile.new()
	cf.load(path)
	cf.set_value("campaign","state",state.duplicate(true))
	cf.save(path)

# Commit a new generation atomically before changing scene. The father's state
# remains in [campaign]; only the active Pokémon and its current journey reset.
static func store_cycle(child: Dictionary, map_id: String) -> void:
	var cf := ConfigFile.new()
	cf.load(path)
	for key in ["species","level","exp","evolution_declined_level","slots","learned","pid","ivs","hold","status","hotbar","pp_focus_slot"]:
		if child.has(key):cf.set_value("mon",key,child[key])
	cf.set_value("progress","cleared",child.get("cleared",[]))
	cf.set_value("progress","trainers",child.get("trainers",[]))
	cf.set_value("progress","events",child.get("events",[]))
	cf.set_value("progress","field_puzzles",child.get("field_puzzles",{}))
	cf.set_value("bag","items",child.get("bag",{}))
	cf.set_value("bag","reward_reserve",{})
	if cf.has_section_key("bag","berries"):cf.erase_section_key("bag","berries")
	cf.set_value("where","map",map_id)
	cf.set_value("where","layout",1)
	cf.set_value("where","x",-1.0)
	cf.set_value("where","y",-1.0)
	cf.set_value("respawn","map",map_id)
	cf.set_value("respawn","x",-1.0)
	cf.set_value("respawn","y",-1.0)
	cf.save(path)
