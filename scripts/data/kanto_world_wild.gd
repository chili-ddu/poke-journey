class_name KantoWorldWild
extends RefCounted

const PATH="res://assets/data/kanto_world_wild.json"
static var _data: Dictionary={}

static func data() -> Dictionary:
	if _data.is_empty():
		_data=JSON.parse_string(FileAccess.get_file_as_string(PATH))
		# Godot's JSON reader makes every number a float. Encounter consumers
		# share the integer slot format used by the existing GDScript tables.
		for cfg in _data.tables.values():
			for key in ["encounters","water_encounters","rock_smash_encounters"]:
				_integer_slots(cfg.get(key,[]))
			for slots in cfg.fishing.values():_integer_slots(slots)
			for key in cfg:
				if String(key).ends_with("encounter_rate"):cfg[key]=int(cfg[key])
		for record in _data.species.values():
			for key in ["dex","min_level","max_level"]:record[key]=int(record[key])
	return _data

static func _integer_slots(slots: Array) -> void:
	for row in slots:
		for i in range(1,row.size()):row[i]=int(row[i])

static func area(id: String) -> Dictionary:
	return data().tables.get(id,{})
