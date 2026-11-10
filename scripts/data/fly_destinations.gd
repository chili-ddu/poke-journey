class_name FlyDestinations
extends RefCounted

const PATH := "res://assets/data/fly_destinations.json"
static var _locations: Array=[]

static func all_locations() -> Array:
	if _locations.is_empty():
		var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_locations=data.locations
	return _locations

static func visit_flag(id: String) -> String:
	return "visited_area_"+id

static func can_fly(id: String, events: Array) -> bool:
	var entry:=find(id)
	return not entry.is_empty() and bool(entry.get("enabled",false)) and events.has(visit_flag(id)) and RoadAccess.can_fly(id,events)

static func available(events: Array=[]) -> Array:
	return all_locations().filter(func(entry):return can_fly(String(entry.id),events))

static func find(id: String) -> Dictionary:
	for entry in all_locations():
		if entry.id==id:return entry
	return {}

static func label(entry: Dictionary) -> String:
	return String(entry.get("name_ko",entry.get("name","")) if Lang.is_ko() else entry.get("name",""))

static func position_of(entry: Dictionary) -> Vector2:
	var tile: Array=entry.get("tile",[-1,-1])
	return Arena.tile_center(Vector2i(int(tile[0]),int(tile[1])))
