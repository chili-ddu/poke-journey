extends RefCounted
const ID="seafoam_boulders"
static var _data: Dictionary={}

static func data() -> Dictionary:
	if _data.is_empty():_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/seafoam_puzzle.json"))
	return _data

static func is_floor(place: String) -> bool:return data().floors.has(place)

static func initial() -> Dictionary:return {"boulders":data().roots.duplicate(true),"stopped":[]}

static func theme(base: Dictionary,place: String,puzzles: Dictionary) -> Dictionary:
	var state: Dictionary=puzzles.get(ID,{})
	if not is_floor(place) or not state.get("stopped",[]).has(place):return base
	return {"map":data().floors[place].calm_map,"tiles":{}}

static func vec(value: Array) -> Vector2i:return Vector2i(int(value[0]),int(value[1]))
