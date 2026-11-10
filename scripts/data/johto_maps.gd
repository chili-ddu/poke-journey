extends RefCounted

## Map-only HGSS region registered in the ordinary Game lifecycle.
const Collection = preload("res://scripts/johto/hgss_map_collection.gd")
const GAME_BASE = "res://assets/maps/johto_border_hgss/"
const LEGACY_GATE = "route22_north_entrance"
static var _collection: Collection

static func collection() -> Collection:
	if _collection == null: _collection = Collection.new(GAME_BASE)
	return _collection

static func id(header: int) -> String:
	return "johto_%03d" % header

static func header(place: String) -> int:
	return int(place.trim_prefix("johto_")) if place.begins_with("johto_") else 0

static func has(place: String) -> bool:
	return collection().manifest.headers.has(str(header(place))) if place.begins_with("johto_") else false

static func metadata(place: String) -> Dictionary:
	return collection().manifest.headers.get(str(header(place)), {})

static func themes() -> Dictionary:
	var result := {}
	for key in collection().manifest.headers:
		var h := int(key)
		result[id(h)] = {"native_map":GAME_BASE,"hgss_scene":collection().scene_for(h),"hgss_header":h}
	return result

static func places() -> Dictionary:
	var result := {}
	for key in collection().manifest.headers:
		var h := int(key)
		var meta: Dictionary = collection().manifest.headers[key]
		var indoor: bool = meta.mapType == "MAP_TYPE_INTERIOR"
		result[id(h)] = {"name":String(meta.constant).trim_prefix("MAP_").replace("_"," "),
			"name_ko":collection().title(h),"theme":id(h),"indoor":indoor,"overworld":not indoor,
			"count":0,"encounters":[],"encounter_rate":0,"map_only":true}
	return result

static func area(place: String) -> Dictionary:
	var meta := metadata(place)
	if meta.is_empty(): return {}
	return {"name":String(meta.constant).trim_prefix("MAP_").replace("_"," "),
		"name_ko":collection().title(header(place)),"encounters":[],"encounter_rate":0}

static func popup(place: String) -> String:
	var meta := metadata(place)
	if meta.get("mapsec", "") == "MAPSEC_ILEX_FOREST": return "forest"
	match meta.get("mapType", ""):
		"MAP_TYPE_INTERIOR": return "indoors"
		"MAP_TYPE_CITY_TOWN": return "town" if header(place) in [60,67,74,87] else "city"
	return "route"

static func title_at(place: String, pos: Vector2) -> String:
	if not has(place): return ""
	var c := collection()
	var scene := c.scene_data(c.scene_for(header(place)))
	var h := c.header_at(scene, Vector2i((pos / 24.0).floor()))
	return c.title(h if h != 0 else header(place))
