class_name AbilityDB
extends RefCounted

# 특성(상태창 표시용 — 게임 규칙엔 아직 안 쓴다). assets/data/abilities.json(tools/plat_summary.py):
#   species: {종: [특성 id…]}(플래티넘 res/pokemon/<종>/data.json), abilities: {id: {name, name_ko, desc, desc_ko}}(PokeAPI CSV).

const DATA := "res://assets/data/abilities.json"
static var _data := {}

static func _load() -> void:
	if _data.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
		_data = d if d is Dictionary else {"species": {}, "abilities": {}}

# 그 종의 첫 특성(원작 개체는 둘 중 하나 — 이 게임은 첫 것). 없으면 "".
static func of_species(sid: String) -> String:
	_load()
	var list: Array = _data["species"].get(sid, [])
	return String(list[0]) if not list.is_empty() else ""

static func name_of(id: String) -> String:
	_load()
	var a: Dictionary = _data["abilities"].get(id, {})
	if Lang.is_ko() and String(a.get("name_ko", "")) != "":
		return String(a["name_ko"])
	return String(a.get("name", id))

static func desc_of(id: String) -> String:
	_load()
	var a: Dictionary = _data["abilities"].get(id, {})
	if Lang.is_ko() and String(a.get("desc_ko", "")) != "":
		return String(a["desc_ko"])
	return String(a.get("desc", ""))
